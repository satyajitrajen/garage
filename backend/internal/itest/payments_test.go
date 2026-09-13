package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestRecordPayment(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pay1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("PayCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	// invoiceBody: item 1800, discount 100 → taxable 1700, +18% → grand 2006.
	_, _, inv := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-P1", customer.ID, vehicle.ID))
	pay := func(amount any, mode string) (int, []byte) {
		return doJSON(t, "POST", "/api/invoices/"+inv.ID+"/payments", owner.AccessToken, garageID,
			map[string]any{"amount": amount, "mode": mode})
	}

	status, _ := pay(0, "cash")
	if status != 422 {
		t.Fatalf("zero amount: %d", status)
	}
	status, data := pay(100, "bitcoin")
	if status != 400 {
		t.Fatalf("bad mode: %d", status)
	}
	if code, message := decodeError(t, data); code != "invalid_request" {
		t.Fatalf("code = %s / %s", code, message)
	}
	status, data = pay(2007, "cash")
	if status != 422 {
		t.Fatalf("overpay: %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" || message != "payment exceeds balance due" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Exactly balanceDue + 0.01 is accepted (mirrors the Dart bound).
	status, data = pay(2006.01, "upi")
	if status != 201 {
		t.Fatalf("full pay: status %d body %s", status, data)
	}
	var p models.Payment
	mustUnmarshal(t, data, &p)
	if p.ID == "" || p.InvoiceID != inv.ID || p.Mode != "upi" || p.PaymentDate.IsZero() {
		t.Fatalf("payment = %+v", p)
	}

	// Balance is now zero → another rupee is rejected.
	status, _ = pay(1, "cash")
	if status != 422 {
		t.Fatalf("post-settlement payment: %d", status)
	}

	// Cancelled invoices take no payments.
	_, _, inv2 := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-P2", customer.ID, vehicle.ID))
	status, _ = doJSON(t, "POST", "/api/invoices/"+inv2.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("cancel inv2: %d", status)
	}
	status, data = doJSON(t, "POST", "/api/invoices/"+inv2.ID+"/payments", owner.AccessToken, garageID,
		map[string]any{"amount": 10, "mode": "cash"})
	if status != 422 {
		t.Fatalf("payment on cancelled: %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" || message != "invoice is cancelled" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Unknown invoice → 404.
	status, _ = doJSON(t, "POST", "/api/invoices/11111111-1111-1111-1111-111111111111/payments",
		owner.AccessToken, garageID, map[string]any{"amount": 5, "mode": "cash"})
	if status != 404 {
		t.Fatalf("unknown invoice: %d", status)
	}
}
