import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/vehicle.dart';
import '../models/maintenance_item.dart';
import '../models/job_card.dart';
import '../models/quotation.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../models/staff.dart';
import '../services/mock_data_service.dart';

class GarageProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  // State collections
  List<Customer> _customers = [];
  List<Vehicle> _vehicles = [];
  List<JobCard> _jobCards = [];
  List<Quotation> _quotations = [];
  List<Invoice> _invoices = [];
  List<Payment> _payments = [];
  List<GarageExpense> _expenses = [];
  List<Staff> _staff = [];
  List<AttendanceRecord> _attendance = [];
  List<SalaryAdvance> _salaryAdvances = [];
  List<MaintenanceItem> _catalog = [];

  // Theme mode toggle
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  GarageProvider() {
    _initMockData();
  }

  void _initMockData() {
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

    // Collect all payments from invoices
    _payments = [];
    for (var inv in _invoices) {
      _payments.addAll(inv.payments);
    }
  }

  // Getters
  List<Customer> get customers => List.unmodifiable(_customers);
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<JobCard> get jobCards => List.unmodifiable(_jobCards);
  List<Quotation> get quotations => List.unmodifiable(_quotations);
  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<Payment> get payments => List.unmodifiable(_payments);
  List<GarageExpense> get expenses => List.unmodifiable(_expenses);
  List<Staff> get staff => List.unmodifiable(_staff);
  List<AttendanceRecord> get attendance => List.unmodifiable(_attendance);
  List<SalaryAdvance> get salaryAdvances => List.unmodifiable(_salaryAdvances);
  List<MaintenanceItem> get catalog => List.unmodifiable(_catalog);

  // -------------------------------------------------------------
  // DASHBOARD CALCULATIONS & ANALYTICS
  // -------------------------------------------------------------
  double get todayCollection {
    final now = DateTime.now();
    return _payments.where((p) {
      return p.paymentDate.year == now.year &&
          p.paymentDate.month == now.month &&
          p.paymentDate.day == now.day;
    }).fold(0.0, (sum, p) => sum + p.amount);
  }

  double get totalPendingPayments {
    return _invoices
        .where((inv) => inv.status != InvoiceStatus.cancelled)
        .fold(0.0, (sum, inv) => sum + inv.balanceDue);
  }

  double get todayExpenses {
    final now = DateTime.now();
    return _expenses.where((e) {
      return e.expenseDate.year == now.year &&
          e.expenseDate.month == now.month &&
          e.expenseDate.day == now.day;
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisMonthRevenue {
    final now = DateTime.now();
    return _payments.where((p) {
      return p.paymentDate.year == now.year && p.paymentDate.month == now.month;
    }).fold(0.0, (sum, p) => sum + p.amount);
  }

  double get thisMonthExpenses {
    final now = DateTime.now();
    return _expenses.where((e) {
      return e.expenseDate.year == now.year && e.expenseDate.month == now.month;
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  int get activeVehiclesUnderMaintenanceCount {
    return _jobCards.where((jc) {
      return jc.status != JobStatus.delivered && jc.status != JobStatus.cancelled;
    }).length;
  }

  List<JobCard> get activeJobCards {
    return _jobCards.where((jc) {
      return jc.status != JobStatus.delivered && jc.status != JobStatus.cancelled;
    }).toList();
  }

  List<JobCard> get recentJobCards {
    final sorted = List<JobCard>.from(_jobCards)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  List<Invoice> get recentInvoices {
    final sorted = List<Invoice>.from(_invoices)
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return sorted.take(5).toList();
  }

  Map<ExpenseCategory, double> get expenseCategoryBreakdown {
    final Map<ExpenseCategory, double> map = {};
    for (var cat in ExpenseCategory.values) {
      map[cat] = 0.0;
    }
    for (var exp in _expenses) {
      map[exp.category] = (map[exp.category] ?? 0.0) + exp.amount;
    }
    return map;
  }

  // -------------------------------------------------------------
  // CUSTOMER METHODS
  // -------------------------------------------------------------
  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Customer> searchCustomers(String query) {
    if (query.trim().isEmpty) return _customers;
    final q = query.toLowerCase().trim();

    return _customers.where((c) {
      final nameMatches = c.name.toLowerCase().contains(q);
      final phoneMatches = c.phone.contains(q);
      // Check if any of customer's vehicles match registration number
      final vehicles = getVehiclesForCustomer(c.id);
      final vehicleMatches = vehicles.any((v) =>
          v.registrationNumber.toLowerCase().replaceAll(' ', '').contains(q.replaceAll(' ', '')) ||
          v.model.toLowerCase().contains(q) ||
          v.make.toLowerCase().contains(q));

      return nameMatches || phoneMatches || vehicleMatches;
    }).toList();
  }

  Customer addCustomer(Customer customer) {
    _customers.insert(0, customer);
    notifyListeners();
    return customer;
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  /// Deletes a customer and their vehicles. Deletion is blocked while the
  /// customer still has outstanding dues on any invoice, otherwise those
  /// documents would silently orphan and corrupt pending-payment analytics.
  /// Returns false (and does not delete) when dues exist.
  bool deleteCustomer(String customerId) {
    if (getCustomerOutstandingBalance(customerId) > 0.01) {
      return false;
    }
    _customers.removeWhere((c) => c.id == customerId);
    _vehicles.removeWhere((v) => v.customerId == customerId);
    notifyListeners();
    return true;
  }

  double getCustomerOutstandingBalance(String customerId) {
    return _invoices
        .where((inv) => inv.customerId == customerId && inv.status != InvoiceStatus.cancelled)
        .fold(0.0, (sum, inv) => sum + inv.balanceDue);
  }

  // -------------------------------------------------------------
  // VEHICLE METHODS
  // -------------------------------------------------------------
  List<Vehicle> getVehiclesForCustomer(String customerId) {
    return _vehicles.where((v) => v.customerId == customerId).toList();
  }

  Vehicle? getVehicleById(String id) {
    try {
      return _vehicles.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Vehicle addVehicle(Vehicle vehicle) {
    _vehicles.insert(0, vehicle);
    notifyListeners();
    return vehicle;
  }

  void updateVehicle(Vehicle vehicle) {
    final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) {
      _vehicles[index] = vehicle;
      notifyListeners();
    }
  }

  void deleteVehicle(String vehicleId) {
    _vehicles.removeWhere((v) => v.id == vehicleId);
    notifyListeners();
  }

  List<JobCard> getServiceHistoryForVehicle(String vehicleId) {
    return _jobCards.where((jc) => jc.vehicleId == vehicleId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // -------------------------------------------------------------
  // JOB CARD METHODS
  // -------------------------------------------------------------
  JobCard? getJobCardById(String id) {
    try {
      return _jobCards.firstWhere((jc) => jc.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Generates a document number by scanning the given existing numbers and
  /// returning max(parsed)+1, so numbers stay unique even if records are
  /// ever deleted or seeded with gaps.
  String _nextNumber({
    required String prefix,
    required List<String> existingNumbers,
    required int firstNumber,
  }) {
    final regex = RegExp('^$prefix-(\\d+)\$');
    int max = firstNumber - 1;
    for (final number in existingNumbers) {
      final match = regex.firstMatch(number);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed > max) max = parsed;
      }
    }
    return '$prefix-${max + 1}';
  }

  String generateJobCardNumber() => _nextNumber(
        prefix: 'JC',
        existingNumbers: _jobCards.map((jc) => jc.jobCardNumber).toList(),
        firstNumber: 1001,
      );

  JobCard addJobCard(JobCard jobCard) {
    _jobCards.insert(0, jobCard);
    notifyListeners();
    return jobCard;
  }

  void updateJobCard(JobCard jobCard) {
    final index = _jobCards.indexWhere((jc) => jc.id == jobCard.id);
    if (index != -1) {
      _jobCards[index] = jobCard;
      notifyListeners();
    }
  }

  void updateJobStatus(String jobCardId, JobStatus status) {
    final index = _jobCards.indexWhere((jc) => jc.id == jobCardId);
    if (index != -1) {
      final isCompleted = status == JobStatus.delivered;
      _jobCards[index] = _jobCards[index].copyWith(
        status: status,
        // completedAt is only stamped once the vehicle is actually delivered;
        // moving a job back to an earlier state clears the stale timestamp.
        completedAt: isCompleted ? DateTime.now() : (status == JobStatus.cancelled ? _jobCards[index].completedAt : null),
      );
      notifyListeners();
    }
  }

  void addOrUpdateItemInJobCard(String jobCardId, MaintenanceItem item) {
    final index = _jobCards.indexWhere((jc) => jc.id == jobCardId);
    if (index != -1) {
      final currentJob = _jobCards[index];
      final currentItems = List<MaintenanceItem>.from(currentJob.items);
      final itemIndex = currentItems.indexWhere((i) => i.id == item.id);
      if (itemIndex != -1) {
        currentItems[itemIndex] = item;
      } else {
        currentItems.add(item);
      }
      _jobCards[index] = currentJob.copyWith(items: currentItems);
      notifyListeners();
    }
  }

  void removeItemFromJobCard(String jobCardId, String itemId) {
    final index = _jobCards.indexWhere((jc) => jc.id == jobCardId);
    if (index != -1) {
      final currentJob = _jobCards[index];
      final currentItems = List<MaintenanceItem>.from(currentJob.items)
        ..removeWhere((i) => i.id == itemId);
      _jobCards[index] = currentJob.copyWith(items: currentItems);
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // QUOTATION / ESTIMATE METHODS
  // -------------------------------------------------------------
  String generateQuotationNumber() => _nextNumber(
        prefix: 'EST',
        existingNumbers: _quotations.map((q) => q.quotationNumber).toList(),
        firstNumber: 1001,
      );

  Quotation addQuotation(Quotation quote) {
    _quotations.insert(0, quote);
    notifyListeners();
    return quote;
  }

  void updateQuotation(Quotation quote) {
    final index = _quotations.indexWhere((q) => q.id == quote.id);
    if (index != -1) {
      _quotations[index] = quote;
      notifyListeners();
    }
  }

  void updateQuotationStatus(String id, QuotationStatus status) {
    final index = _quotations.indexWhere((q) => q.id == id);
    if (index != -1) {
      _quotations[index] = _quotations[index].copyWith(status: status);
      notifyListeners();
    }
  }

  JobCard convertQuotationToJobCard(Quotation quote, {String? assignedStaffId}) {
    final jobCard = JobCard(
      id: _uuid.v4(),
      jobCardNumber: generateJobCardNumber(),
      customerId: quote.customerId,
      vehicleId: quote.vehicleId,
      customerComplaints: ['Converted from Estimate #${quote.quotationNumber}'],
      kmReading: quote.kmReading,
      assignedStaffId: assignedStaffId,
      status: JobStatus.inProgress,
      promisedDeliveryDate: DateTime.now().add(const Duration(hours: 6)),
      items: List.from(quote.items),
      supervisorNotes: 'Created directly from approved quotation ${quote.quotationNumber}',
    );

    addJobCard(jobCard);
    updateQuotationStatus(quote.id, QuotationStatus.converted);
    return jobCard;
  }

  // -------------------------------------------------------------
  // INVOICE METHODS
  // -------------------------------------------------------------
  String generateInvoiceNumber() => _nextNumber(
        prefix: 'INV-${DateTime.now().year}',
        existingNumbers: _invoices.map((inv) => inv.invoiceNumber).toList(),
        firstNumber: 1,
      );

  Invoice? getInvoiceById(String id) {
    try {
      return _invoices.firstWhere((inv) => inv.id == id);
    } catch (_) {
      return null;
    }
  }

  Invoice addInvoice(Invoice invoice) {
    _invoices.insert(0, invoice);
    if (invoice.payments.isNotEmpty) {
      for (var p in invoice.payments) {
        _payments.insert(0, p);
      }
    }
    // Update vehicle last serviced date & km
    final vehicle = getVehicleById(invoice.vehicleId);
    if (vehicle != null) {
      updateVehicle(vehicle.copyWith(
        currentKm: invoice.kmReading > vehicle.currentKm ? invoice.kmReading : vehicle.currentKm,
        lastServiceDate: invoice.invoiceDate,
      ));
    }
    // If associated with a job card, mark job card as delivered
    if (invoice.jobCardId != null) {
      updateJobStatus(invoice.jobCardId!, JobStatus.delivered);
    }
    notifyListeners();
    return invoice;
  }

  Invoice createInvoiceFromJobCard(JobCard jobCard, {double discount = 0, double taxPercent = 18.0}) {
    if (jobCard.items.isEmpty) {
      throw Exception('Cannot invoice a job card with no work items');
    }
    final invoice = Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateInvoiceNumber(),
      jobCardId: jobCard.id,
      customerId: jobCard.customerId,
      vehicleId: jobCard.vehicleId,
      kmReading: jobCard.kmReading,
      items: List.from(jobCard.items),
      discountAmount: discount,
      taxPercent: taxPercent,
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 7)),
      notes: 'Thank you for choosing us! Standard warranty applies.',
      termsAndConditions: 'All parts replaced carry manufacturer warranty. Labour warranty 30 days.',
    );

    return addInvoice(invoice);
  }

  // -------------------------------------------------------------
  // PAYMENT METHODS
  // -------------------------------------------------------------
  Payment recordPayment({
    required String invoiceId,
    required double amount,
    required PaymentMode mode,
    String? transactionRef,
    String? notes,
    String? receivedBy,
  }) {
    final invoiceIndex = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (invoiceIndex == -1) throw Exception('Invoice not found');

    final invoice = _invoices[invoiceIndex];
    if (invoice.status == InvoiceStatus.cancelled) {
      throw Exception('Cannot record payment against a cancelled invoice');
    }
    // Guard against overpayment / invalid amounts so collections analytics
    // cannot be inflated by a bad caller (tiny epsilon for float noise).
    const epsilon = 0.01;
    if (amount <= 0 || amount > invoice.balanceDue + epsilon) {
      throw Exception(
        'Payment amount must be between 0 and ${invoice.balanceDue.toStringAsFixed(2)}',
      );
    }
    // Never record more than the remaining balance.
    final safeAmount = amount.clamp(0.0, invoice.balanceDue);
    final payment = Payment(
      id: _uuid.v4(),
      invoiceId: invoiceId,
      customerId: invoice.customerId,
      amount: safeAmount,
      mode: mode,
      transactionRef: transactionRef,
      paymentDate: DateTime.now(),
      notes: notes,
      receivedBy: receivedBy ?? 'Cashier',
    );

    final updatedPayments = List<Payment>.from(invoice.payments)..add(payment);
    _invoices[invoiceIndex] = invoice.copyWith(payments: updatedPayments);
    _payments.insert(0, payment);

    notifyListeners();
    return payment;
  }

  // -------------------------------------------------------------
  // EXPENSE METHODS
  // -------------------------------------------------------------
  GarageExpense addExpense(GarageExpense expense) {
    _expenses.insert(0, expense);
    notifyListeners();
    return expense;
  }

  void updateExpense(GarageExpense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      notifyListeners();
    }
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // STAFF, ATTENDANCE & SALARY METHODS
  // -------------------------------------------------------------
  Staff? getStaffById(String id) {
    try {
      return _staff.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Staff addStaff(Staff staffMember) {
    _staff.add(staffMember);
    notifyListeners();
    return staffMember;
  }

  void updateStaff(Staff staffMember) {
    final index = _staff.indexWhere((s) => s.id == staffMember.id);
    if (index != -1) {
      _staff[index] = staffMember;
      notifyListeners();
    }
  }

  void deleteStaff(String staffId) {
    _staff.removeWhere((s) => s.id == staffId);
    notifyListeners();
  }

  int getStaffActiveJobCount(String staffId) {
    return _jobCards.where((jc) {
      return jc.assignedStaffId == staffId &&
          jc.status != JobStatus.delivered &&
          jc.status != JobStatus.cancelled;
    }).length;
  }

  AttendanceRecord? getAttendanceForStaffOnDate(String staffId, DateTime date) {
    try {
      return _attendance.firstWhere((a) =>
          a.staffId == staffId &&
          a.date.year == date.year &&
          a.date.month == date.month &&
          a.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  void markAttendance({
    required String staffId,
    required DateTime date,
    required AttendanceStatus status,
    String? notes,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final index = _attendance.indexWhere((a) =>
        a.staffId == staffId &&
        a.date.year == date.year &&
        a.date.month == date.month &&
        a.date.day == date.day);

    if (index != -1) {
      _attendance[index] = AttendanceRecord(
        id: _attendance[index].id,
        staffId: staffId,
        date: normalizedDate,
        status: status,
        notes: notes,
      );
    } else {
      _attendance.add(
        AttendanceRecord(
          id: _uuid.v4(),
          staffId: staffId,
          date: normalizedDate,
          status: status,
          notes: notes,
        ),
      );
    }
    notifyListeners();
  }

  void markAllPresentToday() {
    final today = DateTime.now();
    for (var s in _staff) {
      if (s.isActive) {
        markAttendance(staffId: s.id, date: today, status: AttendanceStatus.present);
      }
    }
  }

  SalaryAdvance addSalaryAdvance({
    required String staffId,
    required double amount,
    String? reason,
  }) {
    final advance = SalaryAdvance(
      id: _uuid.v4(),
      staffId: staffId,
      amount: amount,
      date: DateTime.now(),
      reason: reason,
    );
    _salaryAdvances.insert(0, advance);

    // Also record this as a Garage Expense under staff salaries/refreshments
    final staffMember = getStaffById(staffId);
    addExpense(GarageExpense(
      id: _uuid.v4(),
      title: 'Salary Advance - ${staffMember?.name ?? "Staff"}',
      category: ExpenseCategory.miscellaneous,
      amount: amount,
      paymentMode: PaymentMode.cash,
      notes: reason,
    ));

    notifyListeners();
    return advance;
  }

  /// Disburses the net salary for a staff member for [month]/[year]:
  /// marks all outstanding advances for that month as deducted and records
  /// the payout as a real workshop expense so monthly P&L stays accurate.
  void disburseSalary({
    required String staffId,
    required int month,
    required int year,
    required double netPayable,
  }) {
    final staffMember = getStaffById(staffId);
    if (staffMember == null) return;

    // Mark this month's advances as settled in payroll.
    for (var i = 0; i < _salaryAdvances.length; i++) {
      final adv = _salaryAdvances[i];
      if (adv.staffId == staffId && adv.date.month == month && adv.date.year == year && !adv.isDeducted) {
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

    addExpense(GarageExpense(
      id: _uuid.v4(),
      title: 'Salary Paid - ${staffMember.name} (${_monthName(month)} $year)',
      category: ExpenseCategory.miscellaneous,
      amount: netPayable,
      paymentMode: PaymentMode.cash,
      notes: 'Monthly salary disbursement for ${_monthName(month)} $year',
    ));
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  List<SalaryAdvance> getAdvancesForStaff(String staffId, {int? month, int? year}) {
    return _salaryAdvances.where((adv) {
      if (adv.staffId != staffId) return false;
      if (month != null && adv.date.month != month) return false;
      if (year != null && adv.date.year != year) return false;
      return true;
    }).toList();
  }

  Map<String, dynamic> calculateMonthlySalarySummary(String staffId, int month, int year) {
    final staffMember = getStaffById(staffId);
    if (staffMember == null) return {};

    final monthlyRecords = _attendance.where((a) {
      return a.staffId == staffId && a.date.month == month && a.date.year == year;
    }).toList();

    int presentCount = 0;
    int halfDayCount = 0;
    int absentCount = 0;
    int leaveCount = 0;

    for (var rec in monthlyRecords) {
      switch (rec.status) {
        case AttendanceStatus.present:
          presentCount++;
          break;
        case AttendanceStatus.halfDay:
          halfDayCount++;
          break;
        case AttendanceStatus.absent:
          absentCount++;
          break;
        case AttendanceStatus.leave:
          leaveCount++;
          break;
      }
    }

    final advances = getAdvancesForStaff(staffId, month: month, year: year);
    final totalAdvances = advances.fold(0.0, (sum, a) => sum + a.amount);

    const workingDays = 26; // approx 26 working days in a month
    final dailyRate = staffMember.monthlySalary / workingDays;
    final absentDeduction = absentCount * dailyRate;
    final halfDayDeduction = halfDayCount * (dailyRate / 2);
    final totalDeductions = absentDeduction + halfDayDeduction + totalAdvances;

    final netPayable = (staffMember.monthlySalary - totalDeductions).clamp(0, double.infinity);

    return {
      'baseSalary': staffMember.monthlySalary,
      'workingDays': workingDays,
      'presentDays': presentCount,
      'halfDays': halfDayCount,
      'absentDays': absentCount,
      'leaveDays': leaveCount,
      'dailyRate': dailyRate,
      'absentDeduction': absentDeduction,
      'halfDayDeduction': halfDayDeduction,
      'totalAdvances': totalAdvances,
      'totalDeductions': totalDeductions,
      'netPayable': netPayable,
    };
  }
}
