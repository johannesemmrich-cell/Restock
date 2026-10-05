---
spec_file: docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md
spec_sha256: 56a19900e54eedd684d120b6ef7d722319d9240a987ebe09263916898ba1db5f
---

# PO-Briefing: test-98-durchgang-4-sync

- **Spec:** docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md
- **Issue:** #98
- **Erstellt:** 2026-10-05

## Was gebaut wird

Automatische Prüfung, wie zwei geteilte Einkaufslisten zusammenfinden, plus drei Nachschärfungen früherer Tests.

## Definition of Done

Neue Tests laufen grün und scheitern nachweislich bei absichtlich kaputt gemachter Regel; am Produkt ändert sich nichts.

## Wie geprüft wird

Tests prüfen das Zusammenführen ohne Internet; echtes Teilen mit zweitem iCloud-Konto, Einladung und Server-Rechte bleiben ungeprüft.

## Kritische Anmerkungen

- Umfang: 6 Dateien, ca. 230 Zeilen, über dem Dateilimit (4–5); bei Zeilenüberschreitung Rückmeldung.
- Offene Grenze: Teilen mit echtem zweiten Konto braucht zwei angemeldete Geräte; Simulator und CI können das nicht.
- Gleichstand beim Zeitstempel wird beim Senden und Empfangen unterschiedlich entschieden; nur festgehalten, nicht geändert.

## Freigabe-Frage

Gibst du diesen Durchgang mit sechs Dateien und rund 230 Zeilen frei?
