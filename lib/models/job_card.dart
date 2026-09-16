import 'maintenance_item.dart';

enum JobStatus {
  received,
  inspection,
  inProgress,
  waitingParts,
  readyForDelivery,
  delivered,
  cancelled,
}

extension JobStatusExtension on JobStatus {
  String get displayName {
    switch (this) {
      case JobStatus.received:
        return 'Vehicle Received';
      case JobStatus.inspection:
        return 'Under Inspection';
      case JobStatus.inProgress:
        return 'Work In Progress';
      case JobStatus.waitingParts:
        return 'Waiting For Parts';
      case JobStatus.readyForDelivery:
        return 'Ready For Delivery';
      case JobStatus.delivered:
        return 'Delivered & Invoiced';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get shortName {
    switch (this) {
      case JobStatus.received:
        return 'Received';
      case JobStatus.inspection:
        return 'Inspection';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.waitingParts:
        return 'Waiting Parts';
      case JobStatus.readyForDelivery:
        return 'Ready';
      case JobStatus.delivered:
        return 'Delivered';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class JobCard {
  /// Default vehicle inspection checklist applied to new job cards. Single
  /// source used both as the constructor default and by the create form.
  static const Map<String, bool> defaultChecklist = {
    'Engine Oil Level': true,
    'Brake System': true,
    'Coolant & Fluids': true,
    'Battery & Terminals': true,
    'Tyres & Pressure': true,
    'AC & Heating': true,
    'Lights & Horn': true,
    'Body Scratches Checked': true,
  };

  final String id;
  final String jobCardNumber; // e.g. JC-1001
  final String customerId;
  final String vehicleId;
  final List<String> customerComplaints;
  final Map<String, bool> inspectionChecklist;
  final String fuelLevel; // 'Empty', '1/4', '1/2', '3/4', 'Full'
  final int kmReading;
  final String? assignedStaffId;
  final JobStatus status;
  final DateTime promisedDeliveryDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<MaintenanceItem> items;
  final String? estimatedCostNote;
  final String? supervisorNotes;

  JobCard({
    required this.id,
    required this.jobCardNumber,
    required this.customerId,
    required this.vehicleId,
    required this.customerComplaints,
    Map<String, bool>? inspectionChecklist,
    this.fuelLevel = '1/2',
    required this.kmReading,
    this.assignedStaffId,
    this.status = JobStatus.received,
    required this.promisedDeliveryDate,
    DateTime? createdAt,
    this.completedAt,
    List<MaintenanceItem>? items,
    this.estimatedCostNote,
    this.supervisorNotes,
  })  : inspectionChecklist = inspectionChecklist == null
            ? Map<String, bool>.of(defaultChecklist)
            : Map<String, bool>.of(inspectionChecklist),
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? [];

  double get partsTotal => items
      .where((item) => !item.isLabour)
      .fold(0.0, (sum, item) => sum + item.totalAmount);

  double get labourTotal => items
      .where((item) => item.isLabour)
      .fold(0.0, (sum, item) => sum + item.totalAmount);

  double get grandTotal => items.fold(0.0, (sum, item) => sum + item.totalAmount);

  JobCard copyWith({
    String? id,
    String? jobCardNumber,
    String? customerId,
    String? vehicleId,
    List<String>? customerComplaints,
    Map<String, bool>? inspectionChecklist,
    String? fuelLevel,
    int? kmReading,
    String? assignedStaffId,
    bool clearAssignedStaffId = false,
    JobStatus? status,
    DateTime? promisedDeliveryDate,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    List<MaintenanceItem>? items,
    String? estimatedCostNote,
    bool clearEstimatedCostNote = false,
    String? supervisorNotes,
    bool clearSupervisorNotes = false,
  }) {
    return JobCard(
      id: id ?? this.id,
      jobCardNumber: jobCardNumber ?? this.jobCardNumber,
      customerId: customerId ?? this.customerId,
      vehicleId: vehicleId ?? this.vehicleId,
      customerComplaints: customerComplaints ?? this.customerComplaints,
      inspectionChecklist: inspectionChecklist ?? this.inspectionChecklist,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      kmReading: kmReading ?? this.kmReading,
      assignedStaffId:
          clearAssignedStaffId ? null : (assignedStaffId ?? this.assignedStaffId),
      status: status ?? this.status,
      promisedDeliveryDate: promisedDeliveryDate ?? this.promisedDeliveryDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      items: items ?? this.items,
      estimatedCostNote: clearEstimatedCostNote
          ? null
          : (estimatedCostNote ?? this.estimatedCostNote),
      supervisorNotes: clearSupervisorNotes
          ? null
          : (supervisorNotes ?? this.supervisorNotes),
    );
  }
}
