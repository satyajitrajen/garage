package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func settingsURL(garageID string) string { return "/api/garages/" + garageID + "/settings" }

func TestGetSettingsDefaults(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "set")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "GET", settingsURL(garageID), owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("get settings: status %d body %s", status, data)
	}
	var gs models.GarageSettings
	mustUnmarshal(t, data, &gs)
	if gs.GarageID != garageID {
		t.Fatalf("garage_id = %s", gs.GarageID)
	}
	if gs.DefaultTaxPercent != 18 || gs.InvoiceDueDays != 7 || gs.WorkingDaysPerMonth != 26 ||
		gs.PromisedDeliveryHours != 6 || gs.DefaultReceivedBy != "Cashier" {
		t.Fatalf("config defaults = %+v", gs)
	}
	if len(gs.TaxPercentOptions) != 4 || len(gs.QuotationValidityOptions) != 3 {
		t.Fatalf("option lists = %v / %v", gs.TaxPercentOptions, gs.QuotationValidityOptions)
	}
}

func TestPatchSettingsMerges(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "patch")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "PATCH", settingsURL(garageID), owner.AccessToken, garageID,
		map[string]any{"invoice_due_days": 14})
	if status != 200 {
		t.Fatalf("patch due days: status %d body %s", status, data)
	}
	var gs models.GarageSettings
	mustUnmarshal(t, data, &gs)
	if gs.InvoiceDueDays != 14 {
		t.Fatalf("due days = %v", gs.InvoiceDueDays)
	}
	if gs.DefaultTaxPercent != 18 || len(gs.TaxPercentOptions) != 4 {
		t.Fatalf("unpatched fields must be unchanged: %+v", gs)
	}

	status, data = doJSON(t, "PATCH", settingsURL(garageID), owner.AccessToken, garageID,
		map[string]any{"profile": map[string]any{
			"name": "Sharma Motors", "tagline": "Trusted since 1995",
			"address_line": "12 MG Road", "city": "Pune", "phone": "9876543210",
			"email": "sharma@motors.in", "gstin": "27ABCDE1234F1Z5", "upi_id": "sharma@upi",
		}})
	if status != 200 {
		t.Fatalf("patch profile: status %d body %s", status, data)
	}
	mustUnmarshal(t, data, &gs)
	if gs.Profile.Name != "Sharma Motors" || gs.Profile.City != "Pune" || gs.Profile.UPIID != "sharma@upi" {
		t.Fatalf("profile = %+v", gs.Profile)
	}
	if gs.InvoiceDueDays != 14 {
		t.Fatal("profile patch must not touch config fields")
	}

	status, data = doJSON(t, "PATCH", settingsURL(garageID), owner.AccessToken, garageID, map[string]any{})
	if status != 200 {
		t.Fatalf("empty patch: status %d body %s", status, data)
	}
	mustUnmarshal(t, data, &gs)
	if gs.InvoiceDueDays != 14 || gs.Profile.Name != "Sharma Motors" {
		t.Fatalf("empty patch must change nothing: %+v", gs)
	}
}

func TestSettingsPermissionGate(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "gate")
	garageID := owner.Memberships[0].GarageID
	createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-set@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-set@test.dev", "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data = doJSON(t, "GET", settingsURL(garageID), login.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff get settings: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); message != "missing permission: settings.manage" {
		t.Fatalf("message = %s", message)
	}
}

func TestSettingsNonMemberForbidden(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "sga")
	outsider := registerOwner(t, "sgb")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "GET", settingsURL(garageID), outsider.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("non-member get settings: status %d body %s", status, data)
	}
	code, _ := decodeError(t, data)
	if code != "forbidden" {
		t.Fatalf("code = %s", code)
	}

	status, data = doJSON(t, "PATCH", settingsURL(garageID), outsider.AccessToken, garageID,
		map[string]any{"invoice_due_days": 14})
	if status != 403 {
		t.Fatalf("non-member patch settings: status %d body %s", status, data)
	}
}

func TestSettingsPerGarage(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "sgc")
	b := registerOwner(t, "sgd")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID

	status, _ := doJSON(t, "PATCH", settingsURL(aGarage), a.AccessToken, aGarage,
		map[string]any{"invoice_due_days": 14})
	if status != 200 {
		t.Fatalf("patch A settings: status %d", status)
	}

	status, data := doJSON(t, "GET", settingsURL(bGarage), b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("get B settings: status %d body %s", status, data)
	}
	var gs models.GarageSettings
	mustUnmarshal(t, data, &gs)
	if gs.InvoiceDueDays != 7 {
		t.Fatalf("B's settings must be independent, due days = %v", gs.InvoiceDueDays)
	}
}
