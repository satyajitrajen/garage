package models

import "testing"

// Pins DefaultSettings against the const AppConfig defaults in
// lib/data/app_config.dart so the two cannot silently diverge.
func TestDefaultSettingsMatchFlutterDefaults(t *testing.T) {
	s := DefaultSettings("g-1")
	if s.GarageID != "g-1" {
		t.Fatalf("garage_id = %q", s.GarageID)
	}
	if s.Profile.Name != "My Garage" {
		t.Fatalf("profile name = %q", s.Profile.Name)
	}
	if s.DefaultTaxPercent != 18 {
		t.Fatalf("default_tax_percent = %v", s.DefaultTaxPercent)
	}
	wantTax := []float64{0, 12, 18, 28}
	for i, v := range wantTax {
		if s.TaxPercentOptions[i] != v {
			t.Fatalf("tax_percent_options = %v", s.TaxPercentOptions)
		}
	}
	if s.InvoiceDueDays != 7 {
		t.Fatalf("invoice_due_days = %d", s.InvoiceDueDays)
	}
	wantValidity := []int{7, 15, 30}
	for i, v := range wantValidity {
		if s.QuotationValidityOptions[i] != v {
			t.Fatalf("quotation_validity_options = %v", s.QuotationValidityOptions)
		}
	}
	if s.WorkingDaysPerMonth != 26 {
		t.Fatalf("working_days_per_month = %d", s.WorkingDaysPerMonth)
	}
	if s.PromisedDeliveryHours != 6 {
		t.Fatalf("promised_delivery_hours = %d", s.PromisedDeliveryHours)
	}
	if s.InvoiceNotes != "Thank you for choosing us! Standard warranty applies." {
		t.Fatalf("invoice_notes = %q", s.InvoiceNotes)
	}
	if s.InvoiceTerms != "All parts replaced carry manufacturer warranty. Labour warranty 30 days." {
		t.Fatalf("invoice_terms = %q", s.InvoiceTerms)
	}
	if s.DefaultReceivedBy != "Cashier" {
		t.Fatalf("default_received_by = %q", s.DefaultReceivedBy)
	}
}
