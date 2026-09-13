package store

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"garage-backend/internal/models"
)

const itemColumns = `id, name, category, unit_price, quantity, unit, discount_percent,
	tax_percent, is_labour, part_number, notes, assigned_staff_id`

// itemParent locates the document table an items table hangs off.
type itemParent struct {
	parentTable string
	fkColumn    string
}

var itemParents = map[string]itemParent{
	"job_card_items":  {parentTable: "job_cards", fkColumn: "job_card_id"},
	"quotation_items": {parentTable: "quotations", fkColumn: "quotation_id"},
	"invoice_items":   {parentTable: "invoices", fkColumn: "invoice_id"},
}

// execer is satisfied by both *pgxpool.Pool and pgx.Tx.
type execer interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

func itemParentOf(itemsTable string) (itemParent, error) {
	p, ok := itemParents[itemsTable]
	if !ok {
		return itemParent{}, fmt.Errorf("unknown items table %q", itemsTable)
	}
	return p, nil
}

func scanItem(row scanner) (models.MaintenanceItem, error) {
	var it models.MaintenanceItem
	err := row.Scan(&it.ID, &it.Name, &it.Category, &it.UnitPrice, &it.Quantity, &it.Unit,
		&it.DiscountPercent, &it.TaxPercent, &it.IsLabour, &it.PartNumber, &it.Notes,
		&it.AssignedStaffID)
	return it, mapPGError(err)
}

// ItemsOfParent returns one document's items ordered by creation.
func (s *Store) ItemsOfParent(ctx context.Context, itemsTable, parentID string) ([]models.MaintenanceItem, error) {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return nil, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+itemColumns+` FROM `+itemsTable+` WHERE `+p.fkColumn+` = $1 ORDER BY created_at, id`,
		parentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.MaintenanceItem{}
	for rows.Next() {
		it, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// ItemsByGarage returns every item of the given items table for documents in
// the garage, keyed by parent document id (list endpoints attach them).
func (s *Store) ItemsByGarage(ctx context.Context, itemsTable, garageID string) (map[string][]models.MaintenanceItem, error) {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return nil, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT it.id, it.name, it.category, it.unit_price, it.quantity, it.unit,
		        it.discount_percent, it.tax_percent, it.is_labour, it.part_number,
		        it.notes, it.assigned_staff_id, it.`+p.fkColumn+`
		 FROM `+itemsTable+` it
		 JOIN `+p.parentTable+` d ON d.id = it.`+p.fkColumn+`
		 WHERE d.garage_id = $1 ORDER BY it.created_at, it.id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := map[string][]models.MaintenanceItem{}
	for rows.Next() {
		var parentID string
		var it models.MaintenanceItem
		if err := rows.Scan(&it.ID, &it.Name, &it.Category, &it.UnitPrice, &it.Quantity,
			&it.Unit, &it.DiscountPercent, &it.TaxPercent, &it.IsLabour, &it.PartNumber,
			&it.Notes, &it.AssignedStaffID, &parentID); err != nil {
			return nil, err
		}
		items[parentID] = append(items[parentID], it)
	}
	return items, rows.Err()
}

// replaceItemsOn deletes the document's item rows and inserts the supplied
// ones inside the caller's transaction (PUT replaces the items array
// wholesale, mirroring the mock's update setters). Empty item ids get server
// uuids; supplied ids are preserved so the client's upsert-by-id contract
// keeps working. Table names come from the compile-time itemParents map,
// never from request input.
func replaceItemsOn(ctx context.Context, x execer, itemsTable, parentID string, items []models.MaintenanceItem) error {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return err
	}
	if _, err := x.Exec(ctx, `DELETE FROM `+itemsTable+` WHERE `+p.fkColumn+` = $1`, parentID); err != nil {
		return mapPGError(err)
	}
	for i := range items {
		it := &items[i]
		if it.ID == "" {
			it.ID = uuid.NewString()
		}
		if _, err := x.Exec(ctx,
			`INSERT INTO `+itemsTable+` (id, `+p.fkColumn+`, name, category, unit_price, quantity,
			                            unit, discount_percent, tax_percent, is_labour, part_number,
			                            notes, assigned_staff_id)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
			it.ID, parentID, it.Name, it.Category, it.UnitPrice, it.Quantity, it.Unit,
			it.DiscountPercent, it.TaxPercent, it.IsLabour, it.PartNumber, it.Notes,
			it.AssignedStaffID); err != nil {
			return mapPGError(err)
		}
	}
	return nil
}

// UpsertItem updates the item when its id already exists under the parent,
// otherwise inserts it (mock upsertJobCardItem semantics). Empty ids always
// insert with a server uuid.
func (s *Store) UpsertItem(ctx context.Context, itemsTable, parentID string, it models.MaintenanceItem) (models.MaintenanceItem, error) {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return models.MaintenanceItem{}, err
	}
	if it.ID != "" {
		tag, err := s.Pool.Exec(ctx,
			`UPDATE `+itemsTable+` SET name=$3, category=$4, unit_price=$5, quantity=$6, unit=$7,
			                          discount_percent=$8, tax_percent=$9, is_labour=$10,
			                          part_number=$11, notes=$12, assigned_staff_id=$13
			 WHERE `+p.fkColumn+` = $1 AND id = $2`,
			parentID, it.ID, it.Name, it.Category, it.UnitPrice, it.Quantity, it.Unit,
			it.DiscountPercent, it.TaxPercent, it.IsLabour, it.PartNumber, it.Notes,
			it.AssignedStaffID)
		if err != nil {
			return models.MaintenanceItem{}, mapPGError(err)
		}
		if tag.RowsAffected() == 1 {
			return it, nil
		}
	} else {
		it.ID = uuid.NewString()
	}
	_, err = s.Pool.Exec(ctx,
		`INSERT INTO `+itemsTable+` (id, `+p.fkColumn+`, name, category, unit_price, quantity,
		                            unit, discount_percent, tax_percent, is_labour, part_number,
		                            notes, assigned_staff_id)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
		it.ID, parentID, it.Name, it.Category, it.UnitPrice, it.Quantity, it.Unit,
		it.DiscountPercent, it.TaxPercent, it.IsLabour, it.PartNumber, it.Notes,
		it.AssignedStaffID)
	return it, mapPGError(err)
}

// DeleteItem removes one item row; 0 rows → ErrNotFound (unknown id or
// another parent's id — both 404 to the client).
func (s *Store) DeleteItem(ctx context.Context, itemsTable, parentID, itemID string) error {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return err
	}
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM `+itemsTable+` WHERE `+p.fkColumn+` = $1 AND id = $2`, parentID, itemID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
