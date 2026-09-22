---
spec_file: docs/specs/testing/receipt-review-test-entry.md
spec_sha256: 58fac04cdee2f7f8581185dceca7755ed65509c55d63df2f9bb89bf471e6f511
---

# PO-Briefing: feat-28-receipt-review-test-entry

- **Spec:** docs/specs/testing/receipt-review-test-entry.md
- **Issue:** #28
- **Erstellt:** 2026-09-22

## Was gebaut wird

Ein automatischer Testzugang öffnet den Bon-Prüf-Screen ohne Kamera für künftige Prüfungen.

## Definition of Done

Für Nutzer ändert sich nichts sichtbar; zwei neue automatische Tests laufen zuverlässig und weisen die fehlende Bontext-Anzeige nach.

## Wie geprüft wird

Zwei Bildschirmtests prüfen, ob der Screen sichtbar öffnet; dass die Bon-Zeilen dabei unverändert bleiben, wird nur im Code geprüft, nicht getestet.

## Kritische Anmerkungen

- Dass die Bon-Zeilen unverändert bleiben, ist nicht getestet, sondern nur im Programmcode nachgelesen.
- Der automatische Nachweis deckt nur einen von drei im Auftrag genannten Prüfpunkten ab; Namenslänge und Darstellung der KI-Marke bleiben ungeprüft.
- Ein absichtlich fehlschlagender Test gilt als bestanden, damit eine spätere Nachbesserung ihn automatisch wieder auslöst.

## Freigabe-Frage

Reicht Ihnen, dass die Zeilen-Unveränderlichkeit nur im Code nachgelesen statt getestet ist und nur einer von drei Punkten automatisch geprüft wird?
