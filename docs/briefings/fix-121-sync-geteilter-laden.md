---
spec_file: docs/specs/services/shared-store-schema-fallback.md
spec_sha256: d923cbc0e2349ae35eac86ee9a214b42b351fb05b2e4c7711dfe5b391a8a1d9e
---

# PO-Briefing: fix-121-sync-geteilter-laden

- **Spec:** docs/specs/services/shared-store-schema-fallback.md
- **Issue:** #121
- **Erstellt:** 2026-10-07

## Was gebaut wird

Geteilte Läden gleichen Artikel, Preise und Mitglieder wieder ab, auch bei unvollständiger Server-Einrichtung.

## Definition of Done

Auf einem neuen TestFlight-Stand erscheinen Artikel auf dem zweiten Gerät, und ein Hinweis nennt die unvollständige Server-Einrichtung.

## Wie geprüft wird

Ein nachgebauter Produktionsserver belegt das Verhalten (462 Tests grün); echtes CloudKit wird nicht automatisch geprüft.

## Kritische Anmerkungen

- Ursache unbewiesen; Behebung ist vermutlich Schema-Veröffentlichung im CloudKit-Dashboard durch den Kontoinhaber. Bis dahin werden Kategorien und Zuordnungen nicht geteilt.
- Hinweis bleibt, bis ein vollständiges Speichern gelingt; nur im Arbeitsspeicher, nach App-Neustart bis zum nächsten Speichern weg.
- Wirkung in Produktion erst nach neuem TestFlight-Stand auf Ihrem Gerät belegbar; „Sync repariert“ gilt vorher nicht.

## Freigabe-Frage

Geben Sie diese Härtung frei, im Wissen, dass das Schema im Dashboard separat veröffentlicht werden muss?
