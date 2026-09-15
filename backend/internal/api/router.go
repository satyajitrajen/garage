// Package api holds the chi router and HTTP handlers, one file per domain.
package api

import (
	"context"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"garage-backend/internal/auth"
	"garage-backend/internal/config"
	"garage-backend/internal/httputil"
	"garage-backend/internal/mail"
	"garage-backend/internal/store"
)

type Server struct {
	Store  *store.Store
	Issuer *auth.TokenIssuer
	Config config.Config
	Mail   mail.Sender
}

func NewRouter(s *Server) http.Handler {
	if s.Mail == nil {
		s.Mail = mail.LogSender{}
	}
	return NewRouterWithOrigins(s, []string{"*"})
}

func NewRouterWithOrigins(s *Server, allowedOrigins []string) http.Handler {
	if len(allowedOrigins) == 0 {
		allowedOrigins = []string{"*"}
	}
	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Logger, middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: allowedOrigins,
		AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Authorization", "Content-Type", "X-Garage-Id"},
		MaxAge:         300,
	}))

	r.Get("/api/health", func(w http.ResponseWriter, r *http.Request) {
		httputil.JSON(w, 200, map[string]string{"status": "ok"})
	})
	r.Get("/api/ready", func(w http.ResponseWriter, r *http.Request) {
		// Readiness probe: fail closed when the DB is unreachable so
		// orchestrators stop routing traffic instead of 500ing every call.
		if s == nil || s.Store == nil || s.Store.Pool == nil {
			httputil.Error(w, 503, "internal", "database unavailable")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := s.Store.Pool.Ping(ctx); err != nil {
			httputil.Error(w, 503, "internal", "database unavailable")
			return
		}
		httputil.JSON(w, 200, map[string]string{"status": "ok"})
	})

	r.Route("/api", func(r chi.Router) {
		// Generous per-IP budgets: the suite shares one loopback IP, and
		// bcrypt-12 already makes credential stuffing expensive. Tighten
		// via reverse-proxy limits in prod if needed.
		r.With(auth.RateLimit(200, time.Minute)).Post("/auth/register", s.handleRegister)
		r.With(auth.RateLimit(200, time.Minute)).Post("/auth/login", s.handleLogin)
		r.Post("/auth/refresh", s.handleRefresh)
		r.Post("/auth/logout", s.handleLogout)
		r.With(auth.RateLimit(100, time.Minute)).Post("/auth/verify-request", s.handleVerifyRequest)
		r.Post("/auth/verify", s.handleVerify)
		r.With(auth.RateLimit(100, time.Minute)).Post("/auth/forgot", s.handleForgot)
		r.With(auth.RateLimit(100, time.Minute)).Post("/auth/reset", s.handleReset)
		r.Post("/billing/webhooks/razorpay", s.razorpayWebhook)
		r.Get("/invites/{token}", s.getInvite)

		r.Group(func(r chi.Router) {
			r.Use(auth.RequireAuth(s.Issuer, s.Store))
			r.Get("/me", s.handleMe)
			r.Post("/invites/{token}/accept", s.acceptInvite)

			r.Route("/garages/{garageId}", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Route("/members", func(r chi.Router) {
					r.Use(auth.RequirePermission("staff.manage"))
					r.Get("/", s.listMembers)
					r.Post("/", s.createMember)
					r.Patch("/{userId}", s.updateMember)
					r.Delete("/{userId}", s.deleteMember)
				})
				r.Route("/invites", func(r chi.Router) {
					r.Use(auth.RequirePermission("staff.manage"))
					r.Post("/", s.createInvite)
					r.Delete("/{inviteId}", s.revokeInvite)
				})
				r.Route("/settings", func(r chi.Router) {
					r.Use(auth.RequirePermission("settings.manage"))
					r.Get("/", s.getSettings)
					r.Patch("/", s.patchSettings)
				})
				r.Route("/billing", func(r chi.Router) {
					r.Get("/", s.getBilling)
					r.Post("/checkout", s.createCheckout)
					r.Post("/cancel", s.cancelBilling)
				})
				r.Route("/doc-numbers", func(r chi.Router) {
					r.Get("/next", s.nextDocNumber)
				})
			})

			r.Route("/admin", func(r chi.Router) {
				r.Use(auth.RequireSuperadmin(s.Store))
				r.Get("/garages", s.adminGarages)
				r.Post("/garages/{garageId}/suspend", s.adminSuspend)
				r.Post("/garages/{garageId}/unsuspend", s.adminUnsuspend)
				r.Get("/metrics", s.adminMetrics)
				r.Get("/audit", s.adminAudit)
			})

			// Domain routes are flat under /api and scoped by the X-Garage-Id
			// header (spec §5); RequireGarage resolves the header since there
			// is no {garageId} URL segment here.
			r.Route("/customers", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("customers.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listCustomers)
				r.Post("/", s.createCustomer)
				r.Put("/{customerId}", s.updateCustomer)
				r.Delete("/{customerId}", s.deleteCustomer)
			})

			r.Route("/vehicles", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("vehicles.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listVehicles)
				r.Post("/", s.createVehicle)
				r.Put("/{vehicleId}", s.updateVehicle)
				r.Delete("/{vehicleId}", s.deleteVehicle)
			})

			r.Route("/staff", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("staff.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listStaff)
				r.Post("/", s.createStaff)
				r.Put("/{staffId}", s.updateStaff)
				r.Delete("/{staffId}", s.deleteStaff)
			})

			r.Route("/attendance", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("attendance.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listAttendance)
				r.Post("/", s.upsertAttendance)
			})

			r.Route("/salary-advances", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("advances.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listSalaryAdvances)
				r.Post("/", s.createSalaryAdvance)
				r.Post("/settle", s.settleSalaryAdvances)
			})

			r.Route("/jobcards", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("jobcards.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listJobCards)
				r.Post("/", s.createJobCard)
				r.Put("/{jobCardId}", s.updateJobCard)
				r.Post("/{jobCardId}/status", s.updateJobCardStatus)
				r.Post("/{jobCardId}/items", s.upsertJobCardItem)
				r.Delete("/{jobCardId}/items/{itemId}", s.deleteJobCardItem)
			})

			r.Route("/quotations", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("quotations.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listQuotations)
				r.Post("/", s.createQuotation)
				r.Put("/{quotationId}", s.updateQuotation)
				r.Post("/{quotationId}/status", s.updateQuotationStatus)
			})

			r.Route("/invoices", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("invoices.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listInvoices)
				r.Post("/", s.createInvoice)
				r.Put("/{invoiceId}", s.updateInvoice)
				r.Post("/{invoiceId}/cancel", s.cancelInvoice)
			})
			// Own top-level Route block (NOT nested in /invoices) because
			// payments.record is a different permission than invoices.manage.
			r.Route("/invoices/{invoiceId}/payments", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("payments.record"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Post("/", s.recordPayment)
			})

			r.Route("/expenses", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Use(auth.RequirePermission("expenses.manage"))
				r.Use(auth.SubscriptionGate(s.Store))
				r.Get("/", s.listExpenses)
				r.Post("/", s.createExpense)
				r.Put("/{expenseId}", s.updateExpense)
				r.Delete("/{expenseId}", s.deleteExpense)
			})
			// Catalog is readable by any member of the garage (spec §5).
			r.Route("/catalog", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Get("/", s.listCatalog)
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
