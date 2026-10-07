---
spec_file: docs/specs/services/shared-store-schema-fallback.md
spec_sha256: e231150849d047ce60d75110edb3c87db6d65ee068d3709024db420562ad925d
---

# PO-Briefing: fix-121-sync-geteilter-laden

- **Spec:** docs/specs/services/shared-store-schema-fallback.md
- **Issue:** #121
- **Erstellt:** 2026-10-07

## Was gebaut wird

Geteilte Läden gleichen Artikel, Preise und Mitglieder auch bei unvollständig eingerichtetem Server ab; Fehler werden sichtbar benannt.

## Definition of Done

Im Laden erscheint bei unvollständigem Server ein klarer Hinweis, Artikel gleichen ab; vollständig behoben erst nach Veröffentlichung des Schemas und Prüfung auf deinem TestFlight-Gerät.

## Wie geprüft wird

Automatische Tests mit nachgebautem Server belegen Ersatzverhalten und Hinweise; sie beweisen nicht, dass es gegen den echten Apple-Server funktioniert.

## Kritische Anmerkungen

- Ursache ist unbewiesen; die eigentliche Behebung ist eine Einstellung des Kontoinhabers im CloudKit-Dashboard, nicht der Code.
- Bis das Schema veröffentlicht ist, werden Kategorien und gemerkte Zuordnungen nicht geteilt; die Spec benennt das ehrlich.

## Freigabe-Frage

Soll dieser Härtungs-Durchgang starten, obwohl Kategorien erst nach Schema-Veröffentlichung durch den Kontoinhaber wieder geteilt werden?
