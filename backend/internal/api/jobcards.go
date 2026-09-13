package api

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateJobCard(jc models.JobCard) (string, int) {
	if jc.JobCardNumber == "" {
		return "jobCardNumber is required", 400
	}
	if !models.ValidValue(jc.Status, models.JobStatuses...) {
		return "invalid status \"" + jc.Status + "\"", 400
	}
	if jc.PromisedDeliveryDate.IsZero() {
		return "promisedDeliveryDate is required", 400
	}
	return "", 0
}

// normalizeJobCard fills the constructor defaults the Dart side always has:
// status 'received' (JobStatus.received), fuelLevel '1/2', empty complaints,
// the default inspection checklist and a non-nil items slice.
func normalizeJobCard(jc *models.JobCard) {
	if jc.Status == "" {
		jc.Status = "received"
	}
	if jc.FuelLevel == "" {
		jc.FuelLevel = models.DefaultFuelLevel
	}
	if jc.CustomerComplaints == nil {
		jc.CustomerComplaints = []string{}
	}
	if jc.InspectionChecklist == nil {
		jc.InspectionChecklist = models.DefaultChecklist
	}
	if jc.Items == nil {
		jc.Items = []models.MaintenanceItem{}
	}
}

func (s *Server) listJobCards(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListJobCards(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list job cards")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createJobCard(w http.ResponseWriter, r *http.Request) {
	var jc models.JobCard
	if !httputil.Decode(w, r, &jc) {
		return
	}
	normalizeJobCard(&jc)
	if msg, status := validateJobCard(jc); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, jc.CustomerID, jc.VehicleID, jc.AssignedStaffID); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range jc.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	created, err := s.Store.CreateJobCard(r.Context(), garageID, jc)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "job card number already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create job card")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateJobCard(w http.ResponseWriter, r *http.Request) {
	var jc models.JobCard
	if !httputil.Decode(w, r, &jc) {
		return
	}
	jc.ID = chi.URLParam(r, "jobCardId")
	if _, err := parseID(jc.ID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	normalizeJobCard(&jc)
	if msg, status := validateJobCard(jc); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, jc.CustomerID, jc.VehicleID, jc.AssignedStaffID); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range jc.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	updated, err := s.Store.UpdateJobCard(r.Context(), garageID, jc)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update job card")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) updateJobCardStatus(w http.ResponseWriter, r *http.Request) {
	jobCardID := chi.URLParam(r, "jobCardId")
	if _, err := parseID(jobCardID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if !models.ValidValue(req.Status, models.JobStatuses...) {
		httputil.Error(w, 400, "invalid_request", "invalid status \""+req.Status+"\"")
		return
	}
	updated, err := s.Store.UpdateJobCardStatus(r.Context(), auth.GarageID(r.Context()), jobCardID, req.Status)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update job card status")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) upsertJobCardItem(w http.ResponseWriter, r *http.Request) {
	jobCardID := chi.URLParam(r, "jobCardId")
	if _, err := parseID(jobCardID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	var it models.MaintenanceItem
	if !httputil.Decode(w, r, &it) {
		return
	}
	if it.Name == "" {
		httputil.Error(w, 400, "invalid_request", "name is required")
		return
	}
	if !models.ValidValue(it.Category, models.ItemCategories...) {
		httputil.Error(w, 400, "invalid_request", "invalid category \""+it.Category+"\"")
		return
	}
	garageID := auth.GarageID(r.Context())
	if _, err := s.Store.JobCardByID(r.Context(), garageID, jobCardID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "job card not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not load job card")
		return
	}
	if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	saved, err := s.Store.UpsertItem(r.Context(), "job_card_items", jobCardID, it)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "item id already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not save job card item")
		return
	}
	httputil.JSON(w, 200, saved)
}

func (s *Server) deleteJobCardItem(w http.ResponseWriter, r *http.Request) {
	jobCardID := chi.URLParam(r, "jobCardId")
	itemID := chi.URLParam(r, "itemId")
	if _, err := parseID(jobCardID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	if _, err := parseID(itemID); err != nil {
		httputil.Error(w, 404, "not_found", "item not found")
		return
	}
	err := s.Store.DeleteItem(r.Context(), "job_card_items", jobCardID, itemID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "item not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete job card item")
		return
	}
	w.WriteHeader(204)
}
