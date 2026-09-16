package itest

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/store"
)

// SaaS coverage: doc sequences, pagination envelope, identity proofing,
// invites, subscription gate, billing endpoints, admin isolation.

func TestDocNumbersAutoAssignAndNext(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-doc")
	gid := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, gid, customerBody("DocCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, gid, customer.ID)

	// Empty numbers auto-assign with the documented prefixes.
	status, data, jc := createJobCard(t, owner.AccessToken, gid, jobCardBody("", customer.ID, vehicle.ID))
	if status != 201 || jc.JobCardNumber == "" || len(jc.JobCardNumber) < 4 || jc.JobCardNumber[:3] != "JC-" {
		t.Fatalf("jobcard auto number: status %d body %s", status, data)
	}
	status, _, inv := createInvoice(t, owner.AccessToken, gid, invoiceBody("", customer.ID, vehicle.ID))
	if status != 201 || inv.InvoiceNumber == "" {
		t.Fatalf("invoice auto number: status %d", status)
	}
	// Second invoice gets a distinct number (no multi-user collision).
	status, _, inv2 := createInvoice(t, owner.AccessToken, gid, invoiceBody("", customer.ID, vehicle.ID))
	if status != 201 || inv2.InvoiceNumber == inv.InvoiceNumber {
		t.Fatalf("invoice sequence: %q vs %q", inv.InvoiceNumber, inv2.InvoiceNumber)
	}
	// Explicit /next endpoint agrees on shape.
	status, data = doJSON(t, "GET", "/api/garages/"+gid+"/doc-numbers/next?kind=jobcard",
		owner.AccessToken, gid, nil)
	if status != 200 {
		t.Fatalf("next number: status %d body %s", status, data)
	}
	var next struct {
		Number string `json:"number"`
	}
	mustUnmarshal(t, data, &next)
	if len(next.Number) < 4 || next.Number[:3] != "JC-" {
		t.Fatalf("next number shape: %q", next.Number)
	}
	// Bad kind → 400.
	if status, _ := doJSON(t, "GET", "/api/garages/"+gid+"/doc-numbers/next?kind=nope",
		owner.AccessToken, gid, nil); status != 400 {
		t.Fatalf("bad kind: status %d", status)
	}
}

func TestPaginationEnvelope(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-page")
	gid := owner.Memberships[0].GarageID
	for _, n := range []string{"P1", "P2", "P3"} {
		if status, data, _ := createCustomer(t, owner.AccessToken, gid, customerBody(n)); status != 201 {
			t.Fatalf("seed: status %d body %s", status, data)
		}
	}
	// Legacy shape without params.
	status, data := doJSON(t, "GET", "/api/customers", owner.AccessToken, gid, nil)
	if status != 200 {
		t.Fatalf("legacy list: status %d", status)
	}
	var legacy struct {
		Items []any `json:"items"`
		Total *int  `json:"total"`
	}
	mustUnmarshal(t, data, &legacy)
	if len(legacy.Items) != 3 || legacy.Total != nil {
		t.Fatalf("legacy shape: items=%d total-present=%v", len(legacy.Items), legacy.Total != nil)
	}
	// Paged shape with limit/offset.
	status, data = doJSON(t, "GET", "/api/customers?limit=2&offset=1", owner.AccessToken, gid, nil)
	if status != 200 {
		t.Fatalf("paged list: status %d", status)
	}
	var paged struct {
		Items  []any `json:"items"`
		Total  int   `json:"total"`
		Limit  int   `json:"limit"`
		Offset int   `json:"offset"`
	}
	mustUnmarshal(t, data, &paged)
	if len(paged.Items) != 2 || paged.Total != 3 || paged.Limit != 2 || paged.Offset != 1 {
		t.Fatalf("paged shape: %+v", paged)
	}
}

func TestVerifyAndResetFlow(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-id")
	s := store.New(pool)
	var userID string
	if err := pool.QueryRow(ctx, `SELECT id FROM users WHERE email='owner-saas-id@test.dev'`).Scan(&userID); err != nil {
		t.Fatalf("lookup user: %v", err)
	}
	_ = owner

	// verify-request is always 200 (no enumeration), even for unknown emails.
	if status, _ := doJSON(t, "POST", "/api/auth/verify-request", "", "", map[string]string{"email": "nobody@test.dev"}); status != 200 {
		t.Fatalf("verify-request unknown: %d", status)
	}
	// Real token round-trips through the API.
	raw, hash, err := auth.RawToken()
	if err != nil {
		t.Fatal(err)
	}
	if err := s.CreateEmailVerification(ctx, userID, hash, time.Hour); err != nil {
		t.Fatalf("seed verification: %v", err)
	}
	if status, data := doJSON(t, "POST", "/api/auth/verify", "", "", map[string]string{"token": raw}); status != 200 {
		t.Fatalf("verify: status %d body %s", status, data)
	}
	// Single-use: second attempt fails.
	if status, _ := doJSON(t, "POST", "/api/auth/verify", "", "", map[string]string{"token": raw}); status != 400 {
		t.Fatalf("verify reuse: %d", status)
	}
	// Bad token → 400.
	if status, _ := doJSON(t, "POST", "/api/auth/verify", "", "", map[string]string{"token": "nope"}); status != 400 {
		t.Fatalf("verify bad: %d", status)
	}

	// forgot is always 200; reset round-trips and revokes sessions.
	if status, _ := doJSON(t, "POST", "/api/auth/forgot", "", "", map[string]string{"email": "owner-saas-id@test.dev"}); status != 200 {
		t.Fatalf("forgot: %d", status)
	}
	raw2, hash2, _ := auth.RawToken()
	if err := s.CreatePasswordReset(ctx, userID, hash2, time.Hour); err != nil {
		t.Fatalf("seed reset: %v", err)
	}
	if status, data := doJSON(t, "POST", "/api/auth/reset", "", "", map[string]string{"token": raw2, "password": "newpassword123"}); status != 200 {
		t.Fatalf("reset: status %d body %s", status, data)
	}
	// Old password dead, new password works.
	if status, _ := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{"email": "owner-saas-id@test.dev", "password": "password123"}); status != 401 {
		t.Fatalf("old password login: %d", status)
	}
	if status, _ := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{"email": "owner-saas-id@test.dev", "password": "newpassword123"}); status != 200 {
		t.Fatalf("new password login: %d", status)
	}
	// Short password → 400.
	if status, _ := doJSON(t, "POST", "/api/auth/reset", "", "", map[string]string{"token": raw2, "password": "short"}); status != 400 {
		t.Fatalf("short password: %d", status)
	}
}

func TestInviteFlow(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-inv")
	gid := owner.Memberships[0].GarageID
	s := store.New(pool)

	// Owner creates invite via API.
	status, data := doJSON(t, "POST", "/api/garages/"+gid+"/invites", owner.AccessToken, gid,
		map[string]any{"email": "invitee@test.dev"})
	if status != 201 {
		t.Fatalf("create invite: status %d body %s", status, data)
	}
	// Bad role → 400.
	if status, _ := doJSON(t, "POST", "/api/garages/"+gid+"/invites", owner.AccessToken, gid,
		map[string]any{"email": "x@test.dev", "role": "admin"}); status != 400 {
		t.Fatalf("bad role: %d", status)
	}
	// Inviting the owner (already a member) → 409.
	if status, _ := doJSON(t, "POST", "/api/garages/"+gid+"/invites", owner.AccessToken, gid,
		map[string]any{"email": "owner-saas-inv@test.dev"}); status != 409 {
		t.Fatalf("existing member invite: %d", status)
	}

	// Seed a second invite with a known token, preview publicly, accept as
	// new user. The invite names the joiner's address: acceptance is bound
	// to the invited email (F4).
	raw, hash, _ := auth.RawToken()
	var ownerID string
	if err := pool.QueryRow(ctx, `SELECT id FROM users WHERE email='owner-saas-inv@test.dev'`).Scan(&ownerID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateInvite(ctx, gid, "owner-saas-joiner@test.dev", "staff", auth.DefaultStaffPermissions, hash, ownerID); err != nil {
		t.Fatalf("seed invite: %v", err)
	}
	status, data = doJSON(t, "GET", "/api/invites/"+raw, "", "", nil)
	if status != 200 {
		t.Fatalf("preview: status %d body %s", status, data)
	}
	joiner := registerOwner(t, "saas-joiner")
	status, data = doJSON(t, "POST", "/api/invites/"+raw+"/accept", joiner.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("accept: status %d body %s", status, data)
	}
	// Joiner is now a member: garage-scoped read works.
	if status, _ := doJSON(t, "GET", "/api/customers", joiner.AccessToken, gid, nil); status != 200 {
		t.Fatalf("joiner list: %d", status)
	}
	// Reuse → 404.
	if status, _ := doJSON(t, "POST", "/api/invites/"+raw+"/accept", joiner.AccessToken, "", nil); status != 404 {
		t.Fatalf("accept reuse: %d", status)
	}
}

func TestSubscriptionGateAndBilling(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-bill")
	gid := owner.Memberships[0].GarageID
	s := store.New(pool)

	// Billing status starts trialing with a trial window.
	status, data := doJSON(t, "GET", "/api/garages/"+gid+"/billing", owner.AccessToken, gid, nil)
	if status != 200 {
		t.Fatalf("billing: status %d body %s", status, data)
	}
	var billing struct {
		Status string `json:"status"`
	}
	mustUnmarshal(t, data, &billing)
	if billing.Status != "trialing" {
		t.Fatalf("initial status: %q", billing.Status)
	}
	// Checkout without Razorpay config → manual instructions, still 200.
	status, data = doJSON(t, "POST", "/api/garages/"+gid+"/billing/checkout", owner.AccessToken, gid,
		map[string]string{"plan": "monthly"})
	if status != 200 {
		t.Fatalf("checkout: status %d body %s", status, data)
	}

	// Suspend → writes 402, reads still 200.
	if err := s.SuspendGarage(ctx, gid, true); err != nil {
		t.Fatal(err)
	}
	if status, _ := doJSON(t, "POST", "/api/customers", owner.AccessToken, gid, customerBody("Blocked")); status != 402 {
		t.Fatalf("suspended write: %d", status)
	}
	if status, _ := doJSON(t, "GET", "/api/customers", owner.AccessToken, gid, nil); status != 200 {
		t.Fatalf("suspended read: %d", status)
	}
	if err := s.SuspendGarage(ctx, gid, false); err != nil {
		t.Fatal(err)
	}
	if status, data, _ := createCustomer(t, owner.AccessToken, gid, customerBody("Unblocked")); status != 201 {
		t.Fatalf("unsuspended write: status %d body %s", status, data)
	}

	// Webhook activation (signed with the harness webhook secret).
	status, data = postWebhook(t, map[string]any{
		"id": "evt_test_1", "event": "subscription.activated",
		"payload": map[string]any{"subscription": map[string]any{
			"id": "sub_test_1", "notes": map[string]any{"garage_id": gid}}},
	})
	if status != 200 {
		t.Fatalf("webhook: status %d body %s", status, data)
	}
	sub, err := s.SubscriptionByGarage(ctx, gid)
	if err != nil || sub.Status != "active" {
		t.Fatalf("webhook status: %+v err=%v", sub, err)
	}
	// Replay is idempotent.
	if status, _ := postWebhook(t, map[string]any{
		"id": "evt_test_1", "event": "subscription.activated",
		"payload": map[string]any{"subscription": map[string]any{
			"id": "sub_test_1", "notes": map[string]any{"garage_id": gid}}},
	}); status != 200 {
		t.Fatalf("webhook replay: %d", status)
	}
	// Suspend then pay: activation must re-enable writes (both status
	// holders stay in sync).
	if err := s.SuspendGarage(ctx, gid, true); err != nil {
		t.Fatal(err)
	}
	status, data = postWebhook(t, map[string]any{
		"id": "evt_test_2", "event": "subscription.charged",
		"payload": map[string]any{"subscription": map[string]any{
			"id": "sub_test_1", "notes": map[string]any{"garage_id": gid}}},
	})
	if status != 200 {
		t.Fatalf("reactivate webhook: status %d body %s", status, data)
	}
	if status, data, _ := createCustomer(t, owner.AccessToken, gid, customerBody("Reactivated")); status != 201 {
		t.Fatalf("write after reactivate: status %d body %s", status, data)
	}
	// past_due with a fresh status change → grace allows writes.
	if _, err := pool.Exec(ctx, `UPDATE garages SET subscription_status='past_due' WHERE id=$1`, gid); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE subscriptions SET status='past_due', updated_at=now() WHERE garage_id=$1`, gid); err != nil {
		t.Fatal(err)
	}
	if status, data, _ := createCustomer(t, owner.AccessToken, gid, customerBody("Grace")); status != 201 {
		t.Fatalf("write in grace: status %d body %s", status, data)
	}
	// past_due older than the grace window → 402 on writes, 200 on reads.
	if _, err := pool.Exec(ctx, `UPDATE subscriptions SET updated_at=now() - interval '4 days' WHERE garage_id=$1`, gid); err != nil {
		t.Fatal(err)
	}
	if status, _ := doJSON(t, "POST", "/api/customers", owner.AccessToken, gid, customerBody("Late")); status != 402 {
		t.Fatalf("write past grace: %d", status)
	}
	if status, _ := doJSON(t, "GET", "/api/customers", owner.AccessToken, gid, nil); status != 200 {
		t.Fatalf("read past grace: %d", status)
	}
}

func TestAdminIsolation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-adm")
	gid := owner.Memberships[0].GarageID
	s := store.New(pool)

	// Non-superadmin → 403 everywhere.
	for _, p := range []string{"/api/admin/garages", "/api/admin/metrics", "/api/admin/audit"} {
		if status, _ := doJSON(t, "GET", p, owner.AccessToken, "", nil); status != 403 {
			t.Fatalf("%s: %d", p, status)
		}
	}
	var ownerID string
	if err := pool.QueryRow(ctx, `SELECT id FROM users WHERE email='owner-saas-adm@test.dev'`).Scan(&ownerID); err != nil {
		t.Fatal(err)
	}
	if err := s.SetSuperadmin(ctx, ownerID, true); err != nil {
		t.Fatal(err)
	}
	// Now listed, metrics work, suspend cycle gates writes.
	if status, data := doJSON(t, "GET", "/api/admin/garages", owner.AccessToken, "", nil); status != 200 {
		t.Fatalf("admin list: status %d body %s", status, data)
	}
	if status, _ := doJSON(t, "GET", "/api/admin/metrics", owner.AccessToken, "", nil); status != 200 {
		t.Fatalf("metrics: %d", status)
	}
	if status, _ := doJSON(t, "POST", "/api/admin/garages/"+gid+"/suspend", owner.AccessToken, "", nil); status != 200 {
		t.Fatalf("suspend: %d", status)
	}
	if status, _ := doJSON(t, "POST", "/api/customers", owner.AccessToken, gid, customerBody("Nope")); status != 402 {
		t.Fatalf("suspended write: %d", status)
	}
	if status, _ := doJSON(t, "POST", "/api/admin/garages/"+gid+"/unsuspend", owner.AccessToken, "", nil); status != 200 {
		t.Fatalf("unsuspend: %d", status)
	}
	if status, data, _ := createCustomer(t, owner.AccessToken, gid, customerBody("Yep")); status != 201 {
		t.Fatalf("restored write: status %d body %s", status, data)
	}
	if status, _ := doJSON(t, "GET", "/api/admin/audit?garage_id="+gid, owner.AccessToken, "", nil); status != 200 {
		t.Fatalf("audit: %d", status)
	}
}

// TestWebhookFailsClosedWithoutSecret pins the F1 fix: with the webhook
// secret unset the endpoint must refuse unsigned requests instead of
// processing them.
func TestWebhookFailsClosedWithoutSecret(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "saas-hook0")
	gid := owner.Memberships[0].GarageID
	s := store.New(pool)

	// Stand-up a second server with an empty Config (the shared harness
	// server carries a webhook secret).
	unconfigured := httptest.NewServer(api.NewRouter(&api.Server{
		Store:  s,
		Issuer: auth.NewTokenIssuer("test-secret-16-chars"),
	}))
	defer unconfigured.Close()

	resp, err := http.Post(unconfigured.URL+"/api/billing/webhooks/razorpay",
		"application/json", strings.NewReader(`{"id":"evt_unsigned","event":"subscription.activated"}`))
	if err != nil {
		t.Fatal(err)
	}
	data, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 503 {
		t.Fatalf("webhook without secret: status %d body %s", resp.StatusCode, data)
	}
	if code, message := decodeError(t, data); code != "internal" || message != "webhook not configured" {
		t.Fatalf("error = %s / %s", code, message)
	}
	sub, err := s.SubscriptionByGarage(ctx, gid)
	if err != nil || sub.Status != "trialing" {
		t.Fatalf("subscription must stay trialing, got %+v err=%v", sub, err)
	}

	// With the secret set, a missing/invalid signature is 401 and ignored.
	status, data := doJSON(t, "POST", "/api/billing/webhooks/razorpay", "", "", map[string]any{
		"id": "evt_badsig", "event": "subscription.activated",
		"payload": map[string]any{"subscription": map[string]any{
			"id": "sub_test_1", "notes": map[string]any{"garage_id": gid}}},
	})
	if status != 401 {
		t.Fatalf("bad signature: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unauthorized" || message != "bad webhook signature" {
		t.Fatalf("error = %s / %s", code, message)
	}
	sub, err = s.SubscriptionByGarage(ctx, gid)
	if err != nil || sub.Status != "trialing" {
		t.Fatalf("subscription must stay trialing after bad signature, got %+v err=%v", sub, err)
	}
}

// TestInviteOwnerRoleGuard pins the F3 fix: staff.manage alone must not be
// able to mint OWNER invites.
func TestInviteOwnerRoleGuard(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "inv-role")
	gid := owner.Memberships[0].GarageID
	mgr := createStaffSession(t, owner, gid, "mgr", []string{"staff.manage"})

	// staff-manager (non-owner) requesting an owner invite → 403.
	status, data := doJSON(t, "POST", "/api/garages/"+gid+"/invites", mgr.AccessToken, gid,
		map[string]any{"email": "escalate@test.dev", "role": "owner"})
	if status != 403 {
		t.Fatalf("staff-manager owner invite: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "forbidden" || message != "only the owner can invite owners" {
		t.Fatalf("error = %s / %s", code, message)
	}
	// The same manager can still mint ordinary staff invites.
	status, data = doJSON(t, "POST", "/api/garages/"+gid+"/invites", mgr.AccessToken, gid,
		map[string]any{"email": "plain-staff@test.dev"})
	if status != 201 {
		t.Fatalf("staff-manager staff invite: status %d body %s", status, data)
	}
	var staffInvite store.Invite
	mustUnmarshal(t, data, &staffInvite)
	if staffInvite.Role != "staff" {
		t.Fatalf("staff invite role = %s", staffInvite.Role)
	}
	// The owner may invite owners.
	status, data = doJSON(t, "POST", "/api/garages/"+gid+"/invites", owner.AccessToken, gid,
		map[string]any{"email": "co-owner@test.dev", "role": "owner"})
	if status != 201 {
		t.Fatalf("owner owner-invite: status %d body %s", status, data)
	}
	var ownerInvite store.Invite
	mustUnmarshal(t, data, &ownerInvite)
	if ownerInvite.Role != "owner" {
		t.Fatalf("owner invite role = %s", ownerInvite.Role)
	}
}

// TestInviteEmailMismatch pins the F4 fix: only the invited email can
// consume an invite, and a rejected attempt must not consume it.
func TestInviteEmailMismatch(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "inv-mail")
	gid := owner.Memberships[0].GarageID
	invitee := registerOwner(t, "inv-mail-a") // the invited user
	other := registerOwner(t, "inv-mail-b")   // an unrelated user
	s := store.New(pool)

	// Seed the invite with a mixed-case variant of the invitee's email:
	// matching must be case-insensitive (citext semantics).
	raw, hash, err := auth.RawToken()
	if err != nil {
		t.Fatal(err)
	}
	var ownerID string
	if err := pool.QueryRow(ctx, `SELECT id FROM users WHERE email='owner-inv-mail@test.dev'`).Scan(&ownerID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateInvite(ctx, gid, "Owner-Inv-Mail-A@Test.dev", "staff",
		auth.DefaultStaffPermissions, hash, ownerID); err != nil {
		t.Fatalf("seed invite: %v", err)
	}

	// A different authenticated user cannot consume it.
	status, data := doJSON(t, "POST", "/api/invites/"+raw+"/accept", other.AccessToken, "", nil)
	if status != 403 {
		t.Fatalf("wrong-user accept: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "forbidden" || message != "invite was issued to a different email" {
		t.Fatalf("error = %s / %s", code, message)
	}
	// The invite is NOT consumed: the public preview still resolves.
	if status, data := doJSON(t, "GET", "/api/invites/"+raw, "", "", nil); status != 200 {
		t.Fatalf("invite consumed by wrong user: status %d body %s", status, data)
	}
	// The invited user can still accept.
	status, data = doJSON(t, "POST", "/api/invites/"+raw+"/accept", invitee.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("invitee accept: status %d body %s", status, data)
	}
	// Case-insensitive match: the invitee is now a member with staff perms.
	if status, _ := doJSON(t, "GET", "/api/customers", invitee.AccessToken, gid, nil); status != 200 {
		t.Fatalf("invitee should be a member now: %d", status)
	}
}
