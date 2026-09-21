---
spec_file: docs/specs/testing/ui-test-language.md
spec_sha256: fbfadac0a46ae9a42658332c0c07fec4f2874543ac087a5d570d25ddc5225c7f
---

# PO-Briefing: fix-3-ui-test-sprache

- **Spec:** docs/specs/testing/ui-test-language.md
- **Issue:** #3
- **Erstellt:** 2026-09-21

## Was gebaut wird

Die App-Tests laufen künftig zuverlässig auf Deutsch, damit die Qualitätsprüfung nicht mehr grundlos rot meldet.

## Definition of Done

Der automatische Testlauf zeigt keine Fehlschläge mehr, weder im Hintergrund noch bei wiederholten lokalen Läufen.

## Wie geprüft wird

Wiederholte automatische Testläufe auf Deutsch und Englisch belegen den Fix; ob die App über mehrere Sitzungen stabil bleibt, prüft das nicht.

## Kritische Anmerkungen

- Der neue Schließ-Mechanismus für das Läden-Fenster hat keinen eigenen Test, nur einen Screenshot-Beleg.
- Das ursprünglich gemeldete Tipp-Problem (Kachel nicht klickbar) bleibt bewusst unbehoben, tritt nur bei lange genutzten Testgeräten auf.
- Umfang wuchs seit letzter Prüfung: Änderungsmenge fast verdoppelt, ein vierter Korrekturpunkt kam nachträglich dazu.

## Freigabe-Frage

Reicht die Zuverlässigkeit auf einem frisch zurückgesetzten Testgerät, obwohl das alte Tipp-Problem bei länger genutzten Geräten bestehen bleibt?
