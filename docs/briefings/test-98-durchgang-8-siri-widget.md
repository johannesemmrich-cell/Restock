---
spec_file: docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md
spec_sha256: b143eee28cdcb6802cb954f71d65b8db4514c6b2bb13622de332b5d34575e5c7
---

# PO-Briefing: test-98-durchgang-8-siri-widget

- **Spec:** docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md
- **Issue:** #98
- **Erstellt:** 2026-10-14

## Was gebaut wird

Siri-Artikel anlegen, Abhaken per Widget oder Insel und der Schnell-hinzufügen-Knopf bekommen automatische Tests.

## Definition of Done

Neue Tests laufen dreimal grün, bestehende bleiben grün, und ein Simulator-Durchlauf zeigt abgehakten Artikel sowie fokussiertes Eingabefeld.

## Wie geprüft wird

Tests prüfen die Logik hinter den Abläufen direkt; echter Siri-Ruf, Widget-Tipp und Gerätetests werden nicht nachgewiesen.

## Kritische Anmerkungen

- Siri-Ruf sowie Widget-, Insel- und Knopf-Tipp bleiben ungeprüft; "Siri/Widget getestet" wäre zu viel gesagt.
- Abhak-Logik wird für Tests umgebaut und zusammengelegt: Risiko im Produktcode, Umfang über Limits (PO-Ausnahme).
- Siri legt doppelte Artikel ohne Mengenvorschlag an; wird nur festgehalten, nicht geändert.

## Freigabe-Frage

Gibst du frei, obwohl nur die Logik geprüft wird und kein echter Siri- oder Widget-Tipp?
