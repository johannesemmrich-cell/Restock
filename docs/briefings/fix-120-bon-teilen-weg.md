---
spec_file: docs/specs/services/receipt-share-extension-recognizer.md
spec_sha256: f9e7f9a10ec5fbb23cc15ddca92d820b9e5d2e1a7f84883db25375ae1674308f
---

# PO-Briefing: fix-120-bon-teilen-weg

- **Spec:** docs/specs/services/receipt-share-extension-recognizer.md
- **Issue:** #120 (Fortsetzung)
- **Erstellt:** 2026-10-08

## Was gebaut wird

Beim Teilen eines langen Kassenbons an Restock werden alle Artikel erkannt, nicht nur etwa drei.

## Definition of Done

Im Simulator liefert der Teilen-Weg beim echten Lidl-Bon mindestens 18 Positionen und die Endsumme 68,69 €, ohne Absturz.

## Wie geprüft wird

Simulator-Durchläufe mit dem echten Bon: vorher 14 Positionen (iOS 26.5) bzw. nichts (iOS 27), nachher je 19 plus Endsumme.

## Kritische Anmerkungen

- Speicherlimit (120 MB) am iPhone unbewiesen, Scanner brauchte 134 MB; Gerätetest nur nach Build 11 und deinem Wort.
- Bei Limit-Verstoß Rückfall Alternative B als eigenes Ticket; keine Zusage „auf dem iPhone repariert“.
- Prüfskript spielt App jetzt selbst ein; UI-Suite-Nachweis auf unberührtem Simulator, Altlast auf Validate als eigenes Ticket.

## Freigabe-Frage

Genügt dir der Simulator-Nachweis jetzt, mit Gerätetest erst nach Build 11 und deinem ausdrücklichen Wort?
