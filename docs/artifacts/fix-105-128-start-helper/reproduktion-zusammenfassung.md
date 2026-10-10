# Reproduktion #128 / #105 (AC-7), Stand `main` vor der Änderung, Simulator Restock-Validate

Aufruf je Lauf: `xcodebuild test -scheme Restock -only-testing:RestockUITests`, ohne Wiederholungs-Optionen, nie parallel.

| Lauf | Bedingung | Ergebnis | Beleg |
|------|-----------|----------|-------|
| 1 | Mac ohne Zusatzlast | 78 Tests, 1 übersprungen, 0 Fehler, grün | `repro-main-vorher-lauf1-gruen.txt` |
| 2 | Mac ohne Zusatzlast, direkt nach Lauf 1 | 78 Tests, 1 übersprungen, 0 Fehler, grün | `repro-main-vorher-lauf2.txt` |
| 3 | je Kern ein Rechenprozess (volle CPU-Last) | 78 Tests, 2 Fehler, **rot** | `repro-main-vorher-lauf3-unter-last.txt` |

Lauf 3, Zeile 108: `AddItemQuantitySuggestionUITests.testAssumedQuantityIsMarkedAsAssumptionInList` — „Quittenhof-Kachel nicht auf dem Home-Screen gefunden“ (derselbe Test und dieselbe Meldung wie im Ticket #128).
Zweiter Fehler, Zeile 4127: `RestockUITests.testAppLaunchesToHomeScreen` — „HomeView-Hero-Titel ‚Restock‘ nicht innerhalb von 15 s“ (Start ohne Seed; liegt außerhalb dieses Durchgangs, Befund für Durchgang 2/3 bzw. ein eigenes Ticket).

Befund: Der Fehler tritt nicht von selbst „fast immer“ auf (Lauf 1 und 2 grün), sondern unter Last (Lauf 3). Das stützt die Lesart „Sitzungsaufbau des Testläufers beim ersten Start zu langsam“; eine Messung der Startargumente in Lauf 3 wurde nicht gemacht, die Ursache bleibt also unbewiesen.
