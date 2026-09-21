---
spec_file: docs/specs/services/receipt-parser-quantity-confirmation.md
spec_sha256: 738c53a6d24f09442288d25d27255f86df65566870cc0443caef5dc0fb523679
---

# PO-Briefing: fix-9-rewe-quantity-weight

- **Spec:** docs/specs/services/receipt-parser-quantity-confirmation.md
- **Issue:** #9
- **Erstellt:** 2026-09-21

## Was gebaut wird

Der Bon-Scanner erkennt künftig Stückzahl und Gewicht korrekt, damit gelernte Preise stimmen.

## Definition of Done

Beim Scannen eines Rewe-Bons zeigt Restock für Brötchen und lose Ware die richtige Stückzahl bzw. das richtige Gewicht, und der gelernte Preis stimmt.

## Wie geprüft wird

Automatische Tests rechnen Bon-Beispiele durch bis zum gelernten Preis; ob alte falsche Preise sich korrigieren, prüfen sie nicht.

## Kritische Anmerkungen

- Bereits falsch gelernte Preise aus vergangenen Scans werden nicht rückwirkend korrigiert, nur künftige Scans lernen richtig.
- Zusatzfund: derselbe Fehler bei lose gewogener Ware im Lidl-Format wird gleich mitbehoben, war nicht angefragt.
- Brötchen erscheinen im Bon-Beleg künftig als Mehrfachposition (z. B. „4 × 0,39 €") statt als ein Gesamtbetrag.

## Freigabe-Frage

Reicht es, dass nur künftige Bon-Scans korrekt lernen, obwohl bereits falsch gelernte Preise unverändert bestehen bleiben?
