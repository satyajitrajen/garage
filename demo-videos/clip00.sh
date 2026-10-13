#!/usr/bin/env bash
# 00 Getting started: sign up, garage details, price list.
# Usage: EMAIL=... PASS=... bash clip00.sh
set -e
. "$(dirname "$0")/drive.sh"

sleep 3                                   # login screen
t "New workshop? Create an account" 1 2
fld 1 "Nitin Thorat"
fld 2 "NT Garage & Body Shop"
fld 3 "$EMAIL"
fld 4 "$PASS"
hidekb; sleep 1
t "Create account" 1 4                    # dashboard with setup card

# Step 1: garage details
t "Add your garage details" 1 2.5
fld 2 "Multi-brand car service & body shop"
fld 3 "Shop 14, Hadapsar Industrial Estate"
fld 4 "Pune, Maharashtra"
fld 5 "9822012345"
fld 7 "27AAKFN1234M1Z5"
fld 8 "ntgarage@upi"
hidekb; sleep 1
up; up
t "Save Settings" 1 3                     # back on dashboard, 1 of 3

# Step 2: price list
t "Add your common parts and labour" 1 2.5
t "Add item" 1 1.5
fld 1 "Engine Oil (3.5 L)"
fld 2 "1650"
hidekb; sleep 0.8
t "Add to price list" 1 2
t "Add item" 1 1.5
fld 1 "General service labour"
fld 2 "900"
hidekb; sleep 0.8
t "Category" 1 1
t "Labour &amp; Service" 1 1
sleep 1
t "Add to price list" 1 2.5
key 4; sleep 2.5                          # dashboard: 2 of 3 done
