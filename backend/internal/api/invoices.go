package api

import (
	"context"
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

func validateInvoice(inv models.Invoice) (string, int) {
	if inv.InvoiceNumber == "" {
		return "invoiceNumber is required", 400
	}
	if inv.DiscountAmount < 0 {
		return "discountAmount cannot be negative", 400
	}
	return "", 0
}

// normalizeInvoice fills the Dart constructor defaults: invoiceDate now and
// a non-nil items slice.
func normalizeInvoice(inv *models.Invoice) {
	if inv.InvoiceDate.IsZero() {
		inv.InvoiceDate = time.Now().UTC()
	}
	if inv.Items == nil {
		inv.Items = []models.MaintenanceItem{}
	}
}

func (s *Server) checkInvoiceRefs(ctx context.Context, garageID string, inv models.Invoice) refCheck {
	if rc := s.checkRefs(ctx, garageID, inv.CustomerID, inv.VehicleID, nil); rc.status != 0 {
		return rc
	}
	if inv.JobCardID != nil && *inv.JobCardID != "" {
		if _, err := uuid.Parse(*inv.JobCardID); err != nil {
			return refCheck{400, "invalid_request", "invalid jobCardId"}
		}
		ok, err := s.Store.JobCardBelongs(ctx, garageID, *inv.JobCardID)
		if err != nil {
			return refCheck{500, "internal", "could not check job card"}
		}
		if !ok {
			return refCheck{404, "not_found", "job card not found"}
		}
	}
	return refCheck{}
}

func (s *Server) listInvoices(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListInvoices(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list invoices")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createInvoice(w http.ResponseWriter, r *http.Request) {
	var inv models.Invoice
	if !httputil.Decode(w, r, &inv) {
		return
	}
	normalizeInvoice(&inv)
	if msg, status := validateInvoice(inv); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkInvoiceRefs(r.Context(), garageID, inv); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range inv.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	created, err := s.Store.CreateInvoice(r.Context(), garageID, inv)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "invoice number already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create invoice")
		return
	}
	httputil.JSON(w, 201, created)
}

// cancelGuard enforces spec §8 on both cancel paths: not already cancelled
// and totalPaid ≤ 0 (mirroring cancelInvoice's `totalPaidAmount > 0` throw).
func (s *Server) cancelGuard(ctx context.Context, garageID, invoiceID string) refCheck {
	m, err := s.Store.InvoiceMoneyFor(ctx, garageID, invoiceID)
	if err != nil {
		return refCheck{500, "internal", "could not load invoice money"}
	}
	if m.CancelledAt != nil {
		return refCheck{422, "unprocessable", "invoice is already cancelled"}
	}
	if m.Paid > 0 {
		return refCheck{422, "unprocessable", "invoice has payments and cannot be cancelled"}
	}
	return refCheck{}
}

func (s *Server) updateInvoice(w http.ResponseWriter, r *http.Request) {
	var inv models.Invoice
	if !httputil.Decode(w, r, &inv) {
		return
	}
	inv.ID = chi.URLParam(r, "invoiceId")
	if _, err := parseID(inv.ID); err != nil {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	normalizeInvoice(&inv)
	if msg, status := validateInvoice(inv); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkInvoiceRefs(r.Context(), garageID, inv); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range inv.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	// A PUT that sets cancelledAt is the provider's cancelInvoice path and
	// must pass the same guard as the cancel endpoint.
	if inv.CancelledAt != nil {
		if rc := s.cancelGuard(r.Context(), garageID, inv.ID); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	updated, err := s.Store.UpdateInvoice(r.Context(), garageID, inv)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update invoice")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) cancelInvoice(w http.ResponseWriter, r *http.Request) {
	invoiceID := chi.URLParam(r, "invoiceId")
	if _, err := parseID(invoiceID); err != nil {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	garageID := auth.GarageID(r.Context())
	if _, err := s.Store.InvoiceByID(r.Context(), garageID, invoiceID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "invoice not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not load invoice")
		return
	}
	if rc := s.cancelGuard(r.Context(), garageID, invoiceID); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	cancelled, err := s.Store.MarkInvoiceCancelled(r.Context(), garageID, invoiceID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not cancel invoice")
		return
	}
	httputil.JSON(w, 200, cancelled)
}
