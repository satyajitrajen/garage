package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestAttendanceUpsertIdempotent(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "a1")
	garageID := owner.Memberships[0].GarageID
	_, _, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Atten"))

	body := func(status string) map[string]any {
		return map[string]any{"staffId": st.ID, "date": "2026-09-10", "status": status}
	}

	status, data := doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, body("present"))
	if status != 200 {
		t.Fatalf("upsert: status %d body %s", status, data)
	}
	var first models.AttendanceRecord
	mustUnmarshal(t, data, &first)
	if first.ID == "" || first.Status != "present" {
		t.Fatalf("record = %+v", first)
	}

	// Same (staff, day) again: same row id, new status — idempotent upsert.
	status, data = doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, body("halfDay"))
	if status != 200 {
		t.Fatalf("second upsert: status %d body %s", status, data)
	}
	var second models.AttendanceRecord
	mustUnmarshal(t, data, &second)
	if second.ID != first.ID || second.Status != "halfDay" {
		t.Fatalf("upsert not idempotent: %+v vs %+v", second, first)
	}

	status, data = doJSON(t, "GET", "/api/attendance", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.AttendanceRecord `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 {
		t.Fatalf("want exactly 1 row, got %d", len(list.Items))
	}
}

func TestAttendanceValidationAndTenancy(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "a2")
	garageID := owner.Memberships[0].GarageID
	_, _, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Atten2"))

	bad := []map[string]any{
		{"staffId": st.ID, "date": "2026-09-10", "status": "sick"},
		{"staffId": st.ID, "date": "10-09-2026", "status": "present"},
		{"staffId": "nope", "date": "2026-09-10", "status": "present"},
	}
	for i, body := range bad {
		status, _ := doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, body)
		if status != 400 {
			t.Fatalf("bad body %d: status %d, want 400", i, status)
		}
	}

	status, _ := doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, map[string]any{
		"staffId": "33333333-3333-3333-3333-333333333333", "date": "2026-09-10", "status": "present",
	})
	if status != 404 {
		t.Fatalf("unknown staff: status %d", status)
	}
}

func TestSalaryAdvanceCreateAndSettle(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "a3")
	garageID := owner.Memberships[0].GarageID
	_, _, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Adv"))

	status, data := doJSON(t, "POST", "/api/salary-advances", owner.AccessToken, garageID, map[string]any{
		"staffId": st.ID, "amount": 3000.0, "date": "2026-09-05", "reason": "Festival",
	})
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	var adv models.SalaryAdvance
	mustUnmarshal(t, data, &adv)
	if adv.ID == "" || adv.IsDeducted {
		t.Fatalf("advance = %+v", adv)
	}
	// Second advance in the same month.
	_, _ = doJSON(t, "POST", "/api/salary-advances", owner.AccessToken, garageID, map[string]any{
		"staffId": st.ID, "amount": 1000.0, "date": "2026-09-20",
	})

	status, data = doJSON(t, "POST", "/api/salary-advances/settle", owner.AccessToken, garageID, map[string]any{
		"staff_id": st.ID, "month": 9, "year": 2026,
	})
	if status != 200 {
		t.Fatalf("settle: status %d body %s", status, data)
	}
	var list struct {
		Items []models.SalaryAdvance `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 {
		t.Fatalf("settle must return the full garage list, got %d", len(list.Items))
	}
	for _, a := range list.Items {
		if !a.IsDeducted {
			t.Fatalf("all rows must be deducted after settle: %+v", list.Items)
		}
	}

	// An advance from another month is untouched by the settle above.
	status, data = doJSON(t, "POST", "/api/salary-advances", owner.AccessToken, garageID, map[string]any{
		"staffId": st.ID, "amount": 500.0, "date": "2026-08-15",
	})
	if status != 201 {
		t.Fatalf("create aug: status %d body %s", status, data)
	}
	var aug models.SalaryAdvance
	mustUnmarshal(t, data, &aug)
	if aug.IsDeducted {
		t.Fatalf("august advance must be untouched: %+v", aug)
	}

	// Invalid month.
	status, _ = doJSON(t, "POST", "/api/salary-advances/settle", owner.AccessToken, garageID, map[string]any{
		"staff_id": st.ID, "month": 13, "year": 2026,
	})
	if status != 400 {
		t.Fatalf("bad month: status %d", status)
	}
}
