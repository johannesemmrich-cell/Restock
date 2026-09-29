---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: f812efb89f5cc45188ddbf2c276b13dc17ad0390a9bb9150da545c820f0af3f6
---

# PO-Briefing: fix-67-currentname-matcheditem

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #67
- **Erstellt:** 2026-09-29

## Was gebaut wird

Wählt man beim Bon-Prüfen den vorherigen Namen zurück, lernt der Preis wieder den richtigen Artikel.

## Definition of Done

Nach Rückwechsel zur ursprünglichen Namensauswahl speichert der Bon-Preis beim richtigen Artikel, nicht mehr bei einer zuvor gewählten Alternative.

## Wie geprüft wird

Ein automatisierter Test prüft die interne Zuordnung nach dem Namenswechsel; ein echter Speichervorgang im Simulator wird nicht durchgespielt.

## Kritische Anmerkungen

- Definition of Done nennt die Korrektur nicht — PO sieht den behobenen Fehler dort nicht.
- Nur ein Unit-Test deckt den Fix ab; ein echter Speichervorgang wird nicht geprüft.

## Freigabe-Frage

Genügt eine gezielte, risikoarme Korrektur der Namensauswahl im Bon-Prüf-Screen, um die Freigabe zu erteilen?
