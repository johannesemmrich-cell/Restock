---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: d73da6007f3b9b40a2b6892ae9537dbc03d96e34664150aa7895d6c38c7ae633
spec_frozen_sha256: 8a3e1d67e127d0e0a0ead3574b604e96b06964324e1a44da832ea8869d882f37
---

# PO-Briefing: feat-175-app-store-auftritt

- **Spec:** docs/specs/appstore/app-store-auftritt.md
- **Issue:** #175
- **Erstellt:** 2026-10-23

## Was gebaut wird

Alle Pflichtangaben für den App Store werden ausgefüllt, sodass Restock zur Prüfung einreichbar ist.

## Definition of Done

Prüfskript meldet für Version 1.0 keine fehlende Pflichtangabe; eingereicht wird nur auf dein ausdrückliches Wort.

## Wie geprüft wird

Automatische Tests prüfen Datenschutz-Angaben und Texte; Angaben in App Store Connect werden nur gegengelesen, nicht von Apple abgenommen.

## Kritische Anmerkungen

- Datenschutz-URL: bestehende Seite ist falsch, Zugang zur Domain ungeklärt; ohne Berichtigung nicht einreichbar. Kaufprodukte: drei statt vier, wie beschlossen.
- Datentyp-Einordnung (Kaufverlauf, Kennung „nicht verknüpft“) ist Schlussfolgerung, Apple entscheidet im Review; Teil B2 ist mit ~520 Zeilen zu groß.
- Nur auf dein Wort: Upload Build 37, Einreichen. Store-Texte (de/en) stehen wörtlich in der Spec, Abschnitt „Texte“, zur Freigabe.

## Freigabe-Frage

Gibst du Spec und Store-Texte frei, obwohl die Datenschutz-URL noch ungeklärt ist?
