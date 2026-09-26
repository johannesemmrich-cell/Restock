---
spec_file: docs/specs/models/learned-price-unit-and-quantity-source.md
spec_sha256: 7104c9999e21c0adf2bab6a6a3d1e540e8bc7c1f81a6114ede039af2a9565921
---

# PO-Briefing: fix-10-preis-einheit

- **Spec:** docs/specs/models/learned-price-unit-and-quantity-source.md
- **Issue:** #10 (Restumfang nach Teilung; sichtbare Mengen-Annahme separat in #57)
- **Erstellt:** 2026-09-26

## Was gebaut wird

Ein vom Bon gelernter Gewichtspreis wird nicht mehr fälschlich als Stückpreis verrechnet und zeigt keinen falschen 1-Cent-Betrag mehr.

## Definition of Done

Ein Artikel mit Gewichtspreis ohne passende Menge zeigt keinen falschen Cent-Betrag; bestehende Stückpreise bleiben unverändert korrekt; die sichtbare Mengen-Annahme folgt erst mit #57.

## Wie geprüft wird

Automatisierte Tests und ein Bildschirm-Test beweisen die Preiskorrektur; die mitgelieferte, noch nicht nutzbare Anzeige-Markierung bleibt ungeprüft.

## Kritische Anmerkungen

- Purpose-Absatz behauptet sichtbare „ca.“-Kennzeichnung und beleghafte Menge — das liefert erst #57, nicht #10.
- Ursprungsantrag verlangte sichtbare, korrigierbare Mengen-Annahme; #10 liefert nur die Preiskorrektur, Rest folgt mit #57.
- Mitgelieferter Anzeige-Code (Tönung, Rücksetzen) bleibt in #10 ungetestet — die Spec belegt nur, dass er compiliert.

## Freigabe-Frage

Reicht die reine Preiskorrektur jetzt, oder soll erst geklärt werden, ob Purpose-Text und Anzeige-Code zu viel versprechen?
