class Customer {
  final String id;
  final String name;
  final String phone;
  final String? whatsappNumber;
  final String? email;
  final String? address;
  final String? gstin;
  final String? notes;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.whatsappNumber,
    this.email,
    this.address,
    this.gstin,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get effectiveWhatsApp => (whatsappNumber != null && whatsappNumber!.isNotEmpty) 
      ? whatsappNumber! 
      : phone;

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsappNumber,
    String? email,
    String? address,
    String? gstin,
    String? notes,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
