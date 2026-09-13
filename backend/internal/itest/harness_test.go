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
