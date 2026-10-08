package config

import "testing"

func TestLoadRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("JWT_SECRET", "long-enough-test-secret")
	if _, err := Load(); err == nil || err.Error() != "DATABASE_URL is required" {
		t.Fatalf("want DATABASE_URL error, got %v", err)
	}
}

func TestLoadRequiresJWTSecret(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "")
	if _, err := Load(); err == nil || err.Error() != "JWT_SECRET is required" {
		t.Fatalf("want JWT_SECRET error, got %v", err)
	}
}

func TestLoadRejectsShortJWTSecret(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "short")
	if _, err := Load(); err == nil {
		t.Fatal("want JWT_SECRET length error, got nil")
	}
}

func TestLoadDefaultsPort(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "long-enough-test-secret")
	t.Setenv("PORT", "")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "8080" {
		t.Fatalf("port = %q, want 8080", cfg.Port)
	}
}

func TestLoadPortOverride(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "long-enough-test-secret")
	t.Setenv("PORT", "3000")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "3000" {
		t.Fatalf("port = %q, want 3000", cfg.Port)
	}
}

func TestLoadPlanPrices(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "long-enough-test-secret")
	t.Setenv("PLAN_PRICE_MONTHLY", "499")
	t.Setenv("PLAN_PRICE_YEARLY", "")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PlanPriceMonthly != 499 || cfg.PlanPriceYearly != 0 {
		t.Fatalf("prices = %d/%d, want 499/0", cfg.PlanPriceMonthly, cfg.PlanPriceYearly)
	}
}
