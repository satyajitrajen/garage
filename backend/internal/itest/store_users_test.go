package itest

import (
	"errors"
	"testing"
	"time"

	"garage-backend/internal/store"
)

func TestUserStore(t *testing.T) {
	truncate(t)
	s := store.New(pool)

	u, err := s.CreateUser(ctx, "user1@test.dev", "hash1", "User One")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if u.ID == "" {
		t.Fatal("expected server-generated id")
	}
	if u.Email != "user1@test.dev" || u.Name != "User One" {
		t.Fatalf("got %+v", u)
	}
	if u.PasswordHash != "" {
		t.Fatal("PasswordHash must not be populated on returned user")
	}
	if time.Since(u.CreatedAt) > time.Minute {
		t.Fatalf("created_at = %v", u.CreatedAt)
	}

	if _, err := s.CreateUser(ctx, "user1@test.dev", "hash2", "Dup"); !errors.Is(err, store.ErrDuplicate) {
		t.Fatalf("want ErrDuplicate, got %v", err)
	}
	if _, err := s.CreateUser(ctx, "USER1@TEST.DEV", "hash2", "CaseDup"); !errors.Is(err, store.ErrDuplicate) {
		t.Fatalf("CITEXT uniqueness must be case-insensitive, got %v", err)
	}

	got, err := s.UserByEmail(ctx, "user1@test.dev")
	if err != nil {
		t.Fatalf("by email: %v", err)
	}
	if got.PasswordHash != "hash1" {
		t.Fatalf("password_hash = %q, want hash1", got.PasswordHash)
	}
	if _, err := s.UserByEmail(ctx, "missing@test.dev"); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}

	byID, err := s.UserByID(ctx, u.ID)
	if err != nil || byID.Name != "User One" {
		t.Fatalf("by id: %+v %v", byID, err)
	}
	if _, err := s.UserByID(ctx, "00000000-0000-0000-0000-000000000000"); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}
}
