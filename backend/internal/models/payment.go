package models

import "time"

type Payment struct {
	ID             string    `json:"id"`
	InvoiceID      string    `json:"invoiceId"`
	CustomerID     *string   `json:"customerId"`
	Amount         float64   `json:"amount"`
	Mode           string    `json:"mode"`
	TransactionRef *string   `json:"transactionRef"`
	PaymentDate    time.Time `json:"paymentDate"`
	Notes          *string   `json:"notes"`
	ReceivedBy     *string   `json:"receivedBy"`
}
