---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: b6a3eac7cbef76f29c298fe6d76d5cc0d8fa8fd67fed1e959f5ab04599581d1f
---

# PO-Briefing: feat-23-receipt-review-screen

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #23
- **Erstellt:** 2026-09-23

## Was gebaut wird

Jede Bon-Position wird eine Karte mit lesbarem Bontext, wählbarem Namen und änderbarem Preis/Menge.

## Definition of Done

Jede Position zeigt vollständigen Bontext und gewählten Namen; Antippen wechselt Namen, Preis oder Menge sichtbar, ohne Abschneiden oder Umbruch-Fehler.

## Wie geprüft wird

Automatisierte Tests prüfen Anzeige, Auswahl und Preisberechnung je Kriterium; sie belegen nicht, ob vorgeschlagene Namen inhaltlich passen.

## Kritische Anmerkungen

- Bei manchen Zeilen ist laut Spec keine Auswahl vorausgewählt (Name ohne Treffer) — Entscheidung steht noch aus.
- Kernbeschwerde der Anfrage — unpassende Vorschläge — bleibt; nur Anzahl wird begrenzt, Qualität folgt erst später (Issue #29).
- Umfang liegt deutlich über dem üblichen Limit (rund 720 statt 250 Zeilen); laut Spec vom PO akzeptiert.

## Freigabe-Frage

Reicht dir die Karten-Auswahl trotz offener Vorauswahl-Lücke und weiterhin unpassenden Vorschlägen bis Issue #29?
