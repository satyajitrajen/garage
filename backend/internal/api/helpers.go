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
