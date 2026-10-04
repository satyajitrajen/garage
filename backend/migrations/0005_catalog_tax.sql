-- +goose Up
-- Price-list items remember their GST rate so picked lines keep it.
ALTER TABLE catalog_items ADD COLUMN IF NOT EXISTS tax_percent numeric(5,2) NOT NULL DEFAULT 0;

-- +goose Down
ALTER TABLE catalog_items DROP COLUMN IF EXISTS tax_percent;
