---
spec_file: docs/specs/ui-tests/test-145-durchgang-3-app-intents.md
spec_sha256: 797ab2751ace7695d9908a159bd537a2c7fb32024593872831a134e05e580e46
spec_frozen_sha256: 7152a7f090ac6fb344c1f3dcc9e7cd15b1606651de6b1d4065e7c467ce336a40
---

# PO-Briefing: test-145-d3-app-intents-testing

- **Spec:** docs/specs/ui-tests/test-145-durchgang-3-app-intents.md
- **Issue:** #145
- **Erstellt:** 2026-10-16

## Was gebaut wird

Automatische Tests prüfen im Simulator, dass Siri-Hinzufügen und Abhaken über den echten Systemweg wirken.

## Definition of Done

Drei Tests laufen in drei Läufen hintereinander grün, einer unter Rechnerlast; die App selbst bleibt unverändert.

## Wie geprüft wird

Geprüft wird die sichtbare Wirkung in der App, nicht Siri-Stimme, Widget-Tipp, Dialogtext oder dein Gerät.

## Kritische Anmerkungen

- Läuft nur lokal; die CI überspringt die Tests, künftige Änderungen werden nicht automatisch geprüft.
- Abhaken ohne laufende Live Activity meldet Erfolg, bewirkt aber nichts; nur dokumentiert, nicht behoben.
- Fehler 400 unter Last wird nur wiederholt abgefangen, Ursache ungeklärt; Tests könnten sporadisch rot werden.

## Freigabe-Frage

Reicht dir ein lokaler Nachweis ohne CI und ohne Siri-Stimme, bei dokumentiertem stillem Erfolg beim Abhaken?
