# Go Backend Phase 2 — Domain CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the 12 domain tables (migration 0002), models, stores, handlers and integration tests for customers, vehicles, staff, attendance, salary advances, job cards, quotations, invoices, payments, expenses and catalog, per spec §4–§9 (`docs/superpowers/specs/2026-09-13-go-backend-design.md`).

**Architecture:** Modular monolith continues. One models file + one store file + one api file per domain; chi routes mount under the existing `/api/garages/{garageId}` group from Phase 1. Enum values stay TEXT in Postgres validated Go-side; money is numeric(12,2). Business rules mirror `lib/data/mock/mock_garage_repository.dart` and `lib/providers/garage_provider.dart` exactly where the spec pins them.

**Tech Stack:** Go 1.26, chi v5, pgx v5 (pgxpool), goose migrations, embedded-postgres itest harness (already running in `backend/internal/itest`).

---

## Conventions every implementer MUST follow (read first)

Phase 1 established these. Violating them is a spec-review finding.

1. **Working directories.** Run go commands from `backend/` (`cd D:/download/garrage/backend`). Run git from the repo root (`cd D:/download/garrage`) with explicit paths like `backend/internal/...`. Never `git add -A` / `git add .`.
2. **Gates are separate Bash calls** (no `&&` chains between them): `gofmt -l .` (expect no output), `go vet ./...`, `go build ./...`, `go test -count=1 ./...` (all from `backend/`). Full itest suite takes ~15–25 s.
3. **Error envelope** is `{"error":{"code","message"}}` via `httputil.Error(w, status, code, message)`. Codes: 400 `invalid_request`, 401 `unauthorized`, 403 `forbidden`, 404 `not_found`, 405, 409 `conflict`, 422 `unprocessable`, 500 `internal`. Lists are `{"items": [...]}`. Create → 201 with the persisted object; update → 200 with the persisted object; delete → 204 empty.
4. **Store conventions:** sentinels `store.ErrNotFound` / `store.ErrDuplicate` are bare-returned via `mapPGError(err)` (pg code 23505 → ErrDuplicate, pgx.ErrNoRows → ErrNotFound). `type scanner interface{ Scan(dest ...any) error }` already exists in `store/memberships.go`. Every query is parameterized and scoped by `garage_id` from `auth.GarageID(r.Context())` — never from request bodies. **Never write bare `tx.Rollback(ctx)`** — use `defer tx.Rollback(context.WithoutCancel(ctx))` (see `store/memberships.go:77`).
5. **Bodies** decode via `httputil.Decode(w, r, &dst)` (400 on malformed JSON). Command endpoints use local request structs; domain payloads decode straight into models structs.
6. **JSON shape:** camelCase tags matching the Dart models (e.g. `jobCardNumber`, `fuelType`). Nullable fields are pointers (`*string`, `*time.Time`, `*int`) and may arrive null or omitted. **Day-grained dates are plain `YYYY-MM-DD` strings** (joiningDate, lastServiceDate, expenseDate, advance date, attendance date) — validate with `time.Parse("2006-01-02", s)` where required. Instants are `time.Time` / `*time.Time`. Money is `float64` (numeric(12,2) in PG).
7. **Enums** live in `models/enums.go` (Task 2) as string slices; validate with `models.ValidValue(v, models.XEnums...)` → 400 `invalid_request` with the offending value in the message. TEXT values are the Dart enum **names** exactly.
8. **Tenancy on references:** any client-supplied reference id (customerId, vehicleId, staffId, jobCardId…) must (a) pass `uuid.Parse` → 400 `invalid_request` "invalid <field> id" when malformed, then (b) pass a store `XBelongs(garageID, id)` EXISTS check → 404 `not_found` "… not found" when it belongs to another garage. URL params addressing the resource itself (`{customerId}` etc.): malformed uuid → 404 (Phase 1 members pattern).
9. **Document numbers** (jobCardNumber, quotationNumber, invoiceNumber) are client-generated; the DB enforces `UNIQUE (garage_id, number)`; handlers map `store.ErrDuplicate` → 409 `conflict` "<resource> number already exists". Numbers are immutable on PUT (the UPDATE never sets them).
10. **IDs are server-generated** except item children, where the client may supply the id for upsert-by-id matching (spec §5 "upsert by item id"); empty item ids get `uuid.NewString()`.
11. **Slices/maps returned to the client must be non-nil** — initialize `items := []models.X{}` so JSON emits `[]` not `null`.
12. **Permission middleware** is already built and unit-tested (`auth.RequirePermission(key)` inside the `/api/garages/{garageId}` group after `RequireGarage`). Just wrap routes. No new middleware in Phase 2.
13. **No new Go dependencies.** google/uuid, pgx, chi are all in go.mod.
14. **Commit style:** conventional commits (`feat: add customers domain`), one commit per task, explicit paths, from repo root.

**Key out-of-scope reminders (do not build):** catalog CRUD (GET only), DELETE routes for job cards / quotations / invoices, payment edits (payments are append-only), receipt uploads.

**FK policy notes (deliberate, in migration 0002):** vehicles cascade when their customer is deleted (mirrors the mock deleting both); job cards / invoices keep NO ACTION on customer/vehicle so document history blocks customer deletion; deleting a staff member cascades attendance/advances and SET NULLs job/item assignments.

---

### Task 1: Migration 0002 — 12 domain tables

**Files:**
- Create: `backend/migrations/0002_domain.sql`
- Modify: `backend/internal/itest/harness_test.go` (truncate list)
- Test: `backend/internal/itest/migrations_test.go` (new test)

- [ ] **Step 1: Write the migration**

Create `backend/migrations/0002_domain.sql` with this exact content:

```sql
-- +goose Up

CREATE TABLE customers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    name text NOT NULL,
    phone text NOT NULL,
    whatsapp_number text,
    email text,
    address text,
    gstin text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_customers_garage ON customers(garage_id);

CREATE TABLE vehicles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    registration_number text NOT NULL,
    make text NOT NULL,
    model text NOT NULL,
    variant text,
    year int,
    fuel_type text NOT NULL,
    current_km int NOT NULL DEFAULT 0,
    color text,
    chassis_number text,
    engine_number text,
    last_service_date date,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_vehicles_garage ON vehicles(garage_id);

CREATE TABLE staff_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    name text NOT NULL,
    role text NOT NULL,
    phone text NOT NULL,
    email text,
    monthly_salary numeric(12,2) NOT NULL,
    joining_date date NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    address text,
    emergency_contact text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_staff_members_garage ON staff_members(garage_id);

CREATE TABLE attendance_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    staff_id uuid NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    date date NOT NULL,
    status text NOT NULL,
    notes text,
    UNIQUE (garage_id, staff_id, date)
);
CREATE INDEX idx_attendance_garage ON attendance_records(garage_id);

CREATE TABLE salary_advances (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    staff_id uuid NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    amount numeric(12,2) NOT NULL,
    date date NOT NULL,
    reason text,
    is_deducted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_salary_advances_garage ON salary_advances(garage_id);

CREATE TABLE job_cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    job_card_number text NOT NULL,
    customer_id uuid NOT NULL REFERENCES customers(id),
    vehicle_id uuid NOT NULL REFERENCES vehicles(id),
    customer_complaints text[] NOT NULL DEFAULT '{}',
    inspection_checklist jsonb NOT NULL DEFAULT '{}',
    fuel_level text NOT NULL DEFAULT '1/2',
    km_reading int NOT NULL DEFAULT 0,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    status text NOT NULL,
    promised_delivery_date timestamptz NOT NULL,
    completed_at timestamptz,
    estimated_cost_note text,
    supervisor_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (garage_id, job_card_number)
);
CREATE INDEX idx_job_cards_garage ON job_cards(garage_id);

CREATE TABLE job_card_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_card_id uuid NOT NULL REFERENCES job_cards(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    unit text NOT NULL DEFAULT 'Pcs',
    discount_percent numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 0,
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_job_card_items_parent ON job_card_items(job_card_id);

CREATE TABLE quotations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    quotation_number text NOT NULL,
    customer_id uuid NOT NULL REFERENCES customers(id),
    vehicle_id uuid NOT NULL REFERENCES vehicles(id),
    km_reading int NOT NULL DEFAULT 0,
    overall_discount numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 18,
    validity_days int NOT NULL DEFAULT 7,
    status text NOT NULL,
    notes text,
    valid_until timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (garage_id, quotation_number)
);
CREATE INDEX idx_quotations_garage ON quotations(garage_id);

CREATE TABLE quotation_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id uuid NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    unit text NOT NULL DEFAULT 'Pcs',
    discount_percent numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 0,
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_quotation_items_parent ON quotation_items(quotation_id);

CREATE TABLE invoices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    invoice_number text NOT NULL,
    job_card_id uuid REFERENCES job_cards(id),
    customer_id uuid NOT NULL REFERENCES customers(id),
    vehicle_id uuid NOT NULL REFERENCES vehicles(id),
    km_reading int NOT NULL DEFAULT 0,
    discount_amount numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 18,
    invoice_date timestamptz NOT NULL DEFAULT now(),
    due_date timestamptz,
    cancelled_at timestamptz,
    notes text,
    terms_and_conditions text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (garage_id, invoice_number)
);
CREATE INDEX idx_invoices_garage ON invoices(garage_id);

CREATE TABLE invoice_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    unit text NOT NULL DEFAULT 'Pcs',
    discount_percent numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 0,
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_invoice_items_parent ON invoice_items(invoice_id);

CREATE TABLE payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    customer_id uuid,
    amount numeric(12,2) NOT NULL,
    mode text NOT NULL,
    transaction_ref text,
    payment_date timestamptz NOT NULL DEFAULT now(),
    notes text,
    received_by text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);

CREATE TABLE expenses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    title text NOT NULL,
    category text NOT NULL,
    amount numeric(12,2) NOT NULL,
    expense_date date NOT NULL,
    payment_mode text NOT NULL DEFAULT 'cash',
    vendor_name text,
    notes text,
    receipt_path text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_expenses_garage ON expenses(garage_id);

CREATE TABLE catalog_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    unit text NOT NULL DEFAULT 'Pcs',
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_catalog_items_garage ON catalog_items(garage_id);

-- +goose Down
DROP TABLE IF EXISTS catalog_items;
DROP TABLE IF EXISTS expenses;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS invoice_items;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS quotation_items;
DROP TABLE IF EXISTS quotations;
DROP TABLE IF EXISTS job_card_items;
DROP TABLE IF EXISTS job_cards;
DROP TABLE IF EXISTS salary_advances;
DROP TABLE IF EXISTS attendance_records;
DROP TABLE IF EXISTS staff_members;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS customers;
```

- [ ] **Step 2: Update `truncate` in `backend/internal/itest/harness_test.go`**

Replace the existing `truncate` function with:

```go
func truncate(t *testing.T) {
	t.Helper()
	if _, err := pool.Exec(ctx,
		`TRUNCATE users, garages, memberships, refresh_tokens, garage_settings,
		customers, vehicles, staff_members, attendance_records, salary_advances,
		job_cards, job_card_items, quotations, quotation_items, invoices,
		invoice_items, payments, expenses, catalog_items CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
}
```

- [ ] **Step 3: Add the domain-tables migration test**

Append to `backend/internal/itest/migrations_test.go`:

```go
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
```

- [ ] **Step 4: Run gates**

From `backend/`, as separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestMigrations -v` (both migration tests PASS), `go test -count=1 ./...` (all PASS — goose runs 0002 on boot).

- [ ] **Step 5: Commit**

From repo root:
```bash
git add backend/migrations/0002_domain.sql backend/internal/itest/harness_test.go backend/internal/itest/migrations_test.go
git commit -m "feat: add migration 0002 with 12 domain tables"
```

---

### Task 2: Shared enum vocabulary + invoice money math

**Files:**
- Create: `backend/internal/models/enums.go`
- Create: `backend/internal/models/enums_test.go`
- Create: `backend/internal/models/money.go`
- Create: `backend/internal/models/money_test.go`

- [ ] **Step 1: Write `backend/internal/models/enums.go`**

```go
package models

// Enum TEXT values carry the Dart enum name exactly (lib/models/*.dart) so
// JSON maps onto Dart .name / $enumName without translation.

// ValidValue reports whether v is one of allowed.
func ValidValue(v string, allowed ...string) bool {
	for _, a := range allowed {
		if v == a {
			return true
		}
	}
	return false
}

var (
	// FuelTypes mirrors enum FuelType in lib/models/vehicle.dart.
	FuelTypes = []string{"petrol", "diesel", "cng", "electric", "hybrid"}
	// StaffRoles mirrors enum StaffRole in lib/models/staff.dart.
	StaffRoles = []string{"headMechanic", "seniorTechnician", "autoElectrician",
		"denterPainter", "helperTrainee", "serviceAdvisor", "manager"}
	// AttendanceStatuses mirrors enum AttendanceStatus in lib/models/staff.dart.
	AttendanceStatuses = []string{"present", "halfDay", "absent", "leave"}
	// JobStatuses mirrors enum JobStatus in lib/models/job_card.dart.
	JobStatuses = []string{"received", "inspection", "inProgress", "waitingParts",
		"readyForDelivery", "delivered", "cancelled"}
	// QuotationStatuses mirrors enum QuotationStatus in lib/models/quotation.dart.
	QuotationStatuses = []string{"draft", "sent", "approved", "converted", "rejected"}
	// PaymentModes mirrors enum PaymentMode in lib/models/payment.dart.
	PaymentModes = []string{"cash", "upi", "card", "bankTransfer", "cheque", "other"}
	// ExpenseCategories mirrors enum ExpenseCategory in lib/models/expense.dart.
	ExpenseCategories = []string{"rent", "electricityUtilities", "internetPhone",
		"toolsEquipment", "consumables", "partsStock", "staffFood", "fuelGenerator",
		"miscellaneous"}
	// ItemCategories mirrors enum ItemCategory in lib/models/maintenance_item.dart.
	ItemCategories = []string{"sparePart", "labour", "fluids", "tyresBattery",
		"transportMisc", "custom"}
)
```

- [ ] **Step 2: Write `backend/internal/models/enums_test.go`**

```go
package models

import "testing"

// Pins every enum set against the Dart enums (count and endpoints) so a
// rename on either side fails this test instead of silently corrupting
// stored rows.
func TestEnumSetsMatchDart(t *testing.T) {
	cases := []struct {
		name  string
		got   []string
		count int
		first string
		last  string
	}{
		{"FuelTypes", FuelTypes, 5, "petrol", "hybrid"},
		{"StaffRoles", StaffRoles, 7, "headMechanic", "manager"},
		{"AttendanceStatuses", AttendanceStatuses, 4, "present", "leave"},
		{"JobStatuses", JobStatuses, 7, "received", "cancelled"},
		{"QuotationStatuses", QuotationStatuses, 5, "draft", "rejected"},
		{"PaymentModes", PaymentModes, 6, "cash", "other"},
		{"ExpenseCategories", ExpenseCategories, 9, "rent", "miscellaneous"},
		{"ItemCategories", ItemCategories, 6, "sparePart", "custom"},
	}
	for _, tc := range cases {
		if len(tc.got) != tc.count {
			t.Errorf("%s: got %d values, want %d (%v)", tc.name, len(tc.got), tc.count, tc.got)
		}
		if tc.got[0] != tc.first || tc.got[len(tc.got)-1] != tc.last {
			t.Errorf("%s: order drifted: first=%q last=%q", tc.name, tc.got[0], tc.got[len(tc.got)-1])
		}
		for _, v := range tc.got {
			if !ValidValue(v, tc.got...) {
				t.Errorf("%s: %q not accepted by ValidValue", tc.name, v)
			}
		}
	}
	if ValidValue("nope", JobStatuses...) {
		t.Error("ValidValue accepted unknown value")
	}
}
```

- [ ] **Step 3: Write `backend/internal/models/money.go`**

```go
package models

import "time"

// InvoiceMoney holds the raw money components of an invoice so handlers can
// reproduce the Dart-side math in lib/models/invoice.dart without loading
// full item and payment rows.
type InvoiceMoney struct {
	CancelledAt *time.Time
	Gross       float64 // sum of item taxable amounts (unit*qty net of item discount)
	Discount    float64 // document-level discount_amount
	TaxPercent  float64
	Paid        float64 // sum of payments
}

// Due mirrors Invoice._rawBalanceDue: taxable = max(gross - discount, 0);
// grand = taxable * (1 + taxPercent/100); due = max(grand - paid, 0).
// Cancelled invoices keep their raw due here — callers decide whether the
// cancelled flag zeroes the balance (the Dart balanceDue getter does).
func (m InvoiceMoney) Due() float64 {
	taxable := m.Gross - m.Discount
	if taxable < 0 {
		taxable = 0
	}
	due := taxable*(1+m.TaxPercent/100) - m.Paid
	if due < 0 {
		due = 0
	}
	return due
}
```

- [ ] **Step 4: Write `backend/internal/models/money_test.go`**

```go
package models

import "testing"

func TestInvoiceMoneyDue(t *testing.T) {
	cases := []struct {
		name                       string
		gross, discount, tax, paid float64
		want                       float64
	}{
		{"plain 18% GST", 1000, 0, 18, 0, 1180},
		{"discount then tax", 1000, 100, 18, 0, 1062},
		{"partial payment", 1000, 100, 18, 500, 562},
		{"overpaid clamps to zero", 100, 0, 0, 150, 0},
		{"discount exceeds gross clamps", 100, 500, 18, 0, 0},
		{"zero tax", 250.50, 0.50, 0, 0, 250},
	}
	for _, tc := range cases {
		m := InvoiceMoney{Gross: tc.gross, Discount: tc.discount, TaxPercent: tc.tax, Paid: tc.paid}
		if got := m.Due(); got < tc.want-1e-9 || got > tc.want+1e-9 {
			t.Errorf("%s: Due() = %v, want %v", tc.name, got, tc.want)
		}
	}
}
```

- [ ] **Step 5: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/models/ -v` (all PASS).

- [ ] **Step 6: Commit**

```bash
git add backend/internal/models/enums.go backend/internal/models/enums_test.go backend/internal/models/money.go backend/internal/models/money_test.go
git commit -m "feat: add shared enum sets and invoice money math"
```

---

### Task 3: Customers domain (incl. dues-gated delete)

**Files:**
- Create: `backend/internal/models/customer.go`
- Create: `backend/internal/store/customers.go`
- Create: `backend/internal/api/customers.go`
- Create: `backend/internal/api/helpers.go`
- Modify: `backend/internal/api/router.go` (customers route group)
- Modify: `backend/internal/itest/harness_test.go` (createStaffSession helper)
- Test: `backend/internal/itest/customers_test.go`

- [ ] **Step 1: Write `backend/internal/models/customer.go`**

```go
package models

import "time"

type Customer struct {
	ID             string    `json:"id"`
	Name           string    `json:"name"`
	Phone          string    `json:"phone"`
	WhatsAppNumber *string   `json:"whatsappNumber"`
	Email          *string   `json:"email"`
	Address        *string   `json:"address"`
	GSTIN          *string   `json:"gstin"`
	Notes          *string   `json:"notes"`
	CreatedAt      time.Time `json:"createdAt"`
}
```

- [ ] **Step 2: Write `backend/internal/store/customers.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const customerColumns = `id, name, phone, whatsapp_number, email, address, gstin, notes, created_at`

func scanCustomer(row scanner) (models.Customer, error) {
	var c models.Customer
	err := row.Scan(&c.ID, &c.Name, &c.Phone, &c.WhatsAppNumber, &c.Email,
		&c.Address, &c.GSTIN, &c.Notes, &c.CreatedAt)
	return c, mapPGError(err)
}

func (s *Store) ListCustomers(ctx context.Context, garageID string) ([]models.Customer, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+customerColumns+` FROM customers WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Customer{}
	for rows.Next() {
		c, err := scanCustomer(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, c)
	}
	return items, rows.Err()
}

func (s *Store) CustomerByID(ctx context.Context, garageID, customerID string) (models.Customer, error) {
	return scanCustomer(s.Pool.QueryRow(ctx,
		`SELECT `+customerColumns+` FROM customers WHERE garage_id = $1 AND id = $2`,
		garageID, customerID))
}

func (s *Store) CreateCustomer(ctx context.Context, garageID string, c models.Customer) (models.Customer, error) {
	return scanCustomer(s.Pool.QueryRow(ctx,
		`INSERT INTO customers (garage_id, name, phone, whatsapp_number, email, address, gstin, notes)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING `+customerColumns,
		garageID, c.Name, c.Phone, c.WhatsAppNumber, c.Email, c.Address, c.GSTIN, c.Notes))
}

func (s *Store) UpdateCustomer(ctx context.Context, garageID string, c models.Customer) (models.Customer, error) {
	return scanCustomer(s.Pool.QueryRow(ctx,
		`UPDATE customers SET name=$3, phone=$4, whatsapp_number=$5, email=$6, address=$7, gstin=$8, notes=$9
		 WHERE garage_id = $1 AND id = $2 RETURNING `+customerColumns,
		garageID, c.ID, c.Name, c.Phone, c.WhatsAppNumber, c.Email, c.Address, c.GSTIN, c.Notes))
}

func (s *Store) DeleteCustomer(ctx context.Context, garageID, customerID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM customers WHERE garage_id = $1 AND id = $2`, garageID, customerID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CustomerBelongs reports whether the customer exists in the garage. Handlers
// use it to reject references to other garages' rows with 404.
func (s *Store) CustomerBelongs(ctx context.Context, garageID, customerID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM customers WHERE garage_id = $1 AND id = $2)`,
		garageID, customerID).Scan(&ok)
	return ok, err
}

// CustomerHasOutstandingDues mirrors MockGarageRepository.deleteCustomer:
// any non-cancelled invoice of the customer with balanceDue > 0.01 blocks
// deletion. Money math comes from models.InvoiceMoney so this query and the
// payments handler can never drift apart.
func (s *Store) CustomerHasOutstandingDues(ctx context.Context, garageID, customerID string) (bool, error) {
	rows, err := s.Pool.Query(ctx, `SELECT i.cancelled_at,
			COALESCE(item_sums.gross, 0), i.discount_amount, i.tax_percent,
			COALESCE(paid_sums.paid, 0)
		FROM invoices i
		LEFT JOIN (SELECT invoice_id, SUM(unit_price * quantity * (1 - discount_percent / 100.0)) AS gross
		           FROM invoice_items GROUP BY invoice_id) item_sums ON item_sums.invoice_id = i.id
		LEFT JOIN (SELECT invoice_id, SUM(amount) AS paid
		           FROM payments GROUP BY invoice_id) paid_sums ON paid_sums.invoice_id = i.id
		WHERE i.garage_id = $1 AND i.customer_id = $2`, garageID, customerID)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	for rows.Next() {
		var m models.InvoiceMoney
		if err := rows.Scan(&m.CancelledAt, &m.Gross, &m.Discount, &m.TaxPercent, &m.Paid); err != nil {
			return false, err
		}
		if m.CancelledAt == nil && m.Due() > 0.01 {
			return true, nil
		}
	}
	return false, rows.Err()
}

// CustomerHasDocuments reports whether the customer has any invoices or job
// cards. Invoice/job-card history also blocks deletion so surviving
// documents always keep a resolvable customer (the mock's dangling
// references are an in-memory artifact the server must not reproduce).
func (s *Store) CustomerHasDocuments(ctx context.Context, garageID, customerID string) (invoices, jobCards bool, err error) {
	err = s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM invoices WHERE garage_id = $1 AND customer_id = $2),
		        EXISTS (SELECT 1 FROM job_cards WHERE garage_id = $1 AND customer_id = $2)`,
		garageID, customerID).Scan(&invoices, &jobCards)
	return invoices, jobCards, err
}
```

- [ ] **Step 3: Write `backend/internal/api/helpers.go`**

```go
package api

import (
	"github.com/google/uuid"
)

// parseID parses a client-supplied resource id from a URL parameter.
func parseID(raw string) (uuid.UUID, error) {
	return uuid.Parse(raw)
}
```

- [ ] **Step 4: Write `backend/internal/api/customers.go`**

```go
package api

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func (s *Server) listCustomers(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListCustomers(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list customers")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createCustomer(w http.ResponseWriter, r *http.Request) {
	var c models.Customer
	if !httputil.Decode(w, r, &c) {
		return
	}
	if c.Name == "" || c.Phone == "" {
		httputil.Error(w, 400, "invalid_request", "name and phone are required")
		return
	}
	created, err := s.Store.CreateCustomer(r.Context(), auth.GarageID(r.Context()), c)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create customer")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateCustomer(w http.ResponseWriter, r *http.Request) {
	var c models.Customer
	if !httputil.Decode(w, r, &c) {
		return
	}
	c.ID = chi.URLParam(r, "customerId")
	if _, err := parseID(c.ID); err != nil {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	if c.Name == "" || c.Phone == "" {
		httputil.Error(w, 400, "invalid_request", "name and phone are required")
		return
	}
	updated, err := s.Store.UpdateCustomer(r.Context(), auth.GarageID(r.Context()), c)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update customer")
		return
	}
	httputil.JSON(w, 200, updated)
}

// deleteCustomer mirrors MockGarageRepository.deleteCustomer: 409 while the
// customer has outstanding dues. Invoice/job-card history also blocks the
// delete so surviving documents keep a resolvable customer.
func (s *Server) deleteCustomer(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	customerID := chi.URLParam(r, "customerId")
	if _, err := parseID(customerID); err != nil {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}

	dues, err := s.Store.CustomerHasOutstandingDues(r.Context(), garageID, customerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer dues")
		return
	}
	if dues {
		httputil.Error(w, 409, "conflict", "customer has outstanding dues")
		return
	}
	hasInvoices, hasJobCards, err := s.Store.CustomerHasDocuments(r.Context(), garageID, customerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer history")
		return
	}
	if hasInvoices || hasJobCards {
		httputil.Error(w, 409, "conflict", "customer has invoice or job card history")
		return
	}
	if err := s.Store.DeleteCustomer(r.Context(), garageID, customerID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "customer not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not delete customer")
		return
	}
	w.WriteHeader(204)
}
```

- [ ] **Step 5: Wire routes in `backend/internal/api/router.go`**

Inside the `r.Route("/garages/{garageId}", ...)` block, after the settings group, add:

```go
			r.Route("/customers", func(r chi.Router) {
				r.Use(auth.RequirePermission("customers.manage"))
				r.Get("/", s.listCustomers)
				r.Post("/", s.createCustomer)
				r.Put("/{customerId}", s.updateCustomer)
				r.Delete("/{customerId}", s.deleteCustomer)
			})
```

- [ ] **Step 6: Add `createStaffSession` to `backend/internal/itest/harness_test.go`**

Append (uses `membersURL` from members_test.go, same package):

```go
// createStaffSession creates a staff member with the given permission keys
// and logs them in, returning their auth response.
func createStaffSession(t *testing.T, owner authResponse, garageID, suffix string, perms []string) authResponse {
	t.Helper()
	status, data := doJSON(t, "POST", membersURL(garageID), owner.AccessToken, garageID, map[string]any{
		"name": "Staff " + suffix, "email": "staff-" + suffix + "@test.dev",
		"password": "password123", "permissions": perms,
	})
	if status != 201 {
		t.Fatalf("create staff: status %d body %s", status, data)
	}
	status, data = doJSON(t, "POST", "/api/auth/login", "", "", map[string]string{
		"email": "staff-" + suffix + "@test.dev", "password": "password123",
	})
	if status != 200 {
		t.Fatalf("staff login: status %d body %s", status, data)
	}
	var login authResponse
	mustUnmarshal(t, data, &login)
	return login
}
```

- [ ] **Step 7: Write `backend/internal/itest/customers_test.go`**

```go
package itest

import (
	"testing"
	"time"

	"garage-backend/internal/models"
)

func createCustomer(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Customer) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/customers", token, garageID, body)
	var c models.Customer
	if status == 201 {
		mustUnmarshal(t, data, &c)
	}
	return status, data, c
}

func customerBody(name string) map[string]any {
	return map[string]any{
		"name": name, "phone": "9876543210",
		"email": name + "@example.com", "address": "12 MG Road",
	}
}

// seedInvoice inserts an invoice + one item (+ optional payment) directly so
// dues-gated delete can be tested without the invoice endpoints. gross is
// the item taxable amount (quantity 1, no item discount/tax).
func seedInvoice(t *testing.T, garageID, customerID, number string, gross, discount, taxPercent, paid float64, cancelled bool) {
	t.Helper()
	var vehicleID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO vehicles (garage_id, customer_id, registration_number, make, model, fuel_type)
		 VALUES ($1,$2,'SEED-00','Seed','Seed','petrol') RETURNING id`,
		garageID, customerID).Scan(&vehicleID); err != nil {
		t.Fatalf("seed vehicle: %v", err)
	}
	var cancelledArg any
	if cancelled {
		cancelledArg = time.Now().UTC()
	}
	var invoiceID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO invoices (garage_id, invoice_number, customer_id, vehicle_id, km_reading,
		                       discount_amount, tax_percent, invoice_date, cancelled_at)
		 VALUES ($1,$2,$3,$4,0,$5,$6,now(),$7) RETURNING id`,
		garageID, number, customerID, vehicleID, discount, taxPercent, cancelledArg).Scan(&invoiceID); err != nil {
		t.Fatalf("seed invoice: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO invoice_items (invoice_id, name, category, unit_price, quantity, unit)
		 VALUES ($1,'Seed item','sparePart',$2,1,'Pcs')`, invoiceID, gross); err != nil {
		t.Fatalf("seed invoice item: %v", err)
	}
	if paid > 0 {
		if _, err := pool.Exec(ctx,
			`INSERT INTO payments (invoice_id, amount, mode, payment_date)
			 VALUES ($1,$2,'cash',now())`, invoiceID, paid); err != nil {
			t.Fatalf("seed payment: %v", err)
		}
	}
}

func TestCustomerCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "c1")
	garageID := owner.Memberships[0].GarageID

	status, data, first := createCustomer(t, owner.AccessToken, garageID, customerBody("Ashok"))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if first.ID == "" || first.Name != "Ashok" || first.CreatedAt.IsZero() {
		t.Fatalf("customer = %+v", first)
	}
	_, _, second := createCustomer(t, owner.AccessToken, garageID, customerBody("Bhavna"))

	status, data = doJSON(t, "GET", "/api/customers", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Customer `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].Name != "Bhavna" {
		t.Fatalf("list must be newest first: %+v", list.Items)
	}

	first.Phone = "9000000001"
	status, data = doJSON(t, "PUT", "/api/customers/"+first.ID, owner.AccessToken, garageID, first)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Customer
	mustUnmarshal(t, data, &updated)
	if updated.Phone != "9000000001" {
		t.Fatalf("update lost phone: %+v", updated)
	}

	status, _ = doJSON(t, "PUT", "/api/customers/"+first.ID, owner.AccessToken, garageID,
		map[string]any{"name": "X"})
	if status != 400 {
		t.Fatalf("update without phone: status %d", status)
	}
}

func TestCustomerDeleteSemantics(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "c2")
	garageID := owner.Memberships[0].GarageID

	// No history: delete succeeds.
	_, _, plain := createCustomer(t, owner.AccessToken, garageID, customerBody("Plain"))
	status, data := doJSON(t, "DELETE", "/api/customers/"+plain.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("plain delete: status %d body %s", status, data)
	}

	// Outstanding dues block (mirrors the mock returning false).
	_, _, debtor := createCustomer(t, owner.AccessToken, garageID, customerBody("Debtor"))
	seedInvoice(t, garageID, debtor.ID, "INV-D-1", 1000, 0, 18, 0, false)
	status, data = doJSON(t, "DELETE", "/api/customers/"+debtor.ID, owner.AccessToken, garageID, nil)
	if status != 409 {
		t.Fatalf("dues delete: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "conflict" || message != "customer has outstanding dues" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Fully paid invoice still blocks (history must stay resolvable).
	_, _, paidUp := createCustomer(t, owner.AccessToken, garageID, customerBody("PaidUp"))
	seedInvoice(t, garageID, paidUp.ID, "INV-P-1", 1000, 0, 0, 1000, false)
	status, data = doJSON(t, "DELETE", "/api/customers/"+paidUp.ID, owner.AccessToken, garageID, nil)
	if status != 409 {
		t.Fatalf("paid-invoice delete: status %d body %s", status, data)
	}
	if code, _ := decodeError(t, data); code != "conflict" {
		t.Fatalf("code = %s", code)
	}

	// Cancelled invoice is not dues but is still history.
	_, _, cancelled := createCustomer(t, owner.AccessToken, garageID, customerBody("Cancelled"))
	seedInvoice(t, garageID, cancelled.ID, "INV-C-1", 1000, 0, 18, 0, true)
	status, data = doJSON(t, "DELETE", "/api/customers/"+cancelled.ID, owner.AccessToken, garageID, nil)
	if status != 409 {
		t.Fatalf("cancelled-invoice delete: status %d body %s", status, data)
	}

	// Unknown id is 404.
	status, _ = doJSON(t, "DELETE", "/api/customers/11111111-1111-1111-1111-111111111111",
		owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("unknown delete: status %d", status)
	}
}

func TestCustomerTenancyIsolation(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "c3a")
	b := registerOwner(t, "c3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID

	_, _, mine := createCustomer(t, a.AccessToken, aGarage, customerBody("Mine"))

	status, data := doJSON(t, "GET", "/api/customers", b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("list B: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Customer `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("B must not see A's customers: %+v", list.Items)
	}

	mine.Name = "Hacked"
	status, _ = doJSON(t, "PUT", "/api/customers/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's customer: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/customers/"+mine.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's customer: status %d", status)
	}
}

func TestCustomerPermissionGate(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "c4")
	garageID := owner.Memberships[0].GarageID
	staff := createStaffSession(t, owner, garageID, "cperm", []string{"vehicles.manage"})

	status, data := doJSON(t, "GET", "/api/customers", staff.AccessToken, garageID, nil)
	if status != 403 {
		t.Fatalf("staff without customers.manage: status %d body %s", status, data)
	}
	if _, message := decodeError(t, data); message != "missing permission: customers.manage" {
		t.Fatalf("message = %s", message)
	}
}
```

- [ ] **Step 8: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestCustomer -v` (4 tests PASS), `go test -count=1 ./...` (all PASS).

- [ ] **Step 9: Commit**

```bash
git add backend/internal/models/customer.go backend/internal/store/customers.go backend/internal/api/customers.go backend/internal/api/helpers.go backend/internal/api/router.go backend/internal/itest/harness_test.go backend/internal/itest/customers_test.go
git commit -m "feat: add customers domain with dues-gated delete"
```

---

### Task 4: Vehicles domain

**Files:**
- Create: `backend/internal/models/vehicle.go`
- Create: `backend/internal/store/vehicles.go`
- Create: `backend/internal/api/vehicles.go`
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/vehicles_test.go`

- [ ] **Step 1: Write `backend/internal/models/vehicle.go`**

```go
package models

import "time"

type Vehicle struct {
	ID                 string    `json:"id"`
	CustomerID         string    `json:"customerId"`
	RegistrationNumber string    `json:"registrationNumber"`
	Make               string    `json:"make"`
	Model              string    `json:"model"`
	Variant            *string   `json:"variant"`
	Year               *int      `json:"year"`
	FuelType           string    `json:"fuelType"`
	CurrentKm          int       `json:"currentKm"`
	Color              *string   `json:"color"`
	ChassisNumber      *string   `json:"chassisNumber"`
	EngineNumber       *string   `json:"engineNumber"`
	CreatedAt          time.Time `json:"createdAt"`
	LastServiceDate    *string   `json:"lastServiceDate"`
}
```

- [ ] **Step 2: Write `backend/internal/store/vehicles.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const vehicleColumns = `id, customer_id, registration_number, make, model, variant, year,
	fuel_type, current_km, color, chassis_number, engine_number, created_at, last_service_date`

func scanVehicle(row scanner) (models.Vehicle, error) {
	var v models.Vehicle
	err := row.Scan(&v.ID, &v.CustomerID, &v.RegistrationNumber, &v.Make, &v.Model,
		&v.Variant, &v.Year, &v.FuelType, &v.CurrentKm, &v.Color, &v.ChassisNumber,
		&v.EngineNumber, &v.CreatedAt, &v.LastServiceDate)
	return v, mapPGError(err)
}

func (s *Store) ListVehicles(ctx context.Context, garageID string) ([]models.Vehicle, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+vehicleColumns+` FROM vehicles WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Vehicle{}
	for rows.Next() {
		v, err := scanVehicle(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, v)
	}
	return items, rows.Err()
}

func (s *Store) VehicleByID(ctx context.Context, garageID, vehicleID string) (models.Vehicle, error) {
	return scanVehicle(s.Pool.QueryRow(ctx,
		`SELECT `+vehicleColumns+` FROM vehicles WHERE garage_id = $1 AND id = $2`,
		garageID, vehicleID))
}

func (s *Store) CreateVehicle(ctx context.Context, garageID string, v models.Vehicle) (models.Vehicle, error) {
	return scanVehicle(s.Pool.QueryRow(ctx,
		`INSERT INTO vehicles (garage_id, customer_id, registration_number, make, model, variant,
		                       year, fuel_type, current_km, color, chassis_number, engine_number, last_service_date)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING `+vehicleColumns,
		garageID, v.CustomerID, v.RegistrationNumber, v.Make, v.Model, v.Variant,
		v.Year, v.FuelType, v.CurrentKm, v.Color, v.ChassisNumber, v.EngineNumber, v.LastServiceDate))
}

func (s *Store) UpdateVehicle(ctx context.Context, garageID string, v models.Vehicle) (models.Vehicle, error) {
	return scanVehicle(s.Pool.QueryRow(ctx,
		`UPDATE vehicles SET customer_id=$3, registration_number=$4, make=$5, model=$6, variant=$7,
		                        year=$8, fuel_type=$9, current_km=$10, color=$11, chassis_number=$12,
		                        engine_number=$13, last_service_date=$14
		 WHERE garage_id = $1 AND id = $2 RETURNING `+vehicleColumns,
		garageID, v.ID, v.CustomerID, v.RegistrationNumber, v.Make, v.Model, v.Variant,
		v.Year, v.FuelType, v.CurrentKm, v.Color, v.ChassisNumber, v.EngineNumber, v.LastServiceDate))
}

func (s *Store) DeleteVehicle(ctx context.Context, garageID, vehicleID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM vehicles WHERE garage_id = $1 AND id = $2`, garageID, vehicleID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// VehicleHasDocuments reports whether the vehicle has any job cards or
// invoices. Deletion is blocked so surviving documents keep a resolvable
// vehicle (mirrors the customer-delete history guard).
func (s *Store) VehicleHasDocuments(ctx context.Context, garageID, vehicleID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM job_cards WHERE garage_id = $1 AND vehicle_id = $2)
		      OR EXISTS (SELECT 1 FROM invoices WHERE garage_id = $1 AND vehicle_id = $2)`,
		garageID, vehicleID).Scan(&ok)
	return ok, err
}

// VehicleBelongs reports whether the vehicle exists in the garage.
func (s *Store) VehicleBelongs(ctx context.Context, garageID, vehicleID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM vehicles WHERE garage_id = $1 AND id = $2)`,
		garageID, vehicleID).Scan(&ok)
	return ok, err
}
```

- [ ] **Step 3: Write `backend/internal/api/vehicles.go`**

Validation: customerId parses (400) and belongs (404 "customer not found"); registrationNumber, make, model required; fuelType valid enum; lastServiceDate when non-empty parses `2006-01-02`; currentKm ≥ 0. Delete is blocked with 409 when the vehicle has documents (same integrity guard as customers).

```go
package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateVehicle(v models.Vehicle) (string, int) {
	if v.RegistrationNumber == "" || v.Make == "" || v.Model == "" {
		return "registration_number, make and model are required", 400
	}
	if _, err := uuid.Parse(v.CustomerID); err != nil {
		return "invalid customer id", 400
	}
	if !models.ValidValue(v.FuelType, models.FuelTypes...) {
		return "invalid fuelType \"" + v.FuelType + "\"", 400
	}
	if v.CurrentKm < 0 {
		return "current_km must not be negative", 400
	}
	if v.LastServiceDate != nil && *v.LastServiceDate != "" {
		if _, err := time.Parse("2006-01-02", *v.LastServiceDate); err != nil {
			return "last_service_date must be YYYY-MM-DD", 400
		}
	}
	return "", 0
}

func (s *Server) listVehicles(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListVehicles(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list vehicles")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createVehicle(w http.ResponseWriter, r *http.Request) {
	var v models.Vehicle
	if !httputil.Decode(w, r, &v) {
		return
	}
	if msg, code := validateVehicle(v); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.CustomerBelongs(r.Context(), garageID, v.CustomerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	created, err := s.Store.CreateVehicle(r.Context(), garageID, v)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create vehicle")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateVehicle(w http.ResponseWriter, r *http.Request) {
	var v models.Vehicle
	if !httputil.Decode(w, r, &v) {
		return
	}
	v.ID = chi.URLParam(r, "vehicleId")
	if _, err := parseID(v.ID); err != nil {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	if msg, code := validateVehicle(v); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.CustomerBelongs(r.Context(), garageID, v.CustomerID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check customer")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "customer not found")
		return
	}
	updated, err := s.Store.UpdateVehicle(r.Context(), garageID, v)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update vehicle")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteVehicle(w http.ResponseWriter, r *http.Request) {
	garageID := auth.GarageID(r.Context())
	vehicleID := chi.URLParam(r, "vehicleId")
	if _, err := parseID(vehicleID); err != nil {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	hasDocs, err := s.Store.VehicleHasDocuments(r.Context(), garageID, vehicleID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check vehicle history")
		return
	}
	if hasDocs {
		httputil.Error(w, 409, "conflict", "vehicle has job cards or invoices")
		return
	}
	err = s.Store.DeleteVehicle(r.Context(), garageID, vehicleID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "vehicle not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete vehicle")
		return
	}
	w.WriteHeader(204)
}
```

- [ ] **Step 4: Wire routes in `backend/internal/api/router.go`** (after customers group)

```go
			r.Route("/vehicles", func(r chi.Router) {
				r.Use(auth.RequirePermission("vehicles.manage"))
				r.Get("/", s.listVehicles)
				r.Post("/", s.createVehicle)
				r.Put("/{vehicleId}", s.updateVehicle)
				r.Delete("/{vehicleId}", s.deleteVehicle)
			})
```

- [ ] **Step 5: Write `backend/internal/itest/vehicles_test.go`**

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func createVehicleFor(t *testing.T, token, garageID, customerID string) models.Vehicle {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/vehicles", token, garageID, map[string]any{
		"customerId": customerID, "registrationNumber": "MH 12 AB 1234",
		"make": "Maruti Suzuki", "model": "Swift Dzire", "variant": "VXI",
		"year": 2021, "fuelType": "petrol", "currentKm": 45200,
		"lastServiceDate": "2026-08-01",
	})
	if status != 201 {
		t.Fatalf("create vehicle: status %d body %s", status, data)
	}
	var v models.Vehicle
	mustUnmarshal(t, data, &v)
	return v
}

func TestVehicleCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "v1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("vown"))

	v := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	if v.ID == "" || v.FuelType != "petrol" || v.LastServiceDate != "2026-08-01" {
		t.Fatalf("vehicle = %+v", v)
	}

	status, data := doJSON(t, "GET", "/api/vehicles", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Vehicle `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 || list.Items[0].ID != v.ID {
		t.Fatalf("items = %+v", list.Items)
	}

	v.CurrentKm = 46000
	status, data = doJSON(t, "PUT", "/api/vehicles/"+v.ID, owner.AccessToken, garageID, v)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Vehicle
	mustUnmarshal(t, data, &updated)
	if updated.CurrentKm != 46000 {
		t.Fatalf("update lost km: %+v", updated)
	}

	status, _ = doJSON(t, "DELETE", "/api/vehicles/"+v.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete: status %d", status)
	}
}

func TestVehicleValidation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "v2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("vval"))

	base := map[string]any{
		"customerId": customer.ID, "registrationNumber": "MH 01 XY 0001",
		"make": "Hyundai", "model": "Creta", "fuelType": "diesel",
	}
	bad := []map[string]any{
		{"registrationNumber": ""},
		{"customerId": "not-a-uuid"},
		{"fuelType": "kerosene"},
		{"lastServiceDate": "01-08-2026"},
		{"currentKm": -5},
	}
	for i, patch := range bad {
		body := map[string]any{}
		for k, val := range base {
			body[k] = val
		}
		for k, val := range patch {
			body[k] = val
		}
		status, _ := doJSON(t, "POST", "/api/vehicles", owner.AccessToken, garageID, body)
		if status != 400 {
			t.Fatalf("bad body %d: status %d, want 400", i, status)
		}
	}

	// Unknown customer (well-formed uuid) → 404.
	status, _ := doJSON(t, "POST", "/api/vehicles", owner.AccessToken, garageID, map[string]any{
		"customerId":         "22222222-2222-2222-2222-222222222222",
		"registrationNumber": "MH 01 XY 0005", "make": "M", "model": "C", "fuelType": "petrol",
	})
	if status != 404 {
		t.Fatalf("unknown customer: status %d", status)
	}
}

func TestVehicleDeleteGuardAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "v3a")
	b := registerOwner(t, "v3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("Avown"))
	v := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)

	// Seeded invoice history blocks vehicle deletion.
	seedInvoice(t, aGarage, aCustomer.ID, "INV-V-1", 500, 0, 0, 0, false)
	status, data := doJSON(t, "DELETE", "/api/vehicles/"+v.ID, a.AccessToken, aGarage, nil)
	if status != 409 {
		t.Fatalf("delete with history: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "conflict" || message != "vehicle has job cards or invoices" {
		t.Fatalf("error = %s / %s", code, message)
	}

	status, _ = doJSON(t, "PUT", "/api/vehicles/"+v.ID, b.AccessToken, bGarage, v)
	if status != 404 {
		t.Fatalf("B update A's vehicle: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/vehicles/"+v.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's vehicle: status %d", status)
	}
}
```

- [ ] **Step 6: Run gates, then commit**

From `backend/`, separate calls: `gofmt -l .`, `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestVehicle -v`, `go test -count=1 ./...` — all green.

```bash
git add backend/internal/models/vehicle.go backend/internal/store/vehicles.go backend/internal/api/vehicles.go backend/internal/api/router.go backend/internal/itest/vehicles_test.go
git commit -m "feat: add vehicles domain with history-guarded delete"
```

---

### Task 5: Staff domain (workshop roster — distinct from members)

**Files:**
- Create: `backend/internal/models/staff.go`
- Create: `backend/internal/store/staff.go`
- Create: `backend/internal/api/staff.go`
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/staff_test.go`

Note: `staff` (workshop employees: mechanics etc.) is a DIFFERENT entity from `members` (app logins). Route is `/api/staff` per spec §5, permission `staff.manage`.

- [ ] **Step 1: Write `backend/internal/models/staff.go`**

```go
package models

import "time"

type Staff struct {
	ID               string    `json:"id"`
	Name             string    `json:"name"`
	Role             string    `json:"role"`
	Phone            string    `json:"phone"`
	Email            *string   `json:"email"`
	MonthlySalary    float64   `json:"monthlySalary"`
	JoiningDate      string    `json:"joiningDate"`
	IsActive         bool      `json:"isActive"`
	Address          *string   `json:"address"`
	EmergencyContact *string   `json:"emergencyContact"`
	CreatedAt        time.Time `json:"createdAt"`
}
```

- [ ] **Step 2: Write `backend/internal/store/staff.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const staffColumns = `id, name, role, phone, email, monthly_salary, joining_date,
	is_active, address, emergency_contact, created_at`

func scanStaff(row scanner) (models.Staff, error) {
	var st models.Staff
	err := row.Scan(&st.ID, &st.Name, &st.Role, &st.Phone, &st.Email, &st.MonthlySalary,
		&st.JoiningDate, &st.IsActive, &st.Address, &st.EmergencyContact, &st.CreatedAt)
	return st, mapPGError(err)
}

func (s *Store) ListStaff(ctx context.Context, garageID string) ([]models.Staff, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+staffColumns+` FROM staff_members WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Staff{}
	for rows.Next() {
		st, err := scanStaff(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, st)
	}
	return items, rows.Err()
}

func (s *Store) StaffByID(ctx context.Context, garageID, staffID string) (models.Staff, error) {
	return scanStaff(s.Pool.QueryRow(ctx,
		`SELECT `+staffColumns+` FROM staff_members WHERE garage_id = $1 AND id = $2`,
		garageID, staffID))
}

func (s *Store) CreateStaff(ctx context.Context, garageID string, st models.Staff) (models.Staff, error) {
	return scanStaff(s.Pool.QueryRow(ctx,
		`INSERT INTO staff_members (garage_id, name, role, phone, email, monthly_salary,
		                            joining_date, is_active, address, emergency_contact)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING `+staffColumns,
		garageID, st.Name, st.Role, st.Phone, st.Email, st.MonthlySalary,
		st.JoiningDate, st.IsActive, st.Address, st.EmergencyContact))
}

func (s *Store) UpdateStaff(ctx context.Context, garageID string, st models.Staff) (models.Staff, error) {
	return scanStaff(s.Pool.QueryRow(ctx,
		`UPDATE staff_members SET name=$3, role=$4, phone=$5, email=$6, monthly_salary=$7,
		                        joining_date=$8, is_active=$9, address=$10, emergency_contact=$11
		 WHERE garage_id = $1 AND id = $2 RETURNING `+staffColumns,
		garageID, st.ID, st.Name, st.Role, st.Phone, st.Email, st.MonthlySalary,
		st.JoiningDate, st.IsActive, st.Address, st.EmergencyContact))
}

func (s *Store) DeleteStaff(ctx context.Context, garageID, staffID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM staff_members WHERE garage_id = $1 AND id = $2`, garageID, staffID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// StaffBelongs reports whether the staff member exists in the garage.
func (s *Store) StaffBelongs(ctx context.Context, garageID, staffID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM staff_members WHERE garage_id = $1 AND id = $2)`,
		garageID, staffID).Scan(&ok)
	return ok, err
}
```

- [ ] **Step 3: Write `backend/internal/api/staff.go`**

Validation: name, phone required; role valid enum; joiningDate required and parses `2006-01-02`.

```go
package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateStaff(st models.Staff) (string, int) {
	if st.Name == "" || st.Phone == "" {
		return "name and phone are required", 400
	}
	if !models.ValidValue(st.Role, models.StaffRoles...) {
		return "invalid role \"" + st.Role + "\"", 400
	}
	if _, err := time.Parse("2006-01-02", st.JoiningDate); err != nil {
		return "joining_date must be YYYY-MM-DD", 400
	}
	return "", 0
}

func (s *Server) listStaff(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListStaff(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list staff")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createStaff(w http.ResponseWriter, r *http.Request) {
	var st models.Staff
	if !httputil.Decode(w, r, &st) {
		return
	}
	if msg, code := validateStaff(st); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	created, err := s.Store.CreateStaff(r.Context(), auth.GarageID(r.Context()), st)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create staff")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateStaff(w http.ResponseWriter, r *http.Request) {
	var st models.Staff
	if !httputil.Decode(w, r, &st) {
		return
	}
	st.ID = chi.URLParam(r, "staffId")
	if _, err := parseID(st.ID); err != nil {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	if msg, code := validateStaff(st); msg != "" {
		httputil.Error(w, code, "invalid_request", msg)
		return
	}
	updated, err := s.Store.UpdateStaff(r.Context(), auth.GarageID(r.Context()), st)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update staff")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteStaff(w http.ResponseWriter, r *http.Request) {
	staffID := chi.URLParam(r, "staffId")
	if _, err := parseID(staffID); err != nil {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	err := s.Store.DeleteStaff(r.Context(), auth.GarageID(r.Context()), staffID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete staff")
		return
	}
	w.WriteHeader(204)
}
```

- [ ] **Step 4: Wire routes in `backend/internal/api/router.go`**

```go
			r.Route("/staff", func(r chi.Router) {
				r.Use(auth.RequirePermission("staff.manage"))
				r.Get("/", s.listStaff)
				r.Post("/", s.createStaff)
				r.Put("/{staffId}", s.updateStaff)
				r.Delete("/{staffId}", s.deleteStaff)
			})
```

- [ ] **Step 5: Write `backend/internal/itest/staff_test.go`**

(Task 6 appends the tenancy-cascade test to this file along with its seed helpers.)

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func staffBody(name string) map[string]any {
	return map[string]any{
		"name": name, "role": "headMechanic", "phone": "9800000001",
		"monthlySalary": 22000.0, "joiningDate": "2024-03-15", "isActive": true,
	}
}

func createStaffMember(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Staff) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/staff", token, garageID, body)
	var st models.Staff
	if status == 201 {
		mustUnmarshal(t, data, &st)
	}
	return status, data, st
}

func TestStaffCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "s1")
	garageID := owner.Memberships[0].GarageID

	status, data, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Ramesh"))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if st.ID == "" || st.JoiningDate != "2024-03-15" || !st.IsActive {
		t.Fatalf("staff = %+v", st)
	}

	st.MonthlySalary = 25000
	status, data = doJSON(t, "PUT", "/api/staff/"+st.ID, owner.AccessToken, garageID, st)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Staff
	mustUnmarshal(t, data, &updated)
	if updated.MonthlySalary != 25000 {
		t.Fatalf("update lost salary: %+v", updated)
	}

	status, _ = doJSON(t, "DELETE", "/api/staff/"+st.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete: status %d", status)
	}
	status, data = doJSON(t, "GET", "/api/staff", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d", status)
	}
	var list struct {
		Items []models.Staff `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("staff not deleted: %+v", list.Items)
	}
}

func TestStaffValidation(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "s2")
	garageID := owner.Memberships[0].GarageID

	bad := []map[string]any{
		{"name": "", "role": "headMechanic", "phone": "1", "monthlySalary": 1, "joiningDate": "2024-03-15"},
		{"name": "X", "role": "boss", "phone": "1", "monthlySalary": 1, "joiningDate": "2024-03-15"},
		{"name": "X", "role": "manager", "phone": "1", "monthlySalary": 1, "joiningDate": "15-03-2024"},
	}
	for i, body := range bad {
		status, _ := doJSON(t, "POST", "/api/staff", owner.AccessToken, garageID, body)
		if status != 400 {
			t.Fatalf("bad body %d: status %d, want 400", i, status)
		}
	}
}
```

- [ ] **Step 6: Run gates, then commit**

From `backend/`, separate calls: `gofmt -l .`, `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestStaff -v`, `go test -count=1 ./...` — all green.

```bash
git add backend/internal/models/staff.go backend/internal/store/staff.go backend/internal/api/staff.go backend/internal/api/router.go backend/internal/itest/staff_test.go
git commit -m "feat: add workshop staff domain"
```

---

### Task 6: Attendance + salary advances + settle

**Files:**
- Create: `backend/internal/models/attendance.go`
- Create: `backend/internal/store/attendance.go`
- Create: `backend/internal/store/advances.go`
- Create: `backend/internal/api/attendance.go`
- Create: `backend/internal/api/advances.go`
- Modify: `backend/internal/api/router.go`
- Modify: `backend/internal/itest/staff_test.go` (append tenancy-cascade test + seed helpers)
- Test: `backend/internal/itest/attendance_test.go`

- [ ] **Step 1: Write `backend/internal/models/attendance.go`**

```go
package models

type AttendanceRecord struct {
	ID      string  `json:"id"`
	StaffID string  `json:"staffId"`
	Date    string  `json:"date"`
	Status  string  `json:"status"`
	Notes   *string `json:"notes"`
}

type SalaryAdvance struct {
	ID         string  `json:"id"`
	StaffID    string  `json:"staffId"`
	Amount     float64 `json:"amount"`
	Date       string  `json:"date"`
	Reason     *string `json:"reason"`
	IsDeducted bool    `json:"isDeducted"`
}
```

- [ ] **Step 2: Write `backend/internal/store/attendance.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const attendanceColumns = `id, staff_id, date, status, notes`

func scanAttendance(row scanner) (models.AttendanceRecord, error) {
	var rec models.AttendanceRecord
	err := row.Scan(&rec.ID, &rec.StaffID, &rec.Date, &rec.Status, &rec.Notes)
	return rec, mapPGError(err)
}

func (s *Store) ListAttendance(ctx context.Context, garageID string) ([]models.AttendanceRecord, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+attendanceColumns+` FROM attendance_records
		 WHERE garage_id = $1 ORDER BY date DESC, staff_id, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.AttendanceRecord{}
	for rows.Next() {
		rec, err := scanAttendance(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, rec)
	}
	return items, rows.Err()
}

// UpsertAttendance inserts or updates by (garage, staff, day) — idempotent
// per spec §8. Returns the stored row including its id either way.
func (s *Store) UpsertAttendance(ctx context.Context, garageID string, rec models.AttendanceRecord) (models.AttendanceRecord, error) {
	return scanAttendance(s.Pool.QueryRow(ctx,
		`INSERT INTO attendance_records (garage_id, staff_id, date, status, notes)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (garage_id, staff_id, date)
		 DO UPDATE SET status = EXCLUDED.status, notes = EXCLUDED.notes
		 RETURNING `+attendanceColumns,
		garageID, rec.StaffID, rec.Date, rec.Status, rec.Notes))
}
```

- [ ] **Step 3: Write `backend/internal/store/advances.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const advanceColumns = `id, staff_id, amount, date, reason, is_deducted`

func scanAdvance(row scanner) (models.SalaryAdvance, error) {
	var adv models.SalaryAdvance
	err := row.Scan(&adv.ID, &adv.StaffID, &adv.Amount, &adv.Date, &adv.Reason, &adv.IsDeducted)
	return adv, mapPGError(err)
}

func (s *Store) ListSalaryAdvances(ctx context.Context, garageID string) ([]models.SalaryAdvance, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+advanceColumns+` FROM salary_advances WHERE garage_id = $1 ORDER BY date DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.SalaryAdvance{}
	for rows.Next() {
		adv, err := scanAdvance(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, adv)
	}
	return items, rows.Err()
}

func (s *Store) CreateSalaryAdvance(ctx context.Context, garageID string, adv models.SalaryAdvance) (models.SalaryAdvance, error) {
	return scanAdvance(s.Pool.QueryRow(ctx,
		`INSERT INTO salary_advances (garage_id, staff_id, amount, date, reason, is_deducted)
		 VALUES ($1,$2,$3,$4,$5,$6) RETURNING `+advanceColumns,
		garageID, adv.StaffID, adv.Amount, adv.Date, adv.Reason, adv.IsDeducted))
}

// SettleSalaryAdvances marks every unsettled advance of the staff member in
// the given month/year as deducted, then returns the garage's full advance
// list (mirrors MockGarageRepository.settleSalaryAdvances returning
// List.of(_salaryAdvances)).
func (s *Store) SettleSalaryAdvances(ctx context.Context, garageID, staffID string, month, year int) ([]models.SalaryAdvance, error) {
	if _, err := s.Pool.Exec(ctx,
		`UPDATE salary_advances SET is_deducted = true
		 WHERE garage_id = $1 AND staff_id = $2 AND is_deducted = false
		   AND EXTRACT(MONTH FROM date) = $3 AND EXTRACT(YEAR FROM date) = $4`,
		garageID, staffID, month, year); err != nil {
		return nil, mapPGError(err)
	}
	return s.ListSalaryAdvances(ctx, garageID)
}
```

- [ ] **Step 4: Write `backend/internal/api/attendance.go`**

Validation: staffId parses (400) and belongs (404 "staff not found"); status valid enum; date parses `2006-01-02`. The POST is a save, not a create — returns 200 with the stored row (matching `saveAttendance` returning the record).

```go
package api

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

func (s *Server) listAttendance(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListAttendance(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list attendance")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) upsertAttendance(w http.ResponseWriter, r *http.Request) {
	var rec models.AttendanceRecord
	if !httputil.Decode(w, r, &rec) {
		return
	}
	if _, err := uuid.Parse(rec.StaffID); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid staff id")
		return
	}
	if !models.ValidValue(rec.Status, models.AttendanceStatuses...) {
		httputil.Error(w, 400, "invalid_request", "invalid status \""+rec.Status+"\"")
		return
	}
	if _, err := time.Parse("2006-01-02", rec.Date); err != nil {
		httputil.Error(w, 400, "invalid_request", "date must be YYYY-MM-DD")
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.StaffBelongs(r.Context(), garageID, rec.StaffID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check staff")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	saved, err := s.Store.UpsertAttendance(r.Context(), garageID, rec)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not save attendance")
		return
	}
	httputil.JSON(w, 200, saved)
}
```

- [ ] **Step 5: Write `backend/internal/api/advances.go`**

```go
package api

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

func (s *Server) listSalaryAdvances(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListSalaryAdvances(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list salary advances")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createSalaryAdvance(w http.ResponseWriter, r *http.Request) {
	var adv models.SalaryAdvance
	if !httputil.Decode(w, r, &adv) {
		return
	}
	if _, err := uuid.Parse(adv.StaffID); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid staff id")
		return
	}
	if _, err := time.Parse("2006-01-02", adv.Date); err != nil {
		httputil.Error(w, 400, "invalid_request", "date must be YYYY-MM-DD")
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.StaffBelongs(r.Context(), garageID, adv.StaffID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check staff")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	created, err := s.Store.CreateSalaryAdvance(r.Context(), garageID, adv)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create salary advance")
		return
	}
	httputil.JSON(w, 201, created)
}

type settleRequest struct {
	StaffID string `json:"staff_id"`
	Month   int    `json:"month"`
	Year    int    `json:"year"`
}

func (s *Server) settleSalaryAdvances(w http.ResponseWriter, r *http.Request) {
	var req settleRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if _, err := uuid.Parse(req.StaffID); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid staff id")
		return
	}
	if req.Month < 1 || req.Month > 12 || req.Year < 1970 || req.Year > 2100 {
		httputil.Error(w, 400, "invalid_request", "month must be 1-12 and year 1970-2100")
		return
	}
	garageID := auth.GarageID(r.Context())
	ok, err := s.Store.StaffBelongs(r.Context(), garageID, req.StaffID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not check staff")
		return
	}
	if !ok {
		httputil.Error(w, 404, "not_found", "staff not found")
		return
	}
	items, err := s.Store.SettleSalaryAdvances(r.Context(), garageID, req.StaffID, req.Month, req.Year)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not settle salary advances")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}
```

- [ ] **Step 6: Wire routes in `backend/internal/api/router.go`**

```go
			r.Route("/attendance", func(r chi.Router) {
				r.Use(auth.RequirePermission("attendance.manage"))
				r.Get("/", s.listAttendance)
				r.Post("/", s.upsertAttendance)
			})
			r.Route("/salary-advances", func(r chi.Router) {
				r.Use(auth.RequirePermission("advances.manage"))
				r.Get("/", s.listSalaryAdvances)
				r.Post("/", s.createSalaryAdvance)
				r.Post("/settle", s.settleSalaryAdvances)
			})
```

- [ ] **Step 7: Append to `backend/internal/itest/staff_test.go`** (seed helpers + tenancy-cascade test)

```go
func seedAttendance(t *testing.T, garageID, staffID, date, status string) {
	t.Helper()
	if _, err := pool.Exec(ctx,
		`INSERT INTO attendance_records (garage_id, staff_id, date, status)
		 VALUES ($1,$2,$3,$4)`, garageID, staffID, date, status); err != nil {
		t.Fatalf("seed attendance: %v", err)
	}
}

func seedAdvance(t *testing.T, garageID, staffID string, amount float64, date string, deducted bool) {
	t.Helper()
	if _, err := pool.Exec(ctx,
		`INSERT INTO salary_advances (garage_id, staff_id, amount, date, is_deducted)
		 VALUES ($1,$2,$3,$4,$5)`, garageID, staffID, amount, date, deducted); err != nil {
		t.Fatalf("seed advance: %v", err)
	}
}

func TestStaffTenancyIsolation(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "s3a")
	b := registerOwner(t, "s3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, st := createStaffMember(t, a.AccessToken, aGarage, staffBody("Suresh"))

	status, _ := doJSON(t, "PUT", "/api/staff/"+st.ID, b.AccessToken, bGarage, st)
	if status != 404 {
		t.Fatalf("B update A's staff: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/staff/"+st.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's staff: status %d", status)
	}

	// Deleting A's staff cascades attendance and advances (FK policy).
	seedAttendance(t, aGarage, st.ID, "2026-09-01", "present")
	seedAdvance(t, aGarage, st.ID, 2000, "2026-09-02", false)
	status, _ = doJSON(t, "DELETE", "/api/staff/"+st.ID, a.AccessToken, aGarage, nil)
	if status != 204 {
		t.Fatalf("delete staff with history: status %d", status)
	}
	var n int
	if err := pool.QueryRow(ctx,
		`SELECT count(*) FROM attendance_records WHERE garage_id = $1`, aGarage).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatalf("attendance rows survived staff delete: %d", n)
	}
}
```

- [ ] **Step 8: Write `backend/internal/itest/attendance_test.go`**

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestAttendanceUpsertIdempotent(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "a1")
	garageID := owner.Memberships[0].GarageID
	_, _, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Atten"))

	body := func(status string) map[string]any {
		return map[string]any{"staffId": st.ID, "date": "2026-09-10", "status": status}
	}

	status, data := doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, body("present"))
	if status != 200 {
		t.Fatalf("upsert: status %d body %s", status, data)
	}
	var first models.AttendanceRecord
	mustUnmarshal(t, data, &first)
	if first.ID == "" || first.Status != "present" {
		t.Fatalf("record = %+v", first)
	}

	// Same (staff, day) again: same row id, new status — idempotent upsert.
	status, data = doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, body("halfDay"))
	if status != 200 {
		t.Fatalf("second upsert: status %d body %s", status, data)
	}
	var second models.AttendanceRecord
	mustUnmarshal(t, data, &second)
	if second.ID != first.ID || second.Status != "halfDay" {
		t.Fatalf("upsert not idempotent: %+v vs %+v", second, first)
	}

	status, data = doJSON(t, "GET", "/api/attendance", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.AttendanceRecord `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 {
		t.Fatalf("want exactly 1 row, got %d", len(list.Items))
	}
}

func TestAttendanceValidationAndTenancy(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "a2")
	garageID := owner.Memberships[0].GarageID
	_, _, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Atten2"))

	bad := []map[string]any{
		{"staffId": st.ID, "date": "2026-09-10", "status": "sick"},
		{"staffId": st.ID, "date": "10-09-2026", "status": "present"},
		{"staffId": "nope", "date": "2026-09-10", "status": "present"},
	}
	for i, body := range bad {
		status, _ := doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, body)
		if status != 400 {
			t.Fatalf("bad body %d: status %d, want 400", i, status)
		}
	}

	status, _ := doJSON(t, "POST", "/api/attendance", owner.AccessToken, garageID, map[string]any{
		"staffId": "33333333-3333-3333-3333-333333333333", "date": "2026-09-10", "status": "present",
	})
	if status != 404 {
		t.Fatalf("unknown staff: status %d", status)
	}
}

func TestSalaryAdvanceCreateAndSettle(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "a3")
	garageID := owner.Memberships[0].GarageID
	_, _, st := createStaffMember(t, owner.AccessToken, garageID, staffBody("Adv"))

	status, data := doJSON(t, "POST", "/api/salary-advances", owner.AccessToken, garageID, map[string]any{
		"staffId": st.ID, "amount": 3000.0, "date": "2026-09-05", "reason": "Festival",
	})
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	var adv models.SalaryAdvance
	mustUnmarshal(t, data, &adv)
	if adv.ID == "" || adv.IsDeducted {
		t.Fatalf("advance = %+v", adv)
	}
	// Second advance in the same month.
	_, _ = doJSON(t, "POST", "/api/salary-advances", owner.AccessToken, garageID, map[string]any{
		"staffId": st.ID, "amount": 1000.0, "date": "2026-09-20",
	})

	status, data = doJSON(t, "POST", "/api/salary-advances/settle", owner.AccessToken, garageID, map[string]any{
		"staff_id": st.ID, "month": 9, "year": 2026,
	})
	if status != 200 {
		t.Fatalf("settle: status %d body %s", status, data)
	}
	var list struct {
		Items []models.SalaryAdvance `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 {
		t.Fatalf("settle must return the full garage list, got %d", len(list.Items))
	}
	for _, a := range list.Items {
		if !a.IsDeducted {
			t.Fatalf("all rows must be deducted after settle: %+v", list.Items)
		}
	}

	// An advance from another month is untouched by the settle above.
	status, data = doJSON(t, "POST", "/api/salary-advances", owner.AccessToken, garageID, map[string]any{
		"staffId": st.ID, "amount": 500.0, "date": "2026-08-15",
	})
	if status != 201 {
		t.Fatalf("create aug: status %d body %s", status, data)
	}
	var aug models.SalaryAdvance
	mustUnmarshal(t, data, &aug)
	if aug.IsDeducted {
		t.Fatalf("august advance must be untouched: %+v", aug)
	}

	// Invalid month.
	status, _ = doJSON(t, "POST", "/api/salary-advances/settle", owner.AccessToken, garageID, map[string]any{
		"staff_id": st.ID, "month": 13, "year": 2026,
	})
	if status != 400 {
		t.Fatalf("bad month: status %d", status)
	}
}
```

- [ ] **Step 9: Run gates, then commit**

From `backend/`, separate calls: `gofmt -l .`, `go vet ./...`, `go test -count=1 ./internal/itest/ -run 'TestStaff|TestAttendance|TestSalaryAdvance' -v`, `go test -count=1 ./...` — all green.

```bash
git add backend/internal/models/attendance.go backend/internal/store/attendance.go backend/internal/store/advances.go backend/internal/api/attendance.go backend/internal/api/advances.go backend/internal/api/router.go backend/internal/itest/staff_test.go backend/internal/itest/attendance_test.go
git commit -m "feat: add attendance and salary-advance domains with settle"
```

---

### Task 7: Maintenance items plumbing + Job cards + Catalog

**Files:**
- Create: `backend/internal/models/maintenance_item.go`
- Create: `backend/internal/models/catalog.go`
- Create: `backend/internal/models/jobcard.go`
- Create: `backend/internal/store/items.go`
- Create: `backend/internal/store/jobcards.go`
- Create: `backend/internal/store/catalog.go`
- Create: `backend/internal/api/jobcards.go`
- Create: `backend/internal/api/catalog.go`
- Modify: `backend/internal/api/helpers.go` (append `refCheck` + `checkRefs` + `checkItemStaffRef`)
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/jobcards_test.go`
- Test: `backend/internal/itest/catalog_test.go`

Design note: all three item child tables (`job_card_items`, `quotation_items`, `invoice_items`) share one MaintenanceItem shape, so their store plumbing is table-driven from a compile-time map (Task 8 and Task 9 reuse it — this is the one deliberate abstraction). Table names never come from request input; they come from the `itemParents` map.

- [ ] **Step 1: Write `backend/internal/models/maintenance_item.go`**

```go
package models

// MaintenanceItem mirrors lib/models/maintenance_item.dart and is shared by
// job cards, quotations and invoices.
type MaintenanceItem struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Category        string  `json:"category"`
	UnitPrice       float64 `json:"unitPrice"`
	Quantity        float64 `json:"quantity"`
	Unit            string  `json:"unit"`
	DiscountPercent float64 `json:"discountPercent"`
	TaxPercent      float64 `json:"taxPercent"`
	IsLabour        bool    `json:"isLabour"`
	PartNumber      *string `json:"partNumber"`
	Notes           *string `json:"notes"`
	AssignedStaffID *string `json:"assignedStaffId"`
}
```

- [ ] **Step 2: Write `backend/internal/models/catalog.go`**

```go
package models

import "time"

type CatalogItem struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	Category   string    `json:"category"`
	UnitPrice  float64   `json:"unitPrice"`
	Unit       string    `json:"unit"`
	IsLabour   bool      `json:"isLabour"`
	PartNumber *string   `json:"partNumber"`
	Notes      *string   `json:"notes"`
	CreatedAt  time.Time `json:"createdAt"`
}
```

- [ ] **Step 3: Write `backend/internal/models/jobcard.go`**

```go
package models

import "time"

type JobCard struct {
	ID                   string            `json:"id"`
	JobCardNumber        string            `json:"jobCardNumber"`
	CustomerID           string            `json:"customerId"`
	VehicleID            string            `json:"vehicleId"`
	CustomerComplaints   []string          `json:"customerComplaints"`
	InspectionChecklist  map[string]bool   `json:"inspectionChecklist"`
	FuelLevel            string            `json:"fuelLevel"`
	KmReading            int               `json:"kmReading"`
	AssignedStaffID      *string           `json:"assignedStaffId"`
	Status               string            `json:"status"`
	PromisedDeliveryDate time.Time         `json:"promisedDeliveryDate"`
	CompletedAt          *time.Time        `json:"completedAt"`
	CreatedAt            time.Time         `json:"createdAt"`
	EstimatedCostNote    *string           `json:"estimatedCostNote"`
	SupervisorNotes      *string           `json:"supervisorNotes"`
	Items                []MaintenanceItem `json:"items"`
}

// DefaultChecklist mirrors JobCard.defaultChecklist in lib/models/job_card.dart.
var DefaultChecklist = map[string]bool{
	"Engine Oil Level":       true,
	"Brake System":           true,
	"Coolant & Fluids":       true,
	"Battery & Terminals":    true,
	"Tyres & Pressure":       true,
	"AC & Heating":           true,
	"Lights & Horn":          true,
	"Body Scratches Checked": true,
}

// DefaultFuelLevel mirrors the JobCard constructor default.
const DefaultFuelLevel = "1/2"
```

- [ ] **Step 4: Write `backend/internal/store/items.go`**

```go
package store

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"garage-backend/internal/models"
)

const itemColumns = `id, name, category, unit_price, quantity, unit, discount_percent,
	tax_percent, is_labour, part_number, notes, assigned_staff_id`

// itemParent locates the document table an items table hangs off.
type itemParent struct {
	parentTable string
	fkColumn    string
}

var itemParents = map[string]itemParent{
	"job_card_items":  {parentTable: "job_cards", fkColumn: "job_card_id"},
	"quotation_items": {parentTable: "quotations", fkColumn: "quotation_id"},
	"invoice_items":   {parentTable: "invoices", fkColumn: "invoice_id"},
}

// execer is satisfied by both *pgxpool.Pool and pgx.Tx.
type execer interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

func itemParentOf(itemsTable string) (itemParent, error) {
	p, ok := itemParents[itemsTable]
	if !ok {
		return itemParent{}, fmt.Errorf("unknown items table %q", itemsTable)
	}
	return p, nil
}

func scanItem(row scanner) (models.MaintenanceItem, error) {
	var it models.MaintenanceItem
	err := row.Scan(&it.ID, &it.Name, &it.Category, &it.UnitPrice, &it.Quantity, &it.Unit,
		&it.DiscountPercent, &it.TaxPercent, &it.IsLabour, &it.PartNumber, &it.Notes,
		&it.AssignedStaffID)
	return it, mapPGError(err)
}

// ItemsOfParent returns one document's items ordered by creation.
func (s *Store) ItemsOfParent(ctx context.Context, itemsTable, parentID string) ([]models.MaintenanceItem, error) {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return nil, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT `+itemColumns+` FROM `+itemsTable+` WHERE `+p.fkColumn+` = $1 ORDER BY created_at, id`,
		parentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.MaintenanceItem{}
	for rows.Next() {
		it, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// ItemsByGarage returns every item of the given items table for documents in
// the garage, keyed by parent document id (list endpoints attach them).
func (s *Store) ItemsByGarage(ctx context.Context, itemsTable, garageID string) (map[string][]models.MaintenanceItem, error) {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return nil, err
	}
	rows, err := s.Pool.Query(ctx,
		`SELECT it.id, it.name, it.category, it.unit_price, it.quantity, it.unit,
		        it.discount_percent, it.tax_percent, it.is_labour, it.part_number,
		        it.notes, it.assigned_staff_id, it.`+p.fkColumn+`
		 FROM `+itemsTable+` it
		 JOIN `+p.parentTable+` d ON d.id = it.`+p.fkColumn+`
		 WHERE d.garage_id = $1 ORDER BY it.created_at, it.id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := map[string][]models.MaintenanceItem{}
	for rows.Next() {
		var parentID string
		var it models.MaintenanceItem
		if err := rows.Scan(&it.ID, &it.Name, &it.Category, &it.UnitPrice, &it.Quantity,
			&it.Unit, &it.DiscountPercent, &it.TaxPercent, &it.IsLabour, &it.PartNumber,
			&it.Notes, &it.AssignedStaffID, &parentID); err != nil {
			return nil, err
		}
		items[parentID] = append(items[parentID], it)
	}
	return items, rows.Err()
}

// replaceItemsOn deletes the document's item rows and inserts the supplied
// ones inside the caller's transaction (PUT replaces the items array
// wholesale, mirroring the mock's update setters). Empty item ids get server
// uuids; supplied ids are preserved so the client's upsert-by-id contract
// keeps working. Table names come from the compile-time itemParents map,
// never from request input.
func replaceItemsOn(ctx context.Context, x execer, itemsTable, parentID string, items []models.MaintenanceItem) error {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return err
	}
	if _, err := x.Exec(ctx, `DELETE FROM `+itemsTable+` WHERE `+p.fkColumn+` = $1`, parentID); err != nil {
		return mapPGError(err)
	}
	for i := range items {
		it := &items[i]
		if it.ID == "" {
			it.ID = uuid.NewString()
		}
		if _, err := x.Exec(ctx,
			`INSERT INTO `+itemsTable+` (id, `+p.fkColumn+`, name, category, unit_price, quantity,
			                            unit, discount_percent, tax_percent, is_labour, part_number,
			                            notes, assigned_staff_id)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
			it.ID, parentID, it.Name, it.Category, it.UnitPrice, it.Quantity, it.Unit,
			it.DiscountPercent, it.TaxPercent, it.IsLabour, it.PartNumber, it.Notes,
			it.AssignedStaffID); err != nil {
			return mapPGError(err)
		}
	}
	return nil
}

// UpsertItem updates the item when its id already exists under the parent,
// otherwise inserts it (mock upsertJobCardItem semantics). Empty ids always
// insert with a server uuid.
func (s *Store) UpsertItem(ctx context.Context, itemsTable, parentID string, it models.MaintenanceItem) (models.MaintenanceItem, error) {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return models.MaintenanceItem{}, err
	}
	if it.ID != "" {
		tag, err := s.Pool.Exec(ctx,
			`UPDATE `+itemsTable+` SET name=$3, category=$4, unit_price=$5, quantity=$6, unit=$7,
			                          discount_percent=$8, tax_percent=$9, is_labour=$10,
			                          part_number=$11, notes=$12, assigned_staff_id=$13
			 WHERE `+p.fkColumn+` = $1 AND id = $2`,
			parentID, it.ID, it.Name, it.Category, it.UnitPrice, it.Quantity, it.Unit,
			it.DiscountPercent, it.TaxPercent, it.IsLabour, it.PartNumber, it.Notes,
			it.AssignedStaffID)
		if err != nil {
			return models.MaintenanceItem{}, mapPGError(err)
		}
		if tag.RowsAffected() == 1 {
			return it, nil
		}
	} else {
		it.ID = uuid.NewString()
	}
	_, err = s.Pool.Exec(ctx,
		`INSERT INTO `+itemsTable+` (id, `+p.fkColumn+`, name, category, unit_price, quantity,
		                            unit, discount_percent, tax_percent, is_labour, part_number,
		                            notes, assigned_staff_id)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
		it.ID, parentID, it.Name, it.Category, it.UnitPrice, it.Quantity, it.Unit,
		it.DiscountPercent, it.TaxPercent, it.IsLabour, it.PartNumber, it.Notes,
		it.AssignedStaffID)
	return it, mapPGError(err)
}

// DeleteItem removes one item row; 0 rows → ErrNotFound (unknown id or
// another parent's id — both 404 to the client).
func (s *Store) DeleteItem(ctx context.Context, itemsTable, parentID, itemID string) error {
	p, err := itemParentOf(itemsTable)
	if err != nil {
		return err
	}
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM `+itemsTable+` WHERE `+p.fkColumn+` = $1 AND id = $2`, parentID, itemID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
```

- [ ] **Step 5: Write `backend/internal/store/jobcards.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const jobCardColumns = `id, job_card_number, customer_id, vehicle_id, customer_complaints,
	inspection_checklist, fuel_level, km_reading, assigned_staff_id, status,
	promised_delivery_date, completed_at, estimated_cost_note, supervisor_notes, created_at`

func scanJobCard(row scanner) (models.JobCard, error) {
	var jc models.JobCard
	err := row.Scan(&jc.ID, &jc.JobCardNumber, &jc.CustomerID, &jc.VehicleID,
		&jc.CustomerComplaints, &jc.InspectionChecklist, &jc.FuelLevel, &jc.KmReading,
		&jc.AssignedStaffID, &jc.Status, &jc.PromisedDeliveryDate, &jc.CompletedAt,
		&jc.EstimatedCostNote, &jc.SupervisorNotes, &jc.CreatedAt)
	return jc, mapPGError(err)
}

func (s *Store) ListJobCards(ctx context.Context, garageID string) ([]models.JobCard, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+jobCardColumns+` FROM job_cards WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	cards := []models.JobCard{}
	for rows.Next() {
		jc, err := scanJobCard(rows)
		if err != nil {
			return nil, err
		}
		cards = append(cards, jc)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	items, err := s.ItemsByGarage(ctx, "job_card_items", garageID)
	if err != nil {
		return nil, err
	}
	for i := range cards {
		cards[i].Items = items[cards[i].ID]
		if cards[i].Items == nil {
			cards[i].Items = []models.MaintenanceItem{}
		}
	}
	return cards, nil
}

func (s *Store) JobCardByID(ctx context.Context, garageID, jobCardID string) (models.JobCard, error) {
	jc, err := scanJobCard(s.Pool.QueryRow(ctx,
		`SELECT `+jobCardColumns+` FROM job_cards WHERE garage_id = $1 AND id = $2`,
		garageID, jobCardID))
	if err != nil {
		return models.JobCard{}, err
	}
	jc.Items, err = s.ItemsOfParent(ctx, "job_card_items", jc.ID)
	return jc, err
}

func (s *Store) CreateJobCard(ctx context.Context, garageID string, jc models.JobCard) (models.JobCard, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.JobCard{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	created, err := scanJobCard(tx.QueryRow(ctx,
		`INSERT INTO job_cards (garage_id, job_card_number, customer_id, vehicle_id,
		                       customer_complaints, inspection_checklist, fuel_level, km_reading,
		                       assigned_staff_id, status, promised_delivery_date,
		                       estimated_cost_note, supervisor_notes)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING `+jobCardColumns,
		garageID, jc.JobCardNumber, jc.CustomerID, jc.VehicleID, jc.CustomerComplaints,
		jc.InspectionChecklist, jc.FuelLevel, jc.KmReading, jc.AssignedStaffID, jc.Status,
		jc.PromisedDeliveryDate, jc.EstimatedCostNote, jc.SupervisorNotes))
	if err != nil {
		return models.JobCard{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "job_card_items", created.ID, jc.Items); err != nil {
		return models.JobCard{}, err
	}
	created.Items = jc.Items
	return created, tx.Commit(ctx)
}

func (s *Store) UpdateJobCard(ctx context.Context, garageID string, jc models.JobCard) (models.JobCard, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.JobCard{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	// job_card_number and created_at are immutable (convention 9).
	updated, err := scanJobCard(tx.QueryRow(ctx,
		`UPDATE job_cards SET customer_id=$3, vehicle_id=$4, customer_complaints=$5,
		                        inspection_checklist=$6, fuel_level=$7, km_reading=$8,
		                        assigned_staff_id=$9, status=$10, promised_delivery_date=$11,
		                        estimated_cost_note=$12, supervisor_notes=$13
		 WHERE garage_id = $1 AND id = $2 RETURNING `+jobCardColumns,
		garageID, jc.ID, jc.CustomerID, jc.VehicleID, jc.CustomerComplaints,
		jc.InspectionChecklist, jc.FuelLevel, jc.KmReading, jc.AssignedStaffID, jc.Status,
		jc.PromisedDeliveryDate, jc.EstimatedCostNote, jc.SupervisorNotes))
	if err != nil {
		return models.JobCard{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "job_card_items", updated.ID, jc.Items); err != nil {
		return models.JobCard{}, err
	}
	updated.Items = jc.Items
	return updated, tx.Commit(ctx)
}

// UpdateJobCardStatus mirrors MockGarageRepository.updateJobStatus:
// delivered stamps completed_at with now, cancelled keeps the previous
// completed_at, every other status clears it.
func (s *Store) UpdateJobCardStatus(ctx context.Context, garageID, jobCardID, status string) (models.JobCard, error) {
	jc, err := scanJobCard(s.Pool.QueryRow(ctx,
		`UPDATE job_cards SET status = $3,
		                        completed_at = CASE WHEN $3 = 'delivered' THEN now()
		                                            WHEN $3 = 'cancelled' THEN completed_at
		                                            ELSE NULL END
		 WHERE garage_id = $1 AND id = $2 RETURNING `+jobCardColumns,
		garageID, jobCardID, status))
	if err != nil {
		return models.JobCard{}, err
	}
	jc.Items, err = s.ItemsOfParent(ctx, "job_card_items", jc.ID)
	return jc, err
}

func (s *Store) JobCardBelongs(ctx context.Context, garageID, jobCardID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM job_cards WHERE garage_id = $1 AND id = $2)`,
		garageID, jobCardID).Scan(&ok)
	return ok, err
}
```

- [ ] **Step 6: Write `backend/internal/store/catalog.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const catalogColumns = `id, name, category, unit_price, unit, is_labour, part_number, notes, created_at`

func scanCatalogItem(row scanner) (models.CatalogItem, error) {
	var ci models.CatalogItem
	err := row.Scan(&ci.ID, &ci.Name, &ci.Category, &ci.UnitPrice, &ci.Unit,
		&ci.IsLabour, &ci.PartNumber, &ci.Notes, &ci.CreatedAt)
	return ci, mapPGError(err)
}

func (s *Store) ListCatalogItems(ctx context.Context, garageID string) ([]models.CatalogItem, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+catalogColumns+` FROM catalog_items WHERE garage_id = $1 ORDER BY name, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.CatalogItem{}
	for rows.Next() {
		ci, err := scanCatalogItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, ci)
	}
	return items, rows.Err()
}
```

- [ ] **Step 7: Append to `backend/internal/api/helpers.go`**

Replace the whole file with (parseID stays, ref checks are added):

```go
package api

import (
	"context"

	"github.com/google/uuid"

	"garage-backend/internal/models"
)

// parseID parses a client-supplied resource id from a URL parameter.
func parseID(raw string) (uuid.UUID, error) {
	return uuid.Parse(raw)
}

// refCheck carries a reference-validation verdict; status 0 means valid.
type refCheck struct {
	status  int
	code    string
	message string
}

// checkRefs validates a required customer+vehicle reference pair and an
// optional assigned-staff id per convention 8: malformed uuid → 400,
// another garage's id → 404.
func (s *Server) checkRefs(ctx context.Context, garageID, customerID, vehicleID string, staffID *string) refCheck {
	if _, err := uuid.Parse(customerID); err != nil {
		return refCheck{400, "invalid_request", "invalid customer id"}
	}
	ok, err := s.Store.CustomerBelongs(ctx, garageID, customerID)
	if err != nil {
		return refCheck{500, "internal", "could not check customer"}
	}
	if !ok {
		return refCheck{404, "not_found", "customer not found"}
	}
	if _, err := uuid.Parse(vehicleID); err != nil {
		return refCheck{400, "invalid_request", "invalid vehicle id"}
	}
	ok, err = s.Store.VehicleBelongs(ctx, garageID, vehicleID)
	if err != nil {
		return refCheck{500, "internal", "could not check vehicle"}
	}
	if !ok {
		return refCheck{404, "not_found", "vehicle not found"}
	}
	if staffID != nil && *staffID != "" {
		if _, err := uuid.Parse(*staffID); err != nil {
			return refCheck{400, "invalid_request", "invalid assignedStaffId"}
		}
		ok, err = s.Store.StaffBelongs(ctx, garageID, *staffID)
		if err != nil {
			return refCheck{500, "internal", "could not check assigned staff"}
		}
		if !ok {
			return refCheck{404, "not_found", "assigned staff not found"}
		}
	}
	return refCheck{}
}

// checkItemStaffRef validates one item's optional assignedStaffId.
func (s *Server) checkItemStaffRef(ctx context.Context, garageID string, it models.MaintenanceItem) refCheck {
	if it.AssignedStaffID == nil || *it.AssignedStaffID == "" {
		return refCheck{}
	}
	if _, err := uuid.Parse(*it.AssignedStaffID); err != nil {
		return refCheck{400, "invalid_request", "invalid assignedStaffId"}
	}
	ok, err := s.Store.StaffBelongs(ctx, garageID, *it.AssignedStaffID)
	if err != nil {
		return refCheck{500, "internal", "could not check assigned staff"}
	}
	if !ok {
		return refCheck{404, "not_found", "assigned staff not found"}
	}
	return refCheck{}
}
```

- [ ] **Step 8: Write `backend/internal/api/jobcards.go`**

```go
package api

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateJobCard(jc models.JobCard) (string, int) {
	if jc.JobCardNumber == "" {
		return "jobCardNumber is required", 400
	}
	if !models.ValidValue(jc.Status, models.JobStatuses...) {
		return "invalid status \"" + jc.Status + "\"", 400
	}
	if jc.PromisedDeliveryDate.IsZero() {
		return "promisedDeliveryDate is required", 400
	}
	return "", 0
}

// normalizeJobCard fills the constructor defaults the Dart side always has:
// fuelLevel '1/2', empty complaints, the default inspection checklist and a
// non-nil items slice.
func normalizeJobCard(jc *models.JobCard) {
	if jc.FuelLevel == "" {
		jc.FuelLevel = models.DefaultFuelLevel
	}
	if jc.CustomerComplaints == nil {
		jc.CustomerComplaints = []string{}
	}
	if jc.InspectionChecklist == nil {
		jc.InspectionChecklist = models.DefaultChecklist
	}
	if jc.Items == nil {
		jc.Items = []models.MaintenanceItem{}
	}
}

func (s *Server) listJobCards(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListJobCards(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list job cards")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createJobCard(w http.ResponseWriter, r *http.Request) {
	var jc models.JobCard
	if !httputil.Decode(w, r, &jc) {
		return
	}
	normalizeJobCard(&jc)
	if msg, status := validateJobCard(jc); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, jc.CustomerID, jc.VehicleID, jc.AssignedStaffID); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range jc.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	created, err := s.Store.CreateJobCard(r.Context(), garageID, jc)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "job card number already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create job card")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateJobCard(w http.ResponseWriter, r *http.Request) {
	var jc models.JobCard
	if !httputil.Decode(w, r, &jc) {
		return
	}
	jc.ID = chi.URLParam(r, "jobCardId")
	if _, err := parseID(jc.ID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	normalizeJobCard(&jc)
	if msg, status := validateJobCard(jc); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, jc.CustomerID, jc.VehicleID, jc.AssignedStaffID); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range jc.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	updated, err := s.Store.UpdateJobCard(r.Context(), garageID, jc)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update job card")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) updateJobCardStatus(w http.ResponseWriter, r *http.Request) {
	jobCardID := chi.URLParam(r, "jobCardId")
	if _, err := parseID(jobCardID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if !models.ValidValue(req.Status, models.JobStatuses...) {
		httputil.Error(w, 400, "invalid_request", "invalid status \""+req.Status+"\"")
		return
	}
	updated, err := s.Store.UpdateJobCardStatus(r.Context(), auth.GarageID(r.Context()), jobCardID, req.Status)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update job card status")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) upsertJobCardItem(w http.ResponseWriter, r *http.Request) {
	jobCardID := chi.URLParam(r, "jobCardId")
	if _, err := parseID(jobCardID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	var it models.MaintenanceItem
	if !httputil.Decode(w, r, &it) {
		return
	}
	if it.Name == "" {
		httputil.Error(w, 400, "invalid_request", "name is required")
		return
	}
	if !models.ValidValue(it.Category, models.ItemCategories...) {
		httputil.Error(w, 400, "invalid_request", "invalid category \""+it.Category+"\"")
		return
	}
	garageID := auth.GarageID(r.Context())
	if _, err := s.Store.JobCardByID(r.Context(), garageID, jobCardID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "job card not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not load job card")
		return
	}
	if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	saved, err := s.Store.UpsertItem(r.Context(), "job_card_items", jobCardID, it)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not save job card item")
		return
	}
	httputil.JSON(w, 200, saved)
}

func (s *Server) deleteJobCardItem(w http.ResponseWriter, r *http.Request) {
	jobCardID := chi.URLParam(r, "jobCardId")
	itemID := chi.URLParam(r, "itemId")
	if _, err := parseID(jobCardID); err != nil {
		httputil.Error(w, 404, "not_found", "job card not found")
		return
	}
	if _, err := parseID(itemID); err != nil {
		httputil.Error(w, 404, "not_found", "item not found")
		return
	}
	err := s.Store.DeleteItem(r.Context(), "job_card_items", jobCardID, itemID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "item not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete job card item")
		return
	}
	w.WriteHeader(204)
}
```

- [ ] **Step 9: Write `backend/internal/api/catalog.go`**

```go
package api

import (
	"net/http"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
)

func (s *Server) listCatalog(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListCatalogItems(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list catalog")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}
```

- [ ] **Step 10: Wire routes in `backend/internal/api/router.go`**

Inside the `r.Route("/garages/{garageId}", ...)` block, after the customers group:

```go
			r.Route("/jobcards", func(r chi.Router) {
				r.Use(auth.RequirePermission("jobcards.manage"))
				r.Get("/", s.listJobCards)
				r.Post("/", s.createJobCard)
				r.Put("/{jobCardId}", s.updateJobCard)
				r.Post("/{jobCardId}/status", s.updateJobCardStatus)
				r.Post("/{jobCardId}/items", s.upsertJobCardItem)
				r.Delete("/{jobCardId}/items/{itemId}", s.deleteJobCardItem)
			})
			// Catalog is readable by any member of the garage (spec §5).
			r.Route("/catalog", func(r chi.Router) {
				r.Get("/", s.listCatalog)
			})
```

- [ ] **Step 11: Write `backend/internal/itest/jobcards_test.go`**

```go
package itest

import (
	"testing"
	"time"

	"garage-backend/internal/models"
)

func jobCardBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"jobCardNumber":        number,
		"customerId":           customerID,
		"vehicleId":            vehicleID,
		"customerComplaints":   []string{"AC not cooling"},
		"kmReading":            32000,
		"promisedDeliveryDate": time.Now().UTC().Add(6 * time.Hour).Format(time.RFC3339),
	}
}

func createJobCard(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.JobCard) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/jobcards", token, garageID, body)
	var jc models.JobCard
	if status == 201 {
		mustUnmarshal(t, data, &jc)
	}
	return status, data, jc
}

func itemBody(name string) map[string]any {
	return map[string]any{
		"name": name, "category": "sparePart", "unitPrice": 1200.0,
		"quantity": 2.0, "unit": "Pcs", "taxPercent": 18.0,
	}
}

func fetchJobCards(t *testing.T, token, garageID string) []models.JobCard {
	t.Helper()
	status, data := doJSON(t, "GET", "/api/jobcards", token, garageID, nil)
	if status != 200 {
		t.Fatalf("list job cards: status %d body %s", status, data)
	}
	var list struct {
		Items []models.JobCard `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	return list.Items
}

func TestJobCardCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "jc1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("JobCustomer"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	// Client-supplied item id must survive; omitted checklist gets the default.
	body := jobCardBody("JC-1001", customer.ID, vehicle.ID)
	body["items"] = []map[string]any{{"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
		"name": "Engine oil", "category": "fluids", "unitPrice": 450.0, "quantity": 1.0}}
	status, data, jc := createJobCard(t, owner.AccessToken, garageID, body)
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if len(jc.Items) != 1 || jc.Items[0].ID != "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" {
		t.Fatalf("items = %+v", jc.Items)
	}
	if len(jc.InspectionChecklist) != 8 || !jc.InspectionChecklist["Engine Oil Level"] {
		t.Fatalf("default checklist not applied: %+v", jc.InspectionChecklist)
	}
	if jc.FuelLevel != "1/2" || jc.CustomerComplaints == nil {
		t.Fatalf("defaults lost: %+v", jc)
	}

	createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-1002", customer.ID, vehicle.ID))
	cards := fetchJobCards(t, owner.AccessToken, garageID)
	if len(cards) != 2 || cards[0].JobCardNumber != "JC-1002" {
		t.Fatalf("list must be newest first: %+v", cards)
	}

	// PUT replaces items wholesale and preserves supplied ids.
	jc.Items = []models.MaintenanceItem{
		{ID: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", Name: "Wiper", Category: "sparePart", UnitPrice: 300, Quantity: 1, Unit: "Pcs"},
		{Name: "Labour", Category: "labour", UnitPrice: 500, Quantity: 2, Unit: "Hours", IsLabour: true},
	}
	jc.KmReading = 32500
	status, data = doJSON(t, "PUT", "/api/jobcards/"+jc.ID, owner.AccessToken, garageID, jc)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.JobCard
	mustUnmarshal(t, data, &updated)
	if updated.KmReading != 32500 || len(updated.Items) != 2 ||
		updated.Items[0].ID != "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" ||
		updated.Items[1].ID == "" {
		t.Fatalf("update lost items/km: %+v", updated)
	}

	// Duplicate number in the SAME garage is 409.
	status, data = createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-1001", customer.ID, vehicle.ID))
	if status != 409 {
		t.Fatalf("duplicate number: status %d body %s", status, data)
	}
}

func TestJobCardStatusTransitions(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "jc2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("StatusCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	_, _, jc := createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-2001", customer.ID, vehicle.ID))

	post := func(status string) (int, []byte, models.JobCard) {
		st, data := doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/status", owner.AccessToken, garageID,
			map[string]any{"status": status})
		var out models.JobCard
		if st == 200 {
			mustUnmarshal(t, data, &out)
		}
		return st, data, out
	}

	st, _, out := post("inProgress")
	if st != 200 || out.Status != "inProgress" || out.CompletedAt != nil {
		t.Fatalf("inProgress: st=%d out=%+v", st, out)
	}
	st, _, out = post("delivered")
	if st != 200 || out.CompletedAt == nil {
		t.Fatalf("delivered must stamp completedAt: st=%d out=%+v", st, out)
	}
	st, _, out = post("cancelled")
	if st != 200 || out.CompletedAt == nil {
		t.Fatalf("cancelled must keep completedAt: st=%d out=%+v", st, out)
	}
	st, _, out = post("received")
	if st != 200 || out.CompletedAt != nil {
		t.Fatalf("back to received must clear completedAt: st=%d out=%+v", st, out)
	}
	st, _ = doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "flying"})
	if st != 400 {
		t.Fatalf("invalid status: st=%d", st)
	}
}

func TestJobCardItemEndpoints(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "jc3")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("ItemCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	_, _, jc := createJobCard(t, owner.AccessToken, garageID, jobCardBody("JC-3001", customer.ID, vehicle.ID))

	// POST without id → server generates.
	item := itemBody("Engine oil")
	item["id"] = ""
	status, data := doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/items", owner.AccessToken, garageID, item)
	if status != 200 {
		t.Fatalf("upsert new: status %d body %s", status, data)
	}
	var saved models.MaintenanceItem
	mustUnmarshal(t, data, &saved)
	if saved.ID == "" {
		t.Fatalf("server must generate item id: %+v", saved)
	}

	// Upsert by the same id updates in place.
	item["id"] = saved.ID
	item["name"] = "Engine oil 5W-40"
	status, _ = doJSON(t, "POST", "/api/jobcards/"+jc.ID+"/items", owner.AccessToken, garageID, item)
	if status != 200 {
		t.Fatalf("upsert existing: status %d", status)
	}
	cards := fetchJobCards(t, owner.AccessToken, garageID)
	if len(cards) != 1 || len(cards[0].Items) != 1 || cards[0].Items[0].Name != "Engine oil 5W-40" {
		t.Fatalf("upsert-by-id produced: %+v", cards)
	}

	// Delete → 204; deleting again → 404.
	status, _ = doJSON(t, "DELETE", "/api/jobcards/"+jc.ID+"/items/"+saved.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete item: status %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/jobcards/"+jc.ID+"/items/"+saved.ID, owner.AccessToken, garageID, nil)
	if status != 404 {
		t.Fatalf("delete missing item: status %d", status)
	}
	cards = fetchJobCards(t, owner.AccessToken, garageID)
	if len(cards[0].Items) != 0 {
		t.Fatalf("items after delete: %+v", cards[0].Items)
	}
}

func TestJobCardValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "jc4a")
	b := registerOwner(t, "jc4b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("A"))
	aVehicle := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)
	_, _, bCustomer := createCustomer(t, b.AccessToken, bGarage, customerBody("B"))

	// Unknown status → 400.
	body := jobCardBody("JC-4001", aCustomer.ID, aVehicle.ID)
	body["status"] = "flying"
	status, _ := createJobCard(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("bad status: %d", status)
	}
	// Malformed customer id → 400.
	status, _ = createJobCard(t, a.AccessToken, aGarage, jobCardBody("JC-4002", "nope", aVehicle.ID))
	if status != 400 {
		t.Fatalf("malformed customer id: %d", status)
	}
	// Another garage's customer → 404.
	status, _ = createJobCard(t, a.AccessToken, aGarage, jobCardBody("JC-4003", bCustomer.ID, aVehicle.ID))
	if status != 404 {
		t.Fatalf("foreign customer: %d", status)
	}
	// Duplicate numbers are per-garage: B may reuse A's number.
	bVehicle := createVehicleFor(t, b.AccessToken, bGarage, bCustomer.ID)
	status, _, jcB := createJobCard(t, b.AccessToken, bGarage, jobCardBody("JC-4001", bCustomer.ID, bVehicle.ID))
	if status != 201 {
		t.Fatalf("B reusing A's number must succeed: %d", status)
	}

	// B sees nothing of A's.
	if cards := fetchJobCards(t, b.AccessToken, bGarage); len(cards) != 1 || cards[0].ID != jcB.ID {
		t.Fatalf("B sees A's job cards: %+v", cards)
	}
	aCard := fetchJobCards(t, a.AccessToken, aGarage)[0]
	aCard.CustomerID = bCustomer.ID
	status, _ = doJSON(t, "PUT", "/api/jobcards/"+aCard.ID, b.AccessToken, bGarage, aCard)
	if status != 404 {
		t.Fatalf("B update A's job card: %d", status)
	}
}
```

- [ ] **Step 12: Write `backend/internal/itest/catalog_test.go`**

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestCatalogList(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "cat1")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "GET", "/api/catalog", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("empty catalog: status %d body %s", status, data)
	}
	var list struct {
		Items []models.CatalogItem `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("catalog ships empty: %+v", list.Items)
	}

	if _, err := pool.Exec(ctx,
		`INSERT INTO catalog_items (garage_id, name, category, unit_price)
		 VALUES ($1,'Engine Oil 5W-40','fluids',450)`, garageID); err != nil {
		t.Fatal(err)
	}
	status, data = doJSON(t, "GET", "/api/catalog", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("catalog: status %d body %s", status, data)
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 || list.Items[0].Name != "Engine Oil 5W-40" || list.Items[0].UnitPrice != 450 {
		t.Fatalf("catalog = %+v", list.Items)
	}
}
```

- [ ] **Step 13: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run 'TestJobCard|TestCatalog' -v` (5 tests PASS), `go test -count=1 ./...` (all PASS).

- [ ] **Step 14: Commit**

From repo root:
```bash
git add backend/internal/models/maintenance_item.go backend/internal/models/catalog.go backend/internal/models/jobcard.go backend/internal/store/items.go backend/internal/store/jobcards.go backend/internal/store/catalog.go backend/internal/api/jobcards.go backend/internal/api/catalog.go backend/internal/api/helpers.go backend/internal/api/router.go backend/internal/itest/jobcards_test.go backend/internal/itest/catalog_test.go
git commit -m "feat: add job cards with item plumbing and read-only catalog"
```

---

### Task 8: Quotations domain (with conversion guard)

**Files:**
- Create: `backend/internal/models/quotation.go`
- Create: `backend/internal/store/quotations.go`
- Create: `backend/internal/api/quotations.go`
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/quotations_test.go`

Design note: PUT `/quotations/{id}` sets `status` wholesale (mirrors the mock's `updateQuotation`, which replaces the object; the provider's edit form never changes status). The converted-only-from-approved guard (spec §5/§8) is pinned on the status ENDPOINT, which is the only path the provider uses for transitions.

- [ ] **Step 1: Write `backend/internal/models/quotation.go`**

```go
package models

import "time"

type Quotation struct {
	ID              string            `json:"id"`
	QuotationNumber string            `json:"quotationNumber"`
	CustomerID      string            `json:"customerId"`
	VehicleID       string            `json:"vehicleId"`
	KmReading       int               `json:"kmReading"`
	Items           []MaintenanceItem `json:"items"`
	OverallDiscount float64           `json:"overallDiscount"`
	TaxPercent      float64           `json:"taxPercent"`
	ValidityDays    int               `json:"validityDays"`
	Status          string            `json:"status"`
	Notes           *string           `json:"notes"`
	CreatedAt       time.Time         `json:"createdAt"`
	ValidUntil      time.Time         `json:"validUntil"`
}
```

- [ ] **Step 2: Write `backend/internal/store/quotations.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const quotationColumns = `id, quotation_number, customer_id, vehicle_id, km_reading,
	overall_discount, tax_percent, validity_days, status, notes, valid_until, created_at`

func scanQuotation(row scanner) (models.Quotation, error) {
	var q models.Quotation
	err := row.Scan(&q.ID, &q.QuotationNumber, &q.CustomerID, &q.VehicleID, &q.KmReading,
		&q.OverallDiscount, &q.TaxPercent, &q.ValidityDays, &q.Status, &q.Notes,
		&q.ValidUntil, &q.CreatedAt)
	return q, mapPGError(err)
}

func (s *Store) ListQuotations(ctx context.Context, garageID string) ([]models.Quotation, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+quotationColumns+` FROM quotations WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	quotes := []models.Quotation{}
	for rows.Next() {
		q, err := scanQuotation(rows)
		if err != nil {
			return nil, err
		}
		quotes = append(quotes, q)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	items, err := s.ItemsByGarage(ctx, "quotation_items", garageID)
	if err != nil {
		return nil, err
	}
	for i := range quotes {
		quotes[i].Items = items[quotes[i].ID]
		if quotes[i].Items == nil {
			quotes[i].Items = []models.MaintenanceItem{}
		}
	}
	return quotes, nil
}

func (s *Store) QuotationByID(ctx context.Context, garageID, quotationID string) (models.Quotation, error) {
	q, err := scanQuotation(s.Pool.QueryRow(ctx,
		`SELECT `+quotationColumns+` FROM quotations WHERE garage_id = $1 AND id = $2`,
		garageID, quotationID))
	if err != nil {
		return models.Quotation{}, err
	}
	q.Items, err = s.ItemsOfParent(ctx, "quotation_items", q.ID)
	return q, err
}

func (s *Store) CreateQuotation(ctx context.Context, garageID string, q models.Quotation) (models.Quotation, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Quotation{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	created, err := scanQuotation(tx.QueryRow(ctx,
		`INSERT INTO quotations (garage_id, quotation_number, customer_id, vehicle_id, km_reading,
		                        overall_discount, tax_percent, validity_days, status, notes, valid_until)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING `+quotationColumns,
		garageID, q.QuotationNumber, q.CustomerID, q.VehicleID, q.KmReading,
		q.OverallDiscount, q.TaxPercent, q.ValidityDays, q.Status, q.Notes, q.ValidUntil))
	if err != nil {
		return models.Quotation{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "quotation_items", created.ID, q.Items); err != nil {
		return models.Quotation{}, err
	}
	created.Items = q.Items
	return created, tx.Commit(ctx)
}

// quotation_number and created_at are immutable (convention 9).
func (s *Store) UpdateQuotation(ctx context.Context, garageID string, q models.Quotation) (models.Quotation, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Quotation{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	updated, err := scanQuotation(tx.QueryRow(ctx,
		`UPDATE quotations SET customer_id=$3, vehicle_id=$4, km_reading=$5,
		                        overall_discount=$6, tax_percent=$7, validity_days=$8,
		                        status=$9, notes=$10, valid_until=$11
		 WHERE garage_id = $1 AND id = $2 RETURNING `+quotationColumns,
		garageID, q.ID, q.CustomerID, q.VehicleID, q.KmReading, q.OverallDiscount,
		q.TaxPercent, q.ValidityDays, q.Status, q.Notes, q.ValidUntil))
	if err != nil {
		return models.Quotation{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "quotation_items", updated.ID, q.Items); err != nil {
		return models.Quotation{}, err
	}
	updated.Items = q.Items
	return updated, tx.Commit(ctx)
}

func (s *Store) UpdateQuotationStatus(ctx context.Context, garageID, quotationID, status string) (models.Quotation, error) {
	q, err := scanQuotation(s.Pool.QueryRow(ctx,
		`UPDATE quotations SET status = $3 WHERE garage_id = $1 AND id = $2 RETURNING `+quotationColumns,
		garageID, quotationID, status))
	if err != nil {
		return models.Quotation{}, err
	}
	q.Items, err = s.ItemsOfParent(ctx, "quotation_items", q.ID)
	return q, err
}
```

- [ ] **Step 3: Write `backend/internal/api/quotations.go`**

```go
package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateQuotation(q models.Quotation) (string, int) {
	if q.QuotationNumber == "" {
		return "quotationNumber is required", 400
	}
	if !models.ValidValue(q.Status, models.QuotationStatuses...) {
		return "invalid status \"" + q.Status + "\"", 400
	}
	if q.ValidityDays <= 0 {
		return "validityDays must be positive", 400
	}
	return "", 0
}

// normalizeQuotation fills the Dart constructor default validUntil =
// today + validityDays when the client omits it, and keeps items non-nil.
func normalizeQuotation(q *models.Quotation) {
	if q.ValidUntil.IsZero() {
		q.ValidUntil = time.Now().UTC().AddDate(0, 0, q.ValidityDays)
	}
	if q.Items == nil {
		q.Items = []models.MaintenanceItem{}
	}
}

func (s *Server) listQuotations(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListQuotations(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list quotations")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createQuotation(w http.ResponseWriter, r *http.Request) {
	var q models.Quotation
	if !httputil.Decode(w, r, &q) {
		return
	}
	normalizeQuotation(&q)
	if msg, status := validateQuotation(q); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, q.CustomerID, q.VehicleID, nil); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range q.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	created, err := s.Store.CreateQuotation(r.Context(), garageID, q)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "quotation number already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create quotation")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateQuotation(w http.ResponseWriter, r *http.Request) {
	var q models.Quotation
	if !httputil.Decode(w, r, &q) {
		return
	}
	q.ID = chi.URLParam(r, "quotationId")
	if _, err := parseID(q.ID); err != nil {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	normalizeQuotation(&q)
	if msg, status := validateQuotation(q); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkRefs(r.Context(), garageID, q.CustomerID, q.VehicleID, nil); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range q.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	updated, err := s.Store.UpdateQuotation(r.Context(), garageID, q)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update quotation")
		return
	}
	httputil.JSON(w, 200, updated)
}

// updateQuotationStatus enforces the provider guard: converted is reachable
// only from approved (spec §8, mirroring convertQuotation in
// lib/providers/garage_provider.dart).
func (s *Server) updateQuotationStatus(w http.ResponseWriter, r *http.Request) {
	quotationID := chi.URLParam(r, "quotationId")
	if _, err := parseID(quotationID); err != nil {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if !models.ValidValue(req.Status, models.QuotationStatuses...) {
		httputil.Error(w, 400, "invalid_request", "invalid status \""+req.Status+"\"")
		return
	}
	garageID := auth.GarageID(r.Context())
	current, err := s.Store.QuotationByID(r.Context(), garageID, quotationID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "quotation not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load quotation")
		return
	}
	if req.Status == "converted" && current.Status != "approved" {
		httputil.Error(w, 422, "unprocessable", "quotation can only be converted from approved")
		return
	}
	updated, err := s.Store.UpdateQuotationStatus(r.Context(), garageID, quotationID, req.Status)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update quotation status")
		return
	}
	httputil.JSON(w, 200, updated)
}
```

- [ ] **Step 4: Wire routes in `backend/internal/api/router.go`**

After the jobcards group:

```go
			r.Route("/quotations", func(r chi.Router) {
				r.Use(auth.RequirePermission("quotations.manage"))
				r.Get("/", s.listQuotations)
				r.Post("/", s.createQuotation)
				r.Put("/{quotationId}", s.updateQuotation)
				r.Post("/{quotationId}/status", s.updateQuotationStatus)
			})
```

- [ ] **Step 5: Write `backend/internal/itest/quotations_test.go`**

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func quotationBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"quotationNumber": number, "customerId": customerID, "vehicleId": vehicleID,
		"kmReading": 15000, "overallDiscount": 100.0, "taxPercent": 18.0, "validityDays": 15,
		"items": []map[string]any{
			{"name": "Clutch plate", "category": "sparePart", "unitPrice": 2500.0, "quantity": 1.0},
		},
	}
}

func createQuotation(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Quotation) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/quotations", token, garageID, body)
	var q models.Quotation
	if status == 201 {
		mustUnmarshal(t, data, &q)
	}
	return status, data, q
}

func TestQuotationCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "q1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("QCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	// validUntil omitted → server fills today + validityDays.
	status, data, q := createQuotation(t, owner.AccessToken, garageID, quotationBody("EST-1001", customer.ID, vehicle.ID))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if q.ValidUntil.IsZero() || len(q.Items) != 1 || q.Items[0].ID == "" {
		t.Fatalf("create lost defaults: %+v", q)
	}
	_, _, q2 := createQuotation(t, owner.AccessToken, garageID, quotationBody("EST-1002", customer.ID, vehicle.ID))
	status, data = doJSON(t, "GET", "/api/quotations", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Quotation `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].QuotationNumber != "EST-1002" {
		t.Fatalf("list must be newest first: %+v", list.Items)
	}

	q.OverallDiscount = 250
	q.Items = []models.MaintenanceItem{
		{Name: "Clutch plate", Category: "sparePart", UnitPrice: 2500, Quantity: 1, Unit: "Pcs"},
		{Name: "Fitting", Category: "labour", UnitPrice: 400, Quantity: 1, Unit: "Job", IsLabour: true},
	}
	status, data = doJSON(t, "PUT", "/api/quotations/"+q.ID, owner.AccessToken, garageID, q)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Quotation
	mustUnmarshal(t, data, &updated)
	if updated.OverallDiscount != 250 || len(updated.Items) != 2 || updated.Items[1].ID == "" {
		t.Fatalf("update lost data: %+v", updated)
	}
}

func TestQuotationConversionGuard(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "q2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("GuardCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	_, _, q := createQuotation(t, owner.AccessToken, garageID, quotationBody("EST-2001", customer.ID, vehicle.ID))

	status, data := doJSON(t, "POST", "/api/quotations/"+q.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "converted"})
	if status != 422 {
		t.Fatalf("draft→converted: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" ||
		message != "quotation can only be converted from approved" {
		t.Fatalf("error = %s / %s", code, message)
	}
	status, _ = doJSON(t, "POST", "/api/quotations/"+q.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "approved"})
	if status != 200 {
		t.Fatalf("draft→approved: status %d", status)
	}
	status, _ = doJSON(t, "POST", "/api/quotations/"+q.ID+"/status", owner.AccessToken, garageID,
		map[string]any{"status": "converted"})
	if status != 200 {
		t.Fatalf("approved→converted: status %d", status)
	}
}

func TestQuotationValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "q3a")
	b := registerOwner(t, "q3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("AQ"))
	aVehicle := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)
	_, _, bCustomer := createCustomer(t, b.AccessToken, bGarage, customerBody("BQ"))
	bVehicle := createVehicleFor(t, b.AccessToken, bGarage, bCustomer.ID)

	body := quotationBody("EST-3001", aCustomer.ID, aVehicle.ID)
	body["status"] = "draft"
	body["validityDays"] = 0
	status, _ := createQuotation(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("validityDays 0: %d", status)
	}
	status, _ = createQuotation(t, a.AccessToken, aGarage, quotationBody("EST-3002", bCustomer.ID, aVehicle.ID))
	if status != 404 {
		t.Fatalf("foreign customer: %d", status)
	}

	_, _, mine := createQuotation(t, a.AccessToken, aGarage, quotationBody("EST-3003", aCustomer.ID, aVehicle.ID))
	// B reusing A's number is fine (UNIQUE is per-garage).
	status, _, _ = createQuotation(t, b.AccessToken, bGarage, quotationBody("EST-3003", bCustomer.ID, bVehicle.ID))
	if status != 201 {
		t.Fatalf("B same number: %d", status)
	}
	status, _ = doJSON(t, "PUT", "/api/quotations/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's quotation: %d", status)
	}
}
```

- [ ] **Step 6: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestQuotation -v` (3 tests PASS), `go test -count=1 ./...` (all PASS).

- [ ] **Step 7: Commit**

From repo root:
```bash
git add backend/internal/models/quotation.go backend/internal/store/quotations.go backend/internal/api/quotations.go backend/internal/api/router.go backend/internal/itest/quotations_test.go
git commit -m "feat: add quotations domain with conversion guard"
```

---

### Task 9: Invoices domain (items, payments embed, cancel rules)

**Files:**
- Create: `backend/internal/models/payment.go`
- Create: `backend/internal/models/invoice.go`
- Create: `backend/internal/store/invoices.go`
- Create: `backend/internal/api/invoices.go`
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/invoices_test.go`

Design notes:
- The provider's `cancelInvoice` (`lib/providers/garage_provider.dart:551`) throws when `totalPaidAmount > 0`, then calls `updateInvoice(copyWith(cancelledAt: now))`. So the cancel rule is enforced on BOTH paths: `POST /invoices/{id}/cancel` and a PUT whose payload sets `cancelledAt`.
- Invoice responses embed `items` AND `payments` (spec §5) because the Dart invoice derives status/balance from payments.
- `cancelled_at` cannot be set on create (invoices are born active).

- [ ] **Step 1: Write `backend/internal/models/payment.go`**

```go
package models

import "time"

type Payment struct {
	ID             string    `json:"id"`
	InvoiceID      string    `json:"invoiceId"`
	CustomerID     *string   `json:"customerId"`
	Amount         float64   `json:"amount"`
	Mode           string    `json:"mode"`
	TransactionRef *string   `json:"transactionRef"`
	PaymentDate    time.Time `json:"paymentDate"`
	Notes          *string   `json:"notes"`
	ReceivedBy     *string   `json:"receivedBy"`
}
```

- [ ] **Step 2: Write `backend/internal/models/invoice.go`**

```go
package models

import "time"

type Invoice struct {
	ID                 string            `json:"id"`
	InvoiceNumber      string            `json:"invoiceNumber"`
	JobCardID          *string           `json:"jobCardId"`
	CustomerID         string            `json:"customerId"`
	VehicleID          string            `json:"vehicleId"`
	KmReading          int               `json:"kmReading"`
	Items              []MaintenanceItem `json:"items"`
	DiscountAmount     float64           `json:"discountAmount"`
	TaxPercent         float64           `json:"taxPercent"`
	Payments           []Payment         `json:"payments"`
	InvoiceDate        time.Time         `json:"invoiceDate"`
	DueDate            *time.Time        `json:"dueDate"`
	CancelledAt        *time.Time        `json:"cancelledAt"`
	Notes              *string           `json:"notes"`
	TermsAndConditions *string           `json:"termsAndConditions"`
	CreatedAt          time.Time         `json:"createdAt"`
}
```

- [ ] **Step 3: Write `backend/internal/store/invoices.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const invoiceColumns = `id, invoice_number, job_card_id, customer_id, vehicle_id, km_reading,
	discount_amount, tax_percent, invoice_date, due_date, cancelled_at, notes,
	terms_and_conditions, created_at`

const paymentColumns = `id, invoice_id, customer_id, amount, mode, transaction_ref,
	payment_date, notes, received_by`

func scanInvoice(row scanner) (models.Invoice, error) {
	var inv models.Invoice
	err := row.Scan(&inv.ID, &inv.InvoiceNumber, &inv.JobCardID, &inv.CustomerID,
		&inv.VehicleID, &inv.KmReading, &inv.DiscountAmount, &inv.TaxPercent,
		&inv.InvoiceDate, &inv.DueDate, &inv.CancelledAt, &inv.Notes,
		&inv.TermsAndConditions, &inv.CreatedAt)
	return inv, mapPGError(err)
}

func scanPayment(row scanner) (models.Payment, error) {
	var p models.Payment
	err := row.Scan(&p.ID, &p.InvoiceID, &p.CustomerID, &p.Amount, &p.Mode,
		&p.TransactionRef, &p.PaymentDate, &p.Notes, &p.ReceivedBy)
	return p, mapPGError(err)
}

// InvoiceMoneyFor loads an invoice's raw money components (gross item
// taxable total, document discount, tax percent, paid total) so handlers can
// run the Dart-side math through models.InvoiceMoney without full rows.
func (s *Store) InvoiceMoneyFor(ctx context.Context, garageID, invoiceID string) (models.InvoiceMoney, error) {
	var m models.InvoiceMoney
	err := s.Pool.QueryRow(ctx,
		`SELECT i.cancelled_at,
		        COALESCE(item_sums.gross, 0), i.discount_amount, i.tax_percent,
		        COALESCE(paid_sums.paid, 0)
		 FROM invoices i
		 LEFT JOIN (SELECT invoice_id,
		                   SUM(unit_price * quantity * (1 - discount_percent / 100)) AS gross
		            FROM invoice_items GROUP BY invoice_id) item_sums
		            ON item_sums.invoice_id = i.id
		 LEFT JOIN (SELECT invoice_id, SUM(amount) AS paid
		            FROM payments GROUP BY invoice_id) paid_sums
		            ON paid_sums.invoice_id = i.id
		 WHERE i.garage_id = $1 AND i.id = $2`, garageID, invoiceID).Scan(
		&m.CancelledAt, &m.Gross, &m.Discount, &m.TaxPercent, &m.Paid)
	return m, mapPGError(err)
}

func (s *Store) PaymentsByInvoice(ctx context.Context, invoiceID string) ([]models.Payment, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+paymentColumns+` FROM payments WHERE invoice_id = $1 ORDER BY payment_date, id`,
		invoiceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Payment{}
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, p)
	}
	return items, rows.Err()
}

// PaymentsByGarage returns every payment for the garage's invoices, keyed by
// invoice id (list endpoint embeds them).
func (s *Store) PaymentsByGarage(ctx context.Context, garageID string) (map[string][]models.Payment, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT p.id, p.invoice_id, p.customer_id, p.amount, p.mode, p.transaction_ref,
		        p.payment_date, p.notes, p.received_by
		 FROM payments p
		 JOIN invoices i ON i.id = p.invoice_id
		 WHERE i.garage_id = $1 ORDER BY p.payment_date, p.id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	pays := map[string][]models.Payment{}
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		pays[p.InvoiceID] = append(pays[p.InvoiceID], p)
	}
	return pays, rows.Err()
}

func (s *Store) ListInvoices(ctx context.Context, garageID string) ([]models.Invoice, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	invs := []models.Invoice{}
	for rows.Next() {
		inv, err := scanInvoice(rows)
		if err != nil {
			return nil, err
		}
		invs = append(invs, inv)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	items, err := s.ItemsByGarage(ctx, "invoice_items", garageID)
	if err != nil {
		return nil, err
	}
	pays, err := s.PaymentsByGarage(ctx, garageID)
	if err != nil {
		return nil, err
	}
	for i := range invs {
		invs[i].Items = items[invs[i].ID]
		if invs[i].Items == nil {
			invs[i].Items = []models.MaintenanceItem{}
		}
		invs[i].Payments = pays[invs[i].ID]
		if invs[i].Payments == nil {
			invs[i].Payments = []models.Payment{}
		}
	}
	return invs, nil
}

func (s *Store) InvoiceByID(ctx context.Context, garageID, invoiceID string) (models.Invoice, error) {
	inv, err := scanInvoice(s.Pool.QueryRow(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE garage_id = $1 AND id = $2`,
		garageID, invoiceID))
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Items, err = s.ItemsOfParent(ctx, "invoice_items", inv.ID)
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Payments, err = s.PaymentsByInvoice(ctx, inv.ID)
	return inv, err
}

func (s *Store) CreateInvoice(ctx context.Context, garageID string, inv models.Invoice) (models.Invoice, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Invoice{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	// cancelled_at is NOT writable on create — invoices are born active.
	created, err := scanInvoice(tx.QueryRow(ctx,
		`INSERT INTO invoices (garage_id, invoice_number, job_card_id, customer_id, vehicle_id,
		                      km_reading, discount_amount, tax_percent, invoice_date, due_date,
		                      notes, terms_and_conditions)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING `+invoiceColumns,
		garageID, inv.InvoiceNumber, inv.JobCardID, inv.CustomerID, inv.VehicleID,
		inv.KmReading, inv.DiscountAmount, inv.TaxPercent, inv.InvoiceDate, inv.DueDate,
		inv.Notes, inv.TermsAndConditions))
	if err != nil {
		return models.Invoice{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "invoice_items", created.ID, inv.Items); err != nil {
		return models.Invoice{}, err
	}
	created.Items = inv.Items
	created.Payments = []models.Payment{}
	return created, tx.Commit(ctx)
}

// invoice_number and created_at are immutable (convention 9).
func (s *Store) UpdateInvoice(ctx context.Context, garageID string, inv models.Invoice) (models.Invoice, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return models.Invoice{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	updated, err := scanInvoice(tx.QueryRow(ctx,
		`UPDATE invoices SET job_card_id=$3, customer_id=$4, vehicle_id=$5, km_reading=$6,
		                        discount_amount=$7, tax_percent=$8, invoice_date=$9,
		                        due_date=$10, cancelled_at=$11, notes=$12, terms_and_conditions=$13
		 WHERE garage_id = $1 AND id = $2 RETURNING `+invoiceColumns,
		garageID, inv.ID, inv.JobCardID, inv.CustomerID, inv.VehicleID, inv.KmReading,
		inv.DiscountAmount, inv.TaxPercent, inv.InvoiceDate, inv.DueDate, inv.CancelledAt,
		inv.Notes, inv.TermsAndConditions))
	if err != nil {
		return models.Invoice{}, mapPGError(err)
	}
	if err := replaceItemsOn(ctx, tx, "invoice_items", updated.ID, inv.Items); err != nil {
		return models.Invoice{}, err
	}
	updated.Items = inv.Items
	if updated.Payments, err = s.PaymentsByInvoice(ctx, updated.ID); err != nil {
		return models.Invoice{}, err
	}
	return updated, tx.Commit(ctx)
}

// MarkInvoiceCancelled sets cancelled_at = now(); the WHERE clause refuses
// already-cancelled rows (the handler checks payments first).
func (s *Store) MarkInvoiceCancelled(ctx context.Context, garageID, invoiceID string) (models.Invoice, error) {
	inv, err := scanInvoice(s.Pool.QueryRow(ctx,
		`UPDATE invoices SET cancelled_at = now()
		 WHERE garage_id = $1 AND id = $2 AND cancelled_at IS NULL
		 RETURNING `+invoiceColumns, garageID, invoiceID))
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Items, err = s.ItemsOfParent(ctx, "invoice_items", inv.ID)
	if err != nil {
		return models.Invoice{}, err
	}
	inv.Payments, err = s.PaymentsByInvoice(ctx, inv.ID)
	return inv, err
}
```

- [ ] **Step 4: Write `backend/internal/api/invoices.go`**

```go
package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func validateInvoice(inv models.Invoice) (string, int) {
	if inv.InvoiceNumber == "" {
		return "invoiceNumber is required", 400
	}
	if inv.DiscountAmount < 0 {
		return "discountAmount cannot be negative", 400
	}
	return "", 0
}

// normalizeInvoice fills the Dart constructor defaults: invoiceDate now and
// a non-nil items slice.
func normalizeInvoice(inv *models.Invoice) {
	if inv.InvoiceDate.IsZero() {
		inv.InvoiceDate = time.Now().UTC()
	}
	if inv.Items == nil {
		inv.Items = []models.MaintenanceItem{}
	}
}

func (s *Server) checkInvoiceRefs(ctx context.Context, garageID string, inv models.Invoice) refCheck {
	if rc := s.checkRefs(ctx, garageID, inv.CustomerID, inv.VehicleID, nil); rc.status != 0 {
		return rc
	}
	if inv.JobCardID != nil && *inv.JobCardID != "" {
		if _, err := uuid.Parse(*inv.JobCardID); err != nil {
			return refCheck{400, "invalid_request", "invalid jobCardId"}
		}
		ok, err := s.Store.JobCardBelongs(ctx, garageID, *inv.JobCardID)
		if err != nil {
			return refCheck{500, "internal", "could not check job card"}
		}
		if !ok {
			return refCheck{404, "not_found", "job card not found"}
		}
	}
	return refCheck{}
}

func (s *Server) listInvoices(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListInvoices(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list invoices")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createInvoice(w http.ResponseWriter, r *http.Request) {
	var inv models.Invoice
	if !httputil.Decode(w, r, &inv) {
		return
	}
	normalizeInvoice(&inv)
	if msg, status := validateInvoice(inv); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkInvoiceRefs(r.Context(), garageID, inv); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range inv.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	created, err := s.Store.CreateInvoice(r.Context(), garageID, inv)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "invoice number already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create invoice")
		return
	}
	httputil.JSON(w, 201, created)
}

// cancelGuard enforces spec §8 on both cancel paths: not already cancelled
// and totalPaid ≤ 0 (mirroring cancelInvoice's `totalPaidAmount > 0` throw).
func (s *Server) cancelGuard(ctx context.Context, garageID, invoiceID string) refCheck {
	m, err := s.Store.InvoiceMoneyFor(ctx, garageID, invoiceID)
	if err != nil {
		return refCheck{500, "internal", "could not load invoice money"}
	}
	if m.CancelledAt != nil {
		return refCheck{422, "unprocessable", "invoice is already cancelled"}
	}
	if m.Paid > 0 {
		return refCheck{422, "unprocessable", "invoice has payments and cannot be cancelled"}
	}
	return refCheck{}
}

func (s *Server) updateInvoice(w http.ResponseWriter, r *http.Request) {
	var inv models.Invoice
	if !httputil.Decode(w, r, &inv) {
		return
	}
	inv.ID = chi.URLParam(r, "invoiceId")
	if _, err := parseID(inv.ID); err != nil {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	normalizeInvoice(&inv)
	if msg, status := validateInvoice(inv); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	garageID := auth.GarageID(r.Context())
	if rc := s.checkInvoiceRefs(r.Context(), garageID, inv); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	for _, it := range inv.Items {
		if rc := s.checkItemStaffRef(r.Context(), garageID, it); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	// A PUT that sets cancelledAt is the provider's cancelInvoice path and
	// must pass the same guard as the cancel endpoint.
	if inv.CancelledAt != nil {
		if rc := s.cancelGuard(r.Context(), garageID, inv.ID); rc.status != 0 {
			httputil.Error(w, rc.status, rc.code, rc.message)
			return
		}
	}
	updated, err := s.Store.UpdateInvoice(r.Context(), garageID, inv)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update invoice")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) cancelInvoice(w http.ResponseWriter, r *http.Request) {
	invoiceID := chi.URLParam(r, "invoiceId")
	if _, err := parseID(invoiceID); err != nil {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	garageID := auth.GarageID(r.Context())
	if _, err := s.Store.InvoiceByID(r.Context(), garageID, invoiceID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "invoice not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not load invoice")
		return
	}
	if rc := s.cancelGuard(r.Context(), garageID, invoiceID); rc.status != 0 {
		httputil.Error(w, rc.status, rc.code, rc.message)
		return
	}
	cancelled, err := s.Store.MarkInvoiceCancelled(r.Context(), garageID, invoiceID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not cancel invoice")
		return
	}
	httputil.JSON(w, 200, cancelled)
}
```

- [ ] **Step 5: Wire routes in `backend/internal/api/router.go`**

After the quotations group:

```go
			r.Route("/invoices", func(r chi.Router) {
				r.Use(auth.RequirePermission("invoices.manage"))
				r.Get("/", s.listInvoices)
				r.Post("/", s.createInvoice)
				r.Put("/{invoiceId}", s.updateInvoice)
				r.Post("/{invoiceId}/cancel", s.cancelInvoice)
			})
```

(Payments get their own top-level Route block in Task 10 because their permission key differs.)

- [ ] **Step 6: Write `backend/internal/itest/invoices_test.go`**

```go
package itest

import (
	"testing"
	"time"

	"garage-backend/internal/models"
)

func invoiceBody(number, customerID, vehicleID string) map[string]any {
	return map[string]any{
		"invoiceNumber": number, "customerId": customerID, "vehicleId": vehicleID,
		"kmReading": 32000, "discountAmount": 100.0, "taxPercent": 18.0,
		"items": []map[string]any{
			{"name": "Brake pads", "category": "sparePart", "unitPrice": 1800.0, "quantity": 1.0},
		},
	}
}

func createInvoice(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Invoice) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/invoices", token, garageID, body)
	var inv models.Invoice
	if status == 201 {
		mustUnmarshal(t, data, &inv)
	}
	return status, data, inv
}

func TestInvoiceCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "i1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("ICust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	status, data, inv := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-1001", customer.ID, vehicle.ID))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if len(inv.Items) != 1 || inv.Items[0].ID == "" || inv.Payments == nil || len(inv.Payments) != 0 {
		t.Fatalf("create embeds: %+v", inv)
	}

	// PUT replaces items; cancelledAt omitted stays nil.
	inv.DiscountAmount = 200
	inv.Items = append(inv.Items, models.MaintenanceItem{
		Name: "Labour", Category: "labour", UnitPrice: 500, Quantity: 1, Unit: "Job", IsLabour: true})
	status, data = doJSON(t, "PUT", "/api/invoices/"+inv.ID, owner.AccessToken, garageID, inv)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Invoice
	mustUnmarshal(t, data, &updated)
	if updated.DiscountAmount != 200 || len(updated.Items) != 2 || len(updated.Payments) != 0 {
		t.Fatalf("update lost data: %+v", updated)
	}

	// List is newest first.
	_, _, _ = createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-1002", customer.ID, vehicle.ID))
	status, data = doJSON(t, "GET", "/api/invoices", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Invoice `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].InvoiceNumber != "INV-1002" {
		t.Fatalf("list order: %+v", list.Items)
	}
}

func TestInvoiceCancelRules(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "i2")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("CancelCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)

	// Unpaid invoice: cancel endpoint works; second cancel is 422.
	_, _, unpaid := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-2001", customer.ID, vehicle.ID))
	status, data := doJSON(t, "POST", "/api/invoices/"+unpaid.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("cancel: status %d body %s", status, data)
	}
	var cancelled models.Invoice
	mustUnmarshal(t, data, &cancelled)
	if cancelled.CancelledAt == nil {
		t.Fatalf("cancel must stamp cancelledAt: %+v", cancelled)
	}
	status, data = doJSON(t, "POST", "/api/invoices/"+unpaid.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 422 {
		t.Fatalf("double cancel: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" || message != "invoice is already cancelled" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Paid invoice blocks cancel via BOTH paths.
	_, _, paid := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-2002", customer.ID, vehicle.ID))
	seedPayment(t, paid.ID, 500)
	status, data = doJSON(t, "POST", "/api/invoices/"+paid.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 422 {
		t.Fatalf("paid cancel: status %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" ||
		message != "invoice has payments and cannot be cancelled" {
		t.Fatalf("error = %s / %s", code, message)
	}
	// PUT with cancelledAt set is the provider's cancel path — same guard.
	paid.CancelledAt = &time.Time{}
	status, data = doJSON(t, "PUT", "/api/invoices/"+paid.ID, owner.AccessToken, garageID, paid)
	if status != 422 {
		t.Fatalf("PUT cancel on paid: status %d body %s", status, data)
	}
}

func TestInvoiceValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "i3a")
	b := registerOwner(t, "i3b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID
	_, _, aCustomer := createCustomer(t, a.AccessToken, aGarage, customerBody("AI"))
	aVehicle := createVehicleFor(t, a.AccessToken, aGarage, aCustomer.ID)
	_, _, aJob := createJobCard(t, a.AccessToken, aGarage,
		jobCardBody("JC-I1", aCustomer.ID, aVehicle.ID))

	// Empty number → 400.
	body := invoiceBody("", aCustomer.ID, aVehicle.ID)
	status, _ := createInvoice(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("empty number: %d", status)
	}
	// Malformed jobCardId → 400.
	body = invoiceBody("INV-3001", aCustomer.ID, aVehicle.ID)
	body["jobCardId"] = "nope"
	status, _ = createInvoice(t, a.AccessToken, aGarage, body)
	if status != 400 {
		t.Fatalf("malformed jobCardId: %d", status)
	}
	// Another garage's job card → 404.
	body = invoiceBody("INV-3002", aCustomer.ID, aVehicle.ID)
	body["jobCardId"] = "11111111-1111-1111-1111-111111111111"
	status, _ = createInvoice(t, a.AccessToken, aGarage, body)
	if status != 404 {
		t.Fatalf("unknown jobCardId: %d", status)
	}
	// Valid jobCardId links and returns.
	body = invoiceBody("INV-3003", aCustomer.ID, aVehicle.ID)
	body["jobCardId"] = aJob.ID
	status, _, linked := createInvoice(t, a.AccessToken, aGarage, body)
	if status != 201 || linked.JobCardID == nil || *linked.JobCardID != aJob.ID {
		t.Fatalf("linked invoice: status %d jobCardId %v", status, linked.JobCardID)
	}

	// Tenancy: B sees nothing of A's and cannot PUT A's invoice.
	_, _, mine := createInvoice(t, a.AccessToken, aGarage, invoiceBody("INV-3004", aCustomer.ID, aVehicle.ID))
	status, data = doJSON(t, "GET", "/api/invoices", b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("B list: status %d", status)
	}
	var list struct {
		Items []models.Invoice `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("B sees A's invoices: %+v", list.Items)
	}
	mine.DiscountAmount = 1
	status, _ = doJSON(t, "PUT", "/api/invoices/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's invoice: %d", status)
	}
}
```

- [ ] **Step 7: Add `seedPayment` to `backend/internal/itest/harness_test.go`**

```go
// seedPayment inserts a payment row directly (used to set up paid invoices
// before the payments endpoint exists in test order).
func seedPayment(t *testing.T, invoiceID string, amount float64) {
	t.Helper()
	if _, err := pool.Exec(ctx,
		`INSERT INTO payments (invoice_id, amount, mode, payment_date)
		 VALUES ($1,$2,'cash',now())`, invoiceID, amount); err != nil {
		t.Fatalf("seed payment: %v", err)
	}
}
```

- [ ] **Step 8: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestInvoice -v` (3 tests PASS), `go test -count=1 ./...` (all PASS).

- [ ] **Step 9: Commit**

From repo root:
```bash
git add backend/internal/models/payment.go backend/internal/models/invoice.go backend/internal/store/invoices.go backend/internal/api/invoices.go backend/internal/api/router.go backend/internal/itest/invoices_test.go backend/internal/itest/harness_test.go
git commit -m "feat: add invoices domain with cancel rules and payments embed"
```

---

### Task 10: Payments endpoint (append-only, bound-checked)

**Files:**
- Create: `backend/internal/api/payments.go`
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/payments_test.go`

The payment store code (`CreatePayment`, `paymentColumns`, `scanPayment`) already landed with Task 9's `store/invoices.go`.

- [ ] **Step 1: Write `backend/internal/api/payments.go`**

```go
package api

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

type recordPaymentRequest struct {
	Amount         float64 `json:"amount"`
	Mode           string  `json:"mode"`
	CustomerID     *string `json:"customerId"`
	TransactionRef *string `json:"transactionRef"`
	Notes          *string `json:"notes"`
	ReceivedBy     *string `json:"receivedBy"`
}

// recordPayment mirrors the provider's addPayment rule (spec §8): amount in
// (0, balanceDue + 0.01] on a non-cancelled invoice. Payments are
// append-only — there is no update or delete.
func (s *Server) recordPayment(w http.ResponseWriter, r *http.Request) {
	invoiceID := chi.URLParam(r, "invoiceId")
	if _, err := parseID(invoiceID); err != nil {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	var req recordPaymentRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Amount <= 0 {
		httputil.Error(w, 422, "unprocessable", "payment amount must be positive")
		return
	}
	if !models.ValidValue(req.Mode, models.PaymentModes...) {
		httputil.Error(w, 400, "invalid_request", "invalid mode \""+req.Mode+"\"")
		return
	}
	garageID := auth.GarageID(r.Context())
	if req.CustomerID != nil && *req.CustomerID != "" {
		if _, err := uuid.Parse(*req.CustomerID); err != nil {
			httputil.Error(w, 400, "invalid_request", "invalid customerId")
			return
		}
		ok, err := s.Store.CustomerBelongs(r.Context(), garageID, *req.CustomerID)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not check customer")
			return
		}
		if !ok {
			httputil.Error(w, 404, "not_found", "customer not found")
			return
		}
	} else {
		req.CustomerID = nil
	}
	m, err := s.Store.InvoiceMoneyFor(r.Context(), garageID, invoiceID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invoice not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load invoice")
		return
	}
	if m.CancelledAt != nil {
		httputil.Error(w, 422, "unprocessable", "invoice is cancelled")
		return
	}
	if req.Amount > m.Due()+0.01 {
		httputil.Error(w, 422, "unprocessable", "payment exceeds balance due")
		return
	}
	p, err := s.Store.CreatePayment(r.Context(), invoiceID, models.Payment{
		CustomerID:     req.CustomerID,
		Amount:         req.Amount,
		Mode:           req.Mode,
		TransactionRef: req.TransactionRef,
		Notes:          req.Notes,
		ReceivedBy:     req.ReceivedBy,
	})
	if err != nil {
		httputil.Error(w, 500, "internal", "could not record payment")
		return
	}
	httputil.JSON(w, 201, p)
}
```

- [ ] **Step 2: Wire routes in `backend/internal/api/router.go`**

This is its OWN top-level Route block (NOT nested inside the invoices group) because `payments.record` is a different permission than `invoices.manage` — nesting would stack both checks. Add after the invoices group:

```go
			r.Route("/invoices/{invoiceId}/payments", func(r chi.Router) {
				r.Use(auth.RequirePermission("payments.record"))
				r.Post("/", s.recordPayment)
			})
```

- [ ] **Step 3: Write `backend/internal/itest/payments_test.go`**

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestRecordPayment(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "pay1")
	garageID := owner.Memberships[0].GarageID
	_, _, customer := createCustomer(t, owner.AccessToken, garageID, customerBody("PayCust"))
	vehicle := createVehicleFor(t, owner.AccessToken, garageID, customer.ID)
	// invoiceBody: item 1800, discount 100 → taxable 1700, +18% → grand 2006.
	_, _, inv := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-P1", customer.ID, vehicle.ID))
	pay := func(amount any, mode string) (int, []byte) {
		return doJSON(t, "POST", "/api/invoices/"+inv.ID+"/payments", owner.AccessToken, garageID,
			map[string]any{"amount": amount, "mode": mode})
	}

	status, _ := pay(0, "cash")
	if status != 422 {
		t.Fatalf("zero amount: %d", status)
	}
	status, data := pay(100, "bitcoin")
	if status != 400 {
		t.Fatalf("bad mode: %d", status)
	}
	if code, message := decodeError(t, data); code != "invalid_request" {
		t.Fatalf("code = %s / %s", code, message)
	}
	status, data = pay(2007, "cash")
	if status != 422 {
		t.Fatalf("overpay: %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" || message != "payment exceeds balance due" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Exactly balanceDue + 0.01 is accepted (mirrors the Dart bound).
	status, data = pay(2006.01, "upi")
	if status != 201 {
		t.Fatalf("full pay: status %d body %s", status, data)
	}
	var p models.Payment
	mustUnmarshal(t, data, &p)
	if p.ID == "" || p.InvoiceID != inv.ID || p.Mode != "upi" || p.PaymentDate.IsZero() {
		t.Fatalf("payment = %+v", p)
	}

	// Balance is now zero → another rupee is rejected.
	status, _ = pay(1, "cash")
	if status != 422 {
		t.Fatalf("post-settlement payment: %d", status)
	}

	// Cancelled invoices take no payments.
	_, _, inv2 := createInvoice(t, owner.AccessToken, garageID, invoiceBody("INV-P2", customer.ID, vehicle.ID))
	status, _ = doJSON(t, "POST", "/api/invoices/"+inv2.ID+"/cancel", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("cancel inv2: %d", status)
	}
	status, data = doJSON(t, "POST", "/api/invoices/"+inv2.ID+"/payments", owner.AccessToken, garageID,
		map[string]any{"amount": 10, "mode": "cash"})
	if status != 422 {
		t.Fatalf("payment on cancelled: %d body %s", status, data)
	}
	if code, message := decodeError(t, data); code != "unprocessable" || message != "invoice is cancelled" {
		t.Fatalf("error = %s / %s", code, message)
	}

	// Unknown invoice → 404.
	status, _ = doJSON(t, "POST", "/api/invoices/11111111-1111-1111-1111-111111111111/payments",
		owner.AccessToken, garageID, map[string]any{"amount": 5, "mode": "cash"})
	if status != 404 {
		t.Fatalf("unknown invoice: %d", status)
	}
}
```

- [ ] **Step 4: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestRecordPayment -v` (PASS), `go test -count=1 ./...` (all PASS).

- [ ] **Step 5: Commit**

From repo root:
```bash
git add backend/internal/api/payments.go backend/internal/api/router.go backend/internal/itest/payments_test.go
git commit -m "feat: add bound-checked append-only payments endpoint"
```

---

### Task 11: Expenses domain

**Files:**
- Create: `backend/internal/models/expense.go`
- Create: `backend/internal/store/expenses.go`
- Create: `backend/internal/api/expenses.go`
- Modify: `backend/internal/api/router.go`
- Test: `backend/internal/itest/expenses_test.go`

- [ ] **Step 1: Write `backend/internal/models/expense.go`**

```go
package models

import "time"

// Expense mirrors GarageExpense in lib/models/expense.dart. expenseDate is
// day-grained (spec §7): a plain YYYY-MM-DD string, not an instant.
type Expense struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Category    string    `json:"category"`
	Amount      float64   `json:"amount"`
	ExpenseDate string    `json:"expenseDate"`
	PaymentMode string    `json:"paymentMode"`
	VendorName  *string   `json:"vendorName"`
	Notes       *string   `json:"notes"`
	ReceiptPath *string   `json:"receiptPath"`
	CreatedAt   time.Time `json:"createdAt"`
}
```

- [ ] **Step 2: Write `backend/internal/store/expenses.go`**

```go
package store

import (
	"context"

	"garage-backend/internal/models"
)

const expenseColumns = `id, title, category, amount, expense_date, payment_mode,
	vendor_name, notes, receipt_path, created_at`

func scanExpense(row scanner) (models.Expense, error) {
	var e models.Expense
	err := row.Scan(&e.ID, &e.Title, &e.Category, &e.Amount, &e.ExpenseDate,
		&e.PaymentMode, &e.VendorName, &e.Notes, &e.ReceiptPath, &e.CreatedAt)
	return e, mapPGError(err)
}

func (s *Store) ListExpenses(ctx context.Context, garageID string) ([]models.Expense, error) {
	rows, err := s.Pool.Query(ctx,
		`SELECT `+expenseColumns+` FROM expenses WHERE garage_id = $1 ORDER BY created_at DESC, id`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []models.Expense{}
	for rows.Next() {
		e, err := scanExpense(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, e)
	}
	return items, rows.Err()
}

func (s *Store) CreateExpense(ctx context.Context, garageID string, e models.Expense) (models.Expense, error) {
	return scanExpense(s.Pool.QueryRow(ctx,
		`INSERT INTO expenses (garage_id, title, category, amount, expense_date, payment_mode,
		                      vendor_name, notes, receipt_path)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING `+expenseColumns,
		garageID, e.Title, e.Category, e.Amount, e.ExpenseDate, e.PaymentMode,
		e.VendorName, e.Notes, e.ReceiptPath))
}

func (s *Store) UpdateExpense(ctx context.Context, garageID string, e models.Expense) (models.Expense, error) {
	return scanExpense(s.Pool.QueryRow(ctx,
		`UPDATE expenses SET title=$3, category=$4, amount=$5, expense_date=$6, payment_mode=$7,
		                        vendor_name=$8, notes=$9, receipt_path=$10
		 WHERE garage_id = $1 AND id = $2 RETURNING `+expenseColumns,
		garageID, e.ID, e.Title, e.Category, e.Amount, e.ExpenseDate, e.PaymentMode,
		e.VendorName, e.Notes, e.ReceiptPath))
}

func (s *Store) DeleteExpense(ctx context.Context, garageID, expenseID string) error {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM expenses WHERE garage_id = $1 AND id = $2`, garageID, expenseID)
	if err != nil {
		return mapPGError(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
```

- [ ] **Step 3: Write `backend/internal/api/expenses.go`**

```go
package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

// validateExpense takes a pointer because it fills the constructor default
// paymentMode 'cash' when the client omits it.
func validateExpense(e *models.Expense) (string, int) {
	if e.Title == "" {
		return "title is required", 400
	}
	if e.Amount < 0 {
		return "amount cannot be negative", 400
	}
	if !models.ValidValue(e.Category, models.ExpenseCategories...) {
		return "invalid category \"" + e.Category + "\"", 400
	}
	if e.PaymentMode == "" {
		e.PaymentMode = "cash"
	}
	if !models.ValidValue(e.PaymentMode, models.PaymentModes...) {
		return "invalid paymentMode \"" + e.PaymentMode + "\"", 400
	}
	if _, err := time.Parse("2006-01-02", e.ExpenseDate); err != nil {
		return "expenseDate must be YYYY-MM-DD", 400
	}
	return "", 0
}

func (s *Server) listExpenses(w http.ResponseWriter, r *http.Request) {
	items, err := s.Store.ListExpenses(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list expenses")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": items})
}

func (s *Server) createExpense(w http.ResponseWriter, r *http.Request) {
	var e models.Expense
	if !httputil.Decode(w, r, &e) {
		return
	}
	if msg, status := validateExpense(&e); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	created, err := s.Store.CreateExpense(r.Context(), auth.GarageID(r.Context()), e)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create expense")
		return
	}
	httputil.JSON(w, 201, created)
}

func (s *Server) updateExpense(w http.ResponseWriter, r *http.Request) {
	var e models.Expense
	if !httputil.Decode(w, r, &e) {
		return
	}
	e.ID = chi.URLParam(r, "expenseId")
	if _, err := parseID(e.ID); err != nil {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if msg, status := validateExpense(&e); msg != "" {
		httputil.Error(w, status, "invalid_request", msg)
		return
	}
	updated, err := s.Store.UpdateExpense(r.Context(), auth.GarageID(r.Context()), e)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update expense")
		return
	}
	httputil.JSON(w, 200, updated)
}

func (s *Server) deleteExpense(w http.ResponseWriter, r *http.Request) {
	expenseID := chi.URLParam(r, "expenseId")
	if _, err := parseID(expenseID); err != nil {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	err := s.Store.DeleteExpense(r.Context(), auth.GarageID(r.Context()), expenseID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "expense not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not delete expense")
		return
	}
	w.WriteHeader(204)
}
```

- [ ] **Step 4: Wire routes in `backend/internal/api/router.go`**

After the payments Route block:

```go
			r.Route("/expenses", func(r chi.Router) {
				r.Use(auth.RequirePermission("expenses.manage"))
				r.Get("/", s.listExpenses)
				r.Post("/", s.createExpense)
				r.Put("/{expenseId}", s.updateExpense)
				r.Delete("/{expenseId}", s.deleteExpense)
			})
```

- [ ] **Step 5: Write `backend/internal/itest/expenses_test.go`**

```go
package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func expenseBody(title string) map[string]any {
	return map[string]any{
		"title": title, "category": "consumables", "amount": 350.5,
		"expenseDate": "2026-09-13", "paymentMode": "upi",
	}
}

func createExpense(t *testing.T, token, garageID string, body map[string]any) (int, []byte, models.Expense) {
	t.Helper()
	status, data := doJSON(t, "POST", "/api/expenses", token, garageID, body)
	var e models.Expense
	if status == 201 {
		mustUnmarshal(t, data, &e)
	}
	return status, data, e
}

func TestExpenseCRUDRoundTrip(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "e1")
	garageID := owner.Memberships[0].GarageID

	status, data, first := createExpense(t, owner.AccessToken, garageID, expenseBody("Engine flush"))
	if status != 201 {
		t.Fatalf("create: status %d body %s", status, data)
	}
	if first.ID == "" || first.Title != "Engine flush" || first.ExpenseDate != "2026-09-13" ||
		first.PaymentMode != "upi" || first.CreatedAt.IsZero() {
		t.Fatalf("expense = %+v", first)
	}

	_, _, _ = createExpense(t, owner.AccessToken, garageID, expenseBody("Shop rent"))
	status, data = doJSON(t, "GET", "/api/expenses", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list: status %d body %s", status, data)
	}
	var list struct {
		Items []models.Expense `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 2 || list.Items[0].Title != "Shop rent" {
		t.Fatalf("list must be newest first: %+v", list.Items)
	}

	first.Amount = 500
	vendor := "AutoCare Supplies"
	first.VendorName = &vendor
	status, data = doJSON(t, "PUT", "/api/expenses/"+first.ID, owner.AccessToken, garageID, first)
	if status != 200 {
		t.Fatalf("update: status %d body %s", status, data)
	}
	var updated models.Expense
	mustUnmarshal(t, data, &updated)
	if updated.Amount != 500 || updated.VendorName == nil || *updated.VendorName != "AutoCare Supplies" {
		t.Fatalf("update lost data: %+v", updated)
	}

	status, _ = doJSON(t, "DELETE", "/api/expenses/"+first.ID, owner.AccessToken, garageID, nil)
	if status != 204 {
		t.Fatalf("delete: %d", status)
	}
	status, data = doJSON(t, "GET", "/api/expenses", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("list after delete: status %d", status)
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 {
		t.Fatalf("after delete: %+v", list.Items)
	}
}
```

- [ ] **Step 6: Write the validation + tenancy test (append to `backend/internal/itest/expenses_test.go`)**

```go
func TestExpenseValidationAndTenancy(t *testing.T) {
	truncate(t)
	a := registerOwner(t, "e2a")
	b := registerOwner(t, "e2b")
	aGarage := a.Memberships[0].GarageID
	bGarage := b.Memberships[0].GarageID

	bad := expenseBody("Bad category")
	bad["category"] = "bribes"
	status, _ := createExpense(t, a.AccessToken, aGarage, bad)
	if status != 400 {
		t.Fatalf("bad category: %d", status)
	}
	bad = expenseBody("Bad mode")
	bad["paymentMode"] = "barter"
	status, _ = createExpense(t, a.AccessToken, aGarage, bad)
	if status != 400 {
		t.Fatalf("bad paymentMode: %d", status)
	}
	bad = expenseBody("Bad date")
	bad["expenseDate"] = "13/09/2026"
	status, _ = createExpense(t, a.AccessToken, aGarage, bad)
	if status != 400 {
		t.Fatalf("bad expenseDate: %d", status)
	}
	// paymentMode omitted → defaults to cash.
	omitted := expenseBody("Default mode")
	delete(omitted, "paymentMode")
	status, _, e := createExpense(t, a.AccessToken, aGarage, omitted)
	if status != 201 || e.PaymentMode != "cash" {
		t.Fatalf("default mode: status %d expense %+v", status, e)
	}

	_, _, mine := createExpense(t, a.AccessToken, aGarage, expenseBody("Mine"))
	var list struct {
		Items []models.Expense `json:"items"`
	}
	status, data := doJSON(t, "GET", "/api/expenses", b.AccessToken, bGarage, nil)
	if status != 200 {
		t.Fatalf("B list: status %d", status)
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("B sees A's expenses: %+v", list.Items)
	}
	status, _ = doJSON(t, "PUT", "/api/expenses/"+mine.ID, b.AccessToken, bGarage, mine)
	if status != 404 {
		t.Fatalf("B update A's expense: %d", status)
	}
	status, _ = doJSON(t, "DELETE", "/api/expenses/"+mine.ID, b.AccessToken, bGarage, nil)
	if status != 404 {
		t.Fatalf("B delete A's expense: %d", status)
	}
}
```

- [ ] **Step 7: Run gates**

From `backend/`, separate calls: `gofmt -l .` (empty), `go vet ./...`, `go test -count=1 ./internal/itest/ -run TestExpense -v` (2 tests PASS), `go test -count=1 ./...` (all PASS).

- [ ] **Step 8: Commit**

From repo root:
```bash
git add backend/internal/models/expense.go backend/internal/store/expenses.go backend/internal/api/expenses.go backend/internal/api/router.go backend/internal/itest/expenses_test.go
git commit -m "feat: add expenses domain"
```

---

### Task 12: README domain docs + final verification

**Files:**
- Modify: `backend/README.md`
- No new code.

- [ ] **Step 1: Append the domain routes to the endpoints table in `backend/README.md`**

Directly after the `PATCH /api/garages/{garageId}/settings` table row, add:

```markdown
| `GET`/`POST /api/customers` · `PUT`/`DELETE /api/customers/{customerId}` | bearer + garage + `customers.manage` | newest-first lists; delete blocked by dues or invoice/job-card history |
| `GET`/`POST /api/vehicles` · `PUT`/`DELETE /api/vehicles/{vehicleId}` | bearer + garage + `vehicles.manage` | delete blocked once documents reference the vehicle |
| `GET`/`POST /api/staff` · `PUT`/`DELETE /api/staff/{staffId}` | bearer + garage + `staff.manage` | workshop roster — distinct from members (app logins) |
| `GET`/`POST /api/attendance` | bearer + garage + `attendance.manage` | POST upserts by (staff, day) — idempotent |
| `GET`/`POST /api/salary-advances` · `POST /api/salary-advances/settle` | bearer + garage + `advances.manage` | settle `{staff_id, month, year}` marks and returns the settled advances |
| `GET`/`POST /api/jobcards` · `PUT /api/jobcards/{jobCardId}` | bearer + garage + `jobcards.manage` | responses embed items; PUT replaces items wholesale |
| `POST /api/jobcards/{jobCardId}/status` | bearer + garage + `jobcards.manage` | delivered stamps completedAt, cancelled keeps it, others clear it |
| `POST /api/jobcards/{jobCardId}/items` · `DELETE /api/jobcards/{jobCardId}/items/{itemId}` | bearer + garage + `jobcards.manage` | item POST upserts by item id |
| `GET`/`POST /api/quotations` · `PUT /api/quotations/{quotationId}` | bearer + garage + `quotations.manage` | responses embed items |
| `POST /api/quotations/{quotationId}/status` | bearer + garage + `quotations.manage` | `converted` allowed only from `approved` (422) |
| `GET`/`POST /api/invoices` · `PUT /api/invoices/{invoiceId}` | bearer + garage + `invoices.manage` | embeds items + payments; number immutable |
| `POST /api/invoices/{invoiceId}/cancel` | bearer + garage + `invoices.manage` | only when unpaid and not already cancelled |
| `POST /api/invoices/{invoiceId}/payments` | bearer + garage + `payments.record` | append-only; amount in (0, balanceDue + 0.01] |
| `GET`/`POST /api/expenses` · `PUT`/`DELETE /api/expenses/{expenseId}` | bearer + garage + `expenses.manage` | expenseDate is a `YYYY-MM-DD` string |
| `GET /api/catalog` | bearer + garage (any member) | read-only; ships empty (CRUD out of scope) |
```

- [ ] **Step 2: Add a "Domain semantics" section to `backend/README.md`**

Insert before `## Phase status`:

```markdown
## Domain semantics

Business rules mirror the Flutter provider (`lib/providers/garage_provider.dart`)
and mock repository so the app's behavior is unchanged when it talks to the
server:

- **Document numbers** (`jobCardNumber`, `quotationNumber`, `invoiceNumber`)
  are client-generated and unique per garage (`409 conflict` on collision);
  they are immutable on PUT.
- **Item children** (job-card / quotation / invoice items) are replaced
  wholesale on PUT. The client may supply item ids: empty ids get server
  uuids, supplied ids are preserved, and the single-item POST upserts by id.
- **Job card status:** `delivered` stamps `completedAt` with now,
  `cancelled` keeps any previous value, every other status clears it
  (mirrors `MockGarageRepository.updateJobStatus`).
- **Invoice cancel** is reachable two ways — `POST /invoices/{id}/cancel`
  and a PUT whose payload sets `cancelledAt` (the provider's path) — and
  both enforce: not already cancelled, and total paid ≤ 0 (`422`).
- **Payments** are append-only with amount in `(0, balanceDue + 0.01]` on a
  non-cancelled invoice (`422` otherwise).
- **Quotation status** transitions freely except `converted`, which is only
  reachable from `approved` (`422`).
- **Customer delete** is blocked (`409`) while the customer has outstanding
  dues (any non-cancelled invoice with balance due > 0.01) OR any
  invoice/job-card history; **vehicle delete** is blocked once job cards or
  invoices reference the vehicle. Deleting a customer cascades their
  vehicles; deleting a staff member cascades attendance/advances and nulls
  their assignments.
- **Attendance** POST upserts per (staff, day) — resending a day replaces it.
- **Catalog** is read-only and ships empty per garage; it exists so the
  client can prefill maintenance items (out of scope to create from the API).
```

- [ ] **Step 3: Replace the "Phase status" section in `backend/README.md`**

```markdown
## Phase status

Phases 1 and 2 of 3 are complete: auth, members, settings, and all domain
CRUD (customers, vehicles, staff, attendance, advances, job cards,
quotations, invoices, payments, expenses, catalog) with integration tests.
Pending: Phase 3 connecting the Flutter app (`lib/data/api/` HTTP repository,
login gate, permission-gated UI).
```

- [ ] **Step 4: Run the full gate suite**

From `backend/`, separate calls: `gofmt -l .` (expect empty), `go vet ./...`, `go build ./...`, `go test -count=1 ./...` — all green with the complete 20+-test itest suite (~15–25 s).

- [ ] **Step 5: Commit**

From repo root:
```bash
git add backend/README.md
git commit -m "docs: document domain endpoints and business rules"
```

---

## Self-review record (writing-plans checklist)

- **Spec coverage:** §4 tables → Task 1 (14 tables incl. the 12 domain + auth from 0001); §5 routes → Tasks 3-11 (every route in the spec has a handler and test, including the payments block under its own permission); §8 business rules → customer dues guard (Task 3), cancel guard on both paths (Task 9), conversion guard (Task 8), payment bound (Task 10), attendance upsert (Task 6); §9 testing → every task runs the itest gate. Catalog GET-only (§5) → Task 7. Out-of-scope reminders at the top pin the negative space (no catalog CRUD, no document DELETE, no payment edits).
- **Placeholder scan:** every code step contains complete, compilable code. Drafting strays (unused `errCode`/`nowPtr` helpers, fake `mustData`/`mustListData`/`strPtr`/`createVehicleForB` references, an unused `jc2`, an inline vehicle closure, duplicated GET lines, an unused `bCustomer`) were found in self-review and fixed inline — no fixup notes remain in task text.
- **Type consistency:** store helpers (`scanner`, `mapPGError`, sentinels), api helpers (`parseID`, `refCheck`, `checkRefs`, `checkItemStaffRef`), itest helpers (`createCustomer`, `customerBody`, `createVehicleFor`, `createStaffSession`, `seedInvoice`, `jobCardBody`, `createJobCard`, `quotationBody`, `createQuotation`, `invoiceBody`, `createInvoice`, `seedPayment`, `expenseBody`, `createExpense`) are defined once and referenced with matching signatures. Models match the 0002 columns field-for-field; JSON tags match the Dart models.

