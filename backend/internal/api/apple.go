package api

import (
	"context"
	"crypto/ecdsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

// App Store Server API hosts. Production is tried first; App Review and
// TestFlight purchases only exist in sandbox, so a "not found" falls back.
const (
	appleProdAPI    = "https://api.storekit.itunes.apple.com"
	appleSandboxAPI = "https://api.storekit-sandbox.itunes.apple.com"
)

var errAppleNotFound = errors.New("apple: transaction not found")

// appleTransaction is the decoded payload of a signedTransactionInfo JWS.
type appleTransaction struct {
	BundleID              string `json:"bundleId"`
	ProductID             string `json:"productId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	AppAccountToken       string `json:"appAccountToken"`
	ExpiresDate           int64  `json:"expiresDate"`
}

// appleSubState is the latest state of one subscription from Get All
// Subscription Statuses.
type appleSubState struct {
	Status int // 1 active, 2 expired, 3 billing retry, 4 grace period, 5 revoked
	Tx     appleTransaction
}

// POST /api/garages/{garageId}/billing/apple {transaction_id} (owner).
// The app calls this after a StoreKit purchase or restore. The transaction
// is looked up with Apple, never trusted from the client.
func (s *Server) verifyApplePurchase(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	if auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "owner only")
		return
	}
	var req struct {
		TransactionID string `json:"transaction_id"`
	}
	if !httputil.Decode(w, r, &req) || strings.TrimSpace(req.TransactionID) == "" {
		httputil.Error(w, 400, "invalid_request", "transaction_id is required")
		return
	}
	if s.Config.AppleIAPPrivateKey == "" {
		httputil.Error(w, 503, "internal", "apple purchases not configured")
		return
	}
	st, err := s.appleSubscriptionState(r.Context(), req.TransactionID)
	if errors.Is(err, errAppleNotFound) {
		httputil.Error(w, 404, "not_found", "transaction not found")
		return
	}
	if err != nil {
		slog.Error("apple status lookup failed", "garage", garageID, "err", err)
		httputil.Error(w, 502, "internal", "could not reach the App Store")
		return
	}
	// The app sets appAccountToken to the garage id at purchase, so a
	// transaction can only unlock the garage that bought it.
	if !strings.EqualFold(st.Tx.AppAccountToken, garageID) {
		httputil.Error(w, 403, "forbidden", "purchase belongs to another workshop")
		return
	}
	status, err := s.applyAppleState(r.Context(), garageID, st)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "purchase already linked to another workshop")
		return
	}
	if err != nil {
		httputil.Error(w, 400, "invalid_request", err.Error())
		return
	}
	s.Store.Audit(r.Context(), garageID, auth.UserID(r.Context()), "billing.apple", "subscription", st.Tx.OriginalTransactionID, nil)
	httputil.JSON(w, 200, map[string]string{"status": status})
}

// POST /api/billing/webhooks/apple — App Store Server Notifications V2.
// The notification body is only used to find the subscription; its state is
// re-fetched from the App Store Server API, so a forged body changes nothing.
func (s *Server) appleWebhook(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		httputil.Error(w, 400, "invalid_request", "body too large")
		return
	}
	if s.Config.AppleIAPPrivateKey == "" {
		httputil.Error(w, 503, "internal", "webhook not configured")
		return
	}
	var body struct {
		SignedPayload string `json:"signedPayload"`
	}
	var note struct {
		NotificationType string `json:"notificationType"`
		NotificationUUID string `json:"notificationUUID"`
		Data             struct {
			SignedTransactionInfo string `json:"signedTransactionInfo"`
		} `json:"data"`
	}
	var tx appleTransaction
	if json.Unmarshal(raw, &body) != nil ||
		decodeJWSPayload(body.SignedPayload, &note) != nil ||
		decodeJWSPayload(note.Data.SignedTransactionInfo, &tx) != nil ||
		tx.OriginalTransactionID == "" {
		httputil.Error(w, 400, "invalid_request", "unreadable notification")
		return
	}
	garageID, err := s.Store.GarageIDByProviderSubscription(r.Context(), tx.OriginalTransactionID)
	if err != nil {
		// Not linked yet (the app's verify call links it). Ack so Apple
		// doesn't retry.
		httputil.JSON(w, 200, map[string]string{"status": "ignored"})
		return
	}
	if note.NotificationUUID != "" {
		if seen, _ := s.Store.SubscriptionEventSeen(r.Context(), note.NotificationUUID); !seen {
			_ = s.Store.RecordSubscriptionEvent(r.Context(), garageID, "apple", note.NotificationUUID, note.NotificationType, string(raw))
		}
	}
	st, err := s.appleSubscriptionState(r.Context(), tx.OriginalTransactionID)
	if err != nil {
		slog.Error("apple status lookup failed", "garage", garageID, "err", err)
		httputil.Error(w, 502, "internal", "could not reach the App Store")
		return
	}
	if _, err := s.applyAppleState(r.Context(), garageID, st); err != nil {
		slog.Error("apple status apply failed", "garage", garageID, "err", err)
	}
	httputil.JSON(w, 200, map[string]string{"status": "ok"})
}

// applyAppleState maps an App Store status onto the garage subscription and
// returns the stored status.
func (s *Server) applyAppleState(ctx context.Context, garageID string, st appleSubState) (string, error) {
	if st.Tx.BundleID != s.Config.AppleBundleID {
		return "", fmt.Errorf("purchase is for another app")
	}
	var plan string
	switch st.Tx.ProductID {
	case s.Config.AppleProductMonthly:
		plan = "monthly"
	case s.Config.AppleProductYearly:
		plan = "yearly"
	default:
		return "", fmt.Errorf("unknown product %q", st.Tx.ProductID)
	}
	var status string
	switch st.Status {
	case 1, 4: // active, billing grace period
		status = "active"
	case 3: // billing retry
		status = "past_due"
	default: // expired, revoked
		status = "cancelled"
	}
	var periodEnd *time.Time
	if st.Tx.ExpiresDate > 0 {
		t := time.UnixMilli(st.Tx.ExpiresDate).UTC()
		periodEnd = &t
	}
	return status, s.Store.SetAppleSubscription(ctx, garageID, st.Tx.OriginalTransactionID, plan, status, periodEnd)
}

// appleSubscriptionState calls Get All Subscription Statuses for any
// transaction id in the subscription and returns its latest transaction.
func (s *Server) appleSubscriptionState(ctx context.Context, transactionID string) (appleSubState, error) {
	token, err := s.appleAPIToken()
	if err != nil {
		return appleSubState{}, err
	}
	bases := []string{appleProdAPI, appleSandboxAPI}
	if s.Config.AppleAPIBase != "" {
		bases = []string{s.Config.AppleAPIBase}
	}
	var lastErr error
	for _, base := range bases {
		st, err := fetchAppleStatus(ctx, base, token, transactionID)
		if err == nil {
			return st, nil
		}
		lastErr = err
		if !errors.Is(err, errAppleNotFound) {
			return appleSubState{}, err
		}
	}
	return appleSubState{}, lastErr
}

func fetchAppleStatus(ctx context.Context, base, token, transactionID string) (appleSubState, error) {
	req, err := http.NewRequestWithContext(ctx, "GET",
		strings.TrimRight(base, "/")+"/inApps/v1/subscriptions/"+transactionID, nil)
	if err != nil {
		return appleSubState{}, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	client := &http.Client{Timeout: 15 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return appleSubState{}, err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if res.StatusCode == 404 {
		return appleSubState{}, errAppleNotFound
	}
	if res.StatusCode != 200 {
		return appleSubState{}, fmt.Errorf("apple status %d: %s", res.StatusCode, raw)
	}
	var out struct {
		Data []struct {
			LastTransactions []struct {
				Status                int    `json:"status"`
				SignedTransactionInfo string `json:"signedTransactionInfo"`
			} `json:"lastTransactions"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &out); err != nil {
		return appleSubState{}, fmt.Errorf("unexpected apple response: %s", raw)
	}
	// One subscription group → one entry. Prefer the newest expiry if more.
	var best appleSubState
	found := false
	for _, g := range out.Data {
		for _, lt := range g.LastTransactions {
			var tx appleTransaction
			if decodeJWSPayload(lt.SignedTransactionInfo, &tx) != nil {
				continue
			}
			if !found || tx.ExpiresDate > best.Tx.ExpiresDate {
				best, found = appleSubState{Status: lt.Status, Tx: tx}, true
			}
		}
	}
	if !found {
		return appleSubState{}, errAppleNotFound
	}
	return best, nil
}

// appleAPIToken signs the short-lived ES256 JWT the App Store Server API
// requires.
func (s *Server) appleAPIToken() (string, error) {
	key, err := jwt.ParseECPrivateKeyFromPEM([]byte(s.Config.AppleIAPPrivateKey))
	if err != nil {
		return "", fmt.Errorf("apple private key: %w", err)
	}
	return signAppleToken(key, s.Config.AppleKeyID, s.Config.AppleIssuerID, s.Config.AppleBundleID)
}

func signAppleToken(key *ecdsa.PrivateKey, keyID, issuerID, bundleID string) (string, error) {
	now := time.Now()
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": issuerID,
		"iat": now.Unix(),
		"exp": now.Add(20 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": bundleID,
	})
	tok.Header["kid"] = keyID
	return tok.SignedString(key)
}

// decodeJWSPayload reads the payload of an Apple JWS without verifying its
// signature. Callers only use it on data fetched from Apple over TLS, or as
// a lookup key whose result is then re-fetched from Apple.
func decodeJWSPayload(jws string, dst any) error {
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		return errors.New("malformed jws")
	}
	b, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return err
	}
	return json.Unmarshal(b, dst)
}
