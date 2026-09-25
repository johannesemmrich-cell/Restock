# Adversary-Dialog: feat-12-destatis-preise

Spec: `docs/specs/models/price-estimator-category-fallback.md`
Fokus: Issue #12 - 12 der 26 Kategorie-Pauschalpreise in `PriceEstimator.estimate`
(`SmartCart/Models/ShoppingItem.swift`, `switch category`) kollidierten exakt; alle 26 Werte
sollen danach paarweise verschieden sein, `specificPrices` und der `default`-Fall unveraendert.

### Runde 1

### Frage 1 (Scope/Diff)

Frage: Aendert der Commit wirklich nur die 12 im Spec genannten Zahlenwerte, sonst nichts?

Beweis: Diff des Commits zeigt einen Hunk innerhalb des `switch`-Blocks (Zeilen 303-329), 12
Aenderungspaare - exakt die 12 in der Spec-Tabelle gelisteten Kategorien mit exakt den dort
genannten alten/neuen Werten (Backwaren 2.00 zu 2.20, Gewuerze & Backen 2.00 zu 3.20, Konserven
2.00 zu 1.70, Lebensmittel 2.50 zu 2.90, Reinigung 3.50 zu 3.90, Kuechenausstattung 8.00 zu
9.50, Elektronik 10.00 zu 14.00, Textilien 8.00 zu 7.00, Dekoration 6.00 zu 6.50, Garten 8.00 zu
7.50, Sanitaer 10.00 zu 11.50, Baumaterial 12.00 zu 13.50). Kein anderer Code-Bereich, kein
`unitDivisor`, kein `maxPlausibleLineTotal`, keine andere Datei betroffen (nur ShoppingItem.swift
+ Testartefakt-Textdatei im Commit-Stat). Der vorherige Commit im Log ist eine unabhaengige,
bereits gemergte Aenderung (STORNO-Fix), nicht Teil dieses Workflows.

Bewertung: AKZEPTIERT (Punkt 2 "Output unveraendert in Mechanik" und Scope "einzige Datei, ~12
LoC" bewiesen).

### Frage 2 (AC-1, alle 26 Werte paarweise verschieden)

Frage: Sind die 26 resultierenden Werte tatsaechlich alle unterschiedlich - nicht nur laut
Spec-Tabelle, sondern im tatsaechlich compilierten Code?

Beweis: Direkt aus dem Code gelesene 26 Literale in einer eigenen Python-Pruefung gegen ein
Set geprueft: 26 Werte, 26 eindeutige Werte. Zusaetzlich lieferte der selbst ausgefuehrte
Testlauf (xcodebuild test -only-testing:RestockTests, Simulator Restock-Validate
8F696920-4B9A-40A7-96F0-7697BE887CC7) testAllCategoryFallbackPricesAreDistinct als PASSED -
dieser Test ruft PriceEstimator.estimate fuer alle 26 Namen aus AssignmentService.categoryOrder
zur Laufzeit auf, nicht nur eine statische Werteliste.

Bewertung: AKZEPTIERT.

### Frage 3 (AC-2 bis AC-6, konkrete Gruppen-Werte)

Frage: Stimmen die in der Spec genannten Einzelwerte exakt mit dem zurueckgegebenen Double?
ueberein - nicht nur ungefaehr?

Beweis: Testdatei RestockTests/PriceEstimatorCategoryFallbackTests.swift enthaelt fuer jede
Gruppe XCTAssertEqual auf die exakten Literale (nicht nur XCTAssertNotEqual), z. B. Zeile
44-47 (Milchprodukte-Gruppe), 61-64 (Babybedarf-Gruppe), 77-79 (Elektronik-Gruppe), 90-104 (die
drei Restpaare). Eigener Testlauf zeigt alle sechs zugehoerigen Testfaelle
(testObstUndGemueseDiffersFromLebensmittel, testMilchproduktGruppeIstDifferenziert,
testBabybedarfGruppeIstDifferenziert, testElektronikGruppeIstDifferenziert,
testVerbleibendePaareSindDifferenziert) als PASSED. Da unitDivisor(for: "") unveraendert 1.0
zurueckgibt (Zeile 214-222, ausserhalb des Diffs), sind das exakte Euro-Werte ohne
Rundungsartefakt.

Bewertung: AKZEPTIERT - aber Runde 1 zu frueh fuer Gesamtverdikt (AC-7/AC-8 noch offen, s.
Regel "keine vorzeitige Konvergenz").

### Runde 2

### Frage 4 (AC-7, Regression specificPrices)

Frage: Bleibt specificPrices wirklich unangetastet, und beweist der vorgelegte Test das
tatsaechlich - oder testet er zufaellig nur den Kategorie-Zweig?

Beweis: Der Diff enthaelt keinen Hunk in den Zeilen 251-284 (specificPrices-Array) - nur der
switch category-Block ab Zeile 303 ist betroffen. Gelesener Code (Zeile 257:
(["milch", "milk"], 1.20)) bestaetigt: "Milch" mappt weiterhin auf 1,20 Euro. Der Test
testSpecificPricesBleibenUnveraendert verwendet bewusst category: "Sonstiges" (kein switch-Fall,
faellt in default: perUnit = nil) - das beweist zwingend, dass der zurueckgegebene Preis (1.20)
aus der specificPrices-Schleife stammt, nicht aus dem Kategorie-Fallback, da Letzterer fuer
"Sonstiges" nil liefert. Eigener Testlauf: PASSED. Nachgefragt, ob das nicht zu schwach ist (nur
ein Keyword von 32 getestet): Code-Lesung zeigt, dass keine der 32 specificPrices-Zeilen im
Diff veraendert wurde (identischer Bytebereich vor und nach dem Fix) - ein Stichprobentest auf
1 von 32 unveraenderten Zeilen ist hier ausreichend, weil der Diff selbst schon beweist: 0 von
32 Zeilen wurden beruehrt.

Bewertung: AKZEPTIERT (nach Nachfrage zur Stichprobenstaerke - durch Diff-Beleg abgesichert,
nicht nur durch den einen Test).

### Frage 5 (AC-8, default-Fall/unbekannte Kategorie)

Frage: Liefert eine nicht in categoryOrder enthaltene Kategorie wirklich weiterhin nil - auch
nach der Werteaenderung, und nicht etwa versehentlich einen der 12 neuen Werte durch einen
Copy-Paste-Fehler im switch?

Beweis: Diff zeigt default: perUnit = nil als letzte, unveraenderte Zeile des switch-Blocks
(kein Aenderungsmarker davor). Test testUnbekannteKategorieLiefertNil ruft mit category:
"Nicht existierende Kategorie" auf und erwartet XCTAssertNil - PASSED im eigenen Lauf.
Nachgefragt: Ist "Nicht existierende Kategorie" wirklich nicht in categoryOrder? Gegen die 26
in AssignmentService+Category.swift:219-225 gelistete Namen abgeglichen (gelesen) - kein
Treffer, echte Negativprobe.

Bewertung: AKZEPTIERT.

### Frage 6 (Skeptiker: Testlauf-Fallen)

Frage: Ist der gruene Testlauf echt (nicht der "Null-Test"-Fallstrick aus vorherigen
Workflows: "Executed 0 tests ... TEST SUCCEEDED" nach einem Abbruch)?

Beweis: Eigener, frischer Lauf (nicht das vom Commit mitgelieferte Artefakt) via xcodebuild
-only-testing:RestockTests test auf Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7),
Output unter docs/artifacts/feat-12-destatis-preise/adversary-test-output.txt. Summary-Zeile:
"Executed 179 tests, with 0 failures (0 unexpected) in 2.009 (2.322) seconds", "** TEST
SUCCEEDED **". Alle 8 neuen Testfaelle aus PriceEstimatorCategoryFallbackTests einzeln als
PASSED aufgefuehrt, zusaetzlich PriceProvenanceMigrationTests (7 Tests) und
ReceiptParserPriceTests (19 Tests) - beide von der Spec als Regressions-Pflichtsuiten benannt -
beide vollstaendig PASSED. Keine "Executed 0 tests"-Zeile, keine Abbruch-/Retry-Marker.

Bewertung: AKZEPTIERT - echter, vollstaendiger Lauf, kein Fehlalarm-Gruen.

### Frage 7 (Skeptiker: neue Kollision durch die neuen Werte selbst eingefuehrt?)

Frage: Koennte einer der 12 neuen Werte zufaellig mit einem der 14 unveraenderten Anker-Werte
kollidieren (neue Kollision statt Aufloesung)?

Beweis: Die Python-Pruefung aus Frage 2 deckt genau das ab - alle 26 Werte (12 neue + 14
unveraenderte) wurden gemeinsam in ein Set geprueft, nicht nur die 12 neuen gegeneinander.
Ergebnis bereits bestaetigt: 26/26 eindeutig. Zusaetzlich bestaetigt
testAllCategoryFallbackPricesAreDistinct das zur Laufzeit ueber alle 26 Kategorien.

Bewertung: AKZEPTIERT.

## Structured Findings

Keine Findings - keine Abweichung von der Spec festgestellt, keine Regression, keine
Testabdeckungsluecke identifiziert (alle 8 spezifizierten Tests existieren, sind an genau die
im Test Plan genannten AC gebunden, und laufen gruen).

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: RestockTests/PriceEstimatorCategoryFallbackTests.swift:13-23
  Evidence: testAllCategoryFallbackPricesAreDistinct - ruft PriceEstimator.estimate fuer alle
    26 Namen aus AssignmentService.categoryOrder auf, prueft Set(prices).count == prices.count.
    PASSED im eigenen Lauf (docs/artifacts/feat-12-destatis-preise/adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Models/ShoppingItem.swift:303,313
  Evidence: "Obst & Gemuese" = 2.50/divisor, "Lebensmittel" = 2.90/divisor (divisor=1 bei
    unit=""). testObstUndGemueseDiffersFromLebensmittel PASSED.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/ShoppingItem.swift:305,306,309,310
  Evidence: Milchprodukte 2.00, Backwaren 2.20, Gewuerze & Backen 3.20, Konserven 1.70 - alle
    vier paarweise verschieden. testMilchproduktGruppeIstDifferenziert PASSED.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Models/ShoppingItem.swift:315,317,319,323
  Evidence: Babybedarf 8.00, Kuechenausstattung 9.50, Textilien 7.00, Garten 7.50 - alle vier
    paarweise verschieden. testBabybedarfGruppeIstDifferenziert PASSED.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Models/ShoppingItem.swift:318,321,326
  Evidence: Elektronik 14.00, Spielzeug 10.00, Sanitaer 11.50 - alle drei paarweise
    verschieden. testElektronikGruppeIstDifferenziert PASSED.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Models/ShoppingItem.swift:308,314,316,320,324,327
  Evidence: Tiefkuehlkost 3.50/Reinigung 3.90, Medikamente 6.00/Dekoration 6.50, Werkzeug
    12.00/Baumaterial 13.50 - jedes Paar unterscheidet sich.
    testVerbleibendePaareSindDifferenziert PASSED.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Models/ShoppingItem.swift:251-284,257
  Evidence: specificPrices-Array im Diff unveraendert (kein Hunk in Zeilen 251-284); Keyword
    "milch"/"milk" liefert weiterhin 1.20. testSpecificPricesBleibenUnveraendert nutzt bewusst
    category:"Sonstiges" (default-Fall), um zu beweisen, dass der Preis aus specificPrices
    stammt. PASSED.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Models/ShoppingItem.swift:329
  Evidence: default: perUnit = nil unveraendert (kein Diff-Hunk an dieser Zeile).
    testUnbekannteKategorieLiefertNil (category: "Nicht existierende Kategorie", nicht in
    AssignmentService.categoryOrder enthalten) liefert nil. PASSED.
  Status: CONFIRMED

## VERDICT

Alle 8 Acceptance Criteria sind durch eigene Testlaeufe (nicht nur das mitgelieferte Artefakt)
und durch Diff-Lektuere bewiesen. Der Diff ist exakt auf die 12 in der Spec genannten Werte
beschraenkt (Scope-Treue), keine andere Funktion, keine andere Datei betroffen. Die
Gesamtsuite (179 Tests) laeuft vollstaendig gruen, inklusive der beiden von der Spec explizit
als Regressions-Pflicht benannten Suiten (PriceProvenanceMigrationTests,
ReceiptParserPriceTests). Keine neue Kollision durch die 12 neuen Werte eingefuehrt (26/26
paarweise verschieden, verifiziert sowohl statisch als auch zur Laufzeit).

===========================================
VERDICT: VERIFIED
===========================================
Tests: 179 passed, 0 failed (eigener Lauf, Restock-Validate Simulator,
  docs/artifacts/feat-12-destatis-preise/adversary-test-output.txt)
Edge cases: AC-7 (Regression specificPrices) und AC-8 (default-Fall) - beide gezielt
  nachgefragt und durch Diff + gezielten Negativtest bestaetigt, nicht nur behauptet.
Regressionen: Keine - PriceProvenanceMigrationTests (7/7) und ReceiptParserPriceTests (19/19)
  vollstaendig gruen im selben Lauf.
Checklist: 8/8 Acceptance Criteria CONFIRMED, 0 Findings.

## Geprüfte Dateien

- sha256:d8cc7adc2728830bf1aa98cd45b478e6c586f372f5ae17d878c1cb5cbe4d32c3  RestockTests/PriceEstimatorCategoryFallbackTests.swift
- sha256:a03ee96239ce929ddf3ca471616566adba9cfb8b5dea00ffb8fa8e020e150b28  SmartCart/Models/ShoppingItem.swift

## Geprüfte Dateien

- sha256:d8cc7adc2728830bf1aa98cd45b478e6c586f372f5ae17d878c1cb5cbe4d32c3  RestockTests/PriceEstimatorCategoryFallbackTests.swift
- sha256:a03ee96239ce929ddf3ca471616566adba9cfb8b5dea00ffb8fa8e020e150b28  SmartCart/Models/ShoppingItem.swift
