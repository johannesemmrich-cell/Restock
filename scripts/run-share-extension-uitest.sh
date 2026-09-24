#!/bin/bash
#
# Cross-App-Nachweis für Issue #4: Fotos-App → Teilen → Restock.
#
# Der XCUITest stellt nur den Ablauf her. Das Urteil fällt hier, weil die beiden Dinge, auf
# die es ankommt, außerhalb jedes Testprozesses liegen:
#
#   1. Landet die Bon-Nutzlast in der App-Gruppe? (Sandbox — ein Testprozess kommt da nicht ran)
#   2. Schreibt das System einen Absturzbericht der Erweiterung?
#
# Die Oberfläche der Erweiterung selbst ist für XCUITest nicht erreichbar (eigener Prozess,
# am 20.09.2026 gegen iOS 27.0 nachgemessen) — diese beiden Kriterien sind ohnehin die
# härteren: Sie prüfen das Ergebnis, nicht seine Beschriftung.
#
# Aufruf:  scripts/run-share-extension-uitest.sh [<simulator-udid>]
#
set -uo pipefail

DEVICE="${1:-}"
TEST_IMAGE="${TEST_IMAGE:-$HOME/.claude/uploads/825e909c-a32a-4c05-a27e-7fd41a005c37/99bb697a-image.png}"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
APP_GROUP="group.com.johannesemmrich.SmartCart"
PAYLOAD_KEY="pendingShareExtensionReceipt"
BACKUP_FLAG="smartcart.preCloudBackupDone.v2"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR" || exit 1

# --- Simulator bestimmen: übergebene UDID, sonst ein laufender iPhone 17 ---
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available | grep "iPhone 17 (" | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')
fi
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')
  echo "→ Kein laufender iPhone 17 — starte $DEVICE"
  xcrun simctl boot "$DEVICE" 2>/dev/null
  sleep 15
fi
echo "→ Simulator: $DEVICE"

# --- Testbild in die Fotos-Bibliothek ---
if [ ! -f "$TEST_IMAGE" ]; then
  echo "FEHLER: Testbild nicht gefunden: $TEST_IMAGE" >&2
  exit 1
fi
xcrun simctl addmedia "$DEVICE" "$TEST_IMAGE" && echo "→ Testbild importiert: $(basename "$TEST_IMAGE")"

# --- App-Gruppen-Ablage finden ---
# WICHTIG: Nicht `defaults` benutzen. Das schreibt und liest die globale Sicht unter
# data/Library/Preferences — die App-Gruppe der Sandbox ist eine ANDERE Datei unter
# Containers/Shared/AppGroup/<GUID>/. Am 20.09.2026 nachgemessen; ein `defaults`-Wert kam in
# der App-Gruppe nie an.
GROUP_PLIST=$(find "$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE/data/Containers/Shared/AppGroup" \
  -name "$APP_GROUP.plist" 2>/dev/null | head -1)

if [ -n "$GROUP_PLIST" ]; then
  echo "→ App-Gruppe: $GROUP_PLIST"
  # Alte Nutzlast entfernen, damit ein Treffer nachher wirklich aus DIESEM Lauf stammt.
  /usr/libexec/PlistBuddy -c "Delete :$PAYLOAD_KEY" "$GROUP_PLIST" >/dev/null 2>&1 \
    && echo "→ Alte Nutzlast entfernt"
  # Dasselbe fürs Sicherungsflag. Ohne diesen Schnitt ist ein späteres "gesetzt: ja" wertlos:
  # Es könnte genauso gut von der Haupt-App aus einem früheren Lauf stammen — oder von einem
  # Erweiterungslauf VOR dem Fix, der das Fenster verbraucht hat. Nur ein vorher gelöschtes
  # Flag macht die Aussage "wer hat es gesetzt?" überhaupt belastbar.
  # Nebenwirkung, gewollt und harmlos: Die Haupt-App legt beim nächsten Start noch einmal eine
  # Sicherungskopie der Store-Dateien unter PreCloudBackup an — reine Kopie, kein Datenverlust.
  /usr/libexec/PlistBuddy -c "Delete :$BACKUP_FLAG" "$GROUP_PLIST" >/dev/null 2>&1 \
    && echo "→ Sicherungsflag zurückgesetzt"
  # Der Einstellungs-Dienst hält Werte im Speicher — ohne Neustart läse die Erweiterung
  # womöglich noch den alten Stand.
  #
  # 20.09.2026, F004: Hier stand `killall -9 cfprefsd`. Das existiert im Simulator NICHT
  # ("An error was encountered processing the command ... No such file or directory"), der
  # Fehler wurde von `>/dev/null 2>&1` verschluckt, und cfprefsd lief unverändert weiter
  # (PID 42170 über mehrere Läufe hinweg gemessen). Folge: Das oben per PlistBuddy AN cfprefsd
  # VORBEI gelöschte Flag lebte in dessen Speicher weiter und wurde beim nächsten Schreibzugriff
  # auf die Domain (die Erweiterung legt ihre Nutzlast ab) wieder mit in die Datei geflusht —
  # es sah aus, als hätte der Lauf das Flag gesetzt. Hintergrund: Defaults werden seit OS X 10.8
  # in cfprefsd im Speicher gehalten und verzögert geschrieben; direktes Editieren der plist wird
  # überschrieben (https://stackoverflow.com/q/19234665), Abhilfe ist ein Neustart von cfprefsd
  # (https://stackoverflow.com/q/19303958). Der im Simulator funktionierende Weg ist `launchctl kill`.
  if ! xcrun simctl spawn "$DEVICE" launchctl kill 9 system/com.apple.cfprefsd.xpc.daemon 2>/dev/null; then
    echo "WARNUNG: cfprefsd konnte nicht neu gestartet werden — Flag-Messung unten ist dann nicht belastbar." >&2
  fi
  sleep 2
else
  echo "→ App-Gruppe noch nicht angelegt (Erweiterung lief auf diesem Simulator noch nie)"
fi

# Vorher-Zustand ausdrücklich protokollieren — er ist die halbe Aussage des Ergebnisblocks.
BACKUP_BEFORE="nicht gesetzt (zurückgesetzt)"
if [ -n "$GROUP_PLIST" ] && /usr/libexec/PlistBuddy -c "Print :$BACKUP_FLAG" "$GROUP_PLIST" >/dev/null 2>&1; then
  BACKUP_BEFORE="GESETZT (Zurücksetzen fehlgeschlagen — ein 'ja' unten ist dann nicht aussagekräftig)"
fi
echo "→ Sicherungsflag vor dem Lauf: $BACKUP_BEFORE"

# Zweite, härtere Spur als das bloße Flag: `backupLocalStoreBeforeFirstCloudAttempt()` legt
# beim Sichern Kopien der Store-Dateien unter PreCloudBackup ab. Ein gesetztes Flag OHNE frische
# Dateien dort bedeutet: Es hat keine Sicherung gegeben, das Flag kam von woanders her.
GROUP_DIR=$(dirname "$(dirname "$GROUP_PLIST")" 2>/dev/null)
BACKUP_DIR="$GROUP_DIR/Library/Application Support/PreCloudBackup"
BACKUP_FILES_BEFORE=0
[ -d "$BACKUP_DIR" ] && BACKUP_FILES_BEFORE=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l | tr -d ' ')
echo "→ Sicherungskopien vor dem Lauf: $BACKUP_FILES_BEFORE Datei(en)"

# Startzeitpunkt für die Prozessmessung unten (welche Prozesse laufen während des Tests?).
LOG_START=$(date '+%Y-%m-%d %H:%M:%S')

# --- Bekannten Ausgangszustand der Oberfläche herstellen ---
# Zwei von fünf Läufen am 20.09.2026 scheiterten nicht am Produktivcode, sondern an einem
# Systemdialog, der aus einem früheren Lauf noch über allem lag („«Restock» möchte dir
# Mitteilungen senden" — die Erweiterung fragt das in ShareViewController.swift:220). Die
# Fotos-App war dann unbedienbar und der Testrunner startete neu.
#
# Von außen vorab erlauben lässt sich das nicht: `xcrun simctl privacy` kennt in Xcode 27 nur
# calendar, contacts(-limited), location(-always), photos(-add), media-library, microphone,
# motion, reminders, siri und all — KEIN `notifications` (Beleg: `xcrun simctl privacy` ohne
# Argumente). Also stattdessen aufräumen: Beteiligte Apps beenden und SpringBoard neu starten,
# das räumt stehengebliebene Dialoge weg. Den Dialog dieses Laufs klickt der Test selbst weg
# (`dismissSystemAlerts()`), sodass er nicht für den nächsten liegen bleibt.
xcrun simctl terminate "$DEVICE" com.apple.mobileslideshow >/dev/null 2>&1
xcrun simctl terminate "$DEVICE" com.johannesemmrich.Restock >/dev/null 2>&1
xcrun simctl spawn "$DEVICE" launchctl kickstart -k system/com.apple.SpringBoard >/dev/null 2>&1 \
  && echo "→ SpringBoard neu gestartet (stehengebliebene Systemdialoge entfernt)"
sleep 8

# --- Absturzberichte VOR dem Lauf festhalten ---
BEFORE=$(ls "$CRASH_DIR" 2>/dev/null | grep -c "^RestockShareExtension-")
echo "→ Absturzberichte der Erweiterung vor dem Lauf: $BEFORE"

# --- Testlauf ---
echo "→ Starte UI-Test …"
# `TEST_RUNNER_RESTOCK_SHARE_E2E` ist das Signal an den Test, dass die Vorbereitung oben
# gelaufen ist. xcodebuild reicht jede Variable mit dem Präfix `TEST_RUNNER_` an den
# Testprozess durch und streift das Präfix ab. Ohne dieses Signal überspringt sich der Test —
# so meldet die CI, die das ganze Target ohne dieses Skript startet, nicht falsch rot.
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TEST_RUNNER_RESTOCK_SHARE_E2E=1 \
xcodebuild test \
  -scheme Restock \
  -project Restock.xcodeproj \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -only-testing:RestockUITests/ReceiptShareExtensionTests \
  2>&1
TEST_STATUS=$?

# --- Auswertung ---
sleep 5   # der Berichtsschreiber des Systems hängt dem Absturz ein paar Sekunden hinterher

AFTER=$(ls "$CRASH_DIR" 2>/dev/null | grep -c "^RestockShareExtension-")
NEW_CRASHES=$((AFTER - BEFORE))

# Die App-Gruppe kann erst durch diesen Lauf entstanden sein — daher hier erneut suchen.
GROUP_PLIST=$(find "$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE/data/Containers/Shared/AppGroup" \
  -name "$APP_GROUP.plist" 2>/dev/null | head -1)

PAYLOAD="nein"
BACKUP_CONSUMED="nein"
if [ -n "$GROUP_PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Print :$PAYLOAD_KEY" "$GROUP_PLIST" >/dev/null 2>&1 && PAYLOAD="ja"
  /usr/libexec/PlistBuddy -c "Print :$BACKUP_FLAG" "$GROUP_PLIST" >/dev/null 2>&1 && BACKUP_CONSUMED="ja"
fi

# --- Gemessen statt unterstellt: Sicherungskopien und beteiligte Prozesse ---
GROUP_DIR=$(dirname "$(dirname "$GROUP_PLIST")" 2>/dev/null)
BACKUP_DIR="$GROUP_DIR/Library/Application Support/PreCloudBackup"
BACKUP_FILES_AFTER=0
BACKUP_NEWEST="—"
if [ -d "$BACKUP_DIR" ]; then
  BACKUP_FILES_AFTER=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l | tr -d ' ')
  NEWEST=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -1)
  [ -n "$NEWEST" ] && BACKUP_NEWEST="$NEWEST ($(stat -f '%Sm' -t '%H:%M:%S' "$BACKUP_DIR/$NEWEST" 2>/dev/null))"
fi

# Welche Prozesse waren im Lauf überhaupt aktiv? Der Filter erfasst ausdrücklich AUCH das
# Widget (`SmartCartWidgets` enthält kein "Restock" — ein Filter auf "Restock" übersieht es).
PROCESSES=$(xcrun simctl spawn "$DEVICE" log show --start "$LOG_START" --style compact \
  --predicate 'process CONTAINS[c] "Restock" OR process CONTAINS[c] "SmartCart"' 2>/dev/null \
  | awk 'NR>1 {print $4}' | sed 's/\[.*//' | grep -v '^$' | sort -u | tr '\n' ' ')
[ -z "$PROCESSES" ] && PROCESSES="(keine erfasst)"

echo ""
echo "=================== ERGEBNIS ==================="
echo "Testlauf-Status:              $TEST_STATUS (0 = Ablauf hergestellt)"
echo "Bon-Nutzlast in App-Gruppe:   $PAYLOAD   (muss nach dem Fix: ja)"
echo "Neue Absturzberichte:         $NEW_CRASHES   (muss nach dem Fix: 0)"
echo "Sicherungsflag vor dem Lauf:  $BACKUP_BEFORE"
echo "Sicherungsflag nach dem Lauf: $BACKUP_CONSUMED   (nur die App darf es verbrauchen)"
echo "Sicherungskopien vor/nach:    $BACKUP_FILES_BEFORE / $BACKUP_FILES_AFTER Datei(en), neueste: $BACKUP_NEWEST"
echo "Prozesse im Lauf (gemessen):  $PROCESSES"
# Kein Ursachensatz mehr an dieser Stelle. Die frühere Zeile behauptete, die Haupt-App habe
# das Flag gesetzt — gemessen (F004, 20.09.2026) lief sie in keinem einzigen Lauf. Was das
# Skript belegen kann, ist genau das, was oben steht: Flag vorher/nachher, Sicherungsdateien,
# beteiligte Prozesse. Die Deutung bleibt dem Leser.
if [ "$BACKUP_CONSUMED" = "ja" ] && [ "$BACKUP_FILES_AFTER" -le "$BACKUP_FILES_BEFORE" ]; then
  echo "  ! Flag gesetzt, aber KEINE neuen Sicherungsdateien — dann hat kein Prozess gesichert."
  echo "    Häufigste Ursache: cfprefsd hat einen alten, zwischengespeicherten Wert"
  echo "    zurückgeschrieben (siehe Kommentar oben am cfprefsd-Neustart)."
fi
if [ "$NEW_CRASHES" -gt 0 ]; then
  echo "Neueste Berichte:"
  ls -t "$CRASH_DIR" | grep "^RestockShareExtension-" | head -"$NEW_CRASHES" | sed 's/^/  /'
fi
echo "================================================"

# Bestanden heißt: Nutzlast angekommen UND kein neuer Absturzbericht.
if [ "$PAYLOAD" = "ja" ] && [ "$NEW_CRASHES" -eq 0 ]; then
  echo "GRÜN — der Bon ist ohne Absturz in der App angekommen."
  exit 0
fi
echo "ROT — siehe Ergebnisblock oben."
exit 1
