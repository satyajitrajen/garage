package store

import (
	"context"

	"garage-backend/internal/models"
)

const attendanceColumns = `id, staff_id, date::text, status, notes`

func scanAttendance(row scanner) (models.AttendanceRecord, error) {
	var rec models.AttendanceRecord
	err := row.Scan(&rec.ID, &rec.StaffID, &rec.Date, &rec.Status, &rec.Notes)
	return rec, mapPGError(err)
}

func (s *Store) ListAttendance(ctx context.Context, garageID string) ([]models.AttendanceRecord, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+attendanceColumns+` FROM attendance_records
		 WHERE garage_id = $1 ORDER BY date DESC, staff_id, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.AttendanceRecord{}
	for rows.Next() {
		rec, err := scanAttendance(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, rec)
	}
	return items, rows.Err()
}

// UpsertAttendance inserts or updates by (garage, staff, day) — idempotent
// per spec §8. Returns the stored row including its id either way.
func (s *Store) UpsertAttendance(ctx context.Context, garageID string, rec models.AttendanceRecord) (models.AttendanceRecord, error) {
	return scanAttendance(s.Pool.QueryRow(ctx,
		`INSERT INTO attendance_records (garage_id, staff_id, date, status, notes)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (garage_id, staff_id, date)
		 DO UPDATE SET status = EXCLUDED.status, notes = EXCLUDED.notes
		 RETURNING `+attendanceColumns,
		garageID, rec.StaffID, rec.Date, rec.Status, rec.Notes))
}
