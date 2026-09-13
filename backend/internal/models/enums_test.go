package models

import "testing"

// Pins every enum set against the Dart enums (count and endpoints) so a
// rename on either side fails this test instead of silently corrupting
// stored rows.
func TestEnumSetsMatchDart(t *testing.T) {
	cases := []struct {
		name  string
		got   []string
		count int
		first string
		last  string
	}{
		{"FuelTypes", FuelTypes, 5, "petrol", "hybrid"},
		{"StaffRoles", StaffRoles, 7, "headMechanic", "manager"},
		{"AttendanceStatuses", AttendanceStatuses, 4, "present", "leave"},
		{"JobStatuses", JobStatuses, 7, "received", "cancelled"},
		{"QuotationStatuses", QuotationStatuses, 5, "draft", "rejected"},
		{"PaymentModes", PaymentModes, 6, "cash", "other"},
		{"ExpenseCategories", ExpenseCategories, 9, "rent", "miscellaneous"},
		{"ItemCategories", ItemCategories, 6, "sparePart", "custom"},
	}
	for _, tc := range cases {
		if len(tc.got) != tc.count {
			t.Errorf("%s: got %d values, want %d (%v)", tc.name, len(tc.got), tc.count, tc.got)
		}
		if tc.got[0] != tc.first || tc.got[len(tc.got)-1] != tc.last {
			t.Errorf("%s: order drifted: first=%q last=%q", tc.name, tc.got[0], tc.got[len(tc.got)-1])
		}
		for _, v := range tc.got {
			if !ValidValue(v, tc.got...) {
				t.Errorf("%s: %q not accepted by ValidValue", tc.name, v)
			}
		}
	}
	if ValidValue("nope", JobStatuses...) {
		t.Error("ValidValue accepted unknown value")
	}
}
