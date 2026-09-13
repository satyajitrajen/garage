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

func TestMigrationsCreateDomainTables(t *testing.T) {
	want := []string{
		"customers", "vehicles", "staff_members", "attendance_records", "salary_advances",
		"job_cards", "job_card_items", "quotations", "quotation_items",
		"invoices", "invoice_items", "payments", "expenses", "catalog_items",
	}
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
