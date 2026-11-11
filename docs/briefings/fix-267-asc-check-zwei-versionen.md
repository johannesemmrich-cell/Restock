---
spec_file: docs/specs/appstore/asc-check-version.md
spec_sha256: d51be7c7290fa69f171702e667341f94e25d695ebf55ee641e9387fcfb412070
spec_frozen_sha256: 2b8fbb4e39c68745f8a293ab8f4175e695f4c2b3b6bf8971d30a40eecc57c5a0
---

# PO-Briefing: fix-267-asc-check-zwei-versionen

- **Spec:** docs/specs/appstore/asc-check-version.md
- **Issue:** #267
- **Erstellt:** 2026-11-11

## Was gebaut wird

Der Prüfbefehl für App Store Connect kann den Stand von Version 1.0.1 lesen, ohne bei zwei Einträgen abzubrechen.

## Definition of Done

Der Lauf für Version 1.0.1 zeigt Zustand, Build und Käufe an, bricht nicht ab und meldet Unbekanntes nie als in Ordnung.

## Wie geprüft wird

Automatische Tests mit Schein-Antworten decken jede Anforderung ab; sie beweisen nicht, dass Apples echte Antworten so aussehen.

## Kritische Anmerkungen

- Zuordnung der Käufe zur Version und Vereinbarung für bezahlte Apps sind nicht lesbar und bleiben manuell zu prüfen.
- Apples echte Zustandsfelder sind erst im Live-Lauf belegt; bei unklarem Eintrag bricht das Werkzeug mit Zustandsliste ab.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
