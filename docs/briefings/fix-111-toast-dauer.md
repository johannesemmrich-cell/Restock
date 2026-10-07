---
spec_file: docs/specs/ui-tests/test-111-durchgang-2-toast-dauer.md
spec_sha256: 8e9ec0b33145ebfd5cd9a192ba4f6d4ae8476cc4f8927b7381b7d18e47293600
---

# PO-Briefing: fix-111-toast-dauer

- **Spec:** docs/specs/ui-tests/test-111-durchgang-2-toast-dauer.md
- **Issue:** #111
- **Erstellt:** 2026-10-07

## Was gebaut wird

Drei Toast-Tests bestehen auf dem Prüfserver verlässlicher, weil der Toast nur in Testläufen länger steht.

## Definition of Done

Gesamte Testsuite grün, 30 Serverwiederholungen der Toast-Tests ohne Fehler, und der Toast steht für Nutzer weiterhin etwa 6 Sekunden.

## Wie geprüft wird

Tests belegen die verlängerte Testdauer und mindestens 2 Sekunden ohne Verlängerung; die genaue 6-Sekunden-Frist prüft nur ein einmaliger Durchlauf.

## Kritische Anmerkungen

- #111 bleibt offen: Fehler durch Zeitgrenze der Testumgebung selbst (31 s) bleiben bestehen.
- Zeigt der Vorher-Lauf 0 Fehler, ist die Wirkung des Fixes nicht beweisbar.
- Statt einer Frist werden drei Toast-Fristen geändert; nicht verlangt, aber zur Zielerreichung nötig.

## Freigabe-Frage

Genügt dir ein Teilerfolg für #111, der Toast-Fehler behebt, aber andere sporadische Fehler offen lässt?
