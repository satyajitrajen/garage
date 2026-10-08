package itest

import (
	"testing"

	"garage-backend/internal/models"
)

// Brake pads 1800 @18% + tyre 4400 @28%, discount 620 (10% of gross):
// taxable 5580, tax (324+1232)*0.9 = 1400.4, grand 6980.4.
func perItemInvoiceBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"invoiceNumber": number, "customerId": customerID, "vehicleId": vehicleID,
		"kmReading": 32000, "discountAmount": 620.0, "taxPercent": 18.0, "perItemTax": true,
		"items": []map[string]any{
			{"name": "Brake pads", "category": "sparePart", "unitPrice": 1800.0, "quantity": 1.0, "taxPercent": 18.0},
			{"name": "Tyre", "category": "tyresBattery", "unitPrice": 4400.0, "quantity": 1.0, "taxPercent": 28.0},
		},
	}
}

func TestPerItemTaxInvoicePayments(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pit1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("PitCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	status, data, inv := createInvoice(t, owner.AccessToken, garageID,
		perItemInvoiceBody("INV-PIT1", customer.ID, vehicle.ID))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if !inv.PerItemTax {
		t.Fatalf("perItemTax not persisted: %+v", inv)
	}
	pay := func(amount float64) (int, []byte) {
		return doJSON(t, "POST", "/api/invoices/"+inv.ID+"/payments", owner.AccessToken, garageID,
			map[string]any{"amount": amount, "mode": "cash"})
	}
	// The single-rate formula would cap the due at 5580*1.18 = 6584.4.
	if status, data := pay(6980.5); status != 422 {
		t.Fatalf("overpay must fail: %d %s", status, data)
	}
	if status, data := pay(6980.4); status != 201 {
		t.Fatalf("exact per-item due must succeed: %d %s", status, data)
	}
}

func TestLegacyInvoiceKeepsDocumentRate(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pit2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("LegCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	body := perItemInvoiceBody("INV-LEG1", customer.ID, vehicle.ID)
	delete(body, "perItemTax")
	_, _, inv := createInvoice(t, owner.AccessToken, garageID, body)
	if inv.PerItemTax {
		t.Fatalf("missing perItemTax must default to false")
	}
	// Legacy math: 5580 * 1.18 = 6584.4.
	status, data := doJSON(t, "POST", "/api/invoices/"+inv.ID+"/payments", owner.AccessToken, garageID,
		map[string]any{"amount": 6584.5, "mode": "cash"})
	if status != 422 {
		t.Fatalf("legacy overpay must fail: %d %s", status, data)
	}
}

func TestQuotationPerItemTaxRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pit3")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("QPitCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	body := quotationBody("EST-PIT1", customer.ID, vehicle.ID)
	body["perItemTax"] = true
	status, data, q := createQuotation(t, owner.AccessToken, garageID, body)
	if status != 201 || !q.PerItemTax {
		t.Fatalf("create: %d %s", status, data)
	}
	status, data = doJSON(t, "GET", "/api/quotations", owner.AccessToken, garageID, nil)
	var list struct {
		Items []models.Quotation `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if status != 200 || len(list.Items) != 1 || !list.Items[0].PerItemTax {
		t.Fatalf("list lost perItemTax: %d %+v", status, list.Items)
	}
}
