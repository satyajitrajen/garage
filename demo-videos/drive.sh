#!/usr/bin/env bash
# Demo driver helpers (sourced). Elements are found by their accessibility
# label in a fresh uiautomator dump, so taps survive layout shifts.
export MSYS_NO_PATHCONV=1
ADB="adb -s emulator-5554"

dump() { $ADB shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; $ADB exec-out cat /sdcard/ui.xml | tr '>' '\n'; }

# center LABEL [N] -> "x y" of the Nth element whose content-desc/text contains LABEL
center() {
  local n="${2:-1}"
  dump | grep -F -- "$1" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | sed -n "${n}p" |
    grep -oE '[0-9]+' | tr '\n' ' ' | awk '{ if (NF==4) printf "%d %d", ($1+$3)/2, ($2+$4)/2 }'
}

# t LABEL [N] [pause]: tap element by label (fails loudly if missing)
t() {
  local c; c=$(center "$1" "${2:-1}")
  if [ -z "$c" ]; then echo "MISSING: $1" >&2; return 1; fi
  $ADB shell input tap $c; sleep "${3:-1.2}"
}

tap() { $ADB shell input tap "$1" "$2"; sleep "${3:-1}"; }
key() { $ADB shell input keyevent "$1"; sleep 0.6; }
swipe() { $ADB shell input swipe "$1" "$2" "$3" "$4" "${5:-500}"; sleep 0.8; }
up() { swipe 540 1800 540 800 600; }      # scroll content up
down() { swipe 540 800 540 1800 600; }

# typ TEXT: type slowly-ish (spaces ok)
typ() { $ADB shell "input text '$(echo "$1" | sed 's/ /%s/g')'"; sleep 0.5; }

# fld N TEXT: focus Nth EditText on screen, clear it, type TEXT
fld() {
  local b; b=$(dump | grep 'EditText' | sed -n "${1}p" | grep -oE 'bounds="[^"]+"' | grep -oE '[0-9]+' | tr '\n' ' ')
  set -- "$1" "$2" $b
  $ADB shell input tap $(( ($3 + $5) / 2 )) $(( ($4 + $6) / 2 )); sleep 0.4
  $ADB shell input keyevent KEYCODE_MOVE_END
  $ADB shell input keyevent $(printf 'KEYCODE_DEL %.0s' $(seq 1 40))
  [ -n "$2" ] && typ "$2"
  sleep 0.4
}

# hidekb: close the soft keyboard only if it is showing
hidekb() { $ADB shell dumpsys input_method | grep -q 'mInputShown=true' && key 4; sleep 0.3; }

shot() { $ADB exec-out screencap -p > "${SHOTS:-shots}/$1.png"; }
