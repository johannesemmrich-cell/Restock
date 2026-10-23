---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: fbe8b7aa15a4338c262398be326555011ad78e1f8779bd3f84e3c3f00758e9bb
spec_frozen_sha256: 0f7b528836c5c44e0be204d06a6712e2930976650191dae12e98adb330bdc9dd
---

# PO-Briefing: feat-175-app-store-auftritt

- **Spec:** docs/specs/appstore/app-store-auftritt.md
- **Issue:** #175
- **Erstellt:** 2026-10-23

## Was gebaut wird

Restock wird in App Store Connect vollständig ausgefüllt, damit ein Build ohne fehlende Pflichtangaben zur Prüfung einreichbar ist.

## Definition of Done

Das Prüfskript meldet für Version 1.0 keine fehlende Pflichtangabe; eingereicht wird nur auf dein ausdrückliches Wort.

## Wie geprüft wird

Automatische Tests prüfen Datenschutz-Angaben und Texte; die Einträge bei Apple werden nur gegengelesen, nicht von Apple abgenommen.

## Kritische Anmerkungen

- Nachgebessert: sechs statt fünf Datenarten, weil der Open-Prices-Beitrag Daten an Dritte schickt; Datenschutz-URL bleibt falsch, Zugang ungeklärt.
- Datenart-Einordnung ist Schlussfolgerung, Apple entscheidet im Review; Teil B2 ist mit etwa 520 Zeilen zu groß.
- Nur auf dein Wort: Upload von Build 37 und Einreichen.

## Freigabe-Frage

Gibst du die nachgebesserte Spec samt Store-Texten frei, obwohl die Datenschutz-URL noch ungeklärt ist?
