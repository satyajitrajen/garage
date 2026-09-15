package api

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
)

// GET /api/garages/{garageId}/billing → plan + subscription + trial state.
func (s *Server) getBilling(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	sub, err := s.Store.SubscriptionByGarage(r.Context(), garageID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load subscription")
		return
	}
	st, _ := s.Store.BillingState(r.Context(), garageID)
	httputil.JSON(w, 200, map[string]any{
		"plan_tier": sub.PlanCode, "status": sub.Status,
		"trial_ends_at": sub.TrialEndsAt, "current_period_end": sub.CurrentPeriodEnd,
		"subscription_status": st.SubscriptionStatus,
		"provider_subscription_id": sub.ProviderSubscription,
		"razorpay_key_id":          s.Config.RazorpayKeyID,
	})
}

// POST /api/garages/{garageId}/billing/checkout {plan: monthly|yearly}
// Returns Razorpay plan id + key so Flutter can open Checkout. The actual
// subscription object is created client-side via Razorpay; activation arrives
// via webhook. When Razorpay is unconfigured, returns manual instructions.
func (s *Server) createCheckout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Plan string `json:"plan"`
	}
	if !httputil.Decode(w, r, &req) || (req.Plan != "monthly" && req.Plan != "yearly") {
		httputil.Error(w, 400, "invalid_request", "plan must be monthly or yearly")
		return
	}
	planID := s.Config.RazorpayPlanMonthly
	if req.Plan == "yearly" {
		planID = s.Config.RazorpayPlanYearly
	}
	if s.Config.RazorpayKeyID == "" || planID == "" {
		httputil.JSON(w, 200, map[string]any{
			"configured": false,
			"message":    "Razorpay not configured; contact support to activate.",
		})
		return
	}
	httputil.JSON(w, 200, map[string]any{
		"configured": true, "key_id": s.Config.RazorpayKeyID,
		"plan_id": planID, "plan": req.Plan,
	})
}

// POST /api/billing/webhooks/razorpay — public, HMAC-verified, idempotent.
func (s *Server) razorpayWebhook(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		httputil.Error(w, 400, "invalid_request", "body too large")
		return
	}
	if s.Config.RazorpayWebhookSecret != "" {
		mac := hmac.New(sha256.New, []byte(s.Config.RazorpayWebhookSecret))
		mac.Write(raw)
		want := hex.EncodeToString(mac.Sum(nil))
		if !hmac.Equal([]byte(want), []byte(r.Header.Get("X-Razorpay-Signature"))) {
			httputil.Error(w, 401, "unauthorized", "bad webhook signature")
			return
		}
	}
	var evt struct {
		ID      string `json:"id"`
		Event   string `json:"event"`
		Payload struct {
			Subscription struct {
				ID     string `json:"id"`
				Status string `json:"status"`
				Notes  struct {
					GarageID string `json:"garage_id"`
				} `json:"notes"`
			} `json:"subscription"`
			Payment struct {
				SubscriptionID string `json:"subscription_id"`
			} `json:"payment"`
		} `json:"payload"`
	}
	// Razorpay nests under payload.subscription.entity; accept both shapes.
	var generic map[string]any
	_ = json.Unmarshal(raw, &generic)
	_ = json.Unmarshal(raw, &evt)
	if evt.ID == "" {
		if v, _ := generic["id"].(string); v != "" {
			evt.ID = v
		}
	}
	if evt.Event == "" {
		if v, _ := generic["event"].(string); v != "" {
			evt.Event = v
		}
	}
	garageID := evt.Payload.Subscription.Notes.GarageID
	if garageID == "" {
		// Real Razorpay shape: payload.subscription.entity.{id, notes}.
		if p, ok := generic["payload"].(map[string]any); ok {
			if sub, ok := p["subscription"].(map[string]any); ok {
				if ent, ok := sub["entity"].(map[string]any); ok {
					if notes, ok := ent["notes"].(map[string]any); ok {
						garageID, _ = notes["garage_id"].(string)
					}
					if evt.Payload.Subscription.ID == "" {
						evt.Payload.Subscription.ID, _ = ent["id"].(string)
					}
				}
			}
			// payment.* events reference the subscription, not the garage:
			// resolve via the stored provider subscription id.
			if garageID == "" {
				if pay, ok := p["payment"].(map[string]any); ok {
					if ent, ok := pay["entity"].(map[string]any); ok {
						if subID, _ := ent["subscription_id"].(string); subID != "" {
							if gid, err := s.Store.GarageIDByProviderSubscription(r.Context(), subID); err == nil {
								garageID = gid
								evt.Payload.Subscription.ID = subID
							}
						}
					}
				}
			}
		}
	}
	if evt.ID == "" {
		httputil.Error(w, 400, "invalid_request", "missing event id")
		return
	}
	seen, _ := s.Store.SubscriptionEventSeen(r.Context(), evt.ID)
	if !seen {
		_ = s.Store.RecordSubscriptionEvent(r.Context(), garageID, "razorpay", evt.ID, evt.Event, string(raw))
	}
	// Map Razorpay events → subscription status. UpdateSubscriptionStatus
	// syncs the garages row too, so the subscription gate follows payment.
	var status string
	switch evt.Event {
	case "subscription.activated", "subscription.charged", "subscription.updated":
		status = "active"
	case "subscription.halted", "subscription.paused", "payment.failed":
		status = "past_due"
	case "subscription.cancelled", "subscription.completed":
		status = "cancelled"
	}
	if status != "" && garageID != "" {
		_ = s.Store.UpdateSubscriptionStatus(r.Context(), garageID, status, evt.Payload.Subscription.ID, "")
	}
	httputil.JSON(w, 200, map[string]string{"status": "ok"})
}

// POST /api/garages/{garageId}/billing/cancel (owner) → mark cancelled.
func (s *Server) cancelBilling(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	if auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "owner only")
		return
	}
	sub, err := s.Store.SubscriptionByGarage(r.Context(), garageID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load subscription")
		return
	}
	_ = s.Store.UpdateSubscriptionStatus(r.Context(), garageID, "cancelled", sub.ProviderSubscription, sub.PlanCode)
	s.Store.Audit(r.Context(), garageID, auth.UserID(r.Context()), "billing.cancel", "subscription", sub.ID, nil)
	httputil.JSON(w, 200, map[string]string{"status": "cancelled"})
}

// GET /api/admin/garages + POST suspend/unsuspend + GET metrics (superadmin).
func (s *Server) adminGarages(w http.ResponseWriter, r *http.Request) {
	limit, offset, _ := pageParams(r)
	if limit == 0 {
		limit = 50
	}
	rows, err := s.Store.Pool.Query(r.Context(),
		`SELECT id, name, plan_tier, subscription_status, trial_ends_at, suspended_at, created_at
		 FROM garages ORDER BY created_at DESC LIMIT $1 OFFSET $2`, limit, offset)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list garages")
		return
	}
	defer rows.Close()
	type g struct {
		ID, Name, Plan, Status string
		TrialEndsAt           any
		SuspendedAt           any
		CreatedAt             any
	}
	var out []g
	for rows.Next() {
		var x g
		if err := rows.Scan(&x.ID, &x.Name, &x.Plan, &x.Status, &x.TrialEndsAt, &x.SuspendedAt, &x.CreatedAt); err != nil {
			httputil.Error(w, 500, "internal", "could not scan garages")
			return
		}
		out = append(out, x)
	}
	if out == nil {
		out = []g{}
	}
	httputil.JSON(w, 200, map[string]any{"items": out, "limit": limit, "offset": offset})
}

func (s *Server) adminSuspend(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "garageId")
	if _, err := parseID(id); err != nil {
		httputil.Error(w, 404, "not_found", "garage not found")
		return
	}
	if err := s.Store.SuspendGarage(r.Context(), id, true); err != nil {
		httputil.Error(w, 500, "internal", "could not suspend")
		return
	}
	s.Store.Audit(r.Context(), id, auth.UserID(r.Context()), "admin.suspend", "garage", id, nil)
	httputil.JSON(w, 200, map[string]string{"status": "suspended"})
}

func (s *Server) adminUnsuspend(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "garageId")
	if _, err := parseID(id); err != nil {
		httputil.Error(w, 404, "not_found", "garage not found")
		return
	}
	if err := s.Store.SuspendGarage(r.Context(), id, false); err != nil {
		httputil.Error(w, 500, "internal", "could not unsuspend")
		return
	}
	s.Store.Audit(r.Context(), id, auth.UserID(r.Context()), "admin.unsuspend", "garage", id, nil)
	httputil.JSON(w, 200, map[string]string{"status": "active"})
}

func (s *Server) adminMetrics(w http.ResponseWriter, r *http.Request) {
	var total, trialing, active, pastDue, suspended int
	_ = s.Store.Pool.QueryRow(r.Context(),
		`SELECT COUNT(*),
		 COUNT(*) FILTER (WHERE subscription_status='trialing'),
		 COUNT(*) FILTER (WHERE subscription_status='active'),
		 COUNT(*) FILTER (WHERE subscription_status='past_due'),
		 COUNT(*) FILTER (WHERE subscription_status='suspended')
		 FROM garages`).Scan(&total, &trialing, &active, &pastDue, &suspended)
	httputil.JSON(w, 200, map[string]any{
		"garages_total": total, "trialing": trialing, "active": active,
		"past_due": pastDue, "suspended": suspended,
	})
}

func (s *Server) adminAudit(w http.ResponseWriter, r *http.Request) {
	limit, offset, _ := pageParams(r)
	if limit == 0 {
		limit = 50
	}
	garage := r.URL.Query().Get("garage_id")
	q := `SELECT id, garage_id, actor_id, action, entity, entity_id, created_at FROM audit_log ORDER BY created_at DESC LIMIT $1 OFFSET $2`
	args := []any{limit, offset}
	if garage != "" {
		if _, err := parseID(garage); err != nil {
			httputil.Error(w, 400, "invalid_request", "invalid garage_id")
			return
		}
		q = `SELECT id, garage_id, actor_id, action, entity, entity_id, created_at FROM audit_log WHERE garage_id=$3 ORDER BY created_at DESC LIMIT $1 OFFSET $2`
		args = append(args, garage)
	}
	dbRows, err := s.Store.Pool.Query(r.Context(), q, args...)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load audit")
		return
	}
	defer dbRows.Close()
	var out []map[string]any
	for dbRows.Next() {
		var id, gid, aid, action, entity, eid any
		var at any
		if err := dbRows.Scan(&id, &gid, &aid, &action, &entity, &eid, &at); err != nil {
			httputil.Error(w, 500, "internal", "could not scan audit")
			return
		}
		out = append(out, map[string]any{"id": id, "garage_id": gid, "actor_id": aid,
			"action": action, "entity": entity, "entity_id": eid, "created_at": at})
	}
	if out == nil {
		out = []map[string]any{}
	}
	httputil.JSON(w, 200, map[string]any{"items": out})
}
