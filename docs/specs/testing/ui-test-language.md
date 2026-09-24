---
entity_id: ui-test-language
type: bugfix
created: 2026-09-21
updated: 2026-09-21
status: draft
version: "1.0"
tags: [ci, ui-tests, testing, xcodebuild]
test_targets: [RestockUITests]
---

# UI-Test-Sprache im Scheme festlegen

## Approval

- [ ] Approved

## GitHub Issue

- **Issue:** #3 — „CI: UI-Tests schlagen fehl, weil der GitHub-Simulator auf Englisch läuft"

## Purpose

Der CI-Job `ui-test` ist rot, weil die UI-Tests Bedienelemente über deutsche Beschriftungen suchen, der GitHub-Runner den Simulator aber englisch startet. Diese Änderung legt die Testsprache zentral im Xcode-Scheme fest (`language = "de"`, `region = "DE"`), sodass CI, das Teilen-Erweiterungs-Skript und lokale Läufe aus Xcode dieselbe, deterministische Sprache verwenden, und behebt zwei zusätzlich aufgedeckte, sprachunabhängige Testdefekte.

## Source

- **File:** `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme`
- **Identifier:** `<TestAction>`-Element, Attribute `language` und `region`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `xcodebuild` TestAction (Scheme) | system API | Laut `man xcodebuild` der vorgesehene Ort für die Standard-Testsprache; `-testLanguage`/`-testRegion` auf der Kommandozeile übersteuern diesen Wert ausdrücklich. |
| `.github/workflows/ci.yml`, Job `ui-test` | caller | Ruft `xcodebuild test` ohne eigene Sprachangabe auf und erbt künftig den neuen Scheme-Standard. Bleibt unverändert. |
| `scripts/run-share-extension-uitest.sh` | caller | Ruft `xcodebuild` mit `-scheme Restock` auf und erbt ebenfalls den neuen Standard. Bleibt unverändert. |
| `RestockUITests/RestockUITests.swift` | test | Enthält die vier betroffenen bzw. korrigierten Tests; wird in diesem Zug modifiziert. |
| `RestockUITests/ReceiptShareExtensionTests.swift` | test | Läuft im selben CI-Job mit, steuert die Fotos-App über technische Identifier statt Beschriftungen und ist daher von der Sprachumstellung nicht betroffen. Bleibt unverändert. |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | resource | Beide Sprachen sind vollständig gepflegt; die Tests greifen nach dieser Änderung verlässlich die deutsche Übersetzung ab. Bleiben unverändert. |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme` | MODIFY | `language = "de"` und `region = "DE"` am `<TestAction>`-Element ergänzen. |
| `RestockUITests/RestockUITests.swift` | MODIFY | (a) Vor `typeText` auf den Tastaturfokus warten statt sofort zu tippen; (b) Teilen-Knopf über `identifier == "person.2"` statt über die Beschriftung suchen; (c) Kopfkommentar ergänzen, dass die deutschen Beschriftungen an die Testsprache im Scheme gekoppelt sind; (d) StoreSetupView-Sheet nicht mehr per `app.swipeDown()` schließen, sondern auf den „Bearbeiten"-Button warten und das Sheet per `press(forDuration:thenDragTo:)` von seiner Titelzeile bis zum unteren Rand ziehen, dazu vor `lidlTile.tap()` eine `isHittable == true`-Expectation (5 s) — siehe Implementation Details 3d. |

**Ausdrücklich NICHT geändert:** `.github/workflows/ci.yml` und `scripts/run-share-extension-uitest.sh` — beide erben die Scheme-Einstellung; sie zusätzlich zu ändern schüfe zwei Wahrheiten. Kein Produktcode der App wird angefasst.

### Estimated Changes
- Files: 3 (Scheme, `RestockUITests.swift`, diese Spec)
- LoC: +35/-5 tatsächlich — Scheme +3/-1, `RestockUITests.swift` +30/-2, Spec +2/-2 (Timeout 3 s → 10 s). Ursprüngliche Schätzung +18/-4 über 2 Dateien; Differenz stammt aus Punkt (d), der erst im GREEN-Lauf sichtbar wurde.
- Risiko: NIEDRIG — kein Produktcode, keine Abhängigkeit, keine Datenmigration. Das Scheme betrifft ausschließlich die Testaktion (Cmd+U), nicht Start/Debug/Archive.

## Implementation Details

```xml
<!-- Restock.xcscheme, <TestAction> -->
<TestAction
   ...
   language = "de"
   region = "DE">
```

```swift
// RestockUITests.swift — 3a: auf Tastaturfokus warten statt blind zu tippen
quickAddField.tap()
let hasFocus = NSPredicate(format: "hasKeyboardFocus == true")
expectation(for: hasFocus, evaluatedWith: quickAddField)
waitForExpectations(timeout: 10)
quickAddField.typeText("...")

// 3b: Teilen-Knopf über die sprachunabhängige Kennung statt über die Beschriftung
let shareButton = app.buttons.matching(
    NSPredicate(format: "identifier == 'person.2'")
).firstMatch

// 3d: StoreSetupView-Sheet deterministisch schließen statt blind zu wischen
let editButton = app.buttons["Bearbeiten"]
XCTAssertTrue(editButton.waitForExistence(timeout: 5), "...")
app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
    .press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
// ... und vor dem Tipp auf die Kachel sicherstellen, dass nichts mehr darüber liegt
expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: lidlTile)
waitForExpectations(timeout: 5)
lidlTile.tap()
```

**Zu 3d — Ergänzung nach dem GREEN-Lauf (nicht Teil der ursprünglichen Spec):** `app.swipeDown()` wischt in der
Bildschirmmitte und traf dort die `List` im StoreSetupView-Sheet — die Liste scrollte, das Sheet blieb offen. Alle
Elemente des Home-Screens dahinter (Lidl-Kachel, Schnelleingabe-Feld, später der Teilen-Knopf) standen zwar in der
Accessibility-Hierarchie, waren aber nicht antippbar: XCUITest meldete `Computed hit point {-1, -1} after scrolling to
visible`, der Tipp ging ins Leere, und die anschließende Fokus-Expectation lief in den Timeout. Beleg: Bildschirmaufnahme
im xcresult des Laufs vom 21.09.2026 14:34 (letztes Bild zeigt das offene Sheet „Läden" mit Lidl) sowie Frame-Vergleich —
das gefundene Textfeld hatte den HomeView-Frame `{{60.3, 299.0}, {245.7, 22.0}}`, identisch zum Start-Hierarchie-Dump,
nicht den Frame des Feldes in StoreDetailView. Dieser Defekt war im RED-Lauf unsichtbar, weil der Test dort schon am
ersten Schritt (`„Läden einrichten"` auf englischem Gerät nicht gefunden) abbrach und nie bis zum Sheet kam. Die
Änderung betrifft ausschließlich den Testablauf, kein Produktverhalten.

## Expected Behavior

- **Input:** `xcodebuild test -scheme Restock -destination 'platform=iOS Simulator,...' -only-testing:RestockUITests` — der bestehende CI-Aufruf, unverändert, ohne `-testLanguage`/`-testRegion`.
- **Output:** Der Simulator startet auf Deutsch. Tests, die deutsche Beschriftungen suchen, finden sie. Ergebnis wechselt von `Executed 5 tests, with 1 test skipped and 3 failures` auf `Executed 5 tests, with 1 test skipped and 0 failures`.
- **Side effects:** Lokale Läufe aus Xcode (Cmd+U) und `scripts/run-share-extension-uitest.sh` laufen ab sofort ebenfalls standardmäßig auf Deutsch, sofern niemand `-testLanguage`/`-testRegion` explizit übersteuert. Kein Einfluss auf Start-, Debug- oder Archive-Aktionen des Schemes, kein Einfluss auf die ausgelieferte App.

## Error Handling

- Übersteuert jemand weiterhin explizit mit `-testLanguage en -testRegion US`, gilt laut `man xcodebuild` diese Kommandozeilenangabe statt der Scheme-Einstellung — die drei ursprünglichen Fehlschläge treten dann bewusst wieder auf. Das ist die in diesem Ticket geforderte Negativkontrolle, kein Fehlerfall.
- Bekommt `quickAddField` innerhalb von 10 Sekunden weiterhin keinen Tastaturfokus, schlägt der Test mit einer klaren Timeout-Meldung der Expectation fehl statt mit der bisherigen sofortigen, kryptischen Meldung `Neither element nor any descendant has keyboard focus`.
- Existiert kein Element mit `identifier == "person.2"`, schlägt der zugehörige Zugriff mit einer klaren „no matches found"-Meldung fehl; es gibt keinen stillen Rückfall auf die alte, sprachabhängige Suche über `label`.

## Known Limitations

- Die Tests hängen weiterhin an Anzeigetexten — jede künftige Textänderung kann sie erneut brechen. Die Umstellung auf `accessibilityIdentifier` würde das dauerhaft beheben, sprengt aber mit 5+ betroffenen Ansichten (`HomeView`, `BrowseStoresView`, `JoinStoreSheet`, `StoreSetupView`, `StoreDetailView`) die 4–5-Dateien-Grenze dieses Tickets; im gesamten `SmartCart/`-Baum existiert derzeit keine einzige gesetzte `accessibilityIdentifier`. Gehört als eigenes Vorhaben angelegt.
- Die Tests sind nicht voneinander isoliert — kein Zustands-Reset zwischen Läufen. Der zuvor gemeldete Fehlschlag „Lidl-Kachel nicht antippbar" entsteht nur auf einem Simulator mit über mehrere Läufe angesammelten Läden; auf dem frischen CI-Simulator tritt er nicht auf und wird in diesem Ticket nicht behoben.
- Ob `-testLanguage`/die Scheme-Sprache auch die Teilen-Erweiterung im eigenen Prozess erfasst, ist unbewiesen. `RestockUITests/ReceiptShareExtensionTests.swift` nutzt ausschließlich technische Identifier und ist von dieser Frage daher nicht betroffen.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten (AC-1 bis AC-5) ist durch einen automatischen Lauf belegt
- [ ] Der CI-Job `ui-test`, unverändert aufgerufen, meldet `1 test skipped and 0 failures` statt bisher `1 test skipped and 3 failures`
- [ ] Die lokale Gegenprobe auf frisch geleertem Simulator, ohne `-testLanguage`/`-testRegion` (nutzt den neuen Scheme-Standard), zeigt 0 Fehlschläge
- [ ] Die Negativkontrolle mit `-testLanguage en -testRegion US` zeigt weiterhin dieselben drei ursprünglichen Meldungen — Beleg, dass die Scheme-Einstellung tatsächlich greift
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün)

## Acceptance Criteria

- **AC-1:** Given der CI-Job `ui-test` mit unverändertem Aufruf / When der Job nach dieser Änderung läuft / Then meldet er `Executed 5 tests, with 1 test skipped and 0 failures` statt bisher `... and 3 failures`.
  - Test: *(populated after TDD RED phase)*

- **AC-2:** Given ein frisch geleerter lokaler Simulator und ein `xcodebuild test`-Aufruf ohne `-testLanguage`/`-testRegion` / When der Aufruf nach dieser Änderung läuft / Then treten 0 Fehlschläge auf.
  - Test: *(populated after TDD RED phase)*

- **AC-3:** Given derselbe frisch geleerte Simulator / When derselbe Testlauf zusätzlich mit `-testLanguage en -testRegion US` ausgeführt wird / Then zeigt er weiterhin exakt die drei ursprünglichen Meldungen aus `testJoinSharedListSheetIsScrollableAndUsable`, `testJoinWithLegacySixCharacterCodeTriggersLookup` und dem ersten Schritt von `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` — als Beleg, dass die Scheme-Einstellung greift und nicht ein Zufallseffekt vorliegt.
  - Test: *(populated after TDD RED phase)*

- **AC-4:** Given der Test `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` auf Deutsch / When `quickAddField.tap()` gefolgt vom Warten auf Tastaturfokus statt sofortigem `typeText` ausgeführt wird / Then gelingt die Texteingabe zuverlässig und der Artikel erscheint in der Liste, ohne die Meldung `Neither element nor any descendant has keyboard focus`.
  - Test: *(populated after TDD RED phase)*

- **AC-5:** Given derselbe Test auf Deutsch / When der Teilen-Knopf über `identifier == "person.2"` statt über die Beschriftung gesucht wird / Then wird das Element gefunden und der Test läuft über diesen Schritt hinaus weiter.
  - Test: *(populated after TDD RED phase)*

## Test Plan

### Automated Tests (TDD RED)
- [ ] Test 1 (AC-1, CI): GitHub-Actions-Job `ui-test` auf dem Feature-Branch — unveränderter Aufruf, erwartet `1 test skipped and 0 failures`.
- [ ] Test 2 (AC-2, lokale Gegenprobe): `xcodebuild test -scheme Restock -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RestockUITests` auf frisch per `simctl erase` geleertem Simulator, ohne `-testLanguage`/`-testRegion` — erwartet 0 Fehlschläge.
- [ ] Test 3 (AC-3, Negativkontrolle): derselbe Aufruf zusätzlich mit `-testLanguage en -testRegion US` — erwartet dieselben drei ursprünglichen Meldungen wie vor dem Fix.
- [ ] Test 4 (AC-4): `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` einzeln über `-only-testing:RestockUITests/RestockUITests/testAddStoreAndQuickAddItemShowsPriceWithoutCrash` auf Deutsch — erwartet erfolgreiche Texteingabe ohne Fokus-Fehler.
- [ ] Test 5 (AC-5): derselbe Test, Prüfung, dass der Teilen-Knopf-Schritt nicht mehr mit „no matches found" für `label CONTAINS 'person.2'` scheitert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Für CI/Teststrategie existiert im Projekt weder ein ADR-Verzeichnis noch eine bestehende Spec. Die Sprachfestlegung im Scheme kippt keine frühere Entscheidung, sie füllt eine bisher offene Lücke (fehlende `language`/`region`-Attribute am `TestAction`). Geprüfte Alternative B (Sprachschalter nur im CI-Aufruf) wurde verworfen, weil sie zwei Wahrheiten erzeugt hätte — CI deutsch, lokale Läufe und das Teilen-Skript je nach Simulator-Zufallssprache. Geprüfte Alternative C (Umstellung der Tests auf `accessibilityIdentifier`) beseitigt die Ursache dauerhaft und wäre nach diesem Fix ersatzlos entfernbar, sprengt aber mit 5+ betroffenen Ansichten den Umfang dieses Tickets und wird als eigenes Vorhaben angelegt.

## Changelog

- 2026-09-21: Initial spec created
