package store

import (
	"context"

	"garage-backend/internal/models"
)

// RegisterOwner creates the user, the garage and the owner membership in one
// transaction. A duplicate email rolls everything back and returns
// ErrDuplicate.
func (s *Store) RegisterOwner(ctx context.Context, email, passwordHash, name, garageName string, ownerPermissions []string) (models.User, models.Membership, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.User{}, models.Membership{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))

	var u models.User
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, name) VALUES ($1, $2, $3)
		 RETURNING id, email, name, created_at`, email, passwordHash, name).
		Scan(&u.ID, &u.Email, &u.Name, &u.CreatedAt)
	if err != nil {
		return models.User{}, models.Membership{}, mapPGError(err)
	}

	var garageID string
	if err := tx.QueryRow(ctx,
		`INSERT INTO garages (name) VALUES ($1) RETURNING id`, garageName).Scan(&garageID); err != nil {
		return models.User{}, models.Membership{}, mapPGError(err)
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO memberships (garage_id, user_id, role, permissions) VALUES ($1, $2, 'owner', $3)`,
		garageID, u.ID, ownerPermissions); err != nil {
		return models.User{}, models.Membership{}, mapPGError(err)
	}

	if err := tx.Commit(ctx); err != nil {
		return models.User{}, models.Membership{}, err
	}
	m := models.Membership{
		GarageID: garageID, GarageName: garageName, Role: "owner",
		Permissions: ownerPermissions, IsActive: true,
	}
	return u, m, nil
}

// SetGarageTrial sets the trial window for a newly registered garage.
func (s *Store) SetGarageTrial(ctx context.Context, garageID string, trialDays int) error {
	if trialDays <= 0 {
		trialDays = 14
	}
	_, err := s.Pool.Exec(ctx,
		`UPDATE garages SET plan_tier='trial', subscription_status='trialing',
		 trial_ends_at = now() + ($2 || ' days')::interval WHERE id = $1`,
		garageID, itoa(trialDays))
	return mapPGError(err)
}
