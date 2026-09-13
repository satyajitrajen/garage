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
- `internal/httputil/` — JSON response and error-envelope helpers
- `internal/itest/` — integration tests against embedded Postgres (no Docker needed)
- `migrations/` — goose SQL files, embedded into the binary and auto-run on boot

## Prerequisites

- Go 1.22+ (the module declares `go 1.26`; a 1.22+ toolchain downloads the
  required toolchain automatically).
- PostgreSQL — only for running the server, e.g. the EDB installer on Windows.
  Tests do not need it: they boot their own embedded Postgres.

## Local setup (one-time)

1. Install PostgreSQL (EDB installer on Windows).
2. Create a database: `createdb garage`
3. Set environment variables:

   | Variable       | Meaning                              | Example                                         |
   |----------------|--------------------------------------|-------------------------------------------------|
   | `PORT`         | HTTP port (default 8080)             | `8080`                                          |
   | `DATABASE_URL` | Postgres connection string (required)| `postgres://postgres:pw@localhost:5432/garage?sslmode=disable` |
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
port 54329, cached under `internal/.embedded-pg`, gitignored) — nothing
external needed. The first run downloads the Postgres binaries.

## Endpoints

| Method & path | Auth | Notes |
|---------------|------|-------|
| `GET /api/health` | none | liveness probe |
| `POST /api/auth/register` | none | `{name, email, password, garageName}` → creator becomes that garage's owner |
| `POST /api/auth/login` | none | → `{access_token, refresh_token, user, memberships[]}` |
| `POST /api/auth/refresh` | none | rotated token pair (old refresh revoked) |
| `POST /api/auth/logout` | none | revokes the refresh token |
| `GET /api/me` | bearer | current user + memberships |
| `GET`/`POST /api/garages/{garageId}/members` | bearer + garage + `staff.manage` | list / create staff |
| `PATCH`/`DELETE /api/garages/{garageId}/members/{userId}` | bearer + garage + `staff.manage` | edit permissions/active flag; password reset and member deletion are owner-only |
| `GET /api/garages/{garageId}/settings` | bearer + garage + `settings.manage` | lazily creates the defaults row |
| `PATCH /api/garages/{garageId}/settings` | bearer + garage + `settings.manage` | partial merge — see "Garage settings semantics" |
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

Garage-scoped routes need `Authorization: Bearer <access token>` and
`X-Garage-Id: <garage uuid>` headers; a mismatch between the header and the
`{garageId}` URL segment is a 400.

## Auth model

Access tokens are JWTs (HS256) and live 15 minutes. Refresh tokens live
30 days, are stored SHA-256-hashed, are single-use, and are rotated on
every refresh. Passwords are bcrypt-hashed (cost 12); minimum length 8.

## Permissions

Fixed 11 keys: `customers.manage vehicles.manage jobcards.manage quotations.manage
invoices.manage payments.record expenses.manage staff.manage attendance.manage
advances.manage settings.manage`. Owners bypass checks. New staff members get
everything except `expenses.manage`, `staff.manage`, `advances.manage`,
`settings.manage` unless an explicit list is provided.

## Error envelope

Every error response is `{"error":{"code":"...","message":"..."}}` with one of:

| Code                 | Status | Typical cause |
|----------------------|--------|---------------|
| `invalid_request`    | 400    | malformed JSON, missing fields, bad `X-Garage-Id`, out-of-range values |
| `unauthorized`       | 401    | missing/expired access token, bad credentials, revoked refresh token |
| `forbidden`          | 403    | missing permission; non-owner password reset or member deletion |
| `not_found`          | 404    | unknown route or resource |
| `method_not_allowed` | 405    | wrong verb for a known route |
| `conflict`           | 409    | duplicate email; user already a member of the garage |
| `unprocessable`      | 422    | modifying or removing the owner |
| `internal`           | 500    | unexpected server error |

## Garage settings semantics

- **Lazy defaults creation:** `GET .../settings` creates and returns the
  default row on first call (defaults mirror the Flutter app's
  `lib/data/app_config.dart`). No separate "create settings" step exists.
- **PATCH merge granularity:** each provided top-level field replaces that
  field; omitted fields keep their stored values. A provided `profile` object
  replaces the **whole** profile — clients must resend all 8 profile fields
  (`name`, `tagline`, `address_line`, `city`, `phone`, `email`, `gstin`,
  `upi_id`); there is no per-field profile merge. The slice fields
  `tax_percent_options` and `quotation_validity_options` are nil-checked:
  omitting keeps the stored list, sending `[]` clears it.
- **Owner-only by default:** both settings routes require `settings.manage`,
  which is excluded from the default staff permission set — so in practice
  only owners (or members explicitly granted `settings.manage`) can read or
  write settings.
- **Range validation:** `default_tax_percent` and each `tax_percent_options`
  entry must be 0–100; each `quotation_validity_options` entry 0–365;
  `invoice_due_days`, `working_days_per_month`, `promised_delivery_hours`
  0–1000.
- **Last write wins:** concurrent PATCHes each read-modify-write the row and
  the last commit wins; there is no field-level conflict detection.
- **Phase 3 Dart note:** Go emits integral floats without a decimal point
  (`default_tax_percent: 18`), so Dart `fromJson` must use
  `(x as num).toDouble()` — never `as double` — for tax and options fields.

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

## Phase status

Phases 1 and 2 of 3 are complete: auth, members, settings, and all domain
CRUD (customers, vehicles, staff, attendance, advances, job cards,
quotations, invoices, payments, expenses, catalog) with integration tests.
Pending: Phase 3 connecting the Flutter app (`lib/data/api/` HTTP repository,
login gate, permission-gated UI).
