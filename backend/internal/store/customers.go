package store

import (
	"context"

	"garage-backend/internal/models"
)

const customerColumns = `id, name, phone, whatsapp_number, email, address, gstin, notes, created_at`

func scanCustomer(row scanner) (models.Customer, error) {
	var c models.Customer
	err := row.Scan(&c.ID, &c.Name, &c.Phone, &c.WhatsAppNumber, &c.Email,
		&c.Address, &c.GSTIN, &c.Notes, &c.CreatedAt)
	return c, mapPGError(err)
}

func (s *Store) ListCustomers(ctx context.Context, garageID string) ([]models.Customer, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+customerColumns+` FROM customers WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Customer{}
	for rows.Next() {
		c, err := scanCustomer(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, c)
	}
	return items, rows.Err()
}

func (s *Store) CustomerByID(ctx context.Context, garageID, customerID string) (models.Customer, error) {
	return scanCustomer(s.Pool.QueryRow(ctx,
		`SELECT `+customerColumns+` FROM customers WHERE garage_id = $1 AND id = $2`,
		garageID, customerID))
}

func (s *Store) CreateCustomer(ctx context.Context, garageID string, c models.Customer) (models.Customer, error) {
	return scanCustomer(s.Pool.QueryRow(ctx,
		`INSERT INTO customers (garage_id, name, phone, whatsapp_number, email, address, gstin, notes)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING `+customerColumns,
		garageID, c.Name, c.Phone, c.WhatsAppNumber, c.Email, c.Address, c.GSTIN, c.Notes))
}

func (s *Store) UpdateCustomer(ctx context.Context, garageID string, c models.Customer) (models.Customer, error) {
	return scanCustomer(s.Pool.QueryRow(ctx,
		`UPDATE customers SET name=$3, phone=$4, whatsapp_number=$5, email=$6, address=$7, gstin=$8, notes=$9
		 WHERE garage_id = $1 AND id = $2 RETURNING `+customerColumns,
		garageID, c.ID, c.Name, c.Phone, c.WhatsAppNumber, c.Email, c.Address, c.GSTIN, c.Notes))
}

func (s *Store) DeleteCustomer(ctx context.Context, garageID, customerID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM customers WHERE garage_id = $1 AND id = $2`, garageID, customerID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CustomerBelongs reports whether the customer exists in the garage. Handlers
// use it to reject references to other garages' rows with 404.
func (s *Store) CustomerBelongs(ctx context.Context, garageID, customerID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM customers WHERE garage_id = $1 AND id = $2)`,
		garageID, customerID).Scan(&ok)
	return ok, err
}

// CustomerHasOutstandingDues mirrors MockGarageRepository.deleteCustomer:
// any non-cancelled invoice of the customer with balanceDue > 0.01 blocks
// deletion. Money math comes from models.InvoiceMoney so this query and the
// payments handler can never drift apart.
func (s *Store) CustomerHasOutstandingDues(ctx context.Context, garageID, customerID string) (bool, error) {
	rows, err := s.Pool.Query(ctx,
		models.InvoiceMoneySelect+` WHERE i.garage_id = $1 AND i.customer_id = $2`, garageID, customerID)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	for rows.Next() {
		var m models.InvoiceMoney
		if err := rows.Scan(m.ScanTargets()...); err != nil {
			return false, err
		}
		if m.CancelledAt == nil && m.Due() > 0.01 {
			return true, nil
		}
	}
	return false, rows.Err()
}

// CustomerHasDocuments reports whether the customer has any invoices or job
// cards. Invoice/job-card history also blocks deletion so surviving
// documents always keep a resolvable customer (the mock's dangling
// references are an in-memory artifact the server must not reproduce).
func (s *Store) CustomerHasDocuments(ctx context.Context, garageID, customerID string) (invoices, jobCards bool, err error) {
	err = s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM invoices WHERE garage_id = $1 AND customer_id = $2),
		        EXISTS (SELECT 1 FROM job_cards WHERE garage_id = $1 AND customer_id = $2)`,
		garageID, customerID).Scan(&invoices, &jobCards)
	return invoices, jobCards, err
}
