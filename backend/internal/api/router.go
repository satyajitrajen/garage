// Package api holds the chi router and HTTP handlers, one file per domain.
package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

type Server struct {
	Store  *store.Store
	Issuer *auth.TokenIssuer
}

func NewRouter(s *Server) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Logger, middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Authorization", "Content-Type", "X-Garage-Id"},
		MaxAge:         300,
	}))

	r.Get("/api/health", func(w http.ResponseWriter, _ *http.Request) {
		httputil.JSON(w, 200, map[string]string{"status": "ok"})
	})

	r.Route("/api", func(r chi.Router) {
		r.Post("/auth/register", s.handleRegister)
		r.Post("/auth/login", s.handleLogin)
		r.Post("/auth/refresh", s.handleRefresh)
		r.Post("/auth/logout", s.handleLogout)

		r.Group(func(r chi.Router) {
			r.Use(auth.RequireAuth(s.Issuer, s.Store))
			r.Get("/me", s.handleMe)

			r.Route("/garages/{garageId}", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Route("/members", func(r chi.Router) {
					r.Use(auth.RequirePermission("staff.manage"))
					r.Get("/", s.listMembers)
					r.Post("/", s.createMember)
					r.Patch("/{userId}", s.updateMember)
					r.Delete("/{userId}", s.deleteMember)
				})
				r.Route("/settings", func(r chi.Router) {
					r.Use(auth.RequirePermission("settings.manage"))
					r.Get("/", s.getSettings)
					r.Patch("/", s.patchSettings)
				})
			})

			// Domain routes are flat under /api and scoped by the X-Garage-Id
			// header (spec §5); RequireGarage resolves the header since there
			// is no {garageId} URL segment here.
			r.Route("/customers", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("customers.manage"))
				r.Get("/", s.listCustomers)
				r.Post("/", s.createCustomer)
				r.Put("/{customerId}", s.updateCustomer)
				r.Delete("/{customerId}", s.deleteCustomer)
			})

			r.Route("/vehicles", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("vehicles.manage"))
				r.Get("/", s.listVehicles)
				r.Post("/", s.createVehicle)
				r.Put("/{vehicleId}", s.updateVehicle)
				r.Delete("/{vehicleId}", s.deleteVehicle)
			})

			r.Route("/staff", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("staff.manage"))
				r.Get("/", s.listStaff)
				r.Post("/", s.createStaff)
				r.Put("/{staffId}", s.updateStaff)
				r.Delete("/{staffId}", s.deleteStaff)
			})
		})
	})

	r.NotFound(func(w http.ResponseWriter, _ *http.Request) {
		httputil.Error(w, 404, "not_found", "route not found")
	})
	r.MethodNotAllowed(func(w http.ResponseWriter, _ *http.Request) {
		httputil.Error(w, 405, "method_not_allowed", "method not allowed")
	})
	return r
}
