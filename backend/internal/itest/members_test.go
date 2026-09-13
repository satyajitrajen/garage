package itest

import (
	"strings"
	"testing"

	"garage-backend/internal/models"
)

func membersURL(garageID string) string { return "/api/garages/" + garageID + "/members" }

func createMember(t *testing.T, owner authResponse, garageID string, body map[string]any) (int, []byte, models.Member) {
	t.Helper()
	status, data := doJSON(t, "POST", membersURL(garageID), owner.AccessToken, garageID, body)
	var member models.Member
	if status == 201 {
		mustUnmarshal(t, data, &member)
	}
	return status, data, member
}

func TestCreateMemberWithDefaults(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "m1")
	garageID := owner.Memberships[0].GarageID

	status, data, member := createMember(t, owner, garageID, map[string]any{
		"name": "Staff One", "email": "staff1@test.dev", "password": "password123",
	})
	if status != 201 {
		t.Fatalf("create member: status %d body %s", status, data)
	}
	if member.Role != "staff" || !member.IsActive || member.Email != "staff1@test.dev" {
		t.Fatalf("member = %+v", member)
	}
	if len(member.Permissions) != 7 {
		t.Fatalf("default staff permissions = %v, want 7 entries", member.Permissions)
	}
	for _, p := range member.Permissions {
		if p == "expenses.manage" || p == "staff.manage" || p == "advances.manage" || p == "settings.manage" {
			t.Fatalf("default staff set must exclude %s", p)
		}
	}

	status, data = doJSON(t, "GET", membersURL(garageID), owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list members: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Member `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].Role != "owner" {
		t.Fatalf("items = %+v", list.Items)
	}

	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff1@test.dev", "password": "password123",
	})
	if status != 200 {
		t.Fatalf("staff login: status %d body %s", status, data)
	}
	var login authResponse
	mustUnmarshal(t, data, &login)
	status, _ = doJSON(t, "GET", "/api/me", login.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("staff me: status %d", status)
	}
}

func TestUpdateMemberEdgeCases(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "edge")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Edge Staff", "email": "edge@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{})
	if status != 200 {
		t.Fatalf("empty patch: status %d body %s", status, data)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"permissions": []string{}})
	if status != 200 {
		t.Fatalf("empty permissions: status %d body %s", status, data)
	}
	var member models.Member
	mustUnmarshal(t, data, &member)
	if len(member.Permissions) != 0 {
		t.Fatalf("permissions must be explicitly empty, got %v", member.Permissions)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/00000000-0000-0000-0000-000000000000",
		owner.AccessToken, garageID, map[string]any{"is_active": false})
	if status != 404 {
		t.Fatalf("unknown member: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "not_found" {
		t.Fatalf("code = %s, want not_found", code)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/not-a-uuid", owner.AccessToken, garageID,
		map[string]any{"is_active": false})
	if status != 404 {
		t.Fatalf("malformed userId: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/not-a-uuid", owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("malformed userId delete: status %d", status)
	}
}

func TestMembersRequirePermission(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "perm")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-perm@test.dev", "password": "password123",
	})

	_, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": staff.Email, "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data := doJSON(t, "GET", membersURL(garageID), login.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff listing members: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "staff.manage") {
		t.Fatalf("message = %s", message)
	}
}

func TestCreateMemberPermissionValidation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pv")
	garageID := owner.Memberships[0].GarageID

	status, data, member := createMember(t, owner, garageID, map[string]any{
		"name": "Parts Staff", "email": "parts@test.dev", "password": "password123",
		"permissions": []string{"customers.manage", "expenses.manage"},
	})
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if len(member.Permissions) != 2 {
		t.Fatalf("permissions = %v", member.Permissions)
	}

	status, data, _ = createMember(t, owner, garageID, map[string]any{
		"name": "Bad", "email": "bad@test.dev", "password": "password123",
		"permissions": []string{"bogus.key"},
	})
	if status != 400 {
		t.Fatalf("unknown permission: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "bogus.key") {
		t.Fatalf("message = %s", message)
	}
}

func TestCreateMemberExistingUser(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "a")
	b := registerOwner(t, "b")
	bGarage := b.Memberships[0].GarageID

	// Garage B's owner adds garage A's owner (existing user, password ignored),
	// granting staff.manage so the multi-garage token can be exercised below.
	status, data, member := createMember(t, b, bGarage, map[string]any{
		"name": "Owner A", "email": "owner-a@test.dev", "password": "ignored-pw",
		"permissions": []string{"staff.manage"},
	})
	if status != 201 {
		t.Fatalf("existing-user member: status %d body %s", status, data)
	}
	if member.UserID != a.User.ID {
		t.Fatalf("must reuse the existing user, got %+v", member)
	}

	status, data, _ = createMember(t, b, bGarage, map[string]any{
		"name": "Owner A", "email": "owner-a@test.dev",
	})
	if status != 409 {
		t.Fatalf("double membership: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "already a member") {
		t.Fatalf("message = %s", message)
	}

	// Multi-garage: A's token can now resolve B's garage too.
	status, _ = doJSON(t, "GET", membersURL(bGarage), a.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("A should be a member of B's garage now: status %d", status)
	}
}

func TestUpdateMember(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "up")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-up@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"permissions": []string{"customers.manage"}})
	if status != 200 {
		t.Fatalf("patch permissions: status %d body %s", status, data)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"password": "newpassword1"})
	if status != 200 {
		t.Fatalf("patch password: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-up@test.dev", "password": "password123",
	})
	if status != 401 {
		t.Fatalf("old password must stop working, got %d", status)
	}
	status, _ = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-up@test.dev", "password": "newpassword1",
	})
	if status != 200 {
		t.Fatalf("new password must work, got %d", status)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"is_active": false})
	if status != 200 {
		t.Fatalf("deactivate: status %d body %s", status, data)
	}
	status, data = doJSON(t, "GET", membersURL(garageID), owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list after deactivate: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Member `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	for _, m := range list.Items {
		if m.UserID == staff.UserID && m.IsActive {
			t.Fatal("is_active=false must persist")
		}
	}
}

func TestDeactivatedMemberBlocked(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "deact")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-deact@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"is_active": false})
	if status != 200 {
		t.Fatalf("deactivate: status %d body %s", status, data)
	}

	_, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-deact@test.dev", "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data = doJSON(t, "GET", membersURL(garageID), login.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("deactivated member: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "membership is deactivated") {
		t.Fatalf("message = %s", message)
	}
}

func TestUpdateMemberPasswordOwnerOnly(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pw")
	garageID := owner.Memberships[0].GarageID
	_, _, _ = createMember(t, owner, garageID, map[string]any{
		"name": "Manager", "email": "manager@test.dev", "password": "password123",
		"permissions": []string{"staff.manage"},
	})
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-pw@test.dev", "password": "password123",
	})

	_, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "manager@test.dev", "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, login.AccessToken, garageID,
		map[string]any{"password": "hacked-pw1"})
	if status != 403 {
		t.Fatalf("staff password reset: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "owner-only") {
		t.Fatalf("message = %s", message)
	}

	status, _ = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, login.AccessToken, garageID,
		map[string]any{"permissions": []string{"customers.manage"}})
	if status != 200 {
		t.Fatalf("staff with staff.manage may change permissions, got %d", status)
	}
}

func TestUpdateOwnerRejected(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "own")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+owner.User.ID, owner.AccessToken, garageID,
		map[string]any{"permissions": []string{"customers.manage"}})
	if status != 422 {
		t.Fatalf("patch owner: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "cannot modify the owner") {
		t.Fatalf("message = %s", message)
	}
}

func TestDeleteMember(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "del")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-del@test.dev", "password": "password123",
	})
	_, _, _ = createMember(t, owner, garageID, map[string]any{
		"name": "Manager", "email": "manager-del@test.dev", "password": "password123",
		"permissions": []string{"staff.manage"},
	})

	_, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "manager-del@test.dev", "password": "password123",
	})
	var managerLogin authResponse
	mustUnmarshal(t, data, &managerLogin)

	status, data := doJSON(t, "DELETE", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("owner delete: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/"+owner.User.ID, managerLogin.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff delete must be owner-only, got %d", status)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/"+owner.User.ID, owner.AccessToken, garageID, nil)
	if status != 422 {
		t.Fatalf("delete owner: status %d, want 422", status)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/00000000-0000-0000-0000-000000000000", owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("delete unknown: status %d, want 404", status)
	}
}

func TestGarageIsolation(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "a")
	b := registerOwner(t, "b")
	aGarage := a.Memberships[0].GarageID

	status, data := doJSON(t, "GET", "/api/garages/"+aGarage+"/members", b.AccessToken, aGarage, nil)
	if status != 403 {
		t.Fatalf("cross-garage access: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "forbidden" {
		t.Fatalf("code = %s, want forbidden", code)
	}

	status, data = doJSON(t, "GET", "/api/garages/"+aGarage+"/members", a.AccessToken, "", nil)
	// RequireGarage falls back to the {garageId} URL segment when the header
	// is absent (pinned by auth's middleware unit test), so this must succeed.
	if status != 200 {
		t.Fatalf("url-param garage fallback: status %d body %s", status, data)
	}
}
