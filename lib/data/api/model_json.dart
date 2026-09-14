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

import '../../models/customer.dart';
import '../../models/maintenance_item.dart';
import '../../models/staff.dart';
import '../../models/vehicle.dart';

String _instant(DateTime d) => d.toUtc().toIso8601String();
DateTime _instantFrom(String s) => DateTime.parse(s).toLocal();

/// Formats the LOCAL calendar day of [d] (normalizing UTC inputs, since
/// day-grained wire fields must be the garage's wall-clock date).
String _day(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

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
      'createdAt': _instant(v.createdAt),
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
