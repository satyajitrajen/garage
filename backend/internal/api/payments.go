package api

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

type recordPaymentRequest struct {
	Amount         float64 `json:"amount"`
	Mode           string  `json:"mode"`
	CustomerID     *string `json:"customerId"`
	TransactionRef *string `json:"transactionRef"`
	Notes          *string `json:"notes"`
	ReceivedBy     *string `json:"receivedBy"`
}

// recordPayment mirrors the provider's addPayment rule (spec §8): amount in
// (0, balanceDue + 0.01] on a non-cancelled invoice. Payments are
// append-only — there is no update or delete.
func (s *Server) recordPayment(w http.ResponseWriter, r *http.Request) {
	invoiceID := chi.URLParam(r, "invoiceId")
	if _, err := parseID(invoiceID); err != nil {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	var req recordPaymentRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Amount <= 0 {
		httputil.Error(w, 422, "unprocessable", "payment amount must be positive")
		return
	}
	if !models.ValidValue(req.Mode, models.PaymentModes...) {
		httputil.Error(w, 400, "invalid_request", "invalid mode \""+req.Mode+"\"")
		return
	}
	garageID := auth.GarageID(r.Context())
	if req.CustomerID != nil && *req.CustomerID != "" {
		if _, err := uuid.Parse(*req.CustomerID); err != nil {
			httputil.Error(w, 400, "invalid_request", "invalid customerId")
			return
		}
		ok, err := s.Store.CustomerBelongs(r.Context(), garageID, *req.CustomerID)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not check customer")
			return
		}
		if !ok {
			httputil.Error(w, 404, "not_found", "customer not found")
			return
		}
	} else {
		req.CustomerID = nil
	}
	m, err := s.Store.InvoiceMoneyFor(r.Context(), garageID, invoiceID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load invoice")
		return
	}
	if m.CancelledAt != nil {
		httputil.Error(w, 422, "unprocessable", "invoice is cancelled")
		return
	}
	if req.Amount > m.Due()+0.01 {
		httputil.Error(w, 422, "unprocessable", "payment exceeds balance due")
		return
	}
	p, err := s.Store.CreatePayment(r.Context(), invoiceID, models.Payment{
		CustomerID:     req.CustomerID,
		Amount:         req.Amount,
		Mode:           req.Mode,
		TransactionRef: req.TransactionRef,
		Notes:          req.Notes,
		ReceivedBy:     req.ReceivedBy,
	})
	if err != nil {
		httputil.Error(w, 500, "internal", "could not record payment")
		return
	}
	httputil.JSON(w, 201, p)
}
