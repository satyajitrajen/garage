package store

import (
	"context"

	"garage-backend/internal/models"
)

const expenseColumns = `id, title, category, amount, expense_date::text, payment_mode,
	vendor_name, notes, receipt_path, created_at`

func scanExpense(row scanner) (models.Expense, error) {
	var e models.Expense
	err := row.Scan(&e.ID, &e.Title, &e.Category, &e.Amount, &e.ExpenseDate,
		&e.PaymentMode, &e.VendorName, &e.Notes, &e.ReceiptPath, &e.CreatedAt)
	return e, mapPGError(err)
}

func (s *Store) ListExpenses(ctx context.Context, garageID string) ([]models.Expense, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+expenseColumns+` FROM expenses WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Expense{}
	for rows.Next() {
		e, err := scanExpense(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, e)
	}
	return items, rows.Err()
}

func (s *Store) CreateExpense(ctx context.Context, garageID string, e models.Expense) (models.Expense, error) {
	return scanExpense(s.Pool.QueryRow(ctx,
		`INSERT INTO expenses (garage_id, title, category, amount, expense_date, payment_mode,
		                      vendor_name, notes)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING `+expenseColumns,
		garageID, e.Title, e.Category, e.Amount, e.ExpenseDate, e.PaymentMode,
		e.VendorName, e.Notes))
}

func (s *Store) UpdateExpense(ctx context.Context, garageID string, e models.Expense) (models.Expense, error) {
	return scanExpense(s.Pool.QueryRow(ctx,
		`UPDATE expenses SET title=$3, category=$4, amount=$5, expense_date=$6, payment_mode=$7,
		                        vendor_name=$8, notes=$9
		 WHERE garage_id = $1 AND id = $2 RETURNING `+expenseColumns,
		garageID, e.ID, e.Title, e.Category, e.Amount, e.ExpenseDate, e.PaymentMode,
		e.VendorName, e.Notes))
}

func (s *Store) DeleteExpense(ctx context.Context, garageID, expenseID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM expenses WHERE garage_id = $1 AND id = $2`, garageID, expenseID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
