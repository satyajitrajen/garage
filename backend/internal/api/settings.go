package api

import (
	"errors"
	"net/http"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func (s *Server) getSettings(w http.ResponseWriter, r *http.Request) {
	gs, err := s.Store.GetOrCreateSettings(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load settings")
		return
	}
	httputil.JSON(w, 200, gs)
}

// patchSettings partial-merges: each provided top-level field replaces that
// field (a provided profile object replaces the whole profile); omitted
// fields keep their stored values.
func (s *Server) patchSettings(w http.ResponseWriter, r *http.Request) {
	current, err := s.Store.GetOrCreateSettings(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load settings")
		return
	}

	var patch struct {
		Profile                  *models.Profile `json:"profile"`
		DefaultTaxPercent        *float64        `json:"default_tax_percent"`
		TaxPercentOptions        []float64       `json:"tax_percent_options"`
		InvoiceDueDays           *int            `json:"invoice_due_days"`
		QuotationValidityOptions []int           `json:"quotation_validity_options"`
		WorkingDaysPerMonth      *int            `json:"working_days_per_month"`
		PromisedDeliveryHours    *int            `json:"promised_delivery_hours"`
		InvoiceNotes             *string         `json:"invoice_notes"`
		InvoiceTerms             *string         `json:"invoice_terms"`
		DefaultReceivedBy        *string         `json:"default_received_by"`
	}
	if !httputil.Decode(w, r, &patch) {
		return
	}

	if patch.DefaultTaxPercent != nil && (*patch.DefaultTaxPercent < 0 || *patch.DefaultTaxPercent > 100) {
		httputil.Error(w, 400, "invalid_request", "default_tax_percent must be between 0 and 100")
		return
	}
	for _, v := range patch.TaxPercentOptions {
		if v < 0 || v > 100 {
			httputil.Error(w, 400, "invalid_request", "tax_percent_options must be between 0 and 100")
			return
		}
	}
	for _, v := range patch.QuotationValidityOptions {
		if v < 0 || v > 365 {
			httputil.Error(w, 400, "invalid_request", "quotation_validity_options must be between 0 and 365")
			return
		}
	}
	for field, v := range map[string]*int{
		"invoice_due_days":        patch.InvoiceDueDays,
		"working_days_per_month":  patch.WorkingDaysPerMonth,
		"promised_delivery_hours": patch.PromisedDeliveryHours,
	} {
		if v != nil && (*v < 0 || *v > 1000) {
			httputil.Error(w, 400, "invalid_request", field+" must be between 0 and 1000")
			return
		}
	}

	if patch.Profile != nil {
		current.Profile = *patch.Profile
	}
	if patch.DefaultTaxPercent != nil {
		current.DefaultTaxPercent = *patch.DefaultTaxPercent
	}
	if patch.TaxPercentOptions != nil {
		current.TaxPercentOptions = patch.TaxPercentOptions
	}
	if patch.InvoiceDueDays != nil {
		current.InvoiceDueDays = *patch.InvoiceDueDays
	}
	if patch.QuotationValidityOptions != nil {
		current.QuotationValidityOptions = patch.QuotationValidityOptions
	}
	if patch.WorkingDaysPerMonth != nil {
		current.WorkingDaysPerMonth = *patch.WorkingDaysPerMonth
	}
	if patch.PromisedDeliveryHours != nil {
		current.PromisedDeliveryHours = *patch.PromisedDeliveryHours
	}
	if patch.InvoiceNotes != nil {
		current.InvoiceNotes = *patch.InvoiceNotes
	}
	if patch.InvoiceTerms != nil {
		current.InvoiceTerms = *patch.InvoiceTerms
	}
	if patch.DefaultReceivedBy != nil {
		current.DefaultReceivedBy = *patch.DefaultReceivedBy
	}

	if err := s.Store.UpdateSettings(r.Context(), current); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "garage not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not save settings")
		return
	}
	httputil.JSON(w, 200, current)
}
