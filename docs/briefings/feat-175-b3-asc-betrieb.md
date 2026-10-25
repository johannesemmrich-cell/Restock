---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: de460581e72d23bb0a7ff07f18bb80e3072739a597463f56705c138edda26a83
spec_frozen_sha256: a0513db3ac378f5339916bd0866d4eaa96bfd9debdd4fe1b196935f179df867c
---

# PO-Briefing: feat-175-b3-asc-betrieb

- **Spec:** docs/specs/appstore/app-store-auftritt.md (Durchgang B3b)
- **Issue:** #175
- **Erstellt:** 2026-10-25

## Was gebaut wird

Das Prüfwerkzeug für App Store Connect meldet fehlende Einträge künftig als Abweichung statt fälschlich als in Ordnung oder als Abbruch.

## Definition of Done

Ein dritter lesender Lauf gegen Apple meldet Datenschutzseite erreichbar sowie Altersfreigabe, App-Preis und Verfügbarkeit als Abweichungen, nie als ok oder Fehler.

## Wie geprüft wird

Tests mit nachgebauten Apple-Antworten belegen jede Meldung; echte Apple-Antworten prüfen sie nicht.

## Kritische Anmerkungen

- Der dritte Echtlauf als Nachweis der Nachbesserung ist noch nicht erfolgt; bisher gibt es nur nachgebaute Antworten.
- Fehlender Preis und fehlende Verfügbarkeit gelten als „nicht eingerichtet“, gestützt nur auf Forenberichte, nicht auf Apple.
- Die 24 Pflichtfelder der Altersfreigabe stammen aus dem Schema; ob Apple alle verlangt, ist unbelegt.

## Freigabe-Frage

Gibst du die Korrektur des Prüfwerkzeugs frei, damit danach der dritte Lesetest gegen Apple laufen kann?
