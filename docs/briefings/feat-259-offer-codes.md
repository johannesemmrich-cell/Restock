---
spec_file: docs/specs/views/offer-codes-einloesen.md
spec_sha256: 72d37c5cdec2eb0da0058b8ce7e03cce1ab405afd30273610e5542e271399f26
spec_frozen_sha256: d931e80973f5a79e20387ab28828207937c254b5170e6c16727a1d683e4d6ba4
---

# PO-Briefing: feat-259-offer-codes

- **Spec:** docs/specs/views/offer-codes-einloesen.md
- **Issue:** #259
- **Erstellt:** 2026-11-05

## Was gebaut wird

Journalisten und Tester lösen Apple-Codes in Einstellungen und Paywall ein und erhalten Restock Pro; der eigene Promo-Code-Pool entfällt.

## Definition of Done

In Einstellungen und Paywall steht „Code einlösen“ und öffnet Apples Fenster; nirgends in der App gibt es noch Promo-Code-Eingabe oder -Texte.

## Wie geprüft wird

Tests zeigen, dass Einstiege sichtbar und stabil sind und ein Entitlement freischaltet; echte Einlösung gegen Apple wird nicht geprüft.

## Kritische Anmerkungen

- Durchgang 1 berührt sechs Dateien statt höchstens fünf; die Spec-Freigabe gilt als ausdrückliche Zustimmung.
- Ohne Offer Codes in App Store Connect bleibt der Einstieg wirkungslos; Anlegen erfolgt separat auf Hennings Wort.
- Bereits eingelöste Promo-Codes verlieren die Freischaltung; Issue-Text lag nur als Kontext-Dokument vor.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
