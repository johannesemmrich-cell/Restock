---
spec_file: docs/specs/ui-tests/test-105-128-durchgang-1-start-helfer.md
spec_sha256: 55cecaaaca5ff7367f866e1b2610bb971d83b153f7164620dd28a6a7333b3c34
---

## Was gebaut wird

Gesäte UI-Tests prüfen nach dem App-Start, ob die Testdaten angekommen sind, und starten sonst einmal neu.

## Definition of Done

Drei volle Testläufe hintereinander sind beim ersten Versuch grün, ohne Eingriff in die App, mit gemeldeter Zahl nötiger Neustarts.

## Wie geprüft wird

Hilfstests belegen die Neustart-Logik, drei Gesamtläufe die Wirkung; nicht bewiesen wird, warum der erste Start leer bleibt.

## Kritische Anmerkungen

- Ursache des leeren Starts bleibt unbekannt; der Neustart ist Abhilfe, keine Erklärung.
- Nur zwei Testgruppen werden geschützt; Ticketziel „alle gesäten Tests“ gilt erst nach Durchgang 3.
- Leere Aufräumstarts und leere Starts mit zufällig sichtbarer Kachel bleiben unbemerkt.

## Freigabe-Frage

Gibst du Durchgang 1 mit diesem Umfang frei, obwohl die Ursache ungeklärt und nur zwei Testgruppen geschützt sind?
