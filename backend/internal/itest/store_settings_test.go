package itest

import (
	"reflect"
	"testing"

	"garage-backend/internal/auth"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func TestSettingsGetOrCreateDefaults(t *testing.T) {
	truncate(t)
	s := store.New(pool)
	_, m, err := s.RegisterOwner(ctx, "s@test.dev", "h", "S", "Garage S", auth.AllPermissions)
	if err != nil {
		t.Fatal(err)
	}

	gs, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil {
		t.Fatalf("get or create: %v", err)
	}
	want := models.DefaultSettings(m.GarageID)
	want.Profile.Name = "Garage S" // seeded from the registered garage name
	if !reflect.DeepEqual(gs, want) {
		t.Fatalf("defaults must match models.DefaultSettings:\n got %+v\nwant %+v", gs, want)
	}
	if gs.GarageID != m.GarageID {
		t.Fatalf("garage_id = %s", gs.GarageID)
	}
	if gs.DefaultTaxPercent != 18 || gs.InvoiceDueDays != 7 {
		t.Fatalf("tax/due = %v/%v", gs.DefaultTaxPercent, gs.InvoiceDueDays)
	}
	if len(gs.TaxPercentOptions) != 4 || gs.TaxPercentOptions[2] != 18 {
		t.Fatalf("tax options = %v", gs.TaxPercentOptions)
	}
	if len(gs.QuotationValidityOptions) != 3 {
		t.Fatalf("validity options = %v", gs.QuotationValidityOptions)
	}
	if gs.WorkingDaysPerMonth != 26 || gs.PromisedDeliveryHours != 6 {
		t.Fatalf("working days/hours = %v/%v", gs.WorkingDaysPerMonth, gs.PromisedDeliveryHours)
	}
	if gs.InvoiceNotes == "" || gs.InvoiceTerms == "" || gs.DefaultReceivedBy != "Cashier" {
		t.Fatalf("notes/terms/receivedBy = %q/%q/%q", gs.InvoiceNotes, gs.InvoiceTerms, gs.DefaultReceivedBy)
	}

	again, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil || again.InvoiceDueDays != gs.InvoiceDueDays {
		t.Fatalf("get-or-create must be idempotent: %+v %v", again, err)
	}
}

func TestSettingsUpdate(t *testing.T) {
	truncate(t)
	s := store.New(pool)
	_, m, err := s.RegisterOwner(ctx, "s2@test.dev", "h", "S", "Garage S2", auth.AllPermissions)
	if err != nil {
		t.Fatal(err)
	}
	gs, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil {
		t.Fatal(err)
	}
	gs.InvoiceDueDays = 14
	gs.Profile.City = "Pune"
	if err := s.UpdateSettings(ctx, gs); err != nil {
		t.Fatalf("update: %v", err)
	}
	got, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil {
		t.Fatal(err)
	}
	if got.InvoiceDueDays != 14 || got.Profile.City != "Pune" || got.DefaultTaxPercent != 18 {
		t.Fatalf("after update: %+v", got)
	}
}
