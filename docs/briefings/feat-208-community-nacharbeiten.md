---
spec_file: docs/specs/services/community-prices-nacharbeiten.md
spec_sha256: 66ed3535b622ab6629bb963e06c701036d671e67126c7d1dcfca2c7b23a3dee4
spec_frozen_sha256: bcbf11aa823aba43e59612cde6c633974ec77ff59d26070d6f38dc19530ff2cb
---

# PO-Briefing: feat-208-community-nacharbeiten

- **Spec:** docs/specs/services/community-prices-nacharbeiten.md
- **Issue:** #208
- **Erstellt:** 2026-10-22

## Was gebaut wird

Fußnote beim Teilen-Schalter stimmt für an und aus, Tests senden keine Preise ins Netz, toter Code entfällt.

## Definition of Done

Die Fußnote passt in beiden Schalterständen, und die vier betroffenen Testklassen laufen grün, ohne Preise ans Netz zu schicken.

## Wie geprüft wird

Automatische Tests belegen Text, Umschaltung auf Ersatzdatenbank und Zählen; ein echter Testlauf ohne Versand wird nicht gemessen.

## Kritische Anmerkungen

- Ticket-Ziel „nachweislich kein Record“ wird nur schwächer erfüllt: Beleg ist Konstruktion, im echten Testlauf wird nichts gemessen.
- Künftige Testklassen ohne die Erkennungswörter werden nicht erfasst; bereits vorhandene Test-Records in der Entwicklungsumgebung bleiben.
- Umfang liegt mit 13 Dateien über dem Limit; im Intake akzeptiert.

## Freigabe-Frage

Reicht dir die schwächere Absicherung (Bauweise statt Messung) für „kein Record mehr“?
