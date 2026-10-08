-- +goose Up
-- Documents created from now on tax each line at its own rate. Existing rows
-- keep the old single document-level rate so their totals never change.
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS per_item_tax boolean NOT NULL DEFAULT false;
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS per_item_tax boolean NOT NULL DEFAULT false;
-- New garages also get the 5% GST slab; existing garages keep their saved list.
ALTER TABLE garage_settings ALTER COLUMN tax_percent_options SET DEFAULT '[0,5,12,18,28]';

-- +goose Down
ALTER TABLE garage_settings ALTER COLUMN tax_percent_options SET DEFAULT '[0,12,18,28]';
ALTER TABLE quotations DROP COLUMN IF EXISTS per_item_tax;
ALTER TABLE invoices DROP COLUMN IF EXISTS per_item_tax;
