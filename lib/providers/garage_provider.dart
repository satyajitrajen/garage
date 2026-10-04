import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/api/api_exception.dart';
import '../data/app_config.dart';
import '../data/garage_profile.dart';
import '../data/garage_repository.dart';
import '../models/customer.dart';
import '../models/vehicle.dart';
import '../models/maintenance_item.dart';
import '../models/job_card.dart';
import '../models/quotation.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../models/staff.dart';

/// Thrown by [GarageProvider.quickServiceCheckout] when the job card was
/// created but billing it failed. Callers retry with [jobCard] so the retry
/// bills the same walk-in instead of opening a second job card.
class QuickServiceBillingException implements Exception {
  QuickServiceBillingException(this.jobCard, this.cause);

  final JobCard jobCard;
  final Object cause;

  @override
  String toString() {
    final reason = cause is ApiException
        ? (cause as ApiException).userMessage
        : cause.toString().replaceFirst('Exception: ', '');
    return 'Job card ${jobCard.jobCardNumber} saved, but billing failed: '
        '$reason. Tap Generate Bill to retry.';
  }
}

/// Single source of app state. All data is fetched from a [GarageRepository]
/// and mirrored in memory for synchronous reads by the UI; every mutation is
/// delegated to the repository first, then applied to the cache.
class GarageProvider extends ChangeNotifier {
  GarageProvider(this._repo);

  final GarageRepository _repo;
  final _uuid = const Uuid();

  bool _isLoading = true;
  String? _loadError;
  GarageProfile? _profile;
  AppConfig? _config;

  /// Best-effort post-commit failure from [addInvoice]'s follow-up side
  /// effects (vehicle odometer/service date, job card delivery). Surfaces as
  /// a warning instead of failing the save, so a retry cannot duplicate the
  /// committed invoice. Cleared at the start of every [addInvoice].
  String? _lastSideEffectWarning;

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

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Non-null when the last [addInvoice] committed the invoice but a
  /// follow-up side effect failed (see [addInvoice]).
  String? get sideEffectWarning => _lastSideEffectWarning;

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
        _unlessForbidden(_repo.fetchCustomers()),
        _unlessForbidden(_repo.fetchVehicles()),
        _unlessForbidden(_repo.fetchStaff()),
        _unlessForbidden(_repo.fetchJobCards()),
        _unlessForbidden(_repo.fetchQuotations()),
        _unlessForbidden(_repo.fetchInvoices()),
        _unlessForbidden(_repo.fetchExpenses()),
        _unlessForbidden(_repo.fetchAttendance()),
        _unlessForbidden(_repo.fetchSalaryAdvances()),
        _repo.fetchCatalog(),
      ]);
      _profile = results[0] as GarageProfile;
      _config = normalizeConfig(results[1] as AppConfig);
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
      if (showLoading) {
        _loadError = e is ApiException ? e.userMessage : e.toString();
      }
      if (!showLoading) return; // refresh failure: keep old data on screen
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Persists the invoice-header profile and business config.
  Future<void> updateSettings(GarageProfile profile, AppConfig config) async {
    final (savedProfile, savedConfig) =
        await _repo.updateSettings(profile, config);
    _profile = savedProfile;
    _config = normalizeConfig(savedConfig);
    notifyListeners();
  }

  /// Saves a reusable part/labour line to the garage's price list.
  Future<MaintenanceItem> addCatalogItem(MaintenanceItem item) async {
    final saved = await _repo.createCatalogItem(item);
    _catalog = [..._catalog, saved];
    notifyListeners();
    return saved;
  }

  Future<MaintenanceItem> updateCatalogItem(MaintenanceItem item) async {
    final saved = await _repo.updateCatalogItem(item);
    _catalog = [for (final c in _catalog) c.id == saved.id ? saved : c];
    notifyListeners();
    return saved;
  }

  Future<void> deleteCatalogItem(String itemId) async {
    await _repo.deleteCatalogItem(itemId);
    _catalog = _catalog.where((c) => c.id != itemId).toList();
    notifyListeners();
  }

  /// Each collection is gated by its own permission server-side, and staff
  /// logins lack some by default (expenses, staff, advances). A 403 means
  /// "not yours to see", so it loads as empty instead of failing the whole
  /// app load; any other error still propagates.
  static Future<List<T>> _unlessForbidden<T>(Future<List<T>> fetch) async {
    try {
      return await fetch;
    } on ApiException catch (e) {
      if (e.isForbidden) return <T>[];
      rethrow;
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

  List<Invoice> get recentInvoices {
    final sorted = List<Invoice>.from(_invoices)
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return sorted.take(5).toList();
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

  Future<Customer> addCustomer(Customer customer) async {
    final created = await _repo.createCustomer(customer);
    _customers.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final updated = await _repo.updateCustomer(customer);
    final index = _customers.indexWhere((c) => c.id == updated.id);
    if (index != -1) _customers[index] = updated;
    notifyListeners();
    return updated;
  }

  /// Deletes a customer and their vehicles. Deletion is blocked (returns
  /// false) while the customer still has outstanding dues on any invoice,
  /// otherwise those documents would silently orphan and corrupt
  /// pending-payment analytics.
  Future<bool> deleteCustomer(String customerId) async {
    final ok = await _repo.deleteCustomer(customerId);
    if (ok) {
      _customers.removeWhere((c) => c.id == customerId);
      _vehicles.removeWhere((v) => v.customerId == customerId);
      notifyListeners();
    }
    return ok;
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

  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    final created = await _repo.createVehicle(vehicle);
    _vehicles.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final updated = await _repo.updateVehicle(vehicle);
    final index = _vehicles.indexWhere((v) => v.id == updated.id);
    if (index != -1) _vehicles[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _repo.deleteVehicle(vehicleId);
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

  Future<JobCard> addJobCard(JobCard jobCard) async {
    final created = await _repo.createJobCard(jobCard);
    _jobCards.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<JobCard> updateJobCard(JobCard jobCard) async {
    final updated = await _repo.updateJobCard(jobCard);
    final index = _jobCards.indexWhere((jc) => jc.id == updated.id);
    if (index != -1) _jobCards[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<JobCard> updateJobStatus(String jobCardId, JobStatus status) async {
    final updated = await _repo.updateJobStatus(jobCardId, status);
    final index = _jobCards.indexWhere((jc) => jc.id == jobCardId);
    if (index != -1) _jobCards[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<JobCard> addOrUpdateItemInJobCard(
      String jobCardId, MaintenanceItem item) async {
    final updated = await _repo.upsertJobCardItem(jobCardId, item);
    final index = _jobCards.indexWhere((jc) => jc.id == jobCardId);
    if (index != -1) _jobCards[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<JobCard> removeItemFromJobCard(String jobCardId, String itemId) async {
    final updated = await _repo.removeJobCardItem(jobCardId, itemId);
    final index = _jobCards.indexWhere((jc) => jc.id == jobCardId);
    if (index != -1) _jobCards[index] = updated;
    notifyListeners();
    return updated;
  }

  // -------------------------------------------------------------
  // QUOTATION / ESTIMATE METHODS
  // -------------------------------------------------------------
  String generateQuotationNumber() => _nextNumber(
        prefix: 'EST',
        existingNumbers: _quotations.map((q) => q.quotationNumber).toList(),
        firstNumber: 1001,
      );

  Quotation? getQuotationById(String id) {
    try {
      return _quotations.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Quotation> addQuotation(Quotation quote) async {
    final created = await _repo.createQuotation(quote);
    _quotations.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<Quotation> updateQuotation(Quotation quote) async {
    final updated = await _repo.updateQuotation(quote);
    final index = _quotations.indexWhere((q) => q.id == updated.id);
    if (index != -1) _quotations[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<Quotation> updateQuotationStatus(String id, QuotationStatus status) async {
    final updated = await _repo.updateQuotationStatus(id, status);
    final index = _quotations.indexWhere((q) => q.id == id);
    if (index != -1) _quotations[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<JobCard> convertQuotationToJobCard(
    Quotation quote, {
    String? assignedStaffId,
  }) async {
    // Defense-in-depth: validate the CURRENT quotation in the cache rather
    // than trusting the passed object's status, which a caller may have
    // mutated locally or allowed to go stale.
    final currentIndex = _quotations.indexWhere((q) => q.id == quote.id);
    if (currentIndex == -1 ||
        _quotations[currentIndex].status != QuotationStatus.approved) {
      throw Exception('Only approved estimates can be converted to a job card');
    }
    final jobCard = JobCard(
      id: _uuid.v4(),
      jobCardNumber: generateJobCardNumber(),
      customerId: quote.customerId,
      vehicleId: quote.vehicleId,
      customerComplaints: ['Converted from Estimate #${quote.quotationNumber}'],
      kmReading: quote.kmReading,
      assignedStaffId: assignedStaffId,
      status: JobStatus.inProgress,
      promisedDeliveryDate:
          DateTime.now().add(Duration(hours: config.promisedDeliveryHours)),
      items: List.from(quote.items),
      supervisorNotes: 'Created directly from approved quotation ${quote.quotationNumber}',
    );

    // Store the repository-created job card (the cache already holds it) so
    // callers see the persisted object, not a local pre-insert copy.
    final created = await addJobCard(jobCard);
    await updateQuotationStatus(quote.id, QuotationStatus.converted);
    return created;
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

  Future<Invoice> addInvoice(Invoice invoice) async {
    _lastSideEffectWarning = null;
    final created = await _repo.createInvoice(invoice);
    _invoices.insert(0, created);
    _payments.insertAll(0, created.payments);
    // The invoice is committed at this point: a failed follow-up side effect
    // must NOT surface as an error — the caller would show a failure and the
    // user's retry would create a second invoice. Record a warning instead
    // (delivered to the UI with the notifyListeners cycle below).
    try {
      // Update vehicle last serviced date & km
      final vehicle = getVehicleById(created.vehicleId);
      if (vehicle != null) {
        await updateVehicle(vehicle.copyWith(
          currentKm: created.kmReading > vehicle.currentKm
              ? created.kmReading
              : vehicle.currentKm,
          lastServiceDate: created.invoiceDate,
        ));
      }
      // If associated with a job card, mark job card as delivered
      if (created.jobCardId != null) {
        await updateJobStatus(created.jobCardId!, JobStatus.delivered);
      }
    } catch (_) {
      _lastSideEffectWarning =
          'Invoice saved, but updating the vehicle/job card failed';
    }
    notifyListeners();
    return created;
  }

  Future<Invoice> createInvoiceFromJobCard(
    JobCard jobCard, {
    double discount = 0,
    double? taxPercent,
    String? notes,
  }) async {
    // Provider-level duplicate guard: the detail screen hides its button once
    // an invoice exists, but a retry that races a slow API (or lands while
    // the side effects are still running) must fail here instead of billing
    // the job twice.
    if (_invoices.any((inv) => inv.jobCardId == jobCard.id)) {
      throw Exception('This job card already has an invoice');
    }
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
      taxPercent: taxPercent ?? config.defaultTaxPercent,
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: config.invoiceDueDays)),
      notes: notes ?? config.invoiceNotes,
      termsAndConditions: config.invoiceTerms,
    );

    return addInvoice(invoice);
  }

  /// Quick Service counter flow in one call: opens a walk-in job card,
  /// bills it, and optionally records an advance payment. Used by the
  /// Quick Service wizard so a counter sale cannot leave a job card and
  /// invoice out of sync.
  Future<Invoice> quickServiceCheckout({
    required String customerId,
    required String vehicleId,
    required int kmReading,
    required List<MaintenanceItem> items,
    double discount = 0,
    double? taxPercent,
    double paymentAmount = 0,
    PaymentMode paymentMode = PaymentMode.cash,
    JobCard? existingJobCard,
  }) async {
    if (items.isEmpty) throw Exception('Add at least one service item');
    // A retry after a failed bill passes back the job card the first attempt
    // already created, so the walk-in is never opened twice.
    final jobCard = existingJobCard ?? await addJobCard(JobCard(
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
    // addInvoice marks the job delivered as a side effect (invoice is tied
    // to the job card), so the counter sale is closed out in one pass.
    final Invoice invoice;
    try {
      invoice = await createInvoiceFromJobCard(
        jobCard,
        discount: discount,
        taxPercent: taxPercent,
        notes: 'Quick Service counter bill',
      );
    } catch (e) {
      throw QuickServiceBillingException(jobCard, e);
    }
    if (paymentAmount > 0) {
      await recordPayment(
        invoiceId: invoice.id,
        amount: paymentAmount,
        mode: paymentMode,
      );
      // recordPayment replaces the invoice object in cache; hand back the
      // paid version so callers see the payment reflected.
      return getInvoiceById(invoice.id) ?? invoice;
    }
    return invoice;
  }

  /// Cancels an unpaid invoice. Invoices with recorded payments are blocked
  /// from cancellation so money already collected can never vanish from
  /// analytics; refunding is a separate workflow.
  Future<void> cancelInvoice(String invoiceId) async {
    final i = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (i == -1) throw Exception('Invoice not found');
    final invoice = _invoices[i];
    if (invoice.totalPaidAmount > 0) {
      throw Exception('Cannot cancel an invoice with recorded payments');
    }
    _invoices[i] = await _repo.cancelInvoice(invoiceId);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // PAYMENT METHODS
  // -------------------------------------------------------------
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
    // Guard against overpayment / invalid amounts so collections analytics
    // cannot be inflated by a bad caller (tiny epsilon for float noise).
    const epsilon = 0.01;
    if (amount <= 0 || amount > invoice.balanceDue + epsilon) {
      throw Exception(
          'Payment amount must be between 0 and ${invoice.balanceDue.toStringAsFixed(2)}');
    }
    // Never record more than the remaining balance.
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

  // -------------------------------------------------------------
  // EXPENSE METHODS
  // -------------------------------------------------------------
  Future<GarageExpense> addExpense(GarageExpense expense) async {
    final created = await _repo.createExpense(expense);
    _expenses.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<GarageExpense> updateExpense(GarageExpense expense) async {
    final updated = await _repo.updateExpense(expense);
    final index = _expenses.indexWhere((e) => e.id == updated.id);
    if (index != -1) _expenses[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<void> deleteExpense(String expenseId) async {
    await _repo.deleteExpense(expenseId);
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

  Future<Staff> addStaff(Staff staffMember) async {
    final created = await _repo.createStaff(staffMember);
    _staff.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<Staff> updateStaff(Staff staffMember) async {
    final updated = await _repo.updateStaff(staffMember);
    final index = _staff.indexWhere((s) => s.id == updated.id);
    if (index != -1) _staff[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<void> deleteStaff(String staffId) async {
    await _repo.deleteStaff(staffId);
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

  /// Static calendar-day equality helper shared by attendance lookups.
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  AttendanceRecord? getAttendanceForStaffOnDate(String staffId, DateTime date) {
    try {
      return _attendance
          .firstWhere((a) => a.staffId == staffId && _sameDay(a.date, date));
    } catch (_) {
      return null;
    }
  }

  Future<void> markAttendance({
    required String staffId,
    required DateTime date,
    required AttendanceStatus status,
    String? notes,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final record = AttendanceRecord(
      id: _uuid.v4(),
      staffId: staffId,
      date: normalizedDate,
      status: status,
      notes: notes,
    );
    final saved = await _repo.saveAttendance(record);

    final index = _attendance.indexWhere(
        (a) => a.staffId == staffId && _sameDay(a.date, normalizedDate));
    if (index != -1) {
      _attendance[index] = saved;
    } else {
      _attendance.add(saved);
    }
    notifyListeners();
  }

  Future<void> markAllPresentToday() async {
    final today = DateTime.now();
    for (var s in _staff) {
      if (s.isActive) {
        await markAttendance(
            staffId: s.id, date: today, status: AttendanceStatus.present);
      }
    }
  }

  Future<SalaryAdvance> addSalaryAdvance({
    required String staffId,
    required double amount,
    String? reason,
  }) async {
    final advance = SalaryAdvance(
      id: _uuid.v4(),
      staffId: staffId,
      amount: amount,
      date: DateTime.now(),
      reason: reason,
    );
    final saved = await _repo.createSalaryAdvance(advance);
    _salaryAdvances.insert(0, saved);
    notifyListeners();

    // Also record this as a Garage Expense under staff salaries/refreshments
    final staffMember = getStaffById(staffId);
    await addExpense(GarageExpense(
      id: _uuid.v4(),
      title: 'Salary Advance - ${staffMember?.name ?? "Staff"}',
      category: ExpenseCategory.miscellaneous,
      amount: amount,
      paymentMode: PaymentMode.cash,
      notes: reason,
    ));

    return saved;
  }

  /// Disburses the net salary for a staff member for [month]/[year]:
  /// marks all outstanding advances for that month as deducted and records
  /// the payout as a real workshop expense so monthly P&L stays accurate.
  Future<void> disburseSalary({
    required String staffId,
    required int month,
    required int year,
    required double netPayable,
  }) async {
    final staffMember = getStaffById(staffId);
    if (staffMember == null) return;

    // Mark this month's advances as settled in payroll.
    _salaryAdvances
      ..clear()
      ..addAll(await _repo.settleSalaryAdvances(staffId, month, year));

    await addExpense(GarageExpense(
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

    final workingDays =
        config.workingDaysPerMonth <= 0 ? 26 : config.workingDaysPerMonth;
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
