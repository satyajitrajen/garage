package itest

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/config"
	"garage-backend/internal/notify"
	"garage-backend/internal/store"
)

func TestDeviceTokenRegisterAndUnregister(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "dev1")
	gid := owner.Memberships[0].GarageID
	path := "/api/garages/" + gid + "/devices/token"

	status, data := doJSON(t, "POST", path, owner.AccessToken, "", map[string]string{"token": "tok-a", "platform": "android"})
	if status != 204 {
		t.Fatalf("register: status %d body %s", status, data)
	}
	// Re-registering the same token is an upsert, not a conflict.
	if status, data := doJSON(t, "POST", path, owner.AccessToken, "", map[string]string{"token": "tok-a", "platform": "ios"}); status != 204 {
		t.Fatalf("re-register: status %d body %s", status, data)
	}
	if status, _ := doJSON(t, "POST", path, owner.AccessToken, "", map[string]string{"token": "", "platform": "android"}); status != 400 {
		t.Fatalf("empty token: want 400, got %d", status)
	}
	if status, _ := doJSON(t, "POST", path, owner.AccessToken, "", map[string]string{"token": "tok-b", "platform": "symbian"}); status != 400 {
		t.Fatalf("bad platform: want 400, got %d", status)
	}
	if status, _ := doJSON(t, "POST", path, "", "", map[string]string{"token": "tok-c"}); status != 401 {
		t.Fatalf("unauthenticated: want 401, got %d", status)
	}

	tokens, err := store.New(pool).ListDeviceTokensByGarage(ctx, gid)
	if err != nil || len(tokens) != 1 || tokens[0] != "tok-a" {
		t.Fatalf("tokens after register: %v err=%v", tokens, err)
	}

	// Another garage's owner cannot remove this device.
	other := registerOwner(t, "dev2")
	otherPath := "/api/garages/" + other.Memberships[0].GarageID + "/devices/token"
	doJSON(t, "DELETE", otherPath, other.AccessToken, "", map[string]string{"token": "tok-a"})
	if tokens, _ := store.New(pool).ListDeviceTokensByGarage(ctx, gid); len(tokens) != 1 {
		t.Fatalf("foreign delete removed token: %v", tokens)
	}

	if status, data := doJSON(t, "DELETE", path, owner.AccessToken, "", map[string]string{"token": "tok-a"}); status != 204 {
		t.Fatalf("unregister: status %d body %s", status, data)
	}
	if tokens, _ := store.New(pool).ListDeviceTokensByGarage(ctx, gid); len(tokens) != 0 {
		t.Fatalf("tokens after unregister: %v", tokens)
	}
}

func TestSubscriptionActivationPushesToGarageDevices(t *testing.T) {
	truncate(t)
	var mu sync.Mutex
	var sent []map[string]any
	fcm := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/projects/test-proj/messages:send" {
			w.WriteHeader(404)
			return
		}
		var body map[string]any
		json.NewDecoder(r.Body).Decode(&body)
		mu.Lock()
		sent = append(sent, body)
		mu.Unlock()
		w.Write([]byte(`{}`))
	}))
	defer fcm.Close()

	srv := httptest.NewServer(api.NewRouter(&api.Server{
		Store:    store.New(pool),
		Issuer:   auth.NewTokenIssuer("test-secret-16-chars"),
		Config:   config.Config{RazorpayWebhookSecret: webhookSecret},
		Notifier: notify.New(fcm.Client(), "test-proj", fcm.URL),
	}))
	defer srv.Close()

	owner := registerOwner(t, "push1")
	gid := owner.Memberships[0].GarageID
	if status, data := doJSON(t, "POST", "/api/garages/"+gid+"/devices/token", owner.AccessToken, "",
		map[string]string{"token": "tok-push", "platform": "android"}); status != 204 {
		t.Fatalf("register: status %d body %s", status, data)
	}

	evt := map[string]any{
		"id": "evt_push_1", "event": "subscription.activated",
		"payload": map[string]any{"subscription": map[string]any{
			"id": "sub_push_1", "notes": map[string]any{"garage_id": gid}}},
	}
	post := func() {
		raw, _ := json.Marshal(evt)
		mac := hmac.New(sha256.New, []byte(webhookSecret))
		mac.Write(raw)
		req, _ := http.NewRequest("POST", srv.URL+"/api/billing/webhooks/razorpay", bytes.NewReader(raw))
		req.Header.Set("X-Razorpay-Signature", hex.EncodeToString(mac.Sum(nil)))
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		if resp.StatusCode != 200 {
			t.Fatalf("webhook: status %d", resp.StatusCode)
		}
	}
	post()
	post() // a replayed event must not push again

	deadline := time.Now().Add(5 * time.Second)
	for {
		mu.Lock()
		n := len(sent)
		mu.Unlock()
		if n >= 1 || time.Now().After(deadline) {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	time.Sleep(200 * time.Millisecond)
	mu.Lock()
	defer mu.Unlock()
	if len(sent) != 1 {
		t.Fatalf("want exactly 1 push, got %d: %v", len(sent), sent)
	}
	msg, _ := sent[0]["message"].(map[string]any)
	notif, _ := msg["notification"].(map[string]any)
	if msg["token"] != "tok-push" || notif["title"] != "Subscription active" {
		t.Fatalf("unexpected push: %v", sent[0])
	}
}
