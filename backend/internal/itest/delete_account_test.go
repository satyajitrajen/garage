package itest

import (
	"strings"
	"testing"
	"time"

	"garage-backend/internal/api"
	"garage-backend/internal/store"
)

func TestDeleteAccount(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "del-a")
	b := registerOwner(t, "del-b")
	soloGarage := a.Memberships[0].GarageID
	sharedGarage := b.Memberships[0].GarageID
	staff := createStaffSession(t, a, soloGarage, "del-staff", nil)

	// A also co-owns B's garage.
	if _, err := pool.Exec(ctx,
		`INSERT INTO memberships (garage_id, user_id, role) VALUES ($1, $2, 'owner')`,
		sharedGarage, a.User.ID); err != nil {
		t.Fatal(err)
	}

	del := func(password, confirm string) (int, []byte) {
		return doJSON(t, "DELETE", "/api/me", a.AccessToken, "", map[string]string{"password": password, "confirm": confirm})
	}
	if status, _ := del("password123", ""); status != 400 {
		t.Fatalf("missing DELETE confirmation: status %d", status)
	}
	if status, _ := del("wrong", "DELETE"); status != 400 {
		t.Fatalf("wrong password: status %d", status)
	}
	status, data := del("password123", "DELETE")
	if status != 200 {
		t.Fatalf("schedule delete: status %d body %s", status, data)
	}
	var sched struct {
		Status string    `json:"status"`
		At     time.Time `json:"deletion_scheduled_at"`
	}
	mustUnmarshal(t, data, &sched)
	if sched.Status != "scheduled" || time.Until(sched.At) < 6*24*time.Hour || time.Until(sched.At) > 7*24*time.Hour+time.Minute {
		t.Fatalf("schedule response: %+v", sched)
	}

	// During the grace period the user can still sign in and sees the date.
	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-del-a@test.dev", "password": "password123"})
	if status != 200 {
		t.Fatalf("login during grace: status %d", status)
	}
	var me struct {
		User struct {
			DeletionScheduledAt *time.Time `json:"deletion_scheduled_at"`
		} `json:"user"`
	}
	mustUnmarshal(t, data, &me)
	if me.User.DeletionScheduledAt == nil {
		t.Fatal("login response does not show the pending deletion")
	}
	// Asking again must not push the date back.
	if _, data := del("password123", "DELETE"); !strings.Contains(string(data), sched.At.UTC().Format("2006-01-02T15:04:05")) {
		t.Fatalf("repeat request moved the date: %s", data)
	}

	// Purging before the date deletes nothing.
	srv := &api.Server{Store: store.New(pool)}
	if n := srv.PurgeDueAccounts(ctx); n != 0 {
		t.Fatalf("purged %d accounts before the grace period ended", n)
	}

	// Cancelling keeps the account; a purge after the old date does nothing.
	if status, data := doJSON(t, "POST", "/api/me/deletion/cancel", a.AccessToken, "", nil); status != 200 {
		t.Fatalf("cancel: status %d body %s", status, data)
	}
	if n := srv.PurgeDueAccounts(ctx); n != 0 {
		t.Fatalf("purged a cancelled account")
	}

	// Schedule again and let the grace period lapse.
	if status, _ := del("password123", "DELETE"); status != 200 {
		t.Fatal("reschedule failed")
	}
	if _, err := pool.Exec(ctx, `UPDATE users SET deletion_scheduled_at = now() - interval '1 minute' WHERE id = $1`, a.User.ID); err != nil {
		t.Fatal(err)
	}
	if n := srv.PurgeDueAccounts(ctx); n != 1 {
		t.Fatalf("purged %d accounts, want 1", n)
	}

	count := func(q string, args ...any) int {
		var n int
		if err := pool.QueryRow(ctx, q, args...).Scan(&n); err != nil {
			t.Fatal(err)
		}
		return n
	}
	if n := count(`SELECT count(*) FROM users WHERE id = $1`, a.User.ID); n != 0 {
		t.Fatal("user row still exists")
	}
	if n := count(`SELECT count(*) FROM garages WHERE id = $1`, soloGarage); n != 0 {
		t.Fatal("solely owned garage still exists")
	}
	if n := count(`SELECT count(*) FROM garages WHERE id = $1`, sharedGarage); n != 1 {
		t.Fatal("shared garage was deleted")
	}
	if n := count(`SELECT count(*) FROM memberships WHERE user_id = $1`, staff.User.ID); n != 0 {
		t.Fatal("staff membership in deleted garage remains")
	}
	if status, _ := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-del-a@test.dev", "password": "password123",
	}); status == 200 {
		t.Fatal("deleted user can still sign in")
	}
	if status, _ := doJSON(t, "GET", "/api/garages/"+sharedGarage+"/settings", b.AccessToken, sharedGarage, nil); status != 200 {
		t.Fatalf("other owner lost access: status %d", status)
	}
}
