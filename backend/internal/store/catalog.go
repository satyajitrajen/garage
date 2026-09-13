package store

import (
	"context"

	"garage-backend/internal/models"
)

const catalogColumns = `id, name, category, unit_price, unit, is_labour, part_number, notes, created_at`

func scanCatalogItem(row scanner) (models.CatalogItem, error) {
	var ci models.CatalogItem
	err := row.Scan(&ci.ID, &ci.Name, &ci.Category, &ci.UnitPrice, &ci.Unit,
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
