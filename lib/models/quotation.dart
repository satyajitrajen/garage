import 'maintenance_item.dart';

enum QuotationStatus {
  draft,
  sent,
  approved,
  converted,
  rejected,
}

extension QuotationStatusExtension on QuotationStatus {
  String get displayName {
    switch (this) {
      case QuotationStatus.draft:
        return 'Draft';
      case QuotationStatus.sent:
        return 'Sent to Customer';
      case QuotationStatus.approved:
        return 'Customer Approved';
      case QuotationStatus.converted:
        return 'Converted to Job';
      case QuotationStatus.rejected:
        return 'Declined';
    }
  }
}

class Quotation {
  final String id;
  final String quotationNumber; // e.g. EST-1001
  final String customerId;
  final String vehicleId;
  final int kmReading;
  final List<MaintenanceItem> items;
  final double overallDiscount;
  /// Document-level GST rate. Only used by legacy estimates
  /// ([perItemTax] false); newer estimates tax each line at its own rate.
  final double taxPercent;
  final bool perItemTax;
  final int validityDays;
  final QuotationStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime validUntil;

  Quotation({
    required this.id,
    required this.quotationNumber,
    required this.customerId,
    required this.vehicleId,
    required this.kmReading,
    required this.items,
    this.overallDiscount = 0.0,
    this.taxPercent = 18.0,
    this.perItemTax = false,
    this.validityDays = 7,
    this.status = QuotationStatus.draft,
    this.notes,
    DateTime? createdAt,
    DateTime? validUntil,
  })  : createdAt = createdAt ?? DateTime.now(),
        validUntil = validUntil ??
            (createdAt ?? DateTime.now()).add(Duration(days: validityDays));

  double get partsSubtotal => items
      .where((item) => !item.isLabour)
      .fold(0.0, (sum, item) => sum + item.taxableAmount);

  double get labourSubtotal => items
      .where((item) => item.isLabour)
      .fold(0.0, (sum, item) => sum + item.taxableAmount);

  double get grossSubtotal => partsSubtotal + labourSubtotal;
  double get discountedAmount => (grossSubtotal - overallDiscount).clamp(0, double.infinity);

  /// GST per rate (rate → tax amount); see [Invoice.taxBreakdown].
  Map<double, double> get taxBreakdown => perItemTax
      ? perItemTaxBreakdown(items, grossSubtotal, discountedAmount)
      : {if (taxPercent > 0) taxPercent: discountedAmount * taxPercent / 100};

  double get totalTaxAmount =>
      taxBreakdown.values.fold(0.0, (sum, tax) => sum + tax);
  double get grandTotal => discountedAmount + totalTaxAmount;

  Quotation copyWith({
    String? id,
    String? quotationNumber,
    String? customerId,
    String? vehicleId,
    int? kmReading,
    List<MaintenanceItem>? items,
    double? overallDiscount,
    double? taxPercent,
    bool? perItemTax,
    int? validityDays,
    QuotationStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? validUntil,
  }) {
    return Quotation(
      id: id ?? this.id,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      customerId: customerId ?? this.customerId,
      vehicleId: vehicleId ?? this.vehicleId,
      kmReading: kmReading ?? this.kmReading,
      items: items ?? this.items,
      overallDiscount: overallDiscount ?? this.overallDiscount,
      taxPercent: taxPercent ?? this.taxPercent,
      perItemTax: perItemTax ?? this.perItemTax,
      validityDays: validityDays ?? this.validityDays,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      validUntil: validUntil ?? this.validUntil,
    );
  }
}
