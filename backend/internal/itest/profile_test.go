package itest

import "testing"

func TestProfileUpdateAndChangePassword(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "profile")
	other := loginSession(t, "owner-profile@test.dev", "password123")

	// Name update.
	status, data := doJSON(t, "PATCH", "/api/me", owner.AccessToken, "", map[string]string{"name": "  Asha Mane "})
	if status != 200 {
		t.Fatalf("patch me: status %d body %s", status, data)
	}
	var me struct {
		User struct{ Name string } `json:"user"`
	}
	mustUnmarshal(t, data, &me)
	if me.User.Name != "Asha Mane" {
		t.Fatalf("name = %q", me.User.Name)
	}
	if status, _ := doJSON(t, "PATCH", "/api/me", owner.AccessToken, "", map[string]string{"name": " "}); status != 400 {
		t.Fatalf("blank name: status %d", status)
	}

	// Wrong current password is rejected.
	if status, _ := doJSON(t, "POST", "/api/me/password", owner.AccessToken, "", map[string]string{
		"current_password": "nope", "new_password": "newpassword1",
	}); status != 400 {
		t.Fatalf("wrong current: status %d", status)
	}
	// Change keeps this device's session and signs out the other one.
	status, data = doJSON(t, "POST", "/api/me/password", owner.AccessToken, "", map[string]string{
		"current_password": "password123", "new_password": "newpassword1", "refresh_token": owner.RefreshToken,
	})
	if status != 200 {
		t.Fatalf("change: status %d body %s", status, data)
	}
	if status, _ := doJSON(t, "POST", "/api/auth/refresh", "", "", map[string]string{"refresh_token": owner.RefreshToken}); status != 200 {
		t.Fatalf("own session refresh: status %d", status)
	}
	if status, _ := doJSON(t, "POST", "/api/auth/refresh", "", "", map[string]string{"refresh_token": other.RefreshToken}); status == 200 {
		t.Fatal("other session should be revoked")
	}
	if status, _ := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-profile@test.dev", "password": "newpassword1",
	}); status != 200 {
		t.Fatalf("login with new password: status %d", status)
	}
}

func loginSession(t *testing.T, email, password string) authResponse {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{"email": email, "password": password})
	if status != 200 {
		t.Fatalf("login: status %d body %s", status, data)
	}
	var resp authResponse
	mustUnmarshal(t, data, &resp)
	return resp
}
