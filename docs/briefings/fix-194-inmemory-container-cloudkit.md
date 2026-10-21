---
spec_file: docs/specs/testing/inmemory-container-ohne-cloudkit.md
spec_sha256: ca3241c4885859277e2c0ba491934ef8b8116c3b8767ad9a1e1b3a9c6951b134
spec_frozen_sha256: e5f8a6c82c55802bea9c447a30b3d6925886aa56df3602a474ae9d11665f3856
---

# PO-Briefing: fix-194-inmemory-container-cloudkit

- **Spec:** docs/specs/testing/inmemory-container-ohne-cloudkit.md
- **Issue:** #194
- **Erstellt:** 2026-10-21

## Was gebaut wird

Die Test-Suite stürzt auf dem neuen iOS 27 nicht mehr ab, und künftige gleiche Fehler werden automatisch erkannt.

## Definition of Done

Die gesamte Test-Suite läuft auf iOS 27 im Simulator ohne Absturz durch; nur die bekannten Texterkennungs-Tests (#195) bleiben rot.

## Wie geprüft wird

Ein Lauf auf iOS 27 im Simulator und ein automatischer Strukturtest; die CI prüft nur iOS 26 und kann den Fehler nicht zeigen.

## Kritische Anmerkungen

- Den Absturz-Nachweis gibt es nur lokal; die CI bestätigt nichts.
- Sieben Dateien statt Richtwert fünf, aber fünf davon sind Einzeiler.
- Die Texterkennungs-Tests (#195) bleiben rot; „stabil" heißt nur: kein Absturz.

## Freigabe-Frage

Gibst du die Änderung frei, obwohl die Texterkennungs-Tests bis zur Lösung von #195 rot bleiben?
