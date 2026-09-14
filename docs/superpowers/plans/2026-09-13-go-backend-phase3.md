# Go Backend Phase 3 — Flutter Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the Flutter app to the Phase 1+2 Go backend: JSON codecs, ApiClient with refresh-on-401, auth session storage, login/register UI, HttpGarageRepository implementing all 38 `GarageRepository` methods, and permission-aware UI gating.

**Architecture:** A new `lib/data/api/` layer. `ApiClient` wraps package:http (auth header, `X-Garage-Id` header, error-envelope decoding, one refresh-and-retry on 401). `AuthSession` owns token persistence (secure storage) + server URL / garage id (shared prefs). `HttpGarageRepository` implements the existing `GarageRepository` interface 1:1 onto the §5 routes and pre-filters fetches the active membership lacks permission for, so `GarageProvider` stays untouched except for a `permissions` field used by UI gating. `main.dart` becomes `LoginGate` → LoginScreen or AppShell; widget tests keep `MockGarageRepository` via a new `repository` constructor param.

**Tech Stack:** Flutter/Dart (provider, existing hand-rolled style), package:http, flutter_secure_storage, shared_preferences; Go backend (existing, no changes required).

**Spec:** docs/superpowers/specs/2026-09-13-go-backend-design.md §7 (Flutter connection), §5 (API surface), §8 (error codes).

---

## Conventions (apply to every task)

- **Working dirs:** `flutter`/`dart` commands from repo root (`D:\download\garrage`); `go` commands from `backend/`; `git` from repo root.
- **Gates as separate Bash calls** — never `&&` chains. Before each commit: `flutter analyze` then `flutter test`.
- **Commits:** conventional prefixes (`feat:`, `test:`, `fix:`), explicit file adds only (never `git add -A` / `git add .`). If bare `git commit -m` is blocked, use `git commit -m "..." -- <explicit paths>`.
- **Continuous execution** via subagent-driven development: implementer → spec-compliance reviewer → code-quality reviewer per task, no human check-ins.

### Wire format facts (verified against backend source — do not re-derive)

1. **Domain objects are camelCase** and key names exactly equal Dart field names: `customerId`, `whatsappNumber`, `jobCardNumber`, `inspectionChecklist`, `assignedStaffId`, `monthlySalary`, `isActive`, `isDeducted`, `unitPrice`, `taxPercent`, `lastServiceDate`, `expenseDate`, `paymentDate`, `cancelledAt`, `termsAndConditions`, etc. (backend/internal/models/*.go).
2. **Auth + settings payloads are snake_case** (Phase 1): request/response bodies `access_token`, `refresh_token`; `User` → `id,email,name,created_at`; `Membership` → `garage_id,garage_name,role,permissions,is_active`; `Profile` → `name,tagline,address_line,city,phone,email,gstin,upi_id`; `GarageSettings` → `garage_id,profile,default_tax_percent,tax_percent_options,invoice_due_days,quotation_validity_options,working_days_per_month,promised_delivery_hours,invoice_notes,invoice_terms,default_received_by`. Settle request: `staff_id`, `month`, `year`.
3. **Enums** travel as the Dart enum `.name` string 1:1 (Go `enums.go` mirrors them exactly): FuelType[petrol,diesel,cng,electric,hybrid], StaffRole[headMechanic,seniorTechnician,autoElectrician,denterPainter,helperTrainee,serviceAdvisor,manager], AttendanceStatus[present,halfDay,absent,leave], JobStatus[received,inspection,inProgress,waitingParts,readyForDelivery,delivered,cancelled], QuotationStatus[draft,sent,approved,converted,rejected], PaymentMode[cash,upi,card,bankTransfer,cheque,other], ExpenseCategory[rent,electricityUtilities,internetPhone,toolsEquipment,consumables,partsStock,staffFood,fuelGenerator,miscellaneous], ItemCategory[sparePart,labour,fluids,tyresBattery,transportMisc,custom].
4. **Numbers:** Go floats marshal integrally (`100`, not `100.0`) → every numeric read MUST use `(x as num).toDouble()` / `(x as num).toInt()` / `(x as num?)?.toInt()`. Never `as double` / `as int`.
5. **Instants** (createdAt, promisedDeliveryDate, completedAt, validUntil, invoiceDate, dueDate, cancelledAt, paymentDate) are RFC3339 strings from Go (UTC). Write: `.toUtc().toIso8601String()`. Read: `DateTime.parse(s).toLocal()` — toLocal is REQUIRED so provider day-comparisons (`p.paymentDate.year == now.year` etc.) see the garage's wall clock.
6. **Day-grained dates** (staff `joiningDate`, attendance `date`, advance `date`, expense `expenseDate`, vehicle `lastServiceDate`) are plain `YYYY-MM-DD` strings. Write the LOCAL calendar day via the plan's `_day` helper (never `toUtc` — that shifts the day for IST). Read: `DateTime.parse(s)` (no offset → local midnight).
7. **Server assigns ids** on create and ignores client-supplied `id` fields — sending `id` in create bodies is harmless; always return/use the server's response object.
8. **Lists** are `{"items": [...]}`; single objects are bare. Invoice responses embed `items` AND `payments`; job-card and quotation responses embed `items`.
9. **Error envelope:** `{"error":{"code":"...","message":"..."}}` with codes invalid_request(400), unauthorized(401), forbidden(403), not_found(404), conflict(409), unprocessable(422), internal(500).
10. **Route map (flat under /api, garage via `X-Garage-Id` header):** auth `/api/auth/{register,login,refresh,logout}`, `/api/me`, members+settings under `/api/garages/{garageId}/...`, then `/api/customers`, `/api/vehicles`, `/api/staff`, `/api/attendance` (POST upsert), `/api/salary-advances` (+ `/settle`), `/api/jobcards` (+ `/{id}/status`, `/{id}/items`, `DELETE /{id}/items/{itemId}`), `/api/quotations` (+ `/{id}/status`), `/api/invoices` (+ `/{id}/cancel`), `/api/invoices/{id}/payments` (POST), `/api/expenses`, `/api/catalog` (GET only).
11. **Permission keys (11):** `customers.manage, vehicles.manage, jobcards.manage, quotations.manage, invoices.manage, payments.record, expenses.manage, staff.manage, attendance.manage, advances.manage, settings.manage`. Default staff set excludes expenses.manage, staff.manage, advances.manage, settings.manage.
12. **Return-shape gotchas:** `POST /jobcards/{id}/items` returns the ITEM (not the card); `DELETE /jobcards/{id}/items/{itemId}` returns 204 (empty); `POST /salary-advances/settle` returns the FULL garage advance list (matches MockGarageRepository's contract — provider replaces its whole cache with it); `DELETE /customers/{id}` → 409 when dues outstanding (mock's `false`).

### Task graph

T1 deps → T2 auth models → T3/T4/T5 codecs → T6 AuthSession → T7 ApiClient → T8/T9 repository → T10 login UI → T11 bootstrap → T12 gating → T13 final. T3-T5 are independent of each other; T6 and T7 are independent of T3-T5; T8/T9 need T2-T7; T10 needs T2+T6; T11 needs T6-T10; T12 needs T11; T13 last.

---

### Task 1: Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Create: `pubspec.lock` (updated)

- [ ] **Step 1: Add the three packages**

Run from repo root:

```
flutter pub add http flutter_secure_storage shared_preferences
```

Expected: resolves; pubspec.yaml gains `http: ^1.x`, `flutter_secure_storage: ^9.x`, `shared_preferences: ^2.x` under dependencies. Do NOT pin versions manually.

- [ ] **Step 2: Verify analyze still clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run existing tests (baseline stays green)**

Run: `flutter test`
Expected: `All tests passed!` (25 tests)

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add http, flutter_secure_storage, shared_preferences for backend connection"
```

---

### Task 2: ApiException + auth models (snake_case)

**Files:**
- Create: `lib/data/api/api_exception.dart`
- Create: `lib/data/api/auth_models.dart`
- Test: `test/api/auth_models_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/auth_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/api/auth_models.dart';

void main() {
  group('Membership', () {
    test('parses snake_case wire format', () {
      final m = Membership.fromJson(const {
        'garage_id': 'g-1',
        'garage_name': 'Nexory Garage',
        'role': 'owner',
        'permissions': ['customers.manage', 'invoices.manage'],
        'is_active': true,
      });
      expect(m.garageId, 'g-1');
      expect(m.garageName, 'Nexory Garage');
      expect(m.role, 'owner');
      expect(m.permissions, ['customers.manage', 'invoices.manage']);
      expect(m.isActive, isTrue);
    });
  });

  group('AuthUser', () {
    test('parses snake_case wire format', () {
      final u = AuthUser.fromJson(const {
        'id': 'u-1',
        'email': 'a@b.c',
        'name': 'Ada',
        'created_at': '2026-09-13T10:00:00Z',
      });
      expect(u.id, 'u-1');
      expect(u.email, 'a@b.c');
      expect(u.name, 'Ada');
    });
  });

  group('LoginResponse', () {
    test('parses snake_case envelope with nested user and memberships', () {
      final r = LoginResponse.fromJson(const {
        'access_token': 'at',
        'refresh_token': 'rt',
        'user': {'id': 'u-1', 'email': 'a@b.c', 'name': 'Ada'},
        'memberships': [
          {
            'garage_id': 'g-1',
            'garage_name': 'Nexory Garage',
            'role': 'owner',
            'permissions': ['customers.manage'],
            'is_active': true,
          }
        ],
      });
      expect(r.accessToken, 'at');
      expect(r.refreshToken, 'rt');
      expect(r.user.name, 'Ada');
      expect(r.memberships.single.garageId, 'g-1');
    });
  });

  group('ApiException', () {
    test('carries status, code and message', () {
      const e = ApiException(409, 'conflict', 'email already registered');
      expect(e.statusCode, 409);
      expect(e.code, 'conflict');
      expect(e.message, 'email already registered');
      expect(e.toString(), contains('409'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/auth_models_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement**

Create `lib/data/api/api_exception.dart`:

```dart
/// Error thrown for any non-2xx backend response after decoding the server's
/// `{"error":{"code","message"}}` envelope (spec §8).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
```

Create `lib/data/api/auth_models.dart`:

```dart
/// Auth-session wire types. These come from the Phase 1 endpoints and use
/// snake_case keys (unlike the camelCase domain objects in model_json.dart).
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );
}

/// One garage the user belongs to. [permissions] is the server's source of
/// truth for UI gating; owners carry all 11 keys.
class Membership {
  const Membership({
    required this.garageId,
    required this.garageName,
    required this.role,
    required this.permissions,
    required this.isActive,
  });

  final String garageId;
  final String garageName;
  final String role;
  final List<String> permissions;
  final bool isActive;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        garageId: json['garage_id'] as String,
        garageName: json['garage_name'] as String,
        role: json['role'] as String,
        permissions: [for (final p in (json['permissions'] as List)) p as String],
        isActive: json['is_active'] as bool,
      );
}

/// Body of POST /api/auth/login and /api/auth/register.
class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.memberships,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final List<Membership> memberships;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        memberships: [
          for (final m in (json['memberships'] as List))
            Membership.fromJson(m as Map<String, dynamic>)
        ],
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/api/auth_models_test.dart`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/api_exception.dart lib/data/api/auth_models.dart test/api/auth_models_test.dart
git commit -m "feat: add ApiException and snake_case auth wire models"
```

---

### Task 3: Domain JSON codecs — item, customer, vehicle, staff, attendance, advance

**Files:**
- Create: `lib/data/api/model_json.dart`
- Test: `test/api/model_json_part1_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/model_json_part1_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/model_json.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/models/staff.dart';
import 'package:garage_manager/models/vehicle.dart';

void main() {
  group('MaintenanceItem codec', () {
    test('round-trips with integral floats from Go', () {
      const wire = {
        'id': 'it-1',
        'name': 'Engine Oil',
        'category': 'fluids',
        'unitPrice': 450,
        'quantity': 2,
        'unit': 'Ltr',
        'discountPercent': 0,
        'taxPercent': 18,
        'isLabour': false,
        'partNumber': null,
        'notes': null,
        'assignedStaffId': null,
      };
      final item = maintenanceItemFromJson(wire);
      expect(item.unitPrice, 450.0);
      expect(item.quantity, 2.0);
      expect(item.taxPercent, 18.0);
      expect(item.category, ItemCategory.fluids);
      final back = maintenanceItemToJson(item);
      expect(back['unitPrice'], 450.0);
      expect(back['category'], 'fluids');
    });

    test('round-trips assigned staff and part number', () {
      final item = MaintenanceItem(
        id: 'it-2',
        name: 'Brake Pads',
        category: ItemCategory.sparePart,
        unitPrice: 1200,
        partNumber: 'BP-99',
        assignedStaffId: 'st-1',
      );
      final back = maintenanceItemToJson(item);
      final reparsed = maintenanceItemFromJson(back);
      expect(reparsed.partNumber, 'BP-99');
      expect(reparsed.assignedStaffId, 'st-1');
      expect(reparsed.isLabour, isFalse);
    });
  });

  group('Customer codec', () {
    test('round-trips with nullable fields null on the wire', () {
      const wire = {
        'id': 'c-1',
        'name': 'Ravi Kumar',
        'phone': '9876543210',
        'whatsappNumber': null,
        'email': null,
        'address': null,
        'gstin': null,
        'notes': null,
        'createdAt': '2026-09-13T04:30:00Z',
      };
      final c = customerFromJson(wire);
      expect(c.whatsappNumber, isNull);
      expect(c.createdAt.isAtSameMomentAs(DateTime.parse('2026-09-13T04:30:00Z')), isTrue);
      final back = customerToJson(c);
      expect(back['name'], 'Ravi Kumar');
      expect(back['phone'], '9876543210');
      expect(back['createdAt'], isA<String>());
    });

    test('keeps populated optional fields', () {
      final c = Customer(
        id: 'c-2',
        name: 'Ada',
        phone: '1',
        email: 'a@b.c',
        gstin: 'GST123',
      );
      final reparsed = customerFromJson(customerToJson(c));
      expect(reparsed.email, 'a@b.c');
      expect(reparsed.gstin, 'GST123');
      expect(reparsed.effectiveWhatsApp, '1');
    });
  });

  group('Vehicle codec', () {
    test('parses day-grained lastServiceDate and nullable year', () {
      const wire = {
        'id': 'v-1',
        'customerId': 'c-1',
        'registrationNumber': 'MH 12 AB 1234',
        'make': 'Maruti Suzuki',
        'model': 'Swift',
        'variant': null,
        'year': 2021,
        'fuelType': 'diesel',
        'currentKm': 45000,
        'color': null,
        'chassisNumber': null,
        'engineNumber': null,
        'createdAt': '2026-09-13T04:30:00Z',
        'lastServiceDate': '2026-09-01',
      };
      final v = vehicleFromJson(wire);
      expect(v.fuelType, FuelType.diesel);
      expect(v.year, 2021);
      expect(v.lastServiceDate, DateTime(2026, 9, 1));
      final back = vehicleToJson(v);
      expect(back['lastServiceDate'], '2026-09-01');
      expect(back['fuelType'], 'diesel');
    });

    test('round-trips nulls for year and lastServiceDate', () {
      final v = Vehicle(
        id: 'v-2',
        customerId: 'c-1',
        registrationNumber: 'AP 9 X 1',
        make: 'Hyundai',
        model: 'Creta',
        currentKm: 100,
      );
      final back = vehicleToJson(v);
      expect(back['year'], isNull);
      expect(back['lastServiceDate'], isNull);
      final reparsed = vehicleFromJson(back);
      expect(reparsed.year, isNull);
      expect(reparsed.lastServiceDate, isNull);
      expect(reparsed.fuelType, FuelType.petrol);
    });
  });

  group('Staff codec', () {
    test('round-trips with day-grained joiningDate and role enum', () {
      final s = Staff(
        id: 'st-1',
        name: 'Bala',
        role: StaffRole.headMechanic,
        phone: '999',
        monthlySalary: 22000,
        joiningDate: DateTime(2026, 8, 15),
      );
      final back = staffToJson(s);
      expect(back['role'], 'headMechanic');
      expect(back['joiningDate'], '2026-08-15');
      expect(back['monthlySalary'], 22000.0);
      final reparsed = staffFromJson({
        ...back,
        'createdAt': '2026-09-13T04:30:00Z',
      });
      expect(reparsed.role, StaffRole.headMechanic);
      expect(reparsed.joiningDate, DateTime(2026, 8, 15));
      expect(reparsed.isActive, isTrue);
    });
  });

  group('Attendance + advance codecs', () {
    test('attendance round-trips status and day date', () {
      final r = AttendanceRecord(
        id: 'a-1',
        staffId: 'st-1',
        date: DateTime(2026, 9, 12),
        status: AttendanceStatus.halfDay,
        notes: 'left early',
      );
      final back = attendanceToJson(r);
      expect(back['status'], 'halfDay');
      expect(back['date'], '2026-09-12');
      final reparsed = attendanceFromJson(back);
      expect(reparsed.status, AttendanceStatus.halfDay);
      expect(reparsed.date, DateTime(2026, 9, 12));
    });

    test('advance round-trips amount and deducted flag', () {
      final a = SalaryAdvance(
        id: 'adv-1',
        staffId: 'st-1',
        amount: 1500,
        date: DateTime(2026, 9, 3),
        reason: 'family',
      );
      final back = salaryAdvanceToJson(a);
      expect(back['amount'], 1500.0);
      expect(back['isDeducted'], isFalse);
      final reparsed = salaryAdvanceFromJson(back);
      expect(reparsed.amount, 1500.0);
      expect(reparsed.isDeducted, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/model_json_part1_test.dart`
Expected: FAIL (`model_json.dart` does not exist).

- [ ] **Step 3: Implement the codec file with these six models**

Create `lib/data/api/model_json.dart`. The header comment + helpers are the file's foundation — later tasks append to the same file:

```dart
import '../../models/customer.dart';
import '../../models/maintenance_item.dart';
import '../../models/staff.dart';
import '../../models/vehicle.dart';

/// Hand-written JSON codecs mapping the Dart models onto the Go backend's
/// wire format (spec §7). Domain objects are camelCase; auth and settings
/// payloads are snake_case (auth_models.dart / profile+config below).
///
/// Rules (see plan conventions for the verified facts):
/// - Enums travel as their Dart `.name` — identical to the Go TEXT values.
/// - Instants: written `.toUtc().toIso8601String()`, read back `.toLocal()`
///   so dashboard day comparisons see the garage's wall clock.
/// - Day-grained dates (joiningDate, attendance/advance/expense dates,
///   lastServiceDate) are `YYYY-MM-DD` LOCAL calendar strings.
/// - Numerics read via `(x as num)` because Go marshals integral floats
///   (`100`, not `100.0`).
library;

String _instant(DateTime d) => d.toUtc().toIso8601String();
DateTime _instantFrom(String s) => DateTime.parse(s).toLocal();

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dayFrom(String s) => DateTime.parse(s);

double _dbl(dynamic v) => (v as num).toDouble();
int _int(dynamic v) => (v as num).toInt();

String? _str(Map<String, dynamic> j, String key) => j[key] as String?;

// NOTE: the _instantOpt helper is intentionally NOT here — it has no use
// until Task 4's job-card/invoice codecs and would trip the unused_element
// lint at this task's analyze gate. Task 4 adds it alongside its first use.
// ----- MaintenanceItem -----

Map<String, dynamic> maintenanceItemToJson(MaintenanceItem it) => {
      'id': it.id,
      'name': it.name,
      'category': it.category.name,
      'unitPrice': it.unitPrice,
      'quantity': it.quantity,
      'unit': it.unit,
      'discountPercent': it.discountPercent,
      'taxPercent': it.taxPercent,
      'isLabour': it.isLabour,
      'partNumber': it.partNumber,
      'notes': it.notes,
      'assignedStaffId': it.assignedStaffId,
    };

MaintenanceItem maintenanceItemFromJson(Map<String, dynamic> j) =>
    MaintenanceItem(
      id: j['id'] as String,
      name: j['name'] as String,
      category: ItemCategory.values.byName(j['category'] as String),
      unitPrice: _dbl(j['unitPrice']),
      quantity: _dbl(j['quantity']),
      unit: j['unit'] as String,
      discountPercent: _dbl(j['discountPercent']),
      taxPercent: _dbl(j['taxPercent']),
      isLabour: j['isLabour'] as bool,
      partNumber: _str(j, 'partNumber'),
      notes: _str(j, 'notes'),
      assignedStaffId: _str(j, 'assignedStaffId'),
    );

// ----- Customer -----

Map<String, dynamic> customerToJson(Customer c) => {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
      'whatsappNumber': c.whatsappNumber,
      'email': c.email,
      'address': c.address,
      'gstin': c.gstin,
      'notes': c.notes,
      'createdAt': _instant(c.createdAt),
    };

Customer customerFromJson(Map<String, dynamic> j) => Customer(
      id: j['id'] as String,
      name: j['name'] as String,
      phone: j['phone'] as String,
      whatsappNumber: _str(j, 'whatsappNumber'),
      email: _str(j, 'email'),
      address: _str(j, 'address'),
      gstin: _str(j, 'gstin'),
      notes: _str(j, 'notes'),
      createdAt: _instantFrom(j['createdAt'] as String),
    );

// ----- Vehicle -----

Map<String, dynamic> vehicleToJson(Vehicle v) => {
      'id': v.id,
      'customerId': v.customerId,
      'registrationNumber': v.registrationNumber,
      'make': v.make,
      'model': v.model,
      'variant': v.variant,
      'year': v.year,
      'fuelType': v.fuelType.name,
      'currentKm': v.currentKm,
      'color': v.color,
      'chassisNumber': v.chassisNumber,
      'engineNumber': v.engineNumber,
      'lastServiceDate': v.lastServiceDate == null
          ? null
          : _day(v.lastServiceDate!),
    };

Vehicle vehicleFromJson(Map<String, dynamic> j) => Vehicle(
      id: j['id'] as String,
      customerId: j['customerId'] as String,
      registrationNumber: j['registrationNumber'] as String,
      make: j['make'] as String,
      model: j['model'] as String,
      variant: _str(j, 'variant'),
      year: (j['year'] as num?)?.toInt(),
      fuelType: FuelType.values.byName(j['fuelType'] as String),
      currentKm: _int(j['currentKm']),
      color: _str(j, 'color'),
      chassisNumber: _str(j, 'chassisNumber'),
      engineNumber: _str(j, 'engineNumber'),
      createdAt: _instantFrom(j['createdAt'] as String),
      lastServiceDate:
          _str(j, 'lastServiceDate') == null ? null : _dayFrom(_str(j, 'lastServiceDate')!),
    );

// ----- Staff -----

Map<String, dynamic> staffToJson(Staff s) => {
      'id': s.id,
      'name': s.name,
      'role': s.role.name,
      'phone': s.phone,
      'email': s.email,
      'monthlySalary': s.monthlySalary,
      'joiningDate': _day(s.joiningDate),
      'isActive': s.isActive,
      'address': s.address,
      'emergencyContact': s.emergencyContact,
    };

Staff staffFromJson(Map<String, dynamic> j) => Staff(
      id: j['id'] as String,
      name: j['name'] as String,
      role: StaffRole.values.byName(j['role'] as String),
      phone: j['phone'] as String,
      email: _str(j, 'email'),
      monthlySalary: _dbl(j['monthlySalary']),
      joiningDate: _dayFrom(j['joiningDate'] as String),
      isActive: j['isActive'] as bool,
      address: _str(j, 'address'),
      emergencyContact: _str(j, 'emergencyContact'),
    );

// ----- Attendance / advance -----

Map<String, dynamic> attendanceToJson(AttendanceRecord r) => {
      'id': r.id,
      'staffId': r.staffId,
      'date': _day(r.date),
      'status': r.status.name,
      'notes': r.notes,
    };

AttendanceRecord attendanceFromJson(Map<String, dynamic> j) => AttendanceRecord(
      id: j['id'] as String,
      staffId: j['staffId'] as String,
      date: _dayFrom(j['date'] as String),
      status: AttendanceStatus.values.byName(j['status'] as String),
      notes: _str(j, 'notes'),
    );

Map<String, dynamic> salaryAdvanceToJson(SalaryAdvance a) => {
      'id': a.id,
      'staffId': a.staffId,
      'amount': a.amount,
      'date': _day(a.date),
      'reason': a.reason,
      'isDeducted': a.isDeducted,
    };

SalaryAdvance salaryAdvanceFromJson(Map<String, dynamic> j) => SalaryAdvance(
      id: j['id'] as String,
      staffId: j['staffId'] as String,
      amount: _dbl(j['amount']),
      date: _dayFrom(j['date'] as String),
      reason: _str(j, 'reason'),
      isDeducted: j['isDeducted'] as bool,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/api/model_json_part1_test.dart`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/model_json.dart test/api/model_json_part1_test.dart
git commit -m "feat: JSON codecs for item, customer, vehicle, staff, attendance, advance"
```

---

### Task 4: Domain JSON codecs — job card, quotation, invoice, payment, expense, catalog

**Files:**
- Modify: `lib/data/api/model_json.dart` (append)
- Test: `test/api/model_json_part2_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/model_json_part2_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/model_json.dart';
import 'package:garage_manager/models/expense.dart';
import 'package:garage_manager/models/invoice.dart';
import 'package:garage_manager/models/job_card.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/models/payment.dart';
import 'package:garage_manager/models/quotation.dart';

MaintenanceItem item(String id) => MaintenanceItem(
      id: id,
      name: 'Wash',
      category: ItemCategory.custom,
      unitPrice: 300,
    );

void main() {
  group('JobCard codec', () {
    test('round-trips checklist, complaints, status and embedded items', () {
      final now = DateTime.parse('2026-09-13T04:30:00Z');
      final jc = JobCard(
        id: 'jc-1',
        jobCardNumber: 'JC-1001',
        customerId: 'c-1',
        vehicleId: 'v-1',
        customerComplaints: ['Noise', 'AC weak'],
        fuelLevel: '3/4',
        kmReading: 46000,
        assignedStaffId: 'st-1',
        status: JobStatus.inProgress,
        promisedDeliveryDate: now.add(const Duration(hours: 6)),
        createdAt: now,
        completedAt: null,
        items: [item('it-1')],
      );
      final back = jobCardToJson(jc);
      expect(back['status'], 'inProgress');
      expect(back['promisedDeliveryDate'], isA<String>());
      final reparsed = jobCardFromJson(back);
      expect(reparsed.customerComplaints, ['Noise', 'AC weak']);
      expect(reparsed.inspectionChecklist, JobCard.defaultChecklist);
      expect(reparsed.status, JobStatus.inProgress);
      expect(reparsed.items.single.id, 'it-1');
      expect(reparsed.completedAt, isNull);
    });

    test('round-trips completedAt instant through toLocal', () {
      final jc = JobCard(
        id: 'jc-2',
        jobCardNumber: 'JC-1002',
        customerId: 'c-1',
        vehicleId: 'v-1',
        customerComplaints: const [],
        kmReading: 1,
        promisedDeliveryDate: DateTime.parse('2026-09-13T04:30:00Z'),
        createdAt: DateTime.parse('2026-09-13T04:30:00Z'),
        completedAt: DateTime.parse('2026-09-13T09:30:00Z'),
      );
      final reparsed = jobCardFromJson(jobCardToJson(jc));
      expect(
        reparsed.completedAt!.isAtSameMomentAs(DateTime.parse('2026-09-13T09:30:00Z')),
        isTrue,
      );
    });
  });

  group('Quotation codec', () {
    test('round-trips numbers, status and validity', () {
      final now = DateTime.parse('2026-09-13T04:30:00Z');
      final q = Quotation(
        id: 'q-1',
        quotationNumber: 'EST-1001',
        customerId: 'c-1',
        vehicleId: 'v-1',
        kmReading: 12000,
        items: [item('it-1')],
        overallDiscount: 100,
        taxPercent: 18,
        validityDays: 15,
        status: QuotationStatus.approved,
        notes: 'est',
        createdAt: now,
        validUntil: now.add(const Duration(days: 15)),
      );
      final back = quotationToJson(q);
      expect(back['status'], 'approved');
      expect(back.containsKey('validUntil'), isFalse);
      final reparsed = quotationFromJson({
        ...back,
        'validUntil': _iso(now.add(const Duration(days: 15))),
        'createdAt': _iso(now),
      });
      expect(reparsed.overallDiscount, 100.0);
      expect(reparsed.validityDays, 15);
      expect(reparsed.status, QuotationStatus.approved);
    });
  });

  group('Invoice + payment codec', () {
    test('round-trips embedded payments and nullable instants', () {
      final now = DateTime.parse('2026-09-13T04:30:00Z');
      final inv = Invoice(
        id: 'inv-1',
        invoiceNumber: 'INV-2026-1',
        jobCardId: 'jc-1',
        customerId: 'c-1',
        vehicleId: 'v-1',
        kmReading: 46000,
        items: [item('it-1')],
        discountAmount: 50,
        taxPercent: 18,
        payments: [
          Payment(
            id: 'p-1',
            invoiceId: 'inv-1',
            customerId: 'c-1',
            amount: 500,
            mode: PaymentMode.upi,
            transactionRef: 'UTR1',
            paymentDate: now,
          ),
        ],
        invoiceDate: now,
        dueDate: now.add(const Duration(days: 7)),
        cancelledAt: null,
        notes: 'n',
        termsAndConditions: 't',
      );
      final back = invoiceToJson(inv);
      expect(back.containsKey('payments'), isFalse);
      expect(back['dueDate'], isA<String>());
      final reparsed = invoiceFromJson({
        ...back,
        'createdAt': _iso(now),
        'payments': [
          {
            'id': 'p-1',
            'invoiceId': 'inv-1',
            'customerId': 'c-1',
            'amount': 500,
            'mode': 'upi',
            'transactionRef': 'UTR1',
            'paymentDate': _iso(now),
            'notes': null,
            'receivedBy': null,
          }
        ],
      });
      expect(reparsed.payments.single.amount, 500.0);
      expect(reparsed.payments.single.mode, PaymentMode.upi);
      expect(reparsed.status, InvoiceStatus.pending);
      expect(reparsed.dueDate!.isAtSameMomentAs(DateTime.parse(now.add(const Duration(days: 7)).toUtc().toIso8601String())), isTrue);
    });

    test('cancelled invoice parses cancelledAt and derives status', () {
      const wire = {
        'id': 'inv-2',
        'invoiceNumber': 'INV-2026-2',
        'jobCardId': null,
        'customerId': 'c-1',
        'vehicleId': 'v-1',
        'kmReading': 10,
        'items': [],
        'discountAmount': 0,
        'taxPercent': 18,
        'invoiceDate': '2026-09-12T04:30:00Z',
        'dueDate': null,
        'cancelledAt': '2026-09-13T05:00:00Z',
        'notes': null,
        'termsAndConditions': null,
        'createdAt': '2026-09-12T04:30:00Z',
        'payments': [],
      };
      final inv = invoiceFromJson(wire);
      expect(inv.cancelledAt, isNotNull);
      expect(inv.status, InvoiceStatus.cancelled);
      expect(inv.balanceDue, 0);
    });

    test('payment codec round-trips mode and refs', () {
      final p = Payment(
        id: 'p-2',
        invoiceId: 'inv-1',
        customerId: 'c-1',
        amount: 1200.5,
        mode: PaymentMode.cheque,
        notes: 'chq 42',
        receivedBy: 'Cashier',
        paymentDate: DateTime.parse('2026-09-13T04:30:00Z'),
      );
      final back = paymentToJson(p);
      expect(back['mode'], 'cheque');
      expect(back.containsKey('paymentDate'), isFalse);
      final reparsed = paymentFromJson({
        ...back,
        'paymentDate': _iso(p.paymentDate),
      });
      expect(reparsed.amount, 1200.5);
      expect(reparsed.receivedBy, 'Cashier');
    });
  });

  group('Expense codec', () {
    test('round-trips day-grained expenseDate and category', () {
      final e = GarageExpense(
        id: 'e-1',
        title: 'Rent',
        category: ExpenseCategory.rent,
        amount: 15000,
        expenseDate: DateTime(2026, 9, 1),
        paymentMode: PaymentMode.bankTransfer,
        vendorName: 'Landlord',
      );
      final back = expenseToJson(e);
      expect(back['category'], 'rent');
      expect(back['expenseDate'], '2026-09-01');
      final reparsed = expenseFromJson(back);
      expect(reparsed.expenseDate, DateTime(2026, 9, 1));
      expect(reparsed.paymentMode, PaymentMode.bankTransfer);
      expect(reparsed.receiptPath, isNull);
    });
  });

  group('Catalog item codec', () {
    test('parses read-only catalog rows', () {
      const wire = {
        'id': 'cat-1',
        'name': 'Engine Oil 1L',
        'category': 'fluids',
        'unitPrice': 450,
        'unit': 'Bottle',
        'isLabour': false,
        'partNumber': null,
        'notes': null,
        'createdAt': '2026-09-13T04:30:00Z',
      };
      final c = catalogItemFromJson(wire);
      expect(c.name, 'Engine Oil 1L');
      expect(c.unitPrice, 450.0);
      expect(c.isLabour, isFalse);
    });
  });
}

String _iso(DateTime d) => d.toUtc().toIso8601String();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/model_json_part2_test.dart`
Expected: FAIL (functions undefined).

- [ ] **Step 3: Implement — append to `lib/data/api/model_json.dart`**

Update the import block at the top to add:

```dart
import '../../models/expense.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../models/payment.dart';
import '../../models/quotation.dart';
```

Then append at the end of the file (the `_instantOpt` helper lands here, where it gains its first use — adding it earlier would trip the unused_element lint):

```dart
// ----- optional-instant helper (first use below) -----

DateTime? _instantOpt(Map<String, dynamic> j, String key) =>
    j[key] == null ? null : _instantFrom(j[key] as String);

// ----- JobCard -----

Map<String, dynamic> jobCardToJson(JobCard jc) => {
      'id': jc.id,
      'jobCardNumber': jc.jobCardNumber,
      'customerId': jc.customerId,
      'vehicleId': jc.vehicleId,
      'customerComplaints': jc.customerComplaints,
      'inspectionChecklist': jc.inspectionChecklist,
      'fuelLevel': jc.fuelLevel,
      'kmReading': jc.kmReading,
      'assignedStaffId': jc.assignedStaffId,
      'status': jc.status.name,
      'promisedDeliveryDate': _instant(jc.promisedDeliveryDate),
      'completedAt': jc.completedAt == null ? null : _instant(jc.completedAt!),
      'items': [for (final it in jc.items) maintenanceItemToJson(it)],
      'estimatedCostNote': jc.estimatedCostNote,
      'supervisorNotes': jc.supervisorNotes,
    };

JobCard jobCardFromJson(Map<String, dynamic> j) => JobCard(
      id: j['id'] as String,
      jobCardNumber: j['jobCardNumber'] as String,
      customerId: j['customerId'] as String,
      vehicleId: j['vehicleId'] as String,
      customerComplaints: [
        for (final s in (j['customerComplaints'] as List)) s as String
      ],
      inspectionChecklist: (j['inspectionChecklist'] as Map?)?.cast<String, bool>(),
      fuelLevel: j['fuelLevel'] as String,
      kmReading: _int(j['kmReading']),
      assignedStaffId: _str(j, 'assignedStaffId'),
      status: JobStatus.values.byName(j['status'] as String),
      promisedDeliveryDate: _instantFrom(j['promisedDeliveryDate'] as String),
      createdAt: _instantFrom(j['createdAt'] as String),
      completedAt: _instantOpt(j, 'completedAt'),
      items: [
        for (final it in (j['items'] as List? ?? []))
          maintenanceItemFromJson(it as Map<String, dynamic>)
      ],
      estimatedCostNote: _str(j, 'estimatedCostNote'),
      supervisorNotes: _str(j, 'supervisorNotes'),
    );

// ----- Quotation -----

Map<String, dynamic> quotationToJson(Quotation q) => {
      'id': q.id,
      'quotationNumber': q.quotationNumber,
      'customerId': q.customerId,
      'vehicleId': q.vehicleId,
      'kmReading': q.kmReading,
      'items': [for (final it in q.items) maintenanceItemToJson(it)],
      'overallDiscount': q.overallDiscount,
      'taxPercent': q.taxPercent,
      'validityDays': q.validityDays,
      'status': q.status.name,
      'notes': q.notes,
    };

Quotation quotationFromJson(Map<String, dynamic> j) => Quotation(
      id: j['id'] as String,
      quotationNumber: j['quotationNumber'] as String,
      customerId: j['customerId'] as String,
      vehicleId: j['vehicleId'] as String,
      kmReading: _int(j['kmReading']),
      items: [
        for (final it in (j['items'] as List? ?? []))
          maintenanceItemFromJson(it as Map<String, dynamic>)
      ],
      overallDiscount: _dbl(j['overallDiscount']),
      taxPercent: _dbl(j['taxPercent']),
      validityDays: _int(j['validityDays']),
      status: QuotationStatus.values.byName(j['status'] as String),
      notes: _str(j, 'notes'),
      createdAt: _instantFrom(j['createdAt'] as String),
      validUntil: _instantFrom(j['validUntil'] as String),
    );

// ----- Payment -----

Map<String, dynamic> paymentToJson(Payment p) => {
      'id': p.id,
      'invoiceId': p.invoiceId,
      'customerId': p.customerId,
      'amount': p.amount,
      'mode': p.mode.name,
      'transactionRef': p.transactionRef,
      'notes': p.notes,
      'receivedBy': p.receivedBy,
    };

Payment paymentFromJson(Map<String, dynamic> j) => Payment(
      id: j['id'] as String,
      invoiceId: j['invoiceId'] as String,
      customerId: _str(j, 'customerId'),
      amount: _dbl(j['amount']),
      mode: PaymentMode.values.byName(j['mode'] as String),
      transactionRef: _str(j, 'transactionRef'),
      paymentDate: _instantFrom(j['paymentDate'] as String),
      notes: _str(j, 'notes'),
      receivedBy: _str(j, 'receivedBy'),
    );

// ----- Invoice -----

Map<String, dynamic> invoiceToJson(Invoice inv) => {
      'id': inv.id,
      'invoiceNumber': inv.invoiceNumber,
      'jobCardId': inv.jobCardId,
      'customerId': inv.customerId,
      'vehicleId': inv.vehicleId,
      'kmReading': inv.kmReading,
      'items': [for (final it in inv.items) maintenanceItemToJson(it)],
      'discountAmount': inv.discountAmount,
      'taxPercent': inv.taxPercent,
      'invoiceDate': _instant(inv.invoiceDate),
      'dueDate': inv.dueDate == null ? null : _instant(inv.dueDate!),
      'cancelledAt': inv.cancelledAt == null ? null : _instant(inv.cancelledAt!),
      'notes': inv.notes,
      'termsAndConditions': inv.termsAndConditions,
    };

Invoice invoiceFromJson(Map<String, dynamic> j) => Invoice(
      id: j['id'] as String,
      invoiceNumber: j['invoiceNumber'] as String,
      jobCardId: _str(j, 'jobCardId'),
      customerId: j['customerId'] as String,
      vehicleId: j['vehicleId'] as String,
      kmReading: _int(j['kmReading']),
      items: [
        for (final it in (j['items'] as List? ?? []))
          maintenanceItemFromJson(it as Map<String, dynamic>)
      ],
      discountAmount: _dbl(j['discountAmount']),
      taxPercent: _dbl(j['taxPercent']),
      payments: [
        for (final p in (j['payments'] as List? ?? []))
          paymentFromJson(p as Map<String, dynamic>)
      ],
      invoiceDate: _instantFrom(j['invoiceDate'] as String),
      dueDate: _instantOpt(j, 'dueDate'),
      cancelledAt: _instantOpt(j, 'cancelledAt'),
      notes: _str(j, 'notes'),
      termsAndConditions: _str(j, 'termsAndConditions'),
    );

// ----- Expense -----

Map<String, dynamic> expenseToJson(GarageExpense e) => {
      'id': e.id,
      'title': e.title,
      'category': e.category.name,
      'amount': e.amount,
      'expenseDate': _day(e.expenseDate),
      'paymentMode': e.paymentMode.name,
      'vendorName': e.vendorName,
      'notes': e.notes,
      'receiptPath': e.receiptPath,
    };

GarageExpense expenseFromJson(Map<String, dynamic> j) => GarageExpense(
      id: j['id'] as String,
      title: j['title'] as String,
      category: ExpenseCategory.values.byName(j['category'] as String),
      amount: _dbl(j['amount']),
      expenseDate: _dayFrom(j['expenseDate'] as String),
      paymentMode: PaymentMode.values.byName(j['paymentMode'] as String),
      vendorName: _str(j, 'vendorName'),
      notes: _str(j, 'notes'),
      receiptPath: _str(j, 'receiptPath'),
    );

// ----- Catalog -----

MaintenanceItem catalogItemFromJson(Map<String, dynamic> j) => MaintenanceItem(
      id: j['id'] as String,
      name: j['name'] as String,
      category: ItemCategory.values.byName(j['category'] as String),
      unitPrice: _dbl(j['unitPrice']),
      unit: j['unit'] as String,
      isLabour: j['isLabour'] as bool,
      partNumber: _str(j, 'partNumber'),
      notes: _str(j, 'notes'),
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/api/`
Expected: PASS (part1 + part2 + auth models).

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/model_json.dart test/api/model_json_part2_test.dart
git commit -m "feat: JSON codecs for job card, quotation, invoice, payment, expense, catalog"
```

---

### Task 5: Settings codecs — GarageProfile + AppConfig (snake_case)

**Files:**
- Modify: `lib/data/api/model_json.dart` (append)
- Test: `test/api/model_json_settings_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/model_json_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/model_json.dart';

const settingsWire = {
  'garage_id': 'g-1',
  'profile': {
    'name': 'Nexory Garage & Body Shop',
    'tagline': 'Body repair done right',
    'address_line': '12 MG Road',
    'city': 'Pune',
    'phone': '020-1234',
    'email': 'hello@nexory.in',
    'gstin': '27AAAAA0000A1Z5',
    'upi_id': 'nexory@upi',
  },
  'default_tax_percent': 18,
  'tax_percent_options': [0, 12, 18, 28],
  'invoice_due_days': 7,
  'quotation_validity_options': [7, 15, 30],
  'working_days_per_month': 26,
  'promised_delivery_hours': 6,
  'invoice_notes': 'Thanks!',
  'invoice_terms': 'Warranty 30 days.',
  'default_received_by': 'Cashier',
};

void main() {
  test('profile parses snake_case keys', () {
    final p = profileFromJson(settingsWire['profile'] as Map<String, dynamic>);
    expect(p.name, 'Nexory Garage & Body Shop');
    expect(p.addressLine, '12 MG Road');
    expect(p.upiId, 'nexory@upi');
    expect(p.gstin, '27AAAAA0000A1Z5');
  });

  test('config parses snake_case keys with integral doubles', () {
    final c = appConfigFromSettings(settingsWire);
    expect(c.defaultTaxPercent, 18.0);
    expect(c.taxPercentOptions, [0.0, 12.0, 18.0, 28.0]);
    expect(c.invoiceDueDays, 7);
    expect(c.quotationValidityOptions, [7, 15, 30]);
    expect(c.workingDaysPerMonth, 26);
    expect(c.promisedDeliveryHours, 6);
    expect(c.invoiceNotes, 'Thanks!');
    expect(c.defaultReceivedBy, 'Cashier');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/model_json_settings_test.dart`
Expected: FAIL (functions undefined).

- [ ] **Step 3: Implement — append to `lib/data/api/model_json.dart`**

Add to the import block at the top:

```dart
import '../app_config.dart';
import '../garage_profile.dart';
```

Append at the end of the file:

```dart
// ----- Garage settings (snake_case, Phase 1 wire format) -----

GarageProfile profileFromJson(Map<String, dynamic> j) => GarageProfile(
      name: j['name'] as String,
      tagline: j['tagline'] as String,
      addressLine: j['address_line'] as String,
      city: j['city'] as String,
      phone: j['phone'] as String,
      email: j['email'] as String,
      gstin: j['gstin'] as String,
      upiId: j['upi_id'] as String,
    );

AppConfig appConfigFromSettings(Map<String, dynamic> j) => AppConfig(
      defaultTaxPercent: _dbl(j['default_tax_percent']),
      taxPercentOptions: [
        for (final v in (j['tax_percent_options'] as List)) _dbl(v)
      ],
      invoiceDueDays: _int(j['invoice_due_days']),
      quotationValidityOptions: [
        for (final v in (j['quotation_validity_options'] as List)) _int(v)
      ],
      workingDaysPerMonth: _int(j['working_days_per_month']),
      promisedDeliveryHours: _int(j['promised_delivery_hours']),
      invoiceNotes: j['invoice_notes'] as String,
      invoiceTerms: j['invoice_terms'] as String,
      defaultReceivedBy: j['default_received_by'] as String,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/api/model_json_settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/model_json.dart test/api/model_json_settings_test.dart
git commit -m "feat: snake_case codecs for garage profile and settings config"
```

---

### Task 6: AuthSession — token/pref storage behind fakes, login/register/refresh/signOut

**Files:**
- Create: `lib/data/api/auth_session.dart`
- Test: `test/api/auth_session_test.dart`

Design: `AuthSession` depends on two tiny interfaces (`TokenStore`, `PrefStore`) so unit tests use in-memory fakes — flutter_secure_storage/shared_preferences cannot run in pure Dart tests. Auth endpoints are called with a raw `http.Client` (injectable for tests) so AuthSession never depends on ApiClient (ApiClient depends on AuthSession, one direction only).

- [ ] **Step 1: Write the failing test**

Create `test/api/auth_session_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/api/auth_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeTokenStore implements TokenStore {
  final Map<String, String> backing = {};
  int deleteAllCalls = 0;

  @override
  Future<void> delete(String key) async => backing.remove(key);

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
    backing.clear();
  }

  @override
  Future<String?> read(String key) async => backing[key];

  @override
  Future<void> write(String key, String value) async => backing[key] = value;
}

class FakePrefStore implements PrefStore {
  final Map<String, String> backing = {};

  @override
  Future<String?> read(String key) async => backing[key];

  @override
  Future<void> remove(String key) async => backing.remove(key);

  @override
  Future<void> write(String key, String value) async => backing[key] = value;
}

const loginBody = {
  'access_token': 'at-1',
  'refresh_token': 'rt-1',
  'user': {'id': 'u-1', 'email': 'a@b.c', 'name': 'Ada'},
  'memberships': [
    {
      'garage_id': 'g-1',
      'garage_name': 'Nexory',
      'role': 'owner',
      'permissions': ['customers.manage', 'invoices.manage'],
      'is_active': true,
    }
  ],
};

void main() {
  group('AuthSession.login', () {
    test('posts credentials, persists url/tokens/garage, exposes membership',
        () async {
      final tokens = FakeTokenStore();
      final prefs = FakePrefStore();
      http.Request? captured;
      final session = AuthSession(
        tokenStore: tokens,
        prefStore: prefs,
        client: MockClient((req) async {
          captured = req;
          return http.Response(jsonEncode(loginBody), 200);
        }),
      );

      final res = await session.login('http://localhost:8080', 'a@b.c', 'pw');

      expect(captured!.url.toString(), 'http://localhost:8080/api/auth/login');
      expect(jsonDecode(captured!.body), {'email': 'a@b.c', 'password': 'pw'});
      expect(res.accessToken, 'at-1');
      expect(session.activeMembership!.garageId, 'g-1');
      expect(session.currentUser!.email, 'a@b.c');
      expect(session.garageId, 'g-1');
      expect(prefs.backing['server_url'], 'http://localhost:8080');
      expect(prefs.backing['garage_id'], 'g-1');
      expect(tokens.backing['access_token'], 'at-1');
      expect(tokens.backing['refresh_token'], 'rt-1');
    });

    test('surfaces the error envelope as ApiException', () async {
      final session = AuthSession(
        tokenStore: FakeTokenStore(),
        prefStore: FakePrefStore(),
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'error': {'code': 'unauthorized', 'message': 'invalid email or password'}
            }),
            401)),
      );

      await expectLater(
        session.login('http://localhost:8080', 'a@b.c', 'bad'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'unauthorized')),
      );
    });
  });

  group('AuthSession.loadStored', () {
    test('returns null when nothing persisted', () async {
      final session = AuthSession(
          tokenStore: FakeTokenStore(), prefStore: FakePrefStore());
      expect(await session.loadStored(), isNull);
    });

    test('restores url/garage/tokens when all four keys exist', () async {
      final tokens = FakeTokenStore();
      final prefs = FakePrefStore();
      prefs.backing['server_url'] = 'http://lan:8080';
      prefs.backing['garage_id'] = 'g-1';
      tokens.backing['access_token'] = 'at-old';
      tokens.backing['refresh_token'] = 'rt-old';
      final session = AuthSession(tokenStore: tokens, prefStore: prefs);

      final stored = await session.loadStored();

      expect(stored, isNotNull);
      expect(stored!.serverUrl, 'http://lan:8080');
      expect(stored.garageId, 'g-1');
      expect(session.accessToken, 'at-old');
    });
  });

  group('AuthSession.refreshAccess', () {
    test('rotates both tokens and persists them', () async {
      final tokens = FakeTokenStore();
      final prefs = FakePrefStore();
      prefs.backing['server_url'] = 'http://lan:8080';
      tokens.backing['refresh_token'] = 'rt-old';
      final session = AuthSession(
        tokenStore: tokens,
        prefStore: prefs,
        client: MockClient((req) async {
          expect(req.url.path, '/api/auth/refresh');
          expect(jsonDecode(req.body)['refresh_token'], 'rt-old');
          return http.Response(
              jsonEncode({'access_token': 'at-2', 'refresh_token': 'rt-2'}), 200);
        }),
      );
      await session.loadStored();

      final ok = await session.refreshAccess();

      expect(ok, isTrue);
      expect(session.accessToken, 'at-2');
      expect(tokens.backing['access_token'], 'at-2');
      expect(tokens.backing['refresh_token'], 'rt-2');
    });

    test('returns false without throwing when refresh rejected', () async {
      final tokens = FakeTokenStore();
      tokens.backing['refresh_token'] = 'rt-dead';
      final prefs = FakePrefStore();
      prefs.backing['server_url'] = 'http://lan:8080';
      final session = AuthSession(
        tokenStore: tokens,
        prefStore: prefs,
        client: MockClient((req) async => http.Response('gone', 401)),
      );
      await session.loadStored();

      expect(await session.refreshAccess(), isFalse);
    });
  });

  group('AuthSession.signOut', () {
    test('best-effort logout then clears all storage', () async {
      final tokens = FakeTokenStore();
      final prefs = FakePrefStore();
      prefs.backing['server_url'] = 'http://lan:8080';
      prefs.backing['garage_id'] = 'g-1';
      tokens.backing['access_token'] = 'at';
      tokens.backing['refresh_token'] = 'rt';
      var logoutCalls = 0;
      final session = AuthSession(
        tokenStore: tokens,
        prefStore: prefs,
        client: MockClient((req) async {
          if (req.url.path == '/api/auth/logout') {
            logoutCalls++;
            expect(jsonDecode(req.body)['refresh_token'], 'rt');
            return http.Response('', 204);
          }
          return http.Response('unexpected', 500);
        }),
      );
      await session.loadStored();

      await session.signOut();

      expect(logoutCalls, 1);
      expect(tokens.backing, isEmpty);
      expect(tokens.deleteAllCalls, 1);
      expect(prefs.backing, isEmpty);
      expect(session.activeMembership, isNull);
    });

    test('clears storage even when the logout call fails', () async {
      final tokens = FakeTokenStore();
      tokens.backing['access_token'] = 'at';
      tokens.backing['refresh_token'] = 'rt';
      final prefs = FakePrefStore();
      prefs.backing['server_url'] = 'http://lan:8080';
      final session = AuthSession(
        tokenStore: tokens,
        prefStore: prefs,
        client: MockClient((req) async => throw Exception('offline')),
      );
      await session.loadStored();

      await session.signOut();

      expect(tokens.backing, isEmpty);
      expect(prefs.backing, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/auth_session_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement**

Create `lib/data/api/auth_session.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'auth_models.dart';

/// Persists access/refresh tokens (secrets — secure storage) and the
/// server URL / active garage id (non-secrets — shared prefs).
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Small async string-map facade over SharedPreferences.
abstract class PrefStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class SharedPrefStore implements PrefStore {
  const SharedPrefStore();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

/// Everything loadStored() restored, enough to attempt an authenticated
/// bootstrap.
class StoredLogin {
  const StoredLogin({required this.serverUrl, required this.garageId});

  final String serverUrl;
  final String garageId;
}

/// Owns the logged-in session: tokens, active garage, and the auth endpoints
/// themselves. ApiClient depends on this for per-request credentials; this
/// class never depends on ApiClient (auth calls use a raw http client).
class AuthSession {
  AuthSession({
    TokenStore? tokenStore,
    PrefStore? prefStore,
    http.Client? client,
  })  : _tokens = tokenStore ?? const SecureTokenStore(),
        _prefs = prefStore ?? const SharedPrefStore(),
        _client = client ?? http.Client();

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUrl = 'server_url';
  static const _kGarage = 'garage_id';

  final TokenStore _tokens;
  final PrefStore _prefs;
  final http.Client _client;

  String? serverUrl;
  String? _accessToken;
  String? _refreshToken;
  String? _garageId;
  Membership? _activeMembership;
  AuthUser? currentUser;

  /// Invoked by [handleSessionExpired] when the ApiClient cannot recover the
  /// session (refresh rejected). LoginGate listens and flips to the login
  /// screen; it must be set before any authenticated request is issued.
  void Function()? onSessionExpired;

  String? get accessToken => _accessToken;
  String? get garageId => _garageId;
  Membership? get activeMembership => _activeMembership;

  /// Restores a previously persisted session, or null when any of the four
  /// required keys is missing (fresh install or cleared storage).
  Future<StoredLogin?> loadStored() async {
    serverUrl = await _prefs.read(_kUrl);
    _garageId = await _prefs.read(_kGarage);
    _accessToken = await _tokens.read(_kAccess);
    _refreshToken = await _tokens.read(_kRefresh);
    if (serverUrl == null || _garageId == null) return null;
    if (_accessToken == null || _refreshToken == null) return null;
    return StoredLogin(serverUrl: serverUrl!, garageId: _garageId!);
  }

  /// POST /api/auth/login and persist the returned session. v1 picks the
  /// first membership as the active garage (single-garage users).
  Future<LoginResponse> login(String baseUrl, String email, String password) =>
      _authenticate(baseUrl, '/api/auth/login',
          {'email': email, 'password': password});

  /// POST /api/auth/register — same response shape; the creator becomes the
  /// garage's owner.
  Future<LoginResponse> register(
          String baseUrl, String name, String garageName, String email,
          String password) =>
      _authenticate(baseUrl, '/api/auth/register', {
        'name': name,
        'garageName': garageName,
        'email': email,
        'password': password,
      });

  /// Re-points the session at [membership] during token-based bootstrap
  /// (after GET /api/me succeeded) and persists the choice.
  Future<void> adoptMembership(Membership membership) async {
    _activeMembership = membership;
    _garageId = membership.garageId;
    await _prefs.write(_kGarage, membership.garageId);
  }

  /// One refresh-token rotation. Returns false (never throws) when the
  /// refresh token is missing or rejected.
  Future<bool> refreshAccess() async {
    final refresh = _refreshToken;
    final url = serverUrl;
    if (refresh == null || url == null) return false;
    try {
      final res = await _client.post(
        Uri.parse('$url/api/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String;
      _refreshToken = data['refresh_token'] as String;
      await _tokens.write(_kAccess, _accessToken!);
      await _tokens.write(_kRefresh, _refreshToken!);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called by the ApiClient after a refresh-and-retry cycle still got 401.
  void handleSessionExpired() {
    onSessionExpired?.call();
  }

  /// Revokes the refresh token server-side (best effort) and clears all
  /// local session state.
  Future<void> signOut() async {
    final refresh = _refreshToken;
    final url = serverUrl;
    if (refresh != null && url != null) {
      try {
        await _client.post(
          Uri.parse('$url/api/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refresh}),
        );
      } catch (_) {
        // Offline / already revoked — still clear local state below.
      }
    }
    await _tokens.deleteAll();
    await _prefs.remove(_kUrl);
    await _prefs.remove(_kGarage);
    _accessToken = null;
    _refreshToken = null;
    _garageId = null;
    _activeMembership = null;
    currentUser = null;
  }

  Future<LoginResponse> _authenticate(
    String baseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeEnvelope(res);
    final parsed = LoginResponse.fromJson(data);
    serverUrl = baseUrl;
    _accessToken = parsed.accessToken;
    _refreshToken = parsed.refreshToken;
    currentUser = parsed.user;
    _activeMembership = parsed.memberships.first;
    _garageId = _activeMembership!.garageId;
    await _prefs.write(_kUrl, baseUrl);
    await _prefs.write(_kGarage, _garageId!);
    await _tokens.write(_kAccess, _accessToken!);
    await _tokens.write(_kRefresh, _refreshToken!);
    return parsed;
  }

  Map<String, dynamic> _decodeEnvelope(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _envelope(res);
    }
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  ApiException _envelope(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) {
        final e = j['error'] as Map;
        return ApiException(
          res.statusCode,
          (e['code'] as String?) ?? 'internal',
          (e['message'] as String?) ?? '',
        );
      }
    } catch (_) {
      // fall through to the generic error
    }
    return ApiException(res.statusCode, 'internal',
        'Request failed (${res.statusCode})');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/api/auth_session_test.dart`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/auth_session.dart test/api/auth_session_test.dart
git commit -m "feat: AuthSession with secure token storage, refresh rotation and sign-out"
```

---

### Task 7: ApiClient — headers, error envelope, refresh-once-on-401

**Files:**
- Create: `lib/data/api/api_client.dart`
- Test: `test/api/api_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/api_client_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_client.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/api/auth_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_session_test.dart' show FakePrefStore, FakeTokenStore;

Membership _member() => Membership.fromJson(const {
      'garage_id': 'g-1',
      'garage_name': 'Nexory',
      'role': 'owner',
      'permissions': ['customers.manage'],
      'is_active': true,
    });

AuthSession _session(http.Client client) {
  final session = AuthSession(
    tokenStore: FakeTokenStore(),
    prefStore: FakePrefStore(),
    client: client,
  );
  session.onSessionExpired = () {};
  // refreshAccess() requires a persisted server URL; set it directly.
  session.serverUrl = 'http://lan:8080';
  return session;
}

void main() {
  test('attaches Authorization and X-Garage-Id headers', () async {
    http.Request? captured;
    final session = _session(MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    }));
    await session.adoptMembership(_member());
    // Prime the in-memory access token without a login round-trip.
    session.debugAccessToken = 'jwt-1';
    final api = ApiClient(baseUrl: 'http://lan:8080', session: session);

    await api.get('/api/customers');

    expect(captured!.headers['Authorization'], 'Bearer jwt-1');
    expect(captured!.headers['X-Garage-Id'], 'g-1');
    expect(captured!.url.toString(), 'http://lan:8080/api/customers');
  });

  test('decodes the error envelope into ApiException', () async {
    final session = _session(MockClient((req) async => http.Response(
        jsonEncode({
          'error': {'code': 'conflict', 'message': 'duplicate number'}
        }),
        409)));
    await session.adoptMembership(_member());
    session.debugAccessToken = 'jwt-1';
    final api = ApiClient(baseUrl: 'http://lan:8080', session: session);

    await expectLater(
      api.post('/api/invoices', body: {'x': 1}),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 409)
          .having((e) => e.code, 'code', 'conflict')
          .having((e) => e.message, 'message', 'duplicate number')),
    );
  });

  test('on 401 refreshes once and retries with the new token', () async {
    var customersCalls = 0;
    var refreshCalls = 0;
    final session = _session(MockClient((req) async {
      if (req.url.path == '/api/auth/refresh') {
        refreshCalls++;
        expect(jsonDecode(req.body)['refresh_token'], 'rt-1');
        return http.Response(
            jsonEncode({'access_token': 'jwt-2', 'refresh_token': 'rt-2'}), 200);
      }
      customersCalls++;
      if (customersCalls == 1) {
        expect(req.headers['Authorization'], 'Bearer jwt-1');
        return http.Response(
            jsonEncode({
              'error': {'code': 'unauthorized', 'message': 'expired'}
            }),
            401);
      }
      expect(req.headers['Authorization'], 'Bearer jwt-2');
      return http.Response(jsonEncode({'items': []}), 200);
    }));
    await session.adoptMembership(_member());
    session.debugAccessToken = 'jwt-1';
    final api = ApiClient(baseUrl: 'http://lan:8080', session: session);

    final data = await api.get('/api/customers');

    expect(data, {'items': []});
    expect(customersCalls, 2);
    expect(refreshCalls, 1);
  });

  test('invokes onSessionExpired and throws when refresh fails', () async {
    var expiredCalls = 0;
    final session = _session(MockClient((req) async {
      if (req.url.path == '/api/auth/refresh') {
        return http.Response('revoked', 401);
      }
      return http.Response(
          jsonEncode({
            'error': {'code': 'unauthorized', 'message': 'expired'}
          }),
          401);
    }));
    await session.adoptMembership(_member());
    session.debugAccessToken = 'jwt-1';
    session.onSessionExpired = () => expiredCalls++;
    final api = ApiClient(baseUrl: 'http://lan:8080', session: session);

    await expectLater(
      api.get('/api/customers'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expiredCalls, 1);
  });

  test('returns null on 204 and empty bodies', () async {
    final session = _session(
        MockClient((req) async => http.Response('', 204)));
    await session.adoptMembership(_member());
    session.debugAccessToken = 'jwt-1';
    final api = ApiClient(baseUrl: 'http://lan:8080', session: session);

    expect(await api.delete('/api/customers/c-1'), isNull);
  });
}
```

Note the test uses `session.debugAccessToken` — a test-only setter so tests can prime the access token without calling login. Add it to AuthSession in this task:

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/api_client_test.dart`
Expected: FAIL (`ApiClient` undefined; `debugAccessToken` undefined).

- [ ] **Step 3: Implement**

Add to `lib/data/api/auth_session.dart` (inside `AuthSession`, right after `onSessionExpired`):

```dart
  /// Test-only injection point: primes the in-memory access token without a
  /// login round-trip. Production code must not use this.
  set debugAccessToken(String? value) => _accessToken = value;
```

Create `lib/data/api/api_client.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'auth_session.dart';

/// Thin authenticated wrapper on package:http. Attaches `Authorization` and
/// `X-Garage-Id`, decodes the error envelope, and on 401 performs exactly one
/// refresh-and-retry before failing (and notifying the session so the UI can
/// flip back to login).
class ApiClient {
  ApiClient({required this.baseUrl, required this.session, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final AuthSession session;
  final http.Client _client;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path,
      {Object? body, bool retried = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = session.accessToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final garageId = session.garageId;
    if (garageId != null) headers['X-Garage-Id'] = garageId;

    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    switch (method) {
      case 'GET':
        res = await _client.get(uri, headers: headers);
      case 'DELETE':
        res = await _client.delete(uri, headers: headers);
      case 'POST':
        res = await _client.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        res = await _client.put(uri, headers: headers, body: jsonEncode(body));
      default:
        throw StateError('Unsupported method $method');
    }

    if (res.statusCode == 401 && !retried) {
      final refreshed = await session.refreshAccess();
      if (refreshed) {
        return _send(method, path, body: body, retried: true);
      }
      session.handleSessionExpired();
    }
    if (res.statusCode >= 400) throw _envelope(res);
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  ApiException _envelope(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) {
        final e = j['error'] as Map;
        return ApiException(
          res.statusCode,
          (e['code'] as String?) ?? 'internal',
          (e['message'] as String?) ?? '',
        );
      }
    } catch (_) {
      // fall through to the generic error
    }
    return ApiException(
        res.statusCode, 'internal', 'Request failed (${res.statusCode})');
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/api/`
Expected: PASS (all groups, including auth_session tests still green with the new setter).

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/api_client.dart lib/data/api/auth_session.dart test/api/api_client_test.dart
git commit -m "feat: ApiClient with auth headers, error envelope and refresh-on-401"
```

---

### Task 8: HttpGarageRepository — full implementation, read + permission-gating tests

**Files:**
- Create: `lib/data/api/permissions.dart`
- Create: `lib/data/api/http_garage_repository.dart` (all 38 methods — reads AND writes — since the write methods are one-liners over the codec layer)
- Test: `test/api/http_garage_repository_test.dart` (read/gating groups here; write-path groups in Task 9)

- [ ] **Step 1: Write the failing test**

Create `test/api/http_garage_repository_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_client.dart';
import 'package:garage_manager/data/api/auth_models.dart';
import 'package:garage_manager/data/api/auth_session.dart';
import 'package:garage_manager/data/api/http_garage_repository.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_session_test.dart' show FakePrefStore, FakeTokenStore;

Membership _member(Set<String> perms, {String role = 'staff'}) =>
    Membership.fromJson({
      'garage_id': 'g-1',
      'garage_name': 'Nexory',
      'role': role,
      'permissions': perms.toList(),
      'is_active': true,
    });

class Harness {
  Harness(this.handler)
      : session = AuthSession(
          tokenStore: FakeTokenStore(),
          prefStore: FakePrefStore(),
          client: MockClient((req) async => http.Response('unused', 200)),
        ),
        client = MockClient(handler) {
    session.onSessionExpired = () {};
    session.serverUrl = 'http://lan:8080';
    session.debugAccessToken = 'jwt';
  }

  final AuthSession session;
  final MockClient client;

  HttpGarageRepository repo({required Set<String> perms, String role = 'staff'}) {
    final api = ApiClient(baseUrl: 'http://lan:8080', session: session);
    return HttpGarageRepository(api, _member(perms, role: role));
  }
}

void main() {
  group('gated reads', () {
    test('fetchExpenses returns [] without hitting the server when gated',
        () async {
      var calls = 0;
      final h = Harness((req) async {
        calls++;
        return http.Response(jsonEncode({'items': []}), 200);
      });
      final repo = h.repo(perms: {'invoices.manage'});

      expect(await repo.fetchExpenses(), isEmpty);
      expect(calls, 0);
    });

    test('fetchExpenses hits the server when permitted', () async {
      final h = Harness((req) async {
        expect(req.url.path, '/api/expenses');
        return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'e-1',
                  'title': 'Rent',
                  'category': 'rent',
                  'amount': 15000,
                  'expenseDate': '2026-09-01',
                  'paymentMode': 'cash',
                  'vendorName': null,
                  'notes': null,
                  'receiptPath': null,
                  'createdAt': '2026-09-13T04:30:00Z',
                }
              ]
            }),
            200);
      });
      final repo = h.repo(perms: {'expenses.manage'});

      final expenses = await repo.fetchExpenses();
      expect(expenses.single.title, 'Rent');
    });

    test('fetchProfile falls back to membership name when gated', () async {
      final h = Harness((req) async {
        fail('must not call the server');
      });
      final repo = h.repo(perms: {});

      final profile = await repo.fetchProfile();
      expect(profile.name, 'Nexory');
      expect(profile.upiId, '');
    });

    test('fetchProfile parses the settings profile when permitted', () async {
      final h = Harness((req) async {
        expect(req.url.path, '/api/garages/g-1/settings');
        return http.Response(
            jsonEncode({
              'garage_id': 'g-1',
              'profile': {
                'name': 'Nexory Garage & Body Shop',
                'tagline': 't',
                'address_line': 'a',
                'city': 'Pune',
                'phone': 'p',
                'email': 'e',
                'gstin': 'g',
                'upi_id': 'u',
              },
              'default_tax_percent': 18,
              'tax_percent_options': [0, 18],
              'invoice_due_days': 7,
              'quotation_validity_options': [7],
              'working_days_per_month': 26,
              'promised_delivery_hours': 6,
              'invoice_notes': 'n',
              'invoice_terms': 't',
              'default_received_by': 'Cashier',
            }),
            200);
      });
      final repo = h.repo(perms: {'settings.manage'});

      final profile = await repo.fetchProfile();
      expect(profile.name, 'Nexory Garage & Body Shop');
      expect(profile.upiId, 'u');

      final config = await repo.fetchConfig();
      expect(config.defaultTaxPercent, 18.0);
      expect(config.taxPercentOptions, [0.0, 18.0]);
    });

    test('fetchConfig falls back to defaults when gated', () async {
      final h = Harness((req) async => fail('must not call'));
      final repo = h.repo(perms: {});

      final config = await repo.fetchConfig();
      expect(config.defaultTaxPercent, 18.0);
      expect(config.taxPercentOptions, [0.0, 12.0, 18.0, 28.0]);
      expect(config.invoiceDueDays, 7);
      expect(config.quotationValidityOptions, [7, 15, 30]);
      expect(config.workingDaysPerMonth, 26);
      expect(config.promisedDeliveryHours, 6);
      expect(config.invoiceNotes, 'Thank you for choosing us! Standard warranty applies.');
      expect(config.invoiceTerms, 'All parts replaced carry manufacturer warranty. Labour warranty 30 days.');
      expect(config.defaultReceivedBy, 'Cashier');
    });
  });

  group('open reads', () {
    test('fetchCustomers parses the items list', () async {
      final h = Harness((req) async {
        expect(req.url.path, '/api/customers');
        return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'c-1',
                  'name': 'Ravi',
                  'phone': '987',
                  'whatsappNumber': null,
                  'email': null,
                  'address': null,
                  'gstin': null,
                  'notes': null,
                  'createdAt': '2026-09-13T04:30:00Z',
                }
              ]
            }),
            200);
      });
      final repo = h.repo(perms: {'customers.manage'});

      final customers = await repo.fetchCustomers();
      expect(customers.single, isA<Customer>());
      expect(customers.single.name, 'Ravi');
    });

    test('owner bypasses permission checks', () async {
      final h = Harness((req) async {
        expect(req.url.path, '/api/expenses');
        return http.Response(jsonEncode({'items': []}), 200);
      });
      final repo = h.repo(perms: {}, role: 'owner');

      expect(await repo.fetchExpenses(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/http_garage_repository_test.dart`
Expected: FAIL (`HttpGarageRepository` undefined).

- [ ] **Step 3: Implement permissions.dart + the repository skeleton with reads**

Create `lib/data/api/permissions.dart`:

```dart
/// The backend's fixed permission keys (spec §6). Serves as the default
/// permission set for mock/test runs so every UI affordance stays visible.
const Set<String> allPermissions = {
  'customers.manage',
  'vehicles.manage',
  'jobcards.manage',
  'quotations.manage',
  'invoices.manage',
  'payments.record',
  'expenses.manage',
  'staff.manage',
  'attendance.manage',
  'advances.manage',
  'settings.manage',
};
```

Create `lib/data/api/http_garage_repository.dart`:

```dart
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_models.dart';
import 'model_json.dart';
import '../app_config.dart';
import '../garage_profile.dart';
import '../garage_repository.dart';
import '../../models/customer.dart';
import '../../models/expense.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../models/maintenance_item.dart';
import '../../models/payment.dart';
import '../../models/quotation.dart';
import '../../models/staff.dart';
import '../../models/vehicle.dart';

/// GarageRepository backed by the Go API. Fetch methods the active
/// membership has no permission for return empty/default data WITHOUT a
/// server call — the server is the source of truth for authorization, this
/// is only load() ergonomics (a staff login must not 403 its own load).
/// Write calls go through and surface 403s via ApiException.
class HttpGarageRepository implements GarageRepository {
  HttpGarageRepository(this._api, this._membership);

  final ApiClient _api;
  final Membership _membership;

  bool _can(String key) =>
      _membership.role == 'owner' || _membership.permissions.contains(key);

  List<T> _items<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
      [
        for (final row in ((data as Map<String, dynamic>)['items'] as List? ?? []))
          fromJson(row as Map<String, dynamic>)
      ];

  // ----- profile / config -----

  @override
  Future<GarageProfile> fetchProfile() async {
    if (!_can('settings.manage')) {
      return GarageProfile(
        name: _membership.garageName,
        tagline: '',
        addressLine: '',
        city: '',
        phone: '',
        email: '',
        gstin: '',
        upiId: '',
      );
    }
    final data = await _api.get('/api/garages/${_membership.garageId}/settings');
    return profileFromJson(
        (data as Map<String, dynamic>)['profile'] as Map<String, dynamic>);
  }

  @override
  Future<AppConfig> fetchConfig() async {
    if (!_can('settings.manage')) return const AppConfig();
    final data = await _api.get('/api/garages/${_membership.garageId}/settings');
    return appConfigFromSettings(data as Map<String, dynamic>);
  }

  // ----- customers -----

  @override
  Future<List<Customer>> fetchCustomers() async => _items(
      await _api.get('/api/customers'), customerFromJson);

  @override
  Future<Customer> createCustomer(Customer customer) async =>
      customerFromJson(
          await _api.post('/api/customers', body: customerToJson(customer))
              as Map<String, dynamic>);

  @override
  Future<Customer> updateCustomer(Customer customer) async =>
      customerFromJson(
          await _api.put('/api/customers/${customer.id}',
              body: customerToJson(customer)) as Map<String, dynamic>);

  @override
  Future<bool> deleteCustomer(String customerId) async {
    try {
      await _api.delete('/api/customers/$customerId');
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 409) return false; // outstanding dues (mock contract)
      rethrow;
    }
  }

  // ----- vehicles -----

  @override
  Future<List<Vehicle>> fetchVehicles() async =>
      _items(await _api.get('/api/vehicles'), vehicleFromJson);

  @override
  Future<Vehicle> createVehicle(Vehicle vehicle) async => vehicleFromJson(
      await _api.post('/api/vehicles', body: vehicleToJson(vehicle))
          as Map<String, dynamic>);

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) async => vehicleFromJson(
      await _api.put('/api/vehicles/${vehicle.id}', body: vehicleToJson(vehicle))
          as Map<String, dynamic>);

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    await _api.delete('/api/vehicles/$vehicleId');
  }

  // ----- staff -----

  @override
  Future<List<Staff>> fetchStaff() async =>
      _items(await _api.get('/api/staff'), staffFromJson);

  @override
  Future<Staff> createStaff(Staff staff) async => staffFromJson(
      await _api.post('/api/staff', body: staffToJson(staff))
          as Map<String, dynamic>);

  @override
  Future<Staff> updateStaff(Staff staff) async => staffFromJson(
      await _api.put('/api/staff/${staff.id}', body: staffToJson(staff))
          as Map<String, dynamic>);

  @override
  Future<void> deleteStaff(String staffId) async {
    await _api.delete('/api/staff/$staffId');
  }

  // ----- job cards -----

  @override
  Future<List<JobCard>> fetchJobCards() async =>
      _items(await _api.get('/api/jobcards'), jobCardFromJson);

  @override
  Future<JobCard> createJobCard(JobCard jobCard) async => jobCardFromJson(
      await _api.post('/api/jobcards', body: jobCardToJson(jobCard))
          as Map<String, dynamic>);

  @override
  Future<JobCard> updateJobCard(JobCard jobCard) async => jobCardFromJson(
      await _api.put('/api/jobcards/${jobCard.id}', body: jobCardToJson(jobCard))
          as Map<String, dynamic>);

  @override
  Future<JobCard> updateJobStatus(String jobCardId, JobStatus status) async =>
      jobCardFromJson(await _api.post('/api/jobcards/$jobCardId/status',
          body: {'status': status.name}) as Map<String, dynamic>);

  @override
  Future<JobCard> upsertJobCardItem(
      String jobCardId, MaintenanceItem item) async {
    // The endpoint returns the saved ITEM, not the card — refetch.
    await _api.post('/api/jobcards/$jobCardId/items',
        body: maintenanceItemToJson(item));
    return _fetchJobCard(jobCardId);
  }

  @override
  Future<JobCard> removeJobCardItem(String jobCardId, String itemId) async {
    // 204 empty — refetch the card so the cache sees the new item list.
    await _api.delete('/api/jobcards/$jobCardId/items/$itemId');
    return _fetchJobCard(jobCardId);
  }

  Future<JobCard> _fetchJobCard(String jobCardId) async {
    final all = _items(await _api.get('/api/jobcards'), jobCardFromJson);
    for (final jc in all) {
      if (jc.id == jobCardId) return jc;
    }
    throw const ApiException(404, 'not_found', 'job card not found');
  }

  // ----- quotations -----

  @override
  Future<List<Quotation>> fetchQuotations() async =>
      _items(await _api.get('/api/quotations'), quotationFromJson);

  @override
  Future<Quotation> createQuotation(Quotation quotation) async =>
      quotationFromJson(await _api.post('/api/quotations',
              body: quotationToJson(quotation)) as Map<String, dynamic>);

  @override
  Future<Quotation> updateQuotation(Quotation quotation) async =>
      quotationFromJson(await _api.put('/api/quotations/${quotation.id}',
              body: quotationToJson(quotation)) as Map<String, dynamic>);

  @override
  Future<Quotation> updateQuotationStatus(
      String quotationId, QuotationStatus status) async =>
      quotationFromJson(await _api.post('/api/quotations/$quotationId/status',
          body: {'status': status.name}) as Map<String, dynamic>);

  // ----- invoices / payments -----

  @override
  Future<List<Invoice>> fetchInvoices() async =>
      _items(await _api.get('/api/invoices'), invoiceFromJson);

  @override
  Future<Invoice> createInvoice(Invoice invoice) async => invoiceFromJson(
      await _api.post('/api/invoices', body: invoiceToJson(invoice))
          as Map<String, dynamic>);

  @override
  Future<Invoice> updateInvoice(Invoice invoice) async => invoiceFromJson(
      await _api.put('/api/invoices/${invoice.id}', body: invoiceToJson(invoice))
          as Map<String, dynamic>);

  @override
  Future<Payment> createPayment(Payment payment) async => paymentFromJson(
      await _api.post('/api/invoices/${payment.invoiceId}/payments',
          body: paymentToJson(payment)) as Map<String, dynamic>);

  // ----- expenses -----

  @override
  Future<List<GarageExpense>> fetchExpenses() async {
    if (!_can('expenses.manage')) return [];
    return _items(await _api.get('/api/expenses'), expenseFromJson);
  }

  @override
  Future<GarageExpense> createExpense(GarageExpense expense) async =>
      expenseFromJson(await _api.post('/api/expenses',
              body: expenseToJson(expense)) as Map<String, dynamic>);

  @override
  Future<GarageExpense> updateExpense(GarageExpense expense) async =>
      expenseFromJson(await _api.put('/api/expenses/${expense.id}',
              body: expenseToJson(expense)) as Map<String, dynamic>);

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _api.delete('/api/expenses/$expenseId');
  }

  // ----- attendance / advances / catalog -----

  @override
  Future<AttendanceRecord> saveAttendance(AttendanceRecord record) async =>
      attendanceFromJson(await _api.post('/api/attendance',
              body: attendanceToJson(record)) as Map<String, dynamic>);

  @override
  Future<List<AttendanceRecord>> fetchAttendance() async {
    if (!_can('attendance.manage')) return [];
    return _items(await _api.get('/api/attendance'), attendanceFromJson);
  }

  @override
  Future<List<SalaryAdvance>> fetchSalaryAdvances() async {
    if (!_can('advances.manage')) return [];
    return _items(await _api.get('/api/salary-advances'), salaryAdvanceFromJson);
  }

  @override
  Future<SalaryAdvance> createSalaryAdvance(SalaryAdvance advance) async =>
      salaryAdvanceFromJson(await _api.post('/api/salary-advances',
              body: salaryAdvanceToJson(advance)) as Map<String, dynamic>);

  @override
  Future<List<SalaryAdvance>> settleSalaryAdvances(
      String staffId, int month, int year) async {
    // Server returns the FULL garage list (mock contract — the provider
    // replaces its entire cache with this response).
    return _items(
        await _api.post('/api/salary-advances/settle',
            body: {'staff_id': staffId, 'month': month, 'year': year}),
        salaryAdvanceFromJson);
  }

  @override
  Future<List<MaintenanceItem>> fetchCatalog() async =>
      _items(await _api.get('/api/catalog'), catalogItemFromJson);
}
```

Note: `AttendanceRecord` and `SalaryAdvance` come from `staff.dart` (already imported via the staff import).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/api/http_garage_repository_test.dart`
Expected: PASS (all).

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/data/api/permissions.dart lib/data/api/http_garage_repository.dart test/api/http_garage_repository_test.dart
git commit -m "feat: HttpGarageRepository reads with permission gating"
```

---

### Task 9: HttpGarageRepository — write-path verification tests

All 38 methods are already implemented; this task pins the write/command paths with tests (routes, bodies, error mapping). No new production code unless a test exposes a bug — fix in place if so.

**Files:**
- Modify: `test/api/http_garage_repository_test.dart` (append groups)

- [ ] **Step 1: Write the failing tests**

Append to the existing `main()` in `test/api/http_garage_repository_test.dart`:

```dart
  group('writes: customers/vehicles/expenses', () {
    test('createCustomer POSTs and parses the persisted object', () async {
      http.Request? captured;
      final h = Harness((req) async {
        captured = req;
        return http.Response(
            jsonEncode({
              'id': 'srv-1',
              'name': 'Ravi',
              'phone': '987',
              'whatsappNumber': null,
              'email': null,
              'address': null,
              'gstin': null,
              'notes': null,
              'createdAt': '2026-09-13T04:30:00Z',
            }),
            201);
      });
      final repo = h.repo(perms: {'customers.manage'});

      final created = await repo.createCustomer(
          Customer(id: 'client-ignored', name: 'Ravi', phone: '987'));

      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), 'http://lan:8080/api/customers');
      expect(created.id, 'srv-1');
    });

    test('deleteCustomer maps 409 to false and 204 to true', () async {
      var calls = 0;
      final h = Harness((req) async {
        calls++;
        if (calls == 1) {
          return http.Response(
              jsonEncode({
                'error': {
                  'code': 'conflict',
                  'message': 'customer has outstanding dues'
                }
              }),
              409);
        }
        return http.Response('', 204);
      });
      final repo = h.repo(perms: {'customers.manage'});

      expect(await repo.deleteCustomer('c-1'), isFalse);
      expect(await repo.deleteCustomer('c-2'), isTrue);
      expect(calls, 2);
    });
  });

  group('writes: job card commands', () {
    JobCard _jcCard(String id) => JobCard(
          id: id,
          jobCardNumber: 'JC-1001',
          customerId: 'c-1',
          vehicleId: 'v-1',
          customerComplaints: const [],
          kmReading: 10,
          promisedDeliveryDate: DateTime.parse('2026-09-13T10:30:00Z'),
          createdAt: DateTime.parse('2026-09-13T04:30:00Z'),
        );

    test('updateJobStatus posts the status and parses the card', () async {
      http.Request? captured;
      final h = Harness((req) async {
        captured = req;
        final card = _jcCard('jc-1');
        return http.Response(jsonEncode(jobCardToJson(card)..['status'] = 'delivered'), 200);
      });
      final repo = h.repo(perms: {'jobcards.manage'});

      final updated = await repo.updateJobStatus('jc-1', JobStatus.delivered);

      expect(captured!.url.path, '/api/jobcards/jc-1/status');
      expect(jsonDecode(captured!.body), {'status': 'delivered'});
      expect(updated.status, JobStatus.delivered);
    });

    test('upsertJobCardItem posts the item then refetches the card', () async {
      final paths = <String>[];
      http.Request? itemReq;
      final h = Harness((req) async {
        paths.add(req.url.path);
        if (req.url.path.endsWith('/items')) {
          itemReq = req;
          return http.Response(jsonEncode({
            'id': 'it-1', 'name': 'Wash', 'category': 'custom',
            'unitPrice': 300, 'quantity': 1, 'unit': 'Pcs',
            'discountPercent': 0, 'taxPercent': 0, 'isLabour': false,
            'partNumber': null, 'notes': null, 'assignedStaffId': null,
          }), 200);
        }
        final card = _jcCard('jc-1').copyWith(items: [
          MaintenanceItem(
            id: 'it-1', name: 'Wash', category: ItemCategory.custom,
            unitPrice: 300,
          )
        ]);
        return http.Response(jsonEncode({'items': [jobCardToJson(card)]}), 200);
      });
      final repo = h.repo(perms: {'jobcards.manage'});

      final updated = await repo.upsertJobCardItem(
          'jc-1',
          MaintenanceItem(id: 'it-1', name: 'Wash', category: ItemCategory.custom, unitPrice: 300));

      expect(itemReq!.method, 'POST');
      expect(jsonDecode(itemReq!.body)['name'], 'Wash');
      expect(paths, ['/api/jobcards/jc-1/items', '/api/jobcards']);
      expect(updated.items.single.id, 'it-1');
    });

    test('removeJobCardItem deletes then refetches the card', () async {
      final methods = <String>[];
      final h = Harness((req) async {
        methods.add(req.method);
        if (req.method == 'DELETE') return http.Response('', 204);
        final card = _jcCard('jc-1');
        return http.Response(jsonEncode({'items': [jobCardToJson(card)]}), 200);
      });
      final repo = h.repo(perms: {'jobcards.manage'});

      final updated = await repo.removeJobCardItem('jc-1', 'it-1');

      expect(methods, ['DELETE', 'GET']);
      expect(updated.id, 'jc-1');
    });
  });

  group('writes: quotation status, invoices, payments, attendance, settle', () {
    test('updateQuotationStatus posts the status', () async {
      http.Request? captured;
      final h = Harness((req) async {
        captured = req;
        return http.Response(jsonEncode({
          'id': 'q-1', 'quotationNumber': 'EST-1001', 'customerId': 'c-1',
          'vehicleId': 'v-1', 'kmReading': 10, 'items': [],
          'overallDiscount': 0, 'taxPercent': 18, 'validityDays': 7,
          'status': 'converted', 'notes': null,
          'createdAt': '2026-09-13T04:30:00Z',
          'validUntil': '2026-09-20T04:30:00Z',
        }), 200);
      });
      final repo = h.repo(perms: {'quotations.manage'});

      final updated = await repo.updateQuotationStatus('q-1', QuotationStatus.converted);

      expect(captured!.url.path, '/api/quotations/q-1/status');
      expect(jsonDecode(captured!.body), {'status': 'converted'});
      expect(updated.status, QuotationStatus.converted);
    });

    test('createPayment posts to the invoice payments route', () async {
      http.Request? captured;
      final h = Harness((req) async {
        captured = req;
        return http.Response(jsonEncode({
          'id': 'p-1', 'invoiceId': 'inv-1', 'customerId': 'c-1',
          'amount': 500, 'mode': 'cash', 'transactionRef': null,
          'paymentDate': '2026-09-13T04:30:00Z', 'notes': null,
          'receivedBy': 'Cashier',
        }), 201);
      });
      final repo = h.repo(perms: {'payments.record'});

      final saved = await repo.createPayment(Payment(
        id: 'ignored',
        invoiceId: 'inv-1',
        customerId: 'c-1',
        amount: 500,
        mode: PaymentMode.cash,
      ));

      expect(captured!.url.path, '/api/invoices/inv-1/payments');
      expect(saved.id, 'p-1');
    });

    test('saveAttendance posts the record (upsert route)', () async {
      http.Request? captured;
      final h = Harness((req) async {
        captured = req;
        return http.Response(jsonEncode({
          'id': 'srv-a1', 'staffId': 'st-1', 'date': '2026-09-13',
          'status': 'present', 'notes': null,
        }), 200);
      });
      final repo = h.repo(perms: {'attendance.manage'});

      final saved = await repo.saveAttendance(AttendanceRecord(
        id: 'ignored',
        staffId: 'st-1',
        date: DateTime(2026, 9, 13),
        status: AttendanceStatus.present,
      ));

      expect(captured!.url.path, '/api/attendance');
      expect(jsonDecode(captured!.body)['date'], '2026-09-13');
      expect(saved.id, 'srv-a1');
    });

    test('settleSalaryAdvances posts snake_case body and returns full list',
        () async {
      http.Request? captured;
      final h = Harness((req) async {
        captured = req;
        return http.Response(jsonEncode({
          'items': [
            {
              'id': 'adv-1', 'staffId': 'st-1', 'amount': 1500,
              'date': '2026-09-03', 'reason': null, 'isDeducted': true,
            },
            {
              'id': 'adv-2', 'staffId': 'st-2', 'amount': 900,
              'date': '2026-09-04', 'reason': null, 'isDeducted': false,
            },
          ]
        }), 200);
      });
      final repo = h.repo(perms: {'advances.manage'});

      final all = await repo.settleSalaryAdvances('st-1', 9, 2026);

      expect(captured!.url.path, '/api/salary-advances/settle');
      expect(jsonDecode(captured!.body),
          {'staff_id': 'st-1', 'month': 9, 'year': 2026});
      expect(all.length, 2);
      expect(all.first.isDeducted, isTrue);
      expect(all.last.isDeducted, isFalse);
    });

    test('409 on invoice create propagates as ApiException conflict', () async {
      final h = Harness((req) async {
        return http.Response(
            jsonEncode({
              'error': {'code': 'conflict', 'message': 'invoice number exists'}
            }),
            409);
      });
      final repo = h.repo(perms: {'invoices.manage'});

      await expectLater(
        repo.createInvoice(Invoice(
          id: 'x',
          invoiceNumber: 'INV-2026-1',
          customerId: 'c-1',
          vehicleId: 'v-1',
          kmReading: 10,
          items: [],
        )),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.code, 'code', 'conflict')),
      );
    });
  });
```

The tests need these additional imports at the top of the test file (SalaryAdvance and AttendanceRecord live in `staff.dart` — there is no separate file):

```dart
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/api/model_json.dart';
import 'package:garage_manager/models/job_card.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/models/payment.dart';
import 'package:garage_manager/models/quotation.dart';
import 'package:garage_manager/models/staff.dart';
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/api/http_garage_repository_test.dart`
Expected: PASS — all write tests pass against the existing implementation. If any fail, fix `http_garage_repository.dart` in place (route/body bug) and re-run.

- [ ] **Step 3: Analyze + full test suite**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add test/api/http_garage_repository_test.dart
git commit -m "test: pin HttpGarageRepository write paths and error mapping"
```

---

### Task 10: LoginScreen (Transit Red)

**Files:**
- Create: `lib/screens/auth/login_screen.dart`
- Test: `test/api/login_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/screens/auth/login_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, LoginScreen screen) =>
      tester.pumpWidget(MaterialApp(home: screen));

  testWidgets('login mode: submits server url, email and password',
      (tester) async {
    String? url, email, password;
    await pump(
        tester,
        LoginScreen(
          initialUrl: 'http://lan:8080',
          onAuthenticated: (_) {},
          onLogin: (u, e, p) async {
            url = u;
            email = e;
            password = p;
          },
        ));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Server URL'), 'http://x:8080');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.c');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(url, 'http://x:8080');
    expect(email, 'a@b.c');
    expect(password, 'secret');
  });

  testWidgets('register toggle reveals name and garage fields',
      (tester) async {
    await pump(
        tester,
        LoginScreen(
          onAuthenticated: (_) {},
          onLogin: (_, __, ___) async {},
        ));

    expect(find.text('Your Name'), findsNothing);
    await tester.tap(find.text('Create your garage'));
    await tester.pumpAndSettle();
    expect(find.text('Your Name'), findsOneWidget);
    expect(find.text('Garage Name'), findsOneWidget);
  });

  testWidgets('empty fields block submission with validation messages',
      (tester) async {
    var submitted = false;
    await pump(
        tester,
        LoginScreen(
          onAuthenticated: (_) {},
          onLogin: (_, __, ___) async => submitted = true,
        ));

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(submitted, isFalse);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('failed login surfaces the ApiException message in a snackbar',
      (tester) async {
    await pump(
        tester,
        LoginScreen(
          onAuthenticated: (_) {},
          onLogin: (_, __, ___) async =>
              throw const ApiException(401, 'unauthorized', 'invalid email or password'),
        ));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.c');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('invalid email or password'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/login_screen_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement**

Create `lib/screens/auth/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/auth_models.dart';
import '../../data/api/auth_session.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';

/// Server URL + email + password sign-in, with a register toggle for new
/// garages. The [AuthSession] does the network calls; this widget only
/// renders and reports the resulting membership upward via
/// [onAuthenticated]. The onLogin/onRegister hooks are a test seam so widget
/// tests need no storage; production leaves them null.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.session,
    required this.onAuthenticated,
    this.initialUrl,
    this.onLogin,
    this.onRegister,
  });

  final AuthSession? session;
  final String? initialUrl;
  final Future<void> Function(String url, String email, String password)?
      onLogin;
  final Future<void> Function(String url, String name, String garageName,
      String email, String password)? onRegister;
  final void Function(Membership membership) onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url =
      TextEditingController(text: widget.initialUrl ?? 'http://localhost:8080');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _garageName = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _garageName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_registerMode) {
        if (widget.onRegister != null) {
          await widget.onRegister!(_url.text.trim(), _name.text.trim(),
              _garageName.text.trim(), _email.text.trim(), _password.text);
          return;
        }
        final res = await widget.session!.register(_url.text.trim(),
            _name.text.trim(), _garageName.text.trim(), _email.text.trim(),
            _password.text);
        if (!mounted) return;
        widget.onAuthenticated(res.memberships.first);
        return;
      }
      if (widget.onLogin != null) {
        await widget.onLogin!(_url.text.trim(), _email.text.trim(),
            _password.text);
        return;
      }
      final res = await widget.session!.login(
          _url.text.trim(), _email.text.trim(), _password.text);
      if (!mounted) return;
      widget.onAuthenticated(res.memberships.first);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: palette.brandGradient),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.car_repair_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _registerMode ? 'Create your garage' : 'Nexory Garage',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: AppText.headline,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _url,
                    decoration:
                        const InputDecoration(labelText: 'Server URL'),
                    keyboardType: TextInputType.url,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter the server URL' : null,
                  ),
                  const SizedBox(height: 12),
                  if (_registerMode) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Your Name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _garageName,
                      decoration:
                          const InputDecoration(labelText: 'Garage Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the garage name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration:
                        const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: palette.brandGradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _registerMode ? 'Create Garage' : 'Sign In',
                                style: GoogleFonts.inter(
                                  fontSize: AppText.subtitle,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _registerMode = !_registerMode),
                    child: Text(
                      _registerMode
                          ? 'Already have an account? Sign In'
                          : 'New here? Create your garage',
                      style: GoogleFonts.inter(
                        fontSize: AppText.label,
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/api/login_screen_test.dart`
Expected: PASS (all four).

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/auth/login_screen.dart test/api/login_screen_test.dart
git commit -m "feat: Transit Red login screen with register toggle"
```

---

### Task 11: Bootstrap — provider permissions, AppShell, LoginGate, NexoryGarageApp param

**Files:**
- Create: `lib/screens/auth/login_gate.dart`
- Create: `lib/widgets/app_shell.dart`
- Modify: `lib/providers/garage_provider.dart` (constructor + permissions field only)
- Modify: `lib/main.dart` (NexoryGarageApp gains `repository` param)
- Modify: `test/widget_test.dart` (one line: pass the mock repository)
- Test: `test/api/provider_permissions_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/provider_permissions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/permissions.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';

void main() {
  test('default permissions include all keys (mock/test mode)', () {
    final provider = GarageProvider(MockGarageRepository());
    for (final key in allPermissions) {
      expect(provider.can(key), isTrue, reason: key);
    }
  });

  test('restricted membership hides gated keys', () {
    final provider = GarageProvider(
      MockGarageRepository(),
      permissions: {'customers.manage', 'vehicles.manage', 'invoices.manage',
        'payments.record', 'jobcards.manage', 'quotations.manage',
        'attendance.manage'},
    );
    expect(provider.can('expenses.manage'), isFalse);
    expect(provider.can('staff.manage'), isFalse);
    expect(provider.can('advances.manage'), isFalse);
    expect(provider.can('settings.manage'), isFalse);
    expect(provider.can('invoices.manage'), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/provider_permissions_test.dart`
Expected: FAIL — `GarageProvider` has no `permissions` param / `can`.

- [ ] **Step 3: Implement**

Edit `lib/providers/garage_provider.dart`. Replace the constructor block:

```dart
class GarageProvider extends ChangeNotifier {
  GarageProvider(this._repo);
```

with:

```dart
class GarageProvider extends ChangeNotifier {
  GarageProvider(this._repo, {Set<String>? permissions})
      : permissions = permissions ?? allPermissions;

  /// Permission keys of the active membership (server source of truth at
  /// login; UI gating is convenience only). Mock/test runs default to all
  /// keys so every affordance stays visible.
  final Set<String> permissions;

  bool can(String key) => permissions.contains(key);
```

Add the import to the top of the file:

```dart
import '../data/api/permissions.dart';
```

Create `lib/widgets/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api/auth_session.dart';
import '../data/api/http_garage_repository.dart';
import '../data/api/permissions.dart';
import '../data/garage_repository.dart';
import '../providers/garage_provider.dart';
import '../screens/main_navigation_screen.dart';

/// The authenticated app: wires [GarageProvider] over the given repository
/// (and an optional [AuthSession] for sign-out) above the navigation shell.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.repository,
    this.permissions = allPermissions,
    this.session,
  });

  final GarageRepository repository;
  final Set<String> permissions;
  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (session != null) Provider<AuthSession>.value(value: session!),
        ChangeNotifierProvider<GarageProvider>(
          create: (_) => GarageProvider(repository, permissions: permissions)
            ..load(),
        ),
      ],
      child: const MainNavigationScreen(),
    );
  }
}
```

Create `lib/screens/auth/login_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/auth_models.dart';
import '../../data/api/auth_session.dart';
import '../../data/api/http_garage_repository.dart';
import '../../widgets/app_shell.dart';
import 'login_screen.dart';

enum _GatePhase { loading, login, app }

/// Decides what the app shows: a spinner while the stored session is
/// validated, the login screen, or the authenticated shell. A session that
/// dies mid-use (refresh rejected) flips back to login via the session's
/// onSessionExpired callback.
class LoginGate extends StatefulWidget {
  const LoginGate({super.key});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  _GatePhase _phase = _GatePhase.loading;
  AuthSession? _session;
  ApiClient? _api;
  Membership? _membership;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final session = AuthSession();
    session.onSessionExpired = _expireToLogin;
    final stored = await session.loadStored();
    if (stored == null) {
      _showLogin(session);
      return;
    }
    final api = ApiClient(baseUrl: stored.serverUrl, session: session);
    try {
      final me = await api.get('/api/me') as Map<String, dynamic>;
      final memberships = [
        for (final m in (me['memberships'] as List))
          Membership.fromJson(m as Map<String, dynamic>)
      ];
      Membership? active;
      for (final m in memberships) {
        if (m.garageId == stored.garageId) active = m;
      }
      active ??= memberships.isEmpty ? null : memberships.first;
      if (active == null) {
        _showLogin(session);
        return;
      }
      await session.adoptMembership(active);
      if (!mounted) return;
      setState(() {
        _session = session;
        _api = api;
        _membership = active;
        _phase = _GatePhase.app;
      });
    } on ApiException {
      _showLogin(session);
    }
  }

  void _showLogin(AuthSession session) {
    if (!mounted) return;
    setState(() {
      _session = session;
      _api = null;
      _membership = null;
      _phase = _GatePhase.login;
    });
  }

  void _expireToLogin() {
    if (!mounted) return;
    setState(() {
      _api = null;
      _membership = null;
      _phase = _GatePhase.login;
    });
  }

  void _onAuthenticated(Membership membership) {
    final session = _session!;
    setState(() {
      _api = ApiClient(baseUrl: session.serverUrl!, session: session);
      _membership = membership;
      _phase = _GatePhase.app;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _GatePhase.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      _GatePhase.login => LoginScreen(
          session: _session!,
          onAuthenticated: _onAuthenticated,
          initialUrl: _session!.serverUrl,
        ),
      _GatePhase.app => AppShell(
          repository: HttpGarageRepository(_api!, _membership!),
          permissions: _membership!.permissions.toSet(),
          session: _session,
        ),
    };
  }
}
```

Edit `lib/main.dart` — replace the whole `NexoryGarageApp` class:

```dart
class NexoryGarageApp extends StatelessWidget {
  const NexoryGarageApp({super.key, this.repository});

  /// When provided (tests), the app boots straight into the authenticated
  /// shell over that repository, bypassing LoginGate and secure storage.
  final GarageRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexory Garage Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: repository != null
          ? AppShell(repository: repository!)
          : const LoginGate(),
    );
  }
}
```

And add the imports to main.dart:

```dart
import 'data/garage_repository.dart';
import 'screens/auth/login_gate.dart';
import 'widgets/app_shell.dart';
```

(`data/mock/mock_garage_repository.dart` and `screens/main_navigation_screen.dart` imports become unused in main.dart — remove them. `data/api/permissions.dart` is not needed here — AppShell defaults to `allPermissions` in test mode.)

Edit `test/widget_test.dart`: change `await tester.pumpWidget(const NexoryGarageApp());` to

```dart
await tester.pumpWidget(NexoryGarageApp(repository: MockGarageRepository()));
```

and add `import 'package:garage_manager/data/mock/mock_garage_repository.dart';` (the existing import of main.dart stays).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/api/provider_permissions_test.dart test/widget_test.dart`
Expected: PASS. (`provider.load()` is called with the mock — unchanged behavior.)

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/providers/garage_provider.dart lib/widgets/app_shell.dart lib/screens/auth/login_gate.dart lib/main.dart test/widget_test.dart test/api/provider_permissions_test.dart
git commit -m "feat: LoginGate bootstrap with permission-aware provider and test bypass"
```

---

### Task 12: UI permission gating + logout

**Files:**
- Modify: `lib/screens/more/more_menu_screen.dart` (gate 3 tiles, add Sign out tile)
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (gate Expenses figure ~:447 and dues section ~:371/:536)
- Test: `test/api/permission_gating_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/api/permission_gating_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/permissions.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/screens/more/more_menu_screen.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpMore(WidgetTester tester, GarageProvider provider) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GarageProvider>.value(
        value: provider,
        child: const MaterialApp(home: MoreMenuScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('full permissions show all module tiles', (tester) async {
    final provider = GarageProvider(MockGarageRepository())..load();
    await pumpMore(tester, provider);

    expect(find.text('Garage Expenses'), findsOneWidget);
    expect(find.text('Staff Directory & Roles'), findsOneWidget);
    expect(find.text('Attendance & Payroll Slips'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('restricted staff hides gated tiles but keeps quotations',
      (tester) async {
    final provider = GarageProvider(
      MockGarageRepository(),
      permissions: {
        'customers.manage', 'vehicles.manage', 'jobcards.manage',
        'quotations.manage', 'invoices.manage', 'payments.record',
        'attendance.manage',
      },
    )..load();
    await pumpMore(tester, provider);

    expect(find.text('Garage Expenses'), findsNothing);
    expect(find.text('Staff Directory & Roles'), findsNothing);
    expect(find.text('Attendance & Payroll Slips'), findsOneWidget);
    expect(find.text('Quotations / Estimates'), findsOneWidget);
  });
}
```

Sign-out tile policy: the tile renders ALWAYS (so test mode can pin it); the tap is a no-op when no `AuthSession` provider is registered, which is exactly the widget-test/mock case. `context.read<AuthSession?>()` returns null when nothing provides it — the provider package supports nullable lookups.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/api/permission_gating_test.dart`
Expected: FAIL — tiles not gated yet (restricted test finds 'Garage Expenses').

- [ ] **Step 3: Implement**

**more_menu_screen.dart:** Read the file. The three module tiles live in the ListView children after `_buildSectionTitle(context, 'WORKSHOP MODULES')`: the `_buildMenuTile(...)` calls for `'Quotations / Estimates'`, `'Garage Expenses'`, `'Staff Directory & Roles'`, `'Attendance & Payroll Slips'` (each followed by `const SizedBox(height: 8)`). Wrap the Expenses, Staff, and Attendance tiles + their trailing SizedBox in conditional spreads:

```dart
          if (provider.can('expenses.manage')) ...[
            _buildMenuTile(
              context,
              // ... unchanged Expenses tile arguments ...
            ),
            const SizedBox(height: 8),
          ],
```

Same pattern for `provider.can('staff.manage')` around the Staff tile and `provider.can('attendance.manage')` around the Attendance & Payroll tile. Leave Quotations ungated (no `quotations.manage`-less UI exists; any member may browse).

At the end of the ListView children (after the last tile/section), append:

```dart
          const SizedBox(height: 20),
          _buildMenuTile(
            context,
            icon: Icons.logout_rounded,
            badgeBg: palette.badgeRedBg,
            color: palette.badgeRedIcon,
            title: 'Sign out',
            subtitle: 'End this session on this device',
            onTap: () async {
              final session = context.read<AuthSession?>();
              if (session == null) return; // test/mock mode
              await session.signOut();
              session.handleSessionExpired();
            },
          ),
```

Add imports to more_menu_screen.dart:

```dart
import 'package:provider/provider.dart'; // already present
import '../../data/api/auth_session.dart';
```

Note: `context.read<AuthSession?>()` returns null when no AuthSession provider exists (provider supports nullable lookups) — that is the test/mock mode no-op path.

**dashboard_screen.dart:** Read the file around lines 360-380 (pendingTotal / dues section) and 430-460 (todayExpenses figure). Wrap:
- The widget subtree that renders the Expenses figure (the `CurrencyFormatter.format(provider.todayExpenses)` at ~:447 — identify its enclosing card/section and the adjacent label) in `if (provider.can('expenses.manage')) ...[ ... ]` (or a ternary returning `const SizedBox.shrink()` where spread syntax does not fit the context).
- The pending-dues section (`final pendingTotal = provider.totalPendingPayments;` at ~:371 feeding the dues UI ending with `'No pending dues'` at ~:536) in `if (provider.can('invoices.manage'))`.

The exact enclosing widgets must be read from the file before editing — do not guess; keep the diff minimal (wrap, don't restructure). If the gated section participates in a `Column`, use spread; if it's a single child slot, use a ternary with `SizedBox.shrink`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/api/permission_gating_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!` (smoke test pins survive: full-permission default keeps everything visible).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/more/more_menu_screen.dart lib/screens/dashboard/dashboard_screen.dart test/api/permission_gating_test.dart
git commit -m "feat: permission-gate more-menu tiles, dashboard figures and add sign-out"
```

---

### Task 13: Final verification

**Files:** none created; gates + audit + final review.

- [ ] **Step 1: Full Flutter gates (separate calls)**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 2: Go gates still green (backend untouched, verify anyway — from backend/)**

Run: `go vet ./...`
Expected: exit 0.

Run: `go test ./...`
Expected: `ok` lines, no FAIL.

- [ ] **Step 3: Grep audits**

From repo root, verify no forbidden patterns crept in:

```
grep -rn "as double\b" lib/data/api lib/screens/auth lib/widgets/app_shell.dart
grep -rn "print(" lib/data/api lib/screens/auth
grep -rn "Color(0x" lib/data/api lib/screens/auth lib/widgets/app_shell.dart
```

Expected: no matches (num-casts rule, no debug prints, no raw color literals in new code).

Verify the repository implements the whole interface:

```
grep -c "@override" lib/data/api/http_garage_repository.dart
```

Expected: `38`.

- [ ] **Step 4: Commit any straggler fixes** (only if audits found something; otherwise skip)

- [ ] **Step 5: Final code review**

Dispatch the final code-reviewer subagent over the whole Phase 3 diff (first Phase 3 commit..HEAD). Address Important findings, then finish with the standard finishing-a-development-branch flow (on main, matching Phase 1/2: nothing to merge; report completion).

Known manual follow-ups for the user (do NOT attempt — classifier blocks running the Windows app):
- `flutter run -d windows` visual pass on LoginScreen + logged-in shell.
- Start `backend/` (`go run ./cmd/server`) and set the server URL (default `http://localhost:8080`) on the login screen; register an owner, log in, verify dashboard loads live data.
