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
import 'api_client.dart';
import 'api_exception.dart';
import 'model_json.dart';

/// HTTP [GarageRepository] backed by the Go backend.
///
/// Wire rules (verified against `backend/internal/api`):
/// - Domain objects are camelCase; settings/profile are snake_case.
/// - Lists are `{items: [...]}`; creates are 201, deletes 204.
/// - `POST /salary-advances/settle` uses snake_case `staff_id`.
/// - `PATCH /garages/{id}/members/{userId}` uses snake_case `is_active`.
/// - IDs are server-generated on create (client `id` is ignored).
class ApiGarageRepository implements GarageRepository {
  ApiGarageRepository(this._api);

  final ApiClient _api;

  String get _garageId {
    final id = _api.garageId;
    if (id == null || id.isEmpty) {
      throw const ApiException(0, 'no_garage', 'No garage selected.');
    }
    return id;
  }

  /// Blanks the client's provisional document number so the server allocates
  /// it from the garage's sequence. Numbers computed from a local cache
  /// collide when two devices create documents at the same time.
  Map<String, dynamic> _serverNumbered(Map<String, dynamic> body, String key) =>
      {...body, key: ''};

  /// Page size for list fetches (the server caps `limit` at 200).
  static const _pageSize = 200;

  /// Fetches a whole collection through the paged list API. Endpoints that
  /// don't page ignore the params and answer with the legacy `{items}` shape
  /// (no `total`), which is the complete list.
  Future<List<T>> _fetchAll<T>(
      String path, T Function(Map<String, dynamic>) fromJson) async {
    final all = <T>[];
    var offset = 0;
    while (true) {
      final json = await _api.get('$path?limit=$_pageSize&offset=$offset');
      final page = _items(json, fromJson);
      all.addAll(page);
      final total = json is Map<String, dynamic> ? json['total'] : null;
      if (total is! num || page.isEmpty || all.length >= total) return all;
      offset += page.length;
    }
  }

  List<T> _items<T>(
      dynamic json, T Function(Map<String, dynamic>) fromJson) {
    if (json is Map<String, dynamic>) {
      final raw = json['items'];
      if (raw is List) {
        return [
          for (final e in raw) fromJson(e as Map<String, dynamic>)
        ];
      }
    }
    return <T>[];
  }

  // ---------- Profile & config (via garage settings) ----------

  /// Profile and config come from the same settings document; share one
  /// in-flight request so a load() hits the endpoint once, not twice.
  Future<Map<String, dynamic>>? _settingsInFlight;

  Future<Map<String, dynamic>> _settings() {
    final pending = _settingsInFlight ??= _api
        .get('/api/garages/$_garageId/settings')
        .then((json) => json as Map<String, dynamic>);
    pending.whenComplete(() => _settingsInFlight = null).ignore();
    return pending;
  }

  @override
  Future<GarageProfile> fetchProfile() async =>
      profileFromJson((await _settings())['profile'] as Map<String, dynamic>);

  @override
  Future<AppConfig> fetchConfig() async =>
      appConfigFromSettings(await _settings());

  /// Partial settings PATCH. `profile` replaces the whole profile object, so
  /// all 8 profile fields are always sent.
  @override
  Future<(GarageProfile, AppConfig)> updateSettings(
      GarageProfile profile, AppConfig config) async {
    final json = await _api.patch('/api/garages/$_garageId/settings', {
      'profile': profileToJson(profile),
      ...configToPatchJson(config),
    }) as Map<String, dynamic>;
    return (
      profileFromJson(json['profile'] as Map<String, dynamic>),
      appConfigFromSettings(json),
    );
  }

  // ---------- Customers ----------

  @override
  Future<List<Customer>> fetchCustomers() async =>
      _fetchAll('/api/customers', customerFromJson);

  @override
  Future<Customer> createCustomer(Customer customer) async {
    final json = await _api.post(
        '/api/customers', customerToJson(customer)) as Map<String, dynamic>;
    return customerFromJson(json);
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    final json = await _api.put('/api/customers/${customer.id}',
        customerToJson(customer)) as Map<String, dynamic>;
    return customerFromJson(json);
  }

  @override
  Future<bool> deleteCustomer(String customerId) async {
    try {
      await _api.delete('/api/customers/$customerId');
      return true;
    } on ApiException catch (e) {
      if (e.isConflict) return false;
      rethrow;
    }
  }

  // ---------- Vehicles ----------

  @override
  Future<List<Vehicle>> fetchVehicles() async =>
      _fetchAll('/api/vehicles', vehicleFromJson);

  @override
  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final json = await _api.post(
        '/api/vehicles', vehicleToJson(vehicle)) as Map<String, dynamic>;
    return vehicleFromJson(json);
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final json = await _api.put('/api/vehicles/${vehicle.id}',
        vehicleToJson(vehicle)) as Map<String, dynamic>;
    return vehicleFromJson(json);
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    await _api.delete('/api/vehicles/$vehicleId');
  }

  // ---------- Staff ----------

  @override
  Future<List<Staff>> fetchStaff() async =>
      _fetchAll('/api/staff', staffFromJson);

  @override
  Future<Staff> createStaff(Staff staff) async {
    final json = await _api.post('/api/staff', staffToJson(staff))
        as Map<String, dynamic>;
    return staffFromJson(json);
  }

  @override
  Future<Staff> updateStaff(Staff staff) async {
    final json = await _api.put('/api/staff/${staff.id}', staffToJson(staff))
        as Map<String, dynamic>;
    return staffFromJson(json);
  }

  @override
  Future<void> deleteStaff(String staffId) async {
    await _api.delete('/api/staff/$staffId');
  }

  // ---------- Job cards ----------

  @override
  Future<List<JobCard>> fetchJobCards() async =>
      _fetchAll('/api/jobcards', jobCardFromJson);

  @override
  Future<JobCard> createJobCard(JobCard jobCard) async {
    final json = await _api.post('/api/jobcards',
            _serverNumbered(jobCardToJson(jobCard), 'jobCardNumber'))
        as Map<String, dynamic>;
    return jobCardFromJson(json);
  }

  @override
  Future<JobCard> updateJobCard(JobCard jobCard) async {
    final json = await _api.put(
        '/api/jobcards/${jobCard.id}', jobCardToJson(jobCard))
        as Map<String, dynamic>;
    return jobCardFromJson(json);
  }

  @override
  Future<JobCard> updateJobStatus(String jobCardId, JobStatus status) async {
    final json = await _api.post('/api/jobcards/$jobCardId/status', {
      'status': status.name,
    }) as Map<String, dynamic>;
    return jobCardFromJson(json);
  }

  @override
  Future<JobCard> upsertJobCardItem(
      String jobCardId, MaintenanceItem item) async {
    // Server upserts by item id and returns the saved item; re-fetch the card
    // so the caller's cache holds items + computed totals in sync.
    await _api.post(
        '/api/jobcards/$jobCardId/items', maintenanceItemToJson(item));
    final cards = await fetchJobCards();
    return cards.firstWhere((c) => c.id == jobCardId);
  }

  @override
  Future<JobCard> removeJobCardItem(String jobCardId, String itemId) async {
    await _api.delete('/api/jobcards/$jobCardId/items/$itemId');
    final cards = await fetchJobCards();
    return cards.firstWhere((c) => c.id == jobCardId);
  }

  // ---------- Quotations ----------

  @override
  Future<List<Quotation>> fetchQuotations() async =>
      _fetchAll('/api/quotations', quotationFromJson);

  @override
  Future<Quotation> createQuotation(Quotation quotation) async {
    final json = await _api.post('/api/quotations',
            _serverNumbered(quotationToJson(quotation), 'quotationNumber'))
        as Map<String, dynamic>;
    return quotationFromJson(json);
  }

  @override
  Future<Quotation> updateQuotation(Quotation quotation) async {
    final json = await _api.put('/api/quotations/${quotation.id}',
        quotationToJson(quotation)) as Map<String, dynamic>;
    return quotationFromJson(json);
  }

  @override
  Future<Quotation> updateQuotationStatus(
      String quotationId, QuotationStatus status) async {
    final json = await _api.post('/api/quotations/$quotationId/status', {
      'status': status.name,
    }) as Map<String, dynamic>;
    return quotationFromJson(json);
  }

  // ---------- Invoices & payments ----------

  @override
  Future<List<Invoice>> fetchInvoices() async =>
      _fetchAll('/api/invoices', invoiceFromJson);

  @override
  Future<Invoice> createInvoice(Invoice invoice) async {
    final json = await _api.post('/api/invoices',
            _serverNumbered(invoiceToJson(invoice), 'invoiceNumber'))
        as Map<String, dynamic>;
    return invoiceFromJson(json);
  }

  @override
  Future<Invoice> updateInvoice(Invoice invoice) async {
    final json = await _api.put(
        '/api/invoices/${invoice.id}', invoiceToJson(invoice))
        as Map<String, dynamic>;
    return invoiceFromJson(json);
  }

  @override
  Future<Payment> createPayment(Payment payment) async {
    // Body is the record-payment shape (invoice id lives in the URL).
    final json = await _api.post('/api/invoices/${payment.invoiceId}/payments', {
      'amount': payment.amount,
      'mode': payment.mode.name,
      if (payment.customerId != null) 'customerId': payment.customerId,
      if (payment.transactionRef != null)
        'transactionRef': payment.transactionRef,
      if (payment.notes != null) 'notes': payment.notes,
      if (payment.receivedBy != null) 'receivedBy': payment.receivedBy,
    }) as Map<String, dynamic>;
    return paymentFromJson(json);
  }

  @override
  Future<Invoice> cancelInvoice(String invoiceId) async {
    final json = await _api.post('/api/invoices/$invoiceId/cancel')
        as Map<String, dynamic>;
    return invoiceFromJson(json);
  }

  // ---------- Expenses ----------

  @override
  Future<List<GarageExpense>> fetchExpenses() async =>
      _fetchAll('/api/expenses', expenseFromJson);

  @override
  Future<GarageExpense> createExpense(GarageExpense expense) async {
    final json = await _api.post('/api/expenses', expenseToJson(expense))
        as Map<String, dynamic>;
    return expenseFromJson(json);
  }

  @override
  Future<GarageExpense> updateExpense(GarageExpense expense) async {
    final json = await _api.put(
        '/api/expenses/${expense.id}', expenseToJson(expense))
        as Map<String, dynamic>;
    return expenseFromJson(json);
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _api.delete('/api/expenses/$expenseId');
  }

  // ---------- Attendance ----------

  @override
  Future<AttendanceRecord> saveAttendance(AttendanceRecord record) async {
    final json = await _api.post('/api/attendance', attendanceToJson(record))
        as Map<String, dynamic>;
    return attendanceFromJson(json);
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance() async =>
      _fetchAll('/api/attendance', attendanceFromJson);

  // ---------- Salary advances ----------

  @override
  Future<List<SalaryAdvance>> fetchSalaryAdvances() async =>
      _fetchAll('/api/salary-advances', salaryAdvanceFromJson);

  @override
  Future<SalaryAdvance> createSalaryAdvance(SalaryAdvance advance) async {
    final json = await _api.post(
        '/api/salary-advances', salaryAdvanceToJson(advance))
        as Map<String, dynamic>;
    return salaryAdvanceFromJson(json);
  }

  @override
  Future<List<SalaryAdvance>> settleSalaryAdvances(
      String staffId, int month, int year) async {
    // NOTE: snake_case `staff_id` — the one exception to camelCase domains.
    final json = await _api.post('/api/salary-advances/settle', {
      'staff_id': staffId,
      'month': month,
      'year': year,
    });
    return _items(json, salaryAdvanceFromJson);
  }

  // ---------- Catalog ----------

  @override
  Future<List<MaintenanceItem>> fetchCatalog() async =>
      _fetchAll('/api/catalog', catalogItemFromJson);

  @override
  Future<MaintenanceItem> createCatalogItem(MaintenanceItem item) async {
    final json = await _api.post('/api/catalog', _catalogBody(item))
        as Map<String, dynamic>;
    return catalogItemFromJson(json);
  }

  @override
  Future<MaintenanceItem> updateCatalogItem(MaintenanceItem item) async {
    final json = await _api.put('/api/catalog/${item.id}', _catalogBody(item))
        as Map<String, dynamic>;
    return catalogItemFromJson(json);
  }

  Map<String, dynamic> _catalogBody(MaintenanceItem item) => {
        'name': item.name,
        'category': item.category.name,
        'unitPrice': item.unitPrice,
        'taxPercent': item.taxPercent,
        'unit': item.unit,
        'isLabour': item.isLabour,
        'partNumber': item.partNumber,
        'notes': item.notes,
      };

  @override
  Future<void> deleteCatalogItem(String itemId) async {
    await _api.delete('/api/catalog/$itemId');
  }
}
