---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 03629182559051595308098dade53ac37558be97d5da3a8675bda32c9fe1a57e
---

# PO-Briefing: fix-50-import-dialog-design

- **Spec:** docs/specs/views/receipt-review-card.md (Abschnitt „Nachtrag Issue #50, Paket 1“) und docs/specs/testing/receipt-review-test-entry.md (Abschnitt „Nachtrag Issue #50, Paket 1“)
- **Issue:** #50
- **Erstellt:** 2026-09-27

## Was gebaut wird

Nach dem Zurückkehren aus einer geteilten App zeigt jede Bon-Position einen richtigen, markierten Namen, nie leer.

## Definition of Done

Jede Position im Bon-Prüf-Screen hat nach dem Öffnen aus einer geteilten App sichtbar genau einen markierten Namen, nie einen leeren.

## Wie geprüft wird

Automatisierte Tests zeigen es an einer nachgebauten Übergabe, nicht am echten Fotos-Teilen-Weg; das Speichern wird separat abgesichert.

## Kritische Anmerkungen

- Nur zwei der vier gemeldeten Punkte werden jetzt behoben, der Rest wandert in ein ungeprüftes Ticket #65.
- Beim Speichern wird jetzt auch ein leerer Name verhindert — geht über die vier gemeldeten Punkte hinaus.
- Der Nachweis simuliert den Rücksprung aus einer geteilten App, testet aber nicht den echten Fotos-Teilen-Weg.

## Freigabe-Frage

Sollen die restlichen zwei gemeldeten Punkte (Überschrift, wählbarer Bontext) erst mit einem separaten, noch zu prüfenden Ticket folgen?
