---
spec_file: docs/specs/ui-tests/test-145-durchgang-3-app-intents.md
spec_sha256: 41945131ab157c23a977724e115301d9c567d598d5f5b773aee09f31ba4ee599
spec_frozen_sha256: 84e67297409c349aa9f9ab82c5de507c251123dc264c3995cc12016245c6b465
---

# PO-Briefing: test-145-d3-app-intents-testing

- **Spec:** docs/specs/ui-tests/test-145-durchgang-3-app-intents.md
- **Issue:** #145
- **Erstellt:** 2026-10-16

## Was gebaut wird

Siri-Befehle zum Hinzufügen und Abhaken werden auf einem Test-Simulator über den echten Systemweg automatisch geprüft.

## Definition of Done

Drei Tests laufen dreimal hintereinander grün, einmal unter Rechnerlast; bestehende Tests bleiben grün, die App bleibt unverändert.

## Wie geprüft wird

Die Tests lösen die Befehle über das System aus und prüfen das Ergebnis in der App, nicht Siri-Stimme oder Widget.

## Kritische Anmerkungen

- Läuft nur lokal, nicht in der CI; spätere Rückschritte fallen nicht automatisch auf.
- Abhaken meldet Erfolg ohne Wirkung, wenn die Liste geschlossen ist; bewusst nicht behoben.
- Sprechtext der Antwort ist nicht prüfbar.

## Freigabe-Frage

Reicht dir ein lokaler Nachweis ohne Siri-Stimme und CI, bei offen bleibendem Abhak-Verhalten?
