-- +goose Up
-- Receipt photos live in the database: the host's disk is not persistent.
CREATE TABLE IF NOT EXISTS expense_receipts (
    expense_id uuid PRIMARY KEY REFERENCES expenses(id) ON DELETE CASCADE,
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    content_type text NOT NULL,
    data bytea NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS expense_receipts;
