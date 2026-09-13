package itest

import (
	"testing"
	"time"

	"garage-backend/internal/models"
)

func invoiceBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"invoiceNumber": number, "customerId": customerID, "vehicleId": vehicleID,
		"kmReading": 32000, "discountAmount": 100.0, "taxPercent": 18.0,
		"items": []map[string]any{
			{"name": "Brake pads", "category": "sparePart", "unitPrice": 1800.0, "quantity": 1.0},
		},
	}
}

func createInvoice(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Invoice) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/invoices", token, garageID, body)
	var inv models.Invoice
	if status == 201 {
		mustUnmarshal(t, data, &inv)
	}
	return status, data, inv
}

func TestInvoiceCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "i1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("ICust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	status, data, inv := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-1001", customer.ID, vehicle.ID))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if len(inv.Items) != 1 || inv.Items[0].ID == "" || inv.Payments == nil || len(inv.Payments) != 0 {
		t.Fatalf("create embeds: %+v", inv)
	}

	// PUT replaces items; cancelledAt omitted stays nil.
	inv.DiscountAmount = 200
	inv.Items = append(inv.Items, models.MaintenanceItem{
		Name: "Labour", Category: "labour", UnitPrice: 500, Quantity: 1, Unit: "Job", IsLabour: true})
	status, data = doJSON(t, "PUT", "/api/invoices/"+inv.ID, owner.AccessToken, garageID, inv)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Invoice
	mustUnmarshal(t, data, &updated)
	if updated.DiscountAmount != 200 || len(updated.Items) != 2 || len(updated.Payments) != 0 {
		t.Fatalf("update lost data: %+v", updated)
	}

	// List is newest first.
	_, _, _ = createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-1002", customer.ID, vehicle.ID))
	status, data = doJSON(t, "GET", "/api/invoices", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Invoice `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].InvoiceNumber != "INV-1002" {
		t.Fatalf("list order: %+v", list.Items)
	}
}

func TestInvoiceCancelRules(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "i2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("CancelCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	// Unpaid invoice: cancel endpoint works; second cancel is 422.
	_, _, unpaid := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-2001", customer.ID, vehicle.ID))
	status, data := doJSON(t, "POST", "/api/invoices/"+unpaid.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("cancel: status %d body %s", status, data)
	}
	var cancelled models.Invoice
	mustUnmarshal(t, data, &cancelled)
	if cancelled.CancelledAt == nil {
		t.Fatalf("cancel must stamp cancelledAt: %+v", cancelled)
	}
	status, data = doJSON(t, "POST", "/api/invoices/"+unpaid.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 422 {
		t.Fatalf("double cancel: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" || message != "invoice is already cancelled" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Paid invoice blocks cancel via BOTH paths.
	_, _, paid := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-2002", customer.ID, vehicle.ID))
	seedPayment(t, paid.ID, 500)
	status, data = doJSON(t, "POST", "/api/invoices/"+paid.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 422 {
		t.Fatalf("paid cancel: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" ||
		message != "invoice has payments and cannot be cancelled" {
		t.Fatalf("error = %s / %s", code, message)
	}
	// PUT with cancelledAt set is the provider's cancel path — same guard.
	paid.CancelledAt = &time.Time{}
	status, data = doJSON(t, "PUT", "/api/invoices/"+paid.ID, owner.AccessToken, garageID, paid)
	if status != 422 {
		t.Fatalf("PUT cancel on paid: status %d body %s", status, data)
	}
}

func TestInvoiceValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "i3a")
	b := registerOwner(t, "i3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("AI"))
	aVehicle := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)
	_, _, aJob := createJobCard(t, a.AccessToken, aGarage,
		jobCardBody("JC-I1", aCustomer.ID, aVehicle.ID))

	// Empty number → 400.
	body := invoiceBody("", aCustomer.ID, aVehicle.ID)
	status, _, _ := createInvoice(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("empty number: %d", status)
	}
	// Malformed jobCardId → 400.
	body = invoiceBody("INV-3001", aCustomer.ID, aVehicle.ID)
	body["jobCardId"] = "nope"
	status, _, _ = createInvoice(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("malformed jobCardId: %d", status)
	}
	// Another garage's job card → 404.
	body = invoiceBody("INV-3002", aCustomer.ID, aVehicle.ID)
	body["jobCardId"] = "11111111-1111-1111-1111-111111111111"
	status, _, _ = createInvoice(t, a.AccessToken, aGarage, body)
	if status != 404 {
		t.Fatalf("unknown jobCardId: %d", status)
	}
	// Valid jobCardId links and returns.
	body = invoiceBody("INV-3003", aCustomer.ID, aVehicle.ID)
	body["jobCardId"] = aJob.ID
	status, _, linked := createInvoice(t, a.AccessToken, aGarage, body)
	if status != 201 || linked.JobCardID == nil || *linked.JobCardID != aJob.ID {
		t.Fatalf("linked invoice: status %d jobCardId %v", status, linked.JobCardID)
	}

	// Tenancy: B sees nothing of A's and cannot PUT A's invoice.
	_, _, mine := createInvoice(t, a.AccessToken, aGarage, invoiceBody("INV-3004", aCustomer.ID, aVehicle.ID))
	status, data := doJSON(t, "GET", "/api/invoices", b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("B list: status %d", status)
	}
	var list struct {
		Items []models.Invoice `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("B sees A's invoices: %+v", list.Items)
	}
	mine.DiscountAmount = 1
	status, _ = doJSON(t, "PUT", "/api/invoices/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's invoice: %d", status)
	}
}
