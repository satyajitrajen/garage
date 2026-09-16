import 'maintenance_item.dart';
import 'payment.dart';

enum InvoiceStatus {
  paid,
  partial,
  pending,
  cancelled,
}

extension InvoiceStatusExtension on InvoiceStatus {
  String get displayName {
    switch (this) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.partial:
        return 'Partially Paid';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class Invoice {
  final String id;
  final String invoiceNumber; // e.g. INV-2026-0101
  final String? jobCardId;
  final String customerId;
  final String vehicleId;
  final int kmReading;
  final List<MaintenanceItem> items;
  final double discountAmount;
  final double taxPercent; // e.g. 18% GST or 0
  final List<Payment> payments;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final DateTime? cancelledAt;
  final String? notes;
  final String? termsAndConditions;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    this.jobCardId,
    required this.customerId,
    required this.vehicleId,
    required this.kmReading,
    required this.items,
    this.discountAmount = 0.0,
    this.taxPercent = 18.0,
    List<Payment>? payments,
    DateTime? invoiceDate,
    this.dueDate,
    this.cancelledAt,
    this.notes,
    this.termsAndConditions,
  })  : payments = payments ?? [],
        invoiceDate = invoiceDate ?? DateTime.now();

  double get partsSubtotal => items
      .where((item) => !item.isLabour)
      .fold(0.0, (sum, item) => sum + item.taxableAmount);

  double get labourSubtotal => items
      .where((item) => item.isLabour)
      .fold(0.0, (sum, item) => sum + item.taxableAmount);

  double get grossSubtotal => partsSubtotal + labourSubtotal;
  double get taxableSubtotal => (grossSubtotal - discountAmount).clamp(0, double.infinity);
  double get cgstAmount => (taxPercent > 0) ? (taxableSubtotal * (taxPercent / 200)) : 0.0;
  double get sgstAmount => (taxPercent > 0) ? (taxableSubtotal * (taxPercent / 200)) : 0.0;
  double get totalTaxAmount => cgstAmount + sgstAmount;
  double get grandTotal => taxableSubtotal + totalTaxAmount;

  double get totalPaidAmount => payments.fold(0.0, (sum, p) => sum + p.amount);

  /// Raw balance ignores cancellation. It exists because [balanceDue] reads
  /// [status] (to zero out cancelled invoices) while [status] needs the
  /// balance to classify the invoice — calling [balanceDue] there would
  /// recurse forever.
  double get _rawBalanceDue =>
      (grandTotal - totalPaidAmount).clamp(0, double.infinity);

  double get balanceDue =>
      status == InvoiceStatus.cancelled ? 0 : _rawBalanceDue;

  InvoiceStatus get status {
    if (cancelledAt != null) return InvoiceStatus.cancelled;
    if (_rawBalanceDue <= 0.01) {
      return InvoiceStatus.paid;
    } else if (totalPaidAmount > 0) {
      return InvoiceStatus.partial;
    }
    return InvoiceStatus.pending;
  }

  /// An invoice is overdue when all four conditions hold: it has a [dueDate],
  /// it is not cancelled, [balanceDue] is still positive, and the due date is
  /// before the current instant. That last check is timestamp-based, so a due
  /// date later today does not trigger until the moment actually passes.
  /// Cancelled invoices zero out their balance and fully paid ones owe
  /// nothing, so the flag can never appear on either.
  bool get isOverdue {
    final due = dueDate;
    return due != null &&
        status != InvoiceStatus.cancelled &&
        balanceDue > 0 &&
        due.isBefore(DateTime.now());
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? jobCardId,
    bool clearJobCardId = false,
    String? customerId,
    String? vehicleId,
    int? kmReading,
    List<MaintenanceItem>? items,
    double? discountAmount,
    double? taxPercent,
    List<Payment>? payments,
    DateTime? invoiceDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? cancelledAt,
    String? notes,
    bool clearNotes = false,
    String? termsAndConditions,
    bool clearTerms = false,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      jobCardId: clearJobCardId ? null : (jobCardId ?? this.jobCardId),
      customerId: customerId ?? this.customerId,
      vehicleId: vehicleId ?? this.vehicleId,
      kmReading: kmReading ?? this.kmReading,
      items: items ?? this.items,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercent: taxPercent ?? this.taxPercent,
      payments: payments ?? this.payments,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      cancelledAt: cancelledAt ?? this.cancelledAt,
      notes: clearNotes ? null : (notes ?? this.notes),
      termsAndConditions:
          clearTerms ? null : (termsAndConditions ?? this.termsAndConditions),
    );
  }
}
