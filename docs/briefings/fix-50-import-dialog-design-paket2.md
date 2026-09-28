---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: d85c75ac81ecd8e9b485a628a484e2e74767c257dc4d5f31ed7191ec158efd32
---

# PO-Briefing: fix-50-import-dialog-design-paket2

- **Spec:** docs/specs/views/receipt-review-card.md (Korrektur AC-20)
- **Issue:** #65 (Kontext-Dokument: docs/context/fix-50-import-dialog-design-paket2.md)
- **Erstellt:** 2026-09-28

## Was gebaut wird

Lange gedrückter Bontext im Bon-Prüf-Screen kopiert den gedruckten Namen in die Zwischenablage.

## Definition of Done

PO erkennt es daran, dass sich das Kontextmenü mit „Kopieren" per Test nachweisbar öffnet; ob der Text stimmt, bestätigt nur eine Codeprüfung.

## Wie geprüft wird

Automatisierter Test zeigt nur: Menü öffnet sich, „Kopieren" ist da und antippbar; ob der kopierte Text stimmt, testet er nicht.

## Kritische Anmerkungen

- Ursprünglich als vollautomatisch testbar geplant; iOS verlangt seit Version 16 eine Nutzerbestätigung, die im Testlauf nie kommt.
- Gleiche reduzierte Prüftiefe wie bereits bei der Schriftgröße (AC-19) in derselben Karte akzeptiert.
- Funktion selbst unverändert — nur der automatisierte Nachweisweg ist eingeschränkt, nicht die App-Funktion.

## Freigabe-Frage

Reicht eine Codeprüfung statt automatisiertem Test als Nachweis, dass der kopierte Text stimmt — wie schon bei der Schriftgröße akzeptiert?
