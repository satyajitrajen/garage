package api

import (
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

const maxReceiptBytes = 5 << 20 // 5 MB

// The body is sniffed rather than trusting the client's Content-Type.
var receiptTypes = map[string]bool{
	"image/jpeg": true, "image/png": true, "image/webp": true, "application/pdf": true,
}

func (s *Server) putExpenseReceipt(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "expenseId")
	if _, err := parseID(id); err != nil {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxReceiptBytes+1))
	if err != nil || len(data) > maxReceiptBytes {
		httputil.Error(w, 413, "too_large", "receipt must be 5 MB or smaller")
		return
	}
	if len(data) == 0 {
		httputil.Error(w, 400, "invalid_request", "receipt body is empty")
		return
	}
	ct := http.DetectContentType(data)
	if !receiptTypes[ct] {
		httputil.Error(w, 415, "unsupported_type", "receipt must be a JPEG, PNG, WebP or PDF")
		return
	}
	err = s.Store.PutExpenseReceipt(r.Context(), auth.GarageID(r.Context()), id, ct, data)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not save receipt")
		return
	}
	httputil.JSON(w, 200, map[string]any{"receiptPath": store.ReceiptURL(id)})
}

func (s *Server) getExpenseReceipt(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "expenseId")
	if _, err := parseID(id); err != nil {
		httputil.Error(w, 404, "not_found", "receipt not found")
		return
	}
	ct, data, err := s.Store.GetExpenseReceipt(r.Context(), auth.GarageID(r.Context()), id)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "receipt not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load receipt")
		return
	}
	w.Header().Set("Content-Type", ct)
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	w.Header().Set("Cache-Control", "private, no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(200)
	_, _ = w.Write(data)
}

func (s *Server) deleteExpenseReceipt(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "expenseId")
	if _, err := parseID(id); err != nil {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	err := s.Store.DeleteExpenseReceipt(r.Context(), auth.GarageID(r.Context()), id)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not remove receipt")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
