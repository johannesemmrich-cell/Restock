---
spec_file: docs/specs/views/offer-codes-einloesen.md
spec_sha256: e0119ebaf75eafd76bddba5a7fe1db1307f40cd9a8bc90479cc2fd31f4f87e6d
spec_frozen_sha256: 0b1cc7c0960b474fdd8469bf61db4dd16b2ee09911ade1e9be23c866aef9b71a
---

# PO-Briefing: feat-259-d2-promo-rueckbau

- **Spec:** docs/specs/views/offer-codes-einloesen.md
- **Issue:** #259
- **Erstellt:** 2026-11-05

## Was gebaut wird

Der selbstgebaute Promo-Code-Zugang wird komplett aus der App entfernt; kostenlos freischalten geht nur noch über Apple-Codes.

## Definition of Done

In Einstellungen und Paywall gibt es kein Promo-Code-Feld mehr, die App baut fehlerfrei, alle Tests sind grün, der Apple-Einstieg funktioniert unverändert.

## Wie geprüft wird

Suchläufe, Bauvorgänge und bestehende Tests belegen die restlose Entfernung; echte Code-Einlösung bei Apple und Test auf Hennings Geräten gehören nicht dazu.

## Kritische Anmerkungen

- Bereits eingelöste Promo-Codes verlieren die Freischaltung; wie viele Personen betroffen sind, wurde nicht abgefragt (Annahme: wenige).
- Apple-Codes sind in App Store Connect noch nicht angelegt; bis dahin hat niemand einen kostenlosen Zugang.
- Die Datenschutzseite des Dritten nennt Promo-Codes weiter, bis er sie ändert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
