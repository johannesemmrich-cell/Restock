---
spec_file: docs/specs/views/station-picker-adoption.md
spec_sha256: 14882d2584bdafda937b62cea3de6ab004e73ce1b1367b45a43da3fae7b9fc56
spec_frozen_sha256: eab06ae2751c88e8b4ace507ac8927ef1fe35fa34d46546a0a75e6f0ff7f3785
---

# PO-Briefing: feat-234-d2b2-picker-uebernahme

- **Spec:** docs/specs/views/station-picker-adoption.md
- **Issue:** #234
- **Erstellt:** 2026-11-01

## Was gebaut wird

In der Kategorie-Auswahl lassen sich Gänge per Wischen umbenennen und löschen; frühere eigene Kategorien lassen sich als Gänge übernehmen.

## Definition of Done

Im Simulator lassen sich Gänge beim Artikel umbenennen und löschen, frühere Kategorien übernehmen, und Artikel landen danach im richtigen Gang.

## Wie geprüft wird

Automatische Rechen- und Bedienungstests belegen jedes Kriterium; nicht geprüft sind Hennings Geräte, echtes iCloud-Teilen und große Schrift.

## Kritische Anmerkungen

- Ungenutzte frühere Kategorien mit Vorlagennamen (z. B. „Backstation“) werden nicht zur Übernahme angeboten; Regel des Tech Leads.
- Gang löschen entfernt auch die gleichnamige eigene Kategorie; kein Rückgängig.
- Umfang etwa 525 Zeilen, über Richtwert; von Ihnen als ein Stück beschlossen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
