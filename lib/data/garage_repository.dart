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
    String staffId,
    int month,
    int year,
  );

  Future<List<MaintenanceItem>> fetchCatalog();
}
