# Nexory Garage Manager — Completion & Consistency Design

Date: 2026-09-12
Status: Approved

## Goals

1. Make the app API-replacement-ready via a repository pattern with mock data — zero hardcoded business content in UI.
2. Complete all unfinished features (edit flows, invoice cancel, quotation lifecycle, wizard promise, captured-but-unrendered data).
3. Fix theme consistency and dark-mode bugs via a semantic palette.
4. Replace stubbed external actions with real `url_launcher` / `share_plus` implementations.

## Non-goals

- PDF generation / printing (out of scope this round).
- Receipt photo attach (`image_picker` + storage) — the fake attach button is removed, not implemented.
- Local persistence/database — mock repo is in-memory; a real API is the persistence layer later.
- Auth / login.
- Restructuring dashboard tile navigation (pushing list screens stays).

## 1. Data layer

### 1.1 `GarageRepository` (abstract, async) — `lib/data/garage_repository.dart`

Methods (all `Future`):
- `Future<GarageProfile> fetchProfile()`
- `Future<AppConfig> fetchConfig()`
- Per entity (`Customer`, `Vehicle`, `Staff`, `JobCard`, `Quotation`, `Invoice`, `GarageExpense`, `AttendanceRecord`, `SalaryAdvance`, `MaintenanceItem`): `fetchXs()`, `createX(x)`, `updateX(x)`, `deleteX(id)` where the model supports it (matches today's provider surface: no update/delete for attendance or advances beyond mark/create; no delete for job cards/invoices/quotations/customers-with-dues — the dues rule stays in the mock repo and is re-validated by any future API).
- `Future<Payment> createPayment(Payment payment)` (payment is only created, attached to its invoice server-side in a real API).
- Mutations throw typed exceptions on invalid operations (e.g. overpayment, cancelled invoice), preserving today's provider validation semantics.

### 1.2 `GarageProfile` — `lib/data/garage_profile.dart`

`name`, `tagline`, `addressLine`, `city`, `phone`, `email`, `gstin`, `upiId`. Seeded in `MockDataService`: name `Nexory Garage & Body Shop`, GSTIN `27AAAAA0000A1Z5` (the more-menu value — resolves the current two-GSTIN inconsistency), city `Mumbai, MH`, tagline `Multi-Brand Auto Care`, plausible phone/email/UPI.

### 1.3 `AppConfig` — `lib/data/app_config.dart`

`defaultTaxPercent = 18.0`, `taxPercentOptions = [0, 12, 18, 28]`, `invoiceDueDays = 7`, `quotationValidityOptions = [7, 15, 30]`, `workingDaysPerMonth = 26`, `invoiceNotes`, `invoiceTerms`, `defaultReceivedBy = 'Cashier'`, `promisedDeliveryHours = 6` (used by provider when converting quotation → job card).

### 1.4 `MockGarageRepository` — `lib/data/mock/mock_garage_repository.dart`

In-memory lists seeded from `MockDataService` (kept as pure seed source). All mutations mutate in-memory state and return the resulting object. Simulated latency: none (synchronous completions). `deleteCustomer` keeps the outstanding-dues block (returns failure).

### 1.5 `GarageProvider` changes

- Constructor: `GarageProvider(this._repository)`.
- `load()` / `refresh()`: `Future.wait` all fetches + profile + config + catalog; sets `isLoading` / `loadError`; `refresh()` re-fetches collections (dashboard pull-to-refresh).
- Mutations become async: call repo, update cache, `notifyListeners()`, return the result. Screens `await` them.
- Derived analytics (todayCollection, totals, searches, salary summary, expense breakdown) stay as synchronous getters over the cache.
- Business-rule constants currently duplicated in provider (`taxPercent = 18.0` default param, due days 7, notes/terms, `'Cashier'`, 26 working days) read from `AppConfig`.
- `main.dart`: `GarageProvider(MockGarageRepository())`. Swapping to a real API = new repository class + one line here.

### 1.6 Hardcoded-content elimination (audit items)

- Garage name / GSTIN / city literals in invoice preview, quotation detail, dashboard, more menu (drawer is deleted) → `provider.profile`.
- GST dropdowns, 18% defaults, due-days 7, validity `[7,15,30]`, wizard `0.18` math, `Tax (18%)` label → `provider.config` (label derives percent from selected rate).
- Inspection checklist: single source = `JobCard.defaultChecklist` (model const); create screen uses it verbatim (divergent duplicate list deleted).
- Default promised-delivery `+6 hours` in `create_job_card_screen` → `config.promisedDeliveryHours`.
- `add_expense_screen` payment-mode chips → `PaymentMode.values`.
- `add_maintenance_screen` tab labels → `ItemCategory.values` display names (fixes `Labour & Services` mismatch).
- Raw `₹` string interpolation (~8 sites) → `CurrencyFormatter.format`.
- Invoices list `"Cash"` fabricated fallback → show real mode from invoice payments or "—".
- Wizard persisted note → `'Quick Service counter bill'` (brand removed; profile name not persisted into records).
- Dashboard `GARAGE STATUS: Operational & Peak Flow` → derived: `activeJobCards.isEmpty ? 'All clear — no vehicles in workshop' : '${activeJobCards.length} vehicle(s) in workshop'`.
- Invoice notes/terms defaults in provider → `config.invoiceNotes` / `config.invoiceTerms`.

## 2. Feature completion

### 2.1 Quotation lifecycle
- `create_quotation_screen` gains `Quotation? existing` param → save calls `updateQuotation`. Edit action visible on detail screen only when status is draft.
- Detail screen actions when draft: **Approve** (status → approved), **Decline** (status → rejected), **Edit**, **Convert to Job Card** (allowed only when approved; dialog to optionally pick mechanic; sets `converted`).
- Existing list tabs (Pending/Approved/Converted/Declined) now populate naturally. StatusBadge "DECLINED" label stays.

### 2.2 Invoice cancel
- Model: add `cancelledAt DateTime?` to `Invoice`; `status` getter: cancelled when set, else existing payment-derived computation. `balanceDue` returns 0 when cancelled.
- Cancel action on invoice preview (confirm dialog). Blocked when any payment exists (snackbar explains). Analytics already exclude cancelled.

### 2.3 Expense edit
- `add_expense_screen` gains `GarageExpense? existing` param; list rows get edit via detail/menu; save → `updateExpense`.

### 2.4 Job card edit + item management
- `create_job_card_screen` gains `JobCard? existing` param (edit while status not delivered/cancelled): complaints, KM, mechanic, promised date, checklist, supervisor notes, `estimatedCostNote` (field currently dead — now an input on create/edit and displayed in detail). Customer/vehicle immutable after creation.
- Detail screen: **Edit** action (opens edit mode), **Add item** (existing catalog picker flow → `addOrUpdateItemInJobCard`), remove-item control → `removeItemFromJobCard`.
- Detail displays: inspection checklist, supervisor notes, completedAt (when delivered), estimatedCostNote.

### 2.5 Wizard keeps its promise
- Quick Service Wizard: creates JobCard (inProgress) → Invoice from job card → optional payment collection → job ends delivered (existing `addInvoice` side effect). Banner copy ("job card, bill & collect payment") becomes accurate.

### 2.6 Rendered-but-captured data
- Invoice preview: dueDate (+ overdue badge in lists when past due and unpaid), notes, terms, payment history rows show mode + `receivedBy` + transaction ref; bill-to block shows customer GSTIN when present.
- Customer: GSTIN input (optional) in add/edit form, displayed in detail; notes shown in detail.
- Bottom-nav badge dot → count bubble of active job cards (cap "9+").
- Dashboard `onRefresh` → `provider.refresh()`.

### 2.7 Removals / dead code
- Delete files: `lib/widgets/app_drawer.dart`, `lib/widgets/bento_island_card.dart`, `lib/widgets/stat_card.dart`, `lib/widgets/workshop_efficiency_gauge.dart` (fake 92% KPI), and the fake receipt-attach button in `add_expense_screen`.
- Adopt `SectionHeader` for dashboard hand-rolled section headers.
- Remove never-referenced provider getters (`expenseCategoryBreakdown`, `recentJobCards`) — dashboard computes what it needs inline.
- Remove all "Simulating…" SnackBar stubs (replaced by real actions).

## 3. External actions (real)

Deps: `url_launcher`, `share_plus`.

`lib/utils/contact_actions.dart`:
- `callCustomer(context, phone)` → `tel:` launch.
- `whatsappCustomer(context, phone, message)` → `https://wa.me/<digits>?text=<encoded>`.
- `shareDocument(context, title, body)` → `share_plus` share sheet.
- Failure (no handler / unsupported platform) → info snackbar `No app found to handle this action`.

Used by: customer detail (call/WhatsApp), customers list (WhatsApp), invoice preview (share bill), quotation detail (share estimate). Share body template includes profile name, doc number, customer, vehicle reg, total, balance/due date.

## 4. Theme system

### 4.1 `AppPalette` — `lib/theme/app_palette.dart` (ThemeExtension)

Semantic slots: `background`, `surface`, `card`, `textPrimary`, `textSecondary`, `textMuted`, `border`, `divider`, `primary`, `primaryLight`, `accent`, `onPrimary`, status colors (`paid`, `partial`, `pending`, `inProgress`, `received`, `ready`, `delivered`, `cancelled`, `present`, `halfDay`, `absent`, `leave`), badge pairs (`badgeRed/Orange/Purple/Green/Blue` × bg/icon), `categoryBadge` map for the 9 `ExpenseCategory` values, gradients (`banner`, `card`, `blue`).

- Light instance = current `AppColors` values. Dark instance: surfaces/backgrounds from existing `dark*` values; badge bg = status hue at ~18% opacity on dark, icon = lighter (200–300 range) tone; text tokens slate-200/400/500 equivalents.
- Registered as ThemeExtension on both themes. Access via `context.palette.textSecondary`.
- Screens swept: all ~240 inline `Color(0xFF…)` and `isDark ? … : …` ternaries → palette lookups. Invoice "paper" surface gets its own palette slot (`paperBg`, `paperHeaderBg`) so even structural brightness branches disappear; any remaining `isDark` usage must be structural (e.g. platform overlays), not color selection.

### 4.2 Known dark-mode bugs fixed by the sweep
- Colored `ElevatedButton`s (attendance 4-up, record-payment, convert, delete) get explicit `foregroundColor: Colors.white` with colored bg (dark theme's white-bg/blue-fg default no longer leaks).
- Invoice/estimate table header labels → palette text token (readable on both paper themes).
- Payment balance-card slate gradient → palette `card`/`blue` gradient, works in both themes.

### 4.3 `AppDimens` — `lib/theme/app_dimens.dart`

`radiusCard 20`, `radiusTile 16`, `radiusInput 14`, `radiusButton 16`, `radiusBadge 12`, `radiusFAB 18`, `radiusSheet 24`; `paddingScreen 16`, `paddingCard 16`, spacing ladder 4/8/12/16/20/24. All radius/spacing literals migrated. Gradient FAB aligns to `radiusFAB` (22→18).

### 4.4 Component standards
- **StatusBadge** used everywhere status renders; dashboard's hand-rolled mappings deleted (they currently paint most `JobStatus`es red). New `StatusBadge.forExpenseCategory` + `ExpenseCategory` palette colors (9 distinct badge colors instead of all-orange).
- **PaymentMode** shared icon+label helper (includes `cheque`, used by expense form + collection screen + invoice preview).
- **SnackBar**: single `showAppSnackBar(context, message, type: success|error|info)` (success `paid`, error `pending`, info `primary`; rounded 12, float). All ~40 call sites migrated.
- **Dialogs**: `dialogTheme` added (radius `radiusCard`, palette surface) in both themes; `AddVehicleDialog` stops hand-styling.
- **Buttons**: primary CTA = `GradientButton`; secondary = theme `ElevatedButton`; destructive = `ElevatedButton` with `pending` bg + explicit white fg. Raw ad-hoc CTA paddings normalized.

## 5. Testing

- `garage_workflow_test.dart`: construct `GarageProvider(MockGarageRepository())`; await `load()`. Existing 9 scenarios preserved (seed totals 3304/1416/4720, invoice math 1062, etc.). New coverage: invoice cancel (blocked with payments / allowed without / excluded from analytics), quotation approve→decline→convert, expense update, job-card item add/update/remove, profile+config fetch values, `receivedBy` default from config.
- `widget_test.dart`: pumps app with mock repo; `MainNavigationScreen` shows loading state until `load()` completes; `pumpAndSettle` then expects dashboard.
- `flutter analyze` clean at every step; manual Windows run clicking through dashboard → job card → wizard → invoice → payment → cancel, quotation lifecycle, expense edit, staff/attendance/salary, both themes.

## 6. Sequencing

1. Repository + provider refactor, loading state, tests green.
2. Profile + config (de-hardcode identities/rules).
3. Feature completion (quotations, invoice cancel, expenses, job cards, wizard, rendered data, removals).
4. External actions.
5. Theme palette + dimens + component-standard sweep.
6. Final verify: analyze, tests, manual run in both themes.

## Acceptance criteria

- No business data or garage identity hardcoded in `lib/screens/**` or `lib/widgets/**`; all of it flows from provider (repo → mock seed now).
- Every provider method has a UI caller; no dead screens/widgets; analyzer clean; tests pass.
- Dark mode visually correct on all screens (no low-contrast text, no wrong button foregrounds).
- Call/WhatsApp/share actions launch real handlers.
- Swapping `MockGarageRepository` for a future `ApiGarageRepository` requires no changes outside `main.dart`.
