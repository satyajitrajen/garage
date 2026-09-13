package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func createVehicleFor(t *testing.T, token, garageID, customerID string) models.Vehicle {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/vehicles", token, garageID, map[string]any{
		"customerId": customerID, "registrationNumber": "MH 12 AB 1234",
		"make": "Maruti Suzuki", "model": "Swift Dzire", "variant": "VXI",
		"year": 2021, "fuelType": "petrol", "currentKm": 45200,
		"lastServiceDate": "2026-08-01",
	})
	if status != 201 {
		t.Fatalf("create vehicle: status %d body %s", status, data)
	}
	var v models.Vehicle
	mustUnmarshal(t, data, &v)
	return v
}

func TestVehicleCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "v1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("vown"))

	v := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	if v.ID == "" || v.FuelType != "petrol" || v.LastServiceDate == nil || *v.LastServiceDate != "2026-08-01" {
		t.Fatalf("vehicle = %+v", v)
	}

	status, data := doJSON(t, "GET", "/api/vehicles", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Vehicle `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 || list.Items[0].ID != v.ID {
		t.Fatalf("items = %+v", list.Items)
	}

	v.CurrentKm = 46000
	status, data = doJSON(t, "PUT", "/api/vehicles/"+v.ID, owner.AccessToken, garageID, v)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Vehicle
	mustUnmarshal(t, data, &updated)
	if updated.CurrentKm != 46000 {
		t.Fatalf("update lost km: %+v", updated)
	}

	status, _ = doJSON(t, "DELETE", "/api/vehicles/"+v.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete: status %d", status)
	}
}

func TestVehicleValidation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "v2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("vval"))

	base := map[string]any{
		"customerId": customer.ID, "registrationNumber": "MH 01 XY 0001",
		"make": "Hyundai", "model": "Creta", "fuelType": "diesel",
	}
	bad := []map[string]any{
		{"registrationNumber": ""},
		{"customerId": "not-a-uuid"},
		{"fuelType": "kerosene"},
		{"lastServiceDate": "01-08-2026"},
		{"lastServiceDate": ""},
		{"currentKm": -5},
	}
	for i, patch := range bad {
		body := map[string]any{}
		for k, val := range base {
			body[k] = val
		}
		for k, val := range patch {
			body[k] = val
		}
		status, _ := doJSON(t, "POST", "/api/vehicles", owner.AccessToken, garageID, body)
		if status != 400 {
			t.Fatalf("bad body %d: status %d, want 400", i, status)
		}
	}

	// Unknown customer (well-formed uuid) → 404.
	status, _ := doJSON(t, "POST", "/api/vehicles", owner.AccessToken, garageID, map[string]any{
		"customerId":         "22222222-2222-2222-2222-222222222222",
		"registrationNumber": "MH 01 XY 0005", "make": "M", "model": "C", "fuelType": "petrol",
	})
	if status != 404 {
		t.Fatalf("unknown customer: status %d", status)
	}
}

func TestVehicleDeleteGuardAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "v3a")
	b := registerOwner(t, "v3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("Avown"))
	v := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)

	// Seeded invoice history blocks vehicle deletion.
	seedInvoice(t, aGarage, aCustomer.ID, "INV-V-1", 500, 0, 0, 0, false)
	status, data := doJSON(t, "DELETE", "/api/vehicles/"+v.ID, a.AccessToken, aGarage, nil)
	if status != 409 {
		t.Fatalf("delete with history: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "conflict" || message != "vehicle has job cards or invoices" {
		t.Fatalf("error = %s / %s", code, message)
	}

	status, _ = doJSON(t, "PUT", "/api/vehicles/"+v.ID, b.AccessToken, bGarage, v)
	if status != 404 {
		t.Fatalf("B update A's vehicle: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/vehicles/"+v.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's vehicle: status %d", status)
	}
}
