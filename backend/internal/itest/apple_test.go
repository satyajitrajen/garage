package itest

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/config"
	"garage-backend/internal/store"
)

// fakeJWS wraps a payload as an unsigned three-part JWS like Apple's.
func fakeJWS(t *testing.T, payload any) string {
	t.Helper()
	b, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	enc := base64.RawURLEncoding.EncodeToString
	return enc([]byte(`{"alg":"ES256"}`)) + "." + enc(b) + ".sig"
}

// appleHarness runs the API against a fake App Store Server API that
// reports subscription status *status for transaction "tx-1".
type appleHarness struct {
	srv    *httptest.Server
	status atomic.Int32
	token  atomic.Value // garage id stamped as appAccountToken
}

func newAppleHarness(t *testing.T) *appleHarness {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	pemKey := string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))

	h := &appleHarness{}
	h.status.Store(1)
	h.token.Store("")
	apple := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") {
			w.WriteHeader(401)
			return
		}
		if r.URL.Path != "/inApps/v1/subscriptions/tx-1" {
			w.WriteHeader(404)
			return
		}
		tx := fakeJWS(t, map[string]any{
			"bundleId": "com.nexory.garage", "productId": "com.nexory.garage.pro.yearly",
			"originalTransactionId": "tx-1", "appAccountToken": h.token.Load(),
			"expiresDate": time.Now().Add(365 * 24 * time.Hour).UnixMilli(),
		})
		json.NewEncoder(w).Encode(map[string]any{"data": []any{map[string]any{
			"lastTransactions": []any{map[string]any{
				"status": h.status.Load(), "signedTransactionInfo": tx,
			}},
		}}})
	}))
	t.Cleanup(apple.Close)

	h.srv = httptest.NewServer(api.NewRouter(&api.Server{
		Store:  store.New(pool),
		Issuer: auth.NewTokenIssuer("test-secret-16-chars"),
		Config: config.Config{
			AppleBundleID: "com.nexory.garage", AppleIssuerID: "issuer", AppleKeyID: "kid",
			AppleIAPPrivateKey:  pemKey,
			AppleProductMonthly: "com.nexory.garage.pro.monthly",
			AppleProductYearly:  "com.nexory.garage.pro.yearly",
			AppleAPIBase:        apple.URL,
		},
	}))
	t.Cleanup(h.srv.Close)
	return h
}

func (h *appleHarness) post(t *testing.T, path, token, gid string, body any) (int, []byte) {
	t.Helper()
	old := ts
	ts = h.srv
	defer func() { ts = old }()
	return doJSON(t, "POST", path, token, gid, body)
}

func TestApplePurchaseVerifyAndNotify(t *testing.T) {
	truncate(t)
	h := newAppleHarness(t)
	owner := registerOwner(t, "apple-iap")
	gid := owner.Memberships[0].GarageID
	other := registerOwner(t, "apple-iap2")
	otherGid := other.Memberships[0].GarageID
	h.token.Store(gid)
	path := "/api/garages/" + gid + "/billing/apple"

	// Unknown transaction → 404.
	if status, data := h.post(t, path, owner.AccessToken, gid, map[string]string{"transaction_id": "nope"}); status != 404 {
		t.Fatalf("unknown tx: status %d body %s", status, data)
	}
	// Another garage can't claim this garage's purchase.
	if status, data := h.post(t, "/api/garages/"+otherGid+"/billing/apple", other.AccessToken, otherGid,
		map[string]string{"transaction_id": "tx-1"}); status != 403 {
		t.Fatalf("foreign garage: status %d body %s", status, data)
	}
	// Owner verifies → active yearly.
	status, data := h.post(t, path, owner.AccessToken, gid, map[string]string{"transaction_id": "tx-1"})
	if status != 200 {
		t.Fatalf("verify: status %d body %s", status, data)
	}
	sub, err := store.New(pool).SubscriptionByGarage(ctx, gid)
	if err != nil {
		t.Fatal(err)
	}
	if sub.Status != "active" || sub.Provider != "apple" || sub.PlanCode != "yearly" ||
		sub.ProviderSubscription != "tx-1" || sub.CurrentPeriodEnd == nil {
		t.Fatalf("after verify: %+v", sub)
	}

	// Cancel through our API is refused for Apple subscriptions.
	if status, data := h.post(t, "/api/garages/"+gid+"/billing/cancel", owner.AccessToken, gid, nil); status != 400 {
		t.Fatalf("cancel apple: status %d body %s", status, data)
	}

	// Apple reports expiry → notification re-fetches and cancels.
	h.status.Store(2)
	note := map[string]string{"signedPayload": fakeJWS(t, map[string]any{
		"notificationType": "EXPIRED", "notificationUUID": "n-1",
		"data": map[string]any{"signedTransactionInfo": fakeJWS(t, map[string]any{
			// Forged fields are ignored: only the id is used for lookup.
			"originalTransactionId": "tx-1", "expiresDate": 1,
		})},
	})}
	if status, data := h.post(t, "/api/billing/webhooks/apple", "", "", note); status != 200 {
		t.Fatalf("notification: status %d body %s", status, data)
	}
	sub, _ = store.New(pool).SubscriptionByGarage(ctx, gid)
	if sub.Status != "cancelled" || sub.CurrentPeriodEnd.Before(time.Now()) {
		t.Fatalf("after expiry notification: %+v", sub)
	}
}

func TestAppleVerifyOwnerOnlyAndUnconfigured(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "apple-cfg")
	gid := owner.Memberships[0].GarageID
	// Shared server has no Apple key → 503.
	status, data := doJSON(t, "POST", "/api/garages/"+gid+"/billing/apple", owner.AccessToken, gid,
		map[string]string{"transaction_id": "tx-1"})
	if status != 503 {
		t.Fatalf("unconfigured: status %d body %s", status, data)
	}
	staff := createStaffSession(t, owner, gid, "apple-staff", nil)
	status, data = doJSON(t, "POST", "/api/garages/"+gid+"/billing/apple", staff.AccessToken, gid,
		map[string]string{"transaction_id": "tx-1"})
	if status != 403 {
		t.Fatalf("staff: status %d body %s", status, data)
	}
}
