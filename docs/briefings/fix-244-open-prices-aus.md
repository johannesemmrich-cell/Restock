---
spec_file: docs/specs/services/open-prices-1-0-aus.md
spec_sha256: f309c0fc8bedd6692967a02e4d3f670bba9f4a28bc34148650b64b7a8b1ae9f9
spec_frozen_sha256: 5f2884e336caf75f6a91ecb81ae8180f98be4a4fc5713a3c172e7294948b61e2
---

# PO-Briefing: fix-244-open-prices-aus

- **Spec:** docs/specs/services/open-prices-1-0-aus.md
- **Issue:** #244
- **Erstellt:** 2026-11-01

## Was gebaut wird

Die Funktion „Open Prices“ verschwindet aus den Einstellungen und sendet auch bei früher eingeschaltetem Schalter keine Bonfotos mehr.

## Definition of Done

In den Einstellungen gibt es keinen Eintrag „Open Prices“, und ein gespeicherter Bon löst im Simulator keinerlei Upload aus.

## Wie geprüft wird

Automatische Tests belegen Sperre und fehlenden Eintrag; der Bon-Weg ohne Upload wird nur per manuellem Simulator-Durchlauf belegt, nichts auf Geräten.

## Kritische Anmerkungen

- Neuer Build 39, Notes und Antwort an Apple sind bewusst nicht enthalten, sondern folgen getrennt auf dein Wort.
- Datenschutztexte nennen Open Prices weiter; zu viel deklariert, aber zulässig. Gespeicherte Anmeldungen alter Tester bleiben ungenutzt bestehen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
