#!/usr/bin/env bash
# 02 Billing: bill from the job card -> GST lines -> payment -> PDF / WhatsApp.
# Starts on the job card detail of JC-1004 (end of clip 01).
set -e
. "$(dirname "$0")/drive.sh"

sleep 2
t "Create Bill" 1 3.5                     # bill preview
swipe 540 1700 540 1000 900; sleep 1.5    # items
swipe 540 1700 540 900 900; sleep 2.5     # GST lines + total + UPI QR
t "Record Payment" 1 2.5
t "UPI" 1 1.5
up; sleep 1
t "Confirm &amp; Record Payment" 1 3.5    # payment received
t "Done" 1 2.5                            # back on the bill, paid
down; down; sleep 1
t "Share bill" 1 2
t "Send PDF bill" 1 5                     # share sheet with the PDF
t "Print" 1 6                             # print preview of the PDF
sleep 2
key 4; sleep 2
t "Share bill" 1 2
sleep 2.5                                 # show the WhatsApp option
key 4; sleep 1.5
