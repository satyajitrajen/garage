enum FuelType {
  petrol,
  diesel,
  cng,
  electric,
  hybrid,
}

extension FuelTypeExtension on FuelType {
  String get displayName {
    switch (this) {
      case FuelType.petrol:
        return 'Petrol';
      case FuelType.diesel:
        return 'Diesel';
      case FuelType.cng:
        return 'CNG';
      case FuelType.electric:
        return 'Electric';
      case FuelType.hybrid:
        return 'Hybrid';
    }
  }
}

class Vehicle {
  final String id;
  final String customerId;
  final String registrationNumber; // e.g. MH 12 AB 1234
  final String make; // e.g. Maruti Suzuki, Hyundai
  final String model; // e.g. Swift Dzire, Creta
  final String? variant; // e.g. VXI, SX (O)
  final int? year; // e.g. 2021
  final FuelType fuelType;
  final int currentKm;
  final String? color;
  final String? chassisNumber;
  final String? engineNumber;
  final DateTime createdAt;
  final DateTime? lastServiceDate;

  Vehicle({
    required this.id,
    required this.customerId,
    required this.registrationNumber,
    required this.make,
    required this.model,
    this.variant,
    this.year,
    this.fuelType = FuelType.petrol,
    required this.currentKm,
    this.color,
    this.chassisNumber,
    this.engineNumber,
    DateTime? createdAt,
    this.lastServiceDate,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName => '$make $model ${variant != null ? '($variant)' : ''}'.trim();

  Vehicle copyWith({
    String? id,
    String? customerId,
    String? registrationNumber,
    String? make,
    String? model,
    String? variant,
    int? year,
    FuelType? fuelType,
    int? currentKm,
    String? color,
    String? chassisNumber,
    String? engineNumber,
    DateTime? createdAt,
    DateTime? lastServiceDate,
  }) {
    return Vehicle(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      variant: variant ?? this.variant,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      currentKm: currentKm ?? this.currentKm,
      color: color ?? this.color,
      chassisNumber: chassisNumber ?? this.chassisNumber,
      engineNumber: engineNumber ?? this.engineNumber,
      createdAt: createdAt ?? this.createdAt,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
    );
  }
}
