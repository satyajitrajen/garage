package store

import (
	"context"

	"garage-backend/internal/models"
)

const invoiceColumns = `id, invoice_number, job_card_id, customer_id, vehicle_id, km_reading,
	discount_amount, tax_percent, invoice_date, due_date, cancelled_at, notes,
	terms_and_conditions, created_at`

const paymentColumns = `id, invoice_id, customer_id, amount, mode, transaction_ref,
	payment_date, notes, received_by`

func scanInvoice(row scanner) (models.Invoice, error) {
	var inv models.Invoice
	err := row.Scan(&inv.ID, &inv.InvoiceNumber, &inv.JobCardID, &inv.CustomerID,
		&inv.VehicleID, &inv.KmReading, &inv.DiscountAmount, &inv.TaxPercent,
		&inv.InvoiceDate, &inv.DueDate, &inv.CancelledAt, &inv.Notes,
		&inv.TermsAndConditions, &inv.CreatedAt)
	return inv, mapPGError(err)
}

func scanPayment(row scanner) (models.Payment, error) {
	var p models.Payment
	err := row.Scan(&p.ID, &p.InvoiceID, &p.CustomerID, &p.Amount, &p.Mode,
		&p.TransactionRef, &p.PaymentDate, &p.Notes, &p.ReceivedBy)
	return p, mapPGError(err)
}

// InvoiceMoneyFor loads an invoice's raw money components (gross item
// taxable total, document discount, tax percent, paid total) so handlers can
// run the Dart-side math through models.InvoiceMoney without full rows.
func (s *Store) InvoiceMoneyFor(ctx context.Context, garageID, invoiceID string) (models.InvoiceMoney, error) {
	var m models.InvoiceMoney
	err := s.Pool.QueryRow(ctx,
		`SELECT i.cancelled_at,
		        COALESCE(item_sums.gross, 0), i.discount_amount, i.tax_percent,
		        COALESCE(paid_sums.paid, 0)
		 FROM invoices i
		 LEFT JOIN (SELECT invoice_id,
		                   SUM(unit_price * quantity * (1 - discount_percent / 100)) AS gross
		            FROM invoice_items GROUP BY invoice_id) item_sums
		            ON item_sums.invoice_id = i.id
		 LEFT JOIN (SELECT invoice_id, SUM(amount) AS paid
		            FROM payments GROUP BY invoice_id) paid_sums
		            ON paid_sums.invoice_id = i.id
		 WHERE i.garage_id = $1 AND i.id = $2`, garageID, invoiceID).Scan(
		&m.CancelledAt, &m.Gross, &m.Discount, &m.TaxPercent, &m.Paid)
	return m, mapPGError(err)
}

func (s *Store) PaymentsByInvoice(ctx context.Context, invoiceID string) ([]models.Payment, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+paymentColumns+` FROM payments WHERE invoice_id = $1 ORDER BY payment_date, id`,
		invoiceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Payment{}
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, p)
	}
	return items, rows.Err()
}

// PaymentsByGarage returns every payment for the garage's invoices, keyed by
// invoice id (list endpoint embeds them).
func (s *Store) PaymentsByGarage(ctx context.Context, garageID string) (map[string][]models.Payment, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT p.id, p.invoice_id, p.customer_id, p.amount, p.mode, p.transaction_ref,
		        p.payment_date, p.notes, p.received_by
		 FROM payments p
		 JOIN invoices i ON i.id = p.invoice_id
		 WHERE i.garage_id = $1 ORDER BY p.payment_date, p.id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	pays := map[string][]models.Payment{}
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		pays[p.InvoiceID] = append(pays[p.InvoiceID], p)
	}
	return pays, rows.Err()
}

// CreatePayment inserts an append-only payment row (spec §8: payments are
// never edited or deleted). payment_date is server-stamped by the DB default
// now(); garage scoping is enforced by the caller, which resolves the invoice
// through InvoiceMoneyFor before recording.
func (s *Store) CreatePayment(ctx context.Context, invoiceID string, p models.Payment) (models.Payment, error) {
	return scanPayment(s.Pool.QueryRow(ctx,
		`INSERT INTO payments (invoice_id, customer_id, amount, mode, transaction_ref, notes, received_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING `+paymentColumns,
		invoiceID, p.CustomerID, p.Amount, p.Mode, p.TransactionRef, p.Notes, p.ReceivedBy))
}

func (s *Store) ListInvoices(ctx context.Context, garageID string) ([]models.Invoice, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	invs := []models.Invoice{}
	for rows.Next() {
		inv, err := scanInvoice(rows)
		if err != nil {
			return nil, err
		}
		invs = append(invs, inv)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	items, err := s.ItemsByGarage(ctx, "invoice_items", garageID)
	if err != nil {
		return nil, err
	}
	pays, err := s.PaymentsByGarage(ctx, garageID)
	if err != nil {
		return nil, err
	}
	for i := range invs {
		invs[i].Items = items[invs[i].ID]
		if invs[i].Items == nil {
			invs[i].Items = []models.MaintenanceItem{}
		}
		invs[i].Payments = pays[invs[i].ID]
		if invs[i].Payments == nil {
			invs[i].Payments = []models.Payment{}
		}
	}
	return invs, nil
}

func (s *Store) InvoiceByID(ctx context.Context, garageID, invoiceID string) (models.Invoice, error) {
	inv, err := scanInvoice(s.Pool.QueryRow(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE garage_id = $1 AND id = $2`,
		garageID, invoiceID))
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Items, err = s.ItemsOfParent(ctx, "invoice_items", inv.ID)
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Payments, err = s.PaymentsByInvoice(ctx, inv.ID)
	return inv, err
}

func (s *Store) CreateInvoice(ctx context.Context, garageID string, inv models.Invoice) (models.Invoice, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Invoice{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	// cancelled_at is NOT writable on create — invoices are born active.
	created, err := scanInvoice(tx.QueryRow(ctx,
		`INSERT INTO invoices (garage_id, invoice_number, job_card_id, customer_id, vehicle_id,
		                      km_reading, discount_amount, tax_percent, invoice_date, due_date,
		                      notes, terms_and_conditions)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING `+invoiceColumns,
		garageID, inv.InvoiceNumber, inv.JobCardID, inv.CustomerID, inv.VehicleID,
		inv.KmReading, inv.DiscountAmount, inv.TaxPercent, inv.InvoiceDate, inv.DueDate,
		inv.Notes, inv.TermsAndConditions))
	if err != nil {
		return models.Invoice{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "invoice_items", created.ID, inv.Items); err != nil {
		return models.Invoice{}, err
	}
	created.Items = inv.Items
	created.Payments = []models.Payment{}
	return created, tx.Commit(ctx)
}

// invoice_number and created_at are immutable (convention 9).
func (s *Store) UpdateInvoice(ctx context.Context, garageID string, inv models.Invoice) (models.Invoice, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Invoice{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	updated, err := scanInvoice(tx.QueryRow(ctx,
		`UPDATE invoices SET job_card_id=$3, customer_id=$4, vehicle_id=$5, km_reading=$6,
		                        discount_amount=$7, tax_percent=$8, invoice_date=$9,
		                        due_date=$10, cancelled_at=$11, notes=$12, terms_and_conditions=$13
		 WHERE garage_id = $1 AND id = $2 RETURNING `+invoiceColumns,
		garageID, inv.ID, inv.JobCardID, inv.CustomerID, inv.VehicleID, inv.KmReading,
		inv.DiscountAmount, inv.TaxPercent, inv.InvoiceDate, inv.DueDate, inv.CancelledAt,
		inv.Notes, inv.TermsAndConditions))
	if err != nil {
		return models.Invoice{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "invoice_items", updated.ID, inv.Items); err != nil {
		return models.Invoice{}, err
	}
	updated.Items = inv.Items
	if updated.Payments, err = s.PaymentsByInvoice(ctx, updated.ID); err != nil {
		return models.Invoice{}, err
	}
	return updated, tx.Commit(ctx)
}

// MarkInvoiceCancelled sets cancelled_at = now(); the WHERE clause refuses
// already-cancelled rows (the handler checks payments first).
func (s *Store) MarkInvoiceCancelled(ctx context.Context, garageID, invoiceID string) (models.Invoice, error) {
	inv, err := scanInvoice(s.Pool.QueryRow(ctx,
		`UPDATE invoices SET cancelled_at = now()
		 WHERE garage_id = $1 AND id = $2 AND cancelled_at IS NULL
		 RETURNING `+invoiceColumns, garageID, invoiceID))
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Items, err = s.ItemsOfParent(ctx, "invoice_items", inv.ID)
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Payments, err = s.PaymentsByInvoice(ctx, inv.ID)
	return inv, err
}
