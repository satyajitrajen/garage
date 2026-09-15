package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateStaff(st models.Staff) (string, int) {
	if st.Name == "" || st.Phone == "" {
		return "name and phone are required", 400
	}
	if !models.ValidValue(st.Role, models.StaffRoles...) {
		return "invalid role \"" + st.Role + "\"", 400
	}
	if st.MonthlySalary < 0 {
		return "monthlySalary cannot be negative", 400
	}
	if _, err := time.Parse("2006-01-02", st.JoiningDate); err != nil {
		return "joining_date must be YYYY-MM-DD", 400
	}
	return "", 0
}

func (s *Server) listStaff(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListStaff(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list staff")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createStaff(w http.ResponseWriter, r *http.Request) {
	var st models.Staff
	if !httputil.Decode(w, r, &st) {
		return
	}
	if msg, code := validateStaff(st); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	created, err := s.Store.CreateStaff(r.Context(), auth.GarageID(r.Context()), st)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create staff")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateStaff(w http.ResponseWriter, r *http.Request) {
	var st models.Staff
	if !httputil.Decode(w, r, &st) {
		return
	}
	st.ID = chi.URLParam(r, "staffId")
	if _, err := parseID(st.ID); err != nil {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	if msg, code := validateStaff(st); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	updated, err := s.Store.UpdateStaff(r.Context(), auth.GarageID(r.Context()), st)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update staff")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteStaff(w http.ResponseWriter, r *http.Request) {
	staffID := chi.URLParam(r, "staffId")
	if _, err := parseID(staffID); err != nil {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	err := s.Store.DeleteStaff(r.Context(), auth.GarageID(r.Context()), staffID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete staff")
		return
	}
	w.WriteHeader(204)
}
