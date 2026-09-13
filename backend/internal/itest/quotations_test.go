package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func quotationBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"quotationNumber": number, "customerId": customerID, "vehicleId": vehicleID,
		"kmReading": 15000, "overallDiscount": 100.0, "taxPercent": 18.0, "validityDays": 15,
		"items": []map[string]any{
			{"name": "Clutch plate", "category": "sparePart", "unitPrice": 2500.0, "quantity": 1.0},
		},
	}
}

func createQuotation(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Quotation) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/quotations", token, garageID, body)
	var q models.Quotation
	if status == 201 {
		mustUnmarshal(t, data, &q)
	}
	return status, data, q
}

func TestQuotationCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "q1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("QCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	// validUntil omitted → server fills today + validityDays.
	status, data, q := createQuotation(t, owner.AccessToken, garageID, quotationBody("EST-1001", customer.ID, vehicle.ID))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if q.ValidUntil.IsZero() || len(q.Items) != 1 || q.Items[0].ID == "" {
		t.Fatalf("create lost defaults: %+v", q)
	}
	_, _, _ = createQuotation(t, owner.AccessToken, garageID, quotationBody("EST-1002", customer.ID, vehicle.ID))
	status, data = doJSON(t, "GET", "/api/quotations", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Quotation `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].QuotationNumber != "EST-1002" {
		t.Fatalf("list must be newest first: %+v", list.Items)
	}

	q.OverallDiscount = 250
	q.Items = []models.MaintenanceItem{
		{Name: "Clutch plate", Category: "sparePart", UnitPrice: 2500, Quantity: 1, Unit: "Pcs"},
		{Name: "Fitting", Category: "labour", UnitPrice: 400, Quantity: 1, Unit: "Job", IsLabour: true},
	}
	status, data = doJSON(t, "PUT", "/api/quotations/"+q.ID, owner.AccessToken, garageID, q)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Quotation
	mustUnmarshal(t, data, &updated)
	if updated.OverallDiscount != 250 || len(updated.Items) != 2 || updated.Items[1].ID == "" {
		t.Fatalf("update lost data: %+v", updated)
	}
}

func TestQuotationConversionGuard(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "q2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("GuardCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	_, _, q := createQuotation(t, owner.AccessToken, garageID, quotationBody("EST-2001", customer.ID, vehicle.ID))

	status, data := doJSON(t, "POST", "/api/quotations/"+q.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "converted"})
	if status != 422 {
		t.Fatalf("draft→converted: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" ||
		message != "quotation can only be converted from approved" {
		t.Fatalf("error = %s / %s", code, message)
	}
	status, _ = doJSON(t, "POST", "/api/quotations/"+q.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "approved"})
	if status != 200 {
		t.Fatalf("draft→approved: status %d", status)
	}
	status, _ = doJSON(t, "POST", "/api/quotations/"+q.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "converted"})
	if status != 200 {
		t.Fatalf("approved→converted: status %d", status)
	}
}

func TestQuotationValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "q3a")
	b := registerOwner(t, "q3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("AQ"))
	aVehicle := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)
	_, _, bCustomer := createCustomer(t, b.AccessToken, bGarage, customerBody("BQ"))
	bVehicle := createVehicleFor(t, b.AccessToken, bGarage, bCustomer.ID)

	body := quotationBody("EST-3001", aCustomer.ID, aVehicle.ID)
	body["status"] = "draft"
	body["validityDays"] = 0
	status, _, _ := createQuotation(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("validityDays 0: %d", status)
	}
	status, _, _ = createQuotation(t, a.AccessToken, aGarage, quotationBody("EST-3002", bCustomer.ID, aVehicle.ID))
	if status != 404 {
		t.Fatalf("foreign customer: %d", status)
	}

	_, _, mine := createQuotation(t, a.AccessToken, aGarage, quotationBody("EST-3003", aCustomer.ID, aVehicle.ID))
	// B reusing A's number is fine (UNIQUE is per-garage).
	status, _, _ = createQuotation(t, b.AccessToken, bGarage, quotationBody("EST-3003", bCustomer.ID, bVehicle.ID))
	if status != 201 {
		t.Fatalf("B same number: %d", status)
	}
	status, _ = doJSON(t, "PUT", "/api/quotations/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's quotation: %d", status)
	}
}
