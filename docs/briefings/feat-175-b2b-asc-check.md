---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: d7258434064bfce68e7e54f155cf890b513eaf2c8f1b9bb31a3baebfa6ed1b6d
spec_frozen_sha256: c869784a61857ae8e4caecaf49fd4888474be2481e7aa5b3ef53294ddf092a65
---

# PO-Briefing: feat-175-b2b-asc-check

- **Spec:** docs/specs/appstore/app-store-auftritt.md
- **Issue:** #175
- **Erstellt:** 2026-10-25

## Was gebaut wird

Ein Prüfwerkzeug liest App Store Connect nur lesend aus und meldet, ob alle Pflichtangaben für Version 1.0 stimmen.

## Definition of Done

CI-Tests laufen grün; bei falschen Beispieldaten meldet das Werkzeug Feld, Soll und Ist.

## Wie geprüft wird

Tests mit Schein-Antworten belegen Zaun und Abschnitte, nicht aber, dass Apples echte Schnittstelle genauso antwortet.

## Kritische Anmerkungen

- Datenschutzseite online ist noch falsch; dieser Prüfpunkt bleibt rot, bis jemand mit Domain-Zugriff sie berichtigt.
- Kauf-Prüfungen nur gegen Schein-Antworten getestet; echte Pfade zeigen sich erst im ersten Lauf (B3).
- Datenschutz-Fragebogen nicht per Schnittstelle lesbar, bleibt manueller Beleg.

## Freigabe-Frage

Gibst du das Prüfwerkzeug (460 statt 250 Zeilen) frei, obwohl die Datenschutzseite noch falsch und Kauf-Pfade ungeprüft sind?
