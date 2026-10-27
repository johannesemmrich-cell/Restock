---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: ce2742d7c9364a89b657ed8d84f1be6d429bb46c969ac856bd2c68a594d0911d
spec_frozen_sha256: e2f11b377b39a30bbbb0a9398af9a6365fe25fa20a99c2c9c7eeead007a66d5b
---

# PO-Briefing: feat-175-b3-eintragen

- **Spec:** docs/specs/appstore/app-store-auftritt.md
- **Issue:** #175
- **Erstellt:** 2026-10-27

## Was gebaut wird

Restock bekommt seine vollständige App-Store-Seite auf Deutsch und Englisch, samt Datenschutzangaben, Screenshots und drei Pro-Käufen.

## Definition of Done

Ein Abschlusslauf des Prüfwerkzeugs meldet alle Pflichtangaben als vollständig, der Datenschutz-Fragebogen ist per Screenshot belegt, nichts ist eingereicht.

## Wie geprüft wird

Tests prüfen das Prüfwerkzeug nur mit Scheindaten; ob Apple die Einträge annimmt, zeigt erst der Echtlauf.

## Kritische Anmerkungen

- Abschluss bleibt blockiert: Datenschutzseite pflegt ein Dritter, Build 37 fehlt, Review-Kontaktdaten fehlen noch von Henning.
- Englischer Name weicht ab: im Store „Restock Shopping List“, Deutsch bleibt „Restock“; Längentabelle der Spec nennt noch 7 Zeichen.
- Kaufprodukte sind nach dem Anlegen unumkehrbar; jeder Schritt läuft einzeln nur auf Hennings getipptes Wort.

## Freigabe-Frage

Soll die Spec freigegeben werden, damit der Store-Eintrag mit englischem Namen „Restock Shopping List“ schrittweise befüllt wird?
