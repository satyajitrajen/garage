package store

import (
	"context"
	"time"
)

// Identity proofing + invites (SaaS M2). Tokens are stored SHA-256 hex;
// callers hash the raw token before calling.

func (s *Store) CreateEmailVerification(ctx context.Context, userID, tokenHash string, ttl time.Duration) error {
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO email_verifications (user_id, token_hash, expires_at)
		 VALUES ($1,$2,$3)`, userID, tokenHash, time.Now().Add(ttl))
	return mapPGError(err)
}

func (s *Store) ConsumeEmailVerification(ctx context.Context, tokenHash string) (string, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	var userID string
	var expires time.Time
	err = tx.QueryRow(ctx,
		`DELETE FROM email_verifications WHERE token_hash = $1 RETURNING user_id, expires_at`,
		tokenHash).Scan(&userID, &expires)
	if err != nil {
		return "", mapPGError(err)
	}
	if time.Now().After(expires) {
		return "", ErrNotFound
	}
	if _, err := tx.Exec(ctx,
		`UPDATE users SET email_verified_at = now() WHERE id = $1`, userID); err != nil {
		return "", err
	}
	return userID, tx.Commit(ctx)
}

func (s *Store) CreatePasswordReset(ctx context.Context, userID, tokenHash string, ttl time.Duration) error {
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO password_resets (user_id, token_hash, expires_at) VALUES ($1,$2,$3)`,
		userID, tokenHash, time.Now().Add(ttl))
	return mapPGError(err)
}

func (s *Store) ConsumePasswordReset(ctx context.Context, tokenHash, newHash string) (string, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	var userID string
	var expires time.Time
	var usedAt *time.Time
	err = tx.QueryRow(ctx,
		`SELECT user_id, expires_at, used_at FROM password_resets WHERE token_hash = $1`,
		tokenHash).Scan(&userID, &expires, &usedAt)
	if err != nil {
		return "", mapPGError(err)
	}
	if usedAt != nil || time.Now().After(expires) {
		return "", ErrNotFound
	}
	if _, err := tx.Exec(ctx,
		`UPDATE users SET password_hash = $2 WHERE id = $1`, userID, newHash); err != nil {
		return "", err
	}
	if _, err := tx.Exec(ctx,
		`UPDATE password_resets SET used_at = now() WHERE token_hash = $1`, tokenHash); err != nil {
		return "", err
	}
	// Single-use: revoke all refresh tokens so stolen sessions die.
	if _, err := tx.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, userID); err != nil {
		return "", err
	}
	return userID, tx.Commit(ctx)
}

type Invite struct {
	ID          string   `json:"id"`
	GarageID    string   `json:"garage_id"`
	Email       string   `json:"email"`
	Role        string   `json:"role"`
	Permissions []string `json:"permissions"`
	ExpiresAt   time.Time `json:"expires_at"`
}

func (s *Store) CreateInvite(ctx context.Context, garageID, email, role string, perms []string, tokenHash string, createdBy string) (Invite, error) {
	var inv Invite
	err := s.Pool.QueryRow(ctx,
		`INSERT INTO garage_invites (garage_id, email, role, permissions, token_hash, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, garage_id, email, role, permissions, expires_at`,
		garageID, email, role, perms, tokenHash, createdBy).
		Scan(&inv.ID, &inv.GarageID, &inv.Email, &inv.Role, &inv.Permissions, &inv.ExpiresAt)
	return inv, mapPGError(err)
}

func (s *Store) InviteByToken(ctx context.Context, tokenHash string) (Invite, error) {
	var inv Invite
	var acceptedAt *time.Time
	var expires time.Time
	err := s.Pool.QueryRow(ctx,
		`SELECT id, garage_id, email, role, permissions, expires_at, accepted_at
		 FROM garage_invites WHERE token_hash = $1`, tokenHash).
		Scan(&inv.ID, &inv.GarageID, &inv.Email, &inv.Role, &inv.Permissions, &expires, &acceptedAt)
	if err != nil {
		return inv, mapPGError(err)
	}
	inv.ExpiresAt = expires
	if acceptedAt != nil || time.Now().After(expires) {
		return inv, ErrNotFound
	}
	return inv, nil
}

func (s *Store) AcceptInvite(ctx context.Context, tokenHash, userID string) (Invite, error) {
	var inv Invite
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return inv, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	err = tx.QueryRow(ctx,
		`SELECT id, garage_id, email, role, permissions FROM garage_invites
		 WHERE token_hash = $1 AND accepted_at IS NULL AND expires_at > now()`, tokenHash).
		Scan(&inv.ID, &inv.GarageID, &inv.Email, &inv.Role, &inv.Permissions)
	if err != nil {
		return inv, mapPGError(err)
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO memberships (garage_id, user_id, role, permissions)
		 VALUES ($1,$2,$3,$4) ON CONFLICT (garage_id, user_id) DO NOTHING`,
		inv.GarageID, userID, inv.Role, inv.Permissions); err != nil {
		return inv, err
	}
	if _, err := tx.Exec(ctx,
		`UPDATE garage_invites SET accepted_at = now() WHERE id = $1`, inv.ID); err != nil {
		return inv, err
	}
	return inv, tx.Commit(ctx)
}

func (s *Store) RevokeInvite(ctx context.Context, garageID, inviteID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM garage_invites WHERE garage_id = $1 AND id = $2`, garageID, inviteID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) SetSuperadmin(ctx context.Context, userID string, on bool) error {
	_, err := s.Pool.Exec(ctx, `UPDATE users SET is_superadmin = $2 WHERE id = $1`, userID, on)
	return mapPGError(err)
}

func (s *Store) IsSuperadmin(ctx context.Context, userID string) (bool, error) {
	var on bool
	err := s.Pool.QueryRow(ctx, `SELECT COALESCE(is_superadmin,false) FROM users WHERE id = $1`, userID).Scan(&on)
	return on, mapPGError(err)
}

func (s *Store) IsEmailVerified(ctx context.Context, userID string) (bool, error) {
	var t *time.Time
	err := s.Pool.QueryRow(ctx, `SELECT email_verified_at FROM users WHERE id = $1`, userID).Scan(&t)
	if err != nil {
		return false, mapPGError(err)
	}
	return t != nil, nil
}
