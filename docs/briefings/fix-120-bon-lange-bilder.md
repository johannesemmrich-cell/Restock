---
spec_file: docs/specs/services/receipt-text-recognizer-tiling.md
spec_sha256: 81f257244c1d43cadd2bd38b19fb868f1be82ad77120b1e6c2261810a3e3c47a
---

# PO-Briefing: fix-120-bon-lange-bilder

- **Spec:** docs/specs/services/receipt-text-recognizer-tiling.md
- **Issue:** #120
- **Erstellt:** 2026-10-07

## Was gebaut wird

Sehr lange digitale Kassenbons (z. B. Lidl Plus) werden im Scan vollständig statt nur mit drei Artikeln erkannt.

## Definition of Done

Der echte Bon aus Ticket 120 liefert in der App mindestens 17 Artikel und die Endsumme 68,69 €.

## Wie geprüft wird

Tests prüfen Streifenrechnung und Zusammenführung; ob erzeugte Testbilder den Textverlust zeigen, ist offen — Beweis liefert nur der Durchlauf mit dem echten Bon.

## Kritische Anmerkungen

- Rabatte werden weiterhin nicht abgezogen: Preise bleiben Regalpreise, Summe 70,67 € statt 68,69 €; Ursache war nicht der Rabatt.
- Streifenmaße und Schwelle 2,5 stammen von einem einzigen Bild; andere lange Bons sind ungeprüft.

## Freigabe-Frage

Freigabe, obwohl Rabatte weiter nicht abgezogen werden und der Nachweis nur an einem Bon erfolgt?
