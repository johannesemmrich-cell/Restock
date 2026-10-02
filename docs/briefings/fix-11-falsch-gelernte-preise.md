---
spec_file: docs/specs/models/legacy-price-reset-migration.md
spec_sha256: 4856d935eec20c27ea20ce8b138215a73d1e5ccc0664780ee3a39dcad6587fca
---

# PO-Briefing: fix-11-falsch-gelernte-preise

- **Spec:** docs/specs/models/legacy-price-reset-migration.md
- **Issue:** #11
- **Erstellt:** 2026-10-01

## Was gebaut wird

Einmalig werden alte, zu hohe Artikelpreise beim App-Start auf die Standard-Schätzung zurückgesetzt.

## Definition of Done

Der alte Laugenbrötchen-Artikel zeigt nicht mehr 1,56 €, ein von Hand eingetragener Preis bleibt unverändert.

## Wie geprüft wird

Tests und ein App-Durchlauf mit nachgestelltem Altstand; Hennings echter Datenbestand wird nicht geprüft.

## Kritische Anmerkungen

- Abweichung: Gelernte Laden-Preise bleiben unkorrigiert; nichts wird auf 0,39 € korrigiert, nur auf Schätzung zurückgesetzt.
- Geteilte Listen: Falschwerte anderer Mitglieder werden nicht korrigiert; Ticketfrage bleibt offen.
- Richtige Altpreise gehen verloren; ein gleich hoher Handpreis wird mitgelöscht.

## Freigabe-Frage

Reicht dir Zurücksetzen auf Schätzwerte, obwohl gelernte Preise und geteilte Listen unkorrigiert bleiben?
