package models

import "testing"

func TestInvoiceMoneyDue(t *testing.T) {
	cases := []struct {
		name                       string
		gross, discount, tax, paid float64
		want                       float64
	}{
		{"plain 18% GST", 1000, 0, 18, 0, 1180},
		{"discount then tax", 1000, 100, 18, 0, 1062},
		{"partial payment", 1000, 100, 18, 500, 562},
		{"overpaid clamps to zero", 100, 0, 0, 150, 0},
		{"discount exceeds gross clamps", 100, 500, 18, 0, 0},
		{"zero tax", 250.50, 0.50, 0, 0, 250},
	}
	for _, tc := range cases {
		m := InvoiceMoney{Gross: tc.gross, Discount: tc.discount, TaxPercent: tc.tax, Paid: tc.paid}
		if got := m.Due(); got < tc.want-1e-9 || got > tc.want+1e-9 {
			t.Errorf("%s: Due() = %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestInvoiceMoneyPerItemTax(t *testing.T) {
	cases := []struct {
		name                          string
		gross, discount, taxSum, paid float64
		want                          float64
	}{
		// brake pads 1800 @18% (324) + tyre 4400 @28% (1232)
		{"mixed rates", 6200, 0, 1556, 0, 7756},
		// discount 620 = 10% of gross: tax scales by 0.9
		{"discount spread pro-rata", 6200, 620, 1556, 0, 5580 + 1400.4},
		{"partial payment", 6200, 0, 1556, 6000, 1756},
		{"zero gross", 0, 0, 0, 0, 0},
		{"discount exceeds gross", 100, 500, 18, 0, 0},
	}
	for _, tc := range cases {
		m := InvoiceMoney{Gross: tc.gross, Discount: tc.discount, PerItemTax: true,
			TaxPercent: 99, TaxSum: tc.taxSum, Paid: tc.paid}
		if got := m.Due(); got < tc.want-1e-6 || got > tc.want+1e-6 {
			t.Errorf("%s: Due() = %v, want %v", tc.name, got, tc.want)
		}
	}
}
