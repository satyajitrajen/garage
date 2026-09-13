package api

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

func (s *Server) listSalaryAdvances(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListSalaryAdvances(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list salary advances")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createSalaryAdvance(w http.ResponseWriter, r *http.Request) {
	var adv models.SalaryAdvance
	if !httputil.Decode(w, r, &adv) {
		return
	}
	if adv.Amount <= 0 {
		httputil.Error(w, 422, "unprocessable", "amount must be positive")
		return
	}
	adv.IsDeducted = false
	if _, err := uuid.Parse(adv.StaffID); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid staff id")
		return
	}
	if _, err := time.Parse("2006-01-02", adv.Date); err != nil {
		httputil.Error(w, 400, "invalid_request", "date must be YYYY-MM-DD")
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.StaffBelongs(r.Context(), garageID, adv.StaffID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check staff")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	created, err := s.Store.CreateSalaryAdvance(r.Context(), garageID, adv)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create salary advance")
		return
	}
	httputil.JSON(w, 201, created)
}

type settleRequest struct {
	StaffID string `json:"staff_id"`
	Month   int    `json:"month"`
	Year    int    `json:"year"`
}

func (s *Server) settleSalaryAdvances(w http.ResponseWriter, r *http.Request) {
	var req settleRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if _, err := uuid.Parse(req.StaffID); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid staff id")
		return
	}
	if req.Month < 1 || req.Month > 12 || req.Year < 1970 || req.Year > 2100 {
		httputil.Error(w, 400, "invalid_request", "month must be 1-12 and year 1970-2100")
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.StaffBelongs(r.Context(), garageID, req.StaffID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check staff")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	items, err := s.Store.SettleSalaryAdvances(r.Context(), garageID, req.StaffID, req.Month, req.Year)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not settle salary advances")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}
