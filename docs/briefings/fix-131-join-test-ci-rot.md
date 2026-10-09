---
spec_file: docs/specs/ui-tests/test-131-join-test-testdaten.md
spec_sha256: 01ad1be999a2f1ff81eecec6146186a1ca7a929ef80948bb73af262782cdc992
---

# PO-Briefing: fix-131-join-test-ci-rot

- **Spec:** docs/specs/ui-tests/test-131-join-test-testdaten.md
- **Issue:** #131
- **Erstellt:** 2026-10-09

## Was gebaut wird

Zwei Beitreten-Tests verwenden pro Lauf einen zufälligen Code, damit der rote CI-Test wieder grün wird.

## Definition of Done

Die gesamte Testsuite läuft lokal und auf dem CI-Runner grün durch, mit 78 Tests, ohne Änderung an der App.

## Wie geprüft wird

Lokale und CI-Läufe zeigen, dass der Fehlertext bei unbekanntem Code erscheint; Netzabhängigkeit und Antwortzeiten des Runners bleiben ungeprüft.

## Kritische Anmerkungen

- Ticket-Verdacht (CloudKit-Antwort) widerlegt: Der Testcode existiert nun real; lokal nicht nachgestellt, nur CI-Beleg.
- Zusatz: Zweiter Test wird mitumgestellt, im Ticket nicht verlangt; Ihre Entscheidung dazu steht noch aus.
- Test bleibt am echten Netz; Wackeln durch langsame Runner bleibt möglich, "flakefrei" wird nicht zugesagt.

## Freigabe-Frage

Soll der rote Test mit Zufallscode repariert werden, einschließlich des zweiten, nicht beanstandeten Tests?
