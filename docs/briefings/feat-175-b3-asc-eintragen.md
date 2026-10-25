---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: c17c8885284de26dd8ddb64a879b90ba86caa8762cba30fedd0523ea0dad4907
spec_frozen_sha256: e6706be7412db416f92de104737754ef8c794d06c6dce447f75f712bb9833a42
---

# PO-Briefing: feat-175-b3-asc-eintragen

- **Spec:** docs/specs/appstore/app-store-auftritt.md (nur Durchgang B3a)
- **Issue:** #175
- **Erstellt:** 2026-10-25

## Was gebaut wird

Das Prüfwerkzeug für App Store Connect liest In-App-Käufe und Preise künftig mit den richtigen Apple-Pfaden und wertet Preise zuverlässig.

## Definition of Done

Der Werkzeugtest läuft grün, und ein falscher, abgelaufener oder künftiger Preis wird als Abweichung gemeldet, nie als in Ordnung.

## Wie geprüft wird

Automatische Tests mit nachgestellten Apple-Antworten belegen die Logik; ob Apples echte Antworten so aussehen, beweisen sie nicht.

## Kritische Anmerkungen

- Dieser Durchgang trägt nichts in App Store Connect ein; das Ticketziel „einreichbar“ bleibt offen bis zum Folgedurchgang.
- Datenschutzseite (fremde Pflege) und Build 37 fehlen; ohne beide keine Einreichung.
- Umfang ~215 statt geschätzter ~90 Zeilen, noch im Limit.

## Freigabe-Frage

Gibst du das reine Lese-Werkzeug (ohne Änderungen an App Store Connect) frei, damit danach die echten Eintragungen folgen können?
