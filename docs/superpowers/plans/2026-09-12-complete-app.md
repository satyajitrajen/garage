# Nexory Garage Manager — Completion & Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Flutter garage app API-replacement-ready (repository pattern over mock data), complete all unfinished features, and fix UI/theme consistency with a semantic dark/light palette.

**Architecture:** Abstract `GarageRepository` with a `MockGarageRepository` (in-memory, seeded by `MockDataService`); `GarageProvider` becomes a repo-backed cache + selectors that UI watches. Garage identity/business rules come from `GarageProfile`/`AppConfig`. Theme consistency via an `AppPalette` ThemeExtension + `AppDimens` + shared component helpers.

**Tech Stack:** Flutter (Material 3), provider, uuid, intl, google_fonts, fl_chart; new: url_launcher, share_plus.

**Spec:** `docs/superpowers/specs/2026-09-12-complete-app-design.md` (read it before starting; it defines goals, non-goals, acceptance criteria).

**Working conventions for every task:**
- Run `flutter analyze` after code changes; expect `No issues found!`.
- Run `flutter test` where a task touches provider/models/tests; expect all green.
- Commit at the end of each task with the given message (repo: `D:\download\garrage`, branch `main`).
- The app is NOT run in this plan except Task 18 (manual verification). All other checks are analyze + tests.
- Execute in-place on `main` (no worktree — fresh repo, single developer flow).

---

### Task 1: Profile & config models + mock seeds

**Files:**
- Create: `lib/data/garage_profile.dart`
- Create: `lib/data/app_config.dart`
- Modify: `lib/services/mock_data_service.dart` (append two getters at end of class)

- [ ] **Step 1: Create `GarageProfile`**

```dart
class GarageProfile {
  const GarageProfile({
    required this.name,
    required this.tagline,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.upiId,
  });

  final String name;
  final String tagline;
  final String addressLine;
  final String city;
  final String phone;
  final String email;
  final String gstin;
  final String upiId;
}
```

- [ ] **Step 2: Create `AppConfig`**

```dart
class AppConfig {
  const AppConfig({
    this.defaultTaxPercent = 18.0,
    this.taxPercentOptions = const [0.0, 12.0, 18.0, 28.0],
    this.invoiceDueDays = 7,
    this.quotationValidityOptions = const [7, 15, 30],
    this.workingDaysPerMonth = 26,
    this.promisedDeliveryHours = 6,
    this.invoiceNotes = 'Thank you for choosing us! Standard warranty applies.',
    this.invoiceTerms =
        'All parts replaced carry manufacturer warranty. Labour warranty 30 days.',
    this.defaultReceivedBy = 'Cashier',
  });

  final double defaultTaxPercent;
  final List<double> taxPercentOptions;
  final int invoiceDueDays;
  final List<int> quotationValidityOptions;
  final int workingDaysPerMonth;
  final int promisedDeliveryHours;
  final String invoiceNotes;
  final String invoiceTerms;
  final String defaultReceivedBy;
}
```

- [ ] **Step 3: Add seed getters to `MockDataService`** (import the two new files at top)

```dart
static GarageProfile getGarageProfile() => const GarageProfile(
      name: 'Nexory Garage & Body Shop',
      tagline: 'Multi-Brand Auto Care',
      addressLine: 'Shop 14, Andheri Industrial Estate',
      city: 'Mumbai, MH',
      phone: '+91 98200 12345',
      email: 'service@nexorygarage.in',
      gstin: '27AAAAA0000A1Z5',
      upiId: 'nexorygarage@upi',
    );

static AppConfig getAppConfig() => const AppConfig();
```

- [ ] **Step 4: Verify + commit**

Run: `flutter analyze` → No issues found.

```bash
git add lib/data/garage_profile.dart lib/data/app_config.dart lib/services/mock_data_service.dart
git commit -m "feat: add GarageProfile and AppConfig models with mock seeds"
```

---

### Task 2: GarageRepository interface + MockGarageRepository

**Files:**
- Create: `lib/data/garage_repository.dart`
- Create: `lib/data/mock/mock_garage_repository.dart`

- [ ] **Step 1: Create the abstract repository**

Full interface. Note: `AttendanceRecord` and `SalaryAdvance` live in `lib/models/staff.dart` — import that one; the import block below lists all needed model files:

```dart
import '../data/app_config.dart';
import '../data/garage_profile.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job_card.dart';
import '../models/maintenance_item.dart';
import '../models/payment.dart';
import '../models/quotation.dart';
import '../models/staff.dart';
import '../models/vehicle.dart';

/// Persistence boundary for the app. The UI and [GarageProvider] depend only
/// on this interface; swapping mock data for a real API means implementing it
/// once and injecting the new instance in main.dart.
abstract class GarageRepository {
  Future<GarageProfile> fetchProfile();
  Future<AppConfig> fetchConfig();

  Future<List<Customer>> fetchCustomers();
  Future<Customer> createCustomer(Customer customer);
  Future<Customer> updateCustomer(Customer customer);
  /// Returns false when deletion is blocked (customer has outstanding dues).
  Future<bool> deleteCustomer(String customerId);

  Future<List<Vehicle>> fetchVehicles();
  Future<Vehicle> createVehicle(Vehicle vehicle);
  Future<Vehicle> updateVehicle(Vehicle vehicle);
  Future<void> deleteVehicle(String vehicleId);

  Future<List<Staff>> fetchStaff();
  Future<Staff> createStaff(Staff staff);
  Future<Staff> updateStaff(Staff staff);
  Future<void> deleteStaff(String staffId);

  Future<List<JobCard>> fetchJobCards();
  Future<JobCard> createJobCard(JobCard jobCard);
  Future<JobCard> updateJobCard(JobCard jobCard);
  Future<JobCard> updateJobStatus(String jobCardId, JobStatus status);
  Future<JobCard> upsertJobCardItem(String jobCardId, MaintenanceItem item);
  Future<JobCard> removeJobCardItem(String jobCardId, String itemId);

  Future<List<Quotation>> fetchQuotations();
  Future<Quotation> createQuotation(Quotation quotation);
  Future<Quotation> updateQuotation(Quotation quotation);
  Future<Quotation> updateQuotationStatus(String id, QuotationStatus status);

  Future<List<Invoice>> fetchInvoices();
  Future<Invoice> createInvoice(Invoice invoice);
  Future<Invoice> updateInvoice(Invoice invoice);
  Future<Payment> createPayment(Payment payment);

  Future<List<GarageExpense>> fetchExpenses();
  Future<GarageExpense> createExpense(GarageExpense expense);
  Future<GarageExpense> updateExpense(GarageExpense expense);
  Future<void> deleteExpense(String expenseId);

  /// Upserts by (staffId, calendar day).
  Future<AttendanceRecord> saveAttendance(AttendanceRecord record);
  Future<List<AttendanceRecord>> fetchAttendance();

  Future<List<SalaryAdvance>> fetchSalaryAdvances();
  Future<SalaryAdvance> createSalaryAdvance(SalaryAdvance advance);
  /// Marks all of a staff member's unsettled advances in month/year as deducted.
  Future<List<SalaryAdvance>> settleSalaryAdvances(
      String staffId, int month, int year);

  Future<List<MaintenanceItem>> fetchCatalog();
}
```

Note: `AttendanceRecord` and `SalaryAdvance` live in `lib/models/staff.dart` — import that, don't guess a separate path. Fix the import block accordingly.

- [ ] **Step 2: Create `MockGarageRepository`**

Constructor seeds all lists from `MockDataService` (exact existing calls, copied from current `GarageProvider._initMockData`):

```dart
MockGarageRepository() {
  _customers = MockDataService.getInitialCustomers();
  _vehicles = MockDataService.getInitialVehicles();
  _catalog = MockDataService.getCatalogItems();
  _staff = MockDataService.getInitialStaff();
  _jobCards = MockDataService.getInitialJobCards();
  _quotations = MockDataService.getInitialQuotations();
  _invoices = MockDataService.getInitialInvoices();
  _expenses = MockDataService.getInitialExpenses();
  _attendance = MockDataService.getInitialAttendance(_staff);
  _salaryAdvances = MockDataService.getInitialSalaryAdvances();
}
```

Field declarations: `late List<Customer> _customers;` etc. for all ten collections. Implement every method; mutations are synchronous completions (methods marked `async`, no internal awaits). Key bodies:

```dart
@override
Future<bool> deleteCustomer(String customerId) async {
  final hasDues = _invoices.any((inv) =>
      inv.customerId == customerId &&
      inv.status != InvoiceStatus.cancelled &&
      inv.balanceDue > 0.01);
  if (hasDues) return false;
  _customers.removeWhere((c) => c.id == customerId);
  _vehicles.removeWhere((v) => v.customerId == customerId);
  return true;
}

@override
Future<JobCard> updateJobStatus(String jobCardId, JobStatus status) async {
  final i = _jobCards.indexWhere((jc) => jc.id == jobCardId);
  if (i == -1) throw Exception('Job card not found');
  final current = _jobCards[i];
  _jobCards[i] = current.copyWith(
    status: status,
    completedAt: status == JobStatus.delivered
        ? DateTime.now()
        : (status == JobStatus.cancelled ? current.completedAt : null),
  );
  return _jobCards[i];
}

@override
Future<JobCard> upsertJobCardItem(String jobCardId, MaintenanceItem item) async {
  final i = _jobCards.indexWhere((jc) => jc.id == jobCardId);
  if (i == -1) throw Exception('Job card not found');
  final items = List<MaintenanceItem>.from(_jobCards[i].items);
  final itemIndex = items.indexWhere((x) => x.id == item.id);
  if (itemIndex != -1) {
    items[itemIndex] = item;
  } else {
    items.add(item);
  }
  _jobCards[i] = _jobCards[i].copyWith(items: items);
  return _jobCards[i];
}

@override
Future<JobCard> removeJobCardItem(String jobCardId, String itemId) async {
  final i = _jobCards.indexWhere((jc) => jc.id == jobCardId);
  if (i == -1) throw Exception('Job card not found');
  final items = List<MaintenanceItem>.from(_jobCards[i].items)
    ..removeWhere((x) => x.id == itemId);
  _jobCards[i] = _jobCards[i].copyWith(items: items);
  return _jobCards[i];
}

@override
Future<Payment> createPayment(Payment payment) async {
  final i = _invoices.indexWhere((inv) => inv.id == payment.invoiceId);
  if (i == -1) throw Exception('Invoice not found');
  final invoice = _invoices[i];
  _invoices[i] = invoice.copyWith(payments: [...invoice.payments, payment]);
  return payment;
}

@override
Future<AttendanceRecord> saveAttendance(AttendanceRecord record) async {
  final i = _attendance.indexWhere((a) =>
      a.staffId == record.staffId &&
      a.date.year == record.date.year &&
      a.date.month == record.date.month &&
      a.date.day == record.date.day);
  if (i != -1) {
    _attendance[i] = record;
  } else {
    _attendance.add(record);
  }
  return record;
}

@override
Future<List<SalaryAdvance>> settleSalaryAdvances(
    String staffId, int month, int year) async {
  for (var i = 0; i < _salaryAdvances.length; i++) {
    final adv = _salaryAdvances[i];
    if (adv.staffId == staffId &&
        adv.date.month == month &&
        adv.date.year == year &&
        !adv.isDeducted) {
      _salaryAdvances[i] = SalaryAdvance(
        id: adv.id,
        staffId: adv.staffId,
        amount: adv.amount,
        date: adv.date,
        reason: adv.reason,
        isDeducted: true,
      );
    }
  }
  return List.of(_salaryAdvances);
}
```

Remaining methods follow the same trivial create/update/delete patterns (`createX` inserts at index 0 and returns the object; `updateX` upserts by id and throws `Exception('<Type> not found')` when missing; `deleteX` removes). `fetchX` returns `List.of(_collection)`.

- [ ] **Step 3: Verify + commit**

Run: `flutter analyze` → No issues found (nothing references the repo yet — that is expected and fine).

```bash
git add lib/data/garage_repository.dart lib/data/mock/mock_garage_repository.dart
git commit -m "feat: add GarageRepository interface and in-memory mock implementation"
```

---

### Task 3: GarageProvider refactor + app wiring + tests green

**Files:**
- Modify: `lib/providers/garage_provider.dart` (rewrite)
- Modify: `lib/main.dart:27-28` (inject repo)
- Modify: `lib/screens/main_navigation_screen.dart:38-45` (loading gate)
- Modify: `test/garage_workflow_test.dart` (async + load)
- Modify: `test/widget_test.dart` (pumpAndSettle)

- [ ] **Step 1: Rewrite `GarageProvider`**

Keep: all existing getters, dashboard analytics, search helpers, `getCustomerById`-style lookups, `searchCustomers`, `getServiceHistoryForVehicle`, `getStaffActiveJobCount`, `getAttendanceForStaffOnDate`, `getAdvancesForStaff`, `calculateMonthlySalarySummary`, `generateJobCardNumber`/`generateQuotationNumber`/`generateInvoiceNumber`, `_nextNumber`, `_monthName`, theme toggle. Delete: `_initMockData`, `MockDataService` import, `expenseCategoryBreakdown`, `recentJobCards`.

New shape (constructor, load, mutation pattern — apply this pattern to every mutation; side-effect orchestration stays in the provider):

```dart
class GarageProvider extends ChangeNotifier {
  GarageProvider(this._repo);
  final GarageRepository _repo;
  final _uuid = const Uuid();

  bool _isLoading = true;
  String? _loadError;
  GarageProfile? _profile;
  AppConfig? _config;
  // ...existing collection fields unchanged...

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Screens are gated behind the loading state in MainNavigationScreen, so
  /// accessing profile/config before load() completes is a programming error.
  GarageProfile get profile =>
      _profile ?? (throw StateError('profile accessed before load completed'));
  AppConfig get config =>
      _config ?? (throw StateError('config accessed before load completed'));

  Future<void> load() => _fetchAll(showLoading: true);

  /// Re-fetches without toggling isLoading (pull-to-refresh keeps content).
  Future<void> refresh() => _fetchAll(showLoading: false);

  Future<void> _fetchAll({required bool showLoading}) async {
    if (showLoading) {
      _isLoading = true;
      _loadError = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _repo.fetchProfile(),
        _repo.fetchConfig(),
        _repo.fetchCustomers(),
        _repo.fetchVehicles(),
        _repo.fetchStaff(),
        _repo.fetchJobCards(),
        _repo.fetchQuotations(),
        _repo.fetchInvoices(),
        _repo.fetchExpenses(),
        _repo.fetchAttendance(),
        _repo.fetchSalaryAdvances(),
        _repo.fetchCatalog(),
      ]);
      _profile = results[0] as GarageProfile;
      _config = results[1] as AppConfig;
      _customers = results[2] as List<Customer>;
      _vehicles = results[3] as List<Vehicle>;
      _staff = results[4] as List<Staff>;
      _jobCards = results[5] as List<JobCard>;
      _quotations = results[6] as List<Quotation>;
      _invoices = results[7] as List<Invoice>;
      _expenses = results[8] as List<GarageExpense>;
      _attendance = results[9] as List<AttendanceRecord>;
      _salaryAdvances = results[10] as List<SalaryAdvance>;
      _catalog = results[11] as List<MaintenanceItem>;
      _payments = [for (final inv in _invoices) ...inv.payments];
      _loadError = null;
    } catch (e) {
      _loadError = e.toString();
      if (!showLoading) return; // refresh failure: keep old data on screen
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
```

Mutation pattern (repo call → cache update → notify):

```dart
Future<Customer> addCustomer(Customer customer) async {
  final created = await _repo.createCustomer(customer);
  _customers.insert(0, created);
  notifyListeners();
  return created;
}

Future<Customer> updateCustomer(Customer customer) async {
  final updated = await _repo.updateCustomer(customer);
  final i = _customers.indexWhere((c) => c.id == updated.id);
  if (i != -1) _customers[i] = updated;
  notifyListeners();
  return updated;
}

Future<bool> deleteCustomer(String customerId) async {
  final ok = await _repo.deleteCustomer(customerId);
  if (ok) {
    _customers.removeWhere((c) => c.id == customerId);
    _vehicles.removeWhere((v) => v.customerId == customerId);
    notifyListeners();
  }
  return ok;
}
```

Apply the same shape to: vehicles (add/update/delete), staff (add/update/delete), expenses (add/update/delete), job cards (`addJobCard`, `updateJobCard`, `updateJobStatus` now delegating to `_repo.updateJobStatus` and updating cache), `addOrUpdateItemInJobCard` → `_repo.upsertJobCardItem`, `removeItemFromJobCard` → `_repo.removeJobCardItem`, quotations (`addQuotation`, `updateQuotation`, `updateQuotationStatus` → repo), invoices, payments, attendance, advances.

Special orchestrations (preserve existing side effects exactly):

```dart
Future<Invoice> addInvoice(Invoice invoice) async {
  final created = await _repo.createInvoice(invoice);
  _invoices.insert(0, created);
  _payments.insertAll(0, created.payments);
  final vehicle = getVehicleById(created.vehicleId);
  if (vehicle != null) {
    await updateVehicle(vehicle.copyWith(
      currentKm: created.kmReading > vehicle.currentKm
          ? created.kmReading
          : vehicle.currentKm,
      lastServiceDate: created.invoiceDate,
    ));
  }
  if (created.jobCardId != null) {
    await updateJobStatus(created.jobCardId!, JobStatus.delivered);
  }
  notifyListeners();
  return created;
}

Future<Payment> recordPayment({
  required String invoiceId,
  required double amount,
  required PaymentMode mode,
  String? transactionRef,
  String? notes,
  String? receivedBy,
}) async {
  final i = _invoices.indexWhere((inv) => inv.id == invoiceId);
  if (i == -1) throw Exception('Invoice not found');
  final invoice = _invoices[i];
  if (invoice.status == InvoiceStatus.cancelled) {
    throw Exception('Cannot record payment against a cancelled invoice');
  }
  const epsilon = 0.01;
  if (amount <= 0 || amount > invoice.balanceDue + epsilon) {
    throw Exception(
        'Payment amount must be between 0 and ${invoice.balanceDue.toStringAsFixed(2)}');
  }
  final payment = Payment(
    id: _uuid.v4(),
    invoiceId: invoiceId,
    customerId: invoice.customerId,
    amount: amount.clamp(0.0, invoice.balanceDue),
    mode: mode,
    transactionRef: transactionRef,
    paymentDate: DateTime.now(),
    notes: notes,
    receivedBy: receivedBy ?? config.defaultReceivedBy,
  );
  final saved = await _repo.createPayment(payment);
  _invoices[i] = _invoices[i].copyWith(payments: [..._invoices[i].payments, saved]);
  _payments.insert(0, saved);
  notifyListeners();
  return saved;
}
```

Config-driven changes inside existing logic:
- `createInvoiceFromJobCard`: `dueDate: DateTime.now().add(Duration(days: config.invoiceDueDays))`, `notes: notes ?? config.invoiceNotes` (add optional `{double discount = 0, double taxPercent = ... , String? notes}` — taxPercent default becomes `config.defaultTaxPercent`; keep the empty-items throw).
- `convertQuotationToJobCard`: `promisedDeliveryDate: DateTime.now().add(Duration(hours: config.promisedDeliveryHours))`.
- `calculateMonthlySalarySummary`: `final workingDays = config.workingDaysPerMonth;` (replaces `const workingDays = 26`).
- `addSalaryAdvance`: builds `SalaryAdvance`, `_repo.createSalaryAdvance`, then records the expense via `addExpense` (as today).
- `disburseSalary`: `_salaryAdvances ..clear() ..addAll(await _repo.settleSalaryAdvances(staffId, month, year));` then `addExpense(...)` as today (keep `_monthName`).
- `markAttendance`: build record (uuid id, normalized date) → `_repo.saveAttendance` → replace-or-add in cache → notify. `markAllPresentToday` loops `await markAttendance(...)` for active staff.
- Attendance equality helper: extract `static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;` and use it in `getAttendanceForStaffOnDate` too.

- [ ] **Step 2: Wire `main.dart`**

```dart
create: (_) => GarageProvider(MockGarageRepository()),
```
(import `data/mock/mock_garage_repository.dart`)

- [ ] **Step 3: Loading gate in `MainNavigationScreen.build`** (before existing `Scaffold`)

```dart
final provider = context.watch<GarageProvider>();
if (provider.isLoading) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
if (provider.loadError != null) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          const Text('Failed to load garage data'),
          const SizedBox(height: 16),
          FilledButton(onPressed: provider.load, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Update tests**

`test/garage_workflow_test.dart`: every `GarageProvider()` construction becomes:

```dart
final provider = GarageProvider(MockGarageRepository());
await provider.load();
```

`test/widget_test.dart`:

```dart
await tester.pumpWidget(const NexoryGarageApp());
await tester.pumpAndSettle();
expect(find.text('Nexory Garage'), findsOneWidget);
```

- [ ] **Step 5: Run tests + analyze + commit**

Run: `flutter test` → All tests passed. Run: `flutter analyze` → No issues found.

```bash
git add -A lib/providers lib/main.dart lib/screens/main_navigation_screen.dart test
git commit -m "refactor: GarageProvider backed by GarageRepository with async load"
```

---

### Task 4: Await sweep — all mutation call sites in screens

**Files (exact call sites):** `lib/screens/workflow/quick_service_wizard.dart:124`, `lib/screens/vehicles/add_vehicle_dialog.dart:92,110`, `lib/screens/expenses/expenses_list_screen.dart:55`, `lib/screens/expenses/add_expense_screen.dart:67`, `lib/screens/quotations/quotation_detail_screen.dart:24,43`, `lib/screens/quotations/create_quotation_screen.dart:112`, `lib/screens/staff/staff_attendance_screen.dart:55`, `lib/screens/job_cards/job_card_detail_screen.dart:42,48,66`, `lib/screens/staff/staff_salary_screen.dart:49,321`, `lib/screens/staff/add_staff_screen.dart:67,81`, `lib/screens/invoices/create_invoice_screen.dart:111`, `lib/screens/job_cards/create_job_card_screen.dart:151`, `lib/screens/payments/payment_collection_screen.dart:80`, `lib/screens/staff/staff_list_screen.dart:39,120`, `lib/screens/customers/customer_detail_screen.dart:93,133`, `lib/screens/customers/add_customer_screen.dart:110,137,153`.

- [ ] **Step 1: Add `await` + context-mounted guard at every site.** Canonical pattern:

```dart
final provider = context.read<GarageProvider>();
await provider.addCustomer(newCustomer);
if (!context.mounted) return;
Navigator.pop(context);
```

Rules:
- If `Navigator.pop(context)` / `Navigator.pushReplacement` / snackbar follows the await → capture navigator first (`final nav = Navigator.of(context);`) or use the `context.mounted` guard above; never use `context` across the gap unguarded.
- `deleteCustomer` (returns bool): `final deleted = await provider.deleteCustomer(customer.id); if (!context.mounted) return;` then existing true/false handling.
- `recordPayment` site keeps its existing try/catch — make the call `await`.
- `markAllPresentToday`, `deleteExpense`, `deleteVehicle`, `deleteStaff` (fire-and-forget with snackbar after): still `await` and guard the following `context` usage.
- Convert-to-job-card site: `final jobCard = await provider.convertQuotationToJobCard(quote);` then push detail with `jobCard.id` — guard context before push.

- [ ] **Step 2: Verify + commit**

Run: `flutter analyze` → No issues found. Run: `flutter test` → green.

```bash
git add lib/screens
git commit -m "refactor: await async provider mutations across screens"
```

---

### Task 5: De-hardcode — profile & config into UI

**Files:** `lib/screens/invoices/invoice_preview_screen.dart`, `lib/screens/quotations/quotation_detail_screen.dart`, `lib/screens/dashboard/dashboard_screen.dart`, `lib/screens/more/more_menu_screen.dart`, `lib/screens/workflow/quick_service_wizard.dart`, `lib/screens/invoices/create_invoice_screen.dart`, `lib/screens/quotations/create_quotation_screen.dart`, `lib/screens/job_cards/create_job_card_screen.dart`, `lib/screens/expenses/add_expense_screen.dart`, `lib/screens/maintenance/add_maintenance_screen.dart`, `lib/screens/invoices/invoices_list_screen.dart`, `lib/models/job_card.dart`.

- [ ] **Step 1: Garage identity → `provider.profile`**
  - `invoice_preview_screen.dart:98,116` — letterhead name/address/city/phone/GSTIN: `final profile = context.read<GarageProvider>().profile;` then `Text(profile.name)`, `Text('${profile.addressLine}, ${profile.city}')`, `Text('GSTIN: ${profile.gstin}')`, `Text('Phone: ${profile.phone}')` (keep existing layout, replace literals).
  - `quotation_detail_screen.dart:140` — same profile header.
  - `dashboard_screen.dart:57` — appbar title `profile.name`; `:163-172` status line derived: `provider.activeJobCards.isEmpty ? 'All clear — no vehicles in workshop' : '${provider.activeJobCards.length} vehicle(s) in workshop'` (drop the fake 'Operational & Peak Flow').
  - `more_menu_screen.dart:89,99` — profile card: `profile.name`, `'GSTIN: ${profile.gstin} • ${profile.city}'`.

- [ ] **Step 2: Business rules → `provider.config`**
  - `create_invoice_screen.dart:36,107,257-262` — `_taxPercent` default `provider.config.defaultTaxPercent`; due date `DateTime.now().add(Duration(days: config.invoiceDueDays))`; GST dropdown items = `config.taxPercentOptions` with label `'${rate.toStringAsFixed(0)}%'` (+ `' (CGST ${(rate / 2).toStringAsFixed(1)}% + SGST ${(rate / 2).toStringAsFixed(1)}%)'` when rate > 0).
  - `create_quotation_screen.dart:36-37,264-282` — same for tax; validity dropdown = `config.quotationValidityOptions`.
  - `quick_service_wizard.dart:119,401,525` — invoice `taxPercent: config.defaultTaxPercent`; tax math `final taxRate = config.defaultTaxPercent / 100; final tax = taxable * taxRate;`; label `'Tax (${config.defaultTaxPercent.toStringAsFixed(0)}%):'`.
  - `create_job_card_screen.dart:40` — default promised delivery `Duration(hours: config.promisedDeliveryHours)`.
  - `quick_service_wizard.dart:121` — invoice notes `'Quick Service counter bill'` (brand removed).

- [ ] **Step 3: Checklist single source** — in `lib/models/job_card.dart` the existing default checklist list stays as the single source; rename it to a public const `static const List<Map<String, bool>> defaultChecklist = ...` (keeping exact current entries) and change `create_job_card_screen.dart:43-52` to initialize from `JobCard.defaultChecklist` (delete the divergent duplicate).

- [ ] **Step 4: Enum-backed catalogs**
  - `add_expense_screen.dart:214` — mode chips from `PaymentMode.values` (adds cheque/other).
  - `add_maintenance_screen.dart:508-515` — tab labels from the existing `ItemCategory` display-name extension (verify the extension in `lib/models/maintenance_item.dart`; if tabs need the current 6-group layout keep the grouping constant but source labels from the enum).

- [ ] **Step 5: Display-formatting fixes**
  - `invoices_list_screen.dart:349` — replace `"Cash"` fallback: if `invoice.payments.isEmpty` show `'—'`, else the mode label of the latest payment.
  - Raw `₹` sites → `CurrencyFormatter.format(...)`: `quick_service_wizard.dart:489`, `create_job_card_screen.dart:455,457`, `create_invoice_screen.dart:240`, `create_quotation_screen.dart:247`, `job_card_detail_screen.dart:345`, `staff_salary_screen.dart:61,229`, `add_expense_screen.dart:71`.

- [ ] **Step 6: Verify + commit**

Run: `flutter analyze` → clean. Run: `flutter test` → green.

```bash
git add lib/screens lib/models/job_card.dart
git commit -m "refactor: all garage identity and business rules sourced from profile/config"
```

---

### Task 6: Invoice cancel

**Files:**
- Modify: `lib/models/invoice.dart`
- Modify: `lib/providers/garage_provider.dart`
- Modify: `lib/screens/invoices/invoice_preview_screen.dart`
- Test: `test/garage_workflow_test.dart`

- [ ] **Step 1: Model — failing test first**

```dart
test('invoice cancel: unpaid invoice becomes cancelled, paid cannot cancel', () async {
  final provider = GarageProvider(MockGarageRepository());
  await provider.load();
  final unpaid = provider.invoices.firstWhere((i) => i.totalPaidAmount == 0);
  await provider.cancelInvoice(unpaid.id);
  expect(unpaid.copyWith(cancelledAt: DateTime.now()).status, InvoiceStatus.cancelled);
  expect(
      provider.invoices.firstWhere((i) => i.id == unpaid.id).status,
      InvoiceStatus.cancelled);
  expect(provider.totalPendingPayments,
      isNot(contains(equals(unpaid.balanceDue)))); // excluded from analytics
  final paid = provider.invoices.firstWhere((i) => i.totalPaidAmount > 0);
  expect(() => provider.cancelInvoice(paid.id), throwsException);
});
```

Run: `flutter test test/garage_workflow_test.dart` → FAIL (`cancelInvoice` and `cancelledAt` don't exist).

- [ ] **Step 2: Model change** — add `final DateTime? cancelledAt;` (constructor param, nullable, `this.cancelledAt`), copyWith param `DateTime? cancelledAt` — **note:** copyWith cannot distinguish "unset" from "null" here; that is acceptable because nothing clears a cancellation. Then:

```dart
double get balanceDue =>
    status == InvoiceStatus.cancelled ? 0 : (grandTotal - totalPaidAmount).clamp(0, double.infinity);

InvoiceStatus get status {
  if (cancelledAt != null) return InvoiceStatus.cancelled;
  if (balanceDue <= 0.01) {
    return InvoiceStatus.paid;
  } else if (totalPaidAmount > 0) {
    return InvoiceStatus.partial;
  }
  return InvoiceStatus.pending;
}
```

(Careful: `balanceDue` now reads `status` and `status` reads `balanceDue` — restructure to avoid infinite recursion: compute `rawBalance = (grandTotal - totalPaidAmount).clamp(0, double.infinity);` in a private getter `_rawBalanceDue`; `balanceDue => cancelled ? 0 : _rawBalanceDue;` and `status` checks `_rawBalanceDue <= 0.01`.)

- [ ] **Step 3: Provider**

```dart
Future<void> cancelInvoice(String invoiceId) async {
  final i = _invoices.indexWhere((inv) => inv.id == invoiceId);
  if (i == -1) throw Exception('Invoice not found');
  final invoice = _invoices[i];
  if (invoice.totalPaidAmount > 0) {
    throw Exception('Cannot cancel an invoice with recorded payments');
  }
  final cancelled = invoice.copyWith(cancelledAt: DateTime.now());
  _invoices[i] = await _repo.updateInvoice(cancelled);
  notifyListeners();
}
```

- [ ] **Step 4: UI** — in `invoice_preview_screen.dart`, add a Cancel Invoice action (appbar overflow menu or a destructive `ElevatedButton` with `backgroundColor: AppColors.pending, foregroundColor: Colors.white`): confirm dialog ('Cancel this invoice? This cannot be undone.') → `await provider.cancelInvoice(invoice.id)` → success snackbar + pop. On exception → error snackbar with `e.toString()` minus the `Exception:` prefix. Hide the action when `invoice.totalPaidAmount > 0 || invoice.status == InvoiceStatus.cancelled`.

- [ ] **Step 5: Run tests + analyze + commit**

```bash
git add lib/models/invoice.dart lib/providers/garage_provider.dart lib/screens/invoices/invoice_preview_screen.dart test/garage_workflow_test.dart
git commit -m "feat: invoice cancellation with payment guard"
```

---

### Task 7: Quotation lifecycle — edit, approve, decline, guarded convert

**Files:**
- Modify: `lib/screens/quotations/create_quotation_screen.dart`
- Modify: `lib/screens/quotations/quotation_detail_screen.dart`
- Modify: `lib/providers/garage_provider.dart` (guard in `convertQuotationToJobCard`)
- Test: `test/garage_workflow_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('quotation lifecycle: approve -> convert, decline, guard', () async {
  final provider = GarageProvider(MockGarageRepository());
  await provider.load();
  final draft = provider.quotations.firstWhere((q) => q.status == QuotationStatus.draft);
  await provider.updateQuotationStatus(draft.id, QuotationStatus.approved);
  expect(provider.quotations.firstWhere((q) => q.id == draft.id).status,
      QuotationStatus.approved);
  final jobCard = await provider.convertQuotationToJobCard(
      provider.quotations.firstWhere((q) => q.id == draft.id));
  expect(jobCard.customerId, draft.customerId);
  expect(provider.quotations.firstWhere((q) => q.id == draft.id).status,
      QuotationStatus.converted);
  await provider.updateQuotationStatus(draft.id, QuotationStatus.rejected);
  final stillDraft = provider.quotations
      .firstWhere((q) => q.status == QuotationStatus.draft, orElse: () => draft);
  expect(() => provider.convertQuotationToJobCard(stillDraft.copyWith(status: QuotationStatus.draft)),
      throwsException);
});
```

Run → FAIL (guard doesn't exist yet).

- [ ] **Step 2: Guard in provider**

```dart
Future<JobCard> convertQuotationToJobCard(Quotation quote, {String? assignedStaffId}) async {
  if (quote.status != QuotationStatus.approved) {
    throw Exception('Only approved estimates can be converted to a job card');
  }
  // ...existing body, but awaited: final jobCard = await addJobCard(...); await updateQuotationStatus(quote.id, QuotationStatus.converted);
}
```

- [ ] **Step 3: Edit mode in `create_quotation_screen`** — add `final Quotation? existing;` to the constructor; in state init: prefill controllers/fields from `widget.existing` (customer, vehicle, KM, items list copy, discount, tax, validity, notes, status stays); save path:

```dart
if (widget.existing != null) {
  await provider.updateQuotation(edited.copyWith(items: items));
} else {
  await provider.addQuotation(quote);
}
```
(Number: only generated for new — `generateQuotationNumber()` call moves into the new-quote branch.)

- [ ] **Step 4: Detail actions** — in `quotation_detail_screen.dart`, when `quote.status == QuotationStatus.draft` show a row of actions: **Edit** (push `CreateQuotationScreen(existing: quote)`), **Approve** (`await provider.updateQuotationStatus(quote.id, QuotationStatus.approved)` + success snackbar), **Decline** (confirm dialog → status `rejected`). Show **Convert to Job Card** only when `status == approved` (existing handler + mechanic dialog). Converted/rejected quotes show no lifecycle actions.

- [ ] **Step 5: Tests + analyze + commit**

```bash
git add lib/screens/quotations lib/providers/garage_provider.dart test/garage_workflow_test.dart
git commit -m "feat: quotation edit, approve/decline lifecycle, approved-only conversion"
```

---

### Task 8: Expense edit

**Files:**
- Modify: `lib/screens/expenses/add_expense_screen.dart`
- Modify: `lib/screens/expenses/expenses_list_screen.dart`
- Test: `test/garage_workflow_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('expense update persists through repository', () async {
  final provider = GarageProvider(MockGarageRepository());
  await provider.load();
  final exp = provider.expenses.first;
  await provider.updateExpense(exp.copyWith(amount: exp.amount + 100));
  expect(provider.expenses.firstWhere((e) => e.id == exp.id).amount,
      exp.amount + 100);
});
```
Run → FAIL (updateExpense exists but is sync no-op on cache? — actually it already updates cache; the test validates the async repo path; if it passes, still keep it).

- [ ] **Step 2: Screen edit mode** — add `final GarageExpense? existing;` ctor param; prefill controllers/category/mode/date; save: `existing != null ? await provider.updateExpense(edited) : await provider.addExpense(expense);` then pop.

- [ ] **Step 3: Entry point** — in `expenses_list_screen.dart`, add an edit action per row (trailing menu or long-press sheet): push `AddExpenseScreen(existing: exp)`.

- [ ] **Step 4: Test + analyze + commit**

```bash
git add lib/screens/expenses test/garage_workflow_test.dart
git commit -m "feat: expense editing"
```

---

### Task 9: Job card edit + item management + captured-data display

**Files:**
- Modify: `lib/screens/job_cards/create_job_card_screen.dart`
- Modify: `lib/screens/job_cards/job_card_detail_screen.dart`
- Test: `test/garage_workflow_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('job card item upsert/remove via provider', () async {
  final provider = GarageProvider(MockGarageRepository());
  await provider.load();
  final jc = provider.jobCards.first;
  final item = provider.catalog.first.copyWith(id: 'temp-item', quantity: 2);
  await provider.addOrUpdateItemInJobCard(jc.id, item);
  expect(
      provider.jobCards.firstWhere((x) => x.id == jc.id).items.any((i) => i.id == 'temp-item'),
      isTrue);
  await provider.removeItemFromJobCard(jc.id, 'temp-item');
  expect(
      provider.jobCards.firstWhere((x) => x.id == jc.id).items.any((i) => i.id == 'temp-item'),
      isFalse);
});
```

- [ ] **Step 2: Edit mode in `create_job_card_screen`** — add `final JobCard? existing;` ctor param; prefill: complaints, KM, assigned staff, promised date, checklist copy, supervisor notes, `estimatedCostNote`; customer/vehicle pickers disabled when editing (show read-only summary row). Save → `existing != null ? await provider.updateJobCard(updated) : await provider.addJobCard(jobCard);`.

- [ ] **Step 3: `estimatedCostNote` input** — add a text field on create/edit (`Est. cost note (optional)`), persisted into the model field.

- [ ] **Step 4: Detail screen** —
  - **Edit** button (visible when `status != delivered && status != cancelled`) → push create screen with `existing`.
  - **Add item**: reuse the same catalog-selection flow the create screen uses (push the maintenance picker the same way; on result, for each picked item `await provider.addOrUpdateItemInJobCard(jobCard.id, item)`).
  - **Remove item**: delete icon on each item row (only when job is active) → `await provider.removeItemFromJobCard(jobCard.id, itemId)`.
  - Display sections: inspection checklist (from `jobCard.inspectionChecklist`, label + done/undone), supervisor notes, `estimatedCostNote`, and `completedAt` when delivered (`'Completed: ${DateFormatter...}'` using the existing date formatter util).

- [ ] **Step 5: Test + analyze + commit**

```bash
git add lib/screens/job_cards test/garage_workflow_test.dart
git commit -m "feat: job card editing, item add/remove, and full detail display"
```

---

### Task 10: Quick Service Wizard creates job card + bill + payment

**Files:**
- Modify: `lib/providers/garage_provider.dart` (new orchestration method)
- Modify: `lib/screens/workflow/quick_service_wizard.dart`
- Test: `test/garage_workflow_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('quick service checkout creates job card, invoice, payment; job delivered', () async {
  final provider = GarageProvider(MockGarageRepository());
  await provider.load();
  final vehicle = provider.vehicles.first;
  final jobCountBefore = provider.jobCards.length;
  final invoice = await provider.quickServiceCheckout(
    customerId: vehicle.customerId,
    vehicleId: vehicle.id,
    kmReading: vehicle.currentKm + 10,
    items: [provider.catalog.first.copyWith(id: 'qs-1', quantity: 1)],
    paymentAmount: 500,
  );
  expect(provider.jobCards.length, jobCountBefore + 1);
  expect(invoice.payments.single.amount, 500);
  final job = provider.jobCards.first;
  expect(job.status, JobStatus.delivered); // addInvoice side effect
});
```

- [ ] **Step 2: Provider orchestration**

```dart
Future<Invoice> quickServiceCheckout({
  required String customerId,
  required String vehicleId,
  required int kmReading,
  required List<MaintenanceItem> items,
  double discount = 0,
  double? taxPercent,
  double paymentAmount = 0,
  PaymentMode paymentMode = PaymentMode.cash,
}) async {
  if (items.isEmpty) throw Exception('Add at least one service item');
  final jobCard = await addJobCard(JobCard(
    id: _uuid.v4(),
    jobCardNumber: generateJobCardNumber(),
    customerId: customerId,
    vehicleId: vehicleId,
    customerComplaints: const ['Quick service walk-in'],
    kmReading: kmReading,
    status: JobStatus.inProgress,
    promisedDeliveryDate:
        DateTime.now().add(Duration(hours: config.promisedDeliveryHours)),
    items: List.of(items),
    supervisorNotes: 'Created via Quick Service wizard',
  ));
  final invoice = await createInvoiceFromJobCard(
    jobCard,
    discount: discount,
    taxPercent: taxPercent ?? config.defaultTaxPercent,
    notes: 'Quick Service counter bill',
  );
  if (paymentAmount > 0) {
    await recordPayment(
      invoiceId: invoice.id,
      amount: paymentAmount,
      mode: paymentMode,
    );
  }
  return invoice;
}
```

- [ ] **Step 3: Wizard** — replace the wizard's direct `addInvoice` (`quick_service_wizard.dart:111-124`) with `provider.quickServiceCheckout(...)`, passing the wizard's collected vehicle/KM/items/discount and the optional payment step. Tax math/label already config-driven from Task 5. Success screen copy stays accurate ('Job card, bill & payment recorded').

- [ ] **Step 4: Test + analyze + commit**

```bash
git add lib/providers/garage_provider.dart lib/screens/workflow test/garage_workflow_test.dart
git commit -m "feat: quick service wizard performs full job card + billing flow"
```

---

### Task 11: Rendered data — dueDate, notes/terms, receivedBy, GSTIN, notes, badges, refresh

**Files:**
- Modify: `lib/screens/invoices/invoices_list_screen.dart`, `lib/screens/invoices/invoice_preview_screen.dart`
- Modify: `lib/screens/customers/add_customer_screen.dart`, `lib/screens/customers/customer_detail_screen.dart`
- Modify: `lib/screens/main_navigation_screen.dart`
- Modify: `lib/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Overdue indicator** — in `invoices_list_screen.dart` (and anywhere invoice cards render), when `inv.dueDate != null && inv.status != InvoiceStatus.cancelled && inv.balanceDue > 0 && inv.dueDate!.isBefore(DateTime.now())` show a small `'Overdue'` chip (`AppColors.pending` bg, white text) next to the status badge.

- [ ] **Step 2: Invoice preview additions** —
  - Due date row in the totals block: `'Due Date: ${DateFormatter.format(inv.dueDate!)}'` when set.
  - Notes section (`inv.notes`) and Terms section (`inv.termsAndConditions`) rendered below totals when non-null.
  - Payment history rows: append `receivedBy` and `transactionRef` when present (`'UPI • ref TXN123 • by Cashier'`).
  - Bill-to block: customer GSTIN line when `customer.gstin?.trim().isNotEmpty == true`.

- [ ] **Step 3: Customer GSTIN + notes** — `add_customer_screen.dart`: optional GSTIN field (15-char, uppercase) saved into `Customer.gstin` (model field exists; edit path already preserves it). `customer_detail_screen.dart`: show GSTIN chip and `customer.notes` in the info section when present.

- [ ] **Step 4: Nav badge counts** — `main_navigation_screen.dart:174-189`: replace the empty dot with a count bubble — red circle, white `10`-font label `'${badgeCount > 9 ? '9+' : badgeCount}'`, min width 16.

- [ ] **Step 5: Dashboard refresh** — `dashboard_screen.dart:103-106`: `onRefresh: () => context.read<GarageProvider>().refresh()`.

- [ ] **Step 6: Analyze + tests + commit**

```bash
git add lib/screens
git commit -m "feat: surface due dates, notes, GSTIN, receivedBy; nav counts; real refresh"
```

---

### Task 12: External actions — url_launcher + share_plus

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/utils/contact_actions.dart`
- Modify: `lib/screens/customers/customer_detail_screen.dart:258-276`, `lib/screens/customers/customers_list_screen.dart:290-298`, `lib/screens/invoices/invoice_preview_screen.dart:39-59`, `lib/screens/quotations/quotation_detail_screen.dart:93-100`, `lib/screens/expenses/add_expense_screen.dart:286-293`

- [ ] **Step 1: Deps** — `flutter pub add url_launcher share_plus`. Record resolved versions in the commit.

- [ ] **Step 2: `lib/utils/contact_actions.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_snack_bar.dart';

class ContactActions {
  static Future<void> call(BuildContext context, String phone) =>
      _launch(context, Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  static Future<void> whatsapp(
    BuildContext context,
    String phone, {
    String message = '',
  }) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    await _launch(
      context,
      Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}'),
    );
  }

  static Future<void> shareText(
    BuildContext context, {
    required String title,
    required String text,
  }) async {
    try {
      await SharePlus.instance.share(ShareParams(title: title, text: text));
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'Could not open the share sheet',
            type: SnackBarType.error);
      }
    }
  }

  static Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnackBar(context, 'No app found to handle this action');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No app found to handle this action');
      }
    }
  }
}
```

Note: `app_snack_bar.dart` is created in Task 13 — either create it in this task first (copy the code from Task 13 Step 1) or use inline `ScaffoldMessenger` snackbars here and migrate in Task 13. **Decision: create `lib/widgets/app_snack_bar.dart` in this task** (pull that file forward from Task 13) so `ContactActions` compiles.

- [ ] **Step 3: Wire the five call sites**
  - Customer detail Call → `ContactActions.call(context, customer.phone)`; WhatsApp → `ContactActions.whatsapp(context, customer.phone, message: 'Hello ${customer.name}, this is ${profile.name}.')`.
  - Customers list WhatsApp icon → same helper.
  - Invoice preview Share WhatsApp Bill + Print Tax Bill → collapse into one **Share Bill** action: `ContactActions.shareText(context, title: 'Invoice ${invoice.invoiceNumber}', text: shareText)` where `shareText` is built from profile name, invoice number, customer name, vehicle reg, grand total, balance due, due date (use `CurrencyFormatter`).
  - Quotation detail Share Estimate → same pattern with estimate total/validity.

- [ ] **Step 4: Remove stubs** — delete the fake receipt-attach button + its snackbar in `add_expense_screen.dart:286-293` (keep the `receiptPath` model field). Delete every remaining "Simulating…/Sending…/Preparing…" snackbar replaced above.

- [ ] **Step 5: Analyze + commit**

```bash
git add pubspec.yaml pubspec.lock lib/utils/contact_actions.dart lib/widgets/app_snack_bar.dart lib/screens
git commit -m "feat: real call/WhatsApp/share actions via url_launcher and share_plus"
```

---

### Task 13: Theme foundation — AppPalette, AppDimens, helpers, dead-widget deletion

**Files:**
- Create: `lib/theme/app_palette.dart`, `lib/theme/app_dimens.dart`
- Create: `lib/utils/payment_mode_display.dart`
- Modify: `lib/widgets/status_badge.dart` (expense-category factory)
- Modify: `lib/theme/app_theme.dart` (register extension, dialogTheme)
- Delete: `lib/widgets/app_drawer.dart`, `lib/widgets/bento_island_card.dart`, `lib/widgets/stat_card.dart`, `lib/widgets/workshop_efficiency_gauge.dart`
- Modify: `lib/widgets/gradient_button.dart` (FAB radius)

- [ ] **Step 1: `lib/theme/app_palette.dart`** — full code:

```dart
import 'package:flutter/material.dart';
import '../models/expense.dart';

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.onPrimary,
    required this.paid,
    required this.partial,
    required this.pending,
    required this.inProgress,
    required this.received,
    required this.ready,
    required this.delivered,
    required this.cancelled,
    required this.present,
    required this.halfDay,
    required this.absent,
    required this.leave,
    required this.badgeRedBg,
    required this.badgeRedIcon,
    required this.badgeOrangeBg,
    required this.badgeOrangeIcon,
    required this.badgePurpleBg,
    required this.badgePurpleIcon,
    required this.badgeGreenBg,
    required this.badgeGreenIcon,
    required this.badgeBlueBg,
    required this.badgeBlueIcon,
    required this.paperBg,
    required this.paperHeaderBg,
    required this.bannerGradient,
    required this.cardGradient,
    required this.blueGradient,
    required this.categoryColors,
  });

  final Color background, surface, card, cardAlt;
  final Color textPrimary, textSecondary, textMuted;
  final Color border, divider;
  final Color primary, primaryLight, primaryDark, accent, onPrimary;
  final Color paid, partial, pending, inProgress;
  final Color received, ready, delivered, cancelled;
  final Color present, halfDay, absent, leave;
  final Color badgeRedBg, badgeRedIcon;
  final Color badgeOrangeBg, badgeOrangeIcon;
  final Color badgePurpleBg, badgePurpleIcon;
  final Color badgeGreenBg, badgeGreenIcon;
  final Color badgeBlueBg, badgeBlueIcon;
  final Color paperBg, paperHeaderBg;
  final List<Color> bannerGradient, cardGradient, blueGradient;
  final Map<ExpenseCategory, Color> categoryColors;

  static const light = AppPalette(
    background: Color(0xFFF8FAFD),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFEEF2F6),
    divider: Color(0xFFF1F5F9),
    primary: Color(0xFF0284C7),
    primaryLight: Color(0xFF38BDF8),
    primaryDark: Color(0xFF0369A1),
    accent: Color(0xFF0EA5E9),
    onPrimary: Color(0xFFFFFFFF),
    paid: Color(0xFF10B981),
    partial: Color(0xFFF59E0B),
    pending: Color(0xFFEF4444),
    inProgress: Color(0xFF0EA5E9),
    received: Color(0xFF8B5CF6),
    ready: Color(0xFF059669),
    delivered: Color(0xFF10B981),
    cancelled: Color(0xFFEF4444),
    present: Color(0xFF10B981),
    halfDay: Color(0xFFF59E0B),
    absent: Color(0xFFEF4444),
    leave: Color(0xFF8B5CF6),
    badgeRedBg: Color(0xFFFEE2E2),
    badgeRedIcon: Color(0xFFEF4444),
    badgeOrangeBg: Color(0xFFFEF3C7),
    badgeOrangeIcon: Color(0xFFF59E0B),
    badgePurpleBg: Color(0xFFEDE9FE),
    badgePurpleIcon: Color(0xFF8B5CF6),
    badgeGreenBg: Color(0xFFD1FAE5),
    badgeGreenIcon: Color(0xFF10B981),
    badgeBlueBg: Color(0xFFE0F2FE),
    badgeBlueIcon: Color(0xFF0EA5E9),
    paperBg: Color(0xFFFFFFFF),
    paperHeaderBg: Color(0xFFF1F5F9),
    bannerGradient: [Color(0xFFFBE6F2), Color(0xFFFFF0D6), Color(0xFFD4F8EB), Color(0xFFA7F3D0)],
    cardGradient: [Color(0xFFFBE6F2), Color(0xFFFFF0D6), Color(0xFFD4F8EB), Color(0xFFA7F3D0)],
    blueGradient: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    categoryColors: {
      ExpenseCategory.rent: Color(0xFF8B5CF6),
      ExpenseCategory.electricityUtilities: Color(0xFFF59E0B),
      ExpenseCategory.internetPhone: Color(0xFF0EA5E9),
      ExpenseCategory.toolsEquipment: Color(0xFF64748B),
      ExpenseCategory.consumables: Color(0xFF10B981),
      ExpenseCategory.partsStock: Color(0xFFEF4444),
      ExpenseCategory.staffFood: Color(0xFF10B981),
      ExpenseCategory.fuelGenerator: Color(0xFFEF4444),
      ExpenseCategory.miscellaneous: Color(0xFF64748B),
    },
  );

  static const dark = AppPalette(
    background: Color(0xFF0A0F1D),
    surface: Color(0xFF131927),
    card: Color(0xFF1A2234),
    cardAlt: Color(0xFF223047),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    border: Color(0xFF242E42),
    divider: Color(0xFF1B2436),
    primary: Color(0xFF38BDF8),
    primaryLight: Color(0xFF7DD3FC),
    primaryDark: Color(0xFF0EA5E9),
    accent: Color(0xFF38BDF8),
    onPrimary: Color(0xFF06283D),
    paid: Color(0xFF34D399),
    partial: Color(0xFFFBBF24),
    pending: Color(0xFFF87171),
    inProgress: Color(0xFF38BDF8),
    received: Color(0xFFA78BFA),
    ready: Color(0xFF34D399),
    delivered: Color(0xFF34D399),
    cancelled: Color(0xFFF87171),
    present: Color(0xFF34D399),
    halfDay: Color(0xFFFBBF24),
    absent: Color(0xFFF87171),
    leave: Color(0xFFA78BFA),
    badgeRedBg: Color(0x2EEF4444),
    badgeRedIcon: Color(0xFFF87171),
    badgeOrangeBg: Color(0x2EF59E0B),
    badgeOrangeIcon: Color(0xFFFBBF24),
    badgePurpleBg: Color(0x2E8B5CF6),
    badgePurpleIcon: Color(0xFFA78BFA),
    badgeGreenBg: Color(0x2E10B981),
    badgeGreenIcon: Color(0xFF34D399),
    badgeBlueBg: Color(0x2E0EA5E9),
    badgeBlueIcon: Color(0xFF38BDF8),
    paperBg: Color(0xFF1E293B),
    paperHeaderBg: Color(0xFF0F172A),
    bannerGradient: [Color(0xFF2A1C24), Color(0xFF2A2318), Color(0xFF142B24), Color(0xFF163528)],
    cardGradient: [Color(0xFF2A1C24), Color(0xFF2A2318), Color(0xFF142B24), Color(0xFF163528)],
    blueGradient: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    categoryColors: {
      ExpenseCategory.rent: Color(0xFFA78BFA),
      ExpenseCategory.electricityUtilities: Color(0xFFFBBF24),
      ExpenseCategory.internetPhone: Color(0xFF38BDF8),
      ExpenseCategory.toolsEquipment: Color(0xFF94A3B8),
      ExpenseCategory.consumables: Color(0xFF34D399),
      ExpenseCategory.partsStock: Color(0xFFF87171),
      ExpenseCategory.staffFood: Color(0xFF34D399),
      ExpenseCategory.fuelGenerator: Color(0xFFF87171),
      ExpenseCategory.miscellaneous: Color(0xFF94A3B8),
    },
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
```

- [ ] **Step 2: `lib/theme/app_dimens.dart`**

```dart
class AppDimens {
  static const double radiusCard = 20;
  static const double radiusTile = 16;
  static const double radiusInput = 14;
  static const double radiusButton = 16;
  static const double radiusBadge = 12;
  static const double radiusFAB = 18;
  static const double radiusSheet = 24;
  static const double paddingScreen = 16;
  static const double paddingCard = 16;

  /// Standard card shadow (flat design: soft, low alpha) and floating accent glow.
  static List<BoxShadow> cardShadow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> accentGlow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6)),
      ];
}
```

- [ ] **Step 3: Register in `app_theme.dart`** — add to both ThemeData: `extensions: <ThemeExtension<dynamic>>[AppPalette.light]` (light) / `[AppPalette.dark]` (dark); add `dialogTheme: DialogThemeData(backgroundColor: <surface>, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusCard)))`; replace the dark theme's inline slate literals (`0xFF94A3B8`, `0xFF64748B`, `0xFF334155`) with `AppPalette.dark().textSecondary/.textMuted/.border` references.

- [ ] **Step 4: `lib/utils/payment_mode_display.dart`** — extension on `PaymentMode` with `String get label` and `IconData get icon` covering all six values (cash/upi/card/bankTransfer/cheque/other → labels 'Cash','UPI','Card','Bank Transfer','Cheque','Other'; icons: payments_rounded, smartphone_rounded, credit_card_rounded, account_balance_rounded, receipt_long_rounded, more_horiz_rounded). First check whether `payment.dart` or screens already define a similar extension — if one exists, extend that instead of creating a clashing one.

- [ ] **Step 5: StatusBadge expense factory** — in `status_badge.dart` add:

```dart
factory StatusBadge.forExpenseCategory(ExpenseCategory category, {required AppPalette palette}) {
  final color = palette.categoryColors[category]!;
  return StatusBadge._(
    label: category.displayName,
    backgroundColor: color.withValues(alpha: 0.14),
    textColor: color,
  );
}
```
(Adapt to the file's actual private-constructor shape — read the file first and match its internal factory pattern; keep all existing factories untouched.)

- [ ] **Step 6: Delete dead widgets** — `git rm lib/widgets/app_drawer.dart lib/widgets/bento_island_card.dart lib/widgets/stat_card.dart lib/widgets/workshop_efficiency_gauge.dart`; fix any now-broken imports (expected: none — audit verified they are unreferenced); `GradientFloatingActionButton` radius `22` → `AppDimens.radiusFAB`.

- [ ] **Step 7: Analyze + tests + commit**

```bash
git add -A
git commit -m "feat: semantic AppPalette theme extension, AppDimens, shared helpers; remove dead widgets"
```

---

### Task 14: Theme sweep — dashboard, navigation, more menu

**Files:** `lib/screens/dashboard/dashboard_screen.dart`, `lib/screens/main_navigation_screen.dart`, `lib/screens/more/more_menu_screen.dart`.

**Canonical transformations (apply throughout all sweep tasks):**

| Current pattern | Replacement |
|---|---|
| `isDark ? Color(0xFF94A3B8) : AppColors.textMuted` (or bare literal) | `context.palette.textMuted` |
| `isDark ? Color(0xFF64748B) : AppColors.textSecondary` | `context.palette.textSecondary` |
| `isDark ? Colors.white : AppColors.textPrimary` | `context.palette.textPrimary` |
| `isDark ? AppColors.darkBackground : AppColors.background` | `context.palette.background` |
| `isDark ? AppColors.darkSurface/darkCard : Colors.white` | `context.palette.surface` / `.card` |
| `Color(0xFF1E293B)` / `Color(0xFF131927)` / `Color(0xFF1A2234)` | `context.palette.surface` / `.card` (pick by role) |
| `Color(0xFF121726)` selected chip | `context.palette.textPrimary` (dark navy in light, light chip on dark gradient) |
| `Color(0xFFE2E8F0)` / `Color(0xFFCBD5E1)` | `context.palette.border` / `.textMuted` |
| `isDark ? AppColors.cardGradientDark : AppColors.bannerGradient` | `context.palette.bannerGradient` |
| `Color(0xFF0284C7)` inline | `context.palette.primary` |
| Status-colored `ElevatedButton` | explicit `backgroundColor: <status>, foregroundColor: Colors.white` |
| Border radius literals | nearest `AppDimens.radius*` |
| `ScaffoldMessenger...showSnackBar(...)` | `showAppSnackBar(context, msg, type: ...)` |

- [ ] **Step 1: `dashboard_screen.dart`** — apply the table (26 literals); replace the two hand-rolled job-status color mappings (`:563-580`, `:615-625`) with `StatusBadge.fromJobStatus(...)`; adopt `SectionHeader` for the two hand-rolled header rows (`:465-498`, `:734-767`); unify bento-style radii to the dashboard's own set via AppDimens (`:126,190,289` → `radiusCard`/`radiusTile`); replace `Colors.black` ad-hoc shadows with `AppDimens.cardShadow/accentGlow`; migrate its snackbars.
- [ ] **Step 2: `main_navigation_screen.dart`** — apply the table (selected-chip/labels/borders/glow); nav-bar border `Colors.white.withValues(...)` keep (on-gradient, fine); glow → `AppDimens.accentGlow(palette.paid)`.
- [ ] **Step 3: `more_menu_screen.dart`** — apply the table (11 literals incl. `:353,376,403`, badge radius 11 → `radiusBadge`); theme-toggle row and profile card already profile-driven from Task 5.
- [ ] **Step 4: Analyze + commit** (visual check deferred to Task 18)

```bash
git add lib/screens/dashboard lib/screens/main_navigation_screen.dart lib/screens/more lib/theme
git commit -m "style: palette-based theming for dashboard, navigation, and more menu"
```

---

### Task 15: Theme sweep — list screens

**Files:** `lib/screens/customers/customers_list_screen.dart`, `lib/screens/invoices/invoices_list_screen.dart`, `lib/screens/job_cards/job_cards_list_screen.dart`, `lib/screens/quotations/quotations_list_screen.dart`, `lib/screens/expenses/expenses_list_screen.dart`, `lib/screens/staff/staff_list_screen.dart`.

- [ ] **Step 1:** Apply the Task 14 table per file. Notables: `customers_list_screen.dart:168` card ripple radius → `radiusTile`; `invoices_list_screen.dart:94` `0xFF1E293B` → palette; expenses category chips → `StatusBadge.forExpenseCategory` (replaces all-orange `:276-283`); `staff_list_screen.dart:37` delete button → explicit `foregroundColor: Colors.white`; card inner paddings 14/16 → `AppDimens.paddingCard`; manual divider containers (`invoices:98-100`, `expenses:168`) → `Divider(color: palette.divider)`.
- [ ] **Step 2:** Migrate snackbars to `showAppSnackBar`; KPI strips keep layout, colors via palette.
- [ ] **Step 3: Analyze + commit**

```bash
git add lib/screens/customers lib/screens/invoices lib/screens/job_cards lib/screens/quotations lib/screens/expenses lib/screens/staff
git commit -m "style: palette-based theming for all list screens"
```

---

### Task 16: Theme sweep — detail + payment screens

**Files:** `lib/screens/customers/customer_detail_screen.dart`, `lib/screens/job_cards/job_card_detail_screen.dart`, `lib/screens/quotations/quotation_detail_screen.dart`, `lib/screens/invoices/invoice_preview_screen.dart`, `lib/screens/payments/payment_collection_screen.dart`.

- [ ] **Step 1:** Apply the table. Notables:
  - `invoice_preview_screen.dart:74,190-212` — paper: `palette.paperBg`, header bar `palette.paperHeaderBg`, header labels `palette.textSecondary` (fixes dark-mode invisibility); `:366-369` Record Payment button explicit white fg.
  - `quotation_detail_screen.dart:215-227` — same header-label fix; `:322-325` convert button white fg.
  - `job_card_detail_screen.dart:415-431` — both CTA buttons white fg; `:105-449` literal sweep.
  - `payment_collection_screen.dart:216-235` — replace the hardcoded slate gradient with `palette.blueGradient` (or `palette.card` → border); `:150-280` text tokens; mode icons from `payment_mode_display` extension.
  - `customer_detail_screen.dart:91,131,493` — pending-bg buttons white fg.
- [ ] **Step 2: Analyze + commit**

```bash
git add lib/screens/customers lib/screens/job_cards lib/screens/quotations lib/screens/invoices lib/screens/payments
git commit -m "style: palette-based theming for detail and payment screens"
```

---

### Task 17: Theme sweep — forms, wizard, staff screens

**Files:** `lib/screens/customers/add_customer_screen.dart`, `lib/screens/vehicles/add_vehicle_dialog.dart`, `lib/screens/staff/add_staff_screen.dart`, `lib/screens/expenses/add_expense_screen.dart`, `lib/screens/job_cards/create_job_card_screen.dart`, `lib/screens/invoices/create_invoice_screen.dart`, `lib/screens/quotations/create_quotation_screen.dart`, `lib/screens/maintenance/add_maintenance_screen.dart`, `lib/screens/workflow/quick_service_wizard.dart`, `lib/screens/staff/staff_attendance_screen.dart`, `lib/screens/staff/staff_salary_screen.dart`, `lib/screens/vehicles/vehicle_selection_screen.dart`.

- [ ] **Step 1:** Apply the table. Notables:
  - `staff_attendance_screen.dart:329-361` — the 4 attendance buttons: explicit `foregroundColor: Colors.white` with `palette.present/halfDay/absent/leave` backgrounds; `:381` summary badge radius → `radiusBadge`.
  - `add_vehicle_dialog.dart:118-120` — drop hand-styled dialog bg; plain `AlertDialog` (theme's new `dialogTheme` handles it).
  - `quick_service_wizard.dart:163,432,512-535` — literal sweep; footer CTAs already GradientButton.
  - `add_maintenance_screen.dart:155,351,537-540,620-682` — literal sweep; shadow → `AppDimens.cardShadow`.
  - `vehicle_selection_screen.dart:154-340` — 15 literals sweep (`0xFFF8FAFC` → `palette.background`, borders → `palette.border`).
  - `staff_salary_screen.dart:74,159,255-297` — literal sweep; `:166` shadow → helper.
  - `add_staff_screen.dart` — has no `isDark` today: replace its light-only colors with palette tokens (fixes dark mode for free).
- [ ] **Step 2:** Where forms hand-roll empty states (`create_invoice:226-230`, `create_quotation:227-236`, `wizard:304,473`) → use `EmptyStateWidget`.
- [ ] **Step 3: Analyze + tests + commit**

```bash
git add lib/screens
git commit -m "style: palette-based theming for forms, wizard, and staff screens"
```

---

### Task 18: Final verification

- [ ] **Step 1:** `flutter analyze` → No issues found. `flutter test` → all green.
- [ ] **Step 2:** Grep sweeps (expect zero hits in `lib/screens/**` and `lib/widgets/**`): `Color(0xFF` (allowlist: none), `Colors\.grey`, `'Nexory` (only mock seeds), `27AABCA` (old fake GSTIN gone), `Simulating`. Investigate and fix any hits.
- [ ] **Step 3:** Manual run on Windows: `flutter run -d windows`. Click through: dashboard (both themes via more-menu toggle) → job card create/edit/items → quick service wizard full flow → invoice preview (share button opens OS sheet, cancel unpaid invoice, record payment) → quotation draft→approve→convert + edit + decline → customer create/edit/GSTIN + call/WhatsApp buttons (expect graceful 'no app' on desktop) → expense add/edit → staff add/attendance/salary → pull-to-refresh. Verify dark mode has no low-contrast text or wrong button colors. Fix anything found, re-run tests, commit fixes.
- [ ] **Step 4:** Final commit if any fixes:

```bash
git add -A
git commit -m "chore: final verification fixes"
```

---

## Self-review notes (completed during plan writing)

- **Spec coverage:** §1 data layer → Tasks 1–4; §1.6 de-hardcode → Task 5 (+13); §2.1–2.6 → Tasks 6–11; §2.7 removals → Tasks 12–13; §3 → Task 12; §4 → Tasks 13–17; §5 testing → inside each task + Task 18; acceptance criteria → Task 18 grep sweeps. No gaps found.
- **Type consistency:** repository method names used in Task 3 match Task 2 exactly; provider public method names kept identical to today's so Task 4's call-site list stays valid; `StatusBadge.forExpenseCategory` created in Task 13, consumed in Task 15; `app_snack_bar.dart` pulled forward into Task 12 since `ContactActions` needs it.
- **Placeholders:** none — sweep tasks use a deterministic literal→slot mapping table rather than open-ended instructions.
