package models

type AttendanceRecord struct {
	ID      string  `json:"id"`
	StaffID string  `json:"staffId"`
	Date    string  `json:"date"`
	Status  string  `json:"status"`
	Notes   *string `json:"notes"`
}

type SalaryAdvance struct {
	ID         string  `json:"id"`
	StaffID    string  `json:"staffId"`
	Amount     float64 `json:"amount"`
	Date       string  `json:"date"`
	Reason     *string `json:"reason"`
	IsDeducted bool    `json:"isDeducted"`
}
