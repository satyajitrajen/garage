package models

import "time"

type Staff struct {
	ID               string    `json:"id"`
	Name             string    `json:"name"`
	Role             string    `json:"role"`
	Phone            string    `json:"phone"`
	Email            *string   `json:"email"`
	MonthlySalary    float64   `json:"monthlySalary"`
	JoiningDate      string    `json:"joiningDate"`
	IsActive         bool      `json:"isActive"`
	Address          *string   `json:"address"`
	EmergencyContact *string   `json:"emergencyContact"`
	CreatedAt        time.Time `json:"createdAt"`
}
