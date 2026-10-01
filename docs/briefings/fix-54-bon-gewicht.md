---
spec_file: docs/specs/views/receipt-save-purchase-quantity.md
spec_sha256: 55b0d7b8af08852dbe6a63ac12fa921ad4c579df2c1d479064ff0f5238877005
---

# PO-Briefing: fix-54-bon-gewicht

- **Spec:** docs/specs/views/receipt-save-purchase-quantity.md
- **Issue:** #54
- **Erstellt:** 2026-10-01

## Was gebaut wird

Bon-Import speichert bei Gewichtsware das echte Gewicht, etwa 706 g, statt keiner Menge.

## Definition of Done

Ein importierter Bon mit Bananenzeile zeigt in der Ausgabenansicht „706 g“ und 1,76 €; bestehende Tests bleiben grün.

## Wie geprüft wird

Automatische Tests prüfen Gewicht, Stückzahl, Packungsgröße und einen Durchlauf bis zur Ausgabenansicht; Altdaten werden nicht repariert oder geprüft.

## Kritische Anmerkungen

- Offen: Packungsgröße im Namen (Skyr 500G) wird als 500 g gespeichert, auch bei nur einer Packung.
- Fehler wurde noch nie real nachgestellt; Beleg entsteht erst im ersten roten Testlauf.
- Alte Datensätze bleiben falsch; Positionen mit schon vorhandenem Artikel wurden nicht untersucht.

## Freigabe-Frage

Soll die Packungsgröße aus dem Namen, etwa 500 g, im Kaufdatensatz gespeichert werden?
