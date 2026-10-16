#!/bin/bash
# #145 D3 (Spec docs/specs/ui-tests/test-145-durchgang-3-app-intents.md): AppIntentsUITests auf einem iOS-27.0-
# Wegwerf-Simulator (AppIntentsTesting braucht Xcode 27 + iOS 27). Sperren → einmal bauen → Simulator anlegen →
# installieren → test-without-building → Auswertung → Simulator löschen. Restock-Validate bleibt unberührt.
set -uo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DD="build/dd-appintents"; STAMP=$(date '+%Y%m%d-%H%M%S'); ART="docs/artifacts/test-145-d3-app-intents-testing"
SIM_NAME="Restock-AppIntents-$STAMP"; LOG="$ART/appintents-$STAMP.log"; BUNDLE="build/appintents-$STAMP.xcresult"
MY_LOCKS=""; SIM=""; WATCH=""
cleanup() {
  [ -n "$WATCH" ] && kill "$WATCH" 2>/dev/null
  [ -n "$SIM" ] && { xcrun simctl shutdown "$SIM" >/dev/null 2>&1; xcrun simctl delete "$SIM" >/dev/null 2>&1; }
  for lock in $MY_LOCKS; do rm -rf "$lock"; done   # nur selbst angelegte Sperren
}
trap cleanup EXIT; trap 'exit 130' INT TERM
take_lock() {   # atomar per mkdir, fremde Sperre nie anfassen
  mkdir "$1" 2>/dev/null || { echo "ABBRUCH — Sperre $1 belegt, Inhaber: $(cat "$1/owner" 2>/dev/null || echo '(keine owner-Datei)')"; return 1; }
  MY_LOCKS="$MY_LOCKS $1"; echo "run-appintents-uitest #145-D3 $(date '+%Y-%m-%d %H:%M')" > "$1/owner"
}
take_lock /tmp/heavy-build.lock || exit 2; take_lock /tmp/loose-ends-testlauf.lock || exit 2
LOAD_START=$(sysctl -n vm.loadavg); mkdir -p "$ART"
RUNTIME=$(xcrun simctl list runtimes -j | jq -r '[.runtimes[] | select(.version == "27.0" and .isAvailable)][0].identifier // empty')
[ -n "$RUNTIME" ] || { echo "ROT — Runtime iOS 27.0 nicht vorhanden"; exit 1; }
echo "→ Sperren genommen:$MY_LOCKS — build-for-testing …"
# APPINTENTS_UITESTS nur hier: mit AppIntentsTesting einkompiliert lädt das Testbündel auf iOS 26 nicht (Spec, Kopf)
if ! xcodebuild build-for-testing -scheme Restock -project Restock.xcodeproj -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DD" 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) APPINTENTS_UITESTS' >"$ART/build-$STAMP.log" 2>&1; then
  grep -E "error:" "$ART/build-$STAMP.log" | head -20; echo "ROT — Bau fehlgeschlagen"; exit 1
fi
APP="$DD/Build/Products/Debug-iphonesimulator/Restock.app"
SIM=$(xcrun simctl create "$SIM_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$RUNTIME") || { echo "ROT — Simulator nicht angelegt"; exit 1; }
xcrun simctl boot "$SIM" >/dev/null 2>&1; xcrun simctl bootstatus "$SIM" -b >/dev/null
PROBLEMS=""; xcrun simctl install "$SIM" "$APP" || PROBLEMS="$PROBLEMS Installation fehlgeschlagen;"
echo "→ Test auf $SIM ($SIM_NAME), Protokoll $LOG …"; START=$(date +%s)
xcodebuild test-without-building -scheme Restock -project Restock.xcodeproj -destination "id=$SIM" -derivedDataPath "$DD" \
  -only-testing:RestockUITests/AppIntentsUITests -resultBundlePath "$BUNDLE" -collect-test-diagnostics never > "$LOG" 2>&1 &
XB=$!
# Hänger-Schutz (Muster #21): nach einem Testergebnis 15 min ohne neue Protokollzeile → xcodebuild beenden
( while kill -0 "$XB" 2>/dev/null; do sleep 30
    if grep -qE "^Test Case .*(passed|failed|skipped)" "$LOG" && [ $(( $(date +%s) - $(stat -f %m "$LOG") )) -gt 900 ]; then
      echo "HÄNGER-SCHUTZ: xcodebuild nach 15 min Stillstand beendet" >> "$LOG"; kill "$XB"; fi; done ) &
WATCH=$!
wait "$XB"; STATUS=$?; kill "$WATCH" 2>/dev/null; WATCH=""; SECS=$(( $(date +%s) - START ))
xcrun simctl shutdown "$SIM" >/dev/null 2>&1; xcrun simctl delete "$SIM" >/dev/null 2>&1 && SIM=""
PASSED=$(grep -cE "^Test Case '-\[RestockUITests.AppIntentsUITests .*' passed" "$LOG")
FAILED=$(grep -cE "^Test Case '-\[RestockUITests.AppIntentsUITests .*' failed" "$LOG")
SKIPPED=$(grep -cE "^Test Case '-\[RestockUITests.AppIntentsUITests .*' skipped" "$LOG")
RETRIES=$(grep -c "AppIntents: Wiederholung" "$LOG"); EXECUTED=$((PASSED + FAILED + SKIPPED))
[ "$STATUS" -eq 0 ] || PROBLEMS="$PROBLEMS xcodebuild-Status $STATUS;"
[ "$EXECUTED" -eq 3 ] || PROBLEMS="$PROBLEMS $EXECUTED statt 3 Tests;"
[ "$FAILED" -eq 0 ] || PROBLEMS="$PROBLEMS $FAILED Fehlschläge;"; [ "$SKIPPED" -eq 0 ] || PROBLEMS="$PROBLEMS $SKIPPED übersprungen;"
for bad in "Executed 0 tests" "Restarting after unexpected exit" "TEST EXECUTE FAILED" "HÄNGER-SCHUTZ"; do
  grep -q "$bad" "$LOG" && PROBLEMS="$PROBLEMS $bad;"; done
LEFT="nein"; xcrun simctl list devices | grep -q "$SIM_NAME" && { LEFT="ja"; PROBLEMS="$PROBLEMS Wegwerf-Simulator übrig;"; }
DIRTY="nein"; [ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY="ja"
echo ""; echo "=================== ERGEBNIS ==================="
echo "Commit:       $(git rev-parse --short HEAD 2>/dev/null || echo unbekannt)   (uncommittete Änderungen: $DIRTY)"
echo "Xcode:        $(xcodebuild -version | tr '\n' ' ')  Runtime: $RUNTIME"
echo "Zeit:         $(date '+%Y-%m-%d %H:%M:%S %z')   Testdauer: ${SECS} s   Last zu Beginn: $LOAD_START"
echo "Tests:        ausgeführt $EXECUTED (muss: 3), bestanden $PASSED, Fehlschläge $FAILED, übersprungen $SKIPPED"
echo "400-Wiederholungen (Messzeilen „AppIntents: Wiederholung“): $RETRIES"
echo "Protokoll:    $LOG   Ergebnisbündel: $BUNDLE"
echo "Wegwerf-Simulatoren nach dem Lauf übrig: $LEFT (muss: nein)"
echo "================================================"
grep -E "^Test Case '-\[RestockUITests.AppIntentsUITests .*' (passed|failed|skipped)|AppIntents: (Wiederholung|Erfolg)" "$LOG"
[ -z "$PROBLEMS" ] && { echo "GRÜN — 3 Tests bestanden."; exit 0; }
echo "ROT —$PROBLEMS"; exit 1
