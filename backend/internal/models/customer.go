package models

import "time"

type Customer struct {
	ID             string    `json:"id"`
	Name           string    `json:"name"`
	Phone          string    `json:"phone"`
	WhatsAppNumber *string   `json:"whatsappNumber"`
	Email          *string   `json:"email"`
	Address        *string   `json:"address"`
	GSTIN          *string   `json:"gstin"`
	Notes          *string   `json:"notes"`
	CreatedAt      time.Time `json:"createdAt"`
}
