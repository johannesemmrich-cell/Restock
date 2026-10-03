# Adversary Dialog: test-98-testluecken

Spec: docs/specs/ui-tests/shopping-route-learning-uitest.md
Tests (Belege): docs/artifacts/test-98-testluecken/test-green-output.txt, docs/artifacts/test-98-testluecken/test-class-3runs-output.txt, docs/artifacts/test-98-testluecken/test-full-run-output.txt

### Runde 1

Pruefung der Belege und des Codes (lesend). RED-Artefakte: beide neuen UI-Tests scheitern an der Ausgangslage, Unit-Build scheitert an fehlendem RouteClock. Release-Build (release-build-output.txt) BUILD SUCCEEDED.
Mutationsprobe (Wegwerf-Kopie, Original unberuehrt): isBulkCheckOff in ShoppingRoute.swift abgeschaltet, dann scheitert testFastCheckOffsAtHomeLearnNothing mit [Gouda, Brot, Apfel] != [Apfel, Brot, Gouda]. Test B ist keine Scheinpruefung.
Damalige Befunde F001 (AC-11, drei gruene Klassenlaeufe fehlten) und F002 (AC-10, Gesamtlauf fehlte) wurden in Runde 3 geprueft, siehe dort.

### Runde 2

Gegenproben:
- Uhr-Offset wirkt nur in #if DEBUG (Store.swift:726-742), Release liefert Date(); einziger Verwender ist der Default von finalizeStaleTrip (Store.swift:271), recordCheckOff nutzt echte Zeit.
- Seed-Argument -shoppingRouteNoLearnedModelForUITests wird nur in der DEBUG-Seedfunktion gelesen (SmartCartApp.swift:287); ohne Argument bleibt der Seed identisch.
- uncheckAll laeuft erst nach dem Neustart, wenn der Trip schon abgeschlossen und gelernt ist; es verfaelscht die Reihenfolge nicht.
- Test B haengt an der 2-s-Grenze: Verspaetung > 2 s je Haken wuerde lernen und rot werden (Flake, nie falsch gruen).
- tearDown raeumt per -clearShoppingRouteSeedForUITests auf; deleteAllStoresAndItems ruft removeRouteData (SmartCartApp.swift:377-385).

### Runde 3 (Nachpruefung der neuen Belege)

Geprueft wurde selbst am Rohlog:
- test-class-3runs-output.txt: drei getrennte xcodebuild-Aufrufe (Lauf 1 bis 3, je -only-testing:RestockUITests/ShoppingRouteLearningUITests, Zeitstempel 10:11, 10:13, 10:14, also aufeinanderfolgend, gleiche Simulator-UDID). Je Lauf: testFastCheckOffsAtHomeLearnNothing passed (30,5 / 32,5 / 29,8 s), testRouteIsLearnedFromSlowCheckOffs passed (33,1 / 33,2 / 32,6 s), "Executed 2 tests, with 0 failures", "** TEST SUCCEEDED **". Kein Null-Test-Lauf, keine Abbrueche, kein Retry. Drei gruene Klassenlaeufe in Folge: belegt.
- test-full-run-output.txt: Aufruf ohne -only-testing (Zeile 2). Unit-Ziel: "Executed 434 tests, with 0 failures" (Z. 1200). UI-Ziel: "Executed 56 tests, with 1 test skipped and 0 failures" (Z. 4912), "** TEST SUCCEEDED **" (Z. 4922). Der eine Skip ist ReceiptShareExtensionTests (Z. 3737), designbedingt (braucht scripts/run-share-extension-uitest.sh), nicht aus diesem Ticket. Beide neuen Tests laufen im Gesamtlauf und sind gruen (Z. 4204 und 4319, ShoppingRouteLearningUITests); ShoppingRouteTests 27 und die uebrigen Klassen gruen.
- attempts/: rote Zwischenlaeufe offen dokumentiert (Kaltstart-Flakes a-run1, c-run1; Testlaeufer-Haenger "The test runner hung before establishing connection" in b-run1 und full-run1-unit-runner-hung.txt, Issue #63). Der gruene Gesamtlauf ist ein spaeterer, vollstaendiger Lauf; der Haenger wurde nicht verschleiert.
- Kommentar am slowGap (RestockUITests/ShoppingRouteLearningUITests.swift:17-21): "Drei von drei gilt nur fuer Test A; Test B kam in dieser Messung nur in zwei Laeufen bis zum Abhaken, im dritten setzte der erste Start aus (Kachel nicht gefunden)". Das deckt sich mit den Artefakten (a-run1 Test B rot, a-run2 und Endlauf gruen). Der Kommentar entspricht jetzt der Wahrheit. Die Testlogik ist unveraendert (Diff gegenueber HEAD nur 5 Zeilen, Kommentar).
- Produktivdateien: sha256 von Store.swift (03fb814a...), SmartCartApp.swift (dd976c92...) und ShoppingRoute.swift (da0be6ad...) sind identisch mit dem Stempel aus Runde 2; Produktiv-Diff weiter +22/-2 Zeilen, ShoppingRoute.swift gegenueber HEAD unveraendert. Nur die Testdatei-Hash hat sich durch den Kommentar geaendert (erwartet).

Restrisiko (kein Befund): Test B bleibt ein seltener Kaltstart-Flake (1 von 5 Gesamtlaeufen der Klasse in der Messung, nie falsch gruen); im Kommentar ehrlich benannt.

Confirmation:
  AC: AC-1
  Code reference: SmartCart/SmartCartApp.swift:287
  Evidence: Seed ohne gelerntes Modell; Test A/B pruefen Apfel, Brot, Gouda (gruen), RED-Lauf zeigte vorher Gouda, Brot, Apfel.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/SmartCartApp.swift:288
  Evidence: Schleife mit where learned, ohne Argument unveraendert; ShoppingRouteUITests 6/6 gruen, auch im Gesamtlauf (Z. 4910).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:105
  Evidence: Haken Gouda, Brot, Apfel mit 2,1 s, Neustart Offset 31, Reihenfolge Gouda, Brot, Apfel; 3/3 Klassenlaeufe und Gesamtlauf gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:107
  Evidence: waitForOrder Ausgangslage vor den Haken.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:119
  Evidence: Haken ohne Abstand, Neustart, Reihenfolge unveraendert; Mutationsprobe laesst den Test scheitern.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:65
  Evidence: echte Haken-Buttons der Zellen; nur Seed per Argument.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:28
  Evidence: tearDown mit Clear-Argument, removeRouteData im Clear-Pfad; Gesamtlauf mit allen Klassen gruen (keine Wechselwirkung).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Models/Store.swift:271
  Evidence: Offset nur als Default von finalizeStaleTrip(now:); Unit-Test RouteClock (|now - Date()| < 1 s) im Gesamtlauf gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Models/Store.swift:726
  Evidence: Argument-Lesen in #if DEBUG, Release-Build SUCCEEDED, Seeds in SmartCartApp.swift innerhalb #if DEBUG (Z. 28-44).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/SmartCartApp.swift:38
  Evidence: Gesamtlauf ohne -only-testing: 434 Unit (0 Failures) und 56 UI (1 designbedingter Skip, 0 Failures), TEST SUCCEEDED, beide neuen Tests enthalten (test-full-run-output.txt Z. 1200, 4204, 4319, 4912, 4922).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:21
  Evidence: drei aufeinanderfolgende gruene Klassenlaeufe (test-class-3runs-output.txt, je 2 Tests, 0 Failures, TEST SUCCEEDED); Kommentar am slowGap praezisiert und wahrheitsgemaess.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/SmartCartApp.swift:275
  Evidence: Vorbereitung (Seed-Argument, Offset-Argument, Tests) vorhanden und im Lauf bewiesen; der Durchlauf-Nachweis selbst liegt beim Orchestrator.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Models/ShoppingRoute.swift:151
  Evidence: Datei unveraendert gegenueber HEAD; 4 Dateien, Produktiv-Diff +22/-2.
  Status: CONFIRMED

Confirmation:
  AC: AC-8 und AC-9 (Produktivdatei Store.swift, Runde 3)
  Code reference: SmartCart/Models/Store.swift:742
  Evidence: Hash unveraendert seit Runde 2.
  Status: CONFIRMED

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Befunde F001 und F002 sind durch Belege behoben: drei aufeinanderfolgende gruene Klassenlaeufe und ein vollstaendiger Gesamtlauf (434 Unit + 56 UI, 0 Failures).
Tests: 434 Unit + 56 UI passed, 0 failed (1 designbedingter Skip, Share-Extension)
Edge cases: alle geprueft, keine gebrochen
Regressions: keine gefunden
Checklist: 13/13 Punkte bewiesen

## Geprüfte Dateien

- sha256:bc63de078a20d73a90207d170213e5ee871f615e2bae64b108144bd7255df1b9  RestockUITests/ShoppingRouteLearningUITests.swift
- sha256:da0be6ade18f29163f50fcbcc8dbf422bdf5efc9c62a4242cbf94f48daad246e  SmartCart/Models/ShoppingRoute.swift
- sha256:03fb814ac65e4805ae5d4d8b5c5805585d0ad523408a3559d6797483b888ba7b  SmartCart/Models/Store.swift
- sha256:dd976c92a761d1dbd5eae8b80c33de15670745806792b60f6a2edafe70a4b49a  SmartCart/SmartCartApp.swift
