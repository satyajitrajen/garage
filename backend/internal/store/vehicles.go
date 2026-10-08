package store

import (
	"context"

	"garage-backend/internal/models"
)

const vehicleColumns = `id, customer_id, registration_number, make, model, variant, year,
	fuel_type, current_km, color, chassis_number, engine_number, created_at, last_service_date::text`

func scanVehicle(row scanner) (models.Vehicle, error) {
	var v models.Vehicle
	err := row.Scan(&v.ID, &v.CustomerID, &v.RegistrationNumber, &v.Make, &v.Model,
		&v.Variant, &v.Year, &v.FuelType, &v.CurrentKm, &v.Color, &v.ChassisNumber,
		&v.EngineNumber, &v.CreatedAt, &v.LastServiceDate)
	return v, mapPGError(err)
}

func (s *Store) ListVehicles(ctx context.Context, garageID string) ([]models.Vehicle, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+vehicleColumns+` FROM vehicles WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Vehicle{}
	for rows.Next() {
		v, err := scanVehicle(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, v)
	}
	return items, rows.Err()
}

func (s *Store) VehicleByID(ctx context.Context, garageID, vehicleID string) (models.Vehicle, error) {
	return scanVehicle(s.Pool.QueryRow(ctx,
		`SELECT `+vehicleColumns+` FROM vehicles WHERE garage_id = $1 AND id = $2`,
		garageID, vehicleID))
}

func (s *Store) CreateVehicle(ctx context.Context, garageID string, v models.Vehicle) (models.Vehicle, error) {
	return scanVehicle(s.Pool.QueryRow(ctx,
		`INSERT INTO vehicles (garage_id, customer_id, registration_number, make, model, variant,
		                       year, fuel_type, current_km, color, chassis_number, engine_number, last_service_date)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING `+vehicleColumns,
		garageID, v.CustomerID, v.RegistrationNumber, v.Make, v.Model, v.Variant,
		v.Year, v.FuelType, v.CurrentKm, v.Color, v.ChassisNumber, v.EngineNumber, v.LastServiceDate))
}

func (s *Store) UpdateVehicle(ctx context.Context, garageID string, v models.Vehicle) (models.Vehicle, error) {
	return scanVehicle(s.Pool.QueryRow(ctx,
		`UPDATE vehicles SET customer_id=$3, registration_number=$4, make=$5, model=$6, variant=$7,
		                        year=$8, fuel_type=$9, current_km=$10, color=$11, chassis_number=$12,
		                        engine_number=$13, last_service_date=$14
		 WHERE garage_id = $1 AND id = $2 RETURNING `+vehicleColumns,
		garageID, v.ID, v.CustomerID, v.RegistrationNumber, v.Make, v.Model, v.Variant,
		v.Year, v.FuelType, v.CurrentKm, v.Color, v.ChassisNumber, v.EngineNumber, v.LastServiceDate))
}

func (s *Store) DeleteVehicle(ctx context.Context, garageID, vehicleID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM vehicles WHERE garage_id = $1 AND id = $2`, garageID, vehicleID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// VehicleHasDocuments reports whether the vehicle has any job cards or
// invoices. Deletion is blocked so surviving documents keep a resolvable
// vehicle (mirrors the customer-delete history guard).
func (s *Store) VehicleHasDocuments(ctx context.Context, garageID, vehicleID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM job_cards WHERE garage_id = $1 AND vehicle_id = $2)
		      OR EXISTS (SELECT 1 FROM invoices WHERE garage_id = $1 AND vehicle_id = $2)`,
		garageID, vehicleID).Scan(&ok)
	return ok, err
}

// VehicleBelongs reports whether the vehicle exists in the garage.
func (s *Store) VehicleBelongs(ctx context.Context, garageID, vehicleID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM vehicles WHERE garage_id = $1 AND id = $2)`,
		garageID, vehicleID).Scan(&ok)
	return ok, err
}

// VehicleRegistrationTaken reports whether another vehicle in the garage
// already uses this registration number. Spaces, dashes and case are ignored
// so "mh 12 ab 1234" matches "MH12AB1234". excludeID skips the vehicle being
// updated (pass "" on create).
func (s *Store) VehicleRegistrationTaken(ctx context.Context, garageID, registration, excludeID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM vehicles
		 WHERE garage_id = $1
		   AND upper(regexp_replace(registration_number, '[^A-Za-z0-9]', '', 'g'))
		     = upper(regexp_replace($2, '[^A-Za-z0-9]', '', 'g'))
		   AND ($3 = '' OR id::text <> $3))`,
		garageID, registration, excludeID).Scan(&ok)
	return ok, err
}
