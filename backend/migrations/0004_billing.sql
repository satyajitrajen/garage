-- +goose Up
-- SaaS billing: plans, subscriptions, idempotent provider webhook events.

CREATE TABLE IF NOT EXISTS plans (
    code text PRIMARY KEY,
    name text NOT NULL,
    price_paise int NOT NULL DEFAULT 0,
    interval text NOT NULL DEFAULT 'monthly' CHECK (interval IN ('monthly', 'yearly', 'one_time')),
    limits jsonb NOT NULL DEFAULT '{}'
);

INSERT INTO plans (code, name, price_paise, interval, limits) VALUES
    ('trial', 'Trial', 0, 'monthly', '{"invoices_per_month": 100, "staff": 10}'),
    ('monthly', 'Pro Monthly', 99900, 'monthly', '{"invoices_per_month": 2000, "staff": 50}'),
    ('yearly', 'Pro Yearly', 999900, 'yearly', '{"invoices_per_month": 2000, "staff": 50}')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS subscriptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL UNIQUE REFERENCES garages(id) ON DELETE CASCADE,
    plan_code text NOT NULL DEFAULT 'trial' REFERENCES plans(code),
    provider text NOT NULL DEFAULT 'razorpay',
    provider_subscription_id text UNIQUE,
    status text NOT NULL DEFAULT 'trialing'
        CHECK (status IN ('trialing','active','past_due','cancelled','suspended')),
    trial_ends_at timestamptz NOT NULL DEFAULT now() + interval '14 days',
    current_period_end timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_subscriptions_garage ON subscriptions(garage_id);

CREATE TABLE IF NOT EXISTS subscription_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid REFERENCES garages(id) ON DELETE CASCADE,
    provider text NOT NULL DEFAULT 'razorpay',
    event_id text NOT NULL UNIQUE,
    type text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_subscription_events_garage ON subscription_events(garage_id);

-- +goose Down
DROP TABLE IF EXISTS subscription_events;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS plans;
