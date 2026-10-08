---
spec_file: docs/specs/services/receipt-share-extension-recognizer.md
spec_sha256: e7260be332cef71b273428c3ef90b71289fa2d911b177964fd4cbaa71bbd9dca
---

# PO-Briefing: fix-120-bon-teilen-weg

- **Spec:** docs/specs/services/receipt-share-extension-recognizer.md
- **Issue:** #120 (Fortsetzung)
- **Erstellt:** 2026-10-08

## Was gebaut wird

Beim Teilen eines langen Kassenbons an Restock werden alle Artikel erkannt, nicht nur etwa drei.

## Definition of Done

Im Simulator erkennt der Teilen-Weg beim echten Lidl-Bon mindestens 18 Positionen und die Endsumme 68,69 €, ohne Absturz.

## Wie geprüft wird

Ein Simulator-Durchlauf mit dem echten Bon belegt das Ergebnis; ein Quelltext-Test sichert den gemeinsamen Erkenner. Dein iPhone wird nicht geprüft.

## Kritische Anmerkungen

- Auf dem iPhone unbewiesen: Das Speicherlimit der Erweiterung (120 MB) könnte reißen, der App-Scanner brauchte 134 MB.
- Der Fall „Bild ohne Text" ist nicht automatisch getestet, nur per Code-Lesen belegt.

## Freigabe-Frage

Genügt dir der Simulator-Nachweis jetzt, mit Gerätetest erst nach Build 11 und deinem ausdrücklichen Wort?
