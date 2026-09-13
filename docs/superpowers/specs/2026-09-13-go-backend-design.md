# Go Backend + App Connection Design

Date: 2026-09-13
Status: Approved (user chose: multi-garage with accounts, granular permission matrix, owner-created staff logins, accounts separate from Staff roster, PostgreSQL, LAN-now-cloud-later, online-only client; approach A: modular monolith with chi + pgx). User instruction "implement" pre-authorizes the spec → plan → execution pipeline.

## 1. Goal

Replace the Flutter app's in-memory mock data with a real Go backend: accounts with per-member granular permissions, per-garage data isolation in PostgreSQL, and a Flutter HTTP repository implementing the existing 38-method `GarageRepository` interface so the provider and UI keep working unchanged.

## 2. Environment facts

- Go 1.27 installed on the dev machine. Docker and psql are NOT installed.
- Integration tests therefore run against `github.com/fergusstrange/embedded-postgres` (self-downloading Postgres binaries, Windows-supported) so `go test ./...` needs zero external services.
- Running the server for real needs a one-time PostgreSQL install (EDB installer, Windows) and `DATABASE_URL`; documented in setup steps.

## 3. Architecture

New `backend/` directory in this repo (monorepo; the Flutter app is its only client):

```
backend/
  cmd/server/main.go        # config → pgxpool → router → graceful shutdown
  internal/
    config/config.go        # PORT, DATABASE_URL, JWT_SECRET (env vars)
    auth/                   # bcrypt, JWT issue/verify, refresh tokens, middleware
    api/                    # chi handlers, one file per domain + router.go
    store/                  # pgx queries, one file per domain
    models/                 # Go structs shared by store and api
  migrations/               # goose .sql files, numbered 0001...
  go.mod                    # module garage-backend
```

Stack: Go 1.22+, `chi` v5, `pgx` v5 (`pgxpool`), `golang-jwt/v5`, `golang.org/x/crypto/bcrypt`, `pressly/goose/v3`, `fergusstrange/embedded-postgres` (test-only). Request logging + panic-recovery middleware; CORS middleware (permissive for dev); graceful shutdown on SIGINT.

Portability: the same binary serves LAN (`garage-server.exe` on the workshop PC) and cloud (Docker later); only env vars differ. No OS-specific paths, no file storage (receipt_path stays a client-local string).

## 4. Data model (PostgreSQL)

Conventions: every table has `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, domain tables add `garage_id uuid NOT NULL REFERENCES garages(id)` and an index on it; timestamps `timestamptz`; dates (`joining_date`, `attendance date`, `expense_date`…) `date` where the Dart model is day-grained, `timestamptz` where it is instant-grained; money `numeric(12,2)`; enums stored as TEXT carrying the Dart enum **name** exactly (`inProgress`, `sparePart`, `halfDay`, `petrol`, `cash`, `headMechanic`, …) so JSON maps to Dart `.name`/`$enumName` with no translation tables; server validates enum values.

Auth/tenancy tables:
- `users` (email CITEXT UNIQUE, password_hash, name, created_at)
- `garages` (name, created_at)
- `memberships` (garage_id, user_id, role TEXT `owner|staff`, `permissions TEXT[] NOT NULL DEFAULT '{}'`, UNIQUE (garage_id, user_id))
- `refresh_tokens` (user_id, token_hash SHA-256, expires_at, created_at, revoked_at NULL)

Domain tables (columns pinned from the Dart models):
- `customers`: name, phone, whatsapp_number, email, address, gstin, notes
- `vehicles`: customer_id, registration_number, make, model, variant, year INT, fuel_type, current_km INT, color, chassis_number, engine_number, last_service_date
- `staff_members`: name, role (StaffRole name), phone, email, monthly_salary, joining_date DATE, is_active BOOL, address, emergency_contact
- `job_cards`: job_card_number, customer_id, vehicle_id, customer_complaints TEXT[], inspection_checklist JSONB, fuel_level TEXT, km_reading INT, assigned_staff_id NULL, status, promised_delivery_date TIMESTAMPTZ, completed_at NULL, estimated_cost_note NULL, supervisor_notes NULL
- `quotations`: quotation_number, customer_id, vehicle_id, km_reading INT, overall_discount, tax_percent, validity_days INT, status, notes, valid_until TIMESTAMPTZ
- `invoices`: invoice_number, job_card_id NULL, customer_id, vehicle_id, km_reading INT, discount_amount, tax_percent, invoice_date TIMESTAMPTZ, due_date NULL, cancelled_at NULL, notes NULL, terms_and_conditions NULL
- `payments`: invoice_id, customer_id NULL, amount, mode, transaction_ref NULL, payment_date TIMESTAMPTZ, notes NULL, received_by NULL
- `expenses`: title, category, amount, expense_date DATE, payment_mode, vendor_name NULL, notes NULL, receipt_path NULL
- `attendance_records`: staff_id, date DATE, status, notes NULL, UNIQUE (garage_id, staff_id, date)
- `salary_advances`: staff_id, amount, date DATE, reason NULL, is_deducted BOOL
- `catalog_items`: name, category, unit_price, unit, is_labour BOOL, part_number NULL, notes NULL
- `garage_settings`: garage_id PK — profile fields (name, tagline, address_line, city, phone, email, gstin, upi_id) + config fields (default_tax_percent, tax_percent_options JSONB, invoice_due_days INT, quotation_validity_options JSONB, working_days_per_month INT, promised_delivery_hours INT, invoice_notes, invoice_terms, default_received_by)
- Item children `job_card_items` / `quotation_items` / `invoice_items`: parent_id FK + MaintenanceItem columns (name, category, unit_price, quantity, unit, discount_percent, tax_percent, is_labour, part_number NULL, notes NULL, assigned_staff_id NULL)

IDs: server-generated everywhere. Document numbers (JC-1001, EST-1001, INV-…) stay client-generated (GarageProvider `_nextNumber` is unchanged); server enforces per-garage UNIQUE on the three number columns → 409 on collision.

## 5. API surface

JSON under `/api`. Auth: `Authorization: Bearer <access>`. Garage context: `X-Garage-Id` header on every domain/settings/member route. Error envelope: `{"error": {"code": "...", "message": "..."}}`.

Auth:
- `POST /api/auth/register` {name, email, password, garageName} → 201 {access_token, refresh_token, user, memberships[]} — creator becomes the garage's owner
- `POST /api/auth/login` {email, password} → {access_token, refresh_token, user, memberships[]}
- `POST /api/auth/refresh` {refresh_token} → new pair (old refresh revoked — rotation)
- `POST /api/auth/logout` {refresh_token} → 204
- `GET /api/me` → {user, memberships[]} (each membership: garage_id, garage_name, role, permissions)

Members (perm `staff.manage`; owner sees all):
- `GET /api/garages/{garageId}/members` → [{user_id, name, email, role, permissions, is_active}]
- `POST /api/garages/{garageId}/members` {name, email, password, permissions[]} → creates the user (if new) + staff membership (owner-created staff logins)
- `PATCH /api/garages/{garageId}/members/{userId}` {permissions?, password?, is_active?} — password reset is owner-only
- `DELETE /api/garages/{garageId}/members/{userId}` — owner-only, cannot delete the owner

Settings (perm `settings.manage`):
- `GET` / `PATCH /api/garages/{garageId}/settings` (PATCH partial-merges; GET creates defaults if absent)

Domain routes (list → `GET /api/<res>`, create → `POST /api/<res>`, update → `PUT /api/<res>/{id}`, delete → `DELETE /api/<res>/{id}`, all scoped by X-Garage-Id):
- `customers` — DELETE returns 409 `conflict` when the customer has invoices with balanceDue > 0 (outstanding dues), mirroring the mock's `deleteCustomer → false`
- `vehicles`, `expenses` (perm `expenses.manage`)
- `staff` (perm `staff.manage`)
- `jobcards` + `POST /jobcards/{id}/status` {status} + `POST /jobcards/{id}/items` (upsert by item id) + `DELETE /jobcards/{jobCardId}/items/{itemId}` (perm `jobcards.manage`)
- `quotations` + `POST /quotations/{id}/status` (perm `quotations.manage`); status transitions to `converted` only from `approved` (422 otherwise, mirroring the provider guard)
- `invoices` + `POST /invoices/{id}/cancel` (perm `invoices.manage`) + `POST /invoices/{id}/payments` (perm `payments.record`)
- `attendance` (POST upserts by staff+day; perm `attendance.manage`)
- `salary-advances` + `POST /salary-advances/settle` {staff_id, month, year} (perm `advances.manage`)
- `catalog` (GET only — any authenticated member of the garage; catalog CRUD is out of scope, matching the repository interface)

List responses are `{"items": [...]}`; single resources are the bare object. Invoice responses embed `items` and `payments`; quotation/job-card responses embed `items`.

Permission map: `invoices.manage` covers invoice create/update/cancel; `payments.record` covers payments; `expenses.manage` expenses; `staff.manage` staff + members; `advances.manage` advances/settle; `attendance.manage` attendance; `settings.manage` garage settings; `customers.manage`, `vehicles.manage`, `jobcards.manage`, `quotations.manage` the obvious ones.

## 6. Auth & permissions

- Passwords: bcrypt cost 12.
- Access token: JWT HS256, 15 min, claims `sub` (user id) + `exp`. Garage-agnostic — garage context comes from the `X-Garage-Id` header per request, so multi-garage users switch without re-login.
- Refresh token: 256-bit random, 30-day expiry, stored SHA-256-hashed, rotated on every refresh, revoked on logout.
- Middleware chain per route: `RequireAuth` (parse+verify JWT, load user) → `RequireGarage` (resolve X-Garage-Id, load membership; 403 if not a member) → `RequirePermission(key)` (owner role bypasses; staff checked against `permissions` array; 403 `forbidden` with the missing key in the message).
- Fixed permission list (11): `customers.manage`, `vehicles.manage`, `jobcards.manage`, `quotations.manage`, `invoices.manage`, `payments.record`, `expenses.manage`, `staff.manage`, `attendance.manage`, `advances.manage`, `settings.manage`.
- Default staff permission set (what `POST members` grants when `permissions` is omitted): everything EXCEPT `expenses.manage`, `staff.manage`, `advances.manage`, `settings.manage`. Server validates every submitted permission key against the list.

## 7. Flutter connection

Dependencies added: `http`, `flutter_secure_storage`, `shared_preferences`.

- **JSON**: hand-written `toJson`/`fromJson` on all 9 models + GarageProfile + AppConfig + AttendanceRecord + SalaryAdvance + Payment (no codegen, matching the codebase's hand-rolled style). Rules: enums by Dart name (`JobStatus.values.byName(json['status'])`), instant fields as RFC3339 UTC (`DateTime.parse` handles it; always `.toUtc()` on write), **day-grained dates (`joiningDate`, `expenseDate`, `SalaryAdvance.date`, `AttendanceRecord.date`) as `YYYY-MM-DD` strings** matching their DATE columns, money as JSON numbers (double), nullable fields omitted-or-null both accepted. Round-trip unit tests pin this.
- **ApiClient** (`lib/data/api/api_client.dart`): thin wrapper on package:http — base URL from prefs, attaches `Authorization` + `X-Garage-Id`, decodes the error envelope into `ApiException(code, message, statusCode)`, and on 401 performs one refresh-and-retry before failing. Methods: `get/post/put/delete` returning decoded JSON.
- **Auth session** (`lib/data/api/auth_session.dart`): tokens in `flutter_secure_storage`; server URL in `shared_preferences` (non-secret). Exposes `currentUser`, `memberships`, `permissions(garageId)`, `signOut()`.
- **App bootstrap**: `main.dart` becomes `LoginGate` → if no stored session, LoginScreen; else build `GarageProvider(HttpGarageRepository(apiClient, garageId))..load()`. Login screen: server URL (prefilled, persisted), email, password, sign-in + register (name, garage name, email, password) toggle. Logout lives in the More menu; revoke refresh, clear storage, return to LoginGate.
- **HttpGarageRepository** (`lib/data/api/http_garage_repository.dart`): implements all 38 `GarageRepository` methods 1:1 onto the §5 routes (fetch→GET list `.items`, create→POST returning the persisted object, update→PUT, delete→DELETE, status/items/payments/settle→the POST command routes, saveAttendance→POST upsert). Provider logic (numbering, derived getters, normalizeConfig) is untouched.
- **Permission gating**: after login the app keeps the active membership's permission set. More-menu items for Expenses, Staff Team, Salary/Attendance, and garage Settings/Profile-edit are hidden for members lacking the matching permission; the dashboard's Expenses figure and dues line hide without `expenses.manage` / `invoices.manage`. Any 403 that still arrives surfaces as a snackbar via the existing `showAppSnackBar` error pattern. Server responses are the source of truth; UI gating is convenience.
- **Offline**: online-only — connection failures produce a clear snackbar/screen message; the mock repository remains only for widget tests (tests keep `MockGarageRepository`).

## 8. Error handling

Server error codes: `invalid_request` 400 (malformed JSON, unknown enum, bad permission key), `unauthorized` 401, `forbidden` 403 (not a member / missing permission), `not_found` 404 (wrong id or other garage's id), `conflict` 409 (duplicate email, duplicate document number, customer-delete blocked by dues), `unprocessable` 422 (business rules), `internal` 500.

Business rules enforced server-side (mirroring provider logic):
- Payment amount must be in (0, balanceDue + 0.01] for a non-cancelled invoice.
- Invoice cancel only when totalPaidAmount ≤ 0 and not already cancelled; sets `cancelled_at`.
- Quotation `converted` only from `approved`.
- Customer delete blocked while any of the garage's invoices for that customer has balanceDue > 0.
- Attendance upsert is idempotent per (staff, day).

All store queries are parameterized; every query filters by the resolved garage_id from the middleware context (no client-supplied garage_id in bodies).

## 9. Testing

- **Go unit**: auth token issue/verify, permission middleware (owner bypass, staff allow/deny), error mapping — pure, fast.
- **Go integration**: per-domain handler+store tests against embedded-postgres (goose migrates up, truncate between tests): full CRUD round-trips per resource, tenancy isolation (garage B never sees garage A's rows), business rules above, refresh rotation/logout revocation.
- **Flutter**: JSON round-trip tests for every model; ApiClient refresh-on-401 test against a stub http server; existing 25 tests stay green (mock untouched).
- **Gates per phase**: `go vet ./...`, `go test ./...`, `flutter analyze`, `flutter test`.

## 10. Security notes

bcrypt(12); JWT_SECRET from env (server refuses to start without it); refresh tokens hashed at rest; tokens in `flutter_secure_storage` (never prefs); parameterized SQL only; garage scoping enforced in middleware+store, never from request bodies; CORS locked to the Flutter origins when deployed to cloud (permissive during LAN dev); no secrets logged.

## 11. Phasing (each phase = its own implementation plan, executed sequentially)

- **Phase 1 — backend foundation**: module scaffold, config, migrations 0001 (users/garages/memberships/refresh_tokens/garage_settings), auth endpoints, members endpoints, permission middleware, settings endpoints, Go tests.
- **Phase 2 — domain CRUD**: migrations for the 12 domain tables + stores + handlers + business rules + integration tests.
- **Phase 3 — Flutter connection**: model JSON, ApiClient, auth session, login/register screens, HttpGarageRepository, permission gating, logout, tests, final gates.

Out of scope (v1): file/receipt uploads, password-reset emails, audit logs, offline sync, catalog CRUD UI, staff self-registration.
