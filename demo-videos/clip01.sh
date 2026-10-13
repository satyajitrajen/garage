#!/usr/bin/env bash
# 01 A car comes in: plate lookup -> job card -> items -> status.
# DRY=1 stops before creating and discards.
set -e
. "$(dirname "$0")/drive.sh"
add() { # add catalog item by name on the Add items screen (scrolls if needed)
  local c i
  for i in 1 2 3; do
    c=$(dump | grep -F -A1 "$1" | grep 'content-desc="Add"' | grep -oE 'bounds="[^"]+"' | grep -oE '[0-9]+' | tr '\n' ' ')
    [ -n "$c" ] && break
    swipe 540 1900 540 1300 500
  done
  set -- $c; $ADB shell input tap $(( ($1+$3)/2 )) $(( ($2+$4)/2 )); sleep 1.2
}

sleep 2                                   # dashboard with today's workshop
t "New job card" 1 2
fld 1 "MH12AB"; sleep 1.5                 # returning car found
t "MH12AB1234" 1 2.5                      # job card prefilled
t "Assign Mechanic" 1 1.2
t "Suresh Jadhav" 1 1.5
fld 2 "Brake noise while stopping"; key 66; sleep 0.8
fld 2 "Periodic service due"; key 66; sleep 0.8
hidekb
t "Check all" 1 1.5
up
t "Add Items" 1 2
add "Front brake pads"
add "Engine Oil (3.5 L)"
add "Oil filter"
add "General Service"
sleep 1.5
t "Done (" 1 2
up; sleep 1
if [ -n "$DRY" ]; then key 4; sleep 1; t "Discard" 2 2; exit 0; fi
t "Create &amp; Issue Job Card" 1 3.5      # job card detail
t "Mark ready" 1 3
