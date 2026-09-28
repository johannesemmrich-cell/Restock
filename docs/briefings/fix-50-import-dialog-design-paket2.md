---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 0e7ab1edd9953ad721d8511478109de7ddebdc4fb9736cce0fb9ca79372a1635
---

# PO-Briefing: fix-50-import-dialog-design-paket2

- **Spec:** docs/specs/views/receipt-review-card.md (Abschnitt „Nachtrag Issue #65, Paket 2")
- **Issue:** #65
- **Erstellt:** 2026-09-28

## Was gebaut wird

Der gedruckte Bon-Text wird auf jeder Prüf-Karte besser lesbar, kopierbar und als eigene wählbare Auswahlzeile verfügbar.

## Definition of Done

Der Bon-Text ist größer, per langem Druck kopierbar, und erscheint als antippbare Auswahl, wenn er vom gewählten Namen abweicht und mindestens vier Zeichen hat.

## Wie geprüft wird

Automatisierte Tests decken Kopieren, Auswahl-Verhalten und Unterdrückungsregel ab; die reine Schriftgrößen-/Farbänderung wird nur per Code-Review geprüft, nicht automatisiert.

## Kritische Anmerkungen

- Lesbarkeit (15pt/dunklere Farbe) hat keinen automatisierten Test — nur Code-Review, da UI-Tests Schriftgröße und Farbe technisch nicht prüfen.
- Mindestlänge „4 Zeichen" für die Unterdrückung ist eine Spec-Entscheidung; das Ticket nannte nur das Negativbeispiel „BTR", keine Zahl.

## Freigabe-Frage

Reicht dir Code-Review statt automatisiertem Test für die reine Lesbarkeits-Änderung, und ist die Vier-Zeichen-Grenze für die Bon-Zeile so akzeptabel?
