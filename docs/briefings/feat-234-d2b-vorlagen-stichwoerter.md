---
spec_file: docs/specs/views/station-templates-keywords.md
spec_sha256: 30c49abd008005477d7ef256862bd434132350093972f6cb5cfc2c8bdf79b017
spec_frozen_sha256: 08d8f08322da066c0f8663fec31f45d58d84b102134680a99d50d3629446a139
---

# PO-Briefing: feat-234-d2b-vorlagen-stichwoerter

- **Spec:** docs/specs/views/station-templates-keywords.md
- **Issue:** #234
- **Erstellt:** 2026-11-01

## Was gebaut wird

Ein Laden bekommt vier Mustervorlagen mit Hinweis "Vorschlag, bitte prüfen", bearbeitbare Stichwörter je Gang und korrekte Einzahl.

## Definition of Done

Im Simulator lassen sich alle fünf Vorlagen wählen, Stichwörter hinzufügen und löschen, und Artikel wechseln sofort den Gang.

## Wie geprüft wird

Unit- und Oberflächentests prüfen Vorlagen, Stichwort-Regeln und Umsortierung; echte Geräte, englische Oberfläche und große Schrift bleiben ungeprüft.

## Kritische Anmerkungen

- Umfang rund 600 statt der zugesagten 540 Zeilen; Spec erlaubt bis 700, dann hält die Umsetzung an.
- Neu und nicht verlangt: Rückfrage "Vorhandene Gänge ersetzen?" vor dem Ersetzen, plus eigener vierter CI-Testteil.
- Vorlagen-Inhalte sind abgeleitet, nicht gemessen; Stichwortlisten wurden gegenüber der Vorschau um wenige Wörter ergänzt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
