---
spec_file: docs/specs/views/offer-codes-einloesen.md
spec_sha256: cafcc70bff503832b9de40c9ab69d77d4c3f9587dfecb5a960ee6c3160a004cb
spec_frozen_sha256: a4ed3f27fc8610a493f62fd78b83856db371f536d194d307a977e27870ab8c12
---

# PO-Briefing: feat-259-offer-codes

- **Spec:** docs/specs/views/offer-codes-einloesen.md
- **Issue:** #259
- **Erstellt:** 2026-11-05

## Was gebaut wird

Nutzer können in Einstellungen und Paywall einen Apple-Offer-Code einlösen und Restock Pro kostenlos freischalten; der alte Promo-Pool entfällt.

## Definition of Done

Einstellungen und Paywall zeigen „Code einlösen“, ein Tipp öffnet das Apple-Fenster, und der alte Promo-Code-Pool ist vollständig verschwunden.

## Wie geprüft wird

Tests prüfen Einstiege und Freischaltung über den Ersatz-Store; ob ein echter Code beim App Store einlösbar ist, wird nicht geprüft.

## Kritische Anmerkungen

- AC-7 gelockert: zwei zeitabhängige Unit-Tests (Zeitumstellung) dürfen rot sein; Code laut Spec unverändert gegenüber main.
- Ohne Angebote in App Store Connect bleibt der Einstieg wirkungslos; Anlegen steht nicht im Ticket.
- Bereits eingelöste Promo-Codes verlieren beim Rückbau die Freischaltung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
