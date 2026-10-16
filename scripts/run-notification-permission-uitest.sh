#!/bin/bash
# #145 D2 (Spec docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md): je Weg allow/deny ein Wegwerf-
# Simulator (Typ/Runtime der Vorlage, Neuinstallation setzt erst nach einem Tag zurück, Apple TN2265) → installieren →
# testen → löschen. Aufruf: $0 [<udid>] (Vorlage, Standard „Restock-Validate“, wird nur gelesen, bleibt unberührt).
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DD="build/dd-notif"; STAMP=$(date '+%Y%m%d-%H%M%S'); ART="docs/artifacts/test-145-d2-mitteilungserlaubnis"
HEAVY_LOCK="/tmp/heavy-build.lock"; LOOSE_LOCK="/tmp/loose-ends-testlauf.lock"
MY_LOCKS=""; MY_SIMS=""

drop_sim() { xcrun simctl shutdown "$1" >/dev/null 2>&1; xcrun simctl delete "$1" >/dev/null 2>&1; }
# nur selbst angelegte Wegwerf-Simulatoren und Sperren
cleanup() { for sim in $MY_SIMS; do drop_sim "$sim"; done; for lock in $MY_LOCKS; do rm -rf "$lock"; done; }
trap cleanup EXIT; trap 'exit 130' INT TERM

# Sperren atomar per mkdir, fremde nie anfassen
take_lock() {
  mkdir "$1" 2>/dev/null || { echo "ABBRUCH — Sperre $1 belegt, Inhaber: $(cat "$1/owner" 2>/dev/null || echo '(keine owner-Datei)')"; return 1; }
  MY_LOCKS="$MY_LOCKS $1"; echo "run-notification-permission-uitest #145-D2 $(date '+%Y-%m-%d %H:%M')" > "$1/owner"
}
take_lock "$HEAVY_LOCK" || exit 2; take_lock "$LOOSE_LOCK" || exit 2
echo "→ Sperren genommen:$MY_LOCKS"
# Vorlage nur lesen (nicht booten, nicht verändern): Gerätetyp und Runtime-Schlüssel
SIMS=$(xcrun simctl list devices -j)
TEMPLATE="${1:-$(echo "$SIMS" | jq -r '[.devices[][] | select(.name == "Restock-Validate" and .isAvailable)][0].udid')}"
DEVTYPE=$(echo "$SIMS" | jq -r --arg u "$TEMPLATE" '[.devices[][] | select(.udid == $u)][0].deviceTypeIdentifier // empty')
RUNTIME=$(echo "$SIMS" | jq -r --arg u "$TEMPLATE" '.devices | to_entries[] | select(any(.value[]; .udid == $u)) | .key')
if [ -z "$TEMPLATE" ] || [ "$TEMPLATE" = "null" ] || [ -z "$DEVTYPE" ] || [ -z "$RUNTIME" ]; then echo "ROT — Vorlage nicht gefunden"; exit 1; fi
echo "→ Vorlage: $TEMPLATE ($DEVTYPE, $RUNTIME)"
mkdir -p "$ART"

# Einmal bauen, ohne zusätzliche Build-Settings
echo "→ build-for-testing …"
if ! xcodebuild build-for-testing -scheme Restock -project Restock.xcodeproj -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DD" > "$ART/build-$STAMP.log" 2>&1; then
  grep -E "error:" "$ART/build-$STAMP.log" | head -20; echo "ROT — Bau fehlgeschlagen"; exit 1
fi
BUILT_APP="$DD/Build/Products/Debug-iphonesimulator/Restock.app"
[ -d "$BUILT_APP" ] || { echo "ROT — gebaute App fehlt: $BUILT_APP"; exit 1; }
# Ein Weg: Wegwerf-Simulator anlegen → installieren → Test → Auswertung → löschen
run_way() {
  local way=$1 test=$2 log="$ART/notif-$1-$STAMP.log" bundle="build/notif-$1-$STAMP.xcresult" shots="$ART/screens-$1-$STAMP"
  local status executed failures problems="" summary sim
  sim=$(xcrun simctl create "Restock-Notif-$way-$STAMP" "$DEVTYPE" "$RUNTIME") \
    || { RESULTS="$RESULTS"$'\n'"Weg $way ($test): ROT — Wegwerf-Simulator nicht angelegt"; return 1; }
  MY_SIMS="$MY_SIMS $sim"
  xcrun simctl boot "$sim" >/dev/null 2>&1; xcrun simctl bootstatus "$sim" -b >/dev/null
  xcrun simctl install "$sim" "$BUILT_APP" || problems="$problems Installation fehlgeschlagen;"
  mkdir -p "$shots"
  ( n=0; while true; do n=$((n + 1)); xcrun simctl io "$sim" screenshot --type=jpeg "$shots/$(printf '%03d' $n).jpg" >/dev/null 2>&1; sleep 4; done ) &
  local poller=$!
  echo "→ Weg $way auf $sim: Test läuft (Protokoll $log) …"
  TEST_RUNNER_RESTOCK_NOTIF_DECISION="$way" xcodebuild test-without-building -scheme Restock -project Restock.xcodeproj \
    -destination "id=$sim" -derivedDataPath "$DD" -only-testing:RestockUITests/NotificationPermissionUITests \
    -resultBundlePath "$bundle" -collect-test-diagnostics never > "$log" 2>&1   # sonst 10-min-Hänger beim Diagnose-Sammeln
  status=$?
  kill "$poller" 2>/dev/null; wait "$poller" 2>/dev/null
  xcrun simctl io "$sim" screenshot --type=jpeg "$shots/nach-test.jpg" >/dev/null 2>&1
  drop_sim "$sim"
  sips -Z 900 "$shots"/*.jpg >/dev/null 2>&1   # Belege klein halten (Repo)
  summary=$(grep -E "Executed [0-9]+ tests?, with" "$log" | tail -1)
  executed=$(echo "$summary" | sed -E 's/.*Executed ([0-9]+) test.*/\1/')
  failures=$(echo "$summary" | sed -E 's/.* ([0-9]+) failures?.*/\1/')
  [ "$status" -eq 0 ] || problems="$problems xcodebuild-Status $status;"; [ "${failures:-x}" = "0" ] || problems="$problems Fehlschläge: ${failures:-unbekannt};"
  grep -q "NotificationPermissionUITests $test\]' passed" "$log" || problems="$problems $test nicht bestanden (gelaufen?);"
  grep -q "Executed 0 tests" "$log" && problems="$problems Executed 0 tests;"; grep -q "TEST EXECUTE FAILED" "$log" && problems="$problems TEST EXECUTE FAILED;"
  grep -q "Restarting after unexpected exit" "$log" && problems="$problems Runner-Neustart;"
  local verdict="GRÜN"; [ -n "$problems" ] && verdict="ROT —$problems"
  RESULTS="$RESULTS
Weg $way ($test): $verdict   Wegwerf-Simulator: $sim
  ausgeführt: ${executed:-?}, Fehlschläge: ${failures:-?}, Status: $status
  Protokoll: $log   Ergebnisbündel: $bundle
  Screenshots: $shots/ (alle 4 s während des Tests, zuletzt nach-test.jpg)"
  [ -z "$problems" ]
}

RESULTS=""; OK=0
run_way allow testAllow || OK=1
run_way deny testDeny || OK=1

# Schlusszustand: kein Wegwerf-Simulator dieses Laufs mehr vorhanden
for sim in $MY_SIMS; do drop_sim "$sim"; done
LEFT="nein"; xcrun simctl list devices | grep -qE "Restock-Notif-(allow|deny)-$STAMP" && { LEFT="ja"; OK=1; }
DIRTY="nein"; [ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY="ja"
echo ""; echo "=================== ERGEBNIS ==================="
echo "Commit:     $(git rev-parse --short HEAD 2>/dev/null || echo unbekannt)   (uncommittete Änderungen: $DIRTY)"
echo "Vorlage:    $TEMPLATE / $RUNTIME (unberührt)"; echo "Zeit:       $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "$RESULTS"
echo "Wegwerf-Simulatoren nach dem Lauf übrig: $LEFT   (muss: nein)"
echo "================================================"
[ "$OK" -eq 0 ] && echo "GRÜN — beide Wege bestanden." || echo "ROT — siehe Ergebnisblock."
exit "$OK"
