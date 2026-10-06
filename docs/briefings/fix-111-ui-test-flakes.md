---
spec_file: docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md
spec_sha256: 35239b5552bc0c283fd98336ee67ad7bd6a499a73ebede774d26d67fc72e0b82
---

# PO-Briefing: fix-111-ui-test-flakes

- **Spec:** docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md
- **Issue:** #111
- **Erstellt:** 2026-10-06

## Was gebaut wird

Die Wartezeiten in fünf der sechs unzuverlässigen Oberflächentests werden so verbessert, dass sie auf langsamen Testrechnern nicht mehr zufällig scheitern.

## Definition of Done

Die gesamte Testsuite läuft lokal grün, und 30 Wiederholungen auf dem Testrechner der CI zeigen für die betroffenen Tests keinen einzigen Fehler.

## Wie geprüft wird

Kleine Hilfstests, ein lokaler Gesamtlauf und 30 Läufe auf dem Server; nicht bewiesen wird, dass alle sporadischen Fehler verschwunden sind.

## Kritische Anmerkungen

- Der Toast-Test, einer der sechs Fehlerfälle, bleibt ungelöst; Ticket #111 bleibt offen, „grün beim ersten Versuch“ ist noch nicht erreicht.
- Zeigt der Vergleichslauf vorher 0 Fehler, ist die Wirkung des Fixes nur eingeschränkt belegt.
- Sieben weitere Testdateien bleiben ungeprüft.

## Freigabe-Frage

Soll zuerst nur dieser Teil umgesetzt werden, obwohl der Toast-Fehler offen bleibt?
