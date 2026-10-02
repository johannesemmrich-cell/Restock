---
spec_file: docs/specs/services/receipt-resolution-stats.md
spec_sha256: b4c443c0e2693fa8a1ae56f403ece789f39c13b8b6fa95305945c2e4c048da8a
---

# PO-Briefing: bon-namenserkennung-regelwerk-14

- **Spec:** docs/specs/services/receipt-resolution-stats.md
- **Issue:** #14
- **Erstellt:** 2026-10-02

## Was gebaut wird

Ein Entwickler-Bildschirm „Bon-Auflösung“ zeigt, wie oft welche Namens-Stufe beim Bon-Speichern greift und wie oft du sie korrigierst.

## Definition of Done

Nach dem Speichern eines Bons zeigt der Bildschirm je Stufe Zeilenzahl, Geänderte und Abgewählte; Zurücksetzen funktioniert.

## Wie geprüft wird

Automatische Tests belegen Zählregeln und Bildschirm im Simulator; die KI-Stufe wird dort nicht gemessen.

## Kritische Anmerkungen

- Stufe „Nicht-Produkt“ bleibt immer 0; solche Zeilen landen unter Rohtext, dessen Zahl dadurch vermischt ist.
- Die KI-Stufe, Kern der Frage, ist nur auf deinem iPhone messbar, nicht im Simulator.
- Umfang 9 Dateien, rund 300 Zeilen: über dem Limit; bei Blockade Teilung in zwei Teile.

## Freigabe-Frage

Gibst du diese reine Messung frei, obwohl „Nicht-Produkt“ leer bleibt und der Umfang das Limit überschreitet?
