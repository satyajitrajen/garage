package auth

import (
	"strings"
	"testing"
	"time"
)

func TestHashAndCheckPassword(t *testing.T) {
	hash, err := HashPassword("s3cret-password")
	if err != nil {
		t.Fatal(err)
	}
	if hash == "s3cret-password" {
		t.Fatal("hash must not equal plaintext")
	}
	if !CheckPassword(hash, "s3cret-password") {
		t.Fatal("correct password must verify")
	}
	if CheckPassword(hash, "wrong") {
		t.Fatal("wrong password must fail")
	}
}

func TestTokenIssuerRoundTrip(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	// Wall-clock relative, not a fixed date: jwt.Parse validates exp against
	// the real clock, so a hardcoded `now` would expire as time passes.
	now := time.Now()
	token, err := issuer.Issue("u-1", now)
	if err != nil {
		t.Fatal(err)
	}
	got, err := issuer.Verify(token)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if got != "u-1" {
		t.Fatalf("subject = %q, want u-1", got)
	}
}

func TestTokenIssuerRejects(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	other := NewTokenIssuer("other-secret")
	now := time.Now()
	tok, err := issuer.Issue("u-1", now)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := other.Verify(tok); err == nil {
		t.Fatal("token from another secret must fail")
	}
	expired, _ := issuer.Issue("u-1", now.Add(-AccessTokenTTL-time.Minute))
	if _, err := issuer.Verify(expired); err == nil {
		t.Fatal("expired token must fail")
	}
	if _, err := issuer.Verify(tok + "x"); err == nil {
		t.Fatal("tampered token must fail")
	}
	if _, err := issuer.Verify("not-a-jwt"); err == nil {
		t.Fatal("garbage token must fail")
	}
	if _, err := issuer.Verify(""); err == nil {
		t.Fatal("empty token must fail")
	}
}

func TestNewRefreshToken(t *testing.T) {
	now := time.Date(2026, 9, 13, 0, 0, 0, 0, time.UTC)
	raw, hash, exp, err := NewRefreshToken(now)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw) != 64 {
		t.Fatalf("raw token = %d chars, want 64 hex chars (32 bytes)", len(raw))
	}
	if HashRefreshToken(raw) != hash {
		t.Fatal("HashRefreshToken(raw) must equal the hash returned at creation")
	}
	if exp.Sub(now) != RefreshTokenTTL {
		t.Fatalf("expiry = %v, want %v", exp.Sub(now), RefreshTokenTTL)
	}
	raw2, hash2, _, _ := NewRefreshToken(now)
	if raw == raw2 || hash == hash2 {
		t.Fatal("refresh tokens must be unique")
	}
}

func TestValidatePermissions(t *testing.T) {
	if err := ValidatePermissions(DefaultStaffPermissions); err != nil {
		t.Fatalf("default staff set must be valid: %v", err)
	}
	if err := ValidatePermissions(AllPermissions); err != nil {
		t.Fatalf("full set must be valid: %v", err)
	}
	err := ValidatePermissions([]string{"bogus.key"})
	if err == nil || !strings.Contains(err.Error(), "bogus.key") {
		t.Fatalf("want unknown-permission error naming the key, got %v", err)
	}
}

func TestDefaultStaffPermissionsExclusions(t *testing.T) {
	excluded := map[string]bool{
		"expenses.manage": true, "staff.manage": true,
		"advances.manage": true, "settings.manage": true,
	}
	if len(DefaultStaffPermissions) != len(AllPermissions)-len(excluded) {
		t.Fatalf("default staff set has %d entries, want %d",
			len(DefaultStaffPermissions), len(AllPermissions)-len(excluded))
	}
	for _, p := range DefaultStaffPermissions {
		if excluded[p] {
			t.Fatalf("default staff set must not include %s", p)
		}
	}
}
