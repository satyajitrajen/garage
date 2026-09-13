package store

import (
	"context"

	"garage-backend/internal/models"
)

const staffColumns = `id, name, role, phone, email, monthly_salary, joining_date::text,
	is_active, address, emergency_contact, created_at`

func scanStaff(row scanner) (models.Staff, error) {
	var st models.Staff
	err := row.Scan(&st.ID, &st.Name, &st.Role, &st.Phone, &st.Email, &st.MonthlySalary,
		&st.JoiningDate, &st.IsActive, &st.Address, &st.EmergencyContact, &st.CreatedAt)
	return st, mapPGError(err)
}

func (s *Store) ListStaff(ctx context.Context, garageID string) ([]models.Staff, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+staffColumns+` FROM staff_members WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Staff{}
	for rows.Next() {
		st, err := scanStaff(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, st)
	}
	return items, rows.Err()
}

func (s *Store) StaffByID(ctx context.Context, garageID, staffID string) (models.Staff, error) {
	return scanStaff(s.Pool.QueryRow(ctx,
		`SELECT `+staffColumns+` FROM staff_members WHERE garage_id = $1 AND id = $2`,
		garageID, staffID))
}

func (s *Store) CreateStaff(ctx context.Context, garageID string, st models.Staff) (models.Staff, error) {
	return scanStaff(s.Pool.QueryRow(ctx,
		`INSERT INTO staff_members (garage_id, name, role, phone, email, monthly_salary,
		                            joining_date, is_active, address, emergency_contact)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING `+staffColumns,
		garageID, st.Name, st.Role, st.Phone, st.Email, st.MonthlySalary,
		st.JoiningDate, st.IsActive, st.Address, st.EmergencyContact))
}

func (s *Store) UpdateStaff(ctx context.Context, garageID string, st models.Staff) (models.Staff, error) {
	return scanStaff(s.Pool.QueryRow(ctx,
		`UPDATE staff_members SET name=$3, role=$4, phone=$5, email=$6, monthly_salary=$7,
		                        joining_date=$8, is_active=$9, address=$10, emergency_contact=$11
		 WHERE garage_id = $1 AND id = $2 RETURNING `+staffColumns,
		garageID, st.ID, st.Name, st.Role, st.Phone, st.Email, st.MonthlySalary,
		st.JoiningDate, st.IsActive, st.Address, st.EmergencyContact))
}

func (s *Store) DeleteStaff(ctx context.Context, garageID, staffID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM staff_members WHERE garage_id = $1 AND id = $2`, garageID, staffID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// StaffBelongs reports whether the staff member exists in the garage.
func (s *Store) StaffBelongs(ctx context.Context, garageID, staffID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM staff_members WHERE garage_id = $1 AND id = $2)`,
		garageID, staffID).Scan(&ok)
	return ok, err
}
