package models

import "time"

type CatalogItem struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	Category   string    `json:"category"`
	UnitPrice  float64   `json:"unitPrice"`
	TaxPercent float64   `json:"taxPercent"`
	Unit       string    `json:"unit"`
	IsLabour   bool      `json:"isLabour"`
	PartNumber *string   `json:"partNumber"`
	Notes      *string   `json:"notes"`
	CreatedAt  time.Time `json:"createdAt"`
}
