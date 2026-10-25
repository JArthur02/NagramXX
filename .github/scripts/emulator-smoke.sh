#!/usr/bin/env bash
# Smoke test on an emulator: install the debug APK, launch it, walk to the login
# screen, and fail if the app process crashes. Screenshots and logcat go to smoke/.
set -u
PKG=nu.gpu.nagram
OUT=smoke
mkdir -p "$OUT"

APK=$(ls TMessagesProj/build/outputs/apk/debug/*x86_64*.apk | head -1)
echo "Installing $APK"
adb install -r -g "$APK" || exit 1
adb logcat -c

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }

# Tap the first on-screen element whose text matches $1 (case-insensitive regex).
tap_text() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 1
  adb shell cat /sdcard/ui.xml > "$OUT/ui-$2.xml"
  local bounds
  bounds=$(python3 - "$1" "$OUT/ui-$2.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
pattern, path = re.compile(sys.argv[1], re.I), sys.argv[2]
for node in ET.parse(path).iter('node'):
    if pattern.search(node.get('text', '') or node.get('content-desc', '')):
        print(node.get('bounds')); break
PY
)
  [ -n "$bounds" ] || return 1
  read -r x1 y1 x2 y2 <<<"$(echo "$bounds" | tr -c '0-9' ' ')"
  adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
}

alive() { adb shell pidof "$PKG" >/dev/null; }

adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 25
shot 01-launch
alive || { echo "::error::App is not running after launch"; FAILED=1; }

if [ -z "${FAILED:-}" ]; then
  if tap_text 'start messaging' intro; then
    sleep 10
    shot 02-after-start
  else
    echo "::warning::'Start Messaging' button not found; see smoke/01-launch.png"
  fi
  alive || { echo "::error::App died after opening the login flow"; FAILED=1; }
fi

adb logcat -d > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  echo "::error::Crash in logcat:"
  grep -A30 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60
  FAILED=1
fi
[ -z "${FAILED:-}" ] && echo "Smoke test passed."
exit ${FAILED:-0}
