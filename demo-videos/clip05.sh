#!/usr/bin/env bash
# 05 Expenses, subscription, team and Marathi. Starts on the dashboard.
set -e
. "$(dirname "$0")/drive.sh"
sleep 2
t "More" 1 1.5
t "Expenses" 1 2.5
t "Add Expense" 1 2
t "Tools &amp; Equipment" 1 1
fld 1 "Air impact wrench"
fld 2 "6800"
hidekb
up; sleep 1
t "Save Expense" 1 3                      # list with this month's total
key 4; sleep 1.5
t "Subscription" 1 3
key 4; sleep 1.5
t "Team logins" 1 3
key 4; sleep 1.5
t "Language / " 1 1.5
t "मराठी" 1 4                            # whole app switches
t "होम" 1 3                               # dashboard in Marathi
t "कामे" 1 3
t "बिले" 1 3
