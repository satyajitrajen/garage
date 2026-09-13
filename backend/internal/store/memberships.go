package store

import (
	"context"
	"strconv"
	"strings"

	"garage-backend/internal/models"
)

type scanner interface{ Scan(dest ...any) error }

const membershipSelect = `
SELECT m.garage_id, g.name, m.role, m.permissions, m.is_active
FROM memberships m
JOIN garages g ON g.id = m.garage_id
`

func scanMembership(row scanner) (models.Membership, error) {
	var m models.Membership
	err := row.Scan(&m.GarageID, &m.GarageName, &m.Role, &m.Permissions, &m.IsActive)
	return m, mapPGError(err)
}

const memberSelect = `
SELECT u.id, u.name, u.email, m.role, m.permissions, m.is_active
FROM memberships m
JOIN users u ON u.id = m.user_id
`

func scanMember(row scanner) (models.Member, error) {
	var m models.Member
	err := row.Scan(&m.UserID, &m.Name, &m.Email, &m.Role, &m.Permissions, &m.IsActive)
	return m, mapPGError(err)
}

func (s *Store) MembershipFor(ctx context.Context, garageID, userID string) (models.Membership, error) {
	return scanMembership(s.Pool.QueryRow(ctx,
		membershipSelect+`WHERE m.garage_id = $1 AND m.user_id = $2`, garageID, userID))
}

func (s *Store) MembershipsForUser(ctx context.Context, userID string) ([]models.Membership, error) {
	rows, err := s.Pool.Query(ctx,
		membershipSelect+`WHERE m.user_id = $1 ORDER BY g.name`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	memberships := []models.Membership{}
	for rows.Next() {
		m, err := scanMembership(rows)
		if err != nil {
			return nil, err
		}
		memberships = append(memberships, m)
	}
	return memberships, rows.Err()
}

func (s *Store) CreateMembership(ctx context.Context, garageID, userID, role string, permissions []string) (models.Member, error) {
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO memberships (garage_id, user_id, role, permissions) VALUES ($1, $2, $3, $4)`,
		garageID, userID, role, permissions)
	if err != nil {
		return models.Member{}, mapPGError(err)
	}
	return s.Member(ctx, garageID, userID)
}

// CreateUserWithMembership creates a brand-new user plus a staff membership
// in one transaction (owner-created staff logins).
func (s *Store) CreateUserWithMembership(ctx context.Context, garageID, email, passwordHash, name string, permissions []string) (models.Member, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Member{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))

	var userID string
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, name) VALUES ($1, $2, $3) RETURNING id`,
		email, passwordHash, name).Scan(&userID)
	if err != nil {
		return models.Member{}, mapPGError(err)
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO memberships (garage_id, user_id, role, permissions) VALUES ($1, $2, 'staff', $3)`,
		garageID, userID, permissions); err != nil {
		return models.Member{}, mapPGError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return models.Member{}, err
	}
	return s.Member(ctx, garageID, userID)
}

func (s *Store) Member(ctx context.Context, garageID, userID string) (models.Member, error) {
	return scanMember(s.Pool.QueryRow(ctx,
		memberSelect+`WHERE m.garage_id = $1 AND m.user_id = $2`, garageID, userID))
}

func (s *Store) ListMembers(ctx context.Context, garageID string) ([]models.Member, error) {
	rows, err := s.Pool.Query(ctx,
		memberSelect+`WHERE m.garage_id = $1 ORDER BY (m.role = 'owner') DESC, u.name`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	members := []models.Member{}
	for rows.Next() {
		m, err := scanMember(rows)
		if err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

type MemberPatch struct {
	PasswordHash *string
	Permissions  []string
	IsActive     *bool
}

func (s *Store) UpdateMember(ctx context.Context, garageID, userID string, patch MemberPatch) (models.Member, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Member{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))

	if patch.PasswordHash != nil {
		// The EXISTS guard keeps the users-table write scoped to this garage:
		// without it a foreign garage could reset a user's password before the
		// memberships UPDATE below no-ops.
		if _, err := tx.Exec(ctx,
			`UPDATE users SET password_hash = $1
			 WHERE id = $2 AND EXISTS (SELECT 1 FROM memberships WHERE garage_id = $3 AND user_id = $2)`,
			*patch.PasswordHash, userID, garageID); err != nil {
			return models.Member{}, mapPGError(err)
		}
	}
	if patch.Permissions != nil || patch.IsActive != nil {
		sets := []string{}
		args := []any{}
		if patch.Permissions != nil {
			args = append(args, patch.Permissions)
			sets = append(sets, "permissions = $"+strconv.Itoa(len(args)))
		}
		if patch.IsActive != nil {
			args = append(args, *patch.IsActive)
			sets = append(sets, "is_active = $"+strconv.Itoa(len(args)))
		}
		args = append(args, garageID, userID)
		garageParam := strconv.Itoa(len(args) - 1)
		userParam := strconv.Itoa(len(args))
		if _, err := tx.Exec(ctx,
			`UPDATE memberships SET `+strings.Join(sets, ", ")+
				` WHERE garage_id = $`+garageParam+` AND user_id = $`+userParam, args...); err != nil {
			return models.Member{}, mapPGError(err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return models.Member{}, err
	}
	return s.Member(ctx, garageID, userID)
}

func (s *Store) DeleteMembership(ctx context.Context, garageID, userID string) error {
	_, err := s.Pool.Exec(ctx,
		`DELETE FROM memberships WHERE garage_id = $1 AND user_id = $2`, garageID, userID)
	return mapPGError(err)
}
