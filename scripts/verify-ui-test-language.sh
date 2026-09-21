#!/bin/bash
# Nachweis-Lauf für Issue #3 — "UI-Tests schlagen fehl, weil der Simulator auf Englisch läuft".
#
# Prüft die Acceptance Criteria AC-2 bis AC-5 aus docs/specs/testing/ui-test-language.md.
# AC-1 (CI-Job `ui-test` grün) wird von der CI selbst belegt, nicht hier.
#
# Warum ein eigenes Skript statt eines XCTest-Falls: Geprüft wird nicht App-Verhalten,
# sondern die *Testumgebung* — welche Sprache der Simulator beim Testlauf benutzt. Das
# lässt sich nur von außerhalb des Testprozesses feststellen, indem derselbe Lauf zweimal
# unterschiedlich aufgerufen und das Ergebnis verglichen wird.
#
#   Lauf 1 (AC-2, AC-4, AC-5): Aufruf wie in der CI, OHNE -testLanguage/-testRegion.
#                              Erwartung: 0 Fehlschläge (der neue Scheme-Standard greift).
#   Lauf 2 (AC-3, Negativkontrolle): derselbe Aufruf MIT -testLanguage en -testRegion US.
#                              Erwartung: exakt die drei ursprünglichen Fehlschläge — Beleg,
#                              dass wirklich die Sprache die Ursache ist und nicht ein Zufall.
#
# Der Prüfsimulator wird vor jedem Lauf auf ENGLISCH gestellt. Das ist der entscheidende
# Punkt: Ein Mac mit deutscher Systemsprache erzeugt auch deutsche Simulatoren, der
# GitHub-Runner dagegen englische. Ohne diese Angleichung wäre Lauf 1 lokal schon vor der
# Änderung grün und würde über die Scheme-Einstellung nichts beweisen — die Sprache käme
# vom Gerät, nicht aus dem Scheme.
#
# Jeder Lauf startet auf einem eigens angelegten, per `simctl erase` geleerten Simulator:
# Die Tests setzen ihren Zustand nicht zurück (SwiftData persistiert über Läufe hinweg),
# ohne Leerung laufen lokale und CI-Ergebnisse auseinander.
#
# Aufruf:  scripts/verify-ui-test-language.sh
# Ausgabe: docs/artifacts/fix-3-ui-test-sprache/  (Rohprotokolle beider Läufe)
# Exit:    0 = alle geprüften Kriterien erfüllt, 1 = mindestens eines verletzt.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ARTIFACT_DIR="docs/artifacts/fix-3-ui-test-sprache"
mkdir -p "$ARTIFACT_DIR"

SIM_NAME="Restock-UITest-Verify"
SIM_RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-27-0"
SIM_DEVICE="com.apple.CoreSimulator.SimDeviceType.iPhone-17"
BUNDLE_ID="com.johannesemmrich.Restock"

# Die drei Tests, die auf englischem Simulator an deutschen Beschriftungen scheitern.
# Genau diese — nicht mehr, nicht weniger — muss die Negativkontrolle wieder zeigen.
SPRACH_TESTS=(
  "testJoinSharedListSheetIsScrollableAndUsable"
  "testJoinWithLegacySixCharacterCodeTriggersLookup"
  "testAddStoreAndQuickAddItemShowsPriceWithoutCrash"
)

# Der Test, der die Schnelleingabe und den Teilen-Knopf durchläuft (AC-4, AC-5).
QUICK_ADD_TEST="testAddStoreAndQuickAddItemShowsPriceWithoutCrash"

FAILED_CHECKS=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED_CHECKS=$((FAILED_CHECKS + 1)); }
info() { printf '        %s\n' "$1"; }

# --- Simulator bereitstellen -------------------------------------------------

ensure_simulator() {
  local udid
  udid=$(xcrun simctl list devices -j \
    | /usr/bin/python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for rt,devs in d.items():
    if '$SIM_RUNTIME' == rt:
        for x in devs:
            if x['name'] == '$SIM_NAME':
                print(x['udid']); sys.exit(0)
")
  if [ -z "$udid" ]; then
    udid=$(xcrun simctl create "$SIM_NAME" "$SIM_DEVICE" "$SIM_RUNTIME")
  fi
  echo "$udid"
}

reset_simulator() {
  local udid="$1"
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid" >/dev/null
  xcrun simctl bootstatus "$udid" -b >/dev/null

  # Gerätesprache auf Englisch — gleicht den lokalen Simulator an den GitHub-Runner an
  # (siehe Kopfkommentar). Muss nach dem Leeren und vor dem Testlauf passieren; der
  # Neustart übernimmt die Einstellung in die laufende Sitzung.
  xcrun simctl spawn "$udid" defaults write "Apple Global Domain" AppleLanguages -array en
  xcrun simctl spawn "$udid" defaults write "Apple Global Domain" AppleLocale -string en_US
  xcrun simctl shutdown "$udid" >/dev/null
  xcrun simctl boot "$udid" >/dev/null
  xcrun simctl bootstatus "$udid" -b >/dev/null

  # Wie im CI-Schritt "Grant app permissions": verhindert Systemdialoge, die XCUITest
  # nicht zuverlässig wegklicken kann.
  xcrun simctl privacy "$udid" grant camera "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$udid" grant photos "$BUNDLE_ID" >/dev/null 2>&1 || true
}

# Belegt im Protokoll, dass das Gerät wirklich englisch steht — sonst wäre ein grünes
# Ergebnis in Lauf 1 wertlos.
assert_device_english() {
  local udid="$1"
  local langs
  langs="$(xcrun simctl spawn "$udid" defaults read "Apple Global Domain" AppleLanguages 2>/dev/null | tr -d ' \n')"
  info "Gerätesprache: ${langs:-<nicht lesbar>}"
  case "$langs" in
    *'"en"'*|*'(en)'*) return 0 ;;
    *) fail "Vorbedingung: Prüfsimulator steht nicht auf Englisch — Lauf 1 beweist dann nichts."; return 1 ;;
  esac
}

# --- Testlauf ----------------------------------------------------------------

# run_tests <udid> <logdatei> [zusätzliche xcodebuild-Argumente...]
# Aufruf identisch zum CI-Schritt "Build and run UI tests".
run_tests() {
  local udid="$1"; shift
  local logfile="$1"; shift
  xcodebuild test \
    -project Restock.xcodeproj \
    -scheme Restock \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:RestockUITests \
    -skipMacroValidation \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    "$@" \
    > "$logfile" 2>&1
  return 0
}

# Letzte "Executed N tests, with M test(s) skipped and K failure(s)"-Zeile.
summary_line() {
  grep -E '^[[:space:]]*Executed [0-9]+ test' "$1" | tail -1 | sed 's/^[[:space:]]*//'
}

failure_count() {
  summary_line "$1" | sed -nE 's/.*and ([0-9]+) failure.*/\1/p'
}

# test_passed <testmethode> <logdatei>
test_passed() {
  grep -q "^Test Case '-\[RestockUITests\.RestockUITests $1\]' passed" "$2"
}

# Namen der Testmethoden, die in diesem Lauf fehlgeschlagen sind.
failed_test_names() {
  grep -E "^Test Case '-\[RestockUITests\.RestockUITests .*\]' failed" "$1" \
    | sed -E "s/^Test Case '-\[RestockUITests\.RestockUITests ([A-Za-z0-9_]+)\]'.*/\1/" \
    | sort -u
}

# --- Lauf 1: Standardsprache aus dem Scheme (AC-2, AC-4, AC-5) ---------------

UDID=$(ensure_simulator)
echo "Simulator: $SIM_NAME ($UDID)"
echo

echo "Lauf 1 — Aufruf wie in der CI, ohne -testLanguage/-testRegion (AC-2, AC-4, AC-5)"
reset_simulator "$UDID"
assert_device_english "$UDID"
LOG_DEFAULT="$ARTIFACT_DIR/run-default-language.txt"
run_tests "$UDID" "$LOG_DEFAULT"
SUMMARY_DEFAULT="$(summary_line "$LOG_DEFAULT")"
FAILURES_DEFAULT="$(failure_count "$LOG_DEFAULT")"
info "${SUMMARY_DEFAULT:-<keine Ergebniszeile gefunden — Build fehlgeschlagen?>}"

if [ "${FAILURES_DEFAULT:-}" = "0" ]; then
  pass "AC-2: Standardlauf ohne Sprachschalter zeigt 0 Fehlschläge."
else
  fail "AC-2: Standardlauf zeigt ${FAILURES_DEFAULT:-?} Fehlschläge statt 0."
  failed_test_names "$LOG_DEFAULT" | while read -r t; do [ -n "$t" ] && info "fehlgeschlagen: $t"; done
fi

# AC-4 und AC-5 verlangen beide POSITIVEN Beleg, nicht nur die Abwesenheit einer Meldung:
# Scheitert der Test schon an einem früheren Schritt, taucht der Fokus-Fehler gar nicht
# erst im Protokoll auf — ein "nicht gefunden" wäre dann ein Scheingrün.
if test_passed "$QUICK_ADD_TEST" "$LOG_DEFAULT" \
   && ! grep -q "Neither element nor any descendant has keyboard focus" "$LOG_DEFAULT"; then
  pass "AC-4: Schnelleingabe erhält den Tastaturfokus, Texteingabe gelingt."
else
  fail "AC-4: Texteingabe in die Schnelleingabe ist nicht belegt (Test nicht bestanden oder Fokus-Fehler im Protokoll)."
fi

# AC-5: Die alte, sprachabhängige Suche über 'label CONTAINS' darf im Testcode nicht mehr
# stehen — sie greift in keiner Sprache. Zusätzlich muss der Test tatsächlich durchlaufen.
if grep -q "label CONTAINS 'person.2'" RestockUITests/RestockUITests.swift; then
  fail "AC-5: Teilen-Knopf wird weiterhin über die Beschriftung gesucht (label CONTAINS 'person.2') statt über die Kennung."
elif test_passed "$QUICK_ADD_TEST" "$LOG_DEFAULT"; then
  pass "AC-5: Teilen-Knopf wird über die sprachunabhängige Kennung gefunden."
else
  fail "AC-5: Teilen-Knopf-Schritt ist nicht belegt — Test nicht bestanden."
fi

echo

# --- Lauf 2: Negativkontrolle auf Englisch (AC-3) ----------------------------

echo "Lauf 2 — Negativkontrolle mit -testLanguage en -testRegion US (AC-3)"
reset_simulator "$UDID"
LOG_ENGLISH="$ARTIFACT_DIR/run-negative-control-en.txt"
run_tests "$UDID" "$LOG_ENGLISH" -testLanguage en -testRegion US
SUMMARY_ENGLISH="$(summary_line "$LOG_ENGLISH")"
FAILURES_ENGLISH="$(failure_count "$LOG_ENGLISH")"
info "${SUMMARY_ENGLISH:-<keine Ergebniszeile gefunden — Build fehlgeschlagen?>}"

EXPECTED_NAMES="$(printf '%s\n' "${SPRACH_TESTS[@]}" | sort -u)"
ACTUAL_NAMES="$(failed_test_names "$LOG_ENGLISH")"

if [ "$ACTUAL_NAMES" = "$EXPECTED_NAMES" ]; then
  pass "AC-3: Negativkontrolle zeigt exakt die drei ursprünglichen Fehlschläge."
else
  fail "AC-3: Negativkontrolle zeigt nicht die drei erwarteten Fehlschläge."
  info "erwartet: $(echo "$EXPECTED_NAMES" | tr '\n' ' ')"
  info "erhalten: $(echo "${ACTUAL_NAMES:-<keine>}" | tr '\n' ' ')"
fi

echo
echo "Protokolle: $LOG_DEFAULT"
echo "            $LOG_ENGLISH"
echo

if [ "$FAILED_CHECKS" -eq 0 ]; then
  echo "ERGEBNIS: alle geprüften Kriterien erfüllt (AC-2 bis AC-5)."
  exit 0
fi

echo "ERGEBNIS: $FAILED_CHECKS Kriterium/Kriterien verletzt."
exit 1
