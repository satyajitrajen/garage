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
      // Derived from payments: item 300 − 50 discount + 45 tax = 295 grand
      // total, 500 paid → balance clamps to 0 → paid (pending requires zero
      // payments, which contradicts the 500 payment asserted above).
      expect(reparsed.status, InvoiceStatus.paid);
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
