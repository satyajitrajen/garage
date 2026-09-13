-- +goose Up
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email citext NOT NULL UNIQUE,
    password_hash text NOT NULL,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE garages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE memberships (
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('owner', 'staff')),
    permissions text[] NOT NULL DEFAULT '{}',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (garage_id, user_id)
);
CREATE INDEX idx_memberships_user ON memberships(user_id);

CREATE TABLE refresh_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- Profile mirrors GarageProfile, config mirrors AppConfig defaults from the
-- Flutter app (lib/data/app_config.dart). One row per garage, created lazily.
CREATE TABLE garage_settings (
    garage_id uuid PRIMARY KEY REFERENCES garages(id) ON DELETE CASCADE,
    profile_name text NOT NULL DEFAULT '',
    tagline text NOT NULL DEFAULT '',
    address_line text NOT NULL DEFAULT '',
    city text NOT NULL DEFAULT '',
    phone text NOT NULL DEFAULT '',
    email text NOT NULL DEFAULT '',
    gstin text NOT NULL DEFAULT '',
    upi_id text NOT NULL DEFAULT '',
    default_tax_percent numeric(12,2) NOT NULL DEFAULT 18.0,
    tax_percent_options jsonb NOT NULL DEFAULT '[0,12,18,28]',
    invoice_due_days int NOT NULL DEFAULT 7,
    quotation_validity_options jsonb NOT NULL DEFAULT '[7,15,30]',
    working_days_per_month int NOT NULL DEFAULT 26,
    promised_delivery_hours int NOT NULL DEFAULT 6,
    invoice_notes text NOT NULL DEFAULT 'Thank you for choosing us! Standard warranty applies.',
    invoice_terms text NOT NULL DEFAULT 'All parts replaced carry manufacturer warranty. Labour warranty 30 days.',
    default_received_by text NOT NULL DEFAULT 'Cashier'
);

-- +goose Down
DROP TABLE IF EXISTS garage_settings;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS memberships;
DROP TABLE IF EXISTS garages;
DROP TABLE IF EXISTS users;
DROP EXTENSION IF EXISTS citext;
