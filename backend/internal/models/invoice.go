package models

import "time"

type Invoice struct {
	ID                 string            `json:"id"`
	InvoiceNumber      string            `json:"invoiceNumber"`
	JobCardID          *string           `json:"jobCardId"`
	CustomerID         string            `json:"customerId"`
	VehicleID          string            `json:"vehicleId"`
	KmReading          int               `json:"kmReading"`
	Items              []MaintenanceItem `json:"items"`
	DiscountAmount     float64           `json:"discountAmount"`
	TaxPercent         float64           `json:"taxPercent"`
	PerItemTax         bool              `json:"perItemTax"`
	Payments           []Payment         `json:"payments"`
	InvoiceDate        time.Time         `json:"invoiceDate"`
	DueDate            *time.Time        `json:"dueDate"`
	CancelledAt        *time.Time        `json:"cancelledAt"`
	Notes              *string           `json:"notes"`
	TermsAndConditions *string           `json:"termsAndConditions"`
	CreatedAt          time.Time         `json:"createdAt"`
}
