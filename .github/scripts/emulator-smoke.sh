#!/usr/bin/env bash
# Smoke test on an emulator. Installs the debug APK, launches it, logs in to a fresh
# account on Telegram's TEST servers (phone 99966XYYYY, code XXXXX, no SMS), then sends a
# message to Saved Messages, opens Settings and N-Settings and runs the update check.
#
# Only crashes fail the job. Every other step is reported in the job summary, with
# screenshots, UI dumps and logcat in smoke/.
set -u
PKG=nu.gpu.nagram
OUT=smoke
mkdir -p "$OUT"
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/stdout}
STEP=0

# Test DC 2: the login code is "22222". A random suffix gives a new account each run.
DC=2
PHONE_REST="66${DC}$(printf '%04d' $((RANDOM % 10000)))"
PHONE="999${PHONE_REST}"
CODE="${DC}${DC}${DC}${DC}${DC}"

report() { echo "| $1 | $2 |" >> "$SUMMARY"; echo "$1: $2"; }
shot() { STEP=$((STEP + 1)); adb exec-out screencap -p > "$OUT/$(printf '%02d' $STEP)-$1.png"; }
alive() { adb shell pidof "$PKG" >/dev/null; }
# uiautomator cannot dump screens that never go idle (e.g. the animated intro), so retry
# and let callers fall back to tapping by screen position.
dump() {
  local _
  for _ in 1 2 3; do
    if adb shell uiautomator dump /sdcard/ui.xml 2>&1 | grep -q "dumped to"; then
      adb shell cat /sdcard/ui.xml > "$OUT/ui-last.xml"
      return 0
    fi
    sleep 2
  done
  return 1
}
SCREEN=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1)
W=${SCREEN%x*}; H=${SCREEN#*x}
# Tap at a fraction of the screen size, e.g. tap_frac 50 88 taps (50% width, 88% height).
tap_frac() { adb shell input tap $((W * $1 / 100)) $((H * $2 / 100)); }

# Print "x y" for the centre of the first node whose text or content-desc matches $1
# (case-insensitive regex). $2 optionally restricts the node class (e.g. EditText).
find_node() {
  dump || return 1
  python3 - "$1" "${2:-}" "$OUT/ui-last.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
pattern, cls, path = re.compile(sys.argv[1], re.I), sys.argv[2], sys.argv[3]
for node in ET.parse(path).iter('node'):
    if cls and not node.get('class', '').endswith(cls):
        continue
    if any(pattern.search(node.get(k) or '') for k in ('text', 'content-desc')):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds')))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
}
tap_node() { local xy; xy=$(find_node "$@") && [ -n "$xy" ] && adb shell input tap $xy; }
wait_node() { # pattern timeout_seconds [class]
  local end=$((SECONDS + $2))
  while [ $SECONDS -lt $end ]; do
    [ -n "$(find_node "$1" "${3:-}")" ] && return 0
    sleep 2
  done
  return 1
}
type_text() { adb shell input text "$1"; }

echo "## Emulator smoke test" >> "$SUMMARY"
echo "Test account: +$PHONE on Telegram test DC $DC" >> "$SUMMARY"
echo "" >> "$SUMMARY"
echo "| Step | Result |" >> "$SUMMARY"
echo "|---|---|" >> "$SUMMARY"

APK=$(ls TMessagesProj/build/outputs/apk/debug/*x86_64*.apk | head -1)
adb install -r -g "$APK" || { report "Install" "failed"; exit 1; }
adb logcat -c

# 1. Launch
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 20
shot launch
if alive; then report "Launch" "ok"; else report "Launch" "**app not running**"; fi

# 2. Login on the test backend
LOGGED_IN=""
if alive; then
  # The intro is animated, so its button usually has to be tapped by position.
  tap_node 'start messaging' || tap_frac 50 88
  sleep 5
  if [ -z "$(find_node 'country code' EditText)" ]; then tap_frac 50 90; sleep 5; fi
  shot phone-screen
  if tap_node 'country code' EditText; then
    adb shell input keyevent KEYCODE_MOVE_END
    for _ in 1 2 3 4 5; do adb shell input keyevent KEYCODE_DEL; done
    type_text 999   # "999" switches the app to the test backend
    tap_node 'phone number' EditText && type_text "$PHONE_REST"
    shot phone-entered
    tap_node '^done$|^next$'
    sleep 3
    # Optional "is this number correct?" confirmation.
    tap_node '^(yes|ok|continue)$' >/dev/null 2>&1
    if wait_node '\bsent\b|enter (the )?code|check your telegram' 40; then
      sleep 3
      shot code-screen
      type_text "$CODE"
      sleep 10
      # A new number goes to sign-up: first name, then Done.
      if [ -n "$(find_node 'first name' EditText)" ]; then
        tap_node 'first name' EditText && type_text Nagram
        tap_node '^done$|^next$'
        sleep 10
      fi
      # Terms of Service, if shown.
      tap_node '^(accept|agree)$' >/dev/null 2>&1 && sleep 5
      shot after-login
      if wait_node 'search|chats|saved messages|archived' 30; then
        LOGGED_IN=1
        report "Login (test DC)" "ok"
      else
        report "Login (test DC)" "did not reach the chat list; see screenshots"
      fi
    else
      report "Login (test DC)" "no code screen; see screenshots"
    fi
  else
    report "Login (test DC)" "country code field not found"
  fi
else
  report "Login (test DC)" "skipped: app not running"
fi

# 3. Send a message to Saved Messages
if [ -n "$LOGGED_IN" ]; then
  adb shell am start -a android.intent.action.VIEW -d "tg://resolve?phone=$PHONE" -p "$PKG" >/dev/null
  sleep 8
  if tap_node '^message$' EditText; then
    type_text "Smoke%stest%sfrom%sCI"
    tap_node '^send$' && sleep 5
    shot saved-messages
    if [ -n "$(find_node 'Smoke test from CI')" ]; then report "Send message" "ok"; else report "Send message" "message not visible"; fi
  else
    shot saved-messages
    report "Send message" "message field not found"
  fi

  # 4. Settings and N-Settings
  adb shell am start -a android.intent.action.VIEW -d "tg://settings" -p "$PKG" >/dev/null
  sleep 6
  shot settings
  for _ in 1 2 3; do [ -n "$(find_node 'N-Settings')" ] && break; adb shell input swipe $((W / 2)) $((H * 3 / 4)) $((W / 2)) $((H / 4)) 300; sleep 1; done
  if tap_node 'N-Settings'; then
    sleep 4
    shot nagram-settings
    report "N-Settings" "opened"
  else
    report "N-Settings" "entry not found"
  fi

  # 5. Update check (GitHub Releases)
  adb shell am start -a android.intent.action.VIEW -d "tg://update" -p "$PKG" >/dev/null
  sleep 8
  shot update-check
  report "Update check" "ran; see screenshot"
fi

# Crash check
adb logcat -d > "$OUT/logcat.txt"
FAILED=0
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  report "Crashes" "**FATAL EXCEPTION in logcat**"
  grep -A30 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60
  FAILED=1
elif ! alive; then
  report "Crashes" "**app process died**"
  FAILED=1
else
  report "Crashes" "none"
fi
exit $FAILED
