---
spec_file: docs/specs/testing/receipt-review-test-entry.md
spec_sha256: 43d6b1732f928cbd048651feab09a6e7f9ea1b86730b78d38784f33c77795a7c
---

# PO-Briefing: feat-28-receipt-review-test-entry

- **Spec:** docs/specs/testing/receipt-review-test-entry.md
- **Issue:** #28
- **Erstellt:** 2026-09-22

## Was gebaut wird

Ein automatischer Testzugang öffnet den Bon-Prüf-Screen ohne Kamera, damit künftige Änderungen daran automatisch geprüft werden können.

## Definition of Done

Am Screen ändert sich für Nutzer nichts sichtbar; zwei neue automatische Tests laufen zuverlässig, und die fehlende Bontext-Anzeige ist jetzt automatisch nachgewiesen.

## Wie geprüft wird

Zwei automatische Bildschirmtests öffnen den Screen und prüfen Sichtbarkeit der Zeilen; ob Name vollständig oder KI-Marke einzeilig ist, prüfen sie nicht.

## Kritische Anmerkungen

- Der Testnachweis deckt nur einen von drei im Auftrag genannten Prüfpunkten automatisch ab (Bontext); Name-Länge und KI-Marke bleiben ungeprüft.
- Ein bewusst fehlschlagender Test gilt als bestanden — ungewöhnlich, aber mit Absicherung erklärt.
- Der Umfang wächst von den im Auftrag genannten drei auf vier Änderungsstellen.

## Freigabe-Frage

Reicht Ihnen der automatische Nachweis nur für die fehlende Bontext-Anzeige, obwohl der Auftrag drei Prüfpunkte nannte?
