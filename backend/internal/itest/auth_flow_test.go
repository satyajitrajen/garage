package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestRegisterCreatesOwnerAndMe(t *testing.T) {
	truncate(t)
	resp := registerOwner(t, "me")
	if resp.User.Email != "owner-me@test.dev" {
		t.Fatalf("user = %+v", resp.User)
	}
	if len(resp.Memberships) != 1 {
		t.Fatalf("memberships = %+v", resp.Memberships)
	}
	m := resp.Memberships[0]
	if m.Role != "owner" || m.GarageName != "Garage me" || len(m.Permissions) != 11 || !m.IsActive {
		t.Fatalf("membership = %+v", m)
	}

	status, data := doJSON(t, "GET", "/api/me", resp.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("me: status %d body %s", status, data)
	}
	var me struct {
		User        models.User         `json:"user"`
		Memberships []models.Membership `json:"memberships"`
	}
	mustUnmarshal(t, data, &me)
	if me.User.ID != resp.User.ID || len(me.Memberships) != 1 {
		t.Fatalf("me = %+v", me)
	}
}

func TestRegisterValidation(t *testing.T) {
	truncate(t)
	registerOwner(t, "dup")

	status, data := doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name": "X", "email": "owner-dup@test.dev", "password": "password123", "garageName": "Y",
	})
	if status != 409 {
		t.Fatalf("duplicate email: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "conflict" {
		t.Fatalf("code = %s, want conflict", code)
	}

	status, data = doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name": "X", "email": "short@test.dev", "password": "short", "garageName": "Y",
	})
	if status != 400 {
		t.Fatalf("short password: status %d body %s", status, data)
	}

	status, data = doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name": "", "email": "x@test.dev", "password": "password123", "garageName": "Y",
	})
	if status != 400 {
		t.Fatalf("missing name: status %d body %s", status, data)
	}

	status, data = doJSON(t, "POST", "/api/auth/register", "", "", "not-json")
	if status != 400 {
		t.Fatalf("malformed body: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "invalid_request" {
		t.Fatalf("code = %s, want invalid_request", code)
	}
}

func TestLogin(t *testing.T) {
	truncate(t)
	registerOwner(t, "login")

	status, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-login@test.dev", "password": "wrongpass1",
	})
	if status != 401 {
		t.Fatalf("wrong password: status %d body %s", status, data)
	}
	_, wrongMsg := decodeError(t, data)

	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "nobody-login@test.dev", "password": "wrongpass1",
	})
	if status != 401 {
		t.Fatalf("unknown email: status %d body %s", status, data)
	}
	_, unknownMsg := decodeError(t, data)
	if wrongMsg != unknownMsg {
		t.Fatalf("login errors must not reveal account existence: %q vs %q", wrongMsg, unknownMsg)
	}

	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-login@test.dev", "password": "password123",
	})
	if status != 200 {
		t.Fatalf("login: status %d body %s", status, data)
	}
	var resp authResponse
	mustUnmarshal(t, data, &resp)
	if resp.AccessToken == "" || resp.RefreshToken == "" || len(resp.Memberships) != 1 {
		t.Fatalf("login response = %+v", resp)
	}

	status, data = doJSON(t, "GET", "/api/me", resp.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("me after login: status %d body %s", status, data)
	}
}

func TestMeRequiresAuth(t *testing.T) {
	truncate(t)
	status, data := doJSON(t, "GET", "/api/me", "", "", nil)
	if status != 401 {
		t.Fatalf("no token: status %d body %s", status, data)
	}
	status, data = doJSON(t, "GET", "/api/me", "garbage.token.here", "", nil)
	if status != 401 {
		t.Fatalf("garbage token: status %d body %s", status, data)
	}
}

func TestRefreshRotationAndLogout(t *testing.T) {
	truncate(t)
	resp := registerOwner(t, "rot")

	status, data := doJSON(t, "POST", "/api/auth/refresh", "", "",
		map[string]string{"refresh_token": resp.RefreshToken})
	if status != 200 {
		t.Fatalf("refresh: status %d body %s", status, data)
	}
	var pair struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	mustUnmarshal(t, data, &pair)
	if pair.AccessToken == "" || pair.RefreshToken == "" || pair.RefreshToken == resp.RefreshToken {
		t.Fatalf("refresh pair = %+v", pair)
	}

	status, data = doJSON(t, "POST", "/api/auth/refresh", "", "",
		map[string]string{"refresh_token": resp.RefreshToken})
	if status != 401 {
		t.Fatalf("old refresh must be rotated out: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "POST", "/api/auth/logout", "", "",
		map[string]string{"refresh_token": pair.RefreshToken})
	if status != 204 {
		t.Fatalf("logout: status %d", status)
	}

	status, data = doJSON(t, "POST", "/api/auth/refresh", "", "",
		map[string]string{"refresh_token": pair.RefreshToken})
	if status != 401 {
		t.Fatalf("refresh after logout: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "POST", "/api/auth/logout", "", "",
		map[string]string{"refresh_token": pair.RefreshToken})
	if status != 204 {
		t.Fatalf("logout must be idempotent: status %d", status)
	}
}
