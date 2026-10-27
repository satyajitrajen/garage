package itest

import "testing"

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

	if status, _ := doJSON(t, "DELETE", "/api/me", a.AccessToken, "", map[string]string{"password": "wrong"}); status != 400 {
		t.Fatalf("wrong password: status %d", status)
	}
	status, data := doJSON(t, "DELETE", "/api/me", a.AccessToken, "", map[string]string{"password": "password123"})
	if status != 200 {
		t.Fatalf("delete: status %d body %s", status, data)
	}
	var resp struct {
		GaragesDeleted int `json:"garages_deleted"`
	}
	mustUnmarshal(t, data, &resp)
	if resp.GaragesDeleted != 1 {
		t.Fatalf("garages deleted = %d, want 1 (only the solely owned one)", resp.GaragesDeleted)
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
