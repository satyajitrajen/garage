package itest

import (
	"errors"
	"testing"

	"garage-backend/internal/auth"
	"garage-backend/internal/store"
)

func TestRegisterOwner(t *testing.T) {
	truncate(t)
	s := store.New(pool)

	u, m, err := s.RegisterOwner(ctx, "owner@test.dev", "hash", "Owner", "Garage One", auth.AllPermissions)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if u.ID == "" || m.GarageID == "" {
		t.Fatal("expected generated ids")
	}
	if m.GarageName != "Garage One" || m.Role != "owner" || !m.IsActive {
		t.Fatalf("membership = %+v", m)
	}
	if len(m.Permissions) != len(auth.AllPermissions) {
		t.Fatalf("owner permissions = %d, want %d", len(m.Permissions), len(auth.AllPermissions))
	}

	if _, _, err := s.RegisterOwner(ctx, "owner@test.dev", "hash", "Owner", "Other", auth.AllPermissions); !errors.Is(err, store.ErrDuplicate) {
		t.Fatalf("want ErrDuplicate, got %v", err)
	}

	var garages int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM garages`).Scan(&garages); err != nil {
		t.Fatal(err)
	}
	if garages != 1 {
		t.Fatalf("failed registration must not leave a garage, got %d", garages)
	}
}

func TestMembershipQueries(t *testing.T) {
	truncate(t)
	s := store.New(pool)
	_, om, err := s.RegisterOwner(ctx, "owner@test.dev", "hash", "Owner", "Garage One", auth.AllPermissions)
	if err != nil {
		t.Fatal(err)
	}
	staff, err := s.CreateUser(ctx, "staff@test.dev", "h", "Staff")
	if err != nil {
		t.Fatal(err)
	}

	m, err := s.CreateMembership(ctx, om.GarageID, staff.ID, "staff", []string{"customers.manage"})
	if err != nil {
		t.Fatalf("create membership: %v", err)
	}
	if m.Role != "staff" || len(m.Permissions) != 1 {
		t.Fatalf("membership = %+v", m)
	}
	if _, err := s.CreateMembership(ctx, om.GarageID, staff.ID, "staff", []string{}); !errors.Is(err, store.ErrDuplicate) {
		t.Fatalf("want ErrDuplicate, got %v", err)
	}

	got, err := s.MembershipFor(ctx, om.GarageID, staff.ID)
	if err != nil || got.Role != "staff" || got.GarageName != "Garage One" {
		t.Fatalf("membership for: %+v %v", got, err)
	}
	if _, err := s.MembershipFor(ctx, "00000000-0000-0000-0000-000000000000", staff.ID); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}

	forUser, err := s.MembershipsForUser(ctx, staff.ID)
	if err != nil || len(forUser) != 1 {
		t.Fatalf("memberships for user: %+v %v", forUser, err)
	}

	members, err := s.ListMembers(ctx, om.GarageID)
	if err != nil || len(members) != 2 {
		t.Fatalf("list members: %+v %v", members, err)
	}
	if members[0].Role != "owner" {
		t.Fatalf("owner must list first, got %+v", members[0])
	}

	member, err := s.Member(ctx, om.GarageID, staff.ID)
	if err != nil || member.Name != "Staff" || member.Email != "staff@test.dev" {
		t.Fatalf("member: %+v %v", member, err)
	}
	if _, err := s.Member(ctx, om.GarageID, "00000000-0000-0000-0000-000000000000"); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}

	updated, err := s.UpdateMember(ctx, om.GarageID, staff.ID, store.MemberPatch{
		Permissions: []string{"invoices.manage"},
		IsActive:    boolPtr(false),
	})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if len(updated.Permissions) != 1 || updated.Permissions[0] != "invoices.manage" || updated.IsActive {
		t.Fatalf("updated = %+v", updated)
	}
	inactive, err := s.MembershipFor(ctx, om.GarageID, staff.ID)
	if err != nil || inactive.IsActive {
		t.Fatalf("is_active not persisted: %+v %v", inactive, err)
	}

	newHash := "newhash"
	if _, err := s.UpdateMember(ctx, om.GarageID, staff.ID, store.MemberPatch{PasswordHash: &newHash}); err != nil {
		t.Fatalf("password update: %v", err)
	}
	staffAfter, _ := s.UserByEmail(ctx, "staff@test.dev")
	if staffAfter.PasswordHash != "newhash" {
		t.Fatalf("password_hash = %q, want newhash", staffAfter.PasswordHash)
	}

	if err := s.DeleteMembership(ctx, om.GarageID, staff.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.Member(ctx, om.GarageID, staff.ID); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("want ErrNotFound after delete, got %v", err)
	}
}
