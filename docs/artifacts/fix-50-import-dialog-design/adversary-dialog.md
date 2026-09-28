# Adversary-Dialog — fix-50-import-dialog-design (Issue #50, Paket 1)

- Datum: 2026-09-27
- Spec: `docs/specs/views/receipt-review-card.md` (Nachtrag Issue #50, Paket 1; Regeln 9-11;
  Invarianten 1 und 6; Known Limitations; AC-2, AC-4 bis AC-7, AC-12 bis AC-16)
- Umsetzung: Stand `fcc8018` ("fix: Auswahl der Bon-Karte stimmt wieder (#50, Paket 1)")
- Rolle: Adversary. Annahme: die Umsetzung ist falsch, bis das Gegenteil an Code und Testausgabe
  belegt ist. Die Spec ist der Maßstab, nicht der Code.
- Eigener Prüflauf: `docs/artifacts/fix-50-import-dialog-design/adversary-test-output.txt`

---

### Runde 0 — Eigener Testlauf (nichts geglaubt, selbst gemessen)

Kommando (seriell, keine Zusatz-Build-Settings, kein CODE_SIGNING_ALLOWED=NO):

    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
      -scheme Restock -project Restock.xcodeproj \
      -destination "platform=iOS Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7" \
      -only-testing:RestockTests/ReceiptReviewCardTests \
      -only-testing:RestockTests/ReceiptScannerReResolutionTests

Ergebnis (`adversary-test-output.txt`):

    Test Suite 'ReceiptReviewCardTests' passed          Executed 24 tests, with 0 failures
    Test Suite 'ReceiptScannerReResolutionTests' passed  Executed 5 tests, with 0 failures
                                                        Executed 29 tests, with 0 failures
    ** TEST SUCCEEDED **   (exit 0)

Geprüft und nicht gefunden: "Executed 0 tests", TEST FAILED, BUILD FAILED, ein Retry-/
Wiederholungs-Flag, ein Suite-Neustart. Die einzigen Log-Auffälligkeiten sind CloudKit
(CKAccountStatusNoAccount) und ein linkd-Hinweis — beides simulator-typisch, ohne Testwirkung.

**Bewertung: AKZEPTIERT** (eigene Messung, nicht die vorgelegte).

### Prüfung der vorgelegten Nachweise

Code reference: docs/artifacts/fix-50-import-dialog-design/test-green-output.txt

- Lauf 2: `Executed 29 tests, with 0 failures`, `** TEST SUCCEEDED **` (Z. 553-578).
- Lauf 3: `Executed 2 tests, with 0 failures` (Z. 777-789); namentlich
  `testClearingCustomNameFieldKeepsPreviousItemName` (Z. 729) und
  `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` (Z. 775).
- Lauf 4: `Executed 269 tests, with 0 failures` (Z. 1585) plus die 18 UI-Tests der Klasse
  `ReceiptReviewUITests` (Z. 1879 / 2578 u. a.).
- Keine "Executed 0 tests"-Stelle, kein TEST FAILED, kein Retry-Flag, kein Suite-Neustart.

RED-GREEN-Gegenprobe (dieselben Testfunktionen, nicht bloß dieselbe Anzahl):

Code reference: docs/artifacts/fix-50-import-dialog-design/test-red-unit.txt
Code reference: docs/artifacts/fix-50-import-dialog-design/test-red-ui.txt
Code reference: docs/artifacts/fix-50-import-dialog-design/test-red-ui-ac15.txt

| Testfunktion | RED | GREEN |
|---|---|---|
| `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName` | failed (red-unit Z. 601) | passed (green Z. 513) |
| `testApplyCustomNameOrFallbackRestoresAIStateOnEmptyName` | failed (red-unit Z. 597) | passed (green Z. 511) |
| `testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged` | passed (red-unit Z. 592, Regressionswächter) | passed (green Z. 509) |
| `testIsSavableRejectsLineWithEmptyName` | failed (red-unit Z. 650) | passed (green Z. 560) |
| `testIsSavableKeepsIncludedNamedLineAndRejectsOldCases` | passed (red-unit Z. 646, Regressionswächter) | passed (green Z. 558) |
| `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` | failed (red-ui Z. 184) | passed (green Z. 775) |
| `testClearingCustomNameFieldKeepsPreviousItemName` | failed (red-ui Z. 143, red-ui-ac15 Z. 170) | passed (green Z. 729) |

NACHFRAGE: Die RED-Datei meldet "24 tests, with 5 failures", aber nur zwei fehlgeschlagene
Testfälle. Nachgeprüft: xcodebuild zählt in dieser Zeile Assertion-Fehler, nicht Testfälle — die
Suche nach "Test Case .*failed" liefert exakt drei Funktionen über beide Suiten. Kein verdeckter
Zusatzfehler. **Bewertung: AKZEPTIERT.**

---

### Runde 1 — Angriff auf die neuen Zusagen (AC-13 bis AC-16)

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift

### Angriff 1 — "Springt die Liste unter dem Finger?" (Regel 9, AC-13 zweite Hälfte)

Regel 9 (`ReceiptReviewCard.swift:119-122`) hängt alles am Guard
`!options.contains(where: { isSelected($0) })`. Ich habe `isSelected` (`:366-380`) gegen
`applySelection` (`:458-475`) und `select` (`:382-396`) für ALLE vier Optionsarten gestellt:

| Getippte Option | applySelection schreibt | isSelected danach | gleiche Vergleichsgrundlage? |
|---|---|---|---|
| `.listMatch(s)` | name = s.name, matchedItemID = s.itemID, resolvedByAI = false | !customActive && !resolvedByAI && matchedItemID == s.itemID && name == s.name (ci) -> true | ja, beide s.name wörtlich |
| `.aiSuggestion(n)` | name = aiSuggestedName ?? n, matchedItemID = aiSuggestedMatchedItemID, resolvedByAI = true | !customActive && resolvedByAI && name == (aiSuggestedName ?? n) (ci) -> true | ja, derselbe Ausdruck auf beiden Seiten |
| `.currentName(n)` | name = n | !customActive && name == n (ci) -> true | ja |
| `.custom` | (nichts) | customActive -> true, weil select es vorher setzt | ja |

`select(_:)` setzt für alle Nicht-custom-Fälle `customActive = false` VOR `applySelection`
(`:394-395`), also kann kein !customActive-Term die eben getippte Zeile aussperren. Es gibt keine
Normalisierung (Trim, Unicode-Faltung) auf einer Seite, die auf der anderen fehlt — beide Seiten
vergleichen dieselbe Zeichenkette per caseInsensitiveCompare. Der Guard ist nach jedem Nutzer-Tap
wahr, `options` bleibt stehen.

**Bewertung: AKZEPTIERT** — die zweite Hälfte von AC-13 ("bleibt unverändert stehen") ist belegt.

### Angriff 2 — "Zwei markierte Zeilen?" (AC-14, Fall "nie zwei")

Gesucht: ein erreichbarer Zustand, in dem `isSelected` für zwei Optionen gleichzeitig true liefert.

- `.currentName(X)` + gleichnamiger `.listMatch`: Regel 5 (`:443-447`) fügt `.currentName` nur ein,
  wenn KEIN Kandidat case-insensitiv `line.name` entspricht — ein gleichnamiger `.listMatch`
  schließt die Einfügung aus. Für die Neuberechnung aus Regel 9 gilt dasselbe, sie rechnet mit dem
  aktuellen Namen.
- `.currentName(X)` + `.aiSuggestion(X)`: gleiche Begründung, `.aiSuggestion` ist zum Zeitpunkt von
  Regel 5 selbst Kandidat.
- zwei gleichnamige `.listMatch`: `isSelected` verlangt zusätzlich matchedItemID == s.itemID; und
  `completedItemCandidates` dedupliziert Artikel nach Namen
  (`ReceiptParserService.swift:1186-1192`), zwei gleichnamige Vorschläge entstehen also gar nicht.
- `.listMatch` + `.aiSuggestion`: schließen sich über resolvedByAI gegenseitig aus (`:369` vs. `:373`).
- eingefrorene `.aiSuggestion` + später extern gesetztes aiSuggestedName: nicht erreichbar, weil
  `linesNeedingAIReresolution` (`ReceiptScannerView.swift:112-117`) nur Zeilen mit !resolvedByAI
  auswählt und aiSuggestedName für solche Zeilen an allen Konstruktionsstellen nil ist — eine
  eingefrorene `.aiSuggestion`-Zeile existiert dort nicht.

**Bewertung: AKZEPTIERT für "nie zwei".** Für "nie null" siehe Angriff 3 — dort wird es brüchig.

### Angriff 3 — "Nie null markiert?" (AC-14/Invariante 6) -> Finding F001

Code reference: SmartCart/Services/ReceiptResolutionService.swift

Ich habe die Neuberechnung aus Regel 9 gegen `isSelected` gestellt und einen erreichbaren Zustand
gefunden, in dem NACH der Neuberechnung KEINE Option markiert ist — im genau von AC-13
adressierten Weg (`reResolveAIIfNeeded()` nach dem Teilen-Handoff), wenn Stufe 5 auflöst:

1. `ReceiptResolutionService.resolve` berechnet `resolvedName` VOR der KI-Stufe (`:120`) und filtert
   die Vorschlagsliste gegen genau diesen Vor-KI-Namen (`:152`). Erst danach überschreibt Stufe 5
   den Namen (`:175-176`). Folge: der KI-Name kann unverändert in `suggestions` stehen.
2. `mergeAIReresolution` (`ReceiptScannerView.swift:130-143`) schreibt name, suggestions,
   matchedItemID, resolvedByAI = true und aiSuggestedName = r.name in die Zeile. Für eine KI-Zeile
   ist matchedItemID immer nil: der matchedItemID-Nachgriff in resolve (`:130-140`) benutzt dieselbe
   Bedingung (score >= 0,6, nicht verbraucht) wie Stufe 3, die für eine needsAI-Zeile gerade
   fehlgeschlagen ist.
3. `selectionOptions` (`ReceiptReviewCard.swift:415-454`): Dedup-Regel 2 (`:418-425`) entfernt die
   `.aiSuggestion`-Zeile, weil ein `.listMatch` denselben Namen trägt; Regel 3 (`:428-433`) sortiert
   diesen `.listMatch` nach vorn; Regel 5 (`:443-447`) greift NICHT, weil ein Kandidat dem Namen
   entspricht. Ergebnis: [.listMatch("Butter"), ..., .custom].
4. `isSelected(.listMatch)` (`:368-371`) verlangt !line.resolvedByAI -> false, und keine andere
   Option kann greifen (.aiSuggestion wegdedupliziert, .currentName nie eingefügt).
   NULL markierte Zeilen bei nicht-leerem line.name.

Erreichbarkeit, konkret: ein Artikel "Butter" steht auf der Liste, ist aber noch NICHT abgehakt.
`completedItemCandidates` liefert ihn trotzdem als Vorschlag, weil der Vorschlags-Pool alle Artikel
umfasst (`ReceiptResolutionService.swift:96`, Kommentar "Breiterer Kandidaten-Pool NUR für die
Vorschlags-Chips"), während die automatische Übernahme auf completedItems beschränkt bleibt.
lcsSimilarity("BTR","Butter") = 2*3/(3+6) = 0,67 liegt über dem Vorschlags-Floor 0,45
(`ReceiptParserService.swift:1160`); die Stufen 1-4 greifen dennoch nicht (Artikel nicht abgehakt)
-> Stufe 5 läuft, und der Wortschatz-Kontext der KI besteht genau aus den Artikelnamen dieses
Ladens (`knownItemNames`), die KI liefert also bevorzugt exakt "Butter".

Der vorgelegte UI-Nachweis deckt diesen Zweig NICHT ab:
Code reference: RestockUITests/ReceiptReviewUITests.swift
`Seed.unresolvedLineExpectedName` ist ausdrücklich "Ergebnis von Stufe 2 der Auflösung
(expandAbbreviations) ... ohne Apple Intelligence", also resolvedByAI == false — genau der Pfad, in
dem Regel 5 den .currentName-Ausweg einfügt.

**Bewertung: NACHFRAGE -> offene Lücke, siehe F001.** Die Spec widerspricht sich hier selbst:
Invariante 6 nennt mergeAIReresolution ausdrücklich als abgedeckten Zuweisungsweg, die Known
Limitations erklären den wortgleichen Symptomfall als vorbestehend und bewusst offen.

### Angriff 4 — "Nur Leerzeichen" (Regel 10 vs. Regel 11, AC-15/AC-16) -> Finding F002

Regel 10 guardet auf name.isEmpty (`ReceiptReviewCard.swift:497`), Regel 11 auf
name.trimmingCharacters(in: .whitespaces).isEmpty (`ReceiptScannerView.swift:104-108`). Tippt der
Nutzer im Feld "Anderer Name ..." ein einzelnes Leerzeichen, ist isEmpty == false -> der Rückfall
greift nicht, `applyCustomName` schreibt line.name = " " (`:479-483`) und löscht dabei
matchedItemID/resolvedByAI. Danach:

- Der Buchstabe der Zusage 3 hält: line.name ist nie LEER geschrieben worden.
- Gerettet wird die Datenlage allein von Regel 11 — die Position wird beim Speichern verworfen.
- Der Nutzer erfährt davon nichts: Kopfzeile und Summe zählen weiter über isIncluded
  (`ReceiptScannerView.swift:507-509`, `:224`), canSave ebenfalls (`:260`). Die Karte zeigt ein
  gesetztes Häkchen ("Position übernehmen:  "), die Kopfzeile zählt sie als "ausgewählt" und in der
  Summe — save() überspringt sie still, Haptics.success() und dismiss() laufen trotzdem. Ist es die
  einzige Position, wird gar nichts gespeichert, ohne Hinweis.

Die Spec führt diesen Fall weder in Regel 10 ("bei JEDEM leeren Zwischenstand") noch in den Known
Limitations auf; sie begründet den Rückfall gerade damit, den Nutzer "nicht vor eine gesperrte
Schaltfläche zu stellen" — hier entsteht stattdessen ein stiller Verlust ohne Rückmeldung.

**Bewertung: NACHFRAGE -> F002 (MEDIUM).**

---

### Runde 2 — Nachbohren: Zustandslebensdauer, Recycling, Reichweite, Regressionen

### Angriff 5 — Überlebt `previousSelectionBeforeCustom` zu lange? (AC-15)

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift

`previousSelectionBeforeCustom` wird in `select(_:)` bei JEDEM Betreten von .custom neu geschrieben
(`:384-386`); customActive wird ausschließlich dort gesetzt (`:388` true, `:394` false — die einzigen
Zuweisungen der Datei). Durchgespielter Angriffspfad:

1. .custom bei Name "Vollmilch" -> gemerkt ("Vollmilch", id, false)
2. "Xyz" tippen -> line.name = "Xyz", matchedItemID = nil
3. Zeile "Buttermilch" antippen -> customActive = false, neue Zuordnung
4. erneut .custom -> ÜBERSCHREIBT den Merkzustand auf ("Buttermilch", neueID, false)
5. Feld leeren -> Rückfall auf ("Buttermilch", neueID, false)

Der Rückfall zeigt also den NEUEREN, nicht einen veralteten Zustand. Der ??-Zweig (`:272-273`) ist
reine Verteidigung: previousSelectionBeforeCustom == nil bei gleichzeitig customActive == true ist
nicht konstruierbar, weil beide @State derselben View gemeinsam zurückgesetzt werden.
**Bewertung: AKZEPTIERT.**

NACHFRAGE: Feuert `.onChange(of: customName)` beim Vorbelegen in Schritt 4 (Wert wechselt von "Xyz"
auf "Buttermilch") und überschreibt damit matchedItemID mit nil? Geprüft: die Zuweisung
customName = line.name (`:387`) passiert VOR customActive = true (`:388`); das Feld samt seinem
.onChange existiert in diesem Update noch nicht (`optionRow` zeigt customNameRow() nur bei
customActive, `:194-195`), und onChange feuert nicht für den Anfangswert einer neu erscheinenden
View. Der UI-Test zu AC-15 prüft nach dem Leeren genau das Häkchen-Label und ist grün.
**Bewertung: AKZEPTIERT.**

### Angriff 6 — Zellen-Recycling (Spec-Risiko, AC-15)

Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift

Die Karten liegen in einem VStack INNERHALB einer einzigen Section-Zeile (`:492-496`, mit Begründung
im Kommentar darüber) — nicht als je eigene, lazy erzeugte Listenzeile. Wird diese Zeile doch
recycelt, fallen options, customActive UND previousSelectionBeforeCustom gemeinsam zurück; onAppear
(`:112-114`) baut options aus dem aktuellen line neu auf, und die .custom-Eingabe existiert danach
nicht mehr. Ein Zustand "leeres Feld aktiv, Merkzustand verloren" ist damit nicht erreichbar. Der
von der Spec befürchtete Rest (ein überlebender leerer Name) wird zusätzlich von Regel 11
abgefangen. **Bewertung: AKZEPTIERT** — AC-15 wird durch Recycling nicht gebrochen; die
Mehrfach-Absicherung aus Regel 11 ist begründet, nicht überflüssig.

### Angriff 7 — Reichweite von AC-16: zweiter Schreibpfad in save()?

Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift

Volltextsuche nach parsedLines in der Datei: Z. 167, 204, 224, 231, 260, 342, 345, 349, 412, 493,
507, 508, 547, 594, 615. Schreibend/lernend arbeitet ausschließlich save() ab Z. 615 mit `included`;
die Suche nach "PurchaseRecord(" in SmartCart/Views/Prices/ liefert genau eine Stelle (`:742`), und
die liegt in der Schleife `for line in included`. Auch store.learnedPrices[lineLower],
learnedPriceUnits, learnedPriceDates (`:691-693`) und ReceiptAliasService.learn (`:623`) liegen in
derselben Schleife. Kein zweiter Pfad, der parsedLines direkt benutzt; die übrigen Vorkommen sind
Anzeige/Summen/Auswahl (224, 231, 260, 507, 508) bzw. Nachauflösung (342-349).

**Bewertung: AKZEPTIERT** — AC-16 greift an allen Stellen, die einen Kaufdatensatz anlegen oder
einen Preis lernen.

### Angriff 8 — Regressionsschutz AC-2 / AC-4 bis AC-7 / AC-12

- `selectionOptions` ist durch fcc8018 unverändert (der Diff berührt nur body, select,
  customNameRow, applyCustomNameOrFallback): keine zusätzliche Options-Zeile, kein verschobener
  option.<k>-Index. Die vier Index-Tests der Risikoliste
  (testCardShowsAtMostFourSelectionOptions, testTappingListMatchSelectsThatOption,
  testCustomNameOptionOpensFocusedTextField, testTypingCustomNameIsAppliedWithEveryKeystroke) sind
  in Lauf 4 grün (18/18 UI-Tests der Klasse).
- applySelection/applyCustomName unverändert; applyCustomNameOrFallback delegiert für jeden
  nicht-leeren Namen an applyCustomName (`:506`), bewacht durch
  testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged (in RED bereits grün, also echter
  Regressionswächter).
- save() weicht in genau einer Zeile ab (`:615`); 269 Unit-Tests und die AC-12-UI-Strecke
  ("Speichern -> Preis am Artikel sichtbar") sind grün.

**Bewertung: AKZEPTIERT.**

### Angriff 9 — Nebenbefunde (nicht Paket 1, aber belastbar)

Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift

- `applySelection` setzt im .currentName-Zweig NUR line.name (`:470-471`). Wer zuerst einen
  Listen-Treffer und danach die .currentName-Zeile antippt, behält dessen matchedItemID — save()
  schreibt den Preis dann über matchedItem auf den FALSCHEN Artikel
  (`ReceiptScannerView.swift:642-645`, `:709`). Vorbestehend seit Issue #37, von Paket 1 nicht
  berührt, durch die Neuberechnung aus Regel 9 aber häufiger sichtbar (F003).
- Während customActive trägt keine Options-Zeile den .isSelected-Trait bzw. einen gefüllten
  Radiopunkt: optionRow ersetzt die .custom-Zeile durch das Textfeld (`:194-195`), der Trait hängt
  nur an den Nicht-Custom-Zeilen (`:202`, `:220`). Eine Zählung "genau ein gefüllter Auswahlkreis"
  liefert während der Eingabe 0 (F004). Vorbestehend, von keinem Test abgedeckt.

---

## Findings

    Finding:
      ID: F001
      Severity: HIGH
      Category: spec_violation
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
      Code reference: SmartCart/Services/ReceiptResolutionService.swift
      Description: Löst Stufe 5 (Apple Intelligence) eine Zeile in reResolveAIIfNeeded() auf einen
        Namen auf, der wörtlich einem Eintrag ihrer eigenen suggestions entspricht, bleibt die Karte
        nach der Neuberechnung aus Regel 9 OHNE markierte Zeile: Dedup-Regel 2
        (ReceiptReviewCard.swift:418-425) entfernt die .aiSuggestion-Zeile, Regel 5 (:443-447)
        greift nicht (ein Kandidat entspricht dem Namen), und isSelected(.listMatch) (:368-371)
        verlangt !line.resolvedByAI, das nach mergeAIReresolution
        (ReceiptScannerView.swift:130-143) aber true ist. Der Name ist sichtbar (Zusage 1 erfüllt),
        aber "keine Option markiert" — Punkt 4 aus Issue #50 — bleibt für diesen Eingang bestehen.
        Erreichbar, weil resolve die Vorschlagsliste gegen den VOR-KI-Namen filtert
        (ReceiptResolutionService.swift:120 und :152) und Stufe 5 den Namen erst danach
        überschreibt (:175-176); der KI-Wortschatz besteht genau aus den Artikelnamen dieses Ladens,
        und der Vorschlags-Pool umfasst auch NICHT abgehakte Artikel (:96), die Stufe 3 nie
        automatisch übernimmt. Beispiel: offener Artikel "Butter", Bonzeile "BTR" (lcsSimilarity
        0,67 > Floor 0,45, ReceiptParserService.swift:1160).
      Spec requirement: AC-14 / Invariante 6 — "Für jede Zeile mit nicht-leerem line.name, deren
        matchedItemID/resolvedByAI aus einem der bekannten Zuweisungswege stammen (... oder direkt
        aus ReceiptResolutionService.resolve über mergeAIReresolution), ist immer genau eine
        Auswahlzeile markiert — nie null, nie zwei."
      Conflict: Der Zustand entsteht genau über mergeAIReresolution, also über einen von
        Invariante 6 ausdrücklich eingeschlossenen Zuweisungsweg, und liefert null Markierungen.
        Gleichzeitig beschreibt "Known Limitations" (Absatz "Issue #37/#50, vorbestehende,
        ungeprüfte Randbedingung") wortgleich dasselbe Symptom als bewusst offen gelassen — und
        ihre Bedingung ("suggestion.itemID weicht von line.matchedItemID ab") ist hier formal
        erfüllt, weil matchedItemID für KI-Zeilen immer nil ist. Die Spec sagt an dieser Stelle
        beides: AC-14/Invariante 6 versprechen die Markierung, die Known Limitations nehmen sie
        zurück. Der tiefere Grund im Code ist zudem ein anderer als der dort genannte
        (resolvedByAI, nicht die itemID), und der vorgelegte UI-Nachweis prüft nur den
        Wörterbuch-Zweig (resolvedByAI == false), also gerade nicht diesen Fall.
      Remediation: Entweder (a) isSelected(.listMatch) um den Dedup-Fall erweitern — markiert, wenn
        line.resolvedByAI && line.name == suggestion.name (ci) && line.aiSuggestedName ==
        suggestion.name (ci), denn die Zeile VERTRITT laut Invariante 3 genau diesen KI-Namen —,
        oder (b) Regel 5 so fassen, dass sie auch dann greift, wenn kein Kandidat als AUSGEWÄHLT
        gelten kann (statt nur "kein Kandidat trägt den Namen"), oder (c) die Spec eindeutig machen:
        AC-14/Invariante 6 explizit auf resolvedByAI == false einschränken und den KI-Dedup-Fall
        namentlich in die Known Limitations aufnehmen. Der Wortlaut muss in EINER Richtung
        entschieden werden — derzeit widersprechen sich zwei Spec-Abschnitte.

    Finding:
      ID: F002
      Severity: MEDIUM
      Category: edge_case
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
      Description: Regel 10 prüft name.isEmpty (ReceiptReviewCard.swift:497), Regel 11 prüft
        getrimmt (ReceiptScannerView.swift:104-108). Ein einzelnes Leerzeichen im Feld "Anderer
        Name ..." ist damit kein "leerer Zwischenstand": der Rückfall greift nicht, applyCustomName
        schreibt line.name = " " (:479-483) und löscht matchedItemID/resolvedByAI. Nur Regel 11
        rettet die Datenlage. Nach außen bleibt die Position angehakt: Kopfzeile und Summe
        (ReceiptScannerView.swift:507-509, :224) und canSave (:260) zählen weiter über isIncluded,
        save() überspringt sie still, Haptics.success()/dismiss() laufen trotzdem. Ist es die
        einzige Position, wird nichts gespeichert — ohne jede Rückmeldung.
      Spec requirement: AC-15 — "... line.name wird nie leer geschrieben"; Regel 10: "Wann greift
        der Rückfall: bei JEDEM leeren Zwischenstand, sofort"; AC-16/Regel 11: "Eine Position mit
        leerem Namen wird beim Speichern vollständig übersprungen".
      Conflict: Der Buchstabe von AC-15 hält (" " ist nicht leer), die Absicht nicht: ein für den
        Nutzer optisch leeres Feld führt zu einer angehakten, in Kopfzeile und Summe mitgezählten
        Position, die beim Speichern lautlos verschwindet. Weder Regel 10 noch die Known
        Limitations erwähnen diesen Fall, obwohl die Spec den Rückfall ausdrücklich der Alternative
        "Speichern sperren" vorgezogen hat, um den Nutzer nicht ratlos stehen zu lassen.
      Remediation: Regel 10 und Regel 11 auf dieselbe Bedingung bringen — in
        applyCustomNameOrFallback name.trimmingCharacters(in: .whitespaces).isEmpty prüfen (eine
        Zeile, deckt beide Fälle in EINEM Schritt und macht Regel 11 zur echten
        Tiefenverteidigung statt zum einzigen Wächter). Alternativ Kopfzeile/canSave auf isSavable
        umstellen — größerer Eingriff, berührt AC-10/AC-11.

    Finding:
      ID: F003
      Severity: LOW
      Category: regression
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Description: applySelection setzt im .currentName-Zweig nur line.name (:470-471) und lässt
        matchedItemID/resolvedByAI stehen. Wer zuerst einen Listen-Treffer und danach die
        .currentName-Zeile antippt, behält die Artikel-Identität des Treffers; save() schreibt den
        Preis über matchedItem auf diesen fremden Artikel (ReceiptScannerView.swift:642-645, :709).
      Spec requirement: Implementation Details Abschnitt 5 nennt nur drei Auswahl-Callbacks und legt
        für die .currentName-Zeile aus Regel 5 keine matchedItemID-Semantik fest; AC-5/AC-6/AC-7
        decken sie nicht ab.
      Conflict: Kein Verstoß gegen eine AC von Paket 1 — vorbestehend seit Issue #37. Paket 1
        erzeugt .currentName-Zeilen durch die Neuberechnung aus Regel 9 häufiger, die Exposition
        steigt. Als Befund festgehalten, nicht als Blocker.
      Remediation: Folge-Issue: .currentName entweder matchedItemID = nil/resolvedByAI = false
        setzen (wie ein eigener Name) oder in der Spec festlegen, dass sie den bisherigen Zustand
        bewusst konserviert.

    Finding:
      ID: F004
      Severity: LOW
      Category: edge_case
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Description: Solange customActive gilt, ersetzt optionRow die .custom-Zeile durch das
        Textfeld (:194-195); der .isSelected-Trait und der gefüllte Radiopunkt hängen nur an den
        Nicht-Custom-Zeilen (:202, :220). Eine Zählung "genau ein gefüllter Auswahlkreis" liefert
        während der Eingabe eines eigenen Namens 0.
      Spec requirement: AC-14 — "Karte zeigt genau einen gefüllten Auswahlkreis, nie null und nie
        zwei."
      Conflict: Formal null Markierungen während aktiver Eingabe; inhaltlich ist die Eingabe selbst
        die geltende Auswahl (isSelected(.custom) == true, :378), nur ohne visuelles bzw.
        Bedienhilfen-Korrelat. Verhalten unverändert gegenüber dem Stand vor Paket 1, von keinem
        Test abgedeckt.
      Remediation: Entweder .accessibilityAddTraits(.isSelected) und einen gefüllten Punkt auch an
        der aktiven Custom-Zeile führen, oder AC-14 ausdrücklich auf "custom nicht aktiv" beziehen.

## Confirmations

    Confirmation:
      AC: AC-13
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Evidence: .onChange(of: line.name) mit Guard !options.contains(where: { isSelected($0) })
        (:119-122) führt die eingefrorene Liste genau dann nach, wenn keine Zeile mehr passt;
        Regel 5 (:443-447) macht den neuen Namen dann zur vorausgewählten .currentName-Zeile an
        Position 0. Die zweite Hälfte ("bleibt stehen, wenn eine Zeile weiterhin passt") ist für
        alle vier Optionsarten am Gegenspiel von applySelection (:458-475) und isSelected
        (:366-380) belegt — gleiche Vergleichsgrundlage auf beiden Seiten, keine abweichende
        Normalisierung, customActive wird vor applySelection zurückgesetzt (:394). UI-Nachweis am
        reproduzierten Fall: testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution
        (RED -> GREEN, green Z. 775); Radio-Zustand nach Tap: testTappingListMatchSelectsThatOption
        (grün in Lauf 4).
      Status: CONFIRMED (Einschränkung: der KI-Dedup-Zweig aus F001 liefert den neuen Namen
        sichtbar, aber nicht vorausgewählt)

    Confirmation:
      AC: AC-14 (Teilabdeckung)
      Code reference: RestockUITests/ReceiptReviewUITests.swift
      Evidence: testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution zählt über
        alle vier receiptReview.line.4.option.<k> und verlangt selected == 1 sowie das Label
        "Butter" an option.0; RED (test-red-ui.txt Z. 184) -> GREEN (test-green-output.txt Z. 775,
        zweiter Lauf Z. 2578). "Nie zwei" ist zusätzlich analytisch belegt (Runde 1, Angriff 2).
      Status: CONFIRMED NUR für Zeilen mit resolvedByAI == false; für den KI-Dedup-Zweig siehe F001.

    Confirmation:
      AC: AC-15
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Evidence: applyCustomNameOrFallback (:492-507) stellt bei leerem Namen name, matchedItemID UND
        resolvedByAI gemeinsam aus previousSelectionBeforeCustom her; dieser Merkzustand wird in
        select(.custom) VOR dem Vorbelegen des Feldes geschrieben (:384-387) und bei jedem erneuten
        Betreten überschrieben, liefert also immer den neuesten Zustand. customName selbst wird
        nicht zurückgesetzt — das Feld bleibt leer (:270-274). Belege:
        testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName,
        ...RestoresAIStateOnEmptyName (beide RED -> GREEN), ...AppliesNonEmptyNameUnchanged
        (Regressionswächter, in RED schon grün) sowie der UI-Test
        testClearingCustomNameFieldKeepsPreviousItemName (RED -> GREEN), der nach dem Leeren das
        Häkchen-Label UND die Leerheit des Feldes prüft.
      Status: CONFIRMED (Einschränkung: reines Leerzeichen, siehe F002)

    Confirmation:
      AC: AC-16
      Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
      Evidence: EditableReceiptLine.isSavable (:104-108) trägt die bisherigen Bedingungen plus den
        getrimmten Namenstest; save()s Eingangsfilter ruft sie (:615), und jeder schreibende Schritt
        liegt in for line in included: ReceiptAliasService.learn (:623), store.learnedPrices /
        learnedPriceUnits / learnedPriceDates (:691-693) und die einzige PurchaseRecord-Erzeugung in
        SmartCart/Views/Prices/ (:742). Volltextsuche nach parsedLines zeigt keinen zweiten
        Schreibpfad. Tests: testIsSavableRejectsLineWithEmptyName (leer UND "   ", RED -> GREEN),
        testIsSavableKeepsIncludedNamedLineAndRejectsOldCases (Regressionswächter, in RED schon
        grün).
      Status: CONFIRMED

    Confirmation:
      AC: AC-2
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Evidence: selectionOptions ist von fcc8018 nicht angefasst; Kappung auf drei inhaltliche
        Kandidaten (:436) und Anhängen von .custom (:453) unverändert, Regel 5 entfernt beim
        Einfügen den schwächsten Kandidaten (:445). Keine neue Options-Zeile, kein verschobener
        option.<k>-Index. Grün: testCardShowsAtMostFourSelectionOptions und die übrigen
        Index-Tests in Lauf 4 (18/18 ReceiptReviewUITests), Kappungs-Unit-Tests in Lauf 2 und im
        eigenen Prüflauf.
      Status: CONFIRMED

    Confirmation:
      AC: AC-4
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Evidence: Regel 3 (:428-433) sortiert den geltenden Namen nach vorn, Regel 5 (:443-447) fügt
        ihn sonst als vorausgewählte .currentName-Zeile ein, und der Zweig "leerer line.name" bleibt
        durch !line.name.isEmpty (:443) unverändert — testEmptyCurrentNameDoesNotAddExtraOption...
        und testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches sind in Lauf 2/4 und im
        eigenen Prüflauf grün.
      Status: CONFIRMED

    Confirmation:
      AC: AC-5 / AC-6 / AC-7
      Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift
      Evidence: applySelection (:458-475) und applyCustomName (:479-483) sind durch fcc8018
        unverändert; applyCustomNameOrFallback delegiert für jeden nicht-leeren Namen an
        applyCustomName (:506). originalName wird in keinem Zweig geschrieben. Tests:
        testChoosingListMatchSetsNameAndItemAndClearsAiFlag,
        testChoosingAiSuggestionRestoresAiStateAfterAnotherSelection,
        testEnteringCustomNameClearsMatchAndAiFlag, testOriginalNameSurvivesAllThreeSelectionPaths
        — alle grün in Lauf 2 und im eigenen Prüflauf.
      Status: CONFIRMED

    Confirmation:
      AC: AC-12
      Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
      Evidence: Der Diff von fcc8018 an dieser Datei umfasst genau zwei Stellen: die
        Namensbedingung in isSavable (:104-108) und den Eingangsfilter (:615). looseMatch
        (:656-661), die Schwellenprüfung in match (:665-670), learningQuantity/learningUnit und der
        Rückschreibpfad auf itemToUpdate sind unverändert. Lauf 4: 269 Unit-Tests und 18
        ReceiptReviewUITests grün, darunter die AC-12-Strecke "Speichern -> Preis am Artikel
        sichtbar".
      Status: CONFIRMED

---

## Urteil je Checklistenpunkt

| Punkt | Urteil | Begründung |
|---|---|---|
| AC-13 | PROVEN (Einschränkung F001) | Guard + Regel 5 belegt, Nachführen einmalig, Einfrieren nach Tap für alle vier Optionsarten bewiesen; UI-Test RED -> GREEN |
| AC-14 | AMBIGUOUS | "nie zwei" bewiesen; "nie null" scheitert im KI-Dedup-Zweig (F001), den Invariante 6 einschließt und die Known Limitations gleichzeitig freigeben |
| AC-15 | PROVEN (mit F002) | Rückfall über alle drei Felder, Merkzustand stets aktuell, Feld bleibt leer; Lücke nur beim reinen Leerzeichen |
| AC-16 | PROVEN | isSavable an der einzigen schreibenden Stelle, getrimmt, Volltextsuche ohne zweiten Pfad |
| AC-2 | PROVEN | selectionOptions unberührt, keine neue Zeile, kein Indexversatz |
| AC-4 | PROVEN | Regeln 3/5/6 unverändert, Leer-Zweig unberührt |
| AC-5/6/7 | PROVEN | Zuweisungen unverändert, originalName nie geschrieben |
| AC-12 | PROVEN | genau eine Zeile in save() geändert, 269 + 18 Tests grün |

---

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════

Ambiguous findings (require human review):
  F001: Nach reResolveAIIfNeeded() mit Stufe-5-Auflösung kann eine Karte OHNE markierte Zeile
        stehen, wenn der KI-Name wörtlich einem eigenen Vorschlag entspricht (Dedup entfernt die
        KI-Zeile, isSelected(.listMatch) verlangt !resolvedByAI). Invariante 6 schließt genau
        diesen Zuweisungsweg (mergeAIReresolution) ein und verspricht die Markierung; die Known
        Limitations erklären dasselbe Symptom als vorbestehend und bewusst offen. Zwei
        Spec-Abschnitte widersprechen sich — nicht vom Adversary entscheidbar, ob Spec-Verstoß oder
        gewollt offener Randfall. Der vorgelegte UI-Nachweis deckt nur den Wörterbuch-Zweig
        (resolvedByAI == false) ab.

Weitere Findings:
  F002 (MEDIUM): Regel 10 guardet isEmpty, Regel 11 getrimmt — ein reines Leerzeichen führt zu
        einer angehakten, in Kopfzeile und Summe mitgezählten Position, die save() still verwirft.
        Nicht in Regel 10 und nicht in den Known Limitations beschrieben.
  F003 (LOW, vorbestehend): .currentName-Auswahl behält eine fremde matchedItemID.
  F004 (LOW, vorbestehend): während der Eingabe eines eigenen Namens trägt keine Zeile den
        .isSelected-Trait.

Proven points: 7/8 (AC-14 ambiguous)
Tests: eigener Lauf 29 passed, 0 failed, ** TEST SUCCEEDED **; vorgelegte Läufe 29/0, 2/0, 269/0 und
       18/0 — RED und GREEN betreffen nachweislich dieselben Testfunktionen, keine
       "Executed 0 tests"-Stelle, kein Retry, kein Suite-Neustart, kein Abbruch.
Regressions: keine gefunden (AC-2, AC-4 bis AC-7, AC-12 alle bestätigt)
Recommendation: F001 vor dem Weitergehen entscheiden (Spec-Wortlaut ODER Code), F002 mit einer Zeile
       schließen (getrimmter Guard in Regel 10). F003/F004 als Folge-Issues.

## Geprüfte Dateien

- sha256:2c147882baa47e01ca38ea6745c7bf90feea2d494a95a9b4d522c9f9fe3c1cd5  RestockUITests/ReceiptReviewUITests.swift
- sha256:69164434075e8d67d5937c046192ed402a973969edd6a104df15e964394882f6  SmartCart/Services/ReceiptResolutionService.swift
- sha256:871830d318d2bb31dbaf6a6207e8471b7ae133554011bbfeb83ae7ab5cc453c8  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:46ad8942466f785ebb8538835e2d1e73a7f4fa993e21c82ef4eab794151af91e  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:eaf266cfced414f0a5c0720d35b22cb249f66ffa66268b9790422e2d0139d03f  docs/artifacts/fix-50-import-dialog-design/test-green-output.txt
- sha256:3527d2063891d8440186f6d3d36e4a4687b7699bb92435735385aab1e9387267  docs/artifacts/fix-50-import-dialog-design/test-red-ui-ac15.txt
- sha256:f73c31c2c664e9c057c111348d4a44bb2f47289f98ed583e44c786d6d5fa0627  docs/artifacts/fix-50-import-dialog-design/test-red-ui.txt
- sha256:ab47fdbee0a161b67b028fbbd0d23554e9ce7e2b62727c4b2df9f3f437e2b6a1  docs/artifacts/fix-50-import-dialog-design/test-red-unit.txt

## Geprüfte Dateien

- sha256:2c147882baa47e01ca38ea6745c7bf90feea2d494a95a9b4d522c9f9fe3c1cd5  RestockUITests/ReceiptReviewUITests.swift
- sha256:69164434075e8d67d5937c046192ed402a973969edd6a104df15e964394882f6  SmartCart/Services/ReceiptResolutionService.swift
- sha256:871830d318d2bb31dbaf6a6207e8471b7ae133554011bbfeb83ae7ab5cc453c8  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:46ad8942466f785ebb8538835e2d1e73a7f4fa993e21c82ef4eab794151af91e  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:eaf266cfced414f0a5c0720d35b22cb249f66ffa66268b9790422e2d0139d03f  docs/artifacts/fix-50-import-dialog-design/test-green-output.txt
- sha256:3527d2063891d8440186f6d3d36e4a4687b7699bb92435735385aab1e9387267  docs/artifacts/fix-50-import-dialog-design/test-red-ui-ac15.txt
- sha256:f73c31c2c664e9c057c111348d4a44bb2f47289f98ed583e44c786d6d5fa0627  docs/artifacts/fix-50-import-dialog-design/test-red-ui.txt
- sha256:ab47fdbee0a161b67b028fbbd0d23554e9ce7e2b62727c4b2df9f3f437e2b6a1  docs/artifacts/fix-50-import-dialog-design/test-red-unit.txt

## Weitere geprüfte Quellen (in die Hash-Prüfung einbezogen)

Code reference: SmartCart/Services/ReceiptParserService.swift
  (lcsSimilarity :1110-1130, completedItemSuggestionFloor 0,45 :1160,
  completedItemAutoApplyThreshold 0,6 :1155, Namens-Dedup der Kandidaten :1186-1192)
Code reference: RestockTests/ReceiptReviewCardTests.swift
  (die drei neuen Regel-10-Tests :412-459 und die bestehenden Vorauswahl-/Kappungs-Tests)
Code reference: RestockTests/ReceiptScannerReResolutionTests.swift
  (die zwei neuen isSavable-Tests :52-80)
Code reference: docs/specs/views/receipt-review-card.md
  (Maßstab dieser Prüfung: Regeln 9-11, Invarianten 1 und 6, Known Limitations, AC-2 bis AC-16)

## Geprüfte Dateien

- sha256:eb1ae75632e2abec5c19a4b5469642ac6f90111fc5b342a150395ec5bbc39e9d  RestockTests/ReceiptReviewCardTests.swift
- sha256:d0ea5e968ae9754800cc383095fe46cd01e314c5678005dc3cfa9c9d880e1045  RestockTests/ReceiptScannerReResolutionTests.swift
- sha256:2c147882baa47e01ca38ea6745c7bf90feea2d494a95a9b4d522c9f9fe3c1cd5  RestockUITests/ReceiptReviewUITests.swift
- sha256:b709d56b302b570736637c3f46ce705b7be02483caa5d5aae6094ee8da10a796  SmartCart/Services/ReceiptParserService.swift
- sha256:69164434075e8d67d5937c046192ed402a973969edd6a104df15e964394882f6  SmartCart/Services/ReceiptResolutionService.swift
- sha256:871830d318d2bb31dbaf6a6207e8471b7ae133554011bbfeb83ae7ab5cc453c8  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:46ad8942466f785ebb8538835e2d1e73a7f4fa993e21c82ef4eab794151af91e  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:eaf266cfced414f0a5c0720d35b22cb249f66ffa66268b9790422e2d0139d03f  docs/artifacts/fix-50-import-dialog-design/test-green-output.txt
- sha256:3527d2063891d8440186f6d3d36e4a4687b7699bb92435735385aab1e9387267  docs/artifacts/fix-50-import-dialog-design/test-red-ui-ac15.txt
- sha256:f73c31c2c664e9c057c111348d4a44bb2f47289f98ed583e44c786d6d5fa0627  docs/artifacts/fix-50-import-dialog-design/test-red-ui.txt
- sha256:ab47fdbee0a161b67b028fbbd0d23554e9ce7e2b62727c4b2df9f3f437e2b6a1  docs/artifacts/fix-50-import-dialog-design/test-red-unit.txt
- sha256:234667dab0bd1b17035676ec5f86a6d65f4257dbd152d6d7cd21014251654245  docs/specs/views/receipt-review-card.md

## Geprüfte Dateien

- sha256:eb1ae75632e2abec5c19a4b5469642ac6f90111fc5b342a150395ec5bbc39e9d  RestockTests/ReceiptReviewCardTests.swift
- sha256:d0ea5e968ae9754800cc383095fe46cd01e314c5678005dc3cfa9c9d880e1045  RestockTests/ReceiptScannerReResolutionTests.swift
- sha256:2c147882baa47e01ca38ea6745c7bf90feea2d494a95a9b4d522c9f9fe3c1cd5  RestockUITests/ReceiptReviewUITests.swift
- sha256:b709d56b302b570736637c3f46ce705b7be02483caa5d5aae6094ee8da10a796  SmartCart/Services/ReceiptParserService.swift
- sha256:69164434075e8d67d5937c046192ed402a973969edd6a104df15e964394882f6  SmartCart/Services/ReceiptResolutionService.swift
- sha256:871830d318d2bb31dbaf6a6207e8471b7ae133554011bbfeb83ae7ab5cc453c8  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:46ad8942466f785ebb8538835e2d1e73a7f4fa993e21c82ef4eab794151af91e  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:eaf266cfced414f0a5c0720d35b22cb249f66ffa66268b9790422e2d0139d03f  docs/artifacts/fix-50-import-dialog-design/test-green-output.txt
- sha256:3527d2063891d8440186f6d3d36e4a4687b7699bb92435735385aab1e9387267  docs/artifacts/fix-50-import-dialog-design/test-red-ui-ac15.txt
- sha256:f73c31c2c664e9c057c111348d4a44bb2f47289f98ed583e44c786d6d5fa0627  docs/artifacts/fix-50-import-dialog-design/test-red-ui.txt
- sha256:ab47fdbee0a161b67b028fbbd0d23554e9ce7e2b62727c4b2df9f3f437e2b6a1  docs/artifacts/fix-50-import-dialog-design/test-red-unit.txt
- sha256:234667dab0bd1b17035676ec5f86a6d65f4257dbd152d6d7cd21014251654245  docs/specs/views/receipt-review-card.md
