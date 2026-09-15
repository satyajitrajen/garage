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

func (s *Server) listCustomers(w http.ResponseWriter, r *http.Request) {
	if limit, offset, ok := pageParams(r); ok {
		items, total, err := s.Store.ListCustomersPage(r.Context(), auth.GarageID(r.Context()), limit, offset)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not list customers")
			return
		}
		httputil.JSON(w, 200, map[string]any{"items": items, "total": total, "limit": limit, "offset": offset})
		return
	}
	items, err := s.Store.ListCustomers(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list customers")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createCustomer(w http.ResponseWriter, r *http.Request) {
	var c models.Customer
	if !httputil.Decode(w, r, &c) {
		return
	}
	if c.Name == "" || c.Phone == "" {
		httputil.Error(w, 400, "invalid_request", "name and phone are required")
		return
	}
	created, err := s.Store.CreateCustomer(r.Context(), auth.GarageID(r.Context()), c)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create customer")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateCustomer(w http.ResponseWriter, r *http.Request) {
	var c models.Customer
	if !httputil.Decode(w, r, &c) {
		return
	}
	c.ID = chi.URLParam(r, "customerId")
	if _, err := parseID(c.ID); err != nil {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	if c.Name == "" || c.Phone == "" {
		httputil.Error(w, 400, "invalid_request", "name and phone are required")
		return
	}
	updated, err := s.Store.UpdateCustomer(r.Context(), auth.GarageID(r.Context()), c)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update customer")
		return
	}
	httputil.JSON(w, 200, updated)
}

// deleteCustomer mirrors MockGarageRepository.deleteCustomer: 409 while the
// customer has outstanding dues. Invoice/job-card history also blocks the
// delete so surviving documents keep a resolvable customer.
func (s *Server) deleteCustomer(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	customerID := chi.URLParam(r, "customerId")
	if _, err := parseID(customerID); err != nil {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}

	dues, err := s.Store.CustomerHasOutstandingDues(r.Context(), garageID, customerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer dues")
		return
	}
	if dues {
		httputil.Error(w, 409, "conflict", "customer has outstanding dues")
		return
	}
	hasInvoices, hasJobCards, err := s.Store.CustomerHasDocuments(r.Context(), garageID, customerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer history")
		return
	}
	if hasInvoices || hasJobCards {
		httputil.Error(w, 409, "conflict", "customer has invoice or job card history")
		return
	}
	if err := s.Store.DeleteCustomer(r.Context(), garageID, customerID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "customer not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not delete customer")
		return
	}
	w.WriteHeader(204)
}
