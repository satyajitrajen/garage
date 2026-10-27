-- +goose Up
-- Account deletion is scheduled, not immediate: the user has 7 days to sign
-- in and cancel before the purge job deletes the account for good.
ALTER TABLE users ADD COLUMN IF NOT EXISTS deletion_scheduled_at timestamptz;
CREATE INDEX IF NOT EXISTS users_deletion_scheduled_idx
    ON users (deletion_scheduled_at) WHERE deletion_scheduled_at IS NOT NULL;

-- +goose Down
DROP INDEX IF EXISTS users_deletion_scheduled_idx;
ALTER TABLE users DROP COLUMN IF EXISTS deletion_scheduled_at;
