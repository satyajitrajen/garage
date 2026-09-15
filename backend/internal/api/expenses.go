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

// validateExpense takes a pointer because it fills the constructor default
// paymentMode 'cash' when the client omits it.
func validateExpense(e *models.Expense) (string, int) {
	if e.Title == "" {
		return "title is required", 400
	}
	if e.Amount < 0 {
		return "amount cannot be negative", 400
	}
	if !models.ValidValue(e.Category, models.ExpenseCategories...) {
		return "invalid category \"" + e.Category + "\"", 400
	}
	if e.PaymentMode == "" {
		e.PaymentMode = "cash"
	}
	if !models.ValidValue(e.PaymentMode, models.PaymentModes...) {
		return "invalid paymentMode \"" + e.PaymentMode + "\"", 400
	}
	if _, err := time.Parse("2006-01-02", e.ExpenseDate); err != nil {
		return "expenseDate must be YYYY-MM-DD", 400
	}
	return "", 0
}

func (s *Server) listExpenses(w http.ResponseWriter, r *http.Request) {
	if limit, offset, ok := pageParams(r); ok {
		items, total, err := s.Store.ListExpensesPage(r.Context(), auth.GarageID(r.Context()), limit, offset)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not list expenses")
			return
		}
		httputil.JSON(w, 200, map[string]any{"items": items, "total": total, "limit": limit, "offset": offset})
		return
	}
	items, err := s.Store.ListExpenses(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list expenses")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createExpense(w http.ResponseWriter, r *http.Request) {
	var e models.Expense
	if !httputil.Decode(w, r, &e) {
		return
	}
	if msg, status := validateExpense(&e); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	created, err := s.Store.CreateExpense(r.Context(), auth.GarageID(r.Context()), e)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create expense")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateExpense(w http.ResponseWriter, r *http.Request) {
	var e models.Expense
	if !httputil.Decode(w, r, &e) {
		return
	}
	e.ID = chi.URLParam(r, "expenseId")
	if _, err := parseID(e.ID); err != nil {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if msg, status := validateExpense(&e); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	updated, err := s.Store.UpdateExpense(r.Context(), auth.GarageID(r.Context()), e)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update expense")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteExpense(w http.ResponseWriter, r *http.Request) {
	expenseID := chi.URLParam(r, "expenseId")
	if _, err := parseID(expenseID); err != nil {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	err := s.Store.DeleteExpense(r.Context(), auth.GarageID(r.Context()), expenseID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete expense")
		return
	}
	w.WriteHeader(204)
}
