package store

import (
	"context"

	"garage-backend/internal/models"
)

// Paginated variants (additive; legacy List* stay unbounded for old clients).
// Each returns (page items newest-first, total).

func (s *Store) ListCustomersPage(ctx context.Context, garageID string, limit, offset int) ([]models.Customer, int, error) {
	limit, offset = ClampLimit(limit, offset)
	total, err := countByGarage(ctx, s, "customers", garageID)
	if err != nil {
		return nil, 0, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+customerColumns+` FROM customers WHERE garage_id=$1 ORDER BY created_at DESC, id LIMIT $2 OFFSET $3`,
		garageID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items := []models.Customer{}
	for rows.Next() {
		c, err := scanCustomer(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, c)
	}
	return items, total, rows.Err()
}

func (s *Store) ListVehiclesPage(ctx context.Context, garageID string, limit, offset int) ([]models.Vehicle, int, error) {
	limit, offset = ClampLimit(limit, offset)
	total, err := countByGarage(ctx, s, "vehicles", garageID)
	if err != nil {
		return nil, 0, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+vehicleColumns+` FROM vehicles WHERE garage_id=$1 ORDER BY created_at DESC, id LIMIT $2 OFFSET $3`,
		garageID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items := []models.Vehicle{}
	for rows.Next() {
		v, err := scanVehicle(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, v)
	}
	return items, total, rows.Err()
}

func (s *Store) ListInvoicesPage(ctx context.Context, garageID string, limit, offset int) ([]models.Invoice, int, error) {
	limit, offset = ClampLimit(limit, offset)
	total, err := countByGarage(ctx, s, "invoices", garageID)
	if err != nil {
		return nil, 0, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE garage_id=$1 ORDER BY created_at DESC, id LIMIT $2 OFFSET $3`,
		garageID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items := []models.Invoice{}
	for rows.Next() {
		inv, err := scanInvoice(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, inv)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	ids := make([]string, 0, len(items))
	for i := range items {
		ids = append(ids, items[i].ID)
	}
	itemsMap, err := s.ItemsOfParents(ctx, "invoice_items", ids)
	if err != nil {
		return nil, 0, err
	}
	pays, err := s.PaymentsByInvoices(ctx, ids)
	if err != nil {
		return nil, 0, err
	}
	for i := range items {
		items[i].Items = itemsMap[items[i].ID]
		if items[i].Items == nil {
			items[i].Items = []models.MaintenanceItem{}
		}
		items[i].Payments = pays[items[i].ID]
		if items[i].Payments == nil {
			items[i].Payments = []models.Payment{}
		}
	}
	return items, total, nil
}

func (s *Store) ListJobCardsPage(ctx context.Context, garageID string, limit, offset int) ([]models.JobCard, int, error) {
	limit, offset = ClampLimit(limit, offset)
	total, err := countByGarage(ctx, s, "job_cards", garageID)
	if err != nil {
		return nil, 0, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+jobCardColumns+` FROM job_cards WHERE garage_id=$1 ORDER BY created_at DESC, id LIMIT $2 OFFSET $3`,
		garageID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items := []models.JobCard{}
	for rows.Next() {
		jc, err := scanJobCard(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, jc)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	ids := make([]string, 0, len(items))
	for i := range items {
		ids = append(ids, items[i].ID)
	}
	allItems, err := s.ItemsOfParents(ctx, "job_card_items", ids)
	if err != nil {
		return nil, 0, err
	}
	for i := range items {
		items[i].Items = allItems[items[i].ID]
		if items[i].Items == nil {
			items[i].Items = []models.MaintenanceItem{}
		}
	}
	return items, total, nil
}

func (s *Store) ListExpensesPage(ctx context.Context, garageID string, limit, offset int) ([]models.Expense, int, error) {
	limit, offset = ClampLimit(limit, offset)
	total, err := countByGarage(ctx, s, "expenses", garageID)
	if err != nil {
		return nil, 0, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+expenseColumns+` FROM expenses WHERE garage_id=$1 ORDER BY expense_date DESC, created_at DESC, id LIMIT $2 OFFSET $3`,
		garageID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items := []models.Expense{}
	for rows.Next() {
		e, err := scanExpense(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, e)
	}
	return items, total, rows.Err()
}
