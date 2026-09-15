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
import '../../models/expense.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../models/maintenance_item.dart';
import '../../models/payment.dart';
import '../../models/quotation.dart';
import '../../models/staff.dart';
import '../../models/vehicle.dart';
import '../app_config.dart';
import '../garage_profile.dart';

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
      'createdAt': _instant(jc.createdAt),
      'estimatedCostNote': jc.estimatedCostNote,
      'supervisorNotes': jc.supervisorNotes,
    };

JobCard jobCardFromJson(Map<String, dynamic> j) => JobCard(
      id: j['id'] as String,
      jobCardNumber: j['jobCardNumber'] as String,
      customerId: j['customerId'] as String,
      vehicleId: j['vehicleId'] as String,
      customerComplaints: [
        for (final s in (j['customerComplaints'] as List? ?? [])) s as String
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
