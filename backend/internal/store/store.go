// Package store holds all pgx queries. Every query is parameterized and
// scoped by garage_id supplied from the auth middleware, never from request
// bodies.
package store

import (
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound  = errors.New("not found")
	ErrDuplicate = errors.New("duplicate")
)

// Payment guard sentinels for the atomic record path.
var (
	errCancelled = errors.New("invoice is cancelled")
	errOverpaid  = errors.New("payment exceeds balance due")
)

// IsCancelled reports the atomic-payment cancelled guard.
func IsCancelled(err error) bool { return errors.Is(err, errCancelled) }

// IsOverpaid reports the atomic-payment overpay guard.
func IsOverpaid(err error) bool { return errors.Is(err, errOverpaid) }

type Store struct {
	Pool *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Store { return &Store{Pool: pool} }

func mapPGError(err error) error {
	if err == nil {
		return nil
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return ErrDuplicate
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return err
}
