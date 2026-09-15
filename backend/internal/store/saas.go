package store

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

// NextDocNumber atomically bumps the per-garage counter for kind
// (jobcard|quotation|invoice) and returns the formatted number.
// Prefixes mirror the Flutter provider: JC-<n>, EST-<n>, INV-<YYYY>-<n>.
func (s *Store) NextDocNumber(ctx context.Context, garageID, kind string) (string, error) {
	switch kind {
	case "jobcard", "quotation", "invoice":
	default:
		return "", fmt.Errorf("unknown doc kind %q", kind)
	}
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))

	var n int64
	err = tx.QueryRow(ctx,
		`INSERT INTO doc_sequences (garage_id, kind, last_n) VALUES ($1, $2, 1001)
		 ON CONFLICT (garage_id, kind) DO UPDATE SET last_n = doc_sequences.last_n + 1
		 RETURNING last_n`, garageID, kind).Scan(&n)
	if err != nil {
		return "", mapPGError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	switch kind {
	case "jobcard":
		return fmt.Sprintf("JC-%d", n), nil
	case "quotation":
		return fmt.Sprintf("EST-%d", n), nil
	default:
		return fmt.Sprintf("INV-%d-%d", time.Now().Year(), n), nil
	}
}

// GarageBillingState reports trial/subscription/suspension for gating.
type GarageBillingState struct {
	PlanTier           string
	SubscriptionStatus string
	TrialEndsAt        time.Time
	SuspendedAt        *time.Time
}

// BillingState loads garages row state.
func (s *Store) BillingState(ctx context.Context, garageID string) (GarageBillingState, error) {
	var st GarageBillingState
	err := s.Pool.QueryRow(ctx,
		`SELECT plan_tier, subscription_status, trial_ends_at, suspended_at
		 FROM garages WHERE id = $1`, garageID).
		Scan(&st.PlanTier, &st.SubscriptionStatus, &st.TrialEndsAt, &st.SuspendedAt)
	return st, mapPGError(err)
}

// PastDueGracePeriod is how long writes stay allowed after a payment fails
// before the gate blocks with 402. Anchored to the last status change
// (subscriptions.updated_at), which only moves on real transitions.
const PastDueGracePeriod = 72 * time.Hour

// Writable reports whether the garage may perform mutating calls.
// trialing/active → yes; past_due within grace → yes; else no.
func (s *Store) Writable(ctx context.Context, garageID string) (bool, string) {
	st, err := s.BillingState(ctx, garageID)
	if err != nil {
		return false, "unknown"
	}
	if st.SuspendedAt != nil || st.SubscriptionStatus == "suspended" || st.SubscriptionStatus == "cancelled" {
		return false, st.SubscriptionStatus
	}
	if st.SubscriptionStatus == "trialing" {
		if time.Now().After(st.TrialEndsAt) {
			return false, "trial_expired"
		}
		return true, st.SubscriptionStatus
	}
	if st.SubscriptionStatus == "past_due" {
		changedAt, err := s.SubscriptionStatusChangedAt(ctx, garageID)
		if err != nil {
			return false, st.SubscriptionStatus
		}
		if time.Now().Before(changedAt.Add(PastDueGracePeriod)) {
			return true, st.SubscriptionStatus
		}
		return false, st.SubscriptionStatus
	}
	return true, st.SubscriptionStatus
}

// Audit inserts a best-effort audit row; callers ignore errors.
func (s *Store) Audit(ctx context.Context, garageID, actorID, action, entity, entityID string, meta any) {
	metaJSON := "{}"
	if meta != nil {
		if b, err := json.Marshal(meta); err == nil {
			metaJSON = string(b)
		}
	}
	var gid, aid any
	if garageID != "" {
		gid = garageID
	}
	if actorID != "" {
		aid = actorID
	}
	_, _ = s.Pool.Exec(ctx,
		`INSERT INTO audit_log (garage_id, actor_id, action, entity, entity_id, meta)
		 VALUES ($1,$2,$3,$4,$5,$6::jsonb)`, gid, aid, action, entity, entityID, metaJSON)
}
