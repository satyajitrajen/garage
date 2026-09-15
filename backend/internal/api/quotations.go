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

func validateQuotation(q models.Quotation) (string, int) {
	if q.QuotationNumber == "" {
		return "quotationNumber is required", 400
	}
	if !models.ValidValue(q.Status, models.QuotationStatuses...) {
		return "invalid status \"" + q.Status + "\"", 400
	}
	if q.ValidityDays <= 0 {
		return "validityDays must be positive", 400
	}
	if q.KmReading < 0 {
		return "kmReading cannot be negative", 400
	}
	if q.OverallDiscount < 0 {
		return "overallDiscount cannot be negative", 400
	}
	if q.TaxPercent < 0 || q.TaxPercent > 100 {
		return "taxPercent must be between 0 and 100", 400
	}
	return "", 0
}

// normalizeQuotation fills the Dart constructor defaults status 'draft'
// (QuotationStatus.draft) and validUntil = today + validityDays when the
// client omits them, and keeps items non-nil.
func normalizeQuotation(q *models.Quotation) {
	if q.Status == "" {
		q.Status = "draft"
	}
	if q.ValidUntil.IsZero() {
		q.ValidUntil = time.Now().UTC().AddDate(0, 0, q.ValidityDays)
	}
	if q.Items == nil {
		q.Items = []models.MaintenanceItem{}
	}
}

func (s *Server) listQuotations(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListQuotations(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list quotations")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createQuotation(w http.ResponseWriter, r *http.Request) {
	var q models.Quotation
	if !httputil.Decode(w, r, &q) {
		return
	}
	normalizeQuotation(&q)
	garageID := auth.GarageID(r.Context())
	if q.QuotationNumber == "" {
		num, err := s.Store.NextDocNumber(r.Context(), garageID, "quotation")
		if err != nil {
			httputil.Error(w, 500, "internal", "could not assign quotation number")
			return
		}
		q.QuotationNumber = num
	}
	if msg, status := validateQuotation(q); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	if msg, status := validateItems(q.Items); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	if rc := s.checkRefs(r.Context(), garageID, q.CustomerID, q.VehicleID, nil); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range q.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	created, err := s.Store.CreateQuotation(r.Context(), garageID, q)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "quotation number already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create quotation")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateQuotation(w http.ResponseWriter, r *http.Request) {
	var q models.Quotation
	if !httputil.Decode(w, r, &q) {
		return
	}
	q.ID = chi.URLParam(r, "quotationId")
	if _, err := parseID(q.ID); err != nil {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	normalizeQuotation(&q)
	if msg, status := validateQuotation(q); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	if msg, status := validateItems(q.Items); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, q.CustomerID, q.VehicleID, nil); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range q.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	updated, err := s.Store.UpdateQuotation(r.Context(), garageID, q)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update quotation")
		return
	}
	httputil.JSON(w, 200, updated)
}

// updateQuotationStatus enforces the provider guard: converted is reachable
// only from approved (spec §8, mirroring convertQuotation in
// lib/providers/garage_provider.dart).
func (s *Server) updateQuotationStatus(w http.ResponseWriter, r *http.Request) {
	quotationID := chi.URLParam(r, "quotationId")
	if _, err := parseID(quotationID); err != nil {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if !models.ValidValue(req.Status, models.QuotationStatuses...) {
		httputil.Error(w, 400, "invalid_request", "invalid status \""+req.Status+"\"")
		return
	}
	garageID := auth.GarageID(r.Context())
	current, err := s.Store.QuotationByID(r.Context(), garageID, quotationID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load quotation")
		return
	}
	if req.Status == "converted" && current.Status != "approved" {
		httputil.Error(w, 422, "unprocessable", "quotation can only be converted from approved")
		return
	}
	updated, err := s.Store.UpdateQuotationStatus(r.Context(), garageID, quotationID, req.Status)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update quotation status")
		return
	}
	httputil.JSON(w, 200, updated)
}
