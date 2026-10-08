package itest

import (
	"testing"

	"garage-backend/internal/store"
)

func TestListAndRevokePendingInvites(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "invlist")
	gid := owner.Memberships[0].GarageID
	url := "/api/garages/" + gid + "/invites"

	status, data := doJSON(t, "POST", url, owner.AccessToken, gid, map[string]any{
		"email": "mech@example.com", "role": "staff", "permissions": []string{"jobcards.manage"},
	})
	if status != 201 {
		t.Fatalf("create invite: %d %s", status, data)
	}
	var created store.Invite
	mustUnmarshal(t, data, &created)

	status, data = doJSON(t, "GET", url, owner.AccessToken, gid, nil)
	if status != 200 {
		t.Fatalf("list: %d %s", status, data)
	}
	var list struct {
		Items []store.Invite `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 || list.Items[0].Email != "mech@example.com" ||
		len(list.Items[0].Permissions) != 1 || list.Items[0].Permissions[0] != "jobcards.manage" {
		t.Fatalf("pending invites = %+v", list.Items)
	}

	if status, data := doJSON(t, "DELETE", url+"/"+created.ID, owner.AccessToken, gid, nil); status != 204 {
		t.Fatalf("revoke: %d %s", status, data)
	}
	_, data = doJSON(t, "GET", url, owner.AccessToken, gid, nil)
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("revoked invite still listed: %+v", list.Items)
	}

	// Staff without staff.manage cannot list invites.
	staff := createStaffSession(t, owner, gid, "invlist", []string{"jobcards.manage"})
	if status, _ := doJSON(t, "GET", url, staff.AccessToken, gid, nil); status != 403 {
		t.Fatalf("staff list: %d, want 403", status)
	}
}
