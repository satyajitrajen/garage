package store

import (
	"context"

	"garage-backend/internal/models"
)

const settingsColumns = `garage_id, profile_name, tagline, address_line, city, phone, email, gstin, upi_id,
	default_tax_percent, tax_percent_options, invoice_due_days, quotation_validity_options,
	working_days_per_month, promised_delivery_hours, invoice_notes, invoice_terms, default_received_by`

func scanSettings(row scanner) (models.GarageSettings, error) {
	var gs models.GarageSettings
	err := row.Scan(&gs.GarageID, &gs.Profile.Name, &gs.Profile.Tagline, &gs.Profile.AddressLine,
		&gs.Profile.City, &gs.Profile.Phone, &gs.Profile.Email, &gs.Profile.GSTIN, &gs.Profile.UPIID,
		&gs.DefaultTaxPercent, &gs.TaxPercentOptions, &gs.InvoiceDueDays, &gs.QuotationValidityOptions,
		&gs.WorkingDaysPerMonth, &gs.PromisedDeliveryHours, &gs.InvoiceNotes, &gs.InvoiceTerms,
		&gs.DefaultReceivedBy)
	return gs, mapPGError(err)
}

// GetOrCreateSettings lazily creates the defaults row for a garage, then
// returns it. Idempotent.
func (s *Store) GetOrCreateSettings(ctx context.Context, garageID string) (models.GarageSettings, error) {
	d := models.DefaultSettings(garageID)
	_, err := s.Pool.Exec(ctx, `INSERT INTO garage_settings
		(garage_id, profile_name, tagline, address_line, city, phone, email, gstin, upi_id,
		 default_tax_percent, tax_percent_options, invoice_due_days, quotation_validity_options,
		 working_days_per_month, promised_delivery_hours, invoice_notes, invoice_terms, default_received_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
		ON CONFLICT (garage_id) DO NOTHING`,
		d.GarageID, d.Profile.Name, d.Profile.Tagline, d.Profile.AddressLine, d.Profile.City,
		d.Profile.Phone, d.Profile.Email, d.Profile.GSTIN, d.Profile.UPIID, d.DefaultTaxPercent,
		d.TaxPercentOptions, d.InvoiceDueDays, d.QuotationValidityOptions, d.WorkingDaysPerMonth,
		d.PromisedDeliveryHours, d.InvoiceNotes, d.InvoiceTerms, d.DefaultReceivedBy)
	if err != nil {
		return models.GarageSettings{}, err
	}
	return scanSettings(s.Pool.QueryRow(ctx,
		`SELECT `+settingsColumns+` FROM garage_settings WHERE garage_id = $1`, garageID))
}

func (s *Store) UpdateSettings(ctx context.Context, gs models.GarageSettings) error {
	tag, err := s.Pool.Exec(ctx, `UPDATE garage_settings SET
		profile_name=$2, tagline=$3, address_line=$4, city=$5, phone=$6, email=$7, gstin=$8, upi_id=$9,
		default_tax_percent=$10, tax_percent_options=$11, invoice_due_days=$12, quotation_validity_options=$13,
		working_days_per_month=$14, promised_delivery_hours=$15, invoice_notes=$16, invoice_terms=$17,
		default_received_by=$18
		WHERE garage_id=$1`,
		gs.GarageID, gs.Profile.Name, gs.Profile.Tagline, gs.Profile.AddressLine, gs.Profile.City,
		gs.Profile.Phone, gs.Profile.Email, gs.Profile.GSTIN, gs.Profile.UPIID, gs.DefaultTaxPercent,
		gs.TaxPercentOptions, gs.InvoiceDueDays, gs.QuotationValidityOptions, gs.WorkingDaysPerMonth,
		gs.PromisedDeliveryHours, gs.InvoiceNotes, gs.InvoiceTerms, gs.DefaultReceivedBy)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
