---
spec_file: docs/specs/models/learned-price-unit-and-quantity-source.md
spec_sha256: a9d5df30c0dc699d73d8195fb29cf84b0477cc74e397310df6b91c5b949a34b8
---

# PO-Briefing: fix-10-preis-einheit

- **Spec:** docs/specs/models/learned-price-unit-and-quantity-source.md
- **Issue:** #10
- **Erstellt:** 2026-09-26

## Was gebaut wird

Gelernte Bon-Preise merken sich künftig Stück oder Gramm, damit ein Gewichtspreis nicht mehr als Cent-Betrag erscheint.

## Definition of Done

Ein ohne Menge angelegter, pro Gramm gelernter Artikel zeigt keinen falschen Ein-Cent-Betrag mehr, sondern die übliche Schätzung.

## Wie geprüft wird

264 Rechen- und 22 Oberflächentests belegen den Cent-Fehler behoben; die noch fehlende sichtbare Mengen-Annahme prüfen sie nicht.

## Kritische Anmerkungen

- Mitgelieferter Code für die Mengen-Markierung liegt bereits vor, wirkt aber erst mit dem Folgeticket, ungetestet.
- Die sichtbare, korrigierbare Mengen-Annahme aus der Anfrage ist komplett ins nächste Ticket verschoben, nicht in dieser Lieferung.

## Freigabe-Frage

Reicht dir, dass nur der Cent-Fehler behoben wird und die sichtbare Mengen-Annahme komplett im nächsten Ticket folgt?
