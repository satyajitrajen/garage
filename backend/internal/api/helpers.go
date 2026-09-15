package api

import (
	"context"

	"github.com/google/uuid"

	"garage-backend/internal/models"
)

// parseID parses a client-supplied resource id from a URL parameter.
func parseID(raw string) (uuid.UUID, error) {
	return uuid.Parse(raw)
}

// refCheck carries a reference-validation verdict; status 0 means valid.
type refCheck struct {
	status  int
	code    string
	message string
}

// checkRefs validates a required customer+vehicle reference pair and an
// optional assigned-staff id per convention 8: malformed uuid → 400,
// another garage's id → 404.
func (s *Server) checkRefs(ctx context.Context, garageID, customerID, vehicleID string, staffID *string) refCheck {
	if _, err := uuid.Parse(customerID); err != nil {
		return refCheck{400, "invalid_request", "invalid customer id"}
	}
	ok, err := s.Store.CustomerBelongs(ctx, garageID, customerID)
	if err != nil {
		return refCheck{500, "internal", "could not check customer"}
	}
	if !ok {
		return refCheck{404, "not_found", "customer not found"}
	}
	if _, err := uuid.Parse(vehicleID); err != nil {
		return refCheck{400, "invalid_request", "invalid vehicle id"}
	}
	ok, err = s.Store.VehicleBelongs(ctx, garageID, vehicleID)
	if err != nil {
		return refCheck{500, "internal", "could not check vehicle"}
	}
	if !ok {
		return refCheck{404, "not_found", "vehicle not found"}
	}
	if staffID != nil && *staffID != "" {
		if _, err := uuid.Parse(*staffID); err != nil {
			return refCheck{400, "invalid_request", "invalid assignedStaffId"}
		}
		ok, err = s.Store.StaffBelongs(ctx, garageID, *staffID)
		if err != nil {
			return refCheck{500, "internal", "could not check assigned staff"}
		}
		if !ok {
			return refCheck{404, "not_found", "assigned staff not found"}
		}
	}
	return refCheck{}
}

// checkItemStaffRef validates one item's optional assignedStaffId.
func (s *Server) checkItemStaffRef(ctx context.Context, garageID string, it models.MaintenanceItem) refCheck {
	if it.AssignedStaffID == nil || *it.AssignedStaffID == "" {
		return refCheck{}
	}
	if _, err := uuid.Parse(*it.AssignedStaffID); err != nil {
		return refCheck{400, "invalid_request", "invalid assignedStaffId"}
	}
	ok, err := s.Store.StaffBelongs(ctx, garageID, *it.AssignedStaffID)
	if err != nil {
		return refCheck{500, "internal", "could not check assigned staff"}
	}
	if !ok {
		return refCheck{404, "not_found", "assigned staff not found"}
	}
	return refCheck{}
}

// validateItemNumbers guards the money fields the DB numeric(12,2) columns
// would otherwise accept silently (negatives, >100% rates).
func validateItemNumbers(it models.MaintenanceItem) (string, int) {
	if it.UnitPrice < 0 {
		return "unitPrice cannot be negative", 400
	}
	if it.Quantity <= 0 {
		return "quantity must be positive", 400
	}
	if it.DiscountPercent < 0 || it.DiscountPercent > 100 {
		return "discountPercent must be between 0 and 100", 400
	}
	if it.TaxPercent < 0 || it.TaxPercent > 100 {
		return "taxPercent must be between 0 and 100", 400
	}
	if !models.ValidValue(it.Category, models.ItemCategories...) {
		return "invalid category \"" + it.Category + "\"", 400
	}
	return "", 0
}

// validateItems runs name + number checks over a document's item array.
func validateItems(items []models.MaintenanceItem) (string, int) {
	for _, it := range items {
		if it.Name == "" {
			return "item name is required", 400
		}
		if msg, code := validateItemNumbers(it); msg != "" {
			return msg, code
		}
	}
	return "", 0
}
