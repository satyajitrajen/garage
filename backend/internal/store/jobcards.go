package store

import (
	"context"

	"garage-backend/internal/models"
)

const jobCardColumns = `id, job_card_number, customer_id, vehicle_id, customer_complaints,
	inspection_checklist, fuel_level, km_reading, assigned_staff_id, status,
	promised_delivery_date, completed_at, estimated_cost_note, supervisor_notes, created_at`

func scanJobCard(row scanner) (models.JobCard, error) {
	var jc models.JobCard
	err := row.Scan(&jc.ID, &jc.JobCardNumber, &jc.CustomerID, &jc.VehicleID,
		&jc.CustomerComplaints, &jc.InspectionChecklist, &jc.FuelLevel, &jc.KmReading,
		&jc.AssignedStaffID, &jc.Status, &jc.PromisedDeliveryDate, &jc.CompletedAt,
		&jc.EstimatedCostNote, &jc.SupervisorNotes, &jc.CreatedAt)
	return jc, mapPGError(err)
}

func (s *Store) ListJobCards(ctx context.Context, garageID string) ([]models.JobCard, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+jobCardColumns+` FROM job_cards WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	cards := []models.JobCard{}
	for rows.Next() {
		jc, err := scanJobCard(rows)
		if err != nil {
			return nil, err
		}
		cards = append(cards, jc)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	items, err := s.ItemsByGarage(ctx, "job_card_items", garageID)
	if err != nil {
		return nil, err
	}
	for i := range cards {
		cards[i].Items = items[cards[i].ID]
		if cards[i].Items == nil {
			cards[i].Items = []models.MaintenanceItem{}
		}
	}
	return cards, nil
}

func (s *Store) JobCardByID(ctx context.Context, garageID, jobCardID string) (models.JobCard, error) {
	jc, err := scanJobCard(s.Pool.QueryRow(ctx,
		`SELECT `+jobCardColumns+` FROM job_cards WHERE garage_id = $1 AND id = $2`,
		garageID, jobCardID))
	if err != nil {
		return models.JobCard{}, err
	}
	jc.Items, err = s.ItemsOfParent(ctx, "job_card_items", jc.ID)
	return jc, err
}

func (s *Store) CreateJobCard(ctx context.Context, garageID string, jc models.JobCard) (models.JobCard, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.JobCard{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	created, err := scanJobCard(tx.QueryRow(ctx,
		`INSERT INTO job_cards (garage_id, job_card_number, customer_id, vehicle_id,
		                       customer_complaints, inspection_checklist, fuel_level, km_reading,
		                       assigned_staff_id, status, promised_delivery_date,
		                       estimated_cost_note, supervisor_notes)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING `+jobCardColumns,
		garageID, jc.JobCardNumber, jc.CustomerID, jc.VehicleID, jc.CustomerComplaints,
		jc.InspectionChecklist, jc.FuelLevel, jc.KmReading, jc.AssignedStaffID, jc.Status,
		jc.PromisedDeliveryDate, jc.EstimatedCostNote, jc.SupervisorNotes))
	if err != nil {
		return models.JobCard{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "job_card_items", created.ID, jc.Items); err != nil {
		return models.JobCard{}, err
	}
	created.Items = jc.Items
	return created, tx.Commit(ctx)
}

func (s *Store) UpdateJobCard(ctx context.Context, garageID string, jc models.JobCard) (models.JobCard, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.JobCard{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	// job_card_number and created_at are immutable (convention 9).
	updated, err := scanJobCard(tx.QueryRow(ctx,
		`UPDATE job_cards SET customer_id=$3, vehicle_id=$4, customer_complaints=$5,
	                        inspection_checklist=$6, fuel_level=$7, km_reading=$8,
	                        assigned_staff_id=$9, status=$10, promised_delivery_date=$11,
	                        estimated_cost_note=$12, supervisor_notes=$13
		 WHERE garage_id = $1 AND id = $2 RETURNING `+jobCardColumns,
		garageID, jc.ID, jc.CustomerID, jc.VehicleID, jc.CustomerComplaints,
		jc.InspectionChecklist, jc.FuelLevel, jc.KmReading, jc.AssignedStaffID, jc.Status,
		jc.PromisedDeliveryDate, jc.EstimatedCostNote, jc.SupervisorNotes))
	if err != nil {
		return models.JobCard{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "job_card_items", updated.ID, jc.Items); err != nil {
		return models.JobCard{}, err
	}
	updated.Items = jc.Items
	return updated, tx.Commit(ctx)
}

// UpdateJobCardStatus mirrors MockGarageRepository.updateJobStatus:
// delivered stamps completed_at with now, cancelled keeps the previous
// completed_at, every other status clears it.
func (s *Store) UpdateJobCardStatus(ctx context.Context, garageID, jobCardID, status string) (models.JobCard, error) {
	jc, err := scanJobCard(s.Pool.QueryRow(ctx,
		`UPDATE job_cards SET status = $3,
	                        completed_at = CASE WHEN $3 = 'delivered' THEN now()
	                                            WHEN $3 = 'cancelled' THEN completed_at
	                                            ELSE NULL END
		 WHERE garage_id = $1 AND id = $2 RETURNING `+jobCardColumns,
		garageID, jobCardID, status))
	if err != nil {
		return models.JobCard{}, err
	}
	jc.Items, err = s.ItemsOfParent(ctx, "job_card_items", jc.ID)
	return jc, err
}

func (s *Store) JobCardBelongs(ctx context.Context, garageID, jobCardID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM job_cards WHERE garage_id = $1 AND id = $2)`,
		garageID, jobCardID).Scan(&ok)
	return ok, err
}
