package models

import "time"

// Expense mirrors GarageExpense in lib/models/expense.dart. expenseDate is
// day-grained (spec §7): a plain YYYY-MM-DD string, not an instant.
type Expense struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Category    string    `json:"category"`
	Amount      float64   `json:"amount"`
	ExpenseDate string    `json:"expenseDate"`
	PaymentMode string    `json:"paymentMode"`
	VendorName  *string   `json:"vendorName"`
	Notes       *string   `json:"notes"`
	ReceiptPath *string   `json:"receiptPath"`
	CreatedAt   time.Time `json:"createdAt"`
}
