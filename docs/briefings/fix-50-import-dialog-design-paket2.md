---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 5cf7a0d2adde63e1a5d60e86bbacd14cfeb60a551bc173b8e686c511afc548cb
---

# PO-Briefing: fix-50-import-dialog-design-paket2

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #65 (Inhalt bereits freigegeben — hier nur eine Korrektur danach)
- **Erstellt:** 2026-09-28

## Was gebaut wird

Unverändert gegenüber der bereits freigegebenen Fassung: Bon-Text wird lesbarer, kopierbar, als eigene Auswahlzeile wählbar.

## Definition of Done

Unverändert: Bon-Text größer, kopierbar, erscheint als Auswahl ab vier Zeichen Abweichung vom gewählten Namen.

## Wie geprüft wird

Ein neuer Test verwies auf die falsche Zeilen-Position; jetzt korrekt auf die tatsächliche Reihenfolge der Auswahlzeilen ausgerichtet.

## Kritische Anmerkungen

- Reine Korrektur eines Test-internen Zeilen-Index (kein Verhalten, kein Umfang geändert) — keine neue PO-Entscheidung nötig.
- Inhalt und Umfang der Erweiterung selbst wurden hier nicht erneut geprüft (bereits freigegeben).

## Freigabe-Frage

Bestätigst du, dass diese reine Test-Index-Korrektur keine erneute inhaltliche Prüfung braucht und die vorherige Freigabe bestehen bleibt?
