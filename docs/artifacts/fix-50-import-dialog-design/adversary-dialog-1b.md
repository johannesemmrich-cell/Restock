# Adversary-Prüfdialog 1b — fix-50-import-dialog-design (Issue #50, Paket 1b)

- **Datum:** 2026-09-27
- **Prüfgegenstand:** Paket 1b (Befund F002 aus dem ersten Prüfdialog) sowie die
  Widerspruchsfreiheit der Hauptspec zu F001 (Folge-Issue #66)
- **Eigener Prüflauf:** `docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b.txt`
  (31 Tests, 0 Fehler, `** TEST SUCCEEDED **`); der Fehlversuch davor ist als
  `adversary-test-output-1b-fail1-issue63.txt` aufbewahrt
- **Eigene Probe:** `docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift`

---

### Runde 1 — Angriffe auf die Umsetzung von F002

#### Angriff 1 — „Andere Leerraum-Arten umgehen den Guard"

Behauptung der Spec: Regel 10 und Regel 11 benutzen denselben Leer-Begriff
(`trimmingCharacters(in: .whitespaces)`), deshalb kann keine Position entstehen, die angehakt
mitzählt und beim Speichern still verworfen wird.

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:499
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:106

Beide Stellen trimmen wörtlich identisch. Den Zeichenumfang habe ich gemessen statt vermutet:

```
space U+0020: ws-leer=true    tab U+0009: ws-leer=true      nbsp U+00A0: ws-leer=true
enQuad U+2000: ws-leer=true   narrowNBSP U+202F: ws-leer=true   ideographic U+3000: ws-leer=true
zeroWidth U+200B: ws-leer=true
newline U+000A: ws-leer=false  crlf: ws-leer=false   vtab U+000B: ws-leer=false
```

Code reference: docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift

Bewertung: AKZEPTIERT (für die Asymmetrie-Frage). `.whitespaces` deckt mehr ab als erwartet
(Tabulator, geschütztes Leerzeichen, alle Zs-Leerzeichen, sogar U+200B). Entscheidend ist aber
nicht der Umfang, sondern die Gleichheit beider Tests: weil Regel 10 und Regel 11 denselben
Ausdruck benutzen, gibt es per Konstruktion keinen Namen, den Regel 10 durchlässt und Regel 11
verwirft. Die in AC-18 verbotene „still verschwindende Position" ist damit für JEDEN String
ausgeschlossen, nicht nur für Leerzeichen.

NACHFRAGE (Restfrage): Ein Name aus einem reinen Zeilenumbruch (U+000A) oder Vertikaltabulator
passiert BEIDE Guards und wird gespeichert — optisch namenlos, aber nicht „still verworfen".
Siehe Befund F104.

#### Angriff 2 — „`isSavable` ist asymmetrisch zu Regel 10"

Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:103

`isSavable` = `isIncluded && price > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty`.
Kopfzeile, Summe und `canSave` hängen dagegen NUR an `isIncluded`:

Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:224
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:508

Die Divergenz Kopfzeile/Summe gegen `isSavable` besteht weiterhin (auch für `price == 0`,
vorbestehend, nicht Gegenstand von Paket 1b) — schädlich ist sie nur, wenn ein Name existiert, den
Regel 10 durchlässt und Regel 11 verwirft. Angriff 1 zeigt: den gibt es nicht.

Bewertung: AKZEPTIERT. Für den Namens-Teil ist die Asymmetrie geschlossen.

#### Angriff 3 — „`previousSelection`/`originalName` kann selbst leer sein"

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:500

Der Verteidigungs-Rückfall schreibt `line.originalName`, wenn der festgehaltene Name getrimmt leer
ist. Die Spec behauptet: „der Bontext ist nie leer, sobald eine Karte überhaupt existiert." Am
Parser belegt, nicht geglaubt:

- `parseClassic`: `rawName` wird getrimmt, muss `count >= 2` erfüllen und darf nicht nur aus
  Ziffern/Leerzeichen bestehen — ein Name aus reinem Leerraum fällt heraus.
  Code reference: SmartCart/Services/ReceiptParserService.swift:536
- Der schwebende Name verlangt Buchstaben und `count >= 2`.
  Code reference: SmartCart/Services/ReceiptParserService.swift:580
- Euro-Pfad: der Name ist „erster Chunk mit Buchstaben", Chunks sind getrimmt und nicht leer.
  Code reference: SmartCart/Services/ReceiptParserService.swift:770
- `cleanEuroName` fällt am Ende auf `tidy(raw)` zurück, wenn das Bereinigen den Namen unbrauchbar
  macht — die Buchstaben kommen dadurch zurück.
  Code reference: SmartCart/Services/ReceiptParserService.swift:868

Bewertung: AKZEPTIERT. Die Spec-Behauptung ist belegt; `line.originalName` trägt immer mindestens
einen Buchstaben, der Verteidigungs-Rückfall kann keinen leeren Namen erzeugen.

#### Angriff 4 — „Der UI-Test beweist zu wenig (Kopfzeile/Summe)"

Code reference: RestockUITests/ReceiptReviewUITests.swift:947

Der Test prüft das Bedienhilfen-Label des Häkchens, nicht die Kopfzeile und nicht die Summe —
AC-18 verspricht aber beides. NACHFRAGE.

Nachgeprüft: Kopfzeile und Summe zählen ausschließlich `isIncluded`, das Verwerfen beim Speichern
hängt an `isSavable`. Ist `line.name` nach dem Rückfall „Frische Vollmilch 3,5 %" — genau das prüft
das Label —, dann ist `isSavable` wahr und die Position wird gespeichert; eine Abweichung zwischen
„zählt mit" und „wird gespeichert" ist ausgeschlossen. Die Kette ist vollständig, weil der
Leer-Begriff in beiden Regeln identisch ist (Angriff 1) und `isSavable` mit „   " als Name
unit-getestet ist.

Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:615
Code reference: RestockTests/ReceiptScannerReResolutionTests.swift:52

Bewertung: AKZEPTIERT, kein eigener Befund. Dass kein Test die Kopfzeilen-Zahl direkt abfragt,
bleibt eine Lücke im Nachweis-Komfort, keine Lücke in der Aussage.

#### Angriff 5 — „Es gibt einen zweiten Weg zu einem Namen aus Leerzeichen"

Code reference: docs/specs/views/receipt-review-card.md:537

Die Spec erklärt Regel 11 zur „Verteidigung in der Tiefe" mit der Begründung, der EINZIGE bekannte
Weg (das Feld „Anderer Name …") sei geschlossen; als Restrisiko nennt sie nur *künftige* Änderungen
an den Services. Gegenprobe an der KI-Stufe: `resolve` übernimmt die Modellantwort ungeprüft als
Namen, die einzige Prüfung ist `sanitize`.

Code reference: SmartCart/Services/ReceiptResolutionService.swift:175
Code reference: SmartCart/Services/ReceiptParserService.swift:1327

`sanitize` trimmt ERST Leerraum, DANN Anführungszeichen, und prüft danach nicht erneut auf
Leerraum. Gemessen:

```
sanitize(quote+space+quote) = Optional(" ")     <-- kommt durch
sanitize(single space)      = nil
```

Antwortet das Modell `" "`, liefert `expand` einen Namen aus einem Leerzeichen,
`mergeAIReresolution` schreibt ihn in `line.name`, die Position zählt in Kopfzeile und Summe mit —
und `isSavable` verwirft sie beim Speichern still. Genau das Symptom von F002, über einen zweiten
Weg.

Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:130

Bewertung: NACHFRAGE, Befund F103 (MEDIUM). Die Wirkung ist heute durch Regel 11 auf „Position
verschwindet stillschweigend" begrenzt (kein namenloser Kaufdatensatz), und die Auslösung verlangt
eine pathologische Modellantwort. Die Spec-Aussagen „entsteht nirgends mehr" bzw. „einziger
bekannter Weg" sind damit aber widerlegt, nicht nur unscharf.

---

### Runde 2 — Angriffe auf die Spec (der eigentliche Prüfauftrag)

#### Angriff 6 — „Der Selbstwiderspruch zu F001 ist noch da"

Das erste Urteil war AMBIGUOUS, weil Invariante 6 `mergeAIReresolution` als abgedeckten
Zuweisungsweg nennt und „genau eine markiert" verspricht, während die Known Limitations dasselbe
Symptom freigeben. Ich habe den heutigen Wortlaut gelesen, nicht das Protokoll geglaubt.

Code reference: docs/specs/views/receipt-review-card.md:600

> „Gilt für jede Zeile, deren `matchedItemID`/`resolvedByAI` aus einem der bekannten
> Zuweisungswege stammen (`applySelection`, `applyCustomName`/`applyCustomNameOrFallback`, oder
> direkt aus `ReceiptResolutionService.resolve` über `mergeAIReresolution`) …"

Code reference: docs/specs/views/receipt-review-card.md:1081

> „Löst die Namensauflösung eine Position nachträglich auf einen Namen auf, der wörtlich einem
> ihrer eigenen Vorschläge entspricht (`resolvedByAI == true`, `matchedItemID == nil`) … die Karte
> steht dann ganz OHNE markierte Zeile, obwohl `line.name` nicht leer ist."

Der F001-Zustand entsteht genau über `mergeAIReresolution` — also über einen von Invariante 6
namentlich EINGESCHLOSSENEN Weg. Der Schlusssatz der F001-Grenze („Solange gilt die Einschränkung
von Invariante 6 und AC-14 auf die bekannten Zuweisungswege unverändert weiter") schließt F001
deshalb nicht aus, sondern ein: die Einschränkung, auf die er verweist, nennt
`mergeAIReresolution` als abgedeckt.

Am Code nachgestellt, dass die Grenze real ist und Invariante 6 mehr verspricht, als die
Implementierung hält:

- `mergeAIReresolution` setzt `resolvedByAI = true` und `matchedItemID = r.matchedItemID` (für eine
  KI-Zeile `nil`).
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:130
- Die Dedup-Regel entfernt die separate KI-Zeile, wenn ein Listen-Treffer denselben Namen trägt —
  belegt durch den grünen Bestandstest.
  Code reference: RestockTests/ReceiptReviewCardTests.swift:214
- `isSelected(.listMatch)` verlangt `!line.resolvedByAI` UND
  `line.matchedItemID == suggestion.itemID`; beides trifft nicht zu, und `.currentName` fügt
  Regel 5 nicht ein, weil ein Kandidat namensgleich ist.
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:369

Zusätzlich verspricht der Reichweiten-Satz zu Regel 9 unverändert mehr, als die Spec an anderer
Stelle einräumt: als Ausnahme wird dort NUR der leere Name genannt; F001 (nicht-leerer Name, keine
Markierung) kommt nicht vor.

Code reference: docs/specs/views/receipt-review-card.md:410
Code reference: docs/specs/views/receipt-review-card.md:861

Bewertung: NACHFRAGE, Befund F101 (HIGH). Der Selbstwiderspruch, der das erste Urteil auf
AMBIGUOUS gebracht hat, steht wortgleich noch im Dokument. Die F001-Grenze ist jetzt ausführlich
beschrieben — aber die Invariante, die sie widerlegt, ist nicht angepasst. Ein Leser von
Invariante 6 oder AC-14 erkennt die Grenze nicht, er liest das Gegenteil.

#### Angriff 7 — „Das PO-Briefing verspricht, was F001 widerlegt"

Code reference: docs/briefings/fix-50-import-dialog-design.md:14

> „Jede Bon-Position zeigt sichtbar genau einen markierten Namen, auch nach nachträglicher
> Namensauflösung."

Und als Definition of Done (Zeile 18): „Jede Position trägt beim Öffnen aus einer geteilten App
einen markierten Namen; …"

F001 ist exakt der Fall „nach nachträglicher Namensauflösung, keine Markierung". Die kritischen
Anmerkungen nennen den offenen Fall korrekt — die DoD, auf die sich eine Freigabe stützt, behauptet
das Gegenteil.

Bewertung: NACHFRAGE, Befund F102 (HIGH).

#### Angriff 8 — „Regel 11 ist gar keine reine Verteidigung"

Code reference: docs/specs/views/receipt-review-card.md:453

Geprüft: Der Weg über das Feld ist tatsächlich geschlossen (Angriffe 1-3, eigener grüner Lauf). Ein
zweiter Weg existiert aber (Angriff 5, F103), und `@State customActive` fällt beim Zellen-Recycling
zurück — was die Spec selbst als Grund nennt, den Filter zu behalten. Die Einordnung „Verteidigung
in der Tiefe" ist im Ergebnis richtig (der Filter muss bleiben), die Begründung „einziger bekannter
Weg" ist zu stark.

Bewertung: TEILWEISE AKZEPTIERT, Rest siehe F103.

#### Angriff 9 — „Regel 9 hängt nur an `line.name` — Restlücke"

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:366

Ändert eine externe Auflösung nur `matchedItemID`/`resolvedByAI` und lässt den Namen byte-gleich,
feuert `.onChange(of: line.name)` nicht. Erreichbarkeit geprüft statt behauptet:
`linesNeedingAIReresolution` wählt nur Zeilen mit `name == originalName` und
`resolvedByAI == false`; für solche Zeilen liefert `resolve` garantiert `matchedItemID == nil` — der
`needsAI`-Zweig wird nur erreicht, wenn der `completedItemCandidates`-Zweig nicht griff, und der
Nachfass-Block prüft bei unverändertem Namen exakt dieselbe Bedingung erneut.

Code reference: SmartCart/Services/ReceiptResolutionService.swift:132

Vor dem Merge war deshalb entweder `.currentName` markiert (bleibt markiert, `isSelected` prüft
dort `resolvedByAI` nicht) oder gar nichts (vorbestehende, dokumentierte Namensgleichheits-Lücke).
Ein neuer, undokumentierter Fall entsteht nicht.

Bewertung: AKZEPTIERT. Kein eigener Befund; die Restlücke fällt mit F001 zusammen.

#### Angriff 10 — „Test-Plan-Häkchen ohne Deckung"

Stichprobe von sechs der neun umgestellten Punkte (verlangt waren vier):

1. AC-4 (Issue #37), drei Kandidaten auf zwei plus `.currentName`, vier Optionen:
   `testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches` prüft die Optionszahl, dass
   `options[0]` der geltende Name ist und dass „Vollmilch" entfällt — deckungsgleich mit dem Punkt.
   Code reference: RestockTests/ReceiptReviewCardTests.swift:171
2. Regression (Issue #37), leerer Name:
   `testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches` prüft drei Treffer plus
   eigenen Namen und dass keine `.currentName`-Zeile entsteht.
   Code reference: RestockTests/ReceiptReviewCardTests.swift:193
3. AC-4, Ergänzung am Bestandstest: die Vorauswahl-Assertion steht wirklich in
   `testFiveSuggestionsAreCappedToThreeListMatches`, in Zeile 163. Die Spec zitiert :165, zwei
   Zeilen daneben — Zitat-Ungenauigkeit, keine fehlende Deckung.
   Code reference: RestockTests/ReceiptReviewCardTests.swift:163
4. AC-16 (`isSavable`): `testIsSavableRejectsLineWithEmptyName` prüft den leeren UND den
   Leerzeichen-Namen; in meinem eigenen Lauf bestanden.
   Code reference: RestockTests/ReceiptScannerReResolutionTests.swift:52
5. AC-15 (UI): `testClearingCustomNameFieldKeepsPreviousItemName` existiert und ist in
   green-run2-ui.txt und green-run3b-suite.txt als bestanden protokolliert.
   Code reference: RestockUITests/ReceiptReviewUITests.swift:860
6. AC-13/AC-14 (UI): `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` ist in
   green-run3b-suite.txt als bestanden protokolliert.
   Code reference: docs/artifacts/fix-50-import-dialog-design/green-run3b-suite.txt

Alle zehn geprüften Testnamen (einschließlich der drei neuen) stehen je genau einmal als bestanden
in green-run3b-suite.txt.

Ausdrücklich gewürdigt: Der Punkt „AC-4, zweite Assertion" ist NICHT als erfüllt gehäkelt, sondern
als offen ausgewiesen und nach #66 verschoben, mit nachprüfbarer Begründung — die Markierungs-Logik
ist eine private Funktion der View. Gegenprobe in der Unit-Suite: kein einziges Vorkommen des
Namens der Markierungs-Funktion in der Testdatei. Die Begründung stimmt.

Bewertung: AKZEPTIERT. Kein Häkchen ohne Deckung.

#### Angriff 11 — „Der Abbruch in green-run3-suite.txt verdeckt einen echten Fehlschlag"

Code reference: docs/artifacts/fix-50-import-dialog-design/green-run3-suite.txt

Im Protokoll läuft die UI-Suite vollständig durch (19 Tests, 0 Fehler), danach steht
„Testing failed: Restock (7513) encountered an error (The test runner hung before establishing
connection.)" und TEST FAILED — die Unit-Suite hat 0 Tests ausgeführt, es gibt keinen
Absturzbericht. Punktgenau das Erkennungsmerkmal von Issue #63.

Stärkster Beleg: Ich habe den Abbruch in meinem eigenen ersten Prüflauf reproduziert. Bei
gebootetem Fremd-Simulator (iPhone 17 neben Restock-Validate) endete mein Lauf mit einem
fehlgeschlagenen und null bestandenen Tests und derselben Fehlermeldung, ohne einen einzigen
ausgeführten Test.

Code reference: docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b-fail1-issue63.txt

Nach dem dokumentierten Rezept (Fremd-Simulator herunterfahren, Restock-Validate neu starten) lief
derselbe Befehl mit identischem Code durch: 31 Tests, 0 Fehler, TEST SUCCEEDED.

Code reference: docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b.txt

Bewertung: AKZEPTIERT. Umgebungsproblem, kein Produktfehler — nicht geglaubt, sondern selbst
ausgelöst und selbst behoben. Einschränkung: die Ursache „parallel gebooteter Fremd-Simulator"
steht nicht IM Protokoll green-run3-suite.txt, sie ist eine Zuschreibung; mein eigener Lauf stützt
sie.

#### Angriff 12 — „green-run3b-suite.txt war kein vollständiger Lauf"

Code reference: docs/artifacts/fix-50-import-dialog-design/green-run3b-suite.txt

- 271 Unit-Tests mit 0 Fehlern und 19 UI-Tests mit 0 Fehlern, genau ein TEST SUCCEEDED, kein
  TEST FAILED.
- Keine Übersprünge: die vier Treffer auf „skipped" sind Teile von Test-NAMEN
  (`testStornoStaysPendingAcrossSkippedConfirmationLine`,
  `testItemWhoseHabitEndsBeforeDeliveryIsSkipped`), kein XCTSkip.
- Keine Wiederholungsläufe, kein Neustart nach unerwartetem Ende, keine Liste fehlgeschlagener
  Tests.
- 30 Unit-Test-Klassen plus ReceiptReviewUITests.

Bewertung: AKZEPTIERT.

#### Angriff 13 — „RED und GREEN betreffen nicht dieselben Testfunktionen"

Code reference: docs/artifacts/fix-50-import-dialog-design/test-red-unit-1b.txt

RED-Unit: 31 Tests, 4 Fehler; alle vier sind Zusicherungen, keine Compilerfehler, verteilt auf
genau die zwei neuen Funktionen — eine Zusicherung in
`…FallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly` (Ist-Wert ein Leerzeichen statt
„BTR") und drei in `…RestoresPreviousSelectionOnWhitespaceOnlyName` (Name, `matchedItemID`,
`resolvedByAI`) — genau die drei Felder, die AC-18 verspricht.

Code reference: docs/artifacts/fix-50-import-dialog-design/test-red-ui-1b.txt

RED-UI: 19 Tests, 1 Fehler, in `testWhitespaceOnlyCustomNameKeepsPreviousItemName`, mit dem
Ist-Wert „Position übernehmen:  " — das Symptom von F002 im Klartext. Dieselben drei Funktionen
sind in green-run1-unit.txt, green-run2-ui.txt, green-run3b-suite.txt und in meinem eigenen Lauf
bestanden.

Bewertung: AKZEPTIERT. RED und GREEN deckungsgleich, RED ohne Compilerfehler.

#### Angriff 14 — „F001 ist doch angefasst worden"

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:497

Der Produktiv-Unterschied zum gesicherten Stand umfasst genau zwei geänderte Zeilen plus
Kommentar, beide im Eingangs-Guard und im Rückfall von `applyCustomNameOrFallback`.
`selectionOptions`, `isSelected`, `applySelection` und `mergeAIReresolution` sind unberührt;
`testAiSuggestionIsDroppedWhenAListMatchCarriesTheSameName` ist in meinem eigenen Lauf bestanden.

Bewertung: AKZEPTIERT. F001 unberührt, kein Regress.

### Bewiesene Punkte (abgehakt)

- [x] AC-18, Eingangs-Guard: reine Leerzeichen loesen denselben Rueckfall aus, alle drei Felder
- [x] AC-18, Verteidigungs-Rueckfall auf den Bontext (getrimmt geprueft)
- [x] AC-18, Bildschirm-Nachweis ueber das Haekchen-Label, mit RED-Beleg
- [x] AC-15 praezisiert: line.name nie leer oder reine Leerzeichen, Textfeld unangetastet
- [x] Regel 10 und Regel 11 benutzen denselben Leer-Begriff (am Code und gemessen)
- [x] F001 unberuehrt, Dedup-Bestandstest gruen im eigenen Lauf
- [x] Test-Plan-Integritaet: sechs Stichproben gedeckt, offener Punkt korrekt als offen gefuehrt
- [x] Nachweislage: 3b vollstaendig, Abbruch in run3 als Umgebungsproblem selbst reproduziert
- [x] Eigener Prueflauf gruen: 31 Tests, 0 Fehler, TEST SUCCEEDED

Nicht abgehakt und deshalb als Befund gefuehrt: Checklistenpunkt 3 (Widerspruchsfreiheit,
F101), das Freigabeversprechen im Briefing (F102) sowie Checklistenpunkt 4 nur teilweise (F103).

---

## Befunde

```
Finding:
  ID: F101
  Severity: HIGH
  Category: spec_violation
  Code reference: docs/specs/views/receipt-review-card.md:600
  Description: Invariante 6 nennt „direkt aus ReceiptResolutionService.resolve über
    mergeAIReresolution" weiterhin ausdrücklich als abgedeckten Zuweisungsweg und verspricht für
    solche Zeilen „genau eine Option ist markiert". Ebenso der Reichweiten-Satz zu Regel 9
    (Zeile 410), der als Ausnahme NUR den leeren Namen nennt, und AC-14 (Zeile 861).
  Spec requirement: Widerspruchsfreiheit — die Known Limitation F001 (Zeilen 1081-1093) beschreibt
    für genau diesen Weg (resolvedByAI == true, matchedItemID == nil, KI-Name gleich einem eigenen
    Vorschlag) eine Karte OHNE markierte Zeile bei nicht-leerem line.name.
  Conflict: Invariante 6 und AC-14 versprechen für den Weg mergeAIReresolution das, was F001 für
    genau diesen Weg ausschließt. Der Verweis in F001 („Solange gilt die Einschränkung von
    Invariante 6 und AC-14 auf die bekannten Zuweisungswege weiter") hebt den Widerspruch nicht
    auf, sondern verstärkt ihn: mergeAIReresolution IST ein bekannter Zuweisungsweg. Am Code
    belegt: ReceiptScannerView.swift:130 setzt den Zustand, ReceiptReviewCard.swift:369
    (isSelected für einen Listen-Treffer verlangt !resolvedByAI) verweigert die Markierung. Ein
    Leser erkennt die Grenze aus Invariante 6/AC-14 nicht — er liest dort das Gegenteil. Es ist
    derselbe Selbstwiderspruch, der im ersten Prüfdialog zu AMBIGUOUS geführt hat; der Wortlaut von
    Invariante 6 ist unverändert.
  Remediation: Invariante 6, AC-14 und den Reichweiten-Satz zu Regel 9 um die F001-Ausnahme
    ergänzen („… mit Ausnahme des als F001 (#66) beschriebenen Falls: löst die Auflösung auf einen
    Namen auf, der wörtlich einem eigenen Vorschlag entspricht, ist heute KEINE Zeile markiert")
    oder mergeAIReresolution aus der Aufzählung der abgedeckten Wege herausnehmen und dort auf #66
    verweisen.
```

```
Finding:
  ID: F102
  Severity: HIGH
  Category: spec_violation
  Code reference: docs/briefings/fix-50-import-dialog-design.md:14
  Description: „Was gebaut wird" lautet „Jede Bon-Position zeigt sichtbar genau einen markierten
    Namen, auch nach nachträglicher Namensauflösung"; die Definition of Done (Zeile 18) lautet
    „Jede Position trägt beim Öffnen aus einer geteilten App einen markierten Namen".
  Spec requirement: F001 (docs/specs/views/receipt-review-card.md:1081) hält für „nach
    nachträglicher Namensauflösung" ausdrücklich fest, dass die Karte OHNE markierte Zeile stehen
    kann, und ist per PO-Entscheidung NICHT Teil dieses Pakets.
  Conflict: Das Freigabedokument verspricht in Überschrift und DoD genau die Eigenschaft, die
    dieses Paket bewusst offen lässt. Dass die kritischen Anmerkungen den offenen Fall korrekt
    nennen, heilt eine falsche DoD nicht — die DoD ist der Satz, gegen den abgenommen wird.
  Remediation: „Was gebaut wird" und DoD auf das tatsächlich Erreichte einschränken und die
    Formulierung „auch nach nachträglicher Namensauflösung" streichen.
```

```
Finding:
  ID: F103
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/Services/ReceiptParserService.swift:1327
  Description: sanitize trimmt zuerst Leerraum und DANACH Anführungszeichen; die isEmpty-Prüfung
    greift nur vor dem Quote-Trim. Gemessen: eine Modellantwort aus einem in Anführungszeichen
    gesetzten Leerzeichen liefert einen Namen aus einem Leerzeichen
    (probe-whitespace-1b.swift). Über ReceiptResolutionService.swift:175 und
    ReceiptScannerView.swift:130 landet er in line.name; die Position zählt in Kopfzeile und Summe
    mit (ReceiptScannerView.swift:224, :508) und wird von isSavable (:106) beim Speichern still
    verworfen.
  Spec requirement: docs/specs/views/receipt-review-card.md:537 — „Der einzige bekannte Weg zu
    einem leeren oder nur aus Leerzeichen bestehenden line.name — das Feld ‚Anderer Name …' — ist
    seit dem getrimmten Guard aus Regel 10 geschlossen"; und Zeile 453 — „Ein Name aus reinen
    Leerzeichen entsteht damit nirgends mehr — weder in line.name noch in Kopfzeile, Summe oder
    canSave".
  Conflict: Es gibt heute einen zweiten Weg, nicht erst „künftig" nach einer Änderung an den
    Services. Die Aussage ist widerlegt, nicht nur unscharf; der PO liest eine Vollständigkeit, die
    die Implementierung nicht hat. Die Wirkung bleibt durch Regel 11 auf die still verschwindende
    Position begrenzt (kein namenloser Kaufdatensatz), und die Auslösung verlangt eine pathologische
    Modellantwort — deshalb MEDIUM und nicht HIGH.
  Remediation: Entweder die Spec-Aussage auf „der einzige über die Karte erreichbare Weg"
    einschränken und den KI-Pfad als zweite, offene Quelle benennen (eigenes Ticket), oder in
    sanitize nach dem Quote-Trim erneut trimmen und prüfen.
```

```
Finding:
  ID: F104
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:499
  Description: CharacterSet.whitespaces erfasst Tabulator, U+00A0 und alle Zs-Leerzeichen
    (gemessen), NICHT aber U+000A (Zeilenumbruch), CRLF und U+000B. Ein Name, der nur daraus
    besteht, passiert beide Guards — Regel 10 schreibt ihn durch, isSavable
    (ReceiptScannerView.swift:106) hält ihn für gültig, und save() legt einen optisch namenlosen
    Kaufdatensatz an.
  Spec requirement: AC-16 — „es entsteht kein Kaufdatensatz ohne Namen in der Ausgabenhistorie und
    kein gelernter Preis unter dem leeren Schlüssel".
  Conflict: AC-18 ist NICHT verletzt (keine still verworfene Position, beide Guards sind
    symmetrisch), AC-16 aber nur dem Buchstaben nach erfüllt: ein Name aus einem Zeilenumbruch ist
    für den Nutzer kein Name. Die Erreichbarkeit über das einzeilige Textfeld ist unbewiesen
    (Einfügen mehrzeiligen Textes, Diktat, externe Tastatur) — deshalb LOW.
  Remediation: In Regel 10 UND Regel 11 gemeinsam auf whitespacesAndNewlines umstellen (weiter
    derselbe Leer-Begriff auf beiden Seiten) oder die Grenze in den Known Limitations benennen.
```

---

## Bestätigungen

```
Confirmation:
  AC: AC-18 (Rückfall bei reinen Leerzeichen, alle drei Felder)
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:499
  Evidence: Der Eingangs-Guard prüft den getrimmten Namen und schreibt im Rückfall Name,
    matchedItemID UND resolvedByAI gemeinsam zurück (Zeilen 503-505).
    testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName prüft alle drei
    Felder und ist in meinem eigenen Lauf bestanden (adversary-test-output-1b.txt); RED-Beleg: drei
    Zusicherungen fielen in test-red-unit-1b.txt.
  Status: CONFIRMED
```

```
Confirmation:
  AC: AC-18 (Verteidigungs-Rückfall auf den Bontext)
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:500
  Evidence: Auch previousSelection.name wird getrimmt geprüft; ein festgehaltenes Leerzeichen gilt
    nicht als gültiger Rückfall, stattdessen greift line.originalName mit matchedItemID nil und
    resolvedByAI false. Test
    testApplyCustomNameOrFallbackFallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly in
    meinem eigenen Lauf bestanden. Dass originalName selbst nie leer ist, ist am Parser belegt
    (ReceiptParserService.swift:536, :580, :770, :868).
  Status: CONFIRMED
```

```
Confirmation:
  AC: AC-18 (Bildschirm-Nachweis)
  Code reference: RestockUITests/ReceiptReviewUITests.swift:947
  Evidence: testWhitespaceOnlyCustomNameKeepsPreviousItemName fährt die Strecke über den
    BESTEHENDEN Seed, leert das Feld und tippt ein Leerzeichen; die Assertion fällt, wenn der
    Namensteil des Häkchen-Labels getrimmt leer ist. Im RED-Lauf trug das Label tatsächlich
    „Position übernehmen:  " (test-red-ui-1b.txt), grün in green-run2-ui.txt und
    green-run3b-suite.txt.
  Status: CONFIRMED
```

```
Confirmation:
  AC: AC-15 (präzisiert: geleert ODER reine Leerzeichen; Textfeld unangetastet)
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:270
  Evidence: Die Reaktion auf jede Feldänderung ruft ausschließlich applyCustomNameOrFallback auf und
    schreibt customName nirgends zurück — das sichtbare Feld behält die eingetippten Leerzeichen,
    nur line.name, matchedItemID und resolvedByAI fallen zurück. Nach dem Rückfall trägt line.name
    einen getrimmt nicht-leeren Namen, weil beide Rückfallquellen getrimmt nicht leer sind.
  Status: CONFIRMED
```

```
Confirmation:
  AC: Regel 10 und Regel 11 benutzen denselben Leer-Begriff
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:106
  Evidence: Beide Stellen verwenden wörtlich denselben getrimmten Leer-Test (Karte Zeilen 499 und
    500, Filter Zeile 106). Damit existiert kein Name, den Regel 10 durchlässt und Regel 11
    verwirft — die von AC-18 verbotene still verschwindende Position ist für JEDEN String
    ausgeschlossen, nicht nur für Leerzeichen. Zeichenumfang gemessen in probe-whitespace-1b.swift;
    Einschränkung U+000A/U+000B siehe F104.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F001 unberührt, kein Regress
  Code reference: RestockTests/ReceiptReviewCardTests.swift:214
  Evidence: testAiSuggestionIsDroppedWhenAListMatchCarriesTheSameName ist in meinem eigenen Lauf
    bestanden (adversary-test-output-1b.txt); der Produktiv-Unterschied berührt nur
    applyCustomNameOrFallback (zwei Zeilen plus Kommentar), nicht selectionOptions, isSelected,
    applySelection oder mergeAIReresolution.
  Status: CONFIRMED
```

```
Confirmation:
  AC: Test-Plan-Integrität (Stichprobe von sechs der neun umgestellten Punkte)
  Code reference: RestockTests/ReceiptReviewCardTests.swift:171
  Evidence: Jeder geprüfte Punkt hat einen existierenden Test mit deckungsgleichen Zusicherungen
    (ReceiptReviewCardTests.swift:171, :193, :163; ReceiptScannerReResolutionTests.swift:52;
    ReceiptReviewUITests.swift:860) und je genau einen bestanden-Eintrag in green-run3b-suite.txt.
    Der bewusst offen gelassene Punkt ist korrekt begründet: die Markierungs-Logik ist eine private
    Funktion der View und kommt in der Unit-Testdatei nicht vor. Einzige Ungenauigkeit: eine
    Zeilenangabe der Spec zeigt auf 165 statt 163.
  Status: CONFIRMED
```

```
Confirmation:
  AC: Nachweislage (Abbruch in green-run3-suite.txt, Vollständigkeit von 3b, RED gegen GREEN)
  Code reference: docs/artifacts/fix-50-import-dialog-design/green-run3b-suite.txt
  Evidence: 3b: 271 Unit- und 19 UI-Tests, 0 Fehler, ein TEST SUCCEEDED, keine Übersprünge, keine
    Wiederholungen, 30 Unit-Klassen. run3: UI grün, Unit 0 ausgeführt, Testrunner-Hänger — von mir
    bei gebootetem Fremd-Simulator selbst reproduziert
    (adversary-test-output-1b-fail1-issue63.txt) und nach dem dokumentierten Rezept behoben
    (adversary-test-output-1b.txt, 31 Tests, 0 Fehler). Die RED-Protokolle zeigen ausschließlich
    Zusicherungsfehler an genau den drei neuen Funktionen.
  Status: CONFIRMED
```

---

## Bewertung je Checklistenpunkt

| Punkt | Ergebnis | Begründung |
|-------|----------|------------|
| 1 — AC-18 (Leerzeichen lösen denselben Rückfall aus, keine still verworfene Position) | PROVEN | Guard und Rückfall getrimmt, alle drei Felder; zwei Unit-Tests plus UI-Test mit RED-Beleg; Symmetrie zu isSavable am Code belegt |
| 2 — AC-15 präzisiert, line.name nie leer oder Leerzeichen, Textfeld unangetastet | PROVEN | ReceiptReviewCard.swift:270 und :499-505; beide Rückfallquellen getrimmt nicht leer, originalName am Parser belegt |
| 3 — Widerspruchsfreiheit Invariante 6 / Known Limitations / AC-14 | DISPROVEN | F101: Invariante 6 (Zeile 600) nennt mergeAIReresolution unverändert als abgedeckten Weg, AC-14 (861) und der Reichweiten-Satz (410) ebenso — genau der Weg, über den F001 entsteht |
| 4 — Regel 11 als Verteidigung in der Tiefe, einziger Weg geschlossen | TEILWEISE | Einordnung im Ergebnis richtig, Begründung falsch: ein zweiter Weg über sanitize ist heute erreichbar (F103) |
| 5 — F001 unberührt, Dedup-Test grün | PROVEN | eigener Lauf bestanden, Produktiv-Unterschied auf zwei Zeilen begrenzt |
| 6 — Test-Plan-Integrität (mindestens vier Stichproben) | PROVEN | sechs Punkte geprüft, alle gedeckt; der offene Punkt korrekt als offen geführt |
| Zusatz — PO-Briefing | DISPROVEN | F102: DoD verspricht „auch nach nachträglicher Namensauflösung genau einen markierten Namen" — exakt der Fall F001 |

---

═══════════════════════════════════════
VERDICT: BROKEN
═══════════════════════════════════════

Die Umsetzung von F002 selbst hält jedem Angriff stand: Regel 10 und Regel 11 benutzen jetzt
wörtlich denselben Leer-Begriff, alle drei Felder kommen zurück, der Verteidigungs-Rückfall greift
auch bei einem festgehaltenen Leerzeichen, der Bontext ist am Parser nachweislich nie leer, RED und
GREEN betreffen dieselben Funktionen, und mein eigener Lauf ist grün (31 Tests, 0 Fehler,
TEST SUCCEEDED). F001 ist unberührt, der zugehörige Bestandstest grün. Kein Häkchen im Test Plan
ohne Deckung.

BROKEN wegen der Dokumentenlage, nicht wegen des Codes — an genau der Stelle, die dieser zweite
Prüfdialog klären sollte.

Finding F101: Invariante 6 zählt mergeAIReresolution weiterhin als abgedeckten Zuweisungsweg auf und
  verspricht dort „genau eine Option markiert"; AC-14 und der Reichweiten-Satz zu Regel 9 (dort nur
  „Ausnahme bei leerem Namen") tun dasselbe. F001 entsteht genau über diesen Weg, bei nicht-leerem
  Namen. Der Selbstwiderspruch, der das erste Urteil auf AMBIGUOUS gebracht hat, ist wortgleich
  erhalten; die Grenze ist für einen Leser von Invariante 6 oder AC-14 nicht erkennbar.
  Severity: HIGH
  Evidence: docs/specs/views/receipt-review-card.md:600, :861, :410 gegen :1081-1093;
    SmartCart/Views/Prices/ReceiptScannerView.swift:130;
    SmartCart/Views/Prices/ReceiptReviewCard.swift:369
  Reproduction: Invariante 6 lesen, dann die Known Limitation F001 lesen — beide Sätze beschreiben
    denselben Zuweisungsweg mit entgegengesetztem Ergebnis.

Finding F102: Das PO-Briefing verspricht in „Was gebaut wird" und in der Definition of Done „genau
  einen markierten Namen, auch nach nachträglicher Namensauflösung" — exakt die Eigenschaft, die
  F001 offen lässt.
  Severity: HIGH
  Evidence: docs/briefings/fix-50-import-dialog-design.md:14 und Zeile 18
  Reproduction: Briefing lesen und die DoD gegen die eigene kritische Anmerkung halten.

Finding F103: Die Spec-Aussagen „einziger bekannter Weg … geschlossen" und „entsteht nirgends mehr"
  sind falsch — sanitize lässt eine in Anführungszeichen gesetzte Leerzeichen-Antwort als Namen
  durch (gemessen).
  Severity: MEDIUM
  Evidence: SmartCart/Services/ReceiptParserService.swift:1327;
    docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift

Finding F104: CharacterSet.whitespaces deckt U+000A und U+000B nicht ab; ein solcher Name passiert
  beide Guards symmetrisch und wird gespeichert (AC-18 unverletzt, AC-16 nur dem Buchstaben nach
  erfüllt). Erreichbarkeit über das einzeilige Textfeld unbewiesen.
  Severity: LOW
  Evidence: SmartCart/Views/Prices/ReceiptReviewCard.swift:499;
    docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift

Tests: 31 bestanden, 0 fehlgeschlagen (eigener Lauf); Nachweisprotokolle 271 plus 19 bestanden, 0
fehlgeschlagen. Kein Regress. Checkliste: vier von sechs Punkten bewiesen, einer teilweise, einer
widerlegt (Punkt 3) — dazu ein widerlegtes Freigabeversprechen im Briefing.

Zum Abschluss reichen drei geänderte Sätze (Invariante 6, AC-14, Reichweiten-Satz zu Regel 9) plus
eine eingeschränkte DoD im Briefing; Produktivcode ist dafür nicht zu berühren. Danach ist der Stand
aus meiner Sicht VERIFIED — F001 als bewusst offene, dann widerspruchsfrei dokumentierte Grenze
eingeschlossen.

---

### Runde 3 — Nachprüfung der Dokumentenlage (F101, F102, F103)

- **Datum:** 2026-09-28
- **Prüfumfang:** ausschließlich `docs/specs/views/receipt-review-card.md` und
  `docs/briefings/fix-50-import-dialog-design.md`. Kein neuer Testlauf — der Code ist in den
  Runden 1 und 2 bewiesen.
- **Unverändertheit belegt:** Statusabfrage und Differenzstatistik des Arbeitsbaums zeigen
  denselben Produktiv-Unterschied wie in Runde 2 (`ReceiptReviewCard.swift` +6/−2: zwei Guards
  plus Kommentar; `ReceiptReviewCardTests.swift` +50, `ReceiptReviewUITests.swift` +56). Geändert
  wurden seit Runde 2 nur Spec und Briefing.
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:490

#### Angriff 15 — „Irgendwo behauptet die Spec noch eine Markierung ohne F001-Ausnahme"

Systematisch durchsucht über die GESAMTE Datei (Muster: markiert, Markierung, genau eine,
vorausgew, Auswahlkreis, Punkt 4, behoben, Zusage 2), danach jede der 30 Fundstellen im Kontext
gelesen: Purpose, Scope samt Tabellen, Implementation Details, Invarianten, Test Plan,
Acceptance Criteria, Expected Behavior, Definition of Done, Known Limitations, Changelog.

Behoben und bestätigt:

- Invariante 6 ist neu gefasst und nennt F001 ausdrücklich als „NICHT abgedeckt", samt Codestellen
  und dem Hinweis, dass frühere Fassungen den Selbstwiderspruch trugen.
  Code reference: docs/specs/views/receipt-review-card.md:620
- Der Reichweiten-Satz zu Regel 9 zählt jetzt ZWEI Ausnahmen auf, die zweite ist F001 mit der
  vollständigen Mechanik und Issue #66.
  Code reference: docs/specs/views/receipt-review-card.md:411
- AC-14 trägt einen „Nicht abgedeckt"-Satz mit F001 und #66.
  Code reference: docs/specs/views/receipt-review-card.md:905
- Definition of Done nennt die Ausnahme in PO-Sprache („Trifft der neue Name wörtlich einen
  Artikel, der bereits als Vorschlag dieser Position angeboten wird, steht die Karte weiterhin
  ohne markierten Kreis") und benennt den Alltagsfall.
  Code reference: docs/specs/views/receipt-review-card.md:1069

NICHT behoben, zwei Stellen:

1. **Zusage 1** (Kopf des Nachtrags): „Der aufgelöste Name steht sichtbar als markierte Zeile —
   nicht erst im Feld ‚Anderer Name …'." Zusage 2 direkt darunter trägt die Ausnahme, Zusage 1
   nicht. Im F001-Fall steht der aufgelöste Name zwar sichtbar in der Liste, aber eben NICHT als
   markierte Zeile.
   Code reference: docs/specs/views/receipt-review-card.md:374
2. **AC-13**: „… wird die Auswahlliste einmal neu berechnet (Regel 9) — der neue Name erscheint als
   eigene, vorausgewählte Zeile (Regel 5), nicht erst im Feld ‚Anderer Name …'." Die Vorbedingung
   von AC-13 („passt danach keine der bestehenden Auswahlzeilen mehr dazu") ist im F001-Fall
   ERFÜLLT, die Zusage aber nicht: die Spec sagt selbst, dass Regel 5 dort „mangels
   Namens-Mismatch nicht" greift. Am Code nachgelesen: `selectionOptions` fügt `.currentName` nur
   ein, wenn kein Kandidat namensgleich ist (Regel 5, Zeilen 443-447); im F001-Fall sortiert
   Regel 3 den namensgleichen Listen-Treffer nur nach vorn — ohne Markierung.
   Code reference: docs/specs/views/receipt-review-card.md:895
   Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:443

Bewertung: NACHFRAGE, Befund F106 (MEDIUM). F101 ist an den drei in Runde 2 benannten Stellen
erledigt, an zwei weiteren nicht.

#### Angriff 16 — „Der Autor hat beim Korrigieren zu viel weggenommen" (Gegenrichtung)

Der Prüfauftrag verlangt ausdrücklich die Gegenprobe. Sie trifft zu.

Invariante 6 lautet heute: „Gilt für jede Zeile, deren `matchedItemID`/`resolvedByAI` aus
`applySelection` oder `applyCustomName`/`applyCustomNameOrFallback` stammen". `mergeAIReresolution`
ist aus der Aufzählung vollständig GESTRICHEN. Der „Nicht abgedeckt"-Satz darunter schließt aber nur
die KONJUNKTION aus (`mergeAIReresolution` UND Name gleich einem eigenen Vorschlag). Dazwischen
klafft eine Lücke: eine Zeile aus `mergeAIReresolution` OHNE Namensgleichheit ist weder abgedeckt
noch ausgenommen — obwohl genau sie der reproduzierte Fall aus Issue #50 ist.

Code reference: docs/specs/views/receipt-review-card.md:621
Code reference: docs/specs/views/receipt-review-card.md:901

Am Code und am grünen Test gemessen, dass die Implementierung dort mehr hält, als die Spec noch
zusagt:

- `linesNeedingAIReresolution` wählt die BTR-Zeile, `resolve` löst sie über `expandAbbreviations`
  („btr" → „Butter") auf, `resolvedByAI` bleibt false.
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:104
- `mergeAIReresolution` schreibt Name, `suggestions`, `matchedItemID` und `resolvedByAI` dieser
  Zeile — der Zustand stammt also WEDER aus `applySelection` NOCH aus `applyCustomName`.
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:126
- Der grüne UI-Test prüft für genau diese Zeile: `option.0` zeigt den aufgelösten Namen, ist
  markiert, und über alle vier Optionen ist GENAU EINE markiert.
  Code reference: RestockUITests/ReceiptReviewUITests.swift:842

AC-14 widerspricht sich dadurch in sich selbst: es beschränkt die Zusage auf zwei Zuweisungswege
und beruft sich im selben Satz auf „beweisbar am reproduzierten Fall" — der über den dritten, nun
ausgeschlossenen Weg entsteht. Der Nachweis, den die Implementierung erbringt, deckt damit keine
Zusage der Spec mehr ab.

Bewertung: NACHFRAGE, Befund F105 (MEDIUM). Zu schwach formuliert UND in sich widersprüchlich.

#### Angriff 17 — „Die Scope-Sätze behaupten Punkt 4 als behoben"

Zwei Stellen sagen ohne Einschränkung, Paket 1 behebe Punkt 4 aus Issue #50: „**Paket 1** (diese
Erweiterung) behebt Punkt 2 und Punkt 4 sowie den PO-Fund" und „Behebt Punkt 2 und Punkt 4 aus
Issue #50 sowie den … dritten Fall".

Code reference: docs/specs/views/receipt-review-card.md:64
Code reference: docs/specs/views/receipt-review-card.md:152

Dem stehen zwei Stellen gegenüber, die Punkt 4 ausdrücklich als teilweise offen führen: „Punkt 4
aus Issue #50, für diesen einen Eingang unbehoben" (Invariante 6) und „… obwohl `line.name` nicht
leer ist (Punkt 4 aus Issue #50)" (Known Limitations, F001).

Code reference: docs/specs/views/receipt-review-card.md:632
Code reference: docs/specs/views/receipt-review-card.md:1134

Bewertung: NACHFRAGE, Befund F107 (LOW). Schwächer als F106, weil „Punkt 4" dort die Überschrift
des Arbeitspakets meint und beide Stellen im Scope-Kapitel stehen — aber es ist derselbe
Widerspruchstyp, und die Prüfung verlangte ausdrücklich das Muster „Punkt 4 sei behoben".

#### Angriff 18 — „Das Briefing verspricht weiterhin zu viel" (F102)

Code reference: docs/briefings/fix-50-import-dialog-design.md:14
Code reference: docs/briefings/fix-50-import-dialog-design.md:18

Heutiger Wortlaut: „Eine Bon-Position zeigt sichtbar genau einen markierten Namen — außer wenn die
Auflösung einen Namen trifft, der wörtlich auf deiner Liste steht (offen, #66)." DoD: „Beim Öffnen
aus einer geteilten App trägt eine Position den markierten Namen, außer im Fall #66; ein leeres
oder nur mit Leerzeichen gefülltes Namensfeld kehrt zum vorherigen zurück."

Beide Sätze tragen die Ausnahme jetzt IM Satz, nicht erst in den kritischen Anmerkungen; der
Auslöser ist in PO-Sprache benannt und die Ticketnummer steht dabei. „Wie geprüft wird" („den
KI-Weg zeigt der Simulator nicht") deckt sich mit dem Scope-Eintrag der Spec. Die kritischen
Anmerkungen nennen #66, #67 und #65; #68 und #69 fehlen dort, versprechen aber nichts — DoD und
„Was gebaut wird" bleiben davon unberührt.

Bewertung: AKZEPTIERT. F102 erledigt.

Eine andere Stelle des Briefings ist dafür jetzt falsch: der Kopf bindet die Spec über
`spec_sha256: 3b670d19…`. Die Datei trägt heute die Prüfsumme
`1381e671caf1460519ff400bdc7c1d1fe73256d893028abd974b3067fbe60d61` (mit `shasum -a 256` gemessen).
Das Briefing weist damit auf einen Spec-Stand, den es nicht mehr gibt — genau der Fall, den die
Memory-Notiz `implement-phase-stolpersteine` beschreibt („Briefing-Hash nach jeder Spec-Änderung
neu binden").

Code reference: docs/briefings/fix-50-import-dialog-design.md:3

Bewertung: NACHFRAGE, Befund F108 (MEDIUM, Nachweisform).

#### Angriff 19 — „F103 ist nur umformuliert, nicht eingeschränkt"

Drei Stellen geprüft, alle drei sind jetzt korrekt begrenzt und tragen die Ticketnummer:

- „Wirkung von Paket 1b auf die Datenlage: **Über die Karte** entsteht ein Name aus reinen
  Leerzeichen nirgends mehr" — die frühere, widerlegte Allaussage ist auf den Karten-Weg
  eingeschränkt.
  Code reference: docs/specs/views/receipt-review-card.md:464
- Neuer Absatz „Eine Quelle bleibt offen (2026-09-27, im zweiten Prüfdialog gemessen)" beschreibt
  die Reihenfolge Trim-vor-Quote in `sanitize`, den Weg über `ReceiptResolutionService.swift:175`
  und `mergeAIReresolution` und nennt Folge-Issue **#69**.
  Code reference: docs/specs/views/receipt-review-card.md:469
- Regel 11 sagt jetzt „der einzige **über die Karte** erreichbare Weg … ist geschlossen" und
  ergänzt „**Für den KI-Weg bleibt sie eine erreichbare Bedingung**", wieder mit #69.
  Code reference: docs/specs/views/receipt-review-card.md:558

Gegengeprüft am Code, dass die neue Formulierung stimmt: `sanitize` trimmt vor dem Entfernen der
Anführungszeichen und prüft danach nicht erneut (Messung aus Runde 1 unverändert gültig).
Code reference: SmartCart/Services/ReceiptParserService.swift:1327

Bewertung: AKZEPTIERT. F103 erledigt.

#### Angriff 20 — „Ein Leser ohne Code erkennt die Grenze nicht" (Prüffrage 2)

Vier voneinander unabhängige Stellen nennen die Grenze, davon zwei in PO-Sprache, alle mit
Ticketnummer #66: Briefing „Was gebaut wird" und DoD; Spec-DoD („Trifft der neue Name wörtlich
einen Artikel, der bereits als Vorschlag dieser Position angeboten wird, steht die Karte weiterhin
ohne markierten Kreis. Alltagsfall: der Artikel steht unabgehakt auf der Liste."); Known
Limitations F001 mit Mechanik und Verweis auf die Vorarbeit.

Code reference: docs/specs/views/receipt-review-card.md:1129
Code reference: docs/briefings/fix-50-import-dialog-design.md:26

Bewertung: AKZEPTIERT. Ein Leser kann die Grenze benennen und weiß, dass sie Issue #66 trägt —
auch ohne eine Zeile Code.

#### Angriff 21 — „Der Korrekturgang selbst ist nicht nachvollziehbar"

Der Changelog endet mit dem Nachzug-Abschnitt vom 2026-09-27 (Folge-Issue-Nummern, Test Plan
nachgezogen). Die Korrekturen aus Runde 2 — neu gefasste Invariante 6, AC-14, Reichweiten-Satz,
Einschränkung von Regel 10/11, neues Issue #69 — stehen in KEINEM Changelog-Eintrag. Das Datum im
Kopf steht weiterhin auf `updated: 2026-09-27`.

Code reference: docs/specs/views/receipt-review-card.md:1185
Code reference: docs/specs/views/receipt-review-card.md:4

Bewertung: NACHFRAGE, Befund F109 (LOW).

#### Angriff 22 — „F104 ist inzwischen still verschwunden"

Suche über Spec und Briefing nach #69, F104, Zeilenumbruch und `whitespacesAndNewlines`: #69 kommt
zweimal vor, beide Male für den `sanitize`-Weg (F103). F104 (U+000A/U+000B passieren beide Guards
symmetrisch und werden gespeichert) ist in der Spec nirgends erwähnt — weder als Known Limitation
noch am Leer-Begriff von Regel 10/11.

Code reference: docs/specs/views/receipt-review-card.md:1096

Bewertung: F104 unverändert offen (LOW, wie in Runde 2), jetzt zusätzlich ohne Spur im Dokument.
Kein neuer Befund, aber der bestehende bleibt stehen.

---

## Befunde (Runde 3)

F101 ist in der Hauptsache erledigt (Invariante 6, AC-14, Reichweiten-Satz zu Regel 9), F102 und
F103 vollständig. Neu bzw. verblieben:

```
Finding:
  ID: F105
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/views/receipt-review-card.md:621
  Description: Invariante 6 (Zeile 621-623) und AC-14 (Zeile 901-903) beschränken die Zusage
    „genau eine Option markiert" auf Zeilen, deren matchedItemID/resolvedByAI aus applySelection
    oder applyCustomName/applyCustomNameOrFallback stammen. mergeAIReresolution ist aus der
    Aufzählung ganz gestrichen; der „Nicht abgedeckt"-Satz schließt nur die KONJUNKTION
    (mergeAIReresolution UND Name gleich einem eigenen Vorschlag) aus. Eine Zeile aus
    mergeAIReresolution OHNE Namensgleichheit ist damit weder zugesagt noch ausgenommen.
  Spec requirement: AC-13/AC-14, Zusage 2 — die Spec soll abbilden, was die Implementierung hält.
    Der reproduzierte Fall aus Issue #50 (BTR -> Butter über reResolveAIIfNeeded) durchläuft genau
    mergeAIReresolution: ReceiptResolutionService.swift:104 löst über expandAbbreviations auf,
    ReceiptScannerView.swift:126 schreibt Name/suggestions/matchedItemID/resolvedByAI zurück, und
    der grüne UI-Test RestockUITests/ReceiptReviewUITests.swift:842 prüft „genau eine markiert".
  Conflict: Die Spec verspricht jetzt WENIGER, als der Code beweisbar leistet — die zentrale
    Wirkung von Paket 1 steht ohne Invariante da. Zusätzlich widerspricht sich AC-14 in sich:
    es schließt mergeAIReresolution aus und beruft sich im selben Satz auf „beweisbar am
    reproduzierten Fall", der über genau diesen Weg entsteht. Der einzige UI-Nachweis der
    Markierungs-Logik deckt damit keine Zusage der Spec mehr ab.
  Remediation: Den positiven Satz wieder auf drei Wege öffnen und die Ausnahme dort anhängen, z. B.
    Invariante 6: „Gilt für jede Zeile, deren `matchedItemID`/`resolvedByAI` aus einem der
    bekannten Zuweisungswege stammen (`applySelection`, `applyCustomName`/
    `applyCustomNameOrFallback` oder `mergeAIReresolution`) — mit Ausnahme des unten benannten
    Falls F001". AC-14 wortgleich nachziehen; der bestehende „Nicht abgedeckt"-Satz bleibt
    unverändert stehen und wird dadurch erst schlüssig.
```

```
Finding:
  ID: F106
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/views/receipt-review-card.md:895
  Description: AC-13 sagt zu: „Ändert sich `line.name` von AUSSEN …, UND passt danach keine der
    bestehenden Auswahlzeilen mehr dazu, wird die Auswahlliste einmal neu berechnet (Regel 9) —
    der neue Name erscheint als eigene, vorausgewählte Zeile (Regel 5), nicht erst im Feld
    ‚Anderer Name …'." Keine Ausnahme. Dieselbe Aussage ohne Ausnahme trägt Zusage 1 (Zeile 374):
    „Der aufgelöste Name steht sichtbar als markierte Zeile".
  Spec requirement: F001 (Zeilen 411-423, 625-635, 1129-1141) — im F001-Fall greift Regel 5
    „mangels Namens-Mismatch nicht", und keine Zeile ist markiert.
  Conflict: Die Vorbedingung von AC-13 ist im F001-Fall ERFÜLLT (keine bestehende Zeile ist mehr
    markiert, also läuft die Neuberechnung), die Zusage aber nicht: selectionOptions fügt
    .currentName nur ohne namensgleichen Kandidaten ein (ReceiptReviewCard.swift:443-447); im
    F001-Fall sortiert Regel 3 den namensgleichen Listen-Treffer lediglich nach vorn, markiert
    aber nichts (isSelected verlangt !resolvedByAI, ReceiptReviewCard.swift:369). Für Zusage 1
    gilt dasselbe: der Name ist sichtbar, aber nicht markiert. Zwei der in Runde 2 beanstandeten
    Stellen sind korrigiert, diese zwei nicht — derselbe Selbstwiderspruch, nur an anderer Stelle.
  Remediation: AC-13 um einen Halbsatz ergänzen: „… erscheint als eigene, vorausgewählte Zeile
    (Regel 5) — außer im Fall F001 (Issue #66), in dem ein namensgleicher Listen-Treffer die
    Einfügung nach Regel 5 verhindert und die Karte ohne markierte Zeile bleibt". Zusage 1
    entsprechend: „Der aufgelöste Name steht sichtbar in der Auswahlliste (im Regelfall als
    markierte Zeile; Ausnahme F001, siehe Zusage 2) — nicht erst im Feld ‚Anderer Name …'."
```

```
Finding:
  ID: F107
  Severity: LOW
  Category: spec_violation
  Code reference: docs/specs/views/receipt-review-card.md:64
  Description: „Paket 1 (diese Erweiterung) behebt Punkt 2 und Punkt 4 sowie den PO-Fund"
    (Zeile 64) und „Behebt Punkt 2 und Punkt 4 aus Issue #50 sowie den … dritten Fall" (Zeile 152)
    — beide ohne Einschränkung.
  Spec requirement: Invariante 6 (Zeile 632) „Punkt 4 aus Issue #50, für diesen einen Eingang
    unbehoben" und Known Limitations F001 (Zeile 1134) „… (Punkt 4 aus Issue #50)".
  Conflict: Derselbe Widerspruchstyp wie F101, im Scope-Kapitel. Wer nur den Scope liest, hält
    Punkt 4 für vollständig erledigt.
  Remediation: An beiden Stellen „Punkt 4 (bis auf den als F001/#66 beschriebenen Eingang)"
    schreiben.
```

```
Finding:
  ID: F108
  Severity: MEDIUM
  Category: regression
  Code reference: docs/briefings/fix-50-import-dialog-design.md:3
  Description: Der Briefing-Kopf bindet die Spec über
    spec_sha256: 3b670d19b2075f287f61c93f3df3160368fde5b9a3c89a5523cd412196db8269.
    Die Spec trägt heute die Prüfsumme
    1381e671caf1460519ff400bdc7c1d1fe73256d893028abd974b3067fbe60d61.
  Spec requirement: Das Briefing ist das Freigabedokument zu EINEM bestimmten Spec-Stand; die
    Bindung ist der Nachweis, dass der PO genau diesen Stand gesehen hat (Memory-Notiz
    implement-phase-stolpersteine: Briefing-Hash nach jeder Spec-Änderung neu binden).
  Conflict: Die Korrektur der Spec hat die Bindung gebrochen. Das Briefing verweist auf einen
    Stand, den es nicht mehr gibt; eine Freigabe darauf wäre formal wertlos, und die
    Schreibsperre der Implementierungsphase greift bei der nächsten Code-Änderung.
  Remediation: Nach der letzten Spec-Korrektur die Prüfsumme im Briefing-Kopf neu binden.
```

```
Finding:
  ID: F109
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/specs/views/receipt-review-card.md:1185
  Description: Der Changelog endet mit dem Nachzug vom 2026-09-27. Die Korrekturen aus Prüfrunde 2
    (Invariante 6 neu gefasst, AC-14 eingeschränkt, Reichweiten-Satz zu Regel 9, Regel 10/11 auf
    den Karten-Weg begrenzt, Folge-Issue #69 aufgenommen) sind nirgends als Änderung vermerkt; das
    Kopffeld steht weiter auf updated: 2026-09-27.
  Spec requirement: Changelog-Konvention dieser Spec — jede inhaltliche Änderung bekommt einen
    datierten Eintrag (vier bestehende Einträge folgen dem Muster).
  Conflict: Der Korrekturgang ist nicht nachvollziehbar; wer die Spec später liest, sieht nicht,
    dass Invariante 6 aus einem Prüfbefund heraus umformuliert wurde.
  Remediation: Einen Eintrag „2026-09-28: Prüfdialog-Nachtrag — …" ergänzen und updated setzen.
```

## Bestätigungen (Runde 3)

```
Confirmation:
  AC: F101 (Hauptteil) — Invariante 6 nennt die F001-Ausnahme
  Code reference: docs/specs/views/receipt-review-card.md:620
  Evidence: Invariante 6 heißt jetzt „Genau eine Option ist markiert, sofern line.name nicht leer
    ist — mit den unten benannten Ausnahmen" und trägt einen eigenen Absatz „Ausdrücklich NICHT
    abgedeckt (F001, offen, Issue #66)" mit vollständiger Mechanik (mergeAIReresolution setzt
    resolvedByAI = true / matchedItemID = nil, Dedup-Regel 2, Regel 5 greift nicht,
    isSelected(.listMatch) verweigert wegen !resolvedByAI) und den Codestellen
    ReceiptScannerView.swift:130 und ReceiptReviewCard.swift:369. Am Code gegengelesen: stimmt mit
    dem heutigen Verhalten überein.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F101 — Reichweiten-Satz zu Regel 9 und AC-14 tragen die Ausnahme
  Code reference: docs/specs/views/receipt-review-card.md:411
  Evidence: Der Reichweiten-Satz zählt jetzt ZWEI Ausnahmen auf (leerer Name; F001 mit voller
    Mechanik, Verweis auf #66 und auf die Vorarbeit receipt-review-card-nachtrag-1b.md). AC-14
    (Zeile 905) trägt einen „Nicht abgedeckt"-Satz mit F001 und der byte-gleichen Restlücke. Die in
    Runde 2 beanstandete Fassung („als Ausnahme NUR der leere Name") existiert nicht mehr.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F102 — Briefing verspricht nicht mehr, als der Code hält
  Code reference: docs/briefings/fix-50-import-dialog-design.md:14
  Evidence: „Was gebaut wird" und Definition of Done tragen die Ausnahme im Satz selbst, in
    PO-Sprache und mit Ticketnummer (#66). Keine Stelle des Briefings behauptet mehr „auch nach
    nachträglicher Namensauflösung". „Wie geprüft wird" grenzt den KI-Weg korrekt aus.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F103 — beide Aussagen zur Leerzeichen-Quelle sind eingeschränkt und tragen #69
  Code reference: docs/specs/views/receipt-review-card.md:469
  Evidence: „Über die Karte entsteht ein Name aus reinen Leerzeichen nirgends mehr" (Zeile 464,
    eingeschränkt), neuer Absatz „Eine Quelle bleibt offen" (Zeilen 469-476: sanitize-Reihenfolge,
    Weg über ReceiptResolutionService.swift:175 und mergeAIReresolution, Folge-Issue #69) und
    Regel 11 „der einzige über die Karte erreichbare Weg … Für den KI-Weg bleibt sie eine
    erreichbare Bedingung" (Zeilen 558-562, ebenfalls #69). Deckt sich mit der Messung aus Runde 1.
  Status: CONFIRMED
```

```
Confirmation:
  AC: Prüffrage 2 — die F001-Grenze ist ohne Code erkennbar und benennbar
  Code reference: docs/specs/views/receipt-review-card.md:1069
  Evidence: Die Spec-DoD beschreibt Auslöser und Wirkung in Alltagssprache samt Ticketnummer, die
    Known Limitation F001 (Zeilen 1129-1141) die Mechanik, das Briefing (Zeilen 14, 18, 26) sagt es
    dreimal in PO-Sprache. Ein Leser kann die Grenze benennen („der neue Name trifft wörtlich einen
    Artikel, der bereits als Vorschlag dieser Position angeboten wird") und weiß, dass sie Issue
    #66 trägt.
  Status: CONFIRMED
```

```
Confirmation:
  AC: Produktivcode und Tests seit Runde 2 unverändert
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:490
  Evidence: Der Unterschied zum gesicherten Stand umfasst weiterhin genau die zwei getrimmten
    Guards plus Kommentar in applyCustomNameOrFallback; die beiden Testdateien tragen unverändert
    die in Runde 2 geprüften Ergänzungen. Geändert wurden seitdem ausschließlich Spec und Briefing.
    Deshalb kein neuer Testlauf — die Nachweise aus Runde 2 (eigener Lauf 31 Tests/0 Fehler,
    green-run3b-suite.txt 271 + 19 Tests/0 Fehler) bleiben gültig.
  Status: CONFIRMED
```

---

## Bewertung je Checklistenpunkt (Stand Runde 3 — ersetzt die Tabelle aus Runde 2)

| Punkt | Ergebnis | Begründung |
|-------|----------|------------|
| 1 — AC-18 (Leerzeichen lösen denselben Rückfall aus, keine still verworfene Position) | PROVEN | unverändert aus Runde 1/2; Code und Tests seitdem nicht angefasst |
| 2 — AC-15 präzisiert, line.name nie leer oder Leerzeichen, Textfeld unangetastet | PROVEN | unverändert aus Runde 1/2 |
| 3 — Widerspruchsfreiheit Invariante 6 / Known Limitations / AC-14 | TEILWEISE | Invariante 6, AC-14 („Nicht abgedeckt") und der Reichweiten-Satz tragen die F001-Ausnahme jetzt (F101 erledigt). Offen: AC-13 und Zusage 1 versprechen die Markierung weiterhin ohne Ausnahme (F106), und die positive Aufzählung schließt mergeAIReresolution jetzt ZU WEIT aus (F105) |
| 4 — Regel 11 als Verteidigung in der Tiefe, einziger Weg geschlossen | PROVEN | F103 erledigt: beide Aussagen auf „über die Karte" eingeschränkt, KI-Weg als offene Quelle mit #69 benannt |
| 5 — F001 unberührt, Dedup-Test grün | PROVEN | unverändert aus Runde 2 |
| 6 — Test-Plan-Integrität (mindestens vier Stichproben) | PROVEN | unverändert aus Runde 2 |
| Zusatz — PO-Briefing | PROVEN | F102 erledigt: „Was gebaut wird" und DoD tragen die Ausnahme mit Ticketnummer. Formfehler separat: die Spec-Bindung im Kopf ist veraltet (F108) |
| Zusatz — Gegenrichtung: keine zu schwache Aussage | DISPROVEN | F105: Invariante 6 und AC-14 decken den reproduzierten Fall aus Issue #50 (mergeAIReresolution ohne Namensgleichheit) nicht mehr ab, obwohl der grüne UI-Test ihn beweist |

---

═══════════════════════════════════════
VERDICT: BROKEN
═══════════════════════════════════════

Der Code bleibt bewiesen — an Produktivcode und Tests hat sich seit Runde 2 nichts geändert, die
dortigen Nachweise (eigener Lauf 31 Tests/0 Fehler; green-run3b-suite.txt 271 + 19 Tests/0 Fehler)
gelten unverändert. Drei von vier Prüffragen sind positiv beantwortet:

- **F102 erledigt** — das Briefing verspricht nicht mehr, als der Code hält; die Ausnahme steht in
  „Was gebaut wird" UND in der Definition of Done, in PO-Sprache und mit Ticketnummer #66.
- **F103 erledigt** — beide Aussagen zur Leerzeichen-Quelle sind auf den Karten-Weg eingeschränkt,
  der KI-Weg ist als offene, erreichbare Quelle benannt und trägt #69.
- **Prüffrage 2 erfüllt** — wer nur Spec und Briefing liest, erkennt die Grenze, kann sie in
  eigenen Worten benennen und weiß, dass sie Issue #66 trägt.

BROKEN wegen zweier verbliebener Widersprüche und einer gebrochenen Bindung — weiterhin
ausschließlich Dokumentenlage, kein Produktivcode zu berühren:

Finding F105 (MEDIUM, Gegenrichtung): Invariante 6 (Zeile 621) und AC-14 (Zeile 901) haben
  mergeAIReresolution ganz aus der Aufzählung der abgedeckten Zuweisungswege gestrichen. Damit
  verspricht die Spec WENIGER, als der Code beweisbar hält: der reproduzierte Fall aus Issue #50
  (BTR -> Butter, expandAbbreviations, resolvedByAI false) entsteht genau über diesen Weg und ist
  durch den grünen UI-Test „genau eine markiert" belegt. AC-14 widerspricht sich zusätzlich selbst,
  weil es diesen Fall als seinen eigenen Beweis anführt.
  Evidence: docs/specs/views/receipt-review-card.md:621, :901;
    SmartCart/Views/Prices/ReceiptScannerView.swift:126;
    SmartCart/Services/ReceiptResolutionService.swift:104;
    RestockUITests/ReceiptReviewUITests.swift:842
  Reproduction: Invariante 6 lesen, dann den Test-Plan-Punkt AC-13/AC-14 daneben halten — der dort
    abgehakte, grüne Nachweis fällt nicht mehr unter die Zusage.

Finding F106 (MEDIUM, Rest von F101): AC-13 (Zeile 895) und Zusage 1 (Zeile 374) sagen die
  markierte bzw. per Regel 5 eingefügte Zeile weiterhin ohne Ausnahme zu. Im F001-Fall ist die
  Vorbedingung von AC-13 erfüllt, die Zusage aber nicht — die Spec sagt das an anderer Stelle
  selbst.
  Evidence: docs/specs/views/receipt-review-card.md:895, :374 gegen :411-423;
    SmartCart/Views/Prices/ReceiptReviewCard.swift:443
  Reproduction: AC-13 lesen, dann den Reichweiten-Satz zu Regel 9 lesen.

Finding F108 (MEDIUM, Nachweisform): Der Briefing-Kopf bindet einen Spec-Stand, den es nicht mehr
  gibt (3b670d19… gegen heute 1381e671…).
  Evidence: docs/briefings/fix-50-import-dialog-design.md:3

Finding F107 (LOW): Die Scope-Sätze (Zeilen 64, 152) führen Punkt 4 ohne Einschränkung als behoben.
Finding F109 (LOW): Kein Changelog-Eintrag für den Korrekturgang; updated steht auf 2026-09-27.
Finding F104 (LOW, unverändert aus Runde 2): U+000A/U+000B passieren beide Guards; in der Spec bis
  heute nicht erwähnt.

Zum Abschluss reichen vier Sätze in der Spec (Invariante 6, AC-14, AC-13, Zusage 1), zwei
Halbsätze im Scope, ein Changelog-Eintrag und ein neu gebundener Briefing-Kopf. Danach ist der
Stand aus meiner Sicht VERIFIED — F001 als bewusst offene, dann widerspruchsfrei dokumentierte
Grenze eingeschlossen.

## Geprüfte Dateien

- sha256:4a090efdb7d5af88f239d1990ed61327e9feda13650864d68ebec582d852a9d4  RestockTests/ReceiptReviewCardTests.swift
- sha256:d0ea5e968ae9754800cc383095fe46cd01e314c5678005dc3cfa9c9d880e1045  RestockTests/ReceiptScannerReResolutionTests.swift
- sha256:851566bcad5dd8ac3020a458f6cd40013523e55112f452e5602c6e373e232757  RestockUITests/ReceiptReviewUITests.swift
- sha256:b709d56b302b570736637c3f46ce705b7be02483caa5d5aae6094ee8da10a796  SmartCart/Services/ReceiptParserService.swift
- sha256:69164434075e8d67d5937c046192ed402a973969edd6a104df15e964394882f6  SmartCart/Services/ReceiptResolutionService.swift
- sha256:6f6fbbe30247d1a54d82270574cec100998c831e991feb63f8ff4d948e8bdfe7  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:46ad8942466f785ebb8538835e2d1e73a7f4fa993e21c82ef4eab794151af91e  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:ff5c1296c36b6f2621746ff79a45bf98fb4c0d6cd02c8a87e42f86cc3c89c684  docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b-fail1-issue63.txt
- sha256:2338e8af4b5c71d6fd4f2b7e6b2979d7d24e9f61887123397d73bd44535014e4  docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b.txt
- sha256:bf6583f7fbe03f280b5e93ae4e982e0ab13e5a41c81ee74fa8e2adea0420027f  docs/artifacts/fix-50-import-dialog-design/green-run3-suite.txt
- sha256:91bceaa3d4890eea1b18699844ef91dfd7fbd9b8c3a7ffe64662110aaaec72a8  docs/artifacts/fix-50-import-dialog-design/green-run3b-suite.txt
- sha256:08c52f2ea256309e76a7a06e2d33e14e15f781fbf4752a0ab5baac2e8df65f90  docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift
- sha256:e797917f930b7ec46102f153e7f462f8baef825a748f3c0179ac05d50d3b7d3c  docs/artifacts/fix-50-import-dialog-design/test-red-ui-1b.txt
- sha256:36edc3f378a973f09db84028b41b40e5830a50ada37c046e5a5cec5c86ed5b1d  docs/artifacts/fix-50-import-dialog-design/test-red-unit-1b.txt
- sha256:92751b9284754bb1812869fba9deb80417439329838e2ef9acd099da6aa84a27  docs/briefings/fix-50-import-dialog-design.md
- sha256:1381e671caf1460519ff400bdc7c1d1fe73256d893028abd974b3067fbe60d61  docs/specs/views/receipt-review-card.md

---

### Runde 4 — Nachprüfung des Korrekturgangs

- **Datum:** 2026-09-28
- **Prüfumfang:** erneut nur Spec und Briefing. Produktivcode und Testdateien unverändert
  (Differenzstatistik: `ReceiptReviewCard.swift` +6/−2, `ReceiptReviewCardTests.swift` +50,
  `ReceiptReviewUITests.swift` +56 — identisch zu den Runden 2 und 3). Kein neuer Testlauf.
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:490
- **Bindung geprüft:** Briefing-Kopf und Spec tragen beide
  `127ad63b32218e8199c9a6562227fbe8d954c5c61da27e6b640da808cde24461` (selbst nachgerechnet mit
  `shasum -a 256`). F108 erledigt.
  Code reference: docs/briefings/fix-50-import-dialog-design.md:3

#### Angriff 23 — „Die Rücknahme von F105 schießt über das Ziel hinaus" (Prüffrage 3, Gegenrichtung)

Das ist die heikle Frage dieser Runde, deshalb nicht am Text, sondern am Code entschieden: Hält
`selectionOptions`/`isSelected` die Zusage „genau eine Option markiert" für ALLE
`mergeAIReresolution`-Zeilen außer der ausgenommenen Konjunktion? Ich habe die beiden möglichen
Ausgänge dieses Weges vollständig durchgespielt.

**Fall B — `resolvedByAI == false`** (Alias, Wörterbuch, abgehakter Artikel, Kaufhistorie; das ist
der reproduzierte BTR-Fall): `resolve` filtert die Vorschläge am Ende gegen den AUFGELÖSTEN Namen
(`suggestionCandidates.filter { $0.item.name != resolvedName }`). Nach dem Merge trägt die Zeile
deshalb **garantiert keinen** namensgleichen `.listMatch`. Regel 5 greift also immer, fügt
`.currentName(line.name)` an Position 0 ein, und `isSelected(.currentName)` ist wahr. Ein zweiter
Treffer ist ausgeschlossen: `.listMatch` verlangt Namensgleichheit (gibt es nicht), `.aiSuggestion`
verlangt `resolvedByAI` (ist false).
Code reference: SmartCart/Services/ReceiptResolutionService.swift:148
Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:443

Gegenprobe, ob eine ALTE KI-Zeile stehenbleiben kann: `aiSuggestedName` wird ausschließlich unter
`resolvedByAI` gesetzt (Konstruktionsstellen `:215` und `:605`, Merge `:136`).
`linesNeedingAIReresolution` wählt nur Zeilen mit `!resolvedByAI` — deren `aiSuggestedName` ist
also nil, es entsteht keine zweite, unmarkierte Namenszeile.
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:215

**Fall A — `resolvedByAI == true`** (Apple Intelligence): `aiSuggestedName == line.name`. Trägt
kein Vorschlag denselben Namen, bleibt die `.aiSuggestion`-Zeile erhalten, Regel 3 sortiert sie
wegen Namensgleichheit nach vorn (überlebt damit auch die Kappung auf 3), und
`isSelected(.aiSuggestion)` ist wahr; `.listMatch` scheidet wegen `resolvedByAI` aus, `.currentName`
wird nicht eingefügt, weil ein Kandidat namensgleich ist. Genau eine Markierung. Trägt ein
Vorschlag denselben Namen, ist es exakt die ausgenommene Konjunktion (F001).
Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:427

Warum F001 nur im KI-Zweig auftreten KANN, sauber hergeleitet: der Vorschlags-Filter läuft mit dem
Namen VOR Stufe 5; die KI-Antwort wird erst danach in `resolvedNames` geschrieben. Nur deshalb kann
ein Vorschlag denselben Namen tragen wie der aufgelöste. Im Nicht-KI-Zweig ist das strukturell
unmöglich.
Code reference: SmartCart/Services/ReceiptResolutionService.swift:160

Bewertung: AKZEPTIERT. Die Wiederaufnahme von `mergeAIReresolution` in Invariante 6 und AC-14 ist
NICHT zu stark — sie trifft genau die Menge, die die Implementierung hält, und die ausgenommene
Konjunktion ist genau die Menge, die sie nicht hält. F105 erledigt.

#### Angriff 24 — „Irgendeine Markierungs-Zusage steht noch ohne Ausnahme da" (Prüffrage 1, dritter Durchgang)

Erneut über die GESAMTE Datei gesucht (Muster: markiert, Markierung, genau eine, vorausgew,
Auswahlkreis, Punkt 4, behoben, Zusage 2, mergeAIReresolution — 40 Fundstellen), und zusätzlich
über alle Ausnahme-Formulierungen (Ausnahme, Ausgenommen, Nicht abgedeckt). Jede Stelle im Kontext
gelesen, auch die in Runde 3 bereits abgehakten.

Die in Runde 3 beanstandeten Stellen tragen die Ausnahme jetzt:

- Zusage 1: „Der aufgelöste Name steht sichtbar in der Auswahlliste (im Regelfall als markierte
  Zeile; Ausnahme F001, siehe Zusage 2) — nicht erst im Feld ‚Anderer Name …'."
  Code reference: docs/specs/views/receipt-review-card.md:375
- AC-13: „**Ausgenommen der Fall F001 (Issue #66):** Trägt ein verbliebener Kandidat denselben
  Namen, verhindert Regel 5 die Einfügung (`ReceiptReviewCard.swift:443-447`), Regel 3 sortiert
  den Listen-Treffer nur nach vorn, und `isSelected` verweigert die Markierung wegen
  `!line.resolvedByAI` (`:369`) — die Karte bleibt dann ohne markierte Zeile." Am Code
  nachgelesen: jede der drei Teilaussagen stimmt.
  Code reference: docs/specs/views/receipt-review-card.md:908
- Beide Scope-Sätze: „behebt Punkt 2 und Punkt 4 (Letzteres bis auf den als F001/#66 beschriebenen
  Eingang)" bzw. „(Punkt 4 bis auf den als F001/#66 beschriebenen Eingang)".
  Code reference: docs/specs/views/receipt-review-card.md:64
  Code reference: docs/specs/views/receipt-review-card.md:153

Zwei Stellen habe ich geprüft und ausdrücklich NICHT beanstandet:

- **AC-4** („Der beste Treffer / aktuelle Zustand der Zeile ist vorausgewählt", Zeile 883) benutzt
  „vorausgewählt" im Sinne der Regeln 3/5 (nach vorn sortiert bzw. eingefügt), nicht im Sinne des
  gefüllten Kreises — so definiert es Regel 3 selbst (Zeile 253). Vorbestehend seit Issue #37, von
  Paket 1 unverändert, und die nicht markierte Variante ist als eigene Known Limitation
  beschrieben (Zeilen 1133-1140).
  Code reference: docs/specs/views/receipt-review-card.md:253
- **DoD, Zeile 1064** („Ein Treffer aus der eigenen Liste ist vorausgewählt") stammt aus der
  Ursprungsfassung und beschreibt den Normalfall des Scans; der Paket-1-Punkt vier Zeilen weiter
  unten trägt die F001-Ausnahme ausdrücklich.
  Code reference: docs/specs/views/receipt-review-card.md:1078

Neu aufgefallen ist mir eine Zahlwort-Unschärfe, siehe Angriff 25.

Bewertung: AKZEPTIERT. Keine Markierungs-Zusage ohne Ausnahme mehr. F106 und F107 erledigt.

#### Angriff 25 — „Die neuen Ausnahme-Sätze zählen falsch"

Invariante 6 schließt mit: „Ausgenommen ist **allein** die Konjunktion aus diesem Weg UND
Namensgleichheit, siehe unten." Drei Zeilen darunter steht aber eine ZWEITE Ausnahme derselben
Invariante („Zweite Restlücke (offen, Teil von Issue #66): Regel 9 hängt allein an `line.name`"),
und am Ende eine dritte (leerer `line.name`). Die Überschrift derselben Invariante sagt korrekt
„mit den unten benannten Ausnahme**n**". Dieselbe Zählung steht im Reichweiten-Satz zu Regel 9
(„mit **zwei** ausdrücklich benannten Ausnahmen") und im Changelog.

Code reference: docs/specs/views/receipt-review-card.md:631
Code reference: docs/specs/views/receipt-review-card.md:646
Code reference: docs/specs/views/receipt-review-card.md:414

Geprüft, ob daraus eine FALSCHE Zusage wird — nein: für die zweite Restlücke gilt, was Runde 2
(Angriff 9) bereits am Code gezeigt hat und was ich nachgerechnet habe. `linesNeedingAIReresolution`
wählt nur Zeilen mit `name == originalName` und `!resolvedByAI`; bleibt der Name byte-gleich, hat
weder der Kandidaten-Zweig noch der Nachfass-Block von `resolve` gegriffen (gleiche Kandidaten,
gleiche Schwelle), `matchedItemID` bleibt nil und `resolvedByAI` false — es ändert sich nichts,
und die vorher markierte `.currentName`-Zeile bleibt markiert. Die „zweite Restlücke" ist ein
theoretischer Mechanismus, kein erreichbarer Fall.

Code reference: SmartCart/Services/ReceiptResolutionService.swift:132
Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:369

Bewertung: NACHFRAGE, Befund F110 (LOW). Wortwahl, keine falsche Zusage: nichts wird versprochen,
was der Code nicht hält, und keine Grenze wird verdeckt — die zweite Restlücke steht drei Zeilen
darunter im selben Absatz, AC-14 nennt sie ebenfalls (Zeile 919).

#### Angriff 26 — „F104, Changelog und Test Plan sind nur behauptet"

- F104 steht jetzt als eigene Known Limitation vor dem F001-Punkt, mit meiner Messung (Tabulator,
  U+00A0, alle Zs-Leerzeichen, U+200B erfasst; U+000A/U+000B nicht), der richtigen Einordnung
  („AC-18 ist unverletzt … AC-16 nur dem Buchstaben nach erfüllt"), der unbewiesenen
  Erreichbarkeit, Issue #69 und der Warnung, beim Umstellen auf `.whitespacesAndNewlines` die
  Symmetrie zwischen `ReceiptScannerView.swift:106` und `ReceiptReviewCard.swift:499-500` zu
  wahren. Gegen meine eigene Probe aus Runde 1 gelesen: stimmt in jedem Detail.
  Code reference: docs/specs/views/receipt-review-card.md:1141
  Code reference: docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift
- Changelog: neuer Abschnitt „2026-09-28 — Korrekturgang nach dem zweiten und dritten Prüfdialog"
  nennt alle neun Befunde, führt F105 ausdrücklich als Überschuss des ersten Korrekturversuchs und
  hält fest, dass kein Produktivcode berührt wurde. Kopffeld steht auf `updated: 2026-09-28`.
  Code reference: docs/specs/views/receipt-review-card.md:1221
- Gegenprobe gegen einen stillen Nachzug im Test Plan: weiterhin genau EIN offener Punkt
  („AC-4 (Rest, verschoben nach Issue #66)") und 40 abgehakte Punkte — kein Häkchen ist in diesem
  Korrekturgang dazugekommen, kein Testnachweis umgeschrieben worden.
  Code reference: docs/specs/views/receipt-review-card.md:733

Bewertung: AKZEPTIERT. F104 und F109 erledigt; der Korrekturgang hat den Nachweisteil der Spec
nicht angefasst.

---

## Befunde (Runde 4)

```
Finding:
  ID: F110
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/specs/views/receipt-review-card.md:631
  Description: Invariante 6 endet mit „Ausgenommen ist allein die Konjunktion aus diesem Weg UND
    Namensgleichheit, siehe unten." Unter „siehe unten" stehen aber zwei weitere Ausnahmen
    derselben Invariante: die „Zweite Restlücke" (Zeile 646, byte-gleicher Name) und der leere
    line.name (Zeile 650). Die Überschrift derselben Invariante sagt korrekt „mit den unten
    benannten Ausnahmen" (Plural); der Reichweiten-Satz zu Regel 9 (Zeile 414) zählt „zwei"
    Ausnahmen und lässt die zweite Restlücke ebenfalls aus.
  Spec requirement: Invariante 6 selbst, Zeilen 622-655 — drei benannte Ausnahmen.
  Conflict: Zahlwort-Widerspruch im selben Absatz. KEINE falsche Zusage: die zweite Restlücke ist
    ein theoretischer Mechanismus ohne erreichbaren Fall (linesNeedingAIReresolution wählt nur
    Zeilen mit name == originalName und !resolvedByAI; bleibt der Name byte-gleich, hat auch der
    Nachfass-Block von resolve nicht gegriffen, matchedItemID bleibt nil, resolvedByAI false — die
    vorher markierte .currentName-Zeile bleibt markiert). Deshalb LOW: kein Leser wird über eine
    Grenze getäuscht, und AC-14 nennt beide Ausnahmen vollständig.
  Remediation: In Zeile 631 „allein" streichen („Ausgenommen sind die unten benannten Fälle") und
    in Zeile 414 entweder „drei" schreiben oder die zweite Restlücke dort als „theoretisch, kein
    erreichbarer Fall" mitnennen. Reine Wortwahl, nachziehbar beim nächsten Anfassen der Spec.
```

## Bestätigungen (Runde 4)

```
Confirmation:
  AC: F105 — mergeAIReresolution ist wieder abgedeckt, und zwar genau so weit, wie der Code trägt
  Code reference: docs/specs/views/receipt-review-card.md:622
  Evidence: Invariante 6 nennt die drei Zuweisungswege wieder vollständig und begründet die
    Wiederaufnahme am reproduzierten Fall (ReceiptResolutionService.swift:104,
    ReceiptScannerView.swift:126, UI-Test :842). Am Code gegengeprüft statt geglaubt: im
    Nicht-KI-Zweig filtert resolve die Vorschläge gegen den aufgelösten Namen
    (ReceiptResolutionService.swift:148), deshalb greift Regel 5 dort immer und genau eine Zeile
    ist markiert; im KI-Zweig ist entweder die .aiSuggestion-Zeile markiert oder es liegt die
    ausgenommene Konjunktion vor. aiSuggestedName wird ausschließlich unter resolvedByAI gesetzt
    (ReceiptScannerView.swift:215/:605/:136), eine zweite unmarkierte Namenszeile kann nicht
    entstehen. Weder zu stark noch zu schwach.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F105 — AC-14 widerspricht sich nicht mehr selbst
  Code reference: docs/specs/views/receipt-review-card.md:913
  Evidence: AC-14 zählt dieselben drei Wege auf wie Invariante 6 und beruft sich danach auf den
    reproduzierten Fall — der jetzt INNERHALB der Aufzählung liegt. Der „Nicht abgedeckt"-Satz
    nennt beide Ausnahmen (F001 und die byte-gleiche Änderung). Der grüne UI-Nachweis
    (RestockUITests/ReceiptReviewUITests.swift:842) deckt damit wieder eine Zusage der Spec.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F106 — AC-13 und Zusage 1 tragen die F001-Ausnahme
  Code reference: docs/specs/views/receipt-review-card.md:908
  Evidence: AC-13 beschreibt die Ausnahme mit allen drei Wirkmechanismen (Regel 5 greift nicht,
    Regel 3 sortiert nur, isSelected verweigert wegen !resolvedByAI) und den Codestellen; jede
    Teilaussage am heutigen Code nachgelesen (ReceiptReviewCard.swift:443-447 und :369). Zusage 1
    (Zeile 375) sagt jetzt „sichtbar in der Auswahlliste (im Regelfall als markierte Zeile;
    Ausnahme F001, siehe Zusage 2)".
  Status: CONFIRMED
```

```
Confirmation:
  AC: F107 — beide „behebt Punkt 4"-Stellen sind eingeschränkt
  Code reference: docs/specs/views/receipt-review-card.md:64
  Evidence: Zeile 64 „behebt Punkt 2 und Punkt 4 (Letzteres bis auf den als F001/#66 beschriebenen
    Eingang)", Zeile 153 „(Punkt 4 bis auf den als F001/#66 beschriebenen Eingang)". Deckt sich mit
    Invariante 6 (Zeile 641) und Known Limitations (Zeile 1156).
  Status: CONFIRMED
```

```
Confirmation:
  AC: F104 — als Known Limitation aufgenommen
  Code reference: docs/specs/views/receipt-review-card.md:1141
  Evidence: Messwerte, Symmetrie-Argument (AC-18 unverletzt, AC-16 nur dem Buchstaben nach),
    unbewiesene Erreichbarkeit, Issue #69 und die Warnung zur Symmetrie beim Umstellen auf
    .whitespacesAndNewlines — deckungsgleich mit meiner Probe aus Runde 1
    (probe-whitespace-1b.swift).
  Status: CONFIRMED
```

```
Confirmation:
  AC: F108 — Briefing-Bindung stimmt wieder
  Code reference: docs/briefings/fix-50-import-dialog-design.md:3
  Evidence: Kopf und Datei tragen beide 127ad63b32218e8199c9a6562227fbe8d954c5c61da27e6b640da808
    cde24461 (selbst nachgerechnet). Der Briefing-Text ist unverändert und bleibt korrekt: „Was
    gebaut wird" und DoD tragen die F001-Ausnahme mit Ticketnummer.
  Status: CONFIRMED
```

```
Confirmation:
  AC: F109 — Korrekturgang ist nachvollziehbar
  Code reference: docs/specs/views/receipt-review-card.md:1221
  Evidence: Changelog-Abschnitt vom 2026-09-28 nennt alle neun Dokumenten-Befunde, führt F105
    ausdrücklich als Überschuss des ersten Korrekturversuchs und hält fest, dass kein Produktivcode
    berührt wurde; Kopffeld updated: 2026-09-28. Gegenprobe: im Test Plan ist weiterhin genau ein
    Punkt offen und keiner neu abgehakt.
  Status: CONFIRMED
```

```
Confirmation:
  AC: Produktivcode und Tests seit Runde 2 unverändert
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:490
  Evidence: Differenzstatistik unverändert (+6/−2 in der Karte, +50/+56 in den Testdateien);
    geändert wurden ausschließlich Spec und Briefing. Die Nachweise aus Runde 2 gelten weiter:
    eigener Lauf 31 Tests/0 Fehler (adversary-test-output-1b.txt), green-run3b-suite.txt 271 Unit-
    plus 19 UI-Tests, 0 Fehler, ein TEST SUCCEEDED, keine Übersprünge.
  Status: CONFIRMED
```

---

## Bewertung je Checklistenpunkt (Stand Runde 4 — ersetzt die Tabellen aus Runde 2 und 3)

| Punkt | Ergebnis | Begründung |
|-------|----------|------------|
| 1 — AC-18 (Leerzeichen lösen denselben Rückfall aus, keine still verworfene Position) | PROVEN | Runde 1/2: Guard und Rückfall getrimmt, alle drei Felder, zwei Unit-Tests plus UI-Test mit RED-Beleg; Code seitdem unverändert |
| 2 — AC-15 präzisiert, line.name nie leer oder Leerzeichen, Textfeld unangetastet | PROVEN | Runde 1/2, unverändert |
| 3 — Widerspruchsfreiheit Invariante 6 / Known Limitations / AC-13 / AC-14 | PROVEN | Alle in den Runden 2 und 3 beanstandeten Stellen tragen die F001-Ausnahme (Invariante 6, AC-13, AC-14, Reichweiten-Satz, Zusage 1, beide Scope-Sätze, DoD). Rest: eine Zahlwort-Unschärfe ohne falsche Zusage (F110, LOW) |
| 4 — Regel 11 als Verteidigung in der Tiefe, einziger Weg geschlossen | PROVEN | Runde 3: auf „über die Karte" eingeschränkt, KI-Weg als erreichbare Quelle mit #69 benannt |
| 5 — F001 unberührt, Dedup-Test grün | PROVEN | Runde 2, unverändert |
| 6 — Test-Plan-Integrität (mindestens vier Stichproben) | PROVEN | Runde 2: sechs Stichproben gedeckt; Runde 4 gegengeprüft: kein Häkchen im Korrekturgang dazugekommen |
| Zusatz — PO-Briefing | PROVEN | Text erledigt (Runde 3), Bindung neu gesetzt und nachgerechnet (Runde 4) |
| Zusatz — Gegenrichtung: keine zu schwache und keine zu starke Aussage | PROVEN | mergeAIReresolution wieder abgedeckt; am Code hergeleitet, dass die Zusage genau die Menge trifft, die die Implementierung hält (Nicht-KI-Zweig strukturell markiert, KI-Zweig markiert oder F001) |

---

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════

Der Stand hält vier Prüfrunden stand — zwei am Code, zwei an den Dokumenten.

Code: unverändert seit Runde 2 und dort vollständig bewiesen. Tests: eigener Lauf 31 bestanden,
0 fehlgeschlagen, TEST SUCCEEDED; Nachweisprotokoll green-run3b-suite.txt 271 Unit- plus 19
UI-Tests, 0 fehlgeschlagen, keine Übersprünge, keine Wiederholungsläufe. RED und GREEN betreffen
dieselben drei Funktionen. Kein Regress; F001 unberührt, der zugehörige Bestandstest grün.

Dokumentenlage: alle neun Befunde der Runden 1-3 sind geschlossen. F101/F106/F107 — jede
Markierungs-Zusage trägt die F001-Ausnahme, auch Zusage 1, AC-13 und die beiden Scope-Sätze.
F102/F108 — das Briefing verspricht nicht mehr, als der Code hält, und ist wieder an den heutigen
Spec-Stand gebunden. F103/F104 — beide Leerzeichen-Aussagen sind auf den Karten-Weg eingeschränkt,
der KI-Weg und der Zeilenumbruch-Fall stehen als Known Limitations mit Issue #69. F109 — der
Korrekturgang ist im Changelog datiert und benannt.

**Prüffrage 3 (Gegenrichtung) ausdrücklich beantwortet:** Die Rücknahme von F105 schießt NICHT über
das Ziel hinaus. Ich habe beide Ausgänge von `mergeAIReresolution` am Code durchgespielt: im
Nicht-KI-Zweig filtert `resolve` die Vorschläge gegen den aufgelösten Namen, deshalb greift Regel 5
dort strukturell immer und genau eine Zeile ist markiert; im KI-Zweig ist die `.aiSuggestion`-Zeile
markiert, außer bei Namensgleichheit — und genau diese Konjunktion nimmt die Spec aus. Die Zusage
trifft damit exakt die Menge, die die Implementierung hält.

Offen bleibt ausschließlich F110 (LOW, Wortwahl): „Ausgenommen ist **allein** die Konjunktion"
(Zeile 631) und „mit **zwei** ausdrücklich benannten Ausnahmen" (Zeile 414) zählen die im selben
Absatz stehende zweite Restlücke nicht mit. Keine falsche Zusage — der Fall ist am Code nicht
erreichbar, und AC-14 nennt ihn vollständig. Nachziehbar beim nächsten Anfassen der Spec, kein
Grund, den Stand aufzuhalten.

Die bewusst offene Grenze F001 ist damit widerspruchsfrei dokumentiert: in der Spec mit Mechanik
und Codestellen, im Briefing in PO-Sprache, beide mit Issue #66 und vorgeschaltetem Design-Entwurf.

Tests: 31 bestanden, 0 fehlgeschlagen (eigener Lauf); 271 + 19 bestanden, 0 fehlgeschlagen
(Nachweisprotokoll). Edge Cases: Leerzeichen, geschütztes Leerzeichen, Zeilenumbruch, leerer
Rückfall, namensgleiche Auflösung, byte-gleicher Name — alle geprüft, keiner bricht. Regressionen:
keine. Checkliste: 8 von 8 Punkten bewiesen.

## Geprüfte Dateien

- sha256:4a090efdb7d5af88f239d1990ed61327e9feda13650864d68ebec582d852a9d4  RestockTests/ReceiptReviewCardTests.swift
- sha256:d0ea5e968ae9754800cc383095fe46cd01e314c5678005dc3cfa9c9d880e1045  RestockTests/ReceiptScannerReResolutionTests.swift
- sha256:851566bcad5dd8ac3020a458f6cd40013523e55112f452e5602c6e373e232757  RestockUITests/ReceiptReviewUITests.swift
- sha256:b709d56b302b570736637c3f46ce705b7be02483caa5d5aae6094ee8da10a796  SmartCart/Services/ReceiptParserService.swift
- sha256:69164434075e8d67d5937c046192ed402a973969edd6a104df15e964394882f6  SmartCart/Services/ReceiptResolutionService.swift
- sha256:6f6fbbe30247d1a54d82270574cec100998c831e991feb63f8ff4d948e8bdfe7  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:46ad8942466f785ebb8538835e2d1e73a7f4fa993e21c82ef4eab794151af91e  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:ff5c1296c36b6f2621746ff79a45bf98fb4c0d6cd02c8a87e42f86cc3c89c684  docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b-fail1-issue63.txt
- sha256:2338e8af4b5c71d6fd4f2b7e6b2979d7d24e9f61887123397d73bd44535014e4  docs/artifacts/fix-50-import-dialog-design/adversary-test-output-1b.txt
- sha256:bf6583f7fbe03f280b5e93ae4e982e0ab13e5a41c81ee74fa8e2adea0420027f  docs/artifacts/fix-50-import-dialog-design/green-run3-suite.txt
- sha256:91bceaa3d4890eea1b18699844ef91dfd7fbd9b8c3a7ffe64662110aaaec72a8  docs/artifacts/fix-50-import-dialog-design/green-run3b-suite.txt
- sha256:08c52f2ea256309e76a7a06e2d33e14e15f781fbf4752a0ab5baac2e8df65f90  docs/artifacts/fix-50-import-dialog-design/probe-whitespace-1b.swift
- sha256:e797917f930b7ec46102f153e7f462f8baef825a748f3c0179ac05d50d3b7d3c  docs/artifacts/fix-50-import-dialog-design/test-red-ui-1b.txt
- sha256:36edc3f378a973f09db84028b41b40e5830a50ada37c046e5a5cec5c86ed5b1d  docs/artifacts/fix-50-import-dialog-design/test-red-unit-1b.txt
- sha256:a0cb482cec94c091210e665d363c58d29ae6afd90ac85259301e8f68a8fe8b31  docs/briefings/fix-50-import-dialog-design.md
- sha256:127ad63b32218e8199c9a6562227fbe8d954c5c61da27e6b640da808cde24461  docs/specs/views/receipt-review-card.md
