package itest

import (
	"testing"
	"time"

	"garage-backend/internal/models"
)

func jobCardBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"jobCardNumber":        number,
		"customerId":           customerID,
		"vehicleId":            vehicleID,
		"customerComplaints":   []string{"AC not cooling"},
		"kmReading":            32000,
		"promisedDeliveryDate": time.Now().UTC().Add(6 * time.Hour).Format(time.RFC3339),
	}
}

func createJobCard(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.JobCard) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/jobcards", token, garageID, body)
	var jc models.JobCard
	if status == 201 {
		mustUnmarshal(t, data, &jc)
	}
	return status, data, jc
}

func itemBody(name string) map[string]any {
	return map[string]any{
		"name": name, "category": "sparePart", "unitPrice": 1200.0,
		"quantity": 2.0, "unit": "Pcs", "taxPercent": 18.0,
	}
}

func fetchJobCards(t *testing.T, token, garageID string) []models.JobCard {
	t.Helper()
	status, data := doJSON(t, "GET", "/api/jobcards", token, garageID, nil)
	if status != 200 {
		t.Fatalf("list job cards: status %d body %s", status, data)
	}
	var list struct {
		Items []models.JobCard `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	return list.Items
}

func TestJobCardCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "jc1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("JobCustomer"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	// Client-supplied item id must survive; omitted checklist gets the default.
	body := jobCardBody("JC-1001", customer.ID, vehicle.ID)
	body["items"] = []map[string]any{{"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
		"name": "Engine oil", "category": "fluids", "unitPrice": 450.0, "quantity": 1.0}}
	status, data, jc := createJobCard(t, owner.AccessToken, garageID, body)
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if len(jc.Items) != 1 || jc.Items[0].ID != "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" {
		t.Fatalf("items = %+v", jc.Items)
	}
	if len(jc.InspectionChecklist) != 8 || !jc.InspectionChecklist["Engine Oil Level"] {
		t.Fatalf("default checklist not applied: %+v", jc.InspectionChecklist)
	}
	if jc.FuelLevel != "1/2" || jc.CustomerComplaints == nil {
		t.Fatalf("defaults lost: %+v", jc)
	}

	createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-1002", customer.ID, vehicle.ID))
	cards := fetchJobCards(t, owner.AccessToken, garageID)
	if len(cards) != 2 || cards[0].JobCardNumber != "JC-1002" {
		t.Fatalf("list must be newest first: %+v", cards)
	}

	// PUT replaces items wholesale and preserves supplied ids.
	jc.Items = []models.MaintenanceItem{
		{ID: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", Name: "Wiper", Category: "sparePart", UnitPrice: 300, Quantity: 1, Unit: "Pcs"},
		{Name: "Labour", Category: "labour", UnitPrice: 500, Quantity: 2, Unit: "Hours", IsLabour: true},
	}
	jc.KmReading = 32500
	status, data = doJSON(t, "PUT", "/api/jobcards/"+jc.ID, owner.AccessToken, garageID, jc)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.JobCard
	mustUnmarshal(t, data, &updated)
	if updated.KmReading != 32500 || len(updated.Items) != 2 ||
		updated.Items[0].ID != "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" ||
		updated.Items[1].ID == "" {
		t.Fatalf("update lost items/km: %+v", updated)
	}

	// Duplicate number in the SAME garage is 409.
	status, data, _ = createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-1001", customer.ID, vehicle.ID))
	if status != 409 {
		t.Fatalf("duplicate number: status %d body %s", status, data)
	}
}

func TestJobCardStatusTransitions(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "jc2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("StatusCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	_, _, jc := createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-2001", customer.ID, vehicle.ID))

	post := func(status string) (int, []byte, models.JobCard) {
		st, data := doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/status", owner.AccessToken, garageID,
			map[string]any{"status": status})
		var out models.JobCard
		if st == 200 {
			mustUnmarshal(t, data, &out)
		}
		return st, data, out
	}

	st, _, out := post("inProgress")
	if st != 200 || out.Status != "inProgress" || out.CompletedAt != nil {
		t.Fatalf("inProgress: st=%d out=%+v", st, out)
	}
	st, _, out = post("delivered")
	if st != 200 || out.CompletedAt == nil {
		t.Fatalf("delivered must stamp completedAt: st=%d out=%+v", st, out)
	}
	st, _, out = post("cancelled")
	if st != 200 || out.CompletedAt == nil {
		t.Fatalf("cancelled must keep completedAt: st=%d out=%+v", st, out)
	}
	st, _, out = post("received")
	if st != 200 || out.CompletedAt != nil {
		t.Fatalf("back to received must clear completedAt: st=%d out=%+v", st, out)
	}
	st, _ = doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "flying"})
	if st != 400 {
		t.Fatalf("invalid status: st=%d", st)
	}
}

func TestJobCardItemEndpoints(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "jc3")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("ItemCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	_, _, jc := createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-3001", customer.ID, vehicle.ID))

	// POST without id → server generates.
	item := itemBody("Engine oil")
	item["id"] = ""
	status, data := doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/items", owner.AccessToken, garageID, item)
	if status != 200 {
		t.Fatalf("upsert new: status %d body %s", status, data)
	}
	var saved models.MaintenanceItem
	mustUnmarshal(t, data, &saved)
	if saved.ID == "" {
		t.Fatalf("server must generate item id: %+v", saved)
	}

	// Upsert by the same id updates in place.
	item["id"] = saved.ID
	item["name"] = "Engine oil 5W-40"
	status, _ = doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/items", owner.AccessToken, garageID, item)
	if status != 200 {
		t.Fatalf("upsert existing: status %d", status)
	}
	cards := fetchJobCards(t, owner.AccessToken, garageID)
	if len(cards) != 1 || len(cards[0].Items) != 1 || cards[0].Items[0].Name != "Engine oil 5W-40" {
		t.Fatalf("upsert-by-id produced: %+v", cards)
	}

	// The same item id under a second job card of the same garage misses the
	// job-card-scoped UPDATE and hits the PK on INSERT → 409.
	_, _, jc2 := createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-3002", customer.ID, vehicle.ID))
	status, _ = doJSON(t, "POST", "/api/jobcards/"+jc2.ID+"/items", owner.AccessToken, garageID, item)
	if status != 409 {
		t.Fatalf("duplicate item id: status %d", status)
	}

	// Delete → 204; deleting again → 404.
	status, _ = doJSON(t, "DELETE", "/api/jobcards/"+jc.ID+"/items/"+saved.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete item: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/jobcards/"+jc.ID+"/items/"+saved.ID, owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("delete missing item: status %d", status)
	}
	cards = fetchJobCards(t, owner.AccessToken, garageID)
	for _, c := range cards {
		if c.ID == jc.ID && len(c.Items) != 0 {
			t.Fatalf("items after delete: %+v", c.Items)
		}
	}
}

func TestJobCardValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "jc4a")
	b := registerOwner(t, "jc4b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("A"))
	aVehicle := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)
	_, _, bCustomer := createCustomer(t, b.AccessToken, bGarage, customerBody("B"))

	// Unknown status → 400.
	body := jobCardBody("JC-4001", aCustomer.ID, aVehicle.ID)
	body["status"] = "flying"
	status, _, _ := createJobCard(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("bad status: %d", status)
	}
	// Malformed customer id → 400.
	status, _, _ = createJobCard(t, a.AccessToken, aGarage, jobCardBody("JC-4002", "nope", aVehicle.ID))
	if status != 400 {
		t.Fatalf("malformed customer id: %d", status)
	}
	// Another garage's customer → 404.
	status, _, _ = createJobCard(t, a.AccessToken, aGarage, jobCardBody("JC-4003", bCustomer.ID, aVehicle.ID))
	if status != 404 {
		t.Fatalf("foreign customer: %d", status)
	}
	// A's JC-4001 lands so the reuse below is a real per-garage duplicate.
	status, _, _ = createJobCard(t, a.AccessToken, aGarage, jobCardBody("JC-4001", aCustomer.ID, aVehicle.ID))
	if status != 201 {
		t.Fatalf("A create JC-4001: %d", status)
	}
	// Duplicate numbers are per-garage: B may reuse A's number.
	bVehicle := createVehicleFor(t, b.AccessToken, bGarage, bCustomer.ID)
	status, _, jcB := createJobCard(t, b.AccessToken, bGarage, jobCardBody("JC-4001", bCustomer.ID, bVehicle.ID))
	if status != 201 {
		t.Fatalf("B reusing A's number must succeed: %d", status)
	}

	// B sees nothing of A's.
	if cards := fetchJobCards(t, b.AccessToken, bGarage); len(cards) != 1 || cards[0].ID != jcB.ID {
		t.Fatalf("B sees A's job cards: %+v", cards)
	}
	aCard := fetchJobCards(t, a.AccessToken, aGarage)[0]
	aCard.CustomerID = bCustomer.ID
	status, _ = doJSON(t, "PUT", "/api/jobcards/"+aCard.ID, b.AccessToken, bGarage, aCard)
	if status != 404 {
		t.Fatalf("B update A's job card: %d", status)
	}
}
