package api

import (
	"net/http"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
)

func (s *Server) listCatalog(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListCatalogItems(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list catalog")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}
