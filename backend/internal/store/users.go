package store

import (
	"context"

	"garage-backend/internal/models"
)

func (s *Store) CreateUser(ctx context.Context, email, passwordHash, name string) (models.User, error) {
	row := s.Pool.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, name) VALUES ($1, $2, $3)
		 RETURNING id, email, name, created_at`, email, passwordHash, name)
	var u models.User
	err := row.Scan(&u.ID, &u.Email, &u.Name, &u.CreatedAt)
	return u, mapPGError(err)
}

func (s *Store) userByColumn(ctx context.Context, column, value string) (models.User, error) {
	row := s.Pool.QueryRow(ctx,
		`SELECT id, email, name, password_hash, created_at FROM users WHERE `+column+` = $1`, value)
	var u models.User
	err := row.Scan(&u.ID, &u.Email, &u.Name, &u.PasswordHash, &u.CreatedAt)
	return u, mapPGError(err)
}

func (s *Store) UserByEmail(ctx context.Context, email string) (models.User, error) {
	return s.userByColumn(ctx, "email", email)
}

func (s *Store) UserByID(ctx context.Context, id string) (models.User, error) {
	return s.userByColumn(ctx, "id", id)
}
