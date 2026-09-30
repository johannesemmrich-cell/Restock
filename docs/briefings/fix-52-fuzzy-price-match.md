---
spec_file: docs/specs/models/shopping-item-fuzzy-price-match.md
spec_sha256: 87f2ea5bbd621fa75dc1b1e8d4deb028be479483e9abb070b25e2835bd3ac7b8
---

# PO-Briefing: fix-52-fuzzy-price-match

- **Spec:** docs/specs/models/shopping-item-fuzzy-price-match.md
- **Issue:** #52
- **Erstellt:** 2026-09-30

## Was gebaut wird

Ein per Kassenbon gelernter Preis wird künftig auch bei kleinen Tipp- oder Erkennungsfehlern im Artikelnamen gefunden.

## Definition of Done

Beim Artikel „Seitan" erscheint der zuvor unter „Saitan" gelernte Preis automatisch, statt der groben Kategorie-Pauschale.

## Wie geprüft wird

Automatisierte Tests bestätigen den gemeldeten Fall und mehrere Verwechslungs-Beispiele; echte Nutzung im Bon-Import wird dabei nicht erneut geprüft.

## Kritische Anmerkungen

- Löst nur den Abgleich, behebt nicht die Ursache: Bon-Import lernt weiterhin unbestätigte OCR-Texte als Namen.
- Deckt nur sehr kleine Abweichungen ab (ein Buchstabe, Name mindestens 5 Zeichen) — größere Tippfehler bleiben unentdeckt.
- Alternative (a) wurde vom Entwickler gewählt, nicht vom PO — Issue nannte vier gleichwertige Optionen.

## Freigabe-Frage

Reicht der engere technische Abgleich (Alternative a), oder soll auch die Ursache im Bon-Import angegangen werden?
