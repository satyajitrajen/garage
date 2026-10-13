#!/usr/bin/env bash
# 04 Staff & payroll. Starts on the dashboard.
set -e
. "$(dirname "$0")/drive.sh"
sleep 2
t "More" 1 1.5
t "Staff &amp; payroll" 1 2.5             # staff rows with Attendance / Salary
t "Mark All Present" 1 3
t "Attendance" 2 3                        # Imran's calendar (rows sorted by name)
sleep 1.5
key 4; sleep 1.5
t "Salary" 2 3                            # Imran's payslip
up; sleep 1.5
t "Disburse" 1 2                          # confirmation dialog
t "UPI / QR / GPay" 1 1.5
t "Pay salary" 1 3.5                      # salary paid
