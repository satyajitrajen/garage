package models

import "time"

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	Name         string    `json:"name"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type Membership struct {
	GarageID    string   `json:"garage_id"`
	GarageName  string   `json:"garage_name"`
	Role        string   `json:"role"`
	Permissions []string `json:"permissions"`
	IsActive    bool     `json:"is_active"`
}

type Member struct {
	UserID      string   `json:"user_id"`
	Name        string   `json:"name"`
	Email       string   `json:"email"`
	Role        string   `json:"role"`
	Permissions []string `json:"permissions"`
	IsActive    bool     `json:"is_active"`
}

type Profile struct {
	Name        string `json:"name"`
	Tagline     string `json:"tagline"`
	AddressLine string `json:"address_line"`
	City        string `json:"city"`
	Phone       string `json:"phone"`
	Email       string `json:"email"`
	GSTIN       string `json:"gstin"`
	UPIID       string `json:"upi_id"`
}

type GarageSettings struct {
	GarageID                 string    `json:"garage_id"`
	Profile                  Profile   `json:"profile"`
	DefaultTaxPercent        float64   `json:"default_tax_percent"`
	TaxPercentOptions        []float64 `json:"tax_percent_options"`
	InvoiceDueDays           int       `json:"invoice_due_days"`
	QuotationValidityOptions []int     `json:"quotation_validity_options"`
	WorkingDaysPerMonth      int       `json:"working_days_per_month"`
	PromisedDeliveryHours    int       `json:"promised_delivery_hours"`
	InvoiceNotes             string    `json:"invoice_notes"`
	InvoiceTerms             string    `json:"invoice_terms"`
	DefaultReceivedBy        string    `json:"default_received_by"`
}

// DefaultSettings mirrors const AppConfig defaults in lib/data/app_config.dart.
func DefaultSettings(garageID string) GarageSettings {
	return GarageSettings{
		GarageID:                 garageID,
		Profile:                  Profile{Name: "My Garage"},
		DefaultTaxPercent:        18,
		TaxPercentOptions:        []float64{0, 5, 12, 18, 28},
		InvoiceDueDays:           7,
		QuotationValidityOptions: []int{7, 15, 30},
		WorkingDaysPerMonth:      26,
		PromisedDeliveryHours:    6,
		InvoiceNotes:             "Thank you for choosing us! Standard warranty applies.",
		InvoiceTerms:             "All parts replaced carry manufacturer warranty. Labour warranty 30 days.",
		DefaultReceivedBy:        "Cashier",
	}
}
