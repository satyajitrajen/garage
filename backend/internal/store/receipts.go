package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

// ReceiptURL is the expenses.receipt_path value for an expense whose receipt
// is stored server-side; clients fetch it with their bearer token.
func ReceiptURL(expenseID string) string { return "/api/expenses/" + expenseID + "/receipt" }

// PutExpenseReceipt stores (or replaces) an expense's receipt and points the
// expense's receipt_path at it. ErrNotFound when the expense isn't the garage's.
func (s *Store) PutExpenseReceipt(ctx context.Context, garageID, expenseID, contentType string, data []byte) error {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx,
		`UPDATE expenses SET receipt_path = $3 WHERE garage_id = $1 AND id = $2`,
		garageID, expenseID, ReceiptURL(expenseID))
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO expense_receipts (expense_id, garage_id, content_type, data)
		 VALUES ($1,$2,$3,$4)
		 ON CONFLICT (expense_id) DO UPDATE SET content_type = EXCLUDED.content_type,
		     data = EXCLUDED.data, created_at = now()`,
		expenseID, garageID, contentType, data); err != nil {
		return mapPGError(err)
	}
	return tx.Commit(ctx)
}

func (s *Store) GetExpenseReceipt(ctx context.Context, garageID, expenseID string) (string, []byte, error) {
	var ct string
	var data []byte
	err := s.Pool.QueryRow(ctx,
		`SELECT content_type, data FROM expense_receipts WHERE garage_id = $1 AND expense_id = $2`,
		garageID, expenseID).Scan(&ct, &data)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil, ErrNotFound
	}
	return ct, data, mapPGError(err)
}

func (s *Store) DeleteExpenseReceipt(ctx context.Context, garageID, expenseID string) error {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx,
		`UPDATE expenses SET receipt_path = NULL WHERE garage_id = $1 AND id = $2`, garageID, expenseID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	if _, err := tx.Exec(ctx,
		`DELETE FROM expense_receipts WHERE garage_id = $1 AND expense_id = $2`, garageID, expenseID); err != nil {
		return mapPGError(err)
	}
	return tx.Commit(ctx)
}
