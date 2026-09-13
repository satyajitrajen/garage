package itest

import (
	"errors"
	"testing"
	"time"

	"garage-backend/internal/auth"
	"garage-backend/internal/store"
)

func TestRefreshTokenLifecycle(t *testing.T) {
	truncate(t)
	s := store.New(pool)
	u, err := s.CreateUser(ctx, "r@test.dev", "h", "R")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()

	_, h1, exp1, _ := auth.NewRefreshToken(now)
	if err := s.InsertRefreshToken(ctx, u.ID, h1, exp1); err != nil {
		t.Fatalf("insert: %v", err)
	}

	_, h2, exp2, _ := auth.NewRefreshToken(now)
	userID, err := s.RotateRefreshToken(ctx, h1, h2, exp2)
	if err != nil || userID != u.ID {
		t.Fatalf("rotate: userID=%s err=%v", userID, err)
	}

	if _, err := s.RotateRefreshToken(ctx, h1, "unused", exp2); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("rotated-out token must be gone, got %v", err)
	}

	_, h3, exp3, _ := auth.NewRefreshToken(now)
	if _, err := s.RotateRefreshToken(ctx, h2, h3, exp3); err != nil {
		t.Fatalf("rotate current: %v", err)
	}

	if err := s.RevokeRefreshToken(ctx, h3); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	if _, err := s.RotateRefreshToken(ctx, h3, "x", exp3); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("revoked token must not rotate, got %v", err)
	}
	if err := s.RevokeRefreshToken(ctx, h3); err != nil {
		t.Fatal("revoke must be idempotent")
	}

	_, hE, _, _ := auth.NewRefreshToken(now)
	if err := s.InsertRefreshToken(ctx, u.ID, hE, now.Add(-time.Minute)); err != nil {
		t.Fatal(err)
	}
	_, hE2, _, _ := auth.NewRefreshToken(now)
	if _, err := s.RotateRefreshToken(ctx, hE, hE2, now.Add(time.Hour)); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("expired token must not rotate, got %v", err)
	}

	rawX, hX, expX, _ := auth.NewRefreshToken(now)
	if err := s.InsertRefreshToken(ctx, u.ID, hX, expX); err != nil {
		t.Fatal(err)
	}
	if _, err := s.RotateRefreshToken(ctx, rawX, "x", expX); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("store must key rotation on the stored hash, not hash its input: got %v", err)
	}
}
