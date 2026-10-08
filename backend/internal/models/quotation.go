package models

import "time"

type Quotation struct {
	ID              string            `json:"id"`
	QuotationNumber string            `json:"quotationNumber"`
	CustomerID      string            `json:"customerId"`
	VehicleID       string            `json:"vehicleId"`
	KmReading       int               `json:"kmReading"`
	Items           []MaintenanceItem `json:"items"`
	OverallDiscount float64           `json:"overallDiscount"`
	TaxPercent      float64           `json:"taxPercent"`
	PerItemTax      bool              `json:"perItemTax"`
	ValidityDays    int               `json:"validityDays"`
	Status          string            `json:"status"`
	Notes           *string           `json:"notes"`
	CreatedAt       time.Time         `json:"createdAt"`
	ValidUntil      time.Time         `json:"validUntil"`
}
