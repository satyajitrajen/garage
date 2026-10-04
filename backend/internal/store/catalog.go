package store

import (
	"context"

	"garage-backend/internal/models"
)

const catalogColumns = `id, name, category, unit_price, tax_percent, unit, is_labour, part_number, notes, created_at`

func scanCatalogItem(row scanner) (models.CatalogItem, error) {
	var ci models.CatalogItem
	err := row.Scan(&ci.ID, &ci.Name, &ci.Category, &ci.UnitPrice, &ci.TaxPercent, &ci.Unit,
		&ci.IsLabour, &ci.PartNumber, &ci.Notes, &ci.CreatedAt)
	return ci, mapPGError(err)
}

func (s *Store) ListCatalogItems(ctx context.Context, garageID string) ([]models.CatalogItem, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+catalogColumns+` FROM catalog_items WHERE garage_id = $1 ORDER BY name, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.CatalogItem{}
	for rows.Next() {
		ci, err := scanCatalogItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, ci)
	}
	return items, rows.Err()
}

func (s *Store) CreateCatalogItem(ctx context.Context, garageID string, ci models.CatalogItem) (models.CatalogItem, error) {
	return scanCatalogItem(s.Pool.QueryRow(ctx,
		`INSERT INTO catalog_items (garage_id, name, category, unit_price, unit, is_labour, part_number, notes, tax_percent)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING `+catalogColumns,
		garageID, ci.Name, ci.Category, ci.UnitPrice, ci.Unit, ci.IsLabour, ci.PartNumber, ci.Notes, ci.TaxPercent))
}

func (s *Store) UpdateCatalogItem(ctx context.Context, garageID string, ci models.CatalogItem) (models.CatalogItem, error) {
	return scanCatalogItem(s.Pool.QueryRow(ctx,
		`UPDATE catalog_items SET name=$3, category=$4, unit_price=$5, unit=$6, is_labour=$7,
		 part_number=$8, notes=$9, tax_percent=$10 WHERE id=$1 AND garage_id=$2 RETURNING `+catalogColumns,
		ci.ID, garageID, ci.Name, ci.Category, ci.UnitPrice, ci.Unit, ci.IsLabour, ci.PartNumber, ci.Notes, ci.TaxPercent))
}

func (s *Store) DeleteCatalogItem(ctx context.Context, garageID, id string) error {
	tag, err := s.Pool.Exec(ctx, `DELETE FROM catalog_items WHERE id=$1 AND garage_id=$2`, id, garageID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
