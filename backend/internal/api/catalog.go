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

func (s *Server) listCatalog(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListCatalogItems(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list catalog")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func validateCatalogItem(ci *models.CatalogItem) string {
	if ci.Name == "" {
		return "name is required"
	}
	if !models.ValidValue(ci.Category, models.ItemCategories...) {
		return "invalid category \"" + ci.Category + "\""
	}
	if ci.UnitPrice < 0 {
		return "unitPrice cannot be negative"
	}
	if ci.Unit == "" {
		ci.Unit = "Pcs"
	}
	return ""
}

func (s *Server) createCatalogItem(w http.ResponseWriter, r *http.Request) {
	var ci models.CatalogItem
	if !httputil.Decode(w, r, &ci) {
		return
	}
	if msg := validateCatalogItem(&ci); msg != "" {
		httputil.Error(w, 400, "invalid_request", msg)
		return
	}
	created, err := s.Store.CreateCatalogItem(r.Context(), auth.GarageID(r.Context()), ci)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create catalog item")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateCatalogItem(w http.ResponseWriter, r *http.Request) {
	var ci models.CatalogItem
	if !httputil.Decode(w, r, &ci) {
		return
	}
	ci.ID = chi.URLParam(r, "itemId")
	if _, err := parseID(ci.ID); err != nil {
		httputil.Error(w, 404, "not_found", "catalog item not found")
		return
	}
	if msg := validateCatalogItem(&ci); msg != "" {
		httputil.Error(w, 400, "invalid_request", msg)
		return
	}
	updated, err := s.Store.UpdateCatalogItem(r.Context(), auth.GarageID(r.Context()), ci)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "catalog item not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update catalog item")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteCatalogItem(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "itemId")
	if _, err := parseID(id); err != nil {
		httputil.Error(w, 404, "not_found", "catalog item not found")
		return
	}
	err := s.Store.DeleteCatalogItem(r.Context(), auth.GarageID(r.Context()), id)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "catalog item not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete catalog item")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
