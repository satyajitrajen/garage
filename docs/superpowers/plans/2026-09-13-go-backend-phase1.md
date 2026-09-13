# Go Backend Phase 1 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `backend/` Go service foundation from the approved spec (`docs/superpowers/specs/2026-09-13-go-backend-design.md`): Postgres schema for auth/tenancy/settings, JWT + refresh-token auth, granular permission middleware, members and garage-settings endpoints, all integration-tested against embedded Postgres.

**Architecture:** Modular monolith in a new `backend/` directory: `cmd/server` binary, `internal/{config,auth,api,store,models,httputil}`, goose SQL migrations embedded into the binary and auto-run on boot. All list endpoints return `{"items": [...]}`; errors use the `{"error":{code,message}}` envelope. Garage context is the `X-Garage-Id` header (must match the `{garageId}` URL segment when one is present).

**Tech Stack:** Go 1.24+ (toolchain 1.27 installed), chi v5 + go-chi/cors, pgx v5 (`pgxpool`), golang-jwt/v5, `golang.org/x/crypto/bcrypt` cost 12, pressly/goose v3, google/uuid, fergusstrange/embedded-postgres (test-only). No Docker/psql on this machine — tests are fully self-contained.

**Run all Go commands from `D:\download\garrage\backend`.** First `go test` run downloads Postgres binaries (~1–2 min); later runs are cached.

**Conventions for every task:** write the test, run it to see it fail, implement, run to see it pass, run `go vet ./...`, then commit with explicit `git add` paths from the repo root. Never chain test commands with pipes that mask exit codes — run each gate as its own command.

---

### Task 1: Go module scaffold + config

**Files:**
- Create: `backend/go.mod`
- Create: `backend/internal/config/config.go`
- Test: `backend/internal/config/config_test.go`

- [ ] **Step 1: Create the module**

```bash
cd D:/download/garrage && mkdir -p backend
cd backend && go mod init garage-backend
```

Then edit `backend/go.mod` so the go directive reads `go 1.24` (goose requires ≥1.23; the installed toolchain is 1.27).

- [ ] **Step 2: Write the failing config test**

Create `backend/internal/config/config_test.go`:

```go
package config

import "testing"

func TestLoadRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("JWT_SECRET", "s")
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

func TestLoadDefaultsPort(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PORT", "")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "8080" {
		t.Fatalf("port = %q, want 8080", cfg.Port)
	}
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `go test ./internal/config/ -v`
Expected: FAIL — build error `undefined: Load`.

- [ ] **Step 4: Implement config**

Create `backend/internal/config/config.go`:

```go
package config

import (
	"errors"
	"os"
)

type Config struct {
	Port        string
	DatabaseURL string
	JWTSecret   string
}

func Load() (Config, error) {
	cfg := Config{
		Port:        getenv("PORT", "8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
	}
	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return Config{}, errors.New("JWT_SECRET is required")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
```

- [ ] **Step 5: Run tests + vet to see them pass**

Run: `go test ./... -v`
Expected: `ok garage-backend/internal/config`, 3 tests PASS.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add backend/go.mod backend/internal/config/config.go backend/internal/config/config_test.go
git commit -m "feat(backend): module scaffold and env config"
```

---

### Task 2: Migrations 0001, embedded-Postgres test harness, server skeleton

**Files:**
- Create: `backend/migrations/0001_init.sql`
- Create: `backend/migrations/embed.go`
- Create: `backend/internal/httputil/httputil.go`
- Create: `backend/internal/itest/harness_test.go`
- Create: `backend/internal/itest/migrations_test.go`
- Create: `backend/cmd/server/main.go`
- Create: `backend/.gitignore`
- Modify: `backend/go.mod` / `backend/go.sum` (via go get)

- [ ] **Step 1: Add dependencies**

```bash
go get github.com/go-chi/chi/v5 github.com/jackc/pgx/v5 github.com/pressly/goose/v3 github.com/fergusstrange/embedded-postgres
go mod tidy
```

- [ ] **Step 2: Write the failing migration tests**

The embed directive requires at least one `.sql` file to compile, so this step also creates a stub migration; Step 4 replaces it with the full schema. The test run must start the embedded database and create `backend/.embedded-pg/`, so the gitignore comes first.

Create `backend/.gitignore`:

```
.embedded-pg/
```

Create `backend/migrations/embed.go`:

```go
// Package migrations embeds the SQL migration files so the server binary can
// run goose itself on boot with no external files.
package migrations

import "embed"

//go:embed *.sql
var FS embed.FS
```

Create `backend/migrations/0001_init.sql` (stub — no statements yet):

```sql
-- +goose Up
-- +goose Down
```

Create `backend/internal/itest/harness_test.go`:

```go
package itest

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"garage-backend/migrations"
)

const testDBPort = 54329
const testDBURL = "postgres://postgres:postgres@localhost:54329/garage_test?sslmode=disable"

var ctx = context.Background()
var pool *pgxpool.Pool

func TestMain(m *testing.M) {
	os.Exit(runTests(m))
}

func runTests(m *testing.M) int {
	pg := embeddedpostgres.NewDatabase(
		embeddedpostgres.DefaultConfig().
			Port(testDBPort).
			Database("garage_test").
			RuntimePath(filepath.Join("..", ".embedded-pg")),
	)
	if err := pg.Start(); err != nil {
		panic("start embedded postgres: " + err.Error())
	}
	defer pg.Stop()

	sqlDB, err := sql.Open("pgx", testDBURL)
	if err != nil {
		panic("open migrations db: " + err.Error())
	}
	defer sqlDB.Close()
	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		panic("goose dialect: " + err.Error())
	}
	if err := goose.UpContext(ctx, sqlDB, "."); err != nil {
		panic("goose up: " + err.Error())
	}

	pool, err = pgxpool.New(ctx, testDBURL)
	if err != nil {
		panic("connect pool: " + err.Error())
	}
	defer pool.Close()

	return m.Run()
}

func truncate(t *testing.T) {
	t.Helper()
	if _, err := pool.Exec(ctx,
		`TRUNCATE users, garages, memberships, refresh_tokens, garage_settings CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
}
```

Create `backend/internal/itest/migrations_test.go`:

```go
package itest

import "testing"

func TestMigrationsCreateAuthTables(t *testing.T) {
	want := []string{"users", "garages", "memberships", "refresh_tokens", "garage_settings"}
	rows, err := pool.Query(ctx,
		`SELECT table_name FROM information_schema.tables
		 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	got := map[string]bool{}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			t.Fatal(err)
		}
		got[name] = true
	}
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
	for _, w := range want {
		if !got[w] {
			t.Errorf("missing table %s", w)
		}
	}
}

func TestUsersEmailIsCaseInsensitive(t *testing.T) {
	truncate(t)
	if _, err := pool.Exec(ctx,
		`INSERT INTO users (email, password_hash, name) VALUES ('Mixed@Case.dev', 'h', 'C')`); err != nil {
		t.Fatal(err)
	}
	var n int
	if err := pool.QueryRow(ctx,
		`SELECT count(*) FROM users WHERE email = 'mixed@case.dev'`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("case-insensitive email lookup got %d rows, want 1", n)
	}
}
```

- [ ] **Step 3: Run the migration tests against the stub**

Run: `go test ./internal/itest/ -v`
Expected: FAIL — `missing table users` (goose ran the empty stub). First run downloads Postgres binaries — allow 1–3 minutes.

- [ ] **Step 4: Write the full schema**

Replace the entire contents of `backend/migrations/0001_init.sql` with:

```sql
-- +goose Up
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email citext NOT NULL UNIQUE,
    password_hash text NOT NULL,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE garages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE memberships (
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('owner', 'staff')),
    permissions text[] NOT NULL DEFAULT '{}',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (garage_id, user_id)
);
CREATE INDEX idx_memberships_user ON memberships(user_id);

CREATE TABLE refresh_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- Profile mirrors GarageProfile, config mirrors AppConfig defaults from the
-- Flutter app (lib/data/app_config.dart). One row per garage, created lazily.
CREATE TABLE garage_settings (
    garage_id uuid PRIMARY KEY REFERENCES garages(id) ON DELETE CASCADE,
    profile_name text NOT NULL DEFAULT '',
    tagline text NOT NULL DEFAULT '',
    address_line text NOT NULL DEFAULT '',
    city text NOT NULL DEFAULT '',
    phone text NOT NULL DEFAULT '',
    email text NOT NULL DEFAULT '',
    gstin text NOT NULL DEFAULT '',
    upi_id text NOT NULL DEFAULT '',
    default_tax_percent numeric(12,2) NOT NULL DEFAULT 18.0,
    tax_percent_options jsonb NOT NULL DEFAULT '[0,12,18,28]',
    invoice_due_days int NOT NULL DEFAULT 7,
    quotation_validity_options jsonb NOT NULL DEFAULT '[7,15,30]',
    working_days_per_month int NOT NULL DEFAULT 26,
    promised_delivery_hours int NOT NULL DEFAULT 6,
    invoice_notes text NOT NULL DEFAULT 'Thank you for choosing us! Standard warranty applies.',
    invoice_terms text NOT NULL DEFAULT 'All parts replaced carry manufacturer warranty. Labour warranty 30 days.',
    default_received_by text NOT NULL DEFAULT 'Cashier'
);

-- +goose Down
DROP TABLE IF EXISTS garage_settings;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS memberships;
DROP TABLE IF EXISTS garages;
DROP TABLE IF EXISTS users;
DROP EXTENSION IF EXISTS citext;
```

Run: `go test ./internal/itest/ -v`
Expected: PASS (2 tests). First run downloads Postgres binaries — allow 1–3 minutes.

- [ ] **Step 5: Server skeleton**

Create `backend/internal/httputil/httputil.go`:

```go
// Package httputil holds the shared JSON response and error-envelope helpers.
// Error envelope: {"error":{"code":"...","message":"..."}}.
package httputil

import (
	"encoding/json"
	"net/http"
)

type APIError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type errorEnvelope struct {
	Error APIError `json:"error"`
}

func JSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func Error(w http.ResponseWriter, status int, code, message string) {
	JSON(w, status, errorEnvelope{Error: APIError{Code: code, Message: message}})
}
```

Create `backend/cmd/server/main.go`:

```go
package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"garage-backend/internal/config"
	"garage-backend/migrations"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	if err := migrate(cfg.DatabaseURL); err != nil {
		log.Fatal(err)
	}

	r := chi.NewRouter()
	r.Get("/api/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
	}
	go func() {
		log.Printf("garage server listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

func migrate(databaseURL string) error {
	sqlDB, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return err
	}
	defer sqlDB.Close()
	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	return goose.UpContext(context.Background(), sqlDB, ".")
}
```

Create `backend/.gitignore`:

```
.embedded-pg/
```

Run: `go build ./...`
Expected: no output, exit 0.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add backend/go.mod backend/go.sum backend/migrations/0001_init.sql backend/migrations/embed.go backend/internal/httputil/httputil.go backend/internal/itest/harness_test.go backend/internal/itest/migrations_test.go backend/cmd/server/main.go backend/.gitignore
git commit -m "feat(backend): schema migrations, embedded-postgres test harness, server skeleton"
```

---

### Task 3: Auth primitives (bcrypt, JWT, refresh tokens, permissions)

**Files:**
- Create: `backend/internal/auth/password.go`
- Create: `backend/internal/auth/jwt.go`
- Create: `backend/internal/auth/refresh.go`
- Create: `backend/internal/auth/permissions.go`
- Test: `backend/internal/auth/auth_test.go`

- [ ] **Step 1: Add dependencies**

(No `go mod tidy` here — google/uuid is not imported until Task 4 and tidy would drop it.)

```bash
go get github.com/golang-jwt/jwt/v5 github.com/google/uuid golang.org/x/crypto/bcrypt
```

- [ ] **Step 2: Write the failing tests**

Create `backend/internal/auth/auth_test.go`:

```go
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
```

Run: `go test ./internal/auth/ -v`
Expected: FAIL — build error, `undefined: HashPassword`.

- [ ] **Step 3: Implement the primitives**

Create `backend/internal/auth/password.go`:

```go
package auth

import "golang.org/x/crypto/bcrypt"

const bcryptCost = 12

func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	return string(hash), err
}

func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}
```

Create `backend/internal/auth/jwt.go`:

```go
package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const AccessTokenTTL = 15 * time.Minute

// TokenIssuer issues and verifies HS256 access tokens whose only claims are
// sub (user id) and exp. Garage context is not in the token — it comes from
// the X-Garage-Id header per request so multi-garage users never re-login.
type TokenIssuer struct {
	secret []byte
}

func NewTokenIssuer(secret string) *TokenIssuer {
	return &TokenIssuer{secret: []byte(secret)}
}

func (t *TokenIssuer) Issue(userID string, now time.Time) (string, error) {
	claims := jwt.RegisteredClaims{
		Subject:   userID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(AccessTokenTTL)),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(t.secret)
}

func (t *TokenIssuer) Verify(tokenStr string) (string, error) {
	parsed, err := jwt.Parse(tokenStr, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return t.secret, nil
	})
	if err != nil || !parsed.Valid {
		return "", errors.New("invalid token")
	}
	sub, err := parsed.Claims.GetSubject()
	if err != nil || sub == "" {
		return "", errors.New("missing subject")
	}
	return sub, nil
}
```

Create `backend/internal/auth/refresh.go`:

```go
package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"time"
)

const RefreshTokenTTL = 30 * 24 * time.Hour

// NewRefreshToken returns (raw token, SHA-256 hash to store, expiry). Only the
// hash ever touches the database.
func NewRefreshToken(now time.Time) (raw string, hash string, expiresAt time.Time, err error) {
	buf := make([]byte, 32)
	if _, err = rand.Read(buf); err != nil {
		return "", "", time.Time{}, err
	}
	raw = hex.EncodeToString(buf)
	sum := sha256.Sum256([]byte(raw))
	return raw, hex.EncodeToString(sum[:]), now.Add(RefreshTokenTTL), nil
}

func HashRefreshToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
```

Create `backend/internal/auth/permissions.go`:

```go
package auth

import "errors"

// AllPermissions is the fixed permission matrix (11 keys, spec §6).
var AllPermissions = []string{
	"customers.manage", "vehicles.manage", "jobcards.manage", "quotations.manage",
	"invoices.manage", "payments.record", "expenses.manage", "staff.manage",
	"attendance.manage", "advances.manage", "settings.manage",
}

// DefaultStaffPermissions is granted when POST members omits `permissions`:
// everything EXCEPT expenses, staff, advances and settings management.
var DefaultStaffPermissions = []string{
	"customers.manage", "vehicles.manage", "jobcards.manage", "quotations.manage",
	"invoices.manage", "payments.record", "attendance.manage",
}

func ValidatePermissions(perms []string) error {
	valid := make(map[string]bool, len(AllPermissions))
	for _, p := range AllPermissions {
		valid[p] = true
	}
	for _, p := range perms {
		if !valid[p] {
			return errors.New("unknown permission: " + p)
		}
	}
	return nil
}
```

- [ ] **Step 4: Run tests + vet to see them pass**

Run: `go test ./internal/auth/ -v`
Expected: all 6 tests PASS.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add backend/go.mod backend/go.sum backend/internal/auth/password.go backend/internal/auth/jwt.go backend/internal/auth/refresh.go backend/internal/auth/permissions.go backend/internal/auth/auth_test.go
git commit -m "feat(backend): bcrypt passwords, HS256 access tokens, refresh tokens, permission matrix"
```

---

### Task 4: Models + permission middleware

**Files:**
- Create: `backend/internal/models/models.go`
- Create: `backend/internal/auth/context.go`
- Create: `backend/internal/auth/middleware.go`
- Test: `backend/internal/auth/middleware_test.go`

- [ ] **Step 1: Write the failing middleware tests**

Create `backend/internal/auth/middleware_test.go`:

```go
package auth

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

const testGarageID = "11111111-1111-1111-1111-111111111111"

type fakeUsers struct {
	user models.User
	err  error
}

func (f fakeUsers) UserByID(context.Context, string) (models.User, error) { return f.user, f.err }

type fakeMemberships struct {
	member models.Membership
	err    error
}

func (f fakeMemberships) MembershipFor(context.Context, string, string) (models.Membership, error) {
	return f.member, f.err
}

func newRequest(t *testing.T, url string, urlParams map[string]string, token, garageHeader string) *http.Request {
	t.Helper()
	r := httptest.NewRequest("GET", url, nil)
	rctx := chi.NewRouteContext()
	for k, v := range urlParams {
		rctx.URLParams.Add(k, v)
	}
	r = r.WithContext(context.WithValue(r.Context(), chi.RouteCtxKey, rctx))
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	if garageHeader != "" {
		r.Header.Set("X-Garage-Id", garageHeader)
	}
	return r
}

func ctxHandler(w http.ResponseWriter, r *http.Request) {
	httputil.JSON(w, 200, map[string]any{
		"user_id":     UserID(r.Context()),
		"garage_id":   GarageID(r.Context()),
		"role":        Role(r.Context()),
		"permissions": Permissions(r.Context()),
	})
}

func TestRequireAuth(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	users := fakeUsers{user: models.User{ID: "u-1"}}
	h := RequireAuth(issuer, users)(http.HandlerFunc(ctxHandler))

	t.Run("missing header is 401", func(t *testing.T) {
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, "", ""))
		if rr.Code != 401 {
			t.Fatalf("status = %d, want 401", rr.Code)
		}
		if !strings.Contains(rr.Body.String(), `"unauthorized"`) {
			t.Fatalf("body = %s", rr.Body.String())
		}
	})

	t.Run("valid token reaches handler with user id", func(t *testing.T) {
		token, _ := issuer.Issue("u-1", time.Now())
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, token, ""))
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
		if !strings.Contains(rr.Body.String(), `"u-1"`) {
			t.Fatalf("body = %s", rr.Body.String())
		}
	})

	t.Run("expired token is 401", func(t *testing.T) {
		token, _ := issuer.Issue("u-1", time.Now().Add(-AccessTokenTTL-time.Minute))
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, token, ""))
		if rr.Code != 401 {
			t.Fatalf("status = %d, want 401", rr.Code)
		}
	})
}

func TestRequireGarage(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	token, _ := issuer.Issue("u-1", time.Now())
	activeMember := models.Membership{
		GarageID: testGarageID, GarageName: "G", Role: "staff",
		Permissions: []string{"customers.manage"}, IsActive: true,
	}

	newChain := func(m fakeMemberships) http.Handler {
		return RequireAuth(issuer, fakeUsers{user: models.User{ID: "u-1"}})(
			RequireGarage(m)(http.HandlerFunc(ctxHandler)))
	}

	t.Run("header only", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, testGarageID))
		if rr.Code != 200 || !strings.Contains(rr.Body.String(), testGarageID) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
		if !strings.Contains(rr.Body.String(), `"role":"staff"`) {
			t.Fatalf("role not in context: %s", rr.Body.String())
		}
	})

	t.Run("url param used when header missing", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/garages/x/members", map[string]string{"garageId": testGarageID}, token, ""))
		if rr.Code != 200 || !strings.Contains(rr.Body.String(), testGarageID) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("header and url param mismatch is 400", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/garages/x/members", map[string]string{"garageId": testGarageID},
				token, "22222222-2222-2222-2222-222222222222"))
		if rr.Code != 400 || !strings.Contains(rr.Body.String(), `"invalid_request"`) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("missing garage id entirely is 400", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, ""))
		if rr.Code != 400 {
			t.Fatalf("status = %d, want 400", rr.Code)
		}
	})

	t.Run("non-member is 403", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{err: errors.New("no rows")}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, testGarageID))
		if rr.Code != 403 || !strings.Contains(rr.Body.String(), `"forbidden"`) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("deactivated member is 403", func(t *testing.T) {
		inactive := activeMember
		inactive.IsActive = false
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: inactive}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, testGarageID))
		if rr.Code != 403 || !strings.Contains(rr.Body.String(), "membership is deactivated") {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})
}

func TestRequirePermission(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	token, _ := issuer.Issue("u-1", time.Now())
	base := RequireAuth(issuer, fakeUsers{user: models.User{ID: "u-1"}})

	newChain := func(m fakeMemberships) http.Handler {
		return base(RequireGarage(m)(
			RequirePermission("expenses.manage")(http.HandlerFunc(ctxHandler))))
	}
	staffURL := "/api/garages/x/expenses"

	t.Run("owner bypasses", func(t *testing.T) {
		owner := models.Membership{GarageID: testGarageID, Role: "owner", Permissions: nil, IsActive: true}
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: owner}).ServeHTTP(rr,
			newRequest(t, staffURL, nil, token, testGarageID))
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("staff with permission passes", func(t *testing.T) {
		m := models.Membership{GarageID: testGarageID, Role: "staff",
			Permissions: []string{"expenses.manage"}, IsActive: true}
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: m}).ServeHTTP(rr,
			newRequest(t, staffURL, nil, token, testGarageID))
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("staff without permission is 403 naming the key", func(t *testing.T) {
		m := models.Membership{GarageID: testGarageID, Role: "staff",
			Permissions: []string{"customers.manage"}, IsActive: true}
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: m}).ServeHTTP(rr,
			newRequest(t, staffURL, nil, token, testGarageID))
		if rr.Code != 403 || !strings.Contains(rr.Body.String(), "expenses.manage") {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})
}
```

Run: `go test ./internal/auth/ -v`
Expected: FAIL — build error, `undefined: RequireAuth`.

- [ ] **Step 2: Implement models and middleware**

Create `backend/internal/models/models.go`:

```go
package models

import "time"

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	Name         string    `json:"name"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type Membership struct {
	GarageID    string   `json:"garage_id"`
	GarageName  string   `json:"garage_name"`
	Role        string   `json:"role"`
	Permissions []string `json:"permissions"`
	IsActive    bool     `json:"is_active"`
}

type Member struct {
	UserID      string   `json:"user_id"`
	Name        string   `json:"name"`
	Email       string   `json:"email"`
	Role        string   `json:"role"`
	Permissions []string `json:"permissions"`
	IsActive    bool     `json:"is_active"`
}

type Profile struct {
	Name        string `json:"name"`
	Tagline     string `json:"tagline"`
	AddressLine string `json:"address_line"`
	City        string `json:"city"`
	Phone       string `json:"phone"`
	Email       string `json:"email"`
	GSTIN       string `json:"gstin"`
	UPIID       string `json:"upi_id"`
}

type GarageSettings struct {
	GarageID                 string    `json:"garage_id"`
	Profile                  Profile   `json:"profile"`
	DefaultTaxPercent        float64   `json:"default_tax_percent"`
	TaxPercentOptions        []float64 `json:"tax_percent_options"`
	InvoiceDueDays           int       `json:"invoice_due_days"`
	QuotationValidityOptions []int     `json:"quotation_validity_options"`
	WorkingDaysPerMonth      int       `json:"working_days_per_month"`
	PromisedDeliveryHours    int       `json:"promised_delivery_hours"`
	InvoiceNotes             string    `json:"invoice_notes"`
	InvoiceTerms             string    `json:"invoice_terms"`
	DefaultReceivedBy        string    `json:"default_received_by"`
}

// DefaultSettings mirrors const AppConfig defaults in lib/data/app_config.dart.
func DefaultSettings(garageID string) GarageSettings {
	return GarageSettings{
		GarageID:                 garageID,
		Profile:                  Profile{Name: "My Garage"},
		DefaultTaxPercent:        18,
		TaxPercentOptions:        []float64{0, 12, 18, 28},
		InvoiceDueDays:           7,
		QuotationValidityOptions: []int{7, 15, 30},
		WorkingDaysPerMonth:      26,
		PromisedDeliveryHours:    6,
		InvoiceNotes:             "Thank you for choosing us! Standard warranty applies.",
		InvoiceTerms:             "All parts replaced carry manufacturer warranty. Labour warranty 30 days.",
		DefaultReceivedBy:        "Cashier",
	}
}
```

Create `backend/internal/auth/context.go`:

```go
package auth

import "context"

type ctxKey int

const (
	ctxUserID ctxKey = iota
	ctxGarageID
	ctxRole
	ctxPermissions
)

func UserID(ctx context.Context) string {
	v, _ := ctx.Value(ctxUserID).(string)
	return v
}

func GarageID(ctx context.Context) string {
	v, _ := ctx.Value(ctxGarageID).(string)
	return v
}

func Role(ctx context.Context) string {
	v, _ := ctx.Value(ctxRole).(string)
	return v
}

func Permissions(ctx context.Context) []string {
	v, _ := ctx.Value(ctxPermissions).([]string)
	return v
}
```

Create `backend/internal/auth/middleware.go`:

```go
package auth

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

type UserProvider interface {
	UserByID(ctx context.Context, id string) (models.User, error)
}

type MembershipProvider interface {
	MembershipFor(ctx context.Context, garageID, userID string) (models.Membership, error)
}

// RequireAuth verifies the bearer JWT, checks the user still exists, and puts
// the user id into the request context.
func RequireAuth(issuer *TokenIssuer, users UserProvider) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tokenStr, ok := cutBearer(r.Header.Get("Authorization"))
			if !ok {
				httputil.Error(w, 401, "unauthorized", "missing bearer token")
				return
			}
			userID, err := issuer.Verify(tokenStr)
			if err != nil {
				httputil.Error(w, 401, "unauthorized", "invalid or expired token")
				return
			}
			user, err := users.UserByID(r.Context(), userID)
			if err != nil {
				httputil.Error(w, 401, "unauthorized", "user no longer exists")
				return
			}
			ctx := context.WithValue(r.Context(), ctxUserID, user.ID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func cutBearer(header string) (string, bool) {
	const prefix = "Bearer "
	if len(header) <= len(prefix) || header[:len(prefix)] != prefix {
		return "", false
	}
	return header[len(prefix):], true
}

// RequireGarage resolves the garage context from the X-Garage-Id header
// (falling back to the {garageId} URL segment when the header is absent),
// rejects mismatches, and loads the caller's membership into context.
func RequireGarage(memberships MembershipProvider) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			garageID := r.Header.Get("X-Garage-Id")
			if urlGarage := chi.URLParam(r, "garageId"); urlGarage != "" {
				if garageID == "" {
					garageID = urlGarage
				} else if garageID != urlGarage {
					httputil.Error(w, 400, "invalid_request", "X-Garage-Id does not match garage in URL")
					return
				}
			}
			if _, err := uuid.Parse(garageID); err != nil {
				httputil.Error(w, 400, "invalid_request", "missing or invalid X-Garage-Id")
				return
			}
			m, err := memberships.MembershipFor(r.Context(), garageID, UserID(r.Context()))
			if err != nil {
				httputil.Error(w, 403, "forbidden", "not a member of this garage")
				return
			}
			if !m.IsActive {
				httputil.Error(w, 403, "forbidden", "membership is deactivated")
				return
			}
			ctx := r.Context()
			ctx = context.WithValue(ctx, ctxGarageID, m.GarageID)
			ctx = context.WithValue(ctx, ctxRole, m.Role)
			ctx = context.WithValue(ctx, ctxPermissions, m.Permissions)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequirePermission lets owners through unconditionally and checks staff
// against the membership's permission array.
func RequirePermission(key string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if Role(r.Context()) != "owner" {
				found := false
				for _, p := range Permissions(r.Context()) {
					if p == key {
						found = true
						break
					}
				}
				if !found {
					httputil.Error(w, 403, "forbidden", "missing permission: "+key)
					return
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}
```

- [ ] **Step 3: Run tests + vet to see them pass**

Run: `go test ./internal/auth/ -v`
Expected: all middleware subtests PASS (previous Task 3 tests still green).

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/models/models.go backend/internal/auth/context.go backend/internal/auth/middleware.go backend/internal/auth/middleware_test.go
git commit -m "feat(backend): shared models and auth/permission middleware"
```

---

### Task 5: Store — users, garages, memberships

**Files:**
- Create: `backend/internal/store/store.go`
- Create: `backend/internal/store/users.go`
- Create: `backend/internal/store/garages.go`
- Create: `backend/internal/store/memberships.go`
- Test: `backend/internal/itest/store_users_test.go`
- Test: `backend/internal/itest/store_members_test.go`
- Modify: `backend/internal/itest/harness_test.go` (add boolPtr helper)

- [ ] **Step 1: Add boolPtr to the harness**

Append to `backend/internal/itest/harness_test.go`:

```go
func boolPtr(b bool) *bool { return &b }
```

- [ ] **Step 2: Write the failing store tests**

Create `backend/internal/itest/store_users_test.go`:

```go
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
```

Create `backend/internal/itest/store_members_test.go`:

```go
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
	if m.Role != "staff" || m.GarageName != "Garage One" || len(m.Permissions) != 1 {
		t.Fatalf("membership = %+v", m)
	}
	if _, err := s.CreateMembership(ctx, om.GarageID, staff.ID, "staff", nil); !errors.Is(err, store.ErrDuplicate) {
		t.Fatalf("want ErrDuplicate, got %v", err)
	}

	got, err := s.MembershipFor(ctx, om.GarageID, staff.ID)
	if err != nil || got.Role != "staff" {
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
```

Run: `go test ./internal/itest/ -run 'TestUserStore|TestRegisterOwner|TestMembershipQueries' -v`
Expected: FAIL — build error, `undefined: store.New`.

- [ ] **Step 3: Implement the store**

Create `backend/internal/store/store.go`:

```go
// Package store holds all pgx queries. Every query is parameterized and
// scoped by garage_id supplied from the auth middleware, never from request
// bodies.
package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound  = errors.New("not found")
	ErrDuplicate = errors.New("duplicate")
)

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
```

Create `backend/internal/store/users.go`:

```go
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
```

Create `backend/internal/store/garages.go`:

```go
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
	defer tx.Rollback(ctx)

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
```

Create `backend/internal/store/memberships.go`:

```go
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
	defer tx.Rollback(ctx)

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
	defer tx.Rollback(ctx)

	if patch.PasswordHash != nil {
		if _, err := tx.Exec(ctx,
			`UPDATE users SET password_hash = $1 WHERE id = $2`, *patch.PasswordHash, userID); err != nil {
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
```

- [ ] **Step 4: Run tests + vet to see them pass**

Run: `go test ./internal/itest/ -v`
Expected: all tests PASS including new store tests.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/store/store.go backend/internal/store/users.go backend/internal/store/garages.go backend/internal/store/memberships.go backend/internal/itest/harness_test.go backend/internal/itest/store_users_test.go backend/internal/itest/store_members_test.go
git commit -m "feat(backend): users, garages and memberships store"
```

---

### Task 6: Store — refresh tokens + settings

**Files:**
- Create: `backend/internal/store/refresh_tokens.go`
- Create: `backend/internal/store/settings.go`
- Test: `backend/internal/itest/store_refresh_test.go`
- Test: `backend/internal/itest/store_settings_test.go`

- [ ] **Step 1: Write the failing tests**

Create `backend/internal/itest/store_refresh_test.go`:

```go
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
}
```

Create `backend/internal/itest/store_settings_test.go`:

```go
package itest

import (
	"testing"

	"garage-backend/internal/auth"
	"garage-backend/internal/store"
)

func TestSettingsGetOrCreateDefaults(t *testing.T) {
	truncate(t)
	s := store.New(pool)
	_, m, err := s.RegisterOwner(ctx, "s@test.dev", "h", "S", "Garage S", auth.AllPermissions)
	if err != nil {
		t.Fatal(err)
	}

	gs, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil {
		t.Fatalf("get or create: %v", err)
	}
	if gs.GarageID != m.GarageID {
		t.Fatalf("garage_id = %s", gs.GarageID)
	}
	if gs.DefaultTaxPercent != 18 || gs.InvoiceDueDays != 7 {
		t.Fatalf("tax/due = %v/%v", gs.DefaultTaxPercent, gs.InvoiceDueDays)
	}
	if len(gs.TaxPercentOptions) != 4 || gs.TaxPercentOptions[2] != 18 {
		t.Fatalf("tax options = %v", gs.TaxPercentOptions)
	}
	if len(gs.QuotationValidityOptions) != 3 {
		t.Fatalf("validity options = %v", gs.QuotationValidityOptions)
	}
	if gs.WorkingDaysPerMonth != 26 || gs.PromisedDeliveryHours != 6 {
		t.Fatalf("working days/hours = %v/%v", gs.WorkingDaysPerMonth, gs.PromisedDeliveryHours)
	}
	if gs.InvoiceNotes == "" || gs.InvoiceTerms == "" || gs.DefaultReceivedBy != "Cashier" {
		t.Fatalf("notes/terms/receivedBy = %q/%q/%q", gs.InvoiceNotes, gs.InvoiceTerms, gs.DefaultReceivedBy)
	}

	again, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil || again.InvoiceDueDays != gs.InvoiceDueDays {
		t.Fatalf("get-or-create must be idempotent: %+v %v", again, err)
	}
}

func TestSettingsUpdate(t *testing.T) {
	truncate(t)
	s := store.New(pool)
	_, m, err := s.RegisterOwner(ctx, "s2@test.dev", "h", "S", "Garage S2", auth.AllPermissions)
	if err != nil {
		t.Fatal(err)
	}
	gs, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil {
		t.Fatal(err)
	}
	gs.InvoiceDueDays = 14
	gs.Profile.City = "Pune"
	if err := s.UpdateSettings(ctx, gs); err != nil {
		t.Fatalf("update: %v", err)
	}
	got, err := s.GetOrCreateSettings(ctx, m.GarageID)
	if err != nil {
		t.Fatal(err)
	}
	if got.InvoiceDueDays != 14 || got.Profile.City != "Pune" || got.DefaultTaxPercent != 18 {
		t.Fatalf("after update: %+v", got)
	}
}
```

Run: `go test ./internal/itest/ -run 'TestRefreshTokenLifecycle|TestSettings' -v`
Expected: FAIL — build error, `undefined: s.InsertRefreshToken`.

- [ ] **Step 2: Implement**

Create `backend/internal/store/refresh_tokens.go`:

```go
package store

import (
	"context"
	"time"
)

func (s *Store) InsertRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt)
	return mapPGError(err)
}

// RotateRefreshToken atomically revokes the old token (only if it is active:
// present, unrevoked, unexpired) and inserts the replacement, returning the
// owning user id. Anything else returns ErrNotFound.
func (s *Store) RotateRefreshToken(ctx context.Context, oldHash, newHash string, newExpiresAt time.Time) (string, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	var userID string
	err = tx.QueryRow(ctx,
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()
		 RETURNING user_id`, oldHash).Scan(&userID)
	if err != nil {
		return "", mapPGError(err)
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, newHash, newExpiresAt); err != nil {
		return "", mapPGError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return userID, nil
}

// RevokeRefreshToken is idempotent: revoking an unknown or already-revoked
// token is not an error.
func (s *Store) RevokeRefreshToken(ctx context.Context, tokenHash string) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE token_hash = $1 AND revoked_at IS NULL`, tokenHash)
	return mapPGError(err)
}
```

Create `backend/internal/store/settings.go`:

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const settingsColumns = `garage_id, profile_name, tagline, address_line, city, phone, email, gstin, upi_id,
	default_tax_percent, tax_percent_options, invoice_due_days, quotation_validity_options,
	working_days_per_month, promised_delivery_hours, invoice_notes, invoice_terms, default_received_by`

func scanSettings(row scanner) (models.GarageSettings, error) {
	var gs models.GarageSettings
	err := row.Scan(&gs.GarageID, &gs.Profile.Name, &gs.Profile.Tagline, &gs.Profile.AddressLine,
		&gs.Profile.City, &gs.Profile.Phone, &gs.Profile.Email, &gs.Profile.GSTIN, &gs.Profile.UPIID,
		&gs.DefaultTaxPercent, &gs.TaxPercentOptions, &gs.InvoiceDueDays, &gs.QuotationValidityOptions,
		&gs.WorkingDaysPerMonth, &gs.PromisedDeliveryHours, &gs.InvoiceNotes, &gs.InvoiceTerms,
		&gs.DefaultReceivedBy)
	return gs, mapPGError(err)
}

// GetOrCreateSettings lazily creates the defaults row for a garage, then
// returns it. Idempotent.
func (s *Store) GetOrCreateSettings(ctx context.Context, garageID string) (models.GarageSettings, error) {
	d := models.DefaultSettings(garageID)
	_, err := s.Pool.Exec(ctx, `INSERT INTO garage_settings
		(garage_id, profile_name, tagline, address_line, city, phone, email, gstin, upi_id,
		 default_tax_percent, tax_percent_options, invoice_due_days, quotation_validity_options,
		 working_days_per_month, promised_delivery_hours, invoice_notes, invoice_terms, default_received_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
		ON CONFLICT (garage_id) DO NOTHING`,
		d.GarageID, d.Profile.Name, d.Profile.Tagline, d.Profile.AddressLine, d.Profile.City,
		d.Profile.Phone, d.Profile.Email, d.Profile.GSTIN, d.Profile.UPIID, d.DefaultTaxPercent,
		d.TaxPercentOptions, d.InvoiceDueDays, d.QuotationValidityOptions, d.WorkingDaysPerMonth,
		d.PromisedDeliveryHours, d.InvoiceNotes, d.InvoiceTerms, d.DefaultReceivedBy)
	if err != nil {
		return models.GarageSettings{}, err
	}
	return scanSettings(s.Pool.QueryRow(ctx,
		`SELECT `+settingsColumns+` FROM garage_settings WHERE garage_id = $1`, garageID))
}

func (s *Store) UpdateSettings(ctx context.Context, gs models.GarageSettings) error {
	tag, err := s.Pool.Exec(ctx, `UPDATE garage_settings SET
		profile_name=$2, tagline=$3, address_line=$4, city=$5, phone=$6, email=$7, gstin=$8, upi_id=$9,
		default_tax_percent=$10, tax_percent_options=$11, invoice_due_days=$12, quotation_validity_options=$13,
		working_days_per_month=$14, promised_delivery_hours=$15, invoice_notes=$16, invoice_terms=$17,
		default_received_by=$18
		WHERE garage_id=$1`,
		gs.GarageID, gs.Profile.Name, gs.Profile.Tagline, gs.Profile.AddressLine, gs.Profile.City,
		gs.Profile.Phone, gs.Profile.Email, gs.Profile.GSTIN, gs.Profile.UPIID, gs.DefaultTaxPercent,
		gs.TaxPercentOptions, gs.InvoiceDueDays, gs.QuotationValidityOptions, gs.WorkingDaysPerMonth,
		gs.PromisedDeliveryHours, gs.InvoiceNotes, gs.InvoiceTerms, gs.DefaultReceivedBy)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
```

- [ ] **Step 3: Run tests + vet to see them pass**

Run: `go test ./internal/itest/ -v`
Expected: all tests PASS.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/store/refresh_tokens.go backend/internal/store/settings.go backend/internal/itest/store_refresh_test.go backend/internal/itest/store_settings_test.go
git commit -m "feat(backend): refresh token rotation and garage settings store"
```

---

### Task 7: Auth endpoints + router

**Files:**
- Create: `backend/internal/api/router.go`
- Create: `backend/internal/api/auth.go`
- Modify: `backend/cmd/server/main.go` (serve `api.NewRouter`)
- Modify: `backend/internal/itest/harness_test.go` (add HTTP test server + request helpers)
- Test: `backend/internal/itest/auth_flow_test.go`

- [ ] **Step 1: Add the cors dependency**

```bash
go get github.com/go-chi/cors
go mod tidy
```

- [ ] **Step 2: Extend the harness with the HTTP test server and helpers**

Replace `backend/internal/itest/harness_test.go` in full with:

```go
package itest

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
	"garage-backend/migrations"
)

const testDBPort = 54329
const testDBURL = "postgres://postgres:postgres@localhost:54329/garage_test?sslmode=disable"

var ctx = context.Background()
var pool *pgxpool.Pool
var ts *httptest.Server

func TestMain(m *testing.M) {
	os.Exit(runTests(m))
}

func runTests(m *testing.M) int {
	pg := embeddedpostgres.NewDatabase(
		embeddedpostgres.DefaultConfig().
			Port(testDBPort).
			Database("garage_test").
			RuntimePath(filepath.Join("..", ".embedded-pg")),
	)
	if err := pg.Start(); err != nil {
		panic("start embedded postgres: " + err.Error())
	}
	defer pg.Stop()

	sqlDB, err := sql.Open("pgx", testDBURL)
	if err != nil {
		panic("open migrations db: " + err.Error())
	}
	defer sqlDB.Close()
	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		panic("goose dialect: " + err.Error())
	}
	if err := goose.UpContext(ctx, sqlDB, "."); err != nil {
		panic("goose up: " + err.Error())
	}

	pool, err = pgxpool.New(ctx, testDBURL)
	if err != nil {
		panic("connect pool: " + err.Error())
	}
	defer pool.Close()

	ts = httptest.NewServer(api.NewRouter(&api.Server{
		Store:  store.New(pool),
		Issuer: auth.NewTokenIssuer("test-secret"),
	}))
	defer ts.Close()

	return m.Run()
}

func truncate(t *testing.T) {
	t.Helper()
	if _, err := pool.Exec(ctx,
		`TRUNCATE users, garages, memberships, refresh_tokens, garage_settings CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
}

func boolPtr(b bool) *bool { return &b }

func mustUnmarshal(t *testing.T, data []byte, dst any) {
	t.Helper()
	if err := json.Unmarshal(data, dst); err != nil {
		t.Fatalf("decode response %s: %v", data, err)
	}
}

func decodeError(t *testing.T, data []byte) (code, message string) {
	t.Helper()
	var e struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	mustUnmarshal(t, data, &e)
	return e.Error.Code, e.Error.Message
}

// doJSON performs a request against the test server. Empty token or garageID
// skips that header.
func doJSON(t *testing.T, method, path, token, garageID string, body any) (int, []byte) {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatal(err)
		}
	}
	req, err := http.NewRequest(method, ts.URL+path, &buf)
	if err != nil {
		t.Fatal(err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if garageID != "" {
		req.Header.Set("X-Garage-Id", garageID)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp.StatusCode, data
}

type authResponse struct {
	AccessToken  string              `json:"access_token"`
	RefreshToken string              `json:"refresh_token"`
	User         models.User         `json:"user"`
	Memberships  []models.Membership `json:"memberships"`
}

func registerOwner(t *testing.T, suffix string) authResponse {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name":       "Owner " + suffix,
		"email":      "owner-" + suffix + "@test.dev",
		"password":   "password123",
		"garageName": "Garage " + suffix,
	})
	if status != 201 {
		t.Fatalf("register: status %d body %s", status, data)
	}
	var resp authResponse
	mustUnmarshal(t, data, &resp)
	return resp
}
```

- [ ] **Step 3: Write the failing auth flow tests**

Create `backend/internal/itest/auth_flow_test.go`:

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestRegisterCreatesOwnerAndMe(t *testing.T) {
	truncate(t)
	resp := registerOwner(t, "me")
	if resp.User.Email != "owner-me@test.dev" {
		t.Fatalf("user = %+v", resp.User)
	}
	if len(resp.Memberships) != 1 {
		t.Fatalf("memberships = %+v", resp.Memberships)
	}
	m := resp.Memberships[0]
	if m.Role != "owner" || m.GarageName != "Garage me" || len(m.Permissions) != 11 || !m.IsActive {
		t.Fatalf("membership = %+v", m)
	}

	status, data := doJSON(t, "GET", "/api/me", resp.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("me: status %d body %s", status, data)
	}
	var me struct {
		User        models.User         `json:"user"`
		Memberships []models.Membership `json:"memberships"`
	}
	mustUnmarshal(t, data, &me)
	if me.User.ID != resp.User.ID || len(me.Memberships) != 1 {
		t.Fatalf("me = %+v", me)
	}
}

func TestRegisterValidation(t *testing.T) {
	truncate(t)
	registerOwner(t, "dup")

	status, data := doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name": "X", "email": "owner-dup@test.dev", "password": "password123", "garageName": "Y",
	})
	if status != 409 {
		t.Fatalf("duplicate email: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "conflict" {
		t.Fatalf("code = %s, want conflict", code)
	}

	status, data = doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name": "X", "email": "short@test.dev", "password": "short", "garageName": "Y",
	})
	if status != 400 {
		t.Fatalf("short password: status %d body %s", status, data)
	}

	status, data = doJSON(t, "POST", "/api/auth/register", "", "", map[string]string{
		"name": "", "email": "x@test.dev", "password": "password123", "garageName": "Y",
	})
	if status != 400 {
		t.Fatalf("missing name: status %d body %s", status, data)
	}
}

func TestLogin(t *testing.T) {
	truncate(t)
	registerOwner(t, "login")

	status, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-login@test.dev", "password": "wrongpass1",
	})
	if status != 401 {
		t.Fatalf("wrong password: status %d body %s", status, data)
	}

	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "owner-login@test.dev", "password": "password123",
	})
	if status != 200 {
		t.Fatalf("login: status %d body %s", status, data)
	}
	var resp authResponse
	mustUnmarshal(t, data, &resp)
	if resp.AccessToken == "" || resp.RefreshToken == "" || len(resp.Memberships) != 1 {
		t.Fatalf("login response = %+v", resp)
	}

	status, data = doJSON(t, "GET", "/api/me", resp.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("me after login: status %d body %s", status, data)
	}
}

func TestMeRequiresAuth(t *testing.T) {
	truncate(t)
	status, data := doJSON(t, "GET", "/api/me", "", "", nil)
	if status != 401 {
		t.Fatalf("no token: status %d body %s", status, data)
	}
	status, data = doJSON(t, "GET", "/api/me", "garbage.token.here", "", nil)
	if status != 401 {
		t.Fatalf("garbage token: status %d body %s", status, data)
	}
}

func TestRefreshRotationAndLogout(t *testing.T) {
	truncate(t)
	resp := registerOwner(t, "rot")

	status, data := doJSON(t, "POST", "/api/auth/refresh", "", "",
		map[string]string{"refresh_token": resp.RefreshToken})
	if status != 200 {
		t.Fatalf("refresh: status %d body %s", status, data)
	}
	var pair struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	mustUnmarshal(t, data, &pair)
	if pair.AccessToken == "" || pair.RefreshToken == "" || pair.RefreshToken == resp.RefreshToken {
		t.Fatalf("refresh pair = %+v", pair)
	}

	status, data = doJSON(t, "POST", "/api/auth/refresh", "", "",
		map[string]string{"refresh_token": resp.RefreshToken})
	if status != 401 {
		t.Fatalf("old refresh must be rotated out: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "POST", "/api/auth/logout", "", "",
		map[string]string{"refresh_token": pair.RefreshToken})
	if status != 204 {
		t.Fatalf("logout: status %d", status)
	}

	status, data = doJSON(t, "POST", "/api/auth/refresh", "", "",
		map[string]string{"refresh_token": pair.RefreshToken})
	if status != 401 {
		t.Fatalf("refresh after logout: status %d body %s", status, data)
	}
}

func TestGarageIsolation(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "a")
	b := registerOwner(t, "b")
	aGarage := a.Memberships[0].GarageID

	status, data := doJSON(t, "GET", "/api/garages/"+aGarage+"/members", b.AccessToken, aGarage, nil)
	if status != 403 {
		t.Fatalf("cross-garage access: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "forbidden" {
		t.Fatalf("code = %s, want forbidden", code)
	}

	status, data = doJSON(t, "GET", "/api/garages/"+aGarage+"/members", a.AccessToken, "", nil)
	if status != 400 {
		t.Fatalf("missing garage header: status %d body %s", status, data)
	}
}
```

Run: `go test ./internal/itest/ -run 'TestRegister|TestLogin|TestMe|TestRefresh|TestGarageIsolation' -v`
Expected: FAIL — build error, `undefined: api.NewRouter`.

- [ ] **Step 4: Implement the router and auth handlers**

Create `backend/internal/api/router.go`:

```go
// Package api holds the chi router and HTTP handlers, one file per domain.
package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

type Server struct {
	Store  *store.Store
	Issuer *auth.TokenIssuer
}

func NewRouter(s *Server) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Logger, middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Authorization", "Content-Type", "X-Garage-Id"},
		MaxAge:         300,
	}))

	r.Get("/api/health", func(w http.ResponseWriter, _ *http.Request) {
		httputil.JSON(w, 200, map[string]string{"status": "ok"})
	})

	r.Route("/api", func(r chi.Router) {
		r.Post("/auth/register", s.handleRegister)
		r.Post("/auth/login", s.handleLogin)
		r.Post("/auth/refresh", s.handleRefresh)
		r.Post("/auth/logout", s.handleLogout)

		r.Group(func(r chi.Router) {
			r.Use(auth.RequireAuth(s.Issuer, s.Store))
			r.Get("/me", s.handleMe)
		})
	})
	return r
}
```

(The `/garages/{garageId}` subtree is added in Tasks 8 and 9 so every task compiles on its own.)

Create `backend/internal/api/auth.go`:

```go
package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

type credentialsRequest struct {
	Name       string `json:"name"`
	Email      string `json:"email"`
	Password   string `json:"password"`
	GarageName string `json:"garageName"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}
	if req.Name == "" || req.Email == "" || req.Password == "" || req.GarageName == "" {
		httputil.Error(w, 400, "invalid_request", "name, email, password and garageName are required")
		return
	}
	if len(req.Password) < 8 {
		httputil.Error(w, 400, "invalid_request", "password must be at least 8 characters")
		return
	}
	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not hash password")
		return
	}
	user, membership, err := s.Store.RegisterOwner(r.Context(),
		req.Email, hash, req.Name, req.GarageName, auth.AllPermissions)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "email already registered")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not register")
		return
	}
	s.writeSession(w, r, 201, user, []models.Membership{membership})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}
	if req.Email == "" || req.Password == "" {
		httputil.Error(w, 400, "invalid_request", "email and password are required")
		return
	}
	user, err := s.Store.UserByEmail(r.Context(), req.Email)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 401, "unauthorized", "invalid email or password")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load user")
		return
	}
	if !auth.CheckPassword(user.PasswordHash, req.Password) {
		httputil.Error(w, 401, "unauthorized", "invalid email or password")
		return
	}
	memberships, err := s.Store.MembershipsForUser(r.Context(), user.ID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load memberships")
		return
	}
	s.writeSession(w, r, 200, user, memberships)
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}
	if req.RefreshToken == "" {
		httputil.Error(w, 400, "invalid_request", "refresh_token is required")
		return
	}
	newRaw, newHash, expiresAt, err := auth.NewRefreshToken(time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue refresh token")
		return
	}
	userID, err := s.Store.RotateRefreshToken(r.Context(),
		auth.HashRefreshToken(req.RefreshToken), newHash, expiresAt)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 401, "unauthorized", "invalid or expired refresh token")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not rotate refresh token")
		return
	}
	access, err := s.Issuer.Issue(userID, time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue access token")
		return
	}
	httputil.JSON(w, 200, map[string]string{
		"access_token":  access,
		"refresh_token": newRaw,
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}
	if req.RefreshToken == "" {
		httputil.Error(w, 400, "invalid_request", "refresh_token is required")
		return
	}
	if err := s.Store.RevokeRefreshToken(r.Context(), auth.HashRefreshToken(req.RefreshToken)); err != nil {
		httputil.Error(w, 500, "internal", "could not revoke refresh token")
		return
	}
	w.WriteHeader(204)
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	user, err := s.Store.UserByID(r.Context(), auth.UserID(r.Context()))
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 401, "unauthorized", "user no longer exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load user")
		return
	}
	memberships, err := s.Store.MembershipsForUser(r.Context(), user.ID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load memberships")
		return
	}
	httputil.JSON(w, 200, map[string]any{"user": user, "memberships": memberships})
}

func (s *Server) writeSession(w http.ResponseWriter, r *http.Request, status int, user models.User, memberships []models.Membership) {
	access, err := s.Issuer.Issue(user.ID, time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue access token")
		return
	}
	raw, hash, expiresAt, err := auth.NewRefreshToken(time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue refresh token")
		return
	}
	if err := s.Store.InsertRefreshToken(r.Context(), user.ID, hash, expiresAt); err != nil {
		httputil.Error(w, 500, "internal", "could not store refresh token")
		return
	}
	httputil.JSON(w, status, map[string]any{
		"access_token":  access,
		"refresh_token": raw,
		"user":          user,
		"memberships":   memberships,
	})
}
```

Replace `backend/cmd/server/main.go` in full (it now serves the real router):

```go
package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/config"
	"garage-backend/internal/store"
	"garage-backend/migrations"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	if err := migrate(cfg.DatabaseURL); err != nil {
		log.Fatal(err)
	}

	handler := api.NewRouter(&api.Server{
		Store:  store.New(pool),
		Issuer: auth.NewTokenIssuer(cfg.JWTSecret),
	})

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}
	go func() {
		log.Printf("garage server listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

func migrate(databaseURL string) error {
	sqlDB, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return err
	}
	defer sqlDB.Close()
	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	return goose.UpContext(context.Background(), sqlDB, ".")
}
```

(The `chi` import from the Task 2 skeleton disappears here — the router now owns routing.)

- [ ] **Step 5: Run tests + vet to see them pass**

Run: `go test ./internal/itest/ -v`
Expected: all tests PASS (store tests still green).

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add backend/go.mod backend/go.sum backend/internal/api/router.go backend/internal/api/auth.go backend/cmd/server/main.go backend/internal/itest/harness_test.go backend/internal/itest/auth_flow_test.go
git commit -m "feat(backend): register/login/refresh/logout/me endpoints"
```

---

### Task 8: Members endpoints

> Task 7 note: `TestGarageIsolation` (in Task 7's test sketch above) was deferred to this
> task — its routes only exist here. Add it unchanged to members_test.go in Step 1.

**Files:**
- Create: `backend/internal/api/members.go`
- Test: `backend/internal/itest/members_test.go`

- [ ] **Step 1: Write the failing tests**

Create `backend/internal/itest/members_test.go`:

```go
package itest

import (
	"strings"
	"testing"

	"garage-backend/internal/models"
)

func membersURL(garageID string) string { return "/api/garages/" + garageID + "/members" }

func createMember(t *testing.T, owner authResponse, garageID string, body map[string]any) (int, []byte, models.Member) {
	t.Helper()
	status, data := doJSON(t, "POST", membersURL(garageID), owner.AccessToken, garageID, body)
	var member models.Member
	if status == 201 {
		mustUnmarshal(t, data, &member)
	}
	return status, data, member
}

func TestCreateMemberWithDefaults(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "m1")
	garageID := owner.Memberships[0].GarageID

	status, data, member := createMember(t, owner, garageID, map[string]any{
		"name": "Staff One", "email": "staff1@test.dev", "password": "password123",
	})
	if status != 201 {
		t.Fatalf("create member: status %d body %s", status, data)
	}
	if member.Role != "staff" || !member.IsActive || member.Email != "staff1@test.dev" {
		t.Fatalf("member = %+v", member)
	}
	if len(member.Permissions) != 7 {
		t.Fatalf("default staff permissions = %v, want 7 entries", member.Permissions)
	}
	for _, p := range member.Permissions {
		if p == "expenses.manage" || p == "staff.manage" || p == "advances.manage" || p == "settings.manage" {
			t.Fatalf("default staff set must exclude %s", p)
		}
	}

	status, data = doJSON(t, "GET", membersURL(garageID), owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list members: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Member `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].Role != "owner" {
		t.Fatalf("items = %+v", list.Items)
	}

	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff1@test.dev", "password": "password123",
	})
	if status != 200 {
		t.Fatalf("staff login: status %d body %s", status, data)
	}
	var login authResponse
	mustUnmarshal(t, data, &login)
	status, _ = doJSON(t, "GET", "/api/me", login.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("staff me: status %d", status)
	}
}

func TestMembersRequirePermission(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "perm")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-perm@test.dev", "password": "password123",
	})

	_, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": staff.Email, "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data = doJSON(t, "GET", membersURL(garageID), login.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff listing members: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "staff.manage") {
		t.Fatalf("message = %s", message)
	}
}

func TestCreateMemberPermissionValidation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pv")
	garageID := owner.Memberships[0].GarageID

	status, data, member := createMember(t, owner, garageID, map[string]any{
		"name": "Parts Staff", "email": "parts@test.dev", "password": "password123",
		"permissions": []string{"customers.manage", "expenses.manage"},
	})
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if len(member.Permissions) != 2 {
		t.Fatalf("permissions = %v", member.Permissions)
	}

	status, data, _ = createMember(t, owner, garageID, map[string]any{
		"name": "Bad", "email": "bad@test.dev", "password": "password123",
		"permissions": []string{"bogus.key"},
	})
	if status != 400 {
		t.Fatalf("unknown permission: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "bogus.key") {
		t.Fatalf("message = %s", message)
	}
}

func TestCreateMemberExistingUser(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "a")
	b := registerOwner(t, "b")
	bGarage := b.Memberships[0].GarageID

	// Garage B's owner adds garage A's owner (existing user, password ignored),
	// granting staff.manage so the multi-garage token can be exercised below.
	status, data, member := createMember(t, b, bGarage, map[string]any{
		"name": "Owner A", "email": "owner-a@test.dev", "password": "ignored-pw",
		"permissions": []string{"staff.manage"},
	})
	if status != 201 {
		t.Fatalf("existing-user member: status %d body %s", status, data)
	}
	if member.UserID != a.User.ID {
		t.Fatalf("must reuse the existing user, got %+v", member)
	}

	status, data, _ = createMember(t, b, bGarage, map[string]any{
		"name": "Owner A", "email": "owner-a@test.dev",
	})
	if status != 409 {
		t.Fatalf("double membership: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "already a member") {
		t.Fatalf("message = %s", message)
	}

	// Multi-garage: A's token can now resolve B's garage too.
	status, _ = doJSON(t, "GET", membersURL(bGarage), a.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("A should be a member of B's garage now: status %d", status)
	}
}

func TestUpdateMember(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "up")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-up@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"permissions": []string{"customers.manage"}})
	if status != 200 {
		t.Fatalf("patch permissions: status %d body %s", status, data)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"password": "newpassword1"})
	if status != 200 {
		t.Fatalf("patch password: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-up@test.dev", "password": "password123",
	})
	if status != 401 {
		t.Fatalf("old password must stop working, got %d", status)
	}
	status, _ = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-up@test.dev", "password": "newpassword1",
	})
	if status != 200 {
		t.Fatalf("new password must work, got %d", status)
	}

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"is_active": false})
	if status != 200 {
		t.Fatalf("deactivate: status %d body %s", status, data)
	}
	status, data = doJSON(t, "GET", membersURL(garageID), owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list after deactivate: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Member `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	for _, m := range list.Items {
		if m.UserID == staff.UserID && m.IsActive {
			t.Fatal("is_active=false must persist")
		}
	}
}

func TestDeactivatedMemberBlocked(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "deact")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-deact@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID,
		map[string]any{"is_active": false})
	if status != 200 {
		t.Fatalf("deactivate: status %d body %s", status, data)
	}

	_, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-deact@test.dev", "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data = doJSON(t, "GET", membersURL(garageID), login.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("deactivated member: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "membership is deactivated") {
		t.Fatalf("message = %s", message)
	}
}

func TestUpdateMemberPasswordOwnerOnly(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pw")
	garageID := owner.Memberships[0].GarageID
	_, _, manager := createMember(t, owner, garageID, map[string]any{
		"name": "Manager", "email": "manager@test.dev", "password": "password123",
		"permissions": []string{"staff.manage"},
	})
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-pw@test.dev", "password": "password123",
	})

	_, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "manager@test.dev", "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, login.AccessToken, garageID,
		map[string]any{"password": "hacked-pw1"})
	if status != 403 {
		t.Fatalf("staff password reset: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "owner-only") {
		t.Fatalf("message = %s", message)
	}

	status, _ = doJSON(t, "PATCH", membersURL(garageID)+"/"+staff.UserID, login.AccessToken, garageID,
		map[string]any{"permissions": []string{"customers.manage"}})
	if status != 200 {
		t.Fatalf("staff with staff.manage may change permissions, got %d", status)
	}
}

func TestUpdateOwnerRejected(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "own")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "PATCH", membersURL(garageID)+"/"+owner.User.ID, owner.AccessToken, garageID,
		map[string]any{"permissions": []string{"customers.manage"}})
	if status != 422 {
		t.Fatalf("patch owner: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); !strings.Contains(message, "cannot modify the owner") {
		t.Fatalf("message = %s", message)
	}
}

func TestDeleteMember(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "del")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-del@test.dev", "password": "password123",
	})
	_, _, manager := createMember(t, owner, garageID, map[string]any{
		"name": "Manager", "email": "manager-del@test.dev", "password": "password123",
		"permissions": []string{"staff.manage"},
	})

	_, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "manager-del@test.dev", "password": "password123",
	})
	var managerLogin authResponse
	mustUnmarshal(t, data, &managerLogin)

	status, data := doJSON(t, "DELETE", membersURL(garageID)+"/"+staff.UserID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("owner delete: status %d body %s", status, data)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/"+owner.User.ID, managerLogin.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff delete must be owner-only, got %d", status)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/"+owner.User.ID, owner.AccessToken, garageID, nil)
	if status != 422 {
		t.Fatalf("delete owner: status %d, want 422", status)
	}

	status, _ = doJSON(t, "DELETE", membersURL(garageID)+"/00000000-0000-0000-0000-000000000000", owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("delete unknown: status %d, want 404", status)
	}
}
```

Run: `go test ./internal/itest/ -run 'TestCreateMember|TestMembers|TestUpdate|TestDelete|TestDeactivated' -v`
Expected: FAIL — the members routes are not registered yet, so every request 404s and the status assertions fail.

- [ ] **Step 2: Implement members handlers**

Modify `backend/internal/api/router.go` — replace the `/me` group with the group below, which mounts the garage subtree with the members routes:

```go
		r.Group(func(r chi.Router) {
			r.Use(auth.RequireAuth(s.Issuer, s.Store))
			r.Get("/me", s.handleMe)

			r.Route("/garages/{garageId}", func(r chi.Router) {
				r.Use(auth.RequireGarage(s.Store))
				r.Route("/members", func(r chi.Router) {
					r.Use(auth.RequirePermission("staff.manage"))
					r.Get("/", s.listMembers)
					r.Post("/", s.createMember)
					r.Patch("/{userId}", s.updateMember)
					r.Delete("/{userId}", s.deleteMember)
				})
			})
		})
```

Create `backend/internal/api/members.go`:

```go
package api

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

func (s *Server) listMembers(w http.ResponseWriter, r *http.Request) {
	members, err := s.Store.ListMembers(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list members")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": members})
}

func (s *Server) createMember(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        string   `json:"name"`
		Email       string   `json:"email"`
		Password    string   `json:"password"`
		Permissions []string `json:"permissions"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}
	if req.Name == "" || req.Email == "" {
		httputil.Error(w, 400, "invalid_request", "name and email are required")
		return
	}
	if req.Permissions == nil {
		req.Permissions = auth.DefaultStaffPermissions
	}
	if err := auth.ValidatePermissions(req.Permissions); err != nil {
		httputil.Error(w, 400, "invalid_request", err.Error())
		return
	}
	garageID := auth.GarageID(r.Context())

	existing, err := s.Store.UserByEmail(r.Context(), req.Email)
	switch {
	case errors.Is(err, store.ErrNotFound):
		if len(req.Password) < 8 {
			httputil.Error(w, 400, "invalid_request", "password must be at least 8 characters")
			return
		}
		hash, err := auth.HashPassword(req.Password)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not hash password")
			return
		}
		member, err := s.Store.CreateUserWithMembership(r.Context(), garageID, req.Email, hash, req.Name, req.Permissions)
		if err != nil {
			s.writeMemberStoreError(w, err)
			return
		}
		httputil.JSON(w, 201, member)
	case err != nil:
		httputil.Error(w, 500, "internal", "could not look up user")
	default:
		if _, err := s.Store.MembershipFor(r.Context(), garageID, existing.ID); err == nil {
			httputil.Error(w, 409, "conflict", "user is already a member of this garage")
			return
		}
		member, err := s.Store.CreateMembership(r.Context(), garageID, existing.ID, "staff", req.Permissions)
		if err != nil {
			s.writeMemberStoreError(w, err)
			return
		}
		httputil.JSON(w, 201, member)
	}
}

func (s *Server) writeMemberStoreError(w http.ResponseWriter, err error) {
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "email or membership already exists")
		return
	}
	httputil.Error(w, 500, "internal", "could not save member")
}

func (s *Server) updateMember(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	garageID := auth.GarageID(r.Context())

	target, err := s.Store.Member(r.Context(), garageID, userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "member not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load member")
		return
	}
	if target.Role == "owner" {
		httputil.Error(w, 422, "unprocessable", "cannot modify the owner")
		return
	}

	var req struct {
		Permissions []string `json:"permissions"`
		Password    *string  `json:"password"`
		IsActive    *bool    `json:"is_active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}
	if req.Password != nil && auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "password reset is owner-only")
		return
	}
	if req.Permissions != nil {
		if err := auth.ValidatePermissions(req.Permissions); err != nil {
			httputil.Error(w, 400, "invalid_request", err.Error())
			return
		}
	}
	patch := store.MemberPatch{}
	if req.Permissions != nil {
		patch.Permissions = req.Permissions
	}
	if req.IsActive != nil {
		patch.IsActive = req.IsActive
	}
	if req.Password != nil {
		if len(*req.Password) < 8 {
			httputil.Error(w, 400, "invalid_request", "password must be at least 8 characters")
			return
		}
		hash, err := auth.HashPassword(*req.Password)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not hash password")
			return
		}
		patch.PasswordHash = &hash
	}
	member, err := s.Store.UpdateMember(r.Context(), garageID, userID, patch)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update member")
		return
	}
	httputil.JSON(w, 200, member)
}

func (s *Server) deleteMember(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	garageID := auth.GarageID(r.Context())

	if auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "only the owner can remove members")
		return
	}
	target, err := s.Store.Member(r.Context(), garageID, userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "member not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load member")
		return
	}
	if target.Role == "owner" {
		httputil.Error(w, 422, "unprocessable", "cannot remove the owner")
		return
	}
	if err := s.Store.DeleteMembership(r.Context(), garageID, userID); err != nil {
		httputil.Error(w, 500, "internal", "could not remove member")
		return
	}
	w.WriteHeader(204)
}
```

- [ ] **Step 3: Run tests + vet to see them pass**

Run: `go test ./internal/itest/ -v`
Expected: all tests PASS.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/api/router.go backend/internal/api/members.go backend/internal/itest/members_test.go
git commit -m "feat(backend): member management with granular permissions"
```

---

### Task 9: Settings endpoints

> Concurrency note (Task 6 quality review): PATCH settings is load → merge → full-row write
> with last-write-wins semantics — accepted deliberately. Settings are edited rarely, by the
> owner(s) of one garage, and garage_settings has no updated_at column; the handler must NOT
> add locking around this in Task 9.

**Files:**
- Create: `backend/internal/api/settings.go`
- Test: `backend/internal/itest/settings_test.go`

- [ ] **Step 1: Write the failing tests**

Create `backend/internal/itest/settings_test.go`:

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func settingsURL(garageID string) string { return "/api/garages/" + garageID + "/settings" }

func TestGetSettingsDefaults(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "set")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "GET", settingsURL(garageID), owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("get settings: status %d body %s", status, data)
	}
	var gs models.GarageSettings
	mustUnmarshal(t, data, &gs)
	if gs.GarageID != garageID {
		t.Fatalf("garage_id = %s", gs.GarageID)
	}
	if gs.DefaultTaxPercent != 18 || gs.InvoiceDueDays != 7 || gs.WorkingDaysPerMonth != 26 ||
		gs.PromisedDeliveryHours != 6 || gs.DefaultReceivedBy != "Cashier" {
		t.Fatalf("config defaults = %+v", gs)
	}
	if len(gs.TaxPercentOptions) != 4 || len(gs.QuotationValidityOptions) != 3 {
		t.Fatalf("option lists = %v / %v", gs.TaxPercentOptions, gs.QuotationValidityOptions)
	}
}

func TestPatchSettingsMerges(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "patch")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "PATCH", settingsURL(garageID), owner.AccessToken, garageID,
		map[string]any{"invoice_due_days": 14})
	if status != 200 {
		t.Fatalf("patch due days: status %d body %s", status, data)
	}
	var gs models.GarageSettings
	mustUnmarshal(t, data, &gs)
	if gs.InvoiceDueDays != 14 {
		t.Fatalf("due days = %v", gs.InvoiceDueDays)
	}
	if gs.DefaultTaxPercent != 18 || len(gs.TaxPercentOptions) != 4 {
		t.Fatalf("unpatched fields must be unchanged: %+v", gs)
	}

	status, data = doJSON(t, "PATCH", settingsURL(garageID), owner.AccessToken, garageID,
		map[string]any{"profile": map[string]any{
			"name": "Sharma Motors", "tagline": "Trusted since 1995",
			"address_line": "12 MG Road", "city": "Pune", "phone": "9876543210",
			"email": "sharma@motors.in", "gstin": "27ABCDE1234F1Z5", "upi_id": "sharma@upi",
		}})
	if status != 200 {
		t.Fatalf("patch profile: status %d body %s", status, data)
	}
	mustUnmarshal(t, data, &gs)
	if gs.Profile.Name != "Sharma Motors" || gs.Profile.City != "Pune" || gs.Profile.UPIID != "sharma@upi" {
		t.Fatalf("profile = %+v", gs.Profile)
	}
	if gs.InvoiceDueDays != 14 {
		t.Fatal("profile patch must not touch config fields")
	}

	status, data = doJSON(t, "PATCH", settingsURL(garageID), owner.AccessToken, garageID, map[string]any{})
	if status != 200 {
		t.Fatalf("empty patch: status %d body %s", status, data)
	}
	mustUnmarshal(t, data, &gs)
	if gs.InvoiceDueDays != 14 || gs.Profile.Name != "Sharma Motors" {
		t.Fatalf("empty patch must change nothing: %+v", gs)
	}
}

func TestSettingsPermissionGate(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "gate")
	garageID := owner.Memberships[0].GarageID
	_, _, staff := createMember(t, owner, garageID, map[string]any{
		"name": "Staff", "email": "staff-set@test.dev", "password": "password123",
	})

	status, data := doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-set@test.dev", "password": "password123",
	})
	var login authResponse
	mustUnmarshal(t, data, &login)

	status, data = doJSON(t, "GET", settingsURL(garageID), login.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff get settings: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); message != "missing permission: settings.manage" {
		t.Fatalf("message = %s", message)
	}
}

func TestSettingsPerGarage(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "sga")
	b := registerOwner(t, "sgb")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID

	status, _ := doJSON(t, "PATCH", settingsURL(aGarage), a.AccessToken, aGarage,
		map[string]any{"invoice_due_days": 14})
	if status != 200 {
		t.Fatalf("patch A settings: status %d", status)
	}

	status, data := doJSON(t, "GET", settingsURL(bGarage), b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("get B settings: status %d body %s", status, data)
	}
	var gs models.GarageSettings
	mustUnmarshal(t, data, &gs)
	if gs.InvoiceDueDays != 7 {
		t.Fatalf("B's settings must be independent, due days = %v", gs.InvoiceDueDays)
	}
}
```

Run: `go test ./internal/itest/ -run 'TestGetSettings|TestPatchSettings|TestSettings' -v`
Expected: FAIL — the settings routes are not registered yet, so every request 404s and the status assertions fail.

- [ ] **Step 2: Implement settings handlers**

Modify `backend/internal/api/router.go` — add the settings routes inside the `garages` subtree, directly after the closing `})` of the members `r.Route` block:

```go
				r.Route("/settings", func(r chi.Router) {
					r.Use(auth.RequirePermission("settings.manage"))
					r.Get("/", s.getSettings)
					r.Patch("/", s.patchSettings)
				})
```

Create `backend/internal/api/settings.go`:

```go
package api

import (
	"encoding/json"
	"errors"
	"net/http"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func (s *Server) getSettings(w http.ResponseWriter, r *http.Request) {
	gs, err := s.Store.GetOrCreateSettings(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load settings")
		return
	}
	httputil.JSON(w, 200, gs)
}

// patchSettings partial-merges: each provided top-level field replaces that
// field (a provided profile object replaces the whole profile); omitted
// fields keep their stored values.
func (s *Server) patchSettings(w http.ResponseWriter, r *http.Request) {
	current, err := s.Store.GetOrCreateSettings(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load settings")
		return
	}

	var patch struct {
		Profile                  *models.Profile `json:"profile"`
		DefaultTaxPercent        *float64        `json:"default_tax_percent"`
		TaxPercentOptions        []float64       `json:"tax_percent_options"`
		InvoiceDueDays           *int            `json:"invoice_due_days"`
		QuotationValidityOptions []int           `json:"quotation_validity_options"`
		WorkingDaysPerMonth      *int            `json:"working_days_per_month"`
		PromisedDeliveryHours    *int            `json:"promised_delivery_hours"`
		InvoiceNotes             *string         `json:"invoice_notes"`
		InvoiceTerms             *string         `json:"invoice_terms"`
		DefaultReceivedBy        *string         `json:"default_received_by"`
	}
	if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
		httputil.Error(w, 400, "invalid_request", "malformed JSON")
		return
	}

	if patch.Profile != nil {
		current.Profile = *patch.Profile
	}
	if patch.DefaultTaxPercent != nil {
		current.DefaultTaxPercent = *patch.DefaultTaxPercent
	}
	if patch.TaxPercentOptions != nil {
		current.TaxPercentOptions = patch.TaxPercentOptions
	}
	if patch.InvoiceDueDays != nil {
		current.InvoiceDueDays = *patch.InvoiceDueDays
	}
	if patch.QuotationValidityOptions != nil {
		current.QuotationValidityOptions = patch.QuotationValidityOptions
	}
	if patch.WorkingDaysPerMonth != nil {
		current.WorkingDaysPerMonth = *patch.WorkingDaysPerMonth
	}
	if patch.PromisedDeliveryHours != nil {
		current.PromisedDeliveryHours = *patch.PromisedDeliveryHours
	}
	if patch.InvoiceNotes != nil {
		current.InvoiceNotes = *patch.InvoiceNotes
	}
	if patch.InvoiceTerms != nil {
		current.InvoiceTerms = *patch.InvoiceTerms
	}
	if patch.DefaultReceivedBy != nil {
		current.DefaultReceivedBy = *patch.DefaultReceivedBy
	}

	if err := s.Store.UpdateSettings(r.Context(), current); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "garage not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not save settings")
		return
	}
	httputil.JSON(w, 200, current)
}
```

- [ ] **Step 3: Run the full suite + vet**

Run: `go test ./... -v`
Expected: every package `ok`, all tests PASS.

Run: `go vet ./...`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/api/router.go backend/internal/api/settings.go backend/internal/itest/settings_test.go
git commit -m "feat(backend): garage settings get/patch endpoints"
```

---

### Task 10: README + final gates

**Files:**
- Create: `backend/README.md`

- [ ] **Step 1: Write the README**

Create `backend/README.md`:

````markdown
# Garage Backend

Go backend for the Flutter garage app: multi-garage accounts, per-member
granular permissions, PostgreSQL storage. The Flutter app is its only client.

## Layout

- `cmd/server/` — binary entry point (config → pgxpool → goose migrate → router → graceful shutdown)
- `internal/config/` — env config
- `internal/auth/` — bcrypt, JWT issue/verify, refresh tokens, permission matrix, middleware
- `internal/api/` — chi handlers, one file per domain
- `internal/store/` — pgx queries, one file per domain
- `internal/models/` — structs shared by store and api
- `internal/itest/` — integration tests against embedded Postgres (no Docker needed)
- `migrations/` — goose SQL files, embedded into the binary and auto-run on boot

## Local setup (one-time)

1. Install PostgreSQL (EDB installer on Windows).
2. Create a database: `createdb garage`
3. Set environment variables:

   | Variable       | Meaning                              | Example                                         |
   |----------------|--------------------------------------|-------------------------------------------------|
   | `PORT`         | HTTP port (default 8080)             | `8080`                                          |
   | `DATABASE_URL` | Postgres connection string           | `postgres://postgres:pw@localhost:5432/garage?sslmode=disable` |
   | `JWT_SECRET`   | HS256 signing secret (required)      | any long random string                          |

## Run

```bash
go run ./cmd/server
```

Migrations run automatically on boot. Health check: `GET /api/health`.

## Test

```bash
go test ./...
```

Integration tests start their own throwaway Postgres (embedded binaries,
port 54329) — nothing external needed. First run downloads the binaries.

## Auth model

- `POST /api/auth/register` `{name, email, password, garageName}` → creator becomes that garage's owner
- `POST /api/auth/login` → `{access_token, refresh_token, user, memberships[]}`
- `POST /api/auth/refresh` → rotated token pair (old refresh revoked)
- `POST /api/auth/logout` → revokes the refresh token
- `GET /api/me` → current user + memberships

Access tokens live 15 minutes; refresh tokens 30 days, stored hashed, single-use.
Every garage-scoped route needs `Authorization: Bearer <access>` and
`X-Garage-Id: <garage uuid>` headers.

## Permissions

Fixed 11 keys: `customers.manage vehicles.manage jobcards.manage quotations.manage
invoices.manage payments.record expenses.manage staff.manage attendance.manage
advances.manage settings.manage`. Owners bypass checks. New staff members get
everything except `expenses.manage`, `staff.manage`, `advances.manage`,
`settings.manage` unless an explicit list is provided.
````

- [ ] **Step 2: Final gates (each its own command)**

Run: `go vet ./...`
Expected: no output, exit 0.

Run: `go test ./...`
Expected: `ok` for every package.

Run: `go build ./...`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add backend/README.md
git commit -m "docs(backend): setup and auth model notes"
```

---

## Self-review notes (written during planning, verified before commit)

- Spec coverage: §3 architecture (Tasks 1, 2, 7), §4 auth/tenancy/settings tables (Task 2), §5 auth + members + settings routes (Tasks 7–9; domain routes are Phase 2), §6 auth & permissions incl. default staff set and owner bypass (Tasks 3, 4), §8 error envelope + codes (httputil + handlers), §9 testing incl. embedded-postgres, rotation and revocation, tenancy isolation (Tasks 2, 6, 7), §10 security (bcrypt 12, hashed refresh, env-required JWT_SECRET, parameterized SQL throughout).
- Deliberate additions beyond the literal spec text: `memberships.is_active` (spec's member payload and PATCH reference it), `profile_name` column (disambiguates from `garages.name`), `GET /api/health`, password minimum length 8, mismatch between `X-Garage-Id` header and `{garageId}` URL segment returns 400.
- Members list uses the global `{"items": [...]}` convention (spec's global list rule normalizes the bare-array sketch in §5).
- Type consistency checked across tasks: `store.MemberPatch`, `models.User/Membership/Member/Profile/GarageSettings`, `auth.RequireAuth(issuer, users)` / `RequireGarage(memberships)` / `RequirePermission(key)`, `httputil.JSON/Error`, `store.ErrNotFound/ErrDuplicate` are used identically in every consumer.
