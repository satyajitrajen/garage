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

func boolPtr(b bool) *bool { return &b }
