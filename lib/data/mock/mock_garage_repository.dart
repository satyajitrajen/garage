import '../../models/customer.dart';
import '../../models/expense.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../models/maintenance_item.dart';
import '../../models/payment.dart';
import '../../models/quotation.dart';
import '../../models/staff.dart';
import '../../models/vehicle.dart';
import '../../services/mock_data_service.dart';
import '../app_config.dart';
import '../garage_profile.dart';
import '../garage_repository.dart';

class MockGarageRepository implements GarageRepository {
  final List<Customer> _customers;
  final List<Vehicle> _vehicles;
  final List<Staff> _staff;
  final List<JobCard> _jobCards;
  final List<Quotation> _quotations;
  final List<Invoice> _invoices;
  final List<GarageExpense> _expenses;
  final List<AttendanceRecord> _attendance;
  final List<SalaryAdvance> _salaryAdvances;
  final List<MaintenanceItem> _catalog;

  factory MockGarageRepository() {
    final staff = MockDataService.getInitialStaff();
    return MockGarageRepository._(
      customers: MockDataService.getInitialCustomers(),
      vehicles: MockDataService.getInitialVehicles(),
      catalog: MockDataService.getCatalogItems(),
      staff: staff,
      jobCards: MockDataService.getInitialJobCards(),
      quotations: MockDataService.getInitialQuotations(),
      invoices: MockDataService.getInitialInvoices(),
      expenses: MockDataService.getInitialExpenses(),
      attendance: MockDataService.getInitialAttendance(staff),
      salaryAdvances: MockDataService.getInitialSalaryAdvances(),
    );
  }

  MockGarageRepository._({
    required List<Customer> customers,
    required List<Vehicle> vehicles,
    required List<Staff> staff,
    required List<JobCard> jobCards,
    required List<Quotation> quotations,
    required List<Invoice> invoices,
    required List<GarageExpense> expenses,
    required List<AttendanceRecord> attendance,
    required List<SalaryAdvance> salaryAdvances,
    required List<MaintenanceItem> catalog,
  })  : _customers = customers,
        _vehicles = vehicles,
        _staff = staff,
        _jobCards = jobCards,
        _quotations = quotations,
        _invoices = invoices,
        _expenses = expenses,
        _attendance = attendance,
        _salaryAdvances = salaryAdvances,
        _catalog = catalog;

  // Profile & config

  GarageProfile? _profile;
  AppConfig? _config;

  @override
  Future<GarageProfile> fetchProfile() async =>
      _profile ?? MockDataService.getGarageProfile();

  @override
  Future<AppConfig> fetchConfig() async =>
      _config ?? MockDataService.getAppConfig();

  @override
  Future<(GarageProfile, AppConfig)> updateSettings(
      GarageProfile profile, AppConfig config) async {
    _profile = profile;
    _config = config;
    return (profile, config);
  }

  // Customers

  @override
  Future<List<Customer>> fetchCustomers() async => List.of(_customers);

  @override
  Future<Customer> createCustomer(Customer customer) async {
    _customers.insert(0, customer);
    return customer;
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    final i = _customers.indexWhere((c) => c.id == customer.id);
    if (i == -1) throw Exception('Customer not found');
    _customers[i] = customer;
    return customer;
  }

  @override
  Future<bool> deleteCustomer(String customerId) async {
    final hasDues = _invoices.any(
      (inv) =>
          inv.customerId == customerId &&
          inv.status != InvoiceStatus.cancelled &&
          inv.balanceDue > 0.01,
    );
    if (hasDues) return false;
    _customers.removeWhere((c) => c.id == customerId);
    _vehicles.removeWhere((v) => v.customerId == customerId);
    return true;
  }

  // Vehicles

  @override
  Future<List<Vehicle>> fetchVehicles() async => List.of(_vehicles);

  @override
  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    _vehicles.insert(0, vehicle);
    return vehicle;
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final i = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (i == -1) throw Exception('Vehicle not found');
    _vehicles[i] = vehicle;
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    _vehicles.removeWhere((v) => v.id == vehicleId);
  }

  // Staff

  @override
  Future<List<Staff>> fetchStaff() async => List.of(_staff);

  @override
  Future<Staff> createStaff(Staff staff) async {
    _staff.insert(0, staff);
    return staff;
  }

  @override
  Future<Staff> updateStaff(Staff staff) async {
    final i = _staff.indexWhere((s) => s.id == staff.id);
    if (i == -1) throw Exception('Staff not found');
    _staff[i] = staff;
    return staff;
  }

  @override
  Future<void> deleteStaff(String staffId) async {
    _staff.removeWhere((s) => s.id == staffId);
  }

  // Job cards

  @override
  Future<List<JobCard>> fetchJobCards() async => List.of(_jobCards);

  @override
  Future<JobCard> createJobCard(JobCard jobCard) async {
    _jobCards.insert(0, jobCard);
    return jobCard;
  }

  @override
  Future<JobCard> updateJobCard(JobCard jobCard) async {
    final i = _jobCards.indexWhere((jc) => jc.id == jobCard.id);
    if (i == -1) throw Exception('Job card not found');
    _jobCards[i] = jobCard;
    return jobCard;
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
  Future<JobCard> upsertJobCardItem(
    String jobCardId,
    MaintenanceItem item,
  ) async {
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

  // Quotations

  @override
  Future<List<Quotation>> fetchQuotations() async => List.of(_quotations);

  @override
  Future<Quotation> createQuotation(Quotation quotation) async {
    _quotations.insert(0, quotation);
    return quotation;
  }

  @override
  Future<Quotation> updateQuotation(Quotation quotation) async {
    final i = _quotations.indexWhere((q) => q.id == quotation.id);
    if (i == -1) throw Exception('Quotation not found');
    _quotations[i] = quotation;
    return quotation;
  }

  @override
  Future<Quotation> updateQuotationStatus(
    String quotationId,
    QuotationStatus status,
  ) async {
    final i = _quotations.indexWhere((q) => q.id == quotationId);
    if (i == -1) throw Exception('Quotation not found');
    _quotations[i] = _quotations[i].copyWith(status: status);
    return _quotations[i];
  }

  // Invoices & payments

  @override
  Future<List<Invoice>> fetchInvoices() async => List.of(_invoices);

  @override
  Future<Invoice> createInvoice(Invoice invoice) async {
    _invoices.insert(0, invoice);
    return invoice;
  }

  @override
  Future<Invoice> updateInvoice(Invoice invoice) async {
    final i = _invoices.indexWhere((inv) => inv.id == invoice.id);
    if (i == -1) throw Exception('Invoice not found');
    _invoices[i] = invoice;
    return invoice;
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
  Future<Invoice> cancelInvoice(String invoiceId) async {
    final i = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (i == -1) throw Exception('Invoice not found');
    final invoice = _invoices[i];
    if (invoice.totalPaidAmount > 0) {
      throw Exception('Cannot cancel an invoice with recorded payments');
    }
    return _invoices[i] = invoice.copyWith(cancelledAt: DateTime.now());
  }

  // Expenses

  @override
  Future<List<GarageExpense>> fetchExpenses() async => List.of(_expenses);

  @override
  Future<GarageExpense> createExpense(GarageExpense expense) async {
    _expenses.insert(0, expense);
    return expense;
  }

  @override
  Future<GarageExpense> updateExpense(GarageExpense expense) async {
    final i = _expenses.indexWhere((e) => e.id == expense.id);
    if (i == -1) throw Exception('Expense not found');
    _expenses[i] = expense;
    return expense;
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    _expenses.removeWhere((e) => e.id == expenseId);
  }

  // Attendance

  @override
  Future<AttendanceRecord> saveAttendance(AttendanceRecord record) async {
    final i = _attendance.indexWhere(
      (a) =>
          a.staffId == record.staffId &&
          a.date.year == record.date.year &&
          a.date.month == record.date.month &&
          a.date.day == record.date.day,
    );
    if (i != -1) {
      _attendance[i] = record;
    } else {
      _attendance.add(record);
    }
    return record;
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance() async =>
      List.of(_attendance);

  // Salary advances

  @override
  Future<List<SalaryAdvance>> fetchSalaryAdvances() async =>
      List.of(_salaryAdvances);

  @override
  Future<SalaryAdvance> createSalaryAdvance(SalaryAdvance advance) async {
    _salaryAdvances.insert(0, advance);
    return advance;
  }

  @override
  Future<List<SalaryAdvance>> settleSalaryAdvances(
    String staffId,
    int month,
    int year,
  ) async {
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

  // Catalog

  @override
  Future<List<MaintenanceItem>> fetchCatalog() async => List.of(_catalog);

  @override
  Future<MaintenanceItem> createCatalogItem(MaintenanceItem item) async {
    _catalog.add(item);
    return item;
  }

  @override
  Future<MaintenanceItem> updateCatalogItem(MaintenanceItem item) async {
    final i = _catalog.indexWhere((c) => c.id == item.id);
    if (i == -1) throw StateError('Catalog item not found');
    _catalog[i] = item;
    return item;
  }

  @override
  Future<void> deleteCatalogItem(String itemId) async {
    _catalog.removeWhere((c) => c.id == itemId);
  }
}
