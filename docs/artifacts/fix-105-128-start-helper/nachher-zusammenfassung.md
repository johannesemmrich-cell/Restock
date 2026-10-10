# Nachweis nach der Änderung (AC-8), Simulator Restock-Validate, Vollauf `-only-testing:RestockUITests`

Suite jetzt 82 Tests (78 + 4 Hilfstests `UITestLaunchTests`), 1 übersprungen.

| Lauf | Bedingung | Ergebnis | Meldung „zweiter Start nötig“ | Beleg |
|------|-----------|----------|------------------------------|-------|
| U | volle CPU-Last (wie roter Vorher-Lauf 3) | 1 Fehler: `QuickAddAssignmentUITests.testStoreChipOverridesTarget`, Aufräumschritt „Failed to terminate“ (nicht umgestellte Klasse) | 1× (`AddItemQuantitySuggestionUITests`, Kachel Quittenhof) — der vorher rote Test ist grün | `nachher-lauf1-unter-last.txt` |
| 1 | ohne Last | grün | 1× (Quittenhof) | `nachher-lauf1-ohne-last.txt` |
| 2 | ohne Last | 1 Fehler: `ReplenishmentUITests.testAlsoDuePlusAddsItem` „+ von Listenreis fehlt“ (Kachel war da, Laden geöffnet; Prüfung `.exists` ohne Wartezeit — Timing, kein leerer Start; nicht umgestellte Klasse) | 0× | `nachher-lauf2-ohne-last.txt` |
| 3 | ohne Last | grün | 1× (Quittenhof) | `nachher-lauf3-ohne-last.txt` |

0× „Restarting after unexpected exit“ in allen Läufen.

Befund: Der leere erste Start tritt auch ohne künstliche Last auf (2 von 3 Läufen, jeweils im ersten Test) und wurde jeweils durch den Neustart aufgefangen. Ohne Helfer wären diese Läufe am ersten Test rot gewesen. AC-8 („dreimal nacheinander grün“) ist wörtlich NICHT erfüllt: Lauf 2 ist rot, durch einen anderen Fehler in einer Klasse, die dieser Durchgang nicht berührt.
