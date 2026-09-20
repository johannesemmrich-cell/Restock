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
  # Der Einstellungs-Dienst hält Werte im Speicher — ohne Neustart läse die Erweiterung
  # womöglich noch den alten Stand.
  xcrun simctl spawn "$DEVICE" killall -9 cfprefsd >/dev/null 2>&1
else
  echo "→ App-Gruppe noch nicht angelegt (Erweiterung lief auf diesem Simulator noch nie)"
fi

# --- Absturzberichte VOR dem Lauf festhalten ---
BEFORE=$(ls "$CRASH_DIR" 2>/dev/null | grep -c "^RestockShareExtension-")
echo "→ Absturzberichte der Erweiterung vor dem Lauf: $BEFORE"

# --- Testlauf ---
echo "→ Starte UI-Test …"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
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

echo ""
echo "=================== ERGEBNIS ==================="
echo "Testlauf-Status:              $TEST_STATUS (0 = Ablauf hergestellt)"
echo "Bon-Nutzlast in App-Gruppe:   $PAYLOAD   (muss nach dem Fix: ja)"
echo "Neue Absturzberichte:         $NEW_CRASHES   (muss nach dem Fix: 0)"
echo "Sicherungsflag gesetzt:       $BACKUP_CONSUMED   (nur die App darf es verbrauchen)"
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
