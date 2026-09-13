package models

import "time"

type JobCard struct {
	ID                   string            `json:"id"`
	JobCardNumber        string            `json:"jobCardNumber"`
	CustomerID           string            `json:"customerId"`
	VehicleID            string            `json:"vehicleId"`
	CustomerComplaints   []string          `json:"customerComplaints"`
	InspectionChecklist  map[string]bool   `json:"inspectionChecklist"`
	FuelLevel            string            `json:"fuelLevel"`
	KmReading            int               `json:"kmReading"`
	AssignedStaffID      *string           `json:"assignedStaffId"`
	Status               string            `json:"status"`
	PromisedDeliveryDate time.Time         `json:"promisedDeliveryDate"`
	CompletedAt          *time.Time        `json:"completedAt"`
	CreatedAt            time.Time         `json:"createdAt"`
	EstimatedCostNote    *string           `json:"estimatedCostNote"`
	SupervisorNotes      *string           `json:"supervisorNotes"`
	Items                []MaintenanceItem `json:"items"`
}

// DefaultChecklist mirrors JobCard.defaultChecklist in lib/models/job_card.dart.
var DefaultChecklist = map[string]bool{
	"Engine Oil Level":       true,
	"Brake System":           true,
	"Coolant & Fluids":       true,
	"Battery & Terminals":    true,
	"Tyres & Pressure":       true,
	"AC & Heating":           true,
	"Lights & Horn":          true,
	"Body Scratches Checked": true,
}

// DefaultFuelLevel mirrors the JobCard constructor default.
const DefaultFuelLevel = "1/2"
