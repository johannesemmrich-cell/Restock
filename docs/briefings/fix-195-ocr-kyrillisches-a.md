---
spec_file: docs/specs/services/receipt-parser-cyrillic-tax-code.md
spec_sha256: 89dc93a0a6093b890a4c901844548438daf6b5fdcb1e69e2cb77fa641e5ecbb9
spec_frozen_sha256: 6fb8212e586167aa64b46f9d8bc6f912f3a66f31106092c9713939627c71914d
---

# PO-Briefing: fix-195-ocr-kyrillisches-a

- **Spec:** docs/specs/services/receipt-parser-cyrillic-tax-code.md
- **Issue:** #195
- **Erstellt:** 2026-10-21

## Was gebaut wird

Gescannte Bons verlieren auf iOS 27 keine Artikel mehr, obwohl die Texterkennung das Steuerkürzel mit kyrillischem Buchstaben liest.

## Definition of Done

Der Testbon liefert auf dem iOS-27-Simulator wieder 18 statt 15 Positionen samt Endsumme 68,69 Euro, alle bisherigen Tests bleiben grün.

## Wie geprüft wird

Neue Tests ohne Kamera belegen die Zeichenumwandlung und deren Grenzen; der Bon-Test im Simulator belegt das Ergebnis, ein echtes iPhone wird nicht geprüft.

## Kritische Anmerkungen

- Nichts auf echtem iPhone geprüft; Simulator-Ergebnis kann vom Gerät abweichen.
- Nur vier Buchstaben hinter dem Preis werden korrigiert; andere Fehllesungen der Texterkennung bleiben bestehen.
- Apple änderte die Erkennung still; weitere Verwechslungen fallen womöglich erst im Gebrauch auf.

## Freigabe-Frage

Soll dieser Bon-Fix, der kyrillische Steuerkürzel hinter dem Preis zurückwandelt, so umgesetzt werden?
