package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func staffBody(name string) map[string]any {
	return map[string]any{
		"name": name, "role": "headMechanic", "phone": "9800000001",
		"monthlySalary": 22000.0, "joiningDate": "2024-03-15", "isActive": true,
	}
}

func createStaffMember(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Staff) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/staff", token, garageID, body)
	var st models.Staff
	if status == 201 {
		mustUnmarshal(t, data, &st)
	}
	return status, data, st
}

func TestStaffCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "s1")
	garageID := owner.Memberships[0].GarageID

	status, data, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Ramesh"))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if st.ID == "" || st.JoiningDate != "2024-03-15" || !st.IsActive {
		t.Fatalf("staff = %+v", st)
	}

	st.MonthlySalary = 25000
	status, data = doJSON(t, "PUT", "/api/staff/"+st.ID, owner.AccessToken, garageID, st)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Staff
	mustUnmarshal(t, data, &updated)
	if updated.MonthlySalary != 25000 {
		t.Fatalf("update lost salary: %+v", updated)
	}

	status, _ = doJSON(t, "DELETE", "/api/staff/"+st.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete: status %d", status)
	}
	status, data = doJSON(t, "GET", "/api/staff", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d", status)
	}
	var list struct {
		Items []models.Staff `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("staff not deleted: %+v", list.Items)
	}
}

func TestStaffValidation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "s2")
	garageID := owner.Memberships[0].GarageID

	bad := []map[string]any{
		{"name": "", "role": "headMechanic", "phone": "1", "monthlySalary": 1, "joiningDate": "2024-03-15"},
		{"name": "X", "role": "boss", "phone": "1", "monthlySalary": 1, "joiningDate": "2024-03-15"},
		{"name": "X", "role": "manager", "phone": "1", "monthlySalary": 1, "joiningDate": "15-03-2024"},
	}
	for i, body := range bad {
		status, _ := doJSON(t, "POST", "/api/staff", owner.AccessToken, garageID, body)
		if status != 400 {
			t.Fatalf("bad body %d: status %d, want 400", i, status)
		}
	}
}
