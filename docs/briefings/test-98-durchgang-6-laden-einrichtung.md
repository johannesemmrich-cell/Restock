---
spec_file: docs/specs/ui-tests/test-98-durchgang-6-laden-einrichtung.md
spec_sha256: 050f54420ce0e8d9784489e7c7b4fd4dafecf6e222a2cf52b1445dacdb287593
---

# PO-Briefing: test-98-durchgang-6-laden-einrichtung

- **Spec:** docs/specs/ui-tests/test-98-durchgang-6-laden-einrichtung.md
- **Issue:** #98
- **Erstellt:** 2026-10-13

## Was gebaut wird

Automatische Tests prüfen, dass Nutzer Läden deaktivieren, löschen, hinzufügen, umsortieren und die Besuchshäufigkeit ändern können.

## Definition of Done

Alle acht Tests laufen dreimal hintereinander grün, einmal unter Last, die bisherigen Tests bleiben grün, und zwei behobene App-Fehler sind belegt.

## Wie geprüft wird

Acht Abläufe am Bildschirm, darunter Löschen mit Rückfrage und Reihenfolge nach hartem Neustart; nicht geprüft: geteilte Läden, Emoji, Farbwahl.

## Kritische Anmerkungen

- Mit Ihrem override: zwei App-Fehler mitbehoben (doppelter Laden, verlorene Reihenfolge), Testumfang über Limit.
- Löschen-Rückfrage hat auf dem iPhone keinen Abbrechen-Knopf; Abbrechen heißt außerhalb tippen.
- Ungeprüft: Teilen beenden, Emoji-Eingabe, Farbwähler, Tagesmitteilung, Siri/Widget; wiederholte Wischgeste könnte offene Zeile treffen (nie beobachtet).

## Freigabe-Frage

Geben Sie diese Tests samt den zwei mitbehobenen App-Fehlern und den genannten Lücken frei?
