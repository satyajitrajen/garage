#!/usr/bin/env bash
# 03 Estimates: create -> approve -> convert to job card. Starts on the Estimates list.
set -e
. "$(dirname "$0")/drive.sh"
add() {
  local c i
  for i in 1 2 3; do
    c=$(dump | grep -F -A1 "$1" | grep 'content-desc="Add"' | grep -oE 'bounds="[^"]+"' | grep -oE '[0-9]+' | tr '\n' ' ')
    [ -n "$c" ] && break
    swipe 540 1900 540 1300 500
  done
  set -- $c; $ADB shell input tap $(( ($1+$3)/2 )) $(( ($2+$4)/2 )); sleep 1.2
}
sleep 2
t "Create Estimate" 1 2
t "Vikram Singh" 1 2
t "MH14DS3030" 1 2.5
t "Add Items" 1 2
add "Tyre 185/65 R15"
add "Tyre 185/65 R15"                    # second tyre
add "Wheel alignment"
sleep 1.5
t "Done (" 1 2.5
up; sleep 1.5
t "Save Estimate" 1 3.5                   # estimate preview, Draft
up; sleep 2
t "Approve" 1 3
t "Convert to Job Card" 1 4               # new job card from the estimate
