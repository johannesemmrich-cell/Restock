---
spec_file: docs/specs/views/offer-codes-einloesen.md
spec_sha256: 6b54fc1402d2921054cb207412d6562a14de73f825f2136eedbbc18111f54edf
spec_frozen_sha256: c19c68b08c4bf65b0508fc9ae00d78db752446885c141890da542fc320314631
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
- Bereits eingelöste Promo-Codes verlieren die Freischaltung; Issue-Text nicht selbst gelesen, nur Kontext-Dokument.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
