---
spec_file: docs/specs/models/store-stations.md
spec_sha256: d223d1113ca8baf721dbb5e16aa7685c9d7aef72e46bdd5e8ca46f3dbf16d907
spec_frozen_sha256: e0425ecdbc2635bfd55e9744fcee38e32a896a25723509ab95accc41b2de39c6
---

# PO-Briefing: feat-234-laden-stationen

- **Spec:** docs/specs/models/store-stations.md
- **Issue:** #234
- **Erstellt:** 2026-10-30

## Was gebaut wird

Läden bekommen feste Gänge; die Liste folgt ihrer Reihenfolge, mit Lidl-Vorlage.

## Definition of Done

Mit Lidl-Vorlage zeigt die Liste Gang-Abschnitte in fester Reihenfolge, Sonstiges zuletzt; andere Läden bleiben unverändert.

## Wie geprüft wird

Automatische Tests prüfen Zuordnung, Reihenfolge, Lernen und Oberfläche; geteilte Läden und echte Geräte bleiben ungeprüft.

## Kritische Anmerkungen

- Lidl-Vorlage plus Übergangsmenü schon in Durchgang 1, entschieden war Durchgang 2.
- Umfang 18 Dateien, rund 400 Zeilen, über dem freigegebenen Rahmen von 250–350.
- Mitglieder geteilter Läden sehen die Gänge erst ab Durchgang 3.

## Freigabe-Frage

Darf Durchgang 1 die Lidl-Vorlage samt Übergangsmenü und den größeren Umfang enthalten?

## Ampel

Ampel: rot
