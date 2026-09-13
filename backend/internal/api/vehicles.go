package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateVehicle(v models.Vehicle) (string, int) {
	if v.RegistrationNumber == "" || v.Make == "" || v.Model == "" {
		return "registration_number, make and model are required", 400
	}
	if _, err := uuid.Parse(v.CustomerID); err != nil {
		return "invalid customer id", 400
	}
	if !models.ValidValue(v.FuelType, models.FuelTypes...) {
		return "invalid fuelType \"" + v.FuelType + "\"", 400
	}
	if v.CurrentKm < 0 {
		return "current_km must not be negative", 400
	}
	if v.LastServiceDate != nil && *v.LastServiceDate != "" {
		if _, err := time.Parse("2006-01-02", *v.LastServiceDate); err != nil {
			return "last_service_date must be YYYY-MM-DD", 400
		}
	}
	return "", 0
}

func (s *Server) listVehicles(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListVehicles(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list vehicles")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createVehicle(w http.ResponseWriter, r *http.Request) {
	var v models.Vehicle
	if !httputil.Decode(w, r, &v) {
		return
	}
	if msg, code := validateVehicle(v); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.CustomerBelongs(r.Context(), garageID, v.CustomerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	created, err := s.Store.CreateVehicle(r.Context(), garageID, v)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create vehicle")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateVehicle(w http.ResponseWriter, r *http.Request) {
	var v models.Vehicle
	if !httputil.Decode(w, r, &v) {
		return
	}
	v.ID = chi.URLParam(r, "vehicleId")
	if _, err := parseID(v.ID); err != nil {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	if msg, code := validateVehicle(v); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.CustomerBelongs(r.Context(), garageID, v.CustomerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	updated, err := s.Store.UpdateVehicle(r.Context(), garageID, v)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update vehicle")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteVehicle(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	vehicleID := chi.URLParam(r, "vehicleId")
	if _, err := parseID(vehicleID); err != nil {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	hasDocs, err := s.Store.VehicleHasDocuments(r.Context(), garageID, vehicleID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check vehicle history")
		return
	}
	if hasDocs {
		httputil.Error(w, 409, "conflict", "vehicle has job cards or invoices")
		return
	}
	err = s.Store.DeleteVehicle(r.Context(), garageID, vehicleID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete vehicle")
		return
	}
	w.WriteHeader(204)
}
