---
spec_file: docs/specs/models/private-cloudkit-schema.md
spec_sha256: 5f370505be4a50ed27efc86243aa672784724727903d450d70240c64f9b500f0
spec_frozen_sha256: 771881f288fa256fca9606eb0e2363ef49ed69c04c0f5f2eeaed1ff421783b0e
---

# PO-Briefing: fix-155-icloud-produktionsschema

- **Spec:** docs/specs/models/private-cloudkit-schema.md
- **Issue:** #155
- **Erstellt:** 2026-10-18

## Was gebaut wird

Feedback und Todos aus dem Entwicklermodus werden künftig mit iCloud abgeglichen, ohne dass der Abgleich der Läden blockiert.

## Definition of Done

Der Produktivbereich von iCloud kennt alle fünf Datentypen, belegt durch Werkzeug-Export; ein Test warnt, sobald Datenmodelle und Schema auseinanderlaufen.

## Wie geprüft wird

Tests belegen, dass Datenmodelle und Entwicklungsschema übereinstimmen; ob der Abgleich in der Produktivumgebung wirklich läuft, zeigt nur ein Gerätetest.

## Kritische Anmerkungen

- Gerätetest bei Ihnen steht aus; ob Build 32 wirklich hochlädt, ist bis dahin unbelegt.
- Der Test erkennt einen vergessenen Produktiv-Deploy nicht; nur der Werkzeugbeleg sichert das.
- Doppelte Läden bei mehreren Geräten und unsichtbare Abgleichfehler bleiben bewusst ungelöst (Ticket 156).

## Freigabe-Frage

Soll das iCloud-Schema um Feedback und Todos ergänzt und in der Produktivumgebung veröffentlicht werden?
