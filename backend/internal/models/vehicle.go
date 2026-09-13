package models

import "time"

type Vehicle struct {
	ID                 string    `json:"id"`
	CustomerID         string    `json:"customerId"`
	RegistrationNumber string    `json:"registrationNumber"`
	Make               string    `json:"make"`
	Model              string    `json:"model"`
	Variant            *string   `json:"variant"`
	Year               *int      `json:"year"`
	FuelType           string    `json:"fuelType"`
	CurrentKm          int       `json:"currentKm"`
	Color              *string   `json:"color"`
	ChassisNumber      *string   `json:"chassisNumber"`
	EngineNumber       *string   `json:"engineNumber"`
	CreatedAt          time.Time `json:"createdAt"`
	LastServiceDate    *string   `json:"lastServiceDate"`
}
