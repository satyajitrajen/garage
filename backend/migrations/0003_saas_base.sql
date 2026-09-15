-- +goose Up
-- SaaS base: tenant lifecycle, identity proofing, invites, doc sequences, audit.

ALTER TABLE garages ADD COLUMN IF NOT EXISTS plan_tier text NOT NULL DEFAULT 'trial';
ALTER TABLE garages ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz NOT NULL DEFAULT now() + interval '14 days';
ALTER TABLE garages ADD COLUMN IF NOT EXISTS subscription_status text NOT NULL DEFAULT 'trialing';
ALTER TABLE garages ADD COLUMN IF NOT EXISTS suspended_at timestamptz;

ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_superadmin boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS email_verifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_email_verifications_user ON email_verifications(user_id);

CREATE TABLE IF NOT EXISTS password_resets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    used_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_password_resets_user ON password_resets(user_id);

CREATE TABLE IF NOT EXISTS garage_invites (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    email citext NOT NULL,
    role text NOT NULL DEFAULT 'staff' CHECK (role IN ('owner', 'staff')),
    permissions text[] NOT NULL DEFAULT '{}',
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days',
    accepted_at timestamptz,
    created_by uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_garage_invites_garage ON garage_invites(garage_id);

-- Per-garage monotonic counters for server-generated doc numbers.
CREATE TABLE IF NOT EXISTS doc_sequences (
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('jobcard', 'quotation', 'invoice')),
    last_n bigint NOT NULL DEFAULT 1000,
    PRIMARY KEY (garage_id, kind)
);

CREATE TABLE IF NOT EXISTS audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid REFERENCES garages(id) ON DELETE CASCADE,
    actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
    action text NOT NULL,
    entity text NOT NULL DEFAULT '',
    entity_id text NOT NULL DEFAULT '',
    meta jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_garage ON audit_log(garage_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS doc_sequences;
DROP TABLE IF EXISTS garage_invites;
DROP TABLE IF EXISTS password_resets;
DROP TABLE IF EXISTS email_verifications;
ALTER TABLE users DROP COLUMN IF EXISTS is_superadmin;
ALTER TABLE users DROP COLUMN IF EXISTS email_verified_at;
ALTER TABLE garages DROP COLUMN IF EXISTS suspended_at;
ALTER TABLE garages DROP COLUMN IF EXISTS subscription_status;
ALTER TABLE garages DROP COLUMN IF EXISTS trial_ends_at;
ALTER TABLE garages DROP COLUMN IF EXISTS plan_tier;
