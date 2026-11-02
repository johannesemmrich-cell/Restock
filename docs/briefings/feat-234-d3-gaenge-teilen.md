---
spec_file: docs/specs/services/shared-store-stations-sync.md
spec_sha256: ce3b01af05a5efe5921043cfc4123ab3f60e466be927a7860ce0ff582b40c534
spec_frozen_sha256: cb65c0470984bd7e6b3e29d775dc94a49c54169587f026933e0a060da0cd6dac
---

# PO-Briefing: feat-234-d3-gaenge-teilen

- **Spec:** docs/specs/services/shared-store-stations-sync.md
- **Issue:** #234
- **Erstellt:** 2026-11-02

## Was gebaut wird

Die Gänge eines geteilten Ladens erscheinen bei allen Mitgliedern; wer sie ändert oder entfernt, ändert sie für alle.

## Definition of Done

Ein Mitglied richtet Gänge ein oder entfernt sie, die anderen sehen denselben Stand, der neue Hinweistext steht da, das Cloud-Schema ist freigeschaltet.

## Wie geprüft wird

Tests weisen die Abgleichslogik mit Schein-Antworten nach; ein echter Abgleich zwischen zwei Konten und Geräten wird nicht geprüft.

## Kritische Anmerkungen

- Ändern zwei Mitglieder gleichzeitig, geht die ältere Änderung komplett verloren (bewusst, dokumentiert).
- Ohne Cloud-Schema-Freischaltung vor dem Upload reisen auch Kategorien und Merkungen nicht mehr mit.
- Ältere App-Versionen zeigen geteilte Läden weiterhin ohne Gänge.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
