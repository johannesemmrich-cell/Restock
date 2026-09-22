---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 783bcf35cfaa3d0f78b3c376cbf15ef9e788df60f1ddecf385b87f13f8e5265e
---

# PO-Briefing: feat-23-receipt-review-screen

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #23
- **Erstellt:** 2026-09-22

## Was gebaut wird

Jede Bon-Position wird eine Karte: Original-Bontext sichtbar, wählbarer Artikelname, änderbarer Preis und Menge statt bisheriger unlesbarer Zeile.

## Definition of Done

PO sieht pro Position eine Karte mit Bontext oben, einer Auswahlliste für den Namen und einer Preiszeile mit funktionierendem „Ändern"; alle Tests grün.

## Wie geprüft wird

Automatisierte Unit- und Bildschirmtests decken alle zwölf Anforderungen ab; das Dimmen abgewählter Karten wird dabei nicht geprüft, nur Zähler und Summe.

## Kritische Anmerkungen

- Testeinstieg (Issue #28) fehlt noch — Umsetzung startet nicht sofort nach Freigabe.
- „Nur passende" Vorschläge kommen erst später — bis dahin bleiben teils unpassende Vorschläge sichtbar.
- Umfang ist deutlich größer als üblich — von Ihnen am 22.9. bereits akzeptiert.

## Freigabe-Frage

Sind Karten-Aufbau, „nur passende Vorschläge später", und der Start erst nach der Testeinstieg-Vorarbeit so für Sie in Ordnung?
