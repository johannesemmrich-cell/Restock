---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 4d8d5aeded2077bf4a4776547155b480330e80360397773b8802699e5923bc8c
---

# PO-Briefing: fix-37-receipt-name-preselect

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #37
- **Erstellt:** 2026-09-24

## Was gebaut wird

Bon-Prüf-Karten zeigen den bereits eingetragenen Artikelnamen künftig immer als vorausgewählte Auswahlzeile, auch ohne passenden Listentreffer.

## Definition of Done

Trifft keiner der drei angezeigten Vorschläge den aktuellen Namen, erscheint dieser zusätzlich als angehakte vierte Auswahlzeile.

## Wie geprüft wird

Automatisierte Tests decken den beschriebenen Fall ab; der Randfall mit nur ein oder zwei Treffern bleibt laut Spec ausdrücklich ungetestet.

## Kritische Anmerkungen

- Randfall mit nur ein oder zwei vorhandenen Treffern ist in der Spec als ungelöst markiert, kein Test.

## Freigabe-Frage

Reicht die Spec-Korrektur so aus, oder soll der ungetestete Randfall mit ein bis zwei Treffern vor Freigabe zusätzlich abgesichert werden?
