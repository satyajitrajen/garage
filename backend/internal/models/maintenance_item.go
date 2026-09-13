package models

// MaintenanceItem mirrors lib/models/maintenance_item.dart and is shared by
// job cards, quotations and invoices.
type MaintenanceItem struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Category        string  `json:"category"`
	UnitPrice       float64 `json:"unitPrice"`
	Quantity        float64 `json:"quantity"`
	Unit            string  `json:"unit"`
	DiscountPercent float64 `json:"discountPercent"`
	TaxPercent      float64 `json:"taxPercent"`
	IsLabour        bool    `json:"isLabour"`
	PartNumber      *string `json:"partNumber"`
	Notes           *string `json:"notes"`
	AssignedStaffID *string `json:"assignedStaffId"`
}
