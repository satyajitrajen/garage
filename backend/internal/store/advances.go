package store

import (
	"context"

	"garage-backend/internal/models"
)

const advanceColumns = `id, staff_id, amount, date::text, reason, is_deducted`

func scanAdvance(row scanner) (models.SalaryAdvance, error) {
	var adv models.SalaryAdvance
	err := row.Scan(&adv.ID, &adv.StaffID, &adv.Amount, &adv.Date, &adv.Reason, &adv.IsDeducted)
	return adv, mapPGError(err)
}

func (s *Store) ListSalaryAdvances(ctx context.Context, garageID string) ([]models.SalaryAdvance, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+advanceColumns+` FROM salary_advances WHERE garage_id = $1 ORDER BY date DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.SalaryAdvance{}
	for rows.Next() {
		adv, err := scanAdvance(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, adv)
	}
	return items, rows.Err()
}

func (s *Store) CreateSalaryAdvance(ctx context.Context, garageID string, adv models.SalaryAdvance) (models.SalaryAdvance, error) {
	return scanAdvance(s.Pool.QueryRow(ctx,
		`INSERT INTO salary_advances (garage_id, staff_id, amount, date, reason, is_deducted)
		 VALUES ($1,$2,$3,$4,$5,$6) RETURNING `+advanceColumns,
		garageID, adv.StaffID, adv.Amount, adv.Date, adv.Reason, adv.IsDeducted))
}

// SettleSalaryAdvances marks every unsettled advance of the staff member in
// the given month/year as deducted, then returns the garage's full advance
// list (mirrors MockGarageRepository.settleSalaryAdvances returning
// List.of(_salaryAdvances)).
func (s *Store) SettleSalaryAdvances(ctx context.Context, garageID, staffID string, month, year int) ([]models.SalaryAdvance, error) {
	if _, err := s.Pool.Exec(ctx,
		`UPDATE salary_advances SET is_deducted = true
		 WHERE garage_id = $1 AND staff_id = $2 AND is_deducted = false
		   AND EXTRACT(MONTH FROM date) = $3 AND EXTRACT(YEAR FROM date) = $4`,
		garageID, staffID, month, year); err != nil {
		return nil, mapPGError(err)
	}
	return s.ListSalaryAdvances(ctx, garageID)
}
