---
spec_file: docs/specs/ui-tests/test-98-durchgang-6-laden-einrichtung.md
spec_sha256: c0de5da1951a5a91fb52ce0f6944352a8c9330d7ce1b17217a11ff51bd2fa5c1
---

# PO-Briefing: test-98-durchgang-6-laden-einrichtung

- **Spec:** docs/specs/ui-tests/test-98-durchgang-6-laden-einrichtung.md
- **Issue:** #98
- **Erstellt:** 2026-10-12

## Was gebaut wird

Automatische Tests bedienen die Laden-Einrichtung wie ein Nutzer: ausblenden, löschen, hinzufügen, Häufigkeit ändern, Reihenfolge ziehen.

## Definition of Done

Alle sieben neuen Abläufe laufen dreimal hintereinander grün, einmal unter Last, und bestehende Tests bleiben grün.

## Wie geprüft wird

Tests prüfen Startseite und App-Neustart nach jeder Aktion; ungeprüft bleiben geteiltes Löschen, Emoji-Eingabe und Farbwahl.

## Kritische Anmerkungen

- Löschtest vernichtet Daten; Schutz nur durch Test-Simulator und gesäte Läden, keine technische Sperre.
- Zeilenschalter-Test ist bedingt: Ob er prüfbar ist, zeigt sich erst beim Bauen, sonst entfällt er.
- Startreihenfolge ist zufällig, daher wird nur die Umkehrung geprüft; Ziehen unter Last nur viermal vollständig gemessen.

## Freigabe-Frage

Gibst du die Tests frei, obwohl Emoji-Eingabe, Farbwahl und Löschen geteilter Läden ungeprüft bleiben?
