---
spec_file: docs/specs/models/price-source-display.md
spec_sha256: 1d4880d22e01963ec68abf976289462b021a3f1fbc2b0c7c733dcc3c739566df
spec_frozen_sha256: 11aa76debb8c593cc8aaea0ccb7e06ca851d9311f24c77baedc18567cf63c746
---

# PO-Briefing: fix-151-price-source

- **Spec:** docs/specs/models/price-source-display.md
- **Issue:** #151
- **Erstellt:** 2026-10-17

## Was gebaut wird

Unter jedem Preis steht seine Quelle; Schätzungen erscheinen mit „ca.“ in Warnfarbe.

## Definition of Done

Im Laden „Altbon“ sind Schätzung, eigener Preis und gelernter Preis im Simulator unterscheidbar; bisherige Preis-Tests bleiben grün.

## Wie geprüft wird

Automatische Tests prüfen Quelle, Anzeigetexte und Preiswahl sowie einen Simulator-Durchlauf; nichts wird auf Hennings iPhone geprüft.

## Kritische Anmerkungen

- Bestehende und aus geteilten Läden stammende Preise zeigen nur „gelernt“, nie „Bon“.
- Neue Felder müssen vor dem nächsten TestFlight-Upload im CloudKit-Produktionsschema veröffentlicht werden.
- Zwei „ca.“ in einer Zeile (Menge, Preis): Lesbarkeit nur im Entwurf geprüft.

## Freigabe-Frage

Soll die Preisquelle wie in Entwurf A umgesetzt werden?
