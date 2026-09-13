package api

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

func (s *Server) listAttendance(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListAttendance(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list attendance")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) upsertAttendance(w http.ResponseWriter, r *http.Request) {
	var rec models.AttendanceRecord
	if !httputil.Decode(w, r, &rec) {
		return
	}
	if _, err := uuid.Parse(rec.StaffID); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid staff id")
		return
	}
	if !models.ValidValue(rec.Status, models.AttendanceStatuses...) {
		httputil.Error(w, 400, "invalid_request", "invalid status \""+rec.Status+"\"")
		return
	}
	if _, err := time.Parse("2006-01-02", rec.Date); err != nil {
		httputil.Error(w, 400, "invalid_request", "date must be YYYY-MM-DD")
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.StaffBelongs(r.Context(), garageID, rec.StaffID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check staff")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	saved, err := s.Store.UpsertAttendance(r.Context(), garageID, rec)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not save attendance")
		return
	}
	httputil.JSON(w, 200, saved)
}
