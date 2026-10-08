package store

import (
	"context"

	"garage-backend/internal/models"
)

const quotationColumns = `id, quotation_number, customer_id, vehicle_id, km_reading,
	overall_discount, tax_percent, per_item_tax, validity_days, status, notes, valid_until, created_at`

func scanQuotation(row scanner) (models.Quotation, error) {
	var q models.Quotation
	err := row.Scan(&q.ID, &q.QuotationNumber, &q.CustomerID, &q.VehicleID, &q.KmReading,
		&q.OverallDiscount, &q.TaxPercent, &q.PerItemTax, &q.ValidityDays, &q.Status, &q.Notes,
		&q.ValidUntil, &q.CreatedAt)
	return q, mapPGError(err)
}

func (s *Store) ListQuotations(ctx context.Context, garageID string) ([]models.Quotation, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+quotationColumns+` FROM quotations WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	quotes := []models.Quotation{}
	for rows.Next() {
		q, err := scanQuotation(rows)
		if err != nil {
			return nil, err
		}
		quotes = append(quotes, q)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	items, err := s.ItemsByGarage(ctx, "quotation_items", garageID)
	if err != nil {
		return nil, err
	}
	for i := range quotes {
		quotes[i].Items = items[quotes[i].ID]
		if quotes[i].Items == nil {
			quotes[i].Items = []models.MaintenanceItem{}
		}
	}
	return quotes, nil
}

func (s *Store) QuotationByID(ctx context.Context, garageID, quotationID string) (models.Quotation, error) {
	q, err := scanQuotation(s.Pool.QueryRow(ctx,
		`SELECT `+quotationColumns+` FROM quotations WHERE garage_id = $1 AND id = $2`,
		garageID, quotationID))
	if err != nil {
		return models.Quotation{}, err
	}
	q.Items, err = s.ItemsOfParent(ctx, "quotation_items", q.ID)
	return q, err
}

func (s *Store) CreateQuotation(ctx context.Context, garageID string, q models.Quotation) (models.Quotation, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Quotation{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	created, err := scanQuotation(tx.QueryRow(ctx,
		`INSERT INTO quotations (garage_id, quotation_number, customer_id, vehicle_id, km_reading,
		                        overall_discount, tax_percent, validity_days, status, notes, valid_until,
		                        per_item_tax)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING `+quotationColumns,
		garageID, q.QuotationNumber, q.CustomerID, q.VehicleID, q.KmReading,
		q.OverallDiscount, q.TaxPercent, q.ValidityDays, q.Status, q.Notes, q.ValidUntil,
		q.PerItemTax))
	if err != nil {
		return models.Quotation{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "quotation_items", created.ID, q.Items); err != nil {
		return models.Quotation{}, err
	}
	created.Items = q.Items
	return created, tx.Commit(ctx)
}

// quotation_number and created_at are immutable (convention 9).
func (s *Store) UpdateQuotation(ctx context.Context, garageID string, q models.Quotation) (models.Quotation, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Quotation{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	updated, err := scanQuotation(tx.QueryRow(ctx,
		`UPDATE quotations SET customer_id=$3, vehicle_id=$4, km_reading=$5,
		                        overall_discount=$6, tax_percent=$7, validity_days=$8,
		                        status=$9, notes=$10, valid_until=$11, per_item_tax=$12
		 WHERE garage_id = $1 AND id = $2 RETURNING `+quotationColumns,
		garageID, q.ID, q.CustomerID, q.VehicleID, q.KmReading, q.OverallDiscount,
		q.TaxPercent, q.ValidityDays, q.Status, q.Notes, q.ValidUntil, q.PerItemTax))
	if err != nil {
		return models.Quotation{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "quotation_items", updated.ID, q.Items); err != nil {
		return models.Quotation{}, err
	}
	updated.Items = q.Items
	return updated, tx.Commit(ctx)
}

func (s *Store) UpdateQuotationStatus(ctx context.Context, garageID, quotationID, status string) (models.Quotation, error) {
	q, err := scanQuotation(s.Pool.QueryRow(ctx,
		`UPDATE quotations SET status = $3 WHERE garage_id = $1 AND id = $2 RETURNING `+quotationColumns,
		garageID, quotationID, status))
	if err != nil {
		return models.Quotation{}, err
	}
	q.Items, err = s.ItemsOfParent(ctx, "quotation_items", q.ID)
	return q, err
}
