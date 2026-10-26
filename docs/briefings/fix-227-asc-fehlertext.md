---
spec_file: docs/specs/appstore/asc-fehlertext.md
spec_sha256: 98ad117fee771ae80943d30da0e8e9c8313fd5cc67bdcc3e3fcf960c0296dcbf
spec_frozen_sha256: bd450bbcac989f2cb584b5ae27c87a3d77c13496467f558a0cf8e31f43f794b7
---

# PO-Briefing: fix-227-asc-fehlertext

- **Spec:** docs/specs/appstore/asc-fehlertext.md
- **Issue:** #227
- **Erstellt:** 2026-10-26

## Was gebaut wird

Die App-Store-Werkzeuge nennen bei Fehlern künftig Apples Fehlercode und Titel, damit die Ursache des 409-Abbruchs sichtbar wird.

## Definition of Done

Bei einem Apple-Fehler erscheinen hinter Status und Pfad zusätzlich Code und Titel; Zugangsdaten und Detailtexte bleiben weiterhin unsichtbar.

## Wie geprüft wird

Automatische Tests mit nachgestellten Apple-Antworten prüfen Auslesen, Kürzen und Geheimnisschutz; eine echte Apple-Antwort wird dabei nicht getestet.

## Kritische Anmerkungen

- Das Antwortformat stützt sich nur auf Dokumentation; ob der 409-Grund wirklich erscheint, zeigt erst der nächste echte Lauf.
- Die Prüfung der Datenschutzseite zeigt weiterhin nur den Status, keinen Fehlertext.

## Freigabe-Frage

Soll die Fehleranzeige wie beschrieben immer aktiv sein, statt nur mit einem Zusatzschalter?
