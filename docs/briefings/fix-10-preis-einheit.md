---
spec_file: docs/specs/models/learned-price-unit-and-quantity-source.md
spec_sha256: f712b79773594198bc4bd7a5f2165c635a60918fbf678a6e841fc5bdb6ff4c65
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

264 Rechen- und 22 Oberflächentests laufen im gemeinsamen Lauf grün und belegen den Cent-Fehler behoben; die Mengen-Annahme prüfen sie nicht.

## Kritische Anmerkungen

- Der ursprünglich verlangte, sichtbare und korrigierbare Mengen-Vorschlag wird nicht geliefert, sondern folgt separat im nächsten Ticket.
- Dafür bereits eingebauter Anzeige-Code ist ungetestet und bleibt wirkungslos, bis das Folgeticket ihn aktiviert.
- Alle bisher gelernten Bon-Preise verschwinden einmalig aus der Anzeige, bis sie neu gelernt werden.

## Freigabe-Frage

Reicht dir weiterhin, dass nur der Cent-Fehler behoben ist und die sichtbare Mengen-Annahme komplett im nächsten Ticket folgt?
