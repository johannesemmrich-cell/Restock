# Messung 2026-10-10: leerer erster Start (#105/#128), Restock-Validate, iOS 26.5

Messzeile (vorübergehend, wieder entfernt): `NSLog("MESSUNG105 pid=… args=…")` am Anfang von `SmartCartApp.init`, mitgeschnitten mit `simctl spawn … log stream`.

| # | Bedingung | Ergebnis | Zweiter Start nötig? |
|---|-----------|----------|----------------------|
| 1 | Volllauf (82 Tests), ohne Last, frisch gebaut | grün, erster Prozess (pid 1272) trägt `-seedQuantitySuggestionForUITests` | nein |
| 2 | App läuft vorher ohne Argumente (`simctl launch`), Einzeltest | grün; der laufende Prozess (8493) wird ersetzt, neuer (8617) trägt die Argumente | nein |
| 3 | Einzeltest unter voller CPU-Last (10 Kerne) | grün, Argumente da | nein |
| 4 | Volllauf unter Last, Versuch 1 | Testläufer ließ sich nicht starten („Simulator device failed to launch …xctrunner“, RequestDenied), anderer Fehler | – |
| 5 | Volllauf unter Last, Versuch 2 | erster Test grün, Argumente da | nein |
| 6 | Volllauf unter Last, App und Testläufer vorher deinstalliert | erster Test grün, Argumente da | nein |

Ergebnis: Der leere erste Start ließ sich heute in 5 gültigen Versuchen nicht nachstellen, weder ohne Last, noch unter Last, noch mit vorher laufender oder frisch installierter App. Die Hypothese „erster Start trifft eine noch laufende App des vorigen Laufs“ ist widerlegt (Versuch 2).

Belege: `messung-startargumente-lauf1.txt` (Versuch 1, Prozesse mit Argumenten), `einzeltest-unter-last.txt` (Versuch 3).
