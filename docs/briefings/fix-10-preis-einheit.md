---
spec_file: docs/specs/models/learned-price-unit-and-quantity-source.md
spec_sha256: c177bca4135b4c75f28021f6ac5c9041bf44ac09a4adecf44bb95bd0706cbb21
---

# PO-Briefing: fix-10-preis-einheit

- **Spec:** docs/specs/models/learned-price-unit-and-quantity-source.md
- **Issue:** #10
- **Erstellt:** 2026-09-26

## Was gebaut wird

Gelernte Preise merken künftig ihre Bezugsgröße; fehlende Mengen schätzt die App sichtbar als Annahme.

## Definition of Done

Der PO erkennt es daran, dass die Liste keinen falschen Cent-Betrag mehr zeigt, sondern eine Schätzung oder Rate.

## Wie geprüft wird

Automatisierte Tests prüfen Rechenregeln und Anzeige einzeln; sie beweisen nicht, dass Kaufhistorie oder Gerätesynchronisation korrekt bleiben.

## Kritische Anmerkungen

- Die im Ticket genannte falsche Kaufhistorie (706 g als 1 Stück) bleibt bestehen, Behebung folgt in einem späteren Ticket.
- Preisvergleich zwischen Läden — der Zweck laut Ticket — bleibt unerreicht: Gramm und Milliliter bleiben ununterscheidbar.
- Auf zwei Geräten geteilte Listen verlieren gelernte Preise auf dem anderen Gerät, ohne Hinweis.

## Freigabe-Frage

Sind der ungelöste Fehler in der Kaufhistorie und der fehlende Preisvergleich zwischen Läden für Sie akzeptabel?
