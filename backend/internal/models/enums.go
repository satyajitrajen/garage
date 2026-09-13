package models

// Enum TEXT values carry the Dart enum name exactly (lib/models/*.dart) so
// JSON maps onto Dart .name / $enumName without translation.

// ValidValue reports whether v is one of allowed.
func ValidValue(v string, allowed ...string) bool {
	for _, a := range allowed {
		if v == a {
			return true
		}
	}
	return false
}

var (
	// FuelTypes mirrors enum FuelType in lib/models/vehicle.dart.
	FuelTypes = []string{"petrol", "diesel", "cng", "electric", "hybrid"}
	// StaffRoles mirrors enum StaffRole in lib/models/staff.dart.
	StaffRoles = []string{"headMechanic", "seniorTechnician", "autoElectrician",
		"denterPainter", "helperTrainee", "serviceAdvisor", "manager"}
	// AttendanceStatuses mirrors enum AttendanceStatus in lib/models/staff.dart.
	AttendanceStatuses = []string{"present", "halfDay", "absent", "leave"}
	// JobStatuses mirrors enum JobStatus in lib/models/job_card.dart.
	JobStatuses = []string{"received", "inspection", "inProgress", "waitingParts",
		"readyForDelivery", "delivered", "cancelled"}
	// QuotationStatuses mirrors enum QuotationStatus in lib/models/quotation.dart.
	QuotationStatuses = []string{"draft", "sent", "approved", "converted", "rejected"}
	// PaymentModes mirrors enum PaymentMode in lib/models/payment.dart.
	PaymentModes = []string{"cash", "upi", "card", "bankTransfer", "cheque", "other"}
	// ExpenseCategories mirrors enum ExpenseCategory in lib/models/expense.dart.
	ExpenseCategories = []string{"rent", "electricityUtilities", "internetPhone",
		"toolsEquipment", "consumables", "partsStock", "staffFood", "fuelGenerator",
		"miscellaneous"}
	// ItemCategories mirrors enum ItemCategory in lib/models/maintenance_item.dart.
	ItemCategories = []string{"sparePart", "labour", "fluids", "tyresBattery",
		"transportMisc", "custom"}
)
