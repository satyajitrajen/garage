import '../models/customer.dart';
import '../models/vehicle.dart';
import '../models/maintenance_item.dart';
import '../models/job_card.dart';
import '../models/quotation.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../models/staff.dart';
import '../data/garage_profile.dart';
import '../data/app_config.dart';

class MockDataService {
  // Standard Inventory / Common Parts Catalogue for quick selection
  static List<MaintenanceItem> getCatalogItems() {
    return [
      // Oils & Fluids
      MaintenanceItem(
        id: 'cat_1',
        name: 'Synthetic Engine Oil (5W-30 / 5W-40)',
        category: ItemCategory.fluids,
        unitPrice: 2850.0,
        unit: 'Can (3.5L)',
        taxPercent: 18.0,
        partNumber: 'OIL-SYN-5W30',
      ),
      MaintenanceItem(
        id: 'cat_2',
        name: 'Mineral Engine Oil (15W-40 / 20W-50)',
        category: ItemCategory.fluids,
        unitPrice: 1450.0,
        unit: 'Can (3.5L)',
        taxPercent: 18.0,
        partNumber: 'OIL-MIN-15W40',
      ),
      MaintenanceItem(
        id: 'cat_3',
        name: 'Radiator Coolant (Premixed Concentrate)',
        category: ItemCategory.fluids,
        unitPrice: 380.0,
        unit: 'Ltr',
        taxPercent: 18.0,
        partNumber: 'CLNT-PRE-1L',
      ),
      MaintenanceItem(
        id: 'cat_4',
        name: 'Brake Fluid DOT 4',
        category: ItemCategory.fluids,
        unitPrice: 280.0,
        unit: 'Bottle (500ml)',
        taxPercent: 18.0,
        partNumber: 'BRK-DOT4-500',
      ),
      MaintenanceItem(
        id: 'cat_5',
        name: 'Gear Oil / Transmission Fluid 80W-90',
        category: ItemCategory.fluids,
        unitPrice: 750.0,
        unit: 'Ltr',
        taxPercent: 18.0,
        partNumber: 'GEAR-80W90-1L',
      ),

      // Spare Parts
      MaintenanceItem(
        id: 'cat_6',
        name: 'Engine Oil Filter (OEM)',
        category: ItemCategory.sparePart,
        unitPrice: 320.0,
        unit: 'Pcs',
        taxPercent: 18.0,
        partNumber: 'FLTR-OIL-OEM',
      ),
      MaintenanceItem(
        id: 'cat_7',
        name: 'Engine Air Filter Element',
        category: ItemCategory.sparePart,
        unitPrice: 480.0,
        unit: 'Pcs',
        taxPercent: 18.0,
        partNumber: 'FLTR-AIR-STD',
      ),
      MaintenanceItem(
        id: 'cat_8',
        name: 'Cabin AC Filter (Carbon Treated)',
        category: ItemCategory.sparePart,
        unitPrice: 550.0,
        unit: 'Pcs',
        taxPercent: 18.0,
        partNumber: 'FLTR-AC-CARB',
      ),
      MaintenanceItem(
        id: 'cat_9',
        name: 'Front Disc Brake Pads (Set of 4)',
        category: ItemCategory.sparePart,
        unitPrice: 1850.0,
        unit: 'Set',
        taxPercent: 18.0,
        partNumber: 'BRK-PAD-FRT',
      ),
      MaintenanceItem(
        id: 'cat_10',
        name: 'Rear Brake Shoe Set',
        category: ItemCategory.sparePart,
        unitPrice: 1200.0,
        unit: 'Set',
        taxPercent: 18.0,
        partNumber: 'BRK-SHOE-RR',
      ),
      MaintenanceItem(
        id: 'cat_11',
        name: 'Spark Plugs (Iridium Set of 4)',
        category: ItemCategory.sparePart,
        unitPrice: 1400.0,
        unit: 'Set',
        taxPercent: 18.0,
        partNumber: 'SPK-PLUG-IRID',
      ),
      MaintenanceItem(
        id: 'cat_12',
        name: 'Silicone Wiper Blade Pair (Frameless)',
        category: ItemCategory.sparePart,
        unitPrice: 650.0,
        unit: 'Pair',
        taxPercent: 18.0,
        partNumber: 'WIP-BLD-PR',
      ),
      MaintenanceItem(
        id: 'cat_13',
        name: 'Car Battery 12V 45Ah (With Old Battery Buyback)',
        category: ItemCategory.tyresBattery,
        unitPrice: 4200.0,
        unit: 'Pcs',
        taxPercent: 18.0,
        partNumber: 'BAT-12V45AH',
      ),

      // Labour & Services
      MaintenanceItem(
        id: 'cat_14',
        name: 'Periodic Comprehensive Service Labour',
        category: ItemCategory.labour,
        unitPrice: 1200.0,
        unit: 'Job',
        taxPercent: 18.0,
        isLabour: true,
      ),
      MaintenanceItem(
        id: 'cat_15',
        name: 'Brake Overhaul & Caliper Pin Greasing',
        category: ItemCategory.labour,
        unitPrice: 650.0,
        unit: 'Job',
        taxPercent: 18.0,
        isLabour: true,
      ),
      MaintenanceItem(
        id: 'cat_16',
        name: '3D Computerized Wheel Alignment & Balancing',
        category: ItemCategory.labour,
        unitPrice: 850.0,
        unit: 'Job',
        taxPercent: 18.0,
        isLabour: true,
      ),
      MaintenanceItem(
        id: 'cat_17',
        name: 'Air Conditioning Gas Recharge & Leak Test',
        category: ItemCategory.labour,
        unitPrice: 1600.0,
        unit: 'Job',
        taxPercent: 18.0,
        isLabour: true,
      ),
      MaintenanceItem(
        id: 'cat_18',
        name: 'Single Panel Denting & Spray Painting',
        category: ItemCategory.labour,
        unitPrice: 2400.0,
        unit: 'Panel',
        taxPercent: 18.0,
        isLabour: true,
      ),
      MaintenanceItem(
        id: 'cat_19',
        name: 'Deep Interior Foam Cleaning & Underbody Foam Wash',
        category: ItemCategory.labour,
        unitPrice: 950.0,
        unit: 'Job',
        taxPercent: 18.0,
        isLabour: true,
      ),
      MaintenanceItem(
        id: 'cat_20',
        name: 'Towing & Recovery Transport Charges',
        category: ItemCategory.transportMisc,
        unitPrice: 1500.0,
        unit: 'Trip',
        taxPercent: 18.0,
        isLabour: false,
      ),
    ];
  }

  // Initial Seed Staff
  static List<Staff> getInitialStaff() {
    return [
      Staff(
        id: 'st_1',
        name: 'Ramesh Sharma',
        role: StaffRole.headMechanic,
        phone: '+91 98765 43210',
        monthlySalary: 28000,
        joiningDate: DateTime(2023, 3, 15),
      ),
      Staff(
        id: 'st_2',
        name: 'Imran Khan',
        role: StaffRole.seniorTechnician,
        phone: '+91 98111 22334',
        monthlySalary: 22000,
        joiningDate: DateTime(2023, 8, 1),
      ),
      Staff(
        id: 'st_3',
        name: 'Suresh Patel',
        role: StaffRole.autoElectrician,
        phone: '+91 97234 56789',
        monthlySalary: 20000,
        joiningDate: DateTime(2024, 1, 10),
      ),
      Staff(
        id: 'st_4',
        name: 'Vikram Singh',
        role: StaffRole.denterPainter,
        phone: '+91 99887 76655',
        monthlySalary: 24000,
        joiningDate: DateTime(2023, 6, 20),
      ),
      Staff(
        id: 'st_5',
        name: 'Amit Kumar',
        role: StaffRole.helperTrainee,
        phone: '+91 91234 56780',
        monthlySalary: 12000,
        joiningDate: DateTime(2024, 5, 5),
      ),
    ];
  }

  // Seed Customers
  static List<Customer> getInitialCustomers() {
    return [
      Customer(
        id: 'c_1',
        name: 'Rajesh Malhotra',
        phone: '+91 98200 12345',
        whatsappNumber: '+91 98200 12345',
        email: 'rajesh.malhotra@gmail.com',
        address: 'B-402, Sunshine Heights, Andheri West, Mumbai',
        notes: 'VIP customer, prefers Motul synthetic oil.',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
      Customer(
        id: 'c_2',
        name: 'Pooja Deshmukh',
        phone: '+91 99300 67890',
        whatsappNumber: '+91 99300 67890',
        email: 'pooja.deshmukh@yahoo.com',
        address: '12, Green Glen Layout, Bellandur, Bengaluru',
        notes: 'Always requests evening delivery after 6 PM.',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Customer(
        id: 'c_3',
        name: 'Vikramaditya Transport',
        phone: '+91 94440 98765',
        whatsappNumber: '+91 94440 98765',
        gstin: '27AABCV1234F1Z5',
        address: 'Plot 44, MIDC Industrial Area, Pune',
        notes: 'Commercial Fleet Account. Monthly consolidated billing.',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      Customer(
        id: 'c_4',
        name: 'Ananya Sharma',
        phone: '+91 97110 55443',
        whatsappNumber: '+91 97110 55443',
        email: 'ananya.s@outlook.com',
        address: 'Flat 301, Palm Meadows, Gurgaon Sector 56',
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      Customer(
        id: 'c_5',
        name: 'Harpreet Singh Sandhu',
        phone: '+91 98720 33221',
        whatsappNumber: '+91 98720 33221',
        address: 'Model Town, Phase 2, Ludhiana',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  // Seed Vehicles
  static List<Vehicle> getInitialVehicles() {
    return [
      Vehicle(
        id: 'v_1',
        customerId: 'c_1',
        registrationNumber: 'MH 02 CZ 4421',
        make: 'Hyundai',
        model: 'Creta',
        variant: 'SX (O) 1.5 Turbo',
        year: 2022,
        fuelType: FuelType.petrol,
        currentKm: 34500,
        color: 'Phantom Black',
        lastServiceDate: DateTime.now().subtract(const Duration(days: 90)),
      ),
      Vehicle(
        id: 'v_2',
        customerId: 'c_1',
        registrationNumber: 'MH 02 EB 8899',
        make: 'Maruti Suzuki',
        model: 'Swift Dzire',
        variant: 'ZXI+',
        year: 2020,
        fuelType: FuelType.cng,
        currentKm: 68200,
        color: 'Magma Grey',
        lastServiceDate: DateTime.now().subtract(const Duration(days: 150)),
      ),
      Vehicle(
        id: 'v_3',
        customerId: 'c_2',
        registrationNumber: 'KA 03 MX 7712',
        make: 'Honda',
        model: 'City',
        variant: 'ZX CVT',
        year: 2021,
        fuelType: FuelType.petrol,
        currentKm: 28900,
        color: 'Platinum White Pearl',
        lastServiceDate: DateTime.now().subtract(const Duration(days: 60)),
      ),
      Vehicle(
        id: 'v_4',
        customerId: 'c_3',
        registrationNumber: 'MH 14 TC 9001',
        make: 'Mahindra',
        model: 'Bolero Camper',
        variant: 'Power Plus 2.5D',
        year: 2019,
        fuelType: FuelType.diesel,
        currentKm: 145000,
        color: 'Diamond White',
        lastServiceDate: DateTime.now().subtract(const Duration(days: 35)),
      ),
      Vehicle(
        id: 'v_5',
        customerId: 'c_3',
        registrationNumber: 'MH 14 TC 9002',
        make: 'Mahindra',
        model: 'Scorpio Classic',
        variant: 'S11',
        year: 2021,
        fuelType: FuelType.diesel,
        currentKm: 89400,
        color: 'Galaxy Grey',
      ),
      Vehicle(
        id: 'v_6',
        customerId: 'c_4',
        registrationNumber: 'HR 26 DQ 5520',
        make: 'Tata',
        model: 'Nexon EV',
        variant: 'Empowered+ LR',
        year: 2023,
        fuelType: FuelType.electric,
        currentKm: 19800,
        color: 'Flame Red',
        lastServiceDate: DateTime.now().subtract(const Duration(days: 110)),
      ),
      Vehicle(
        id: 'v_7',
        customerId: 'c_5',
        registrationNumber: 'PB 10 CG 0007',
        make: 'Mahindra',
        model: 'Thar 4x4',
        variant: 'LX Hard Top Diesel AT',
        year: 2022,
        fuelType: FuelType.diesel,
        currentKm: 42000,
        color: 'Rocky Beige',
      ),
    ];
  }

  // Seed Job Cards
  static List<JobCard> getInitialJobCards() {
    final now = DateTime.now();
    return [
      JobCard(
        id: 'jc_1',
        jobCardNumber: 'JC-1001',
        customerId: 'c_1',
        vehicleId: 'v_1',
        customerComplaints: [
          'Periodic 35,000 KM general service due',
          'Brake pedal feeling spongy / mild squeal sound',
          'AC cooling slow on hot afternoons',
        ],
        fuelLevel: '3/4',
        kmReading: 34500,
        assignedStaffId: 'st_1', // Ramesh Sharma
        status: JobStatus.inProgress,
        promisedDeliveryDate: now.add(const Duration(hours: 4)),
        createdAt: now.subtract(const Duration(hours: 3)),
        items: [
          MaintenanceItem(
            id: 'jci_1',
            name: 'Synthetic Engine Oil (5W-30)',
            category: ItemCategory.fluids,
            unitPrice: 2850.0,
            quantity: 1.0,
            taxPercent: 18.0,
            partNumber: 'OIL-SYN-5W30',
          ),
          MaintenanceItem(
            id: 'jci_2',
            name: 'Engine Oil Filter (OEM)',
            category: ItemCategory.sparePart,
            unitPrice: 320.0,
            quantity: 1.0,
            taxPercent: 18.0,
            partNumber: 'FLTR-OIL-OEM',
          ),
          MaintenanceItem(
            id: 'jci_3',
            name: 'Front Disc Brake Pads (Set of 4)',
            category: ItemCategory.sparePart,
            unitPrice: 1850.0,
            quantity: 1.0,
            taxPercent: 18.0,
            partNumber: 'BRK-PAD-FRT',
          ),
          MaintenanceItem(
            id: 'jci_4',
            name: 'Periodic Comprehensive Service Labour',
            category: ItemCategory.labour,
            unitPrice: 1200.0,
            quantity: 1.0,
            taxPercent: 18.0,
            isLabour: true,
          ),
        ],
        supervisorNotes:
            'Front brake pads worn out down to 2mm. Replacement approved by customer.',
      ),
      JobCard(
        id: 'jc_2',
        jobCardNumber: 'JC-1002',
        customerId: 'c_2',
        vehicleId: 'v_3',
        customerComplaints: [
          'Steering vibrates at 80+ km/h on highway',
          'Windshield wiper streaking water',
          'Interior sanitization & wash required',
        ],
        fuelLevel: '1/2',
        kmReading: 28900,
        assignedStaffId: 'st_2', // Imran Khan
        status: JobStatus.readyForDelivery,
        promisedDeliveryDate: now.add(const Duration(hours: 1)),
        createdAt: now.subtract(const Duration(hours: 6)),
        items: [
          MaintenanceItem(
            id: 'jci_5',
            name: '3D Wheel Alignment & Wheel Balancing',
            category: ItemCategory.labour,
            unitPrice: 850.0,
            quantity: 1.0,
            taxPercent: 18.0,
            isLabour: true,
          ),
          MaintenanceItem(
            id: 'jci_6',
            name: 'Silicone Wiper Blade Pair (Frameless)',
            category: ItemCategory.sparePart,
            unitPrice: 650.0,
            quantity: 1.0,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'jci_7',
            name: 'Deep Interior Foam Cleaning & Underbody Foam Wash',
            category: ItemCategory.labour,
            unitPrice: 950.0,
            quantity: 1.0,
            taxPercent: 18.0,
            isLabour: true,
          ),
        ],
      ),
      JobCard(
        id: 'jc_3',
        jobCardNumber: 'JC-1003',
        customerId: 'c_5',
        vehicleId: 'v_7',
        customerComplaints: [
          'Left side front fender dented and scratched',
          'Left headlight assembly bracket broken',
        ],
        fuelLevel: 'Full',
        kmReading: 42000,
        assignedStaffId: 'st_4', // Vikram Singh
        status: JobStatus.waitingParts,
        promisedDeliveryDate: now.add(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(hours: 8)),
        items: [
          MaintenanceItem(
            id: 'jci_8',
            name: 'Left Fender Denting & Spray Painting',
            category: ItemCategory.labour,
            unitPrice: 2800.0,
            quantity: 1.0,
            taxPercent: 18.0,
            isLabour: true,
          ),
          MaintenanceItem(
            id: 'jci_9',
            name: 'Headlight Assembly OEM Thar (Ordered from M&M Stockist)',
            category: ItemCategory.sparePart,
            unitPrice: 4600.0,
            quantity: 1.0,
            taxPercent: 18.0,
          ),
        ],
        supervisorNotes:
            'Waiting for OEM headlight delivery from regional distributor.',
      ),
      JobCard(
        id: 'jc_4',
        jobCardNumber: 'JC-1004',
        customerId: 'c_4',
        vehicleId: 'v_6',
        customerComplaints: [
          'High voltage charging port flap loose',
          'AC Cabin odour / filter cleaning',
          'Wheel rotation',
        ],
        fuelLevel: '3/4',
        kmReading: 19800,
        assignedStaffId: 'st_3', // Suresh Patel
        status: JobStatus.received,
        promisedDeliveryDate: now.add(const Duration(hours: 5)),
        createdAt: now.subtract(const Duration(minutes: 40)),
        items: [],
      ),
    ];
  }

  // Seed Quotations
  static List<Quotation> getInitialQuotations() {
    final now = DateTime.now();
    return [
      Quotation(
        id: 'q_1',
        quotationNumber: 'EST-1001',
        customerId: 'c_1',
        vehicleId: 'v_2',
        kmReading: 68200,
        validityDays: 15,
        status: QuotationStatus.approved,
        notes: 'Clutch overhaul and flywheel facing estimate.',
        createdAt: now.subtract(const Duration(days: 2)),
        items: [
          MaintenanceItem(
            id: 'qi_1',
            name: 'Clutch Disc & Pressure Plate Set (Valeo)',
            category: ItemCategory.sparePart,
            unitPrice: 3800.0,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'qi_2',
            name: 'Clutch Release Bearing',
            category: ItemCategory.sparePart,
            unitPrice: 850.0,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'qi_3',
            name: 'Clutch Replacement & Gearbox Dismantling Labour',
            category: ItemCategory.labour,
            unitPrice: 1800.0,
            taxPercent: 18.0,
            isLabour: true,
          ),
          MaintenanceItem(
            id: 'qi_4',
            name: 'Gear Oil 80W90 (2.5L)',
            category: ItemCategory.fluids,
            unitPrice: 1200.0,
            taxPercent: 18.0,
          ),
        ],
      ),
      Quotation(
        id: 'q_2',
        quotationNumber: 'EST-1002',
        customerId: 'c_3',
        vehicleId: 'v_5',
        kmReading: 89400,
        validityDays: 7,
        status: QuotationStatus.sent,
        notes: 'Suspension overhaul: Front strut pair & lower arms.',
        createdAt: now.subtract(const Duration(days: 1)),
        items: [
          MaintenanceItem(
            id: 'qi_5',
            name: 'Front Shock Absorber Strut Pair (Monroe OEM)',
            category: ItemCategory.sparePart,
            unitPrice: 5400.0,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'qi_6',
            name: 'Lower Control Arm Bushing Kit',
            category: ItemCategory.sparePart,
            unitPrice: 1600.0,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'qi_7',
            name: 'Suspension Overhaul Labour',
            category: ItemCategory.labour,
            unitPrice: 1500.0,
            taxPercent: 18.0,
            isLabour: true,
          ),
        ],
      ),
    ];
  }

  // Seed Invoices
  static List<Invoice> getInitialInvoices() {
    final now = DateTime.now();
    return [
      Invoice(
        id: 'inv_1',
        invoiceNumber: 'INV-2026-0038',
        customerId: 'c_3',
        vehicleId: 'v_4',
        kmReading: 145000,
        invoiceDate: now.subtract(const Duration(days: 1)),
        taxPercent: 18.0,
        items: [
          MaintenanceItem(
            id: 'invi_1',
            name: 'Diesel Engine Oil 15W40 (6.5L)',
            category: ItemCategory.fluids,
            unitPrice: 2600.0,
            quantity: 1,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'invi_2',
            name: 'Diesel Fuel Filter OEM Kit',
            category: ItemCategory.sparePart,
            unitPrice: 950.0,
            quantity: 1,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'invi_3',
            name: 'Major Diesel Service Labour',
            category: ItemCategory.labour,
            unitPrice: 1500.0,
            quantity: 1,
            taxPercent: 18.0,
            isLabour: true,
          ),
        ],
        payments: [
          Payment(
            id: 'pay_1',
            invoiceId: 'inv_1',
            customerId: 'c_3',
            amount: 5000.0,
            mode: PaymentMode.bankTransfer,
            transactionRef: 'NEFT-HDFC-9920114',
            paymentDate: now.subtract(const Duration(days: 1)),
            receivedBy: 'Ramesh Sharma',
          ),
        ],
        notes: 'Partial payment received. Balance due within 15 days.',
      ),
      Invoice(
        id: 'inv_2',
        invoiceNumber: 'INV-2026-0039',
        customerId: 'c_4',
        vehicleId: 'v_6',
        kmReading: 19500,
        invoiceDate: now.subtract(const Duration(days: 3)),
        taxPercent: 18.0,
        items: [
          MaintenanceItem(
            id: 'invi_4',
            name: 'Cabin AC Filter Carbon Treated',
            category: ItemCategory.sparePart,
            unitPrice: 550.0,
            quantity: 1,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'invi_5',
            name: 'Complete EV Diagnostic Health Scan & Wash',
            category: ItemCategory.labour,
            unitPrice: 1100.0,
            quantity: 1,
            taxPercent: 18.0,
            isLabour: true,
          ),
        ],
        payments: [
          Payment(
            id: 'pay_2',
            invoiceId: 'inv_2',
            customerId: 'c_4',
            amount: 1947.0, // Full amount including 18% GST (1650 + 297 = 1947)
            mode: PaymentMode.upi,
            transactionRef: 'UPI-GPAY-409112998',
            paymentDate: now.subtract(const Duration(days: 3)),
            receivedBy: 'Cashier',
          ),
        ],
      ),
      Invoice(
        id: 'inv_3',
        invoiceNumber: 'INV-2026-0040',
        customerId: 'c_1',
        vehicleId: 'v_1',
        kmReading: 32000,
        invoiceDate: now.subtract(const Duration(days: 6)),
        taxPercent: 18.0,
        items: [
          MaintenanceItem(
            id: 'invi_6',
            name: 'Car Battery 12V 45Ah Exide Mileage',
            category: ItemCategory.tyresBattery,
            unitPrice: 4200.0,
            quantity: 1,
            taxPercent: 18.0,
          ),
          MaintenanceItem(
            id: 'invi_7',
            name: 'Battery Installation & Terminal Coating',
            category: ItemCategory.labour,
            unitPrice: 200.0,
            quantity: 1,
            taxPercent: 18.0,
            isLabour: true,
          ),
        ],
        payments: [
          Payment(
            id: 'pay_3',
            invoiceId: 'inv_3',
            customerId: 'c_1',
            amount: 5192.0, // (4400 + 792 GST)
            mode: PaymentMode.card,
            transactionRef: 'POS-HDFC-9932',
            paymentDate: now.subtract(const Duration(days: 6)),
            receivedBy: 'Imran Khan',
          ),
        ],
      ),
      Invoice(
        id: 'inv_4',
        invoiceNumber: 'INV-2026-0041',
        customerId: 'c_5',
        vehicleId: 'v_7',
        kmReading: 41200,
        invoiceDate: now,
        taxPercent: 18.0,
        items: [
          MaintenanceItem(
            id: 'invi_8',
            name: 'Air Conditioning Gas Refill & Leak Test',
            category: ItemCategory.labour,
            unitPrice: 1600.0,
            quantity: 1,
            taxPercent: 18.0,
            isLabour: true,
          ),
          MaintenanceItem(
            id: 'invi_9',
            name: 'Cabin Microfilter',
            category: ItemCategory.sparePart,
            unitPrice: 600.0,
            quantity: 1,
            taxPercent: 18.0,
          ),
        ],
        payments: [], // Unpaid / Pending
        notes: 'Customer will collect car tomorrow morning and pay cash.',
      ),
    ];
  }

  // Seed Expenses
  static List<GarageExpense> getInitialExpenses() {
    final now = DateTime.now();
    return [
      GarageExpense(
        id: 'exp_1',
        title: 'Monthly Workshop Premises Rent',
        category: ExpenseCategory.rent,
        amount: 35000.0,
        expenseDate: DateTime(now.year, now.month, 1),
        paymentMode: PaymentMode.bankTransfer,
        vendorName: 'Shri Ram Commercial Properties',
        notes: 'September Rent paid via NEFT',
      ),
      GarageExpense(
        id: 'exp_2',
        title: 'Commercial 3-Phase Electricity Bill',
        category: ExpenseCategory.electricityUtilities,
        amount: 6850.0,
        expenseDate: DateTime(now.year, now.month, 3),
        paymentMode: PaymentMode.upi,
        vendorName: 'State Electricity Board',
      ),
      GarageExpense(
        id: 'exp_3',
        title: 'Castrol Engine Oil Barrel (50L)',
        category: ExpenseCategory.partsStock,
        amount: 18500.0,
        expenseDate: now.subtract(const Duration(days: 2)),
        paymentMode: PaymentMode.bankTransfer,
        vendorName: 'National Auto Distributors',
        notes: 'Batch 5W30 full synthetic barrel',
      ),
      GarageExpense(
        id: 'exp_4',
        title: 'Brake Cleaner Sprays & WD-40 Cans (Pack of 10)',
        category: ExpenseCategory.consumables,
        amount: 2400.0,
        expenseDate: now.subtract(const Duration(days: 1)),
        paymentMode: PaymentMode.cash,
        vendorName: 'Modern Spares Shop',
      ),
      GarageExpense(
        id: 'exp_5',
        title: 'Staff Afternoon Tea, Samosas & Water',
        category: ExpenseCategory.staffFood,
        amount: 320.0,
        expenseDate: now,
        paymentMode: PaymentMode.upi,
        vendorName: 'Chai Point Corner',
      ),
      GarageExpense(
        id: 'exp_6',
        title: 'Hydraulic Ramp Service & Seal Kit',
        category: ExpenseCategory.toolsEquipment,
        amount: 3500.0,
        expenseDate: now.subtract(const Duration(days: 4)),
        paymentMode: PaymentMode.cash,
        vendorName: 'Apex Garage Equipment',
      ),
    ];
  }

  // Seed Attendance & Advances
  static List<AttendanceRecord> getInitialAttendance(List<Staff> staff) {
    final List<AttendanceRecord> records = [];
    final now = DateTime.now();

    // Generate past 15 days attendance for each staff
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(now.year, now.month, day);
      // Skip Sundays
      if (date.weekday == DateTime.sunday) continue;

      for (var s in staff) {
        AttendanceStatus status = AttendanceStatus.present;
        if (s.id == 'st_5' && day == 4) {
          status = AttendanceStatus.halfDay;
        } else if (s.id == 'st_3' && day == 7) {
          status = AttendanceStatus.leave;
        } else if (s.id == 'st_2' && day == 2) {
          status = AttendanceStatus.absent;
        }

        records.add(
          AttendanceRecord(
            id: 'att_${s.id}_$day',
            staffId: s.id,
            date: date,
            status: status,
          ),
        );
      }
    }
    return records;
  }

  static List<SalaryAdvance> getInitialSalaryAdvances() {
    final now = DateTime.now();
    return [
      SalaryAdvance(
        id: 'adv_1',
        staffId: 'st_1', // Ramesh
        amount: 5000.0,
        date: DateTime(now.year, now.month, 5),
        reason: 'Home renovation emergency',
      ),
      SalaryAdvance(
        id: 'adv_2',
        staffId: 'st_5', // Amit
        amount: 2000.0,
        date: DateTime(now.year, now.month, 8),
        reason: 'College fees balance',
      ),
    ];
  }

  static GarageProfile getGarageProfile() => const GarageProfile(
    name: 'Nexory Garage & Body Shop',
    tagline: 'Multi-Brand Auto Care',
    addressLine: 'Shop 14, Andheri Industrial Estate',
    city: 'Mumbai, MH',
    phone: '+91 98200 12345',
    email: 'service@nexorygarage.in',
    gstin: '27AAAAA0000A1Z5',
    upiId: 'nexorygarage@upi',
  );

  static AppConfig getAppConfig() => const AppConfig();
}
