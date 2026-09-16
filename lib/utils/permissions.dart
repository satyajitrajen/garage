/// Backend permission keys (mirrors `backend/internal/auth/permissions.go`).
abstract final class Permissions {
  static const customersManage = 'customers.manage';
  static const vehiclesManage = 'vehicles.manage';
  static const jobcardsManage = 'jobcards.manage';
  static const quotationsManage = 'quotations.manage';
  static const invoicesManage = 'invoices.manage';
  static const paymentsRecord = 'payments.record';
  static const expensesManage = 'expenses.manage';
  static const staffManage = 'staff.manage';
  static const attendanceManage = 'attendance.manage';
  static const advancesManage = 'advances.manage';
  static const settingsManage = 'settings.manage';

  static const all = <String>[
    customersManage,
    vehiclesManage,
    jobcardsManage,
    quotationsManage,
    invoicesManage,
    paymentsRecord,
    expensesManage,
    staffManage,
    attendanceManage,
    advancesManage,
    settingsManage,
  ];
}
