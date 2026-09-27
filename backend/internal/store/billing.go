package store

import (
	"context"
	"time"
)

type Subscription struct {
	ID                   string     `json:"id"`
	GarageID             string     `json:"garage_id"`
	PlanCode             string     `json:"plan_code"`
	Provider             string     `json:"provider"`
	ProviderSubscription string     `json:"provider_subscription_id"`
	Status               string     `json:"status"`
	TrialEndsAt          time.Time  `json:"trial_ends_at"`
	CurrentPeriodEnd     *time.Time `json:"current_period_end"`
}

func scanSubscription(row scanner) (Subscription, error) {
	var s Subscription
	err := row.Scan(&s.ID, &s.GarageID, &s.PlanCode, &s.Provider,
		&s.ProviderSubscription, &s.Status, &s.TrialEndsAt, &s.CurrentPeriodEnd)
	return s, mapPGError(err)
}

const subColumns = `id, garage_id, plan_code, provider, provider_subscription_id, status, trial_ends_at, current_period_end`

// subSelect mirrors subColumns but coalesces the nullable provider id so it
// scans into a plain string.
const subSelect = `id, garage_id, plan_code, provider, COALESCE(provider_subscription_id,''), status, trial_ends_at, current_period_end`

func (s *Store) EnsureSubscription(ctx context.Context, garageID string, trialDays int) (Subscription, error) {
	if trialDays <= 0 {
		trialDays = 14
	}
	var sub Subscription
	err := s.Pool.QueryRow(ctx,
		`INSERT INTO subscriptions (garage_id, plan_code, status, trial_ends_at)
		 VALUES ($1,'trial','trialing', now() + ($2 || ' days')::interval)
		 ON CONFLICT (garage_id) DO UPDATE SET garage_id = EXCLUDED.garage_id
		 RETURNING `+subSelect, garageID, itoa(trialDays)).Scan(
		&sub.ID, &sub.GarageID, &sub.PlanCode, &sub.Provider,
		&sub.ProviderSubscription, &sub.Status, &sub.TrialEndsAt, &sub.CurrentPeriodEnd)
	if err != nil {
		return sub, mapPGError(err)
	}
	return sub, nil
}

func itoa(n int) string {
	if n < 0 {
		n = 0
	}
	// small int→string without fmt import cycle concerns
	digits := "0123456789"
	if n == 0 {
		return "0"
	}
	out := ""
	for n > 0 {
		out = string(digits[n%10]) + out
		n /= 10
	}
	return out
}

func (s *Store) SubscriptionByGarage(ctx context.Context, garageID string) (Subscription, error) {
	return scanSubscription(s.Pool.QueryRow(ctx,
		`SELECT `+subSelect+` FROM subscriptions WHERE garage_id = $1`, garageID))
}

func (s *Store) UpdateSubscriptionStatus(ctx context.Context, garageID, status, providerSubID, planCode string) error {
	// Single sync point for both status holders: subscriptions.* is the
	// billing history, garages.* is what the subscription gate reads.
	// Updating only one would strand garages (e.g. pay-after-suspend would
	// never re-enable writes).
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	if _, err := tx.Exec(ctx,
		`UPDATE subscriptions SET status=$2, provider_subscription_id=COALESCE(NULLIF($3,''),provider_subscription_id),
		 plan_code=COALESCE(NULLIF($4,''),plan_code),
		 updated_at=CASE WHEN status IS DISTINCT FROM $2 THEN now() ELSE updated_at END
		 WHERE garage_id=$1`,
		garageID, status, providerSubID, planCode); err != nil {
		return mapPGError(err)
	}
	switch status {
	case "active", "trialing":
		_, err = tx.Exec(ctx,
			`UPDATE garages SET subscription_status=$2, suspended_at=NULL WHERE id=$1`,
			garageID, status)
	case "past_due":
		_, err = tx.Exec(ctx,
			`UPDATE garages SET subscription_status='past_due' WHERE id=$1`, garageID)
	default: // cancelled, suspended, unknown provider states
		_, err = tx.Exec(ctx,
			`UPDATE garages SET subscription_status=$2,
			 suspended_at=COALESCE(suspended_at, now()) WHERE id=$1`,
			garageID, status)
	}
	if err != nil {
		return mapPGError(err)
	}
	return tx.Commit(ctx)
}

func (s *Store) RecordSubscriptionEvent(ctx context.Context, garageID, provider, eventID, typ, payload string) error {
	var gid any
	if garageID != "" {
		gid = garageID
	}
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO subscription_events (garage_id, provider, event_id, type, payload)
		 VALUES ($1,$2,$3,$4,$5::jsonb) ON CONFLICT (event_id) DO NOTHING`,
		gid, provider, eventID, typ, payload)
	return mapPGError(err)
}

func (s *Store) SubscriptionEventSeen(ctx context.Context, eventID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM subscription_events WHERE event_id = $1)`, eventID).Scan(&ok)
	return ok, err
}

func (s *Store) SuspendGarage(ctx context.Context, garageID string, suspend bool) error {
	// Mirrors UpdateSubscriptionStatus: keep both status holders in sync so
	// the gate (garages row) and billing views (subscriptions row) agree.
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	if suspend {
		if _, err := tx.Exec(ctx,
			`UPDATE garages SET suspended_at = now(), subscription_status='suspended' WHERE id=$1`, garageID); err != nil {
			return mapPGError(err)
		}
		if _, err := tx.Exec(ctx,
			`UPDATE subscriptions SET status='suspended', updated_at=now() WHERE garage_id=$1`, garageID); err != nil {
			return mapPGError(err)
		}
		return tx.Commit(ctx)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE garages SET suspended_at = NULL, subscription_status='active' WHERE id=$1`, garageID); err != nil {
		return mapPGError(err)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE subscriptions SET status='active', updated_at=now() WHERE garage_id=$1`, garageID); err != nil {
		return mapPGError(err)
	}
	return tx.Commit(ctx)
}

// GarageIDByProviderSubscription resolves a Razorpay subscription id back to
// its garage (payment.* webhooks reference the subscription, not the garage).
func (s *Store) GarageIDByProviderSubscription(ctx context.Context, providerSubID string) (string, error) {
	var gid string
	err := s.Pool.QueryRow(ctx,
		`SELECT garage_id FROM subscriptions WHERE provider_subscription_id = $1`, providerSubID).Scan(&gid)
	return gid, mapPGError(err)
}

// SubscriptionStatusChangedAt returns when the subscription last changed
// status (updated_at only moves on real transitions). The past-due grace
// window in Writable is anchored here.
func (s *Store) SubscriptionStatusChangedAt(ctx context.Context, garageID string) (time.Time, error) {
	var at time.Time
	err := s.Pool.QueryRow(ctx,
		`SELECT updated_at FROM subscriptions WHERE garage_id = $1`, garageID).Scan(&at)
	return at, mapPGError(err)
}

// SetProviderSubscription records the Razorpay subscription created at
// checkout so later payment.* webhooks can resolve the garage. Status is
// left alone: activation only ever arrives via a signed webhook.
func (s *Store) SetProviderSubscription(ctx context.Context, garageID, providerSubID, planCode string) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE subscriptions SET provider_subscription_id=$2, plan_code=$3 WHERE garage_id=$1`,
		garageID, providerSubID, planCode)
	return mapPGError(err)
}
