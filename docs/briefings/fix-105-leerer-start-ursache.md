---
spec_file: docs/specs/ui-tests/test-105-durchgang-2-start-messung.md
spec_sha256: ce25669c7e8aed4b2b281943f8e171e09ae3bc51f451ed9929aa9ee14bc44805
---

# PO-Briefing: fix-105-leerer-start-ursache

- **Spec:** docs/specs/ui-tests/test-105-durchgang-2-start-messung.md
- **Issue:** #105
- **Erstellt:** 2026-10-10

## Was gebaut wird

Die Testhilfe protokolliert bei nötigem zweiten App-Start Zeit, Rechnerlast und Prozessnummern.

## Definition of Done

Bei erzwungenem Neustart zeigt das Testprotokoll alle Messwerte, der volle Testlauf ist grün und am Produkt ändert sich nichts.

## Wie geprüft wird

Kleine Tests und ein erzwungener Neustart beweisen, dass die Messung Zahlen liefert; sie beweisen nicht, warum der leere Start auftritt.

## Kritische Anmerkungen

- Gewünscht war die Ursache, geliefert wird nur Messung; Ursache bleibt unbekannt, Fehler war nicht reproduzierbar.
- Sechs weitere Testgruppen bleiben ungeschützt; Tickets bleiben offen.
- Tritt der Fehler nie auf, liefert die Messung nichts.

## Freigabe-Frage

Soll nur die Messung umgesetzt werden, obwohl sie weder Ursache klärt noch weitere Tests schützt?
