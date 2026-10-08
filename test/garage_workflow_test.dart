import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:garage_manager/models/vehicle.dart';
import 'package:garage_manager/models/job_card.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/models/quotation.dart';
import 'package:garage_manager/models/invoice.dart';
import 'package:garage_manager/models/payment.dart';
import 'package:garage_manager/models/expense.dart';
import 'package:garage_manager/models/staff.dart';
import 'package:garage_manager/data/app_config.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/services/mock_data_service.dart';

void main() {
  group('NT Garage State & Workflow Tests', () {
    late GarageProvider provider;

    setUp(() async {
      provider = GarageProvider(MockGarageRepository());
      await provider.load();
    });

    test('Initial Seed Data Loaded Correctly', () {
      expect(provider.customers.isNotEmpty, isTrue);
      expect(provider.vehicles.isNotEmpty, isTrue);
      expect(provider.jobCards.isNotEmpty, isTrue);
      expect(provider.quotations.isNotEmpty, isTrue);
      expect(provider.invoices.isNotEmpty, isTrue);
      expect(provider.expenses.isNotEmpty, isTrue);
      expect(provider.staff.isNotEmpty, isTrue);
      expect(provider.catalog.isNotEmpty, isTrue);
    });

    test('Customer & Vehicle Registration Flow', () async {
      final initialCustomerCount = provider.customers.length;
      final newCustomer = Customer(
        id: 'test_c_1',
        name: 'Sunil Gavaskar',
        phone: '+91 99880 11223',
      );
      await provider.addCustomer(newCustomer);
      expect(provider.customers.length, equals(initialCustomerCount + 1));

      final newVehicle = Vehicle(
        id: 'test_v_1',
        customerId: 'test_c_1',
        registrationNumber: 'DL 01 AA 9999',
        make: 'Toyota',
        model: 'Fortuner',
        fuelType: FuelType.diesel,
        currentKm: 50000,
      );
      await provider.addVehicle(newVehicle);

      final customerVehicles = provider.getVehiclesForCustomer('test_c_1');
      expect(customerVehicles.length, equals(1));
      expect(customerVehicles.first.registrationNumber, equals('DL 01 AA 9999'));
    });

    test('Job Card Lifecycle & Maintenance Items Flow', () async {
      final initialJobCount = provider.jobCards.length;
      final jobCard = JobCard(
        id: 'test_jc_1',
        jobCardNumber: provider.generateJobCardNumber(),
        customerId: 'c_1',
        vehicleId: 'v_1',
        customerComplaints: ['Engine oil change', 'Front brake noise'],
        kmReading: 35000,
        promisedDeliveryDate: DateTime.now().add(const Duration(hours: 4)),
        status: JobStatus.inProgress,
        items: [
          MaintenanceItem(
            id: 'item_1',
            name: 'Synthetic Engine Oil',
            category: ItemCategory.fluids,
            unitPrice: 2800.0,
            quantity: 1,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'item_2',
            name: 'General Service Labour',
            category: ItemCategory.labour,
            unitPrice: 1200.0,
            quantity: 1,
            isLabour: true,
            taxPercent: 18.0,
          ),
        ],
      );

      await provider.addJobCard(jobCard);
      expect(provider.jobCards.length, equals(initialJobCount + 1));
      expect(jobCard.partsTotal, equals(3304.0)); // 2800 + 18% GST (504) = 3304
      expect(jobCard.labourTotal, equals(1416.0)); // 1200 + 18% GST (216) = 1416
      expect(jobCard.grandTotal, equals(4720.0));

      // Update status
      await provider.updateJobStatus(jobCard.id, JobStatus.readyForDelivery);
      final updated = provider.getJobCardById(jobCard.id);
      expect(updated?.status, equals(JobStatus.readyForDelivery));
    });

    test('Quotation to Job Card and Invoice Conversion Flow', () async {
      final quote = Quotation(
        id: 'test_q_1',
        quotationNumber: provider.generateQuotationNumber(),
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 35000,
        validityDays: 15,
        items: [
          MaintenanceItem(
            id: 'qi_1',
            name: 'Brake Pads Replacement',
            category: ItemCategory.sparePart,
            unitPrice: 1800.0,
          ),
        ],
      );
      await provider.addQuotation(quote);

      // Lifecycle guard: only approved estimates can be converted.
      await provider.updateQuotationStatus(quote.id, QuotationStatus.approved);

      // Convert quotation to Job Card
      final convertedJc = await provider.convertQuotationToJobCard(
          provider.quotations.firstWhere((q) => q.id == quote.id));
      expect(convertedJc.customerId, equals('c_1'));
      expect(convertedJc.items.length, equals(1));
      expect(provider.quotations.firstWhere((q) => q.id == quote.id).status, equals(QuotationStatus.converted));
    });

    test('quotation lifecycle: approve -> convert, decline, guard', () async {
      // Seed data has no draft quotation, so create one (status defaults to
      // draft) and drive it through the full lifecycle.
      final draft = Quotation(
        id: 'test_q_lifecycle',
        quotationNumber: provider.generateQuotationNumber(),
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 35000,
        items: [
          MaintenanceItem(
            id: 'lq_1',
            name: 'Brake Pads Replacement',
            category: ItemCategory.sparePart,
            unitPrice: 1800.0,
          ),
        ],
      );
      await provider.addQuotation(draft);

      await provider.updateQuotationStatus(draft.id, QuotationStatus.approved);
      expect(provider.quotations.firstWhere((q) => q.id == draft.id).status,
          QuotationStatus.approved);

      final jobCard = await provider.convertQuotationToJobCard(
          provider.quotations.firstWhere((q) => q.id == draft.id));
      expect(jobCard.customerId, draft.customerId);
      expect(provider.quotations.firstWhere((q) => q.id == draft.id).status,
          QuotationStatus.converted);

      // After declining, the quotation is no longer approved: the provider
      // guard must reject conversion of anything that is not approved.
      await provider.updateQuotationStatus(draft.id, QuotationStatus.rejected);
      final stillDraft = provider.quotations.firstWhere(
          (q) => q.status == QuotationStatus.draft,
          orElse: () => draft);
      expect(
          () => provider.convertQuotationToJobCard(
              stillDraft.copyWith(status: QuotationStatus.draft)),
          throwsException);
    });

    test('convert guard validates the CURRENT cache, not a stale approved object', () async {
      // Defense-in-depth pin: convertQuotationToJobCard re-checks the
      // quotation's status in the provider's CURRENT cache instead of
      // trusting the passed object. Seed q_1 (EST-1001) ships approved, so
      // first grab the cached object while it is genuinely approved.
      final staleApproved = provider.quotations.firstWhere((q) => q.id == 'q_1');
      expect(staleApproved.status, QuotationStatus.approved);
      final jobCountBefore = provider.jobCards.length;

      // A legitimate provider method then moves the CURRENT cache entry out
      // of approved (e.g. the customer declines after approval), so the
      // caller's object goes stale while still claiming approved.
      await provider.updateQuotationStatus('q_1', QuotationStatus.rejected);
      expect(staleApproved.status, QuotationStatus.approved); // stale local copy

      // Conversion must throw EVEN THOUGH the passed object claims approved:
      // the guard reads the cache, which says rejected.
      expect(
          () => provider.convertQuotationToJobCard(staleApproved),
          throwsException);

      // And nothing leaked through: no job card was created, the cache entry
      // stays rejected.
      expect(provider.jobCards.length, jobCountBefore);
      expect(provider.quotations.firstWhere((q) => q.id == 'q_1').status,
          QuotationStatus.rejected);
    });

    test('Invoice Calculation & Payment Collection Flow', () async {
      final invoice = Invoice(
        id: 'test_inv_1',
        invoiceNumber: provider.generateInvoiceNumber(),
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 35000,
        items: [
          MaintenanceItem(
            id: 'invi_1',
            name: 'Oil Filter',
            category: ItemCategory.sparePart,
            unitPrice: 500.0,
            quantity: 2,
          ),
        ],
        taxPercent: 18.0,
        discountAmount: 100.0, // Subtotal 1000 - 100 = 900. Tax 18% on 900 = 162. Grand Total = 1062.
      );

      await provider.addInvoice(invoice);
      expect(invoice.grandTotal, equals(1062.0));
      expect(invoice.balanceDue, equals(1062.0));
      expect(invoice.status, equals(InvoiceStatus.pending));

      // Partial Payment: Pay 500
      await provider.recordPayment(
        invoiceId: invoice.id,
        amount: 500.0,
        mode: PaymentMode.upi,
      );

      final partialInv = provider.getInvoiceById(invoice.id);
      expect(partialInv?.totalPaidAmount, equals(500.0));
      expect(partialInv?.balanceDue, equals(562.0));
      expect(partialInv?.status, equals(InvoiceStatus.partial));

      // Settle remaining balance 562
      await provider.recordPayment(
        invoiceId: invoice.id,
        amount: 562.0,
        mode: PaymentMode.cash,
      );

      final paidInv = provider.getInvoiceById(invoice.id);
      expect(paidInv?.totalPaidAmount, equals(1062.0));
      expect(paidInv?.balanceDue, equals(0.0));
      expect(paidInv?.status, equals(InvoiceStatus.paid));
    });

    test('Garage Expenses Logging & Dashboard Totals', () async {
      final initialExpenseCount = provider.expenses.length;
      final expense = GarageExpense(
        id: 'test_exp_1',
        title: 'Workshop Cleaning Supplies',
        category: ExpenseCategory.consumables,
        amount: 1500.0,
        paymentMode: PaymentMode.cash,
      );

      await provider.addExpense(expense);
      expect(provider.expenses.length, equals(initialExpenseCount + 1));
      expect(provider.todayExpenses, greaterThanOrEqualTo(1500.0));
    });

    test('expense update persists through repository', () async {
      final exp = provider.expenses.first;
      await provider.updateExpense(exp.copyWith(amount: exp.amount + 100));
      expect(provider.expenses.firstWhere((e) => e.id == exp.id).amount,
          exp.amount + 100);
    });

    test('job card item upsert/remove via provider', () async {
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

    test('job card item upsert REPLACES an existing line (no duplicate)', () async {
      // Seed job card jc_2 starts with 3 items. Upserting the same item id a
      // second time must swap the line in place: list length unchanged, the
      // single surviving entry carrying the new quantity and rate. Fractional
      // quantity (0.5 hours of labour) is a first-class case here.
      final jc = provider.jobCards.firstWhere((j) => j.id == 'jc_2');
      final initialCount = jc.items.length;
      final labour = provider.catalog.firstWhere((c) => c.id == 'cat_14');

      await provider.addOrUpdateItemInJobCard(jc.id, labour.copyWith(quantity: 2));
      var current = provider.jobCards.firstWhere((x) => x.id == jc.id);
      expect(current.items.length, initialCount + 1);
      expect(current.items.singleWhere((i) => i.id == labour.id).quantity, 2);

      await provider.addOrUpdateItemInJobCard(
          jc.id, labour.copyWith(quantity: 0.5, unitPrice: 999.0));
      current = provider.jobCards.firstWhere((x) => x.id == jc.id);
      expect(current.items.length, initialCount + 1); // replaced, not appended
      final replaced = current.items.singleWhere((i) => i.id == labour.id);
      expect(replaced.quantity, 0.5);
      expect(replaced.unitPrice, 999.0);
    });

    test('Staff Attendance & Monthly Salary Net Payout Calculation', () async {
      final staffMember = provider.staff.first; // Ramesh Sharma, 28,000 monthly
      final now = DateTime.now();

      // Mark 2 absent days and 1 half day
      await provider.markAttendance(
        staffId: staffMember.id,
        date: DateTime(now.year, now.month, 10),
        status: AttendanceStatus.absent,
      );
      await provider.markAttendance(
        staffId: staffMember.id,
        date: DateTime(now.year, now.month, 11),
        status: AttendanceStatus.absent,
      );
      await provider.markAttendance(
        staffId: staffMember.id,
        date: DateTime(now.year, now.month, 12),
        status: AttendanceStatus.halfDay,
      );

      final summary = provider.calculateMonthlySalarySummary(
        staffMember.id,
        now.month,
        now.year,
      );

      expect(summary['baseSalary'], equals(28000.0));
      expect(summary['absentDays'], greaterThanOrEqualTo(2));
      expect(summary['halfDays'], greaterThanOrEqualTo(1));
      expect(summary['netPayable'], lessThan(28000.0));
    });

    test('Vehicle Deletion and Expense Deletion', () async {
      final initialVehiclesCount = provider.vehicles.length;
      final vehicleToDelete = provider.vehicles.first;
      await provider.deleteVehicle(vehicleToDelete.id);
      expect(provider.vehicles.length, equals(initialVehiclesCount - 1));
      expect(provider.getVehicleById(vehicleToDelete.id), isNull);

      final initialExpensesCount = provider.expenses.length;
      final expenseToDelete = provider.expenses.first;
      await provider.deleteExpense(expenseToDelete.id);
      expect(provider.expenses.length, equals(initialExpensesCount - 1));
    });

    test('Quotation Conversion Instantiates Invoice Directly Without First Invoice Dependency', () async {
      final quote = provider.quotations.first;
      final newInvoice = await provider.addInvoice(
        Invoice(
          id: 'test_direct_inv',
          invoiceNumber: provider.generateInvoiceNumber(),
          customerId: quote.customerId,
          vehicleId: quote.vehicleId,
          kmReading: quote.kmReading,
          items: quote.items,
          discountAmount: quote.overallDiscount,
          taxPercent: quote.taxPercent,
          invoiceDate: DateTime.now(),
        ),
      );
      expect(newInvoice.id, equals('test_direct_inv'));
      expect(provider.getInvoiceById('test_direct_inv'), isNotNull);
    });

    test('invoice cancel: unpaid invoice becomes cancelled, paid cannot cancel', () async {
      final unpaid = provider.invoices.firstWhere((i) => i.totalPaidAmount == 0);
      // Capture BEFORE cancelling: balanceDue reads 0 once cancelled.
      final before = provider.totalPendingPayments;
      final unpaidDue = unpaid.balanceDue;

      await provider.cancelInvoice(unpaid.id);

      // Repo/cache round-trip: cancellation persisted on the provider copy.
      expect(provider.invoices.firstWhere((i) => i.id == unpaid.id).cancelledAt,
          isNotNull);
      expect(provider.invoices.firstWhere((i) => i.id == unpaid.id).status,
          InvoiceStatus.cancelled);
      // Cancelled invoice drops out of pending-payment analytics.
      expect(provider.totalPendingPayments, closeTo(before - unpaidDue, 0.01));

      // Cancelled invoices reject payments entirely (guard fires before the
      // amount guard, so any positive amount exercises it).
      expect(
        () => provider.recordPayment(
          invoiceId: unpaid.id,
          amount: unpaidDue,
          mode: PaymentMode.upi,
        ),
        throwsException,
      );

      // Invoices with recorded payments cannot be cancelled.
      final paid = provider.invoices.firstWhere((i) => i.totalPaidAmount > 0);
      expect(() => provider.cancelInvoice(paid.id), throwsException);
    });

    test('quick service checkout creates job card, invoice, payment; job delivered', () async {
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
      // Look the job up by the invoice's jobCardId rather than trusting list
      // position: the cache is newest-first today, but firstWhere encodes the
      // intent regardless of insertion order.
      final job = provider.jobCards.firstWhere((j) => j.id == invoice.jobCardId);
      expect(job.status, JobStatus.delivered); // addInvoice side effect
    });

    test('quick service checkout rejects an empty item list', () async {
      final vehicle = provider.vehicles.first;
      expect(
        () => provider.quickServiceCheckout(
          customerId: vehicle.customerId,
          vehicleId: vehicle.id,
          kmReading: vehicle.currentKm,
          items: const [],
        ),
        throwsException,
      );
    });

    test('config normalization preserves a default tax rate missing from its options', () {
      // The default tax rate is a billed money value: when the fetched
      // option list has drifted out of sync with it, normalization must
      // append the stored rate instead of rewriting it to options.first.
      final raw = AppConfig(defaultTaxPercent: 5.0, taxPercentOptions: const [0.0, 12.0, 18.0]);
      final healed = normalizeConfig(raw);
      expect(healed.defaultTaxPercent, 5.0);
      expect(healed.taxPercentOptions, contains(5.0));
      expect(healed.taxPercentOptions, [0.0, 12.0, 18.0, 5.0]);

      // A config whose default is already a member passes through unchanged.
      final consistent = normalizeConfig(const AppConfig());
      expect(consistent.defaultTaxPercent, 18.0);
      expect(consistent.taxPercentOptions, const [0.0, 5.0, 12.0, 18.0, 28.0]);

      // Empty option lists fall back to the default options, but the stored
      // default tax rate is still preserved as a member.
      final emptyOptions = normalizeConfig(
          AppConfig(defaultTaxPercent: 3.0, taxPercentOptions: const []));
      expect(emptyOptions.taxPercentOptions, const [0.0, 5.0, 12.0, 18.0, 28.0, 3.0]);
      expect(emptyOptions.defaultTaxPercent, 3.0);

      // The provider heals the repo config at fetch time, so the invariant
      // holds on the live config after load().
      expect(provider.config.taxPercentOptions, contains(provider.config.defaultTaxPercent));
    });

    test('isOverdue: past due date + balance owed only; never cancelled or paid', () {
      final item = MaintenanceItem(
        id: 'od_item',
        name: 'Brake Pads',
        category: ItemCategory.sparePart,
        unitPrice: 1000.0, // taxPercent defaults to 0 -> grand total 1000
      );
      final now = DateTime.now();

      // Unpaid with a past due date -> overdue.
      final overdue = Invoice(
        id: 'od_past',
        invoiceNumber: 'INV-TEST-PAST',
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 1000,
        items: [item],
        dueDate: now.subtract(const Duration(days: 2)),
      );
      expect(overdue.balanceDue, greaterThan(0));
      expect(overdue.isOverdue, isTrue);

      // Unpaid but due in the future (incl. later today) -> not overdue.
      final upcoming = Invoice(
        id: 'od_future',
        invoiceNumber: 'INV-TEST-FUTURE',
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 1000,
        items: [item],
        dueDate: now.add(const Duration(hours: 1)),
      );
      expect(upcoming.isOverdue, isFalse);

      // No due date set -> never overdue.
      final noDueDate = Invoice(
        id: 'od_nodue',
        invoiceNumber: 'INV-TEST-NODUE',
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 1000,
        items: [item],
      );
      expect(noDueDate.isOverdue, isFalse);

      // Cancelled with a past due date -> never overdue.
      final cancelled = Invoice(
        id: 'od_cancelled',
        invoiceNumber: 'INV-TEST-CANCELLED',
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 1000,
        items: [item],
        dueDate: now.subtract(const Duration(days: 2)),
        cancelledAt: now,
      );
      expect(cancelled.isOverdue, isFalse);

      // Fully paid with a past due date -> never overdue.
      final paid = Invoice(
        id: 'od_paid',
        invoiceNumber: 'INV-TEST-PAID',
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 1000,
        items: [item],
        taxPercent: 0.0, // keep grand total at exactly 1000
        dueDate: now.subtract(const Duration(days: 2)),
        payments: [
          Payment(
            id: 'od_pay_1',
            invoiceId: 'od_paid',
            amount: 1000.0,
            mode: PaymentMode.cash,
          ),
        ],
      );
      expect(paid.balanceDue, 0.0);
      expect(paid.isOverdue, isFalse);
    });

    test('profile & config are served from the data layer after load', () {
      // Compare against the repo's own seed source: if the seed changes, the
      // provider must follow — nothing about the garage identity may live in
      // the UI layer instead.
      final seedProfile = MockDataService.getGarageProfile();
      final seedConfig = MockDataService.getAppConfig();
      expect(provider.profile.name, seedProfile.name);
      expect(provider.profile.gstin, seedProfile.gstin);
      expect(provider.profile.phone, seedProfile.phone);
      expect(provider.profile.upiId, seedProfile.upiId);
      expect(provider.config.defaultTaxPercent, seedConfig.defaultTaxPercent);
      expect(provider.config.invoiceDueDays, seedConfig.invoiceDueDays);
      expect(provider.config.promisedDeliveryHours, seedConfig.promisedDeliveryHours);
      expect(provider.config.defaultReceivedBy, seedConfig.defaultReceivedBy);

      // Pre-load access is a programming error, surfaced loudly.
      final unloaded = GarageProvider(MockGarageRepository());
      expect(() => unloaded.profile, throwsStateError);
      expect(() => unloaded.config, throwsStateError);
    });

    test('recordPayment defaults receivedBy from config; explicit value honored', () async {
      final unpaid = provider.invoices.firstWhere((i) => i.totalPaidAmount == 0);
      final payment = await provider.recordPayment(
        invoiceId: unpaid.id,
        amount: unpaid.balanceDue,
        mode: PaymentMode.cash,
      );
      expect(payment.receivedBy, provider.config.defaultReceivedBy);

      // Explicit receivedBy (the collection screen's picker) wins.
      final fresh = await provider.quickServiceCheckout(
        customerId: provider.vehicles.first.customerId,
        vehicleId: provider.vehicles.first.id,
        kmReading: provider.vehicles.first.currentKm + 5,
        items: [provider.catalog.first.copyWith(id: 'rb-1', quantity: 1)],
        paymentAmount: 0,
      );
      final explicit = await provider.recordPayment(
        invoiceId: fresh.id,
        amount: fresh.balanceDue,
        mode: PaymentMode.upi,
        receivedBy: 'Ravi',
      );
      expect(explicit.receivedBy, 'Ravi');
    });
  });
}
