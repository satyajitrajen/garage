package models

import "time"

// InvoiceMoney holds the raw money components of an invoice so handlers can
// reproduce the Dart-side math in lib/models/invoice.dart without loading
// full item and payment rows.
type InvoiceMoney struct {
	CancelledAt *time.Time
	Gross       float64 // sum of item taxable amounts (unit*qty net of item discount)
	Discount    float64 // document-level discount_amount
	TaxPercent  float64
	Paid        float64 // sum of payments
}

// Due mirrors Invoice._rawBalanceDue: taxable = max(gross - discount, 0);
// grand = taxable * (1 + taxPercent/100); due = max(grand - paid, 0).
// Cancelled invoices keep their raw due here — callers decide whether the
// cancelled flag zeroes the balance (the Dart balanceDue getter does).
func (m InvoiceMoney) Due() float64 {
	taxable := m.Gross - m.Discount
	if taxable < 0 {
		taxable = 0
	}
	due := taxable*(1+m.TaxPercent/100) - m.Paid
	if due < 0 {
		due = 0
	}
	return due
}
