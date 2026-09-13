package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func expenseBody(title string) map[string]any {
	return map[string]any{
		"title": title, "category": "consumables", "amount": 350.5,
		"expenseDate": "2026-09-13", "paymentMode": "upi",
	}
}

func createExpense(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Expense) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/expenses", token, garageID, body)
	var e models.Expense
	if status == 201 {
		mustUnmarshal(t, data, &e)
	}
	return status, data, e
}

func TestExpenseCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "e1")
	garageID := owner.Memberships[0].GarageID

	status, data, first := createExpense(t, owner.AccessToken, garageID, expenseBody("Engine flush"))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if first.ID == "" || first.Title != "Engine flush" || first.ExpenseDate != "2026-09-13" ||
		first.PaymentMode != "upi" || first.CreatedAt.IsZero() {
		t.Fatalf("expense = %+v", first)
	}

	_, _, _ = createExpense(t, owner.AccessToken, garageID, expenseBody("Shop rent"))
	status, data = doJSON(t, "GET", "/api/expenses", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Expense `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].Title != "Shop rent" {
		t.Fatalf("list must be newest first: %+v", list.Items)
	}

	first.Amount = 500
	vendor := "AutoCare Supplies"
	first.VendorName = &vendor
	status, data = doJSON(t, "PUT", "/api/expenses/"+first.ID, owner.AccessToken, garageID, first)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Expense
	mustUnmarshal(t, data, &updated)
	if updated.Amount != 500 || updated.VendorName == nil || *updated.VendorName != "AutoCare Supplies" {
		t.Fatalf("update lost data: %+v", updated)
	}

	status, _ = doJSON(t, "DELETE", "/api/expenses/"+first.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete: %d", status)
	}
	status, data = doJSON(t, "GET", "/api/expenses", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list after delete: status %d", status)
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 {
		t.Fatalf("after delete: %+v", list.Items)
	}
}

func TestExpenseValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "e2a")
	b := registerOwner(t, "e2b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID

	bad := expenseBody("Bad category")
	bad["category"] = "bribes"
	status, _, _ := createExpense(t, a.AccessToken, aGarage, bad)
	if status != 400 {
		t.Fatalf("bad category: %d", status)
	}
	bad = expenseBody("Bad mode")
	bad["paymentMode"] = "barter"
	status, _, _ = createExpense(t, a.AccessToken, aGarage, bad)
	if status != 400 {
		t.Fatalf("bad paymentMode: %d", status)
	}
	bad = expenseBody("Bad date")
	bad["expenseDate"] = "13/09/2026"
	status, _, _ = createExpense(t, a.AccessToken, aGarage, bad)
	if status != 400 {
		t.Fatalf("bad expenseDate: %d", status)
	}
	// paymentMode omitted → defaults to cash.
	omitted := expenseBody("Default mode")
	delete(omitted, "paymentMode")
	status, _, e := createExpense(t, a.AccessToken, aGarage, omitted)
	if status != 201 || e.PaymentMode != "cash" {
		t.Fatalf("default mode: status %d expense %+v", status, e)
	}

	_, _, mine := createExpense(t, a.AccessToken, aGarage, expenseBody("Mine"))
	var list struct {
		Items []models.Expense `json:"items"`
	}
	status, data := doJSON(t, "GET", "/api/expenses", b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("B list: status %d", status)
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("B sees A's expenses: %+v", list.Items)
	}
	status, _ = doJSON(t, "PUT", "/api/expenses/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's expense: %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/expenses/"+mine.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's expense: %d", status)
	}
}
