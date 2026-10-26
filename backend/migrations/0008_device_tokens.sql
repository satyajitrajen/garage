-- +goose Up
-- FCM registration tokens, one row per app install. A token follows whoever
-- last signed in on that device, so re-registering moves it.
CREATE TABLE IF NOT EXISTS device_tokens (
    token      text PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    garage_id  uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    platform   text NOT NULL DEFAULT '',
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS device_tokens_garage_idx ON device_tokens (garage_id);

-- +goose Down
DROP TABLE IF EXISTS device_tokens;
