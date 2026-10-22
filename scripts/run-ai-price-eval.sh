#!/bin/bash
# #164 (Spec docs/specs/services/ai-price-estimation.md): AIPriceEvaluationTests mit dem ECHTEN Apple-Intelligence-
# Modell auf einem Wegwerf-Simulator. Voraussetzung: Mac mit Apple Silicon, macOS 26+, Apple Intelligence in den
# Systemeinstellungen eingeschaltet (Modell heruntergeladen). Sperren → einmal bauen (AI_EVAL) → Simulator anlegen →
# installieren → test-without-building → Bericht aus dem Protokoll heben → Simulator löschen. Restock-Validate bleibt unberührt.
# Aufruf: scripts/run-ai-price-eval.sh [ios-runtime-version, Standard 27.0]
set -uo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
WANT_RUNTIME="${1:-27.0}"
DD="build/dd-ai-price-eval"; STAMP=$(date '+%Y%m%d-%H%M%S'); ART="docs/artifacts/test-164-ai-price-eval"
SIM_NAME="Restock-AIPriceEval-$STAMP"; LOG="$ART/ai-eval-$STAMP.log"; REPORT="$ART/bericht-$STAMP.md"; BUNDLE="build/ai-eval-$STAMP.xcresult"
MY_LOCKS=""; SIM=""; WATCH=""
cleanup() {
  [ -n "$WATCH" ] && kill "$WATCH" 2>/dev/null
  [ -n "$SIM" ] && { xcrun simctl shutdown "$SIM" >/dev/null 2>&1; xcrun simctl delete "$SIM" >/dev/null 2>&1; }
  for lock in $MY_LOCKS; do rm -rf "$lock"; done   # nur selbst angelegte Sperren
}
trap cleanup EXIT; trap 'exit 130' INT TERM
take_lock() {   # atomar per mkdir, fremde Sperre nie anfassen
  mkdir "$1" 2>/dev/null || { echo "ABBRUCH — Sperre $1 belegt, Inhaber: $(cat "$1/owner" 2>/dev/null || echo '(keine owner-Datei)')"; return 1; }
  MY_LOCKS="$MY_LOCKS $1"; echo "run-ai-price-eval #164 $(date '+%Y-%m-%d %H:%M')" > "$1/owner"
}
take_lock /tmp/heavy-build.lock || exit 2; take_lock /tmp/loose-ends-testlauf.lock || exit 2
LOAD_START=$(sysctl -n vm.loadavg); mkdir -p "$ART"
RUNTIME=$(xcrun simctl list runtimes -j | jq -r --arg v "$WANT_RUNTIME" '[.runtimes[] | select(.version == $v and .isAvailable)][0].identifier // empty')
[ -n "$RUNTIME" ] || { echo "ROT — Runtime iOS $WANT_RUNTIME nicht vorhanden"; exit 1; }
echo "→ Sperren genommen:$MY_LOCKS — build-for-testing (AI_EVAL) …"
if ! xcodebuild build-for-testing -scheme Restock -project Restock.xcodeproj -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DD" 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) AI_EVAL' >"$ART/build-$STAMP.log" 2>&1; then
  grep -E "error:" "$ART/build-$STAMP.log" | head -20; echo "ROT — Bau fehlgeschlagen"; exit 1
fi
APP="$DD/Build/Products/Debug-iphonesimulator/Restock.app"
SIM=$(xcrun simctl create "$SIM_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$RUNTIME") || { echo "ROT — Simulator nicht angelegt"; exit 1; }
xcrun simctl boot "$SIM" >/dev/null 2>&1; xcrun simctl bootstatus "$SIM" -b >/dev/null
PROBLEMS=""; xcrun simctl install "$SIM" "$APP" || PROBLEMS="$PROBLEMS Installation fehlgeschlagen;"
echo "→ Messung auf $SIM ($SIM_NAME), Protokoll $LOG …"; START=$(date +%s)
xcodebuild test-without-building -scheme Restock -project Restock.xcodeproj -destination "id=$SIM" -derivedDataPath "$DD" \
  -only-testing:RestockTests/AIPriceEvaluationTests -resultBundlePath "$BUNDLE" -collect-test-diagnostics never > "$LOG" 2>&1 &
XB=$!
# Hänger-Schutz (Muster #21): 20 min ohne neue Protokollzeile → xcodebuild beenden (ein Lauf hat ~200 Modellaufrufe)
( while kill -0 "$XB" 2>/dev/null; do sleep 30
    if [ $(( $(date +%s) - $(stat -f %m "$LOG") )) -gt 1200 ]; then
      echo "HÄNGER-SCHUTZ: xcodebuild nach 20 min Stillstand beendet" >> "$LOG"; kill "$XB"; fi; done ) &
WATCH=$!
wait "$XB"; STATUS=$?; kill "$WATCH" 2>/dev/null; WATCH=""; SECS=$(( $(date +%s) - START ))
xcrun simctl shutdown "$SIM" >/dev/null 2>&1; xcrun simctl delete "$SIM" >/dev/null 2>&1 && SIM=""
PASSED=$(grep -cE "^Test Case '-\[RestockTests.AIPriceEvaluationTests .*' passed" "$LOG")
FAILED=$(grep -cE "^Test Case '-\[RestockTests.AIPriceEvaluationTests .*' failed" "$LOG")
SKIPPED=$(grep -cE "^Test Case '-\[RestockTests.AIPriceEvaluationTests .*' skipped" "$LOG")
EXECUTED=$((PASSED + FAILED + SKIPPED))
{
  echo "# Messung #164 (KI-Preisschätzung gegen Katalog) — $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo ""; echo "Commit $(git rev-parse --short HEAD 2>/dev/null || echo unbekannt) · $(xcodebuild -version | tr '\n' ' ') · Runtime $RUNTIME · Dauer ${SECS} s · Last zu Beginn $LOAD_START"
  echo ""; grep -E "AI-PRICE-EVAL-PROBE" "$LOG" | sed 's/^[^A]*AI-PRICE-EVAL/AI-PRICE-EVAL/'; echo ""
  awk '/AI-PRICE-EVAL-REPORT-BEGIN/{f=1;next}/AI-PRICE-EVAL-REPORT-END/{f=0}f' "$LOG"
} > "$REPORT"
[ "$STATUS" -eq 0 ] || PROBLEMS="$PROBLEMS xcodebuild-Status $STATUS;"
[ "$EXECUTED" -eq 1 ] || PROBLEMS="$PROBLEMS $EXECUTED statt 1 Test;"
[ "$FAILED" -eq 0 ] || PROBLEMS="$PROBLEMS $FAILED Fehlschläge;"; [ "$SKIPPED" -eq 0 ] || PROBLEMS="$PROBLEMS $SKIPPED übersprungen (Apple Intelligence aus?);"
grep -q "AI-PRICE-EVAL-REPORT-BEGIN" "$LOG" || PROBLEMS="$PROBLEMS kein Bericht im Protokoll;"
for bad in "Executed 0 tests" "Restarting after unexpected exit" "TEST EXECUTE FAILED" "HÄNGER-SCHUTZ"; do
  grep -q "$bad" "$LOG" && PROBLEMS="$PROBLEMS $bad;"; done
LEFT="nein"; xcrun simctl list devices | grep -q "$SIM_NAME" && { LEFT="ja"; PROBLEMS="$PROBLEMS Wegwerf-Simulator übrig;"; }
echo ""; echo "=================== ERGEBNIS ==================="
echo "Tests:        ausgeführt $EXECUTED (muss: 1), bestanden $PASSED, Fehlschläge $FAILED, übersprungen $SKIPPED"
echo "Bericht:      $REPORT   Protokoll: $LOG   Ergebnisbündel: $BUNDLE"
echo "Wegwerf-Simulatoren nach dem Lauf übrig: $LEFT (muss: nein)"
echo "================================================"
grep -E "AI-PRICE-EVAL-PROBE" "$LOG" | sed 's/^[^A]*AI-PRICE-EVAL/AI-PRICE-EVAL/'; head -8 "$REPORT" | tail -4
[ -z "$PROBLEMS" ] && { echo "GRÜN — Messung vollständig, Bericht unter $REPORT."; exit 0; }
echo "ROT —$PROBLEMS"; exit 1
