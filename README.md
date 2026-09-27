# NT Garage Manager

Workshop management for independent garages: customers and vehicles, job
cards, estimates, GST invoices and payments, expenses, staff attendance and
payroll. It is a Flutter app (Android, iOS, web, desktop) backed by a
multi-garage Go + PostgreSQL SaaS backend with trials, Razorpay billing,
team invites and per-member permissions.

## Layout

- `lib/` - Flutter app. `data/garage_repository.dart` is the persistence
  boundary, with an HTTP implementation (`data/api/`) and an in-memory mock
  (`data/mock/`). `providers/` hold app state and `screens/` the UI.
- `backend/` - Go API server. See [backend/README.md](backend/README.md) for
  setup, endpoints, auth and permissions.
- `docs/superpowers/` - design specs and implementation plans.

## Running the app

```bash
flutter pub get
flutter run
```

Which backend the app talks to:

| Build | Default backend |
|-------|-----------------|
| debug / profile | `http://localhost:8080` (`10.0.2.2:8080` on the Android emulator) |
| release | production (`ApiConfig.productionUrl`) |

Override with `--dart-define=API_BASE_URL=https://...`, or run fully offline
on seeded demo data with `--dart-define=USE_MOCK=true`.

To run the backend locally, see [backend/README.md](backend/README.md)
(`go run ./cmd/server` with `DATABASE_URL` and `JWT_SECRET` set).

## First-time garage setup

After registering, open **More → Garage Settings** and fill in the GSTIN,
address, phone and UPI ID. They are printed on every invoice and estimate,
and the UPI ID drives the payment QR. Parts and labour you bill often can be
saved to the price list from the **Custom Item** form ("Save to price list").

## Tests

```bash
flutter analyze
flutter test
cd backend && go test ./...
```

`test/app_layout_audit_test.dart` renders every screen at 320 and 390 px
widths, at 1.0x and 1.3x text, with and without the keyboard, and fails on
any overflow. It loads the SDK's bundled Roboto so text has real proportional
metrics. The backend integration tests boot an embedded Postgres, so they
need no external database.
