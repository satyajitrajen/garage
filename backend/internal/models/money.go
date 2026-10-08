package models

import "time"

// InvoiceMoney holds the raw money components of an invoice so handlers can
// reproduce the Dart-side math in lib/models/invoice.dart without loading
// full item and payment rows.
type InvoiceMoney struct {
	CancelledAt *time.Time
	Gross       float64 // sum of item taxable amounts (unit*qty net of item discount)
	Discount    float64 // document-level discount_amount
	TaxPercent  float64 // document-level rate (legacy invoices only)
	PerItemTax  bool    // true: each line is taxed at its own rate
	TaxSum      float64 // sum of item taxable * item rate / 100 (before discount)
	Paid        float64 // sum of payments
}

// Grand mirrors Invoice.grandTotal: taxable = max(gross - discount, 0).
// Legacy invoices tax taxable at the document rate. Per-item invoices spread
// the document discount pro-rata, so tax = TaxSum * taxable / gross.
func (m InvoiceMoney) Grand() float64 {
	taxable := m.Gross - m.Discount
	if taxable < 0 {
		taxable = 0
	}
	if !m.PerItemTax {
		return taxable * (1 + m.TaxPercent/100)
	}
	if m.Gross <= 0 {
		return taxable
	}
	return taxable + m.TaxSum*taxable/m.Gross
}

// Due mirrors Invoice._rawBalanceDue: due = max(grand - paid, 0).
// Cancelled invoices keep their raw due here — callers decide whether the
// cancelled flag zeroes the balance (the Dart balanceDue getter does).
func (m InvoiceMoney) Due() float64 {
	due := m.Grand() - m.Paid
	if due < 0 {
		due = 0
	}
	return due
}

// InvoiceMoneySelect selects the InvoiceMoney columns for invoices aliased
// "i"; scan them with InvoiceMoney.ScanTargets. Callers append their own
// WHERE clause.
const InvoiceMoneySelect = `SELECT i.cancelled_at,
	        COALESCE(item_sums.gross, 0), i.discount_amount, i.tax_percent,
	        i.per_item_tax, COALESCE(item_sums.tax_sum, 0),
	        COALESCE(paid_sums.paid, 0)
	 FROM invoices i
	 LEFT JOIN (SELECT invoice_id,
	                   SUM(unit_price * quantity * (1 - discount_percent / 100.0)) AS gross,
	                   SUM(unit_price * quantity * (1 - discount_percent / 100.0) * tax_percent / 100.0) AS tax_sum
	            FROM invoice_items GROUP BY invoice_id) item_sums
	            ON item_sums.invoice_id = i.id
	 LEFT JOIN (SELECT invoice_id, SUM(amount) AS paid
	            FROM payments GROUP BY invoice_id) paid_sums
	            ON paid_sums.invoice_id = i.id`

// ScanTargets returns pointers in InvoiceMoneySelect column order.
func (m *InvoiceMoney) ScanTargets() []any {
	return []any{&m.CancelledAt, &m.Gross, &m.Discount, &m.TaxPercent,
		&m.PerItemTax, &m.TaxSum, &m.Paid}
}
