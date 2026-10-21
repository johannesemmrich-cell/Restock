#!/bin/zsh
# Nachstellung #35 mit Diagnose-Protokoll (DIAG35): erster Test der Klasse nach kaltem Install, unter CPU-Last.
# Aufruf: repro-35b.sh <Anzahl Läufe> <Last: 1|0> [Testkennung]
set -u
S=/private/tmp/claude-501/-Users-hem-Developer-Restock/2056e5d3-1e6f-4f64-8836-8af6e613992a/scratchpad
WT=$S/copy35
DD=$S/DerivedData-copy
UDID=$(cat "$S/udid.txt")
RUNS=${1:-3}
LOAD=${2:-1}
TEST=${3:-RestockUITests/ReceiptReviewUITests/testAiMarkStaysOnOneLine}
APPGROUP=group.com.johannesemmrich.SmartCart
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

summary="$S/repro-35b-summary.txt"
: > "$summary"

for i in $(seq 1 "$RUNS"); do
  log="$S/repro-35b-run$i.log"
  echo "== Lauf $i $(date '+%H:%M:%S') Last=$LOAD" | tee -a "$summary"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
  if [ "$LOAD" = "1" ]; then
    for c in $(seq 1 10); do perl -e 'alarm 1500; 1 while 1' & done
  fi
  xcodebuild test-without-building \
    -project "$WT/Restock.xcodeproj" -scheme Restock \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DD" \
    -only-testing:"$TEST" \
    -resultBundlePath "$S/repro-35b-run$i.xcresult" > "$log" 2>&1
  rc=$?
  if [ "$LOAD" = "1" ]; then pkill -f "perl -e alarm" ; fi
  result=$(grep -E "Executed [0-9]+ test" "$log" | tail -1)
  fail=$(grep -c "Bon-Prüf-Sheet ist nicht erschienen" "$log")
  prefs=$(ls "$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Containers/Shared/AppGroup/"*/Library/Preferences/"$APPGROUP.plist" 2>/dev/null | head -1)
  pending="unbekannt"
  if [ -n "$prefs" ]; then
    if plutil -p "$prefs" | grep -q pendingShareExtensionReceipt; then pending="JA (Nutzlast liegt noch)"; else pending="nein (verbraucht)"; fi
  fi
  xcrun simctl spawn "$UDID" log show --predicate 'subsystem == "restock.diag35"' --last 2h --style compact > "$S/repro-35b-run$i.diag.log" 2>&1
  echo "   rc=$rc | $result | Vorbedingungsfehler=$fail | Nutzlast wartet: $pending" | tee -a "$summary"
  grep DIAG35 "$S/repro-35b-run$i.diag.log" | sed 's/^/   /' | tee -a "$summary"
done
xcrun simctl shutdown "$UDID" >/dev/null 2>&1
echo "FERTIG" | tee -a "$summary"
