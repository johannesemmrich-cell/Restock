---
spec_file: docs/specs/testing/ui-test-language.md
spec_sha256: 69d95eae9090096ca2718642227a5df837cd3244a1d7ca716b09e149517b1473
---

# PO-Briefing: fix-3-ui-test-sprache

- **Spec:** docs/specs/testing/ui-test-language.md
- **Issue:** #3
- **Erstellt:** 2026-09-21

## Was gebaut wird

Automatische App-Prüfungen laufen wieder zuverlässig auf Deutsch, unabhängig davon, wo sie gestartet werden.

## Definition of Done

Der automatische Prüflauf zeigt nach der Änderung keine Fehlschläge mehr, weder online noch lokal.

## Wie geprüft wird

Automatische Testläufe bestätigen die Sprachumstellung samt Gegenprobe auf Englisch; sie prüfen keine sichtbaren App-Änderungen, weil keine gemacht wurden.

## Kritische Anmerkungen

- Spec behebt zusätzlich zwei weitere, im Ticket nicht genannte Testfehler – mehr Umfang als ursprünglich verlangt.
- Empfohlene robustere Lösung (technische Kennungen statt Text) wird bewusst nicht umgesetzt, macht künftige Textänderungen wieder riskant.
- Ob die Sprachumstellung auch den separaten Prozess der Teilen-Erweiterung erfasst, ist laut Spec unbewiesen.

## Freigabe-Frage

Ist es akzeptabel, zwei zusätzliche Testfehler mit zu beheben und die dauerhaftere Lösung auf später zu verschieben?
