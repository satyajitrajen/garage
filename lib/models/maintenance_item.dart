enum ItemCategory {
  sparePart,
  labour,
  fluids,
  tyresBattery,
  transportMisc,
  custom,
}

extension ItemCategoryExtension on ItemCategory {
  String get displayName {
    switch (this) {
      case ItemCategory.sparePart:
        return 'Spare Parts';
      case ItemCategory.labour:
        return 'Labour & Service';
      case ItemCategory.fluids:
        return 'Oils & Fluids';
      case ItemCategory.tyresBattery:
        return 'Tyres & Battery';
      case ItemCategory.transportMisc:
        return 'Transport / Misc';
      case ItemCategory.custom:
        return 'Custom Item';
    }
  }
}

/// Tax per GST rate for [items] taxed at their own rates, with a document
/// discount spread pro-rata: each line's taxable amount is scaled by
/// taxable / gross. Must match InvoiceMoney.Grand in the Go backend.
Map<double, double> perItemTaxBreakdown(
  List<MaintenanceItem> items,
  double gross,
  double taxable,
) {
  final factor = gross > 0 ? taxable / gross : 0.0;
  final byRate = <double, double>{};
  for (final item in items) {
    if (item.taxPercent <= 0) continue;
    byRate.update(
      item.taxPercent,
      (tax) => tax + item.taxAmount * factor,
      ifAbsent: () => item.taxAmount * factor,
    );
  }
  return Map.fromEntries(
      byRate.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

class MaintenanceItem {
  final String id;
  final String name;
  final ItemCategory category;
  final double unitPrice;
  final double quantity;
  final String unit; // 'Pcs', 'Ltr', 'Hours', 'Set', 'Bottle', 'Job'
  final double discountPercent;
  final double taxPercent; // e.g. 18.0 for 18% GST or 0
  final bool isLabour;
  final String? partNumber;
  final String? notes;
  final String? assignedStaffId;

  MaintenanceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    this.quantity = 1.0,
    this.unit = 'Pcs',
    this.discountPercent = 0.0,
    this.taxPercent = 0.0,
    this.isLabour = false,
    this.partNumber,
    this.notes,
    this.assignedStaffId,
  });

  double get grossAmount => unitPrice * quantity;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get taxableAmount => grossAmount - discountAmount;
  double get taxAmount => taxableAmount * (taxPercent / 100);
  double get totalAmount => taxableAmount + taxAmount;

  MaintenanceItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    double? unitPrice,
    double? quantity,
    String? unit,
    double? discountPercent,
    double? taxPercent,
    bool? isLabour,
    String? partNumber,
    String? notes,
    String? assignedStaffId,
  }) {
    return MaintenanceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      discountPercent: discountPercent ?? this.discountPercent,
      taxPercent: taxPercent ?? this.taxPercent,
      isLabour: isLabour ?? this.isLabour,
      partNumber: partNumber ?? this.partNumber,
      notes: notes ?? this.notes,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
    );
  }
}
