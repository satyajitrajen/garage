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
  double get balanceDue => (grandTotal - totalPaidAmount).clamp(0, double.infinity);

  InvoiceStatus get status {
    if (balanceDue <= 0.01) {
      return InvoiceStatus.paid;
    } else if (totalPaidAmount > 0) {
      return InvoiceStatus.partial;
    } else {
      return InvoiceStatus.pending;
    }
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? jobCardId,
    String? customerId,
    String? vehicleId,
    int? kmReading,
    List<MaintenanceItem>? items,
    double? discountAmount,
    double? taxPercent,
    List<Payment>? payments,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? notes,
    String? termsAndConditions,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      jobCardId: jobCardId ?? this.jobCardId,
      customerId: customerId ?? this.customerId,
      vehicleId: vehicleId ?? this.vehicleId,
      kmReading: kmReading ?? this.kmReading,
      items: items ?? this.items,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercent: taxPercent ?? this.taxPercent,
      payments: payments ?? this.payments,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }
}
