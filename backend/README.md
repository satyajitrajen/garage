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

## Phase status

Phase 1 of 3 is complete: auth, members, settings, migrations, tests.
Pending: Phase 2 domain CRUD (customers, vehicles, job cards, quotations,
invoices, payments, expenses, attendance, advances) and Phase 3 connecting
the Flutter app.
