package auth

import "errors"

// AllPermissions is the fixed permission matrix (11 keys, spec §6).
var AllPermissions = []string{
	"customers.manage", "vehicles.manage", "jobcards.manage", "quotations.manage",
	"invoices.manage", "payments.record", "expenses.manage", "staff.manage",
	"attendance.manage", "advances.manage", "settings.manage",
}

// DefaultStaffPermissions is granted when POST members omits `permissions`:
// everything EXCEPT expenses, staff, advances and settings management.
var DefaultStaffPermissions = []string{
	"customers.manage", "vehicles.manage", "jobcards.manage", "quotations.manage",
	"invoices.manage", "payments.record", "attendance.manage",
}

func ValidatePermissions(perms []string) error {
	valid := make(map[string]bool, len(AllPermissions))
	for _, p := range AllPermissions {
		valid[p] = true
	}
	for _, p := range perms {
		if !valid[p] {
			return errors.New("unknown permission: " + p)
		}
	}
	return nil
}
