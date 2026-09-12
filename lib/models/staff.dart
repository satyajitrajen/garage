enum StaffRole {
  headMechanic,
  seniorTechnician,
  autoElectrician,
  denterPainter,
  helperTrainee,
  serviceAdvisor,
  manager,
}

extension StaffRoleExtension on StaffRole {
  String get displayName {
    switch (this) {
      case StaffRole.headMechanic:
        return 'Head Mechanic';
      case StaffRole.seniorTechnician:
        return 'Senior Technician';
      case StaffRole.autoElectrician:
        return 'Auto Electrician';
      case StaffRole.denterPainter:
        return 'Denter & Painter';
      case StaffRole.helperTrainee:
        return 'Helper / Trainee';
      case StaffRole.serviceAdvisor:
        return 'Service Advisor';
      case StaffRole.manager:
        return 'Workshop Manager';
    }
  }
}

enum AttendanceStatus {
  present,
  halfDay,
  absent,
  leave,
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.leave:
        return 'Paid Leave';
    }
  }
}

class AttendanceRecord {
  final String id;
  final String staffId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.date,
    required this.status,
    this.notes,
  });
}

class SalaryAdvance {
  final String id;
  final String staffId;
  final double amount;
  final DateTime date;
  final String? reason;
  final bool isDeducted;

  SalaryAdvance({
    required this.id,
    required this.staffId,
    required this.amount,
    required this.date,
    this.reason,
    this.isDeducted = false,
  });
}

class Staff {
  final String id;
  final String name;
  final StaffRole role;
  final String phone;
  final String? email;
  final double monthlySalary;
  final DateTime joiningDate;
  final bool isActive;
  final String? address;
  final String? emergencyContact;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.email,
    required this.monthlySalary,
    DateTime? joiningDate,
    this.isActive = true,
    this.address,
    this.emergencyContact,
  }) : joiningDate = joiningDate ?? DateTime.now();

  Staff copyWith({
    String? id,
    String? name,
    StaffRole? role,
    String? phone,
    String? email,
    double? monthlySalary,
    DateTime? joiningDate,
    bool? isActive,
    String? address,
    String? emergencyContact,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }
}
