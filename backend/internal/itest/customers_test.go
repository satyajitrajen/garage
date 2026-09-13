package itest

import (
	"testing"
	"time"

	"garage-backend/internal/models"
)

func createCustomer(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Customer) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/customers", token, garageID, body)
	var c models.Customer
	if status == 201 {
		mustUnmarshal(t, data, &c)
	}
	return status, data, c
}

func customerBody(name string) map[string]any {
	return map[string]any{
		"name": name, "phone": "9876543210",
		"email": name + "@example.com", "address": "12 MG Road",
	}
}

// seedInvoice inserts an invoice + one item (+ optional payment) directly so
// dues-gated delete can be tested without the invoice endpoints. gross is
// the item taxable amount (quantity 1, no item discount/tax).
func seedInvoice(t *testing.T, garageID, customerID, number string, gross, discount, taxPercent, paid float64, cancelled bool) {
	t.Helper()
	var vehicleID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO vehicles (garage_id, customer_id, registration_number, make, model, fuel_type)
		 VALUES ($1,$2,'SEED-00','Seed','Seed','petrol') RETURNING id`,
		garageID, customerID).Scan(&vehicleID); err != nil {
		t.Fatalf("seed vehicle: %v", err)
	}
	var cancelledArg any
	if cancelled {
		cancelledArg = time.Now().UTC()
	}
	var invoiceID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO invoices (garage_id, invoice_number, customer_id, vehicle_id, km_reading,
		                       discount_amount, tax_percent, invoice_date, cancelled_at)
		 VALUES ($1,$2,$3,$4,0,$5,$6,now(),$7) RETURNING id`,
		garageID, number, customerID, vehicleID, discount, taxPercent, cancelledArg).Scan(&invoiceID); err != nil {
		t.Fatalf("seed invoice: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO invoice_items (invoice_id, name, category, unit_price, quantity, unit)
		 VALUES ($1,'Seed item','sparePart',$2,1,'Pcs')`, invoiceID, gross); err != nil {
		t.Fatalf("seed invoice item: %v", err)
	}
	if paid > 0 {
		if _, err := pool.Exec(ctx,
			`INSERT INTO payments (invoice_id, amount, mode, payment_date)
			 VALUES ($1,$2,'cash',now())`, invoiceID, paid); err != nil {
			t.Fatalf("seed payment: %v", err)
		}
	}
}

func TestCustomerCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "c1")
	garageID := owner.Memberships[0].GarageID

	status, data, first := createCustomer(t, owner.AccessToken, garageID, customerBody("Ashok"))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if first.ID == "" || first.Name != "Ashok" || first.CreatedAt.IsZero() {
		t.Fatalf("customer = %+v", first)
	}
	_, _, _ = createCustomer(t, owner.AccessToken, garageID, customerBody("Bhavna"))

	status, data = doJSON(t, "GET", "/api/customers", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Customer `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].Name != "Bhavna" {
		t.Fatalf("list must be newest first: %+v", list.Items)
	}

	first.Phone = "9000000001"
	status, data = doJSON(t, "PUT", "/api/customers/"+first.ID, owner.AccessToken, garageID, first)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Customer
	mustUnmarshal(t, data, &updated)
	if updated.Phone != "9000000001" {
		t.Fatalf("update lost phone: %+v", updated)
	}

	status, _ = doJSON(t, "PUT", "/api/customers/"+first.ID, owner.AccessToken, garageID,
		map[string]any{"name": "X"})
	if status != 400 {
		t.Fatalf("update without phone: status %d", status)
	}
}

func TestCustomerDeleteSemantics(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "c2")
	garageID := owner.Memberships[0].GarageID

	// No history: delete succeeds.
	_, _, plain := createCustomer(t, owner.AccessToken, garageID, customerBody("Plain"))
	status, data := doJSON(t, "DELETE", "/api/customers/"+plain.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("plain delete: status %d body %s", status, data)
	}

	// Outstanding dues block (mirrors the mock returning false).
	_, _, debtor := createCustomer(t, owner.AccessToken, garageID, customerBody("Debtor"))
	seedInvoice(t, garageID, debtor.ID, "INV-D-1", 1000, 0, 18, 0, false)
	status, data = doJSON(t, "DELETE", "/api/customers/"+debtor.ID, owner.AccessToken, garageID, nil)
	if status != 409 {
		t.Fatalf("dues delete: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "conflict" || message != "customer has outstanding dues" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Fully paid invoice still blocks (history must stay resolvable).
	_, _, paidUp := createCustomer(t, owner.AccessToken, garageID, customerBody("PaidUp"))
	seedInvoice(t, garageID, paidUp.ID, "INV-P-1", 1000, 0, 0, 1000, false)
	status, data = doJSON(t, "DELETE", "/api/customers/"+paidUp.ID, owner.AccessToken, garageID, nil)
	if status != 409 {
		t.Fatalf("paid-invoice delete: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "conflict" {
		t.Fatalf("code = %s", code)
	}

	// Cancelled invoice is not dues but is still history.
	_, _, cancelled := createCustomer(t, owner.AccessToken, garageID, customerBody("Cancelled"))
	seedInvoice(t, garageID, cancelled.ID, "INV-C-1", 1000, 0, 18, 0, true)
	status, data = doJSON(t, "DELETE", "/api/customers/"+cancelled.ID, owner.AccessToken, garageID, nil)
	if status != 409 {
		t.Fatalf("cancelled-invoice delete: status %d body %s", status, data)
	}

	// Unknown id is 404.
	status, _ = doJSON(t, "DELETE", "/api/customers/11111111-1111-1111-1111-111111111111",
		owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("unknown delete: status %d", status)
	}
}

func TestCustomerTenancyIsolation(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "c3a")
	b := registerOwner(t, "c3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID

	_, _, mine := createCustomer(t, a.AccessToken, aGarage, customerBody("Mine"))

	status, data := doJSON(t, "GET", "/api/customers", b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("list B: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Customer `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("B must not see A's customers: %+v", list.Items)
	}

	mine.Name = "Hacked"
	status, _ = doJSON(t, "PUT", "/api/customers/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's customer: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/customers/"+mine.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's customer: status %d", status)
	}
}

func TestCustomerPermissionGate(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "c4")
	garageID := owner.Memberships[0].GarageID
	staff := createStaffSession(t, owner, garageID, "cperm", []string{"vehicles.manage"})

	status, data := doJSON(t, "GET", "/api/customers", staff.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff without customers.manage: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); message != "missing permission: customers.manage" {
		t.Fatalf("message = %s", message)
	}
}
