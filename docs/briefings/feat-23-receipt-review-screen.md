---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 3f62fa3f46bdd273451c4aa0dc6c5b2bd68a3200941efc61c1390326f8df491c
---

# PO-Briefing: feat-23-receipt-review-screen

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #23
- **Erstellt:** 2026-09-22

## Was gebaut wird

Jede erkannte Bon-Position wird eine Karte mit Original-Text, wählbarem Artikelnamen sowie änderbarem Preis und Menge.

## Definition of Done

Jede Position zeigt lesbar Bon-Text und gewählten Namen; Antippen ändert Namen, Preis oder Menge sofort sichtbar, ohne Abschneiden oder Umbruch-Fehler.

## Wie geprüft wird

Automatisierte Tests prüfen Anzeige, Auswahl-Logik und Preisberechnung; sie zeigen nicht, ob Vorschläge inhaltlich passen (folgt in Issue #29).

## Kritische Anmerkungen

- Kernbeschwerde aus dem Issue — unpassende Vorschläge — bleibt bestehen, nur Anzahl wird begrenzt; Qualität folgt erst in Issue #29.
- Umfang reißt das übliche Limit deutlich (ca. 720 statt 250 Codezeilen); PO hat das bereits akzeptiert.
- Mengenänderung (Stück/Gramm) ist eine Erweiterung über die ursprüngliche Meldung hinaus, vom PO nachträglich gewünscht.

## Freigabe-Frage

Reicht dir die Karten-Darstellung mit Auswahl statt Tippen, obwohl unpassende Vorschläge erst in einem Folge-Schritt behoben werden?
