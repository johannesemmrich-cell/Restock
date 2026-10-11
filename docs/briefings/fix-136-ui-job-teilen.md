---
spec_file: docs/specs/ci/ui-test-job-in-zwei-haelften.md
spec_sha256: 49fd0f16653943d77ba900a94905e70b7afe4e35a45b168c9ce5a61ed4c33760
---

# PO-Briefing: fix-136-ui-job-teilen

- **Spec:** docs/specs/ci/ui-test-job-in-zwei-haelften.md
- **Issue:** #136
- **Erstellt:** 2026-10-11

## Was gebaut wird

Die automatischen Oberflächentests laufen künftig in zwei gleichzeitigen Hälften, damit die Prüfung nicht mehr am Zeitlimit abbricht.

## Definition of Done

Beide Hälften sind in drei Läufen grün, führen zusammen alle 84 Tests aus und bleiben unter 45 Minuten.

## Wie geprüft wird

Echte Läufe auf dem Server messen Zeiten und Testzahl; ob die Teilung dauerhaft Abstand hält, beweist das nicht.

## Kritische Anmerkungen

- Bau und Start laufen doppelt: mehr Rechenminuten, beide Hälften können getrennt in der Warteschlange warten.
- Wirkung nur durch echte Läufe beweisbar, Schwankung des Servers bleibt, Abstand zum Limit ist nicht garantiert.
- Ticket nannte „langsamste Tests prüfen“: kein dominanter Einzeltest gefunden; Lastprobe auf dem Server womöglich nicht herstellbar.

## Freigabe-Frage

Soll die Prüfung wie beschrieben in zwei parallele Hälften geteilt werden?
