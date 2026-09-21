# Context: fix-3-ui-test-sprache (Issue #3)

## Request Summary
Der CI-Job `ui-test` ist auf `main` seit dem 11.08.2026 durchgehend rot. Drei von vier
UI-Tests scheitern, weil sie Bedienelemente über deutsche Beschriftungen suchen, der
GitHub-Runner den Simulator aber auf Englisch startet. Ziel: `ui-test` wieder grün —
inklusive des vierten, bisher ungeklärten Fehlschlags („Lidl-Kachel nicht antippbar").

## Related Files

| Datei | Relevanz |
|-------|----------|
| `.github/workflows/ci.yml` (Job `ui-test`, Schritt „Build and run UI tests", Z. 146–160) | Ruft `xcodebuild test` ohne Sprach-/Regionsangabe auf. Primärer Fixort (Variante B). |
| `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme` (`<TestAction>`, Z. 70–83) | Enthält **keine** `language`/`region`-Attribute. Primärer Fixort (Variante A) — wirkt zusätzlich in Xcode lokal. |
| `RestockUITests/RestockUITests.swift` (194 Z.) | Die vier betroffenen Tests. Sucht über deutsche Labels: `Läden einrichten` (Z. 130), `Geteilter Liste beitreten` (Z. 45, 97), `Abbrechen` (Z. 62), `Fertig` (Z. 147), `Fortfahren` (Z. 162), `Code generieren` (Z. 175), `Kein Store mit diesem Code gefunden.`, Platzhalter `Z.B. ABCD-EFG-HIJ`, Suchfeld `Laden suchen (alle Länder)`. |
| `RestockUITests/ReceiptShareExtensionTests.swift` (252 Z.) | Läuft im selben CI-Job (`-only-testing:RestockUITests`). Steuert die Fotos-App über **technische Identifier** (`LibraryTab`, `BackButton`, `PUOneUpBarButtonItemIdentifierShare`) — sprachunabhängig. Überspringt sich seit #4 sauber, wenn das Bon-Bild fehlt. |
| `SmartCart/Resources/de.lproj/Localizable.strings` / `en.lproj/Localizable.strings` | Beide Sprachen vollständig gepflegt (`home.stores.setup`, `home.join.shared` …). `knownRegions = (Base, de, en)`. |
| `SmartCart/Views/Home/HomeView.swift` (~1400 Z.) | Store-Kacheln liegen in einem `LazyVGrid` (Z. 1006) innerhalb eines `ScrollView` (Z. 140). Relevant für den `not hittable`-Fall. |
| `SmartCart/Views/Components/StoreCard.swift` | Die Kachel selbst. Kein `accessibilityIdentifier`, Label wird aus Name + Frequenz + Listenstatus zusammengesetzt. |
| `scripts/run-share-extension-uitest.sh` | Eigener Cross-App-Lauf, setzt ebenfalls keine Sprache. |

## Recherche-Ergebnis (2026-09-21)

`xcodebuild` (lokal Xcode 27.0, Build 27A266a) kennt beide Schalter unverändert — belegt
direkt aus `man xcodebuild` und `xcodebuild -help`:

- `-testLanguage language` — „Specifies ISO 639-1 language during testing. **This overrides
  the setting for the test action of a scheme in a workspace.**"
- `-testRegion region` — „Specifies ISO 3166-1 region during testing. This overrides the
  setting for the test action of a scheme in a workspace."

Entscheidend daraus: Die Kommandozeilen-Schalter sind ausdrücklich als **Übersteuerung**
einer Scheme-Einstellung dokumentiert. Das Scheme ist also der vorgesehene Ort, die
CI-Schalter der Sonderfall. Gegenprobe in der Literatur: dieselbe Semantik, plus die
verbreitete Alternative `app.launchArguments += ["-AppleLanguages", "(de)"]` pro Test.
Quellen: `man xcodebuild(1)`; [keith.github.io/xcode-man-pages/xcodebuild.1.html](https://keith.github.io/xcode-man-pages/xcodebuild.1.html);
[onmyway133/blog#540 „How to set language and locale with xcodebuild"](https://github.com/onmyway133/blog/issues/540);
[SwiftLee — Localization testing in Xcode](https://www.avanderlee.com/xcode/localization-testing-in-xcode/).

Es handelt sich um eine rein deterministische Konfiguration — kein Heuristik- oder
Modellanteil, keine Bibliothek nötig.

## Existing Patterns

- **Lokalisierung vollständig über Keys**: Jeder Anzeigetext läuft über
  `String(localized: "key")`; Deutsch und Englisch sind beide gepflegt. Die Tests umgehen
  dieses Muster, indem sie die *übersetzte Ausgabe* statt der Kennung als Anker nehmen.
- **Sprachunabhängige Anker existieren im Projekt bereits**: `ReceiptShareExtensionTests`
  greift die Fotos-App ausschließlich über technische Identifier — und ist genau deshalb
  von diesem Fehlerbild nicht betroffen. Das belegt das robuste Muster im eigenen Haus.
- **Tests, die ihre Vorbedingung nicht herstellen können, überspringen sich** (`XCTSkip`
  in `ReceiptShareExtensionTests`, seit #4) statt falsch rot zu melden.
- **CI baut das eingecheckte `.xcodeproj` unverändert**, kein `xcodegen` — eine Änderung am
  Scheme wirkt damit direkt, ohne Generierungsschritt.

## Dependencies

- **Upstream**: `xcodebuild` (Sprach-/Regionsschalter), Scheme-`TestAction`, iOS-Simulator
  auf dem GitHub-Runner `macos-26`, Auswahl „neuestes verfügbares Xcode" im Workflow.
- **Downstream**: Alles, was den Job `ui-test` als Schranke nutzt — jede künftige
  Freigabe/Zusammenführung. Ein grüner Job ist Voraussetzung dafür, dass die CI überhaupt
  wieder Aussagekraft hat (aktuell wird Rot ignoriert, weil es Dauerzustand ist).
- **Nicht betroffen**: Produktcode der App. Kein Nutzer sieht eine Änderung.

## Existing Specs

- `docs/specs/models/shared-model-container.md` — nicht betroffen, nur der Vollständigkeit halber.
- Für CI/Teststrategie existiert bislang keine Spec.

## Risks & Considerations

1. **Zweiter, ungeklärter Fehlschlag.** `testAddStoreAndQuickAddItemShowsPriceWithoutCrash`
   scheiterte lokal auf Deutsch mit `Failed to not hittable: Button 'Lidl, 2x pro Woche,
   Liste ist leer'`. Ursache unbelegt. Naheliegende Hypothese: Der Simulator behält seinen
   Datenbestand zwischen Läufen, es stehen mehrere Läden im Raster, die Kachel liegt unter
   dem sichtbaren Bereich. Auf einem frischen CI-Simulator mit einem einzigen Laden könnte
   der Fall gar nicht auftreten. **Muss in Phase 2 reproduziert werden, bevor irgendetwas
   geändert wird** — sonst wird ein Fix für ein Phantom gebaut.
2. **Wirkungsbereich der Sprachumstellung ist zu prüfen.** Ob `-testLanguage` auch die
   Teilen-Erweiterung erfasst, die von der Fotos-App in einem eigenen Prozess gestartet
   wird, ist offen. `ReceiptShareExtensionTests` läuft im selben Job mit. Erwartung: nicht
   betroffen (nutzt technische Identifier), aber unbewiesen.
3. **Tests sind nicht voneinander isoliert.** Kein Zurücksetzen des App-Zustands zwischen
   Läufen; `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` hat dafür sogar eine
   Sonderbehandlung eingebaut. Lokale und CI-Ergebnisse können deshalb auseinanderlaufen —
   jede Reproduktion muss den Ausgangszustand mitdokumentieren.
4. **Strukturelles Risiko bleibt bestehen.** Solange die Tests an Anzeigetexten hängen,
   bricht sie jede Textänderung erneut — auch auf Deutsch. Die Sprachumstellung beseitigt
   das Symptom, nicht die Bauweise.
5. **Lokal Xcode 27, CI „neuestes verfügbares Xcode" auf `macos-26`.** Eine Reproduktion
   lokal beweist den CI-Fall nur, wenn die Sprache explizit gesetzt wird (`-testLanguage en
   -testRegion US`) — genau so wurde der Fehler am 20.09. bereits nachgestellt.

## Lösungswege (für Phase 2 zu bewerten, noch keine Entscheidung)

- **A — Sprache im Scheme** (`language="de" region="DE"` im `<TestAction>`): eine Stelle,
  wirkt in CI *und* beim Start aus Xcode. Laut `man xcodebuild` der vorgesehene Ort.
- **B — Schalter nur im CI-Aufruf**: minimal-invasiv, erzeugt aber zwei Wahrheiten (CI
  deutsch, Xcode je nach Rechner) und damit denselben Fehler in umgekehrter Richtung.
- **C — Tests auf technische Kennungen umstellen**: beseitigt die Ursache dauerhaft,
  berührt aber jede betroffene Ansicht. Umfang sprengt diesen Auftrag; als eigenes
  Vorhaben anzulegen.
- **D — Sprache pro Test über `launchArguments`**: verbreitet, aber verteilt die
  Konfiguration über alle Testmethoden und wirkt nicht auf Systemdialoge.

---

## Analysis (Phase 2, 2026-09-21)

### Type

**Bug** — Konfigurations- und Testfehler. Kein Produktcode betroffen, kein Nutzer sieht eine Änderung.

### Reproduktion (Pflicht erfüllt)

Alle Läufe auf einem **eigens angelegten, frischen Simulator** (`iPhone 17`, iOS 27.0, UDID
`F76408DF-…`), vor jedem Lauf per `simctl erase` zurückgesetzt, Kamera-/Foto-Rechte wie in CI
vorab erteilt. Aufruf identisch zum CI-Schritt „Build and run UI tests".

| Lauf | Sprache | Ergebnis |
|------|---------|----------|
| CI 35573883003 (main, 21.09.) | en (Runner-Vorgabe) | `Executed 5 tests, with 1 test skipped and 3 failures` |
| **A — lokal** | `-testLanguage en -testRegion US` | **`Executed 5 tests, with 1 test skipped and 3 failures`** — Wort für Wort dieselben drei Meldungen wie CI |
| **B — lokal** | `-testLanguage de -testRegion DE` | `Executed 5 tests, with 1 test skipped and 1 failure` — die drei Sprach-Fehlschläge sind weg |

Lauf A ist die exakte Nachstellung des CI-Fehlerbildes. Lauf B ist die Gegenprobe.

### Korrektur zur Historie

Die Annahme „seit 11.08. durchgehend rot wegen der Sprache" stimmt so nicht. Die Läufe auf `main`
vom 11.08., 13.08., 14.08., 19.08. und 26.08. sind nach 2–3 Sekunden abgebrochen, ohne dass ein
Test lief — GitHub meldet dort „job was not started because recent account payments have failed".
Der **erste tatsächlich ausgeführte** rote `ui-test`-Lauf ist der vom **14.09.2026** (34900726696),
mit exakt demselben Sprach-Fehlerbild. Seitdem sind es fünf rote Läufe. Für die Analyse ändert das
nichts, für die Aussage „wie lange läuft die CI schon blind" schon.

### Root Causes — drei unabhängige Befunde

### 1. Sprachbindung der Tests (die gemeldete Ursache) — BELEGT

Die Tests suchen Bedienelemente über deutsche Beschriftungen (`app.buttons["Läden einrichten"]`),
der Runner startet den Simulator englisch (`"home.stores.setup" = "Set up stores"`). Weder
`.github/workflows/ci.yml` noch das Scheme setzen eine Testsprache. `man xcodebuild`:
`-testLanguage` „overrides the setting for the test action of a scheme" — das Scheme ist der
vorgesehene Ort. Im `<TestAction>` (Z. 68–73) fehlen `language`/`region` vollständig.

Betrifft: `testJoinSharedListSheetIsScrollableAndUsable`,
`testJoinWithLegacySixCharacterCodeTriggersLookup`,
`testAddStoreAndQuickAddItemShowsPriceWithoutCrash` (dort nur der erste Schritt).

### 2. „Lidl-Kachel nicht antippbar" — WIDERLEGT als CI-Problem

Trat in Lauf B **nicht** auf: Der Tipp auf die Kachel gelang, der Test lief weiter. Der Fehler
entsteht nur auf einem Simulator mit über mehrere Läufe angesammelten Läden — der Test dokumentiert
diese fehlende Isolation selbst (`RestockUITests.swift:124-126`). CI legt pro Lauf eine frische VM
an, der Fall kann dort nicht entstehen. **Kein Fix in diesem Ticket nötig**; die fehlende
Test-Isolation bleibt als eigenes Thema bestehen.

### 3. `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` ist auch auf Deutsch rot — NEU, BELEGT

Erst Lauf B macht diesen Test überhaupt so weit lauffähig, dass die dahinterliegenden Defekte
sichtbar werden. Zwei davon sind bewiesen:

**3a — Schnelleingabefeld bekommt den Fokus zu spät.**
`quickAddField.tap()` (Z. 160) gefolgt von sofortigem `typeText` (Z. 161) scheitert mit
`Neither element nor any descendant has keyboard focus`. Messreihe auf frischem Simulator:
mit 1 s Wartezeit nach dem Tipp weiterhin Fehler; mit 2 s Wartezeit `keyboards.count=1` und
`hasKeyboardFocus=1`, Eingabe gelingt, Artikel erscheint in der Liste. Ursache ist kein
Tastaturproblem des Simulators — die beiden Beitreten-Tests tippen erfolgreich, sie haben ein
`sleep(1)` an der entsprechenden Stelle. Der Unterschied: Das Feld sitzt in einer `List`-Section,
die beim Fokuswechsel neu umbricht (`isQuickAddFocused` blendet `ProductSuggestionChips` ein,
`StoreDetailView.swift:126-128`).

**3b — Teilen-Knopf wird über die falsche Eigenschaft gesucht.**
Der Test sucht `label CONTAINS 'person.2'` (Z. 171). Der Hierarchie-Abzug zeigt das Element als:
`Button, identifier: 'person.2', label: 'Zwei Personen'`. Das Symbolnamen-Matching auf `label`
greift also **in keiner Sprache** — englisch hieße das Element „Two People". Richtig wäre die
Kennung (`identifier`), die sprachunabhängig `person.2` ist. Dieser Defekt ist von der
Sprachumstellung unabhängig und bestand vorher unentdeckt, weil der Test nie so weit kam.

Ein drittes, nicht fatales Verhalten: `app.keyboards.buttons["Fortfahren"].tap()` (Z. 162) meldet
einmal `Failed to scroll to visible`, der automatische zweite Versuch gelingt. Kein Handlungsbedarf.

### Affected Files (with changes)

| Datei | Change Type | Beschreibung |
|-------|-------------|--------------|
| `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme` | MODIFY | `language = "de"` / `region = "DE"` am `<TestAction>` (Z. 68). Wirkt auf CI, auf `scripts/run-share-extension-uitest.sh` (ruft `-scheme Restock`) und auf Läufe aus Xcode — eine Stelle statt drei. |
| `RestockUITests/RestockUITests.swift` | MODIFY | (a) Vor `typeText` auf den Tastaturfokus warten statt blind zu tippen; (b) Teilen-Knopf über `identifier == "person.2"` statt über die Beschriftung suchen; (c) Kopfkommentar: die deutschen Beschriftungen sind an die Testsprache im Scheme gekoppelt. |

Nicht angefasst: `.github/workflows/ci.yml` und `scripts/run-share-extension-uitest.sh` erben die
Scheme-Einstellung. Sie zusätzlich zu ändern schüfe zwei Wahrheiten.

### Scope Assessment

- Dateien: **2**
- Geschätzte LoC: **+18 / −4**
- Risiko: **NIEDRIG** — kein Produktcode, keine Abhängigkeit, keine Datenmigration. Das Scheme
  betrifft ausschließlich die Testaktion (Cmd+U), nicht Start/Debug/Archive.

### Technical Approach

Sprache im Scheme festlegen (Variante A), und die zwei bewiesenen Testdefekte im selben Zug
beheben. Begründung für A statt B (Schalter nur im CI-Aufruf): B ließe Hennings lokale Läufe und
das Teilen-Skript weiter von der Zufallssprache des jeweiligen Simulators abhängen — genau die
Abhängigkeit, die den Fehler erzeugt hat. A kostet zwei Attribute und beseitigt sie überall.

**Echte Alternative:** Tests auf Accessibility-Kennungen umstellen (Variante C) statt die Sprache
festzuschreiben. Das beseitigt die Ursache dauerhaft und würde nebenbei 3b erschlagen. Dagegen
spricht der Umfang: Im gesamten `SmartCart/`-Baum existiert derzeit keine einzige gesetzte
`accessibilityIdentifier`; betroffen wären `HomeView`, `BrowseStoresView`, `JoinStoreSheet`,
`StoreSetupView`, `StoreDetailView` plus Testdatei — deutlich über der 4–5-Dateien-Grenze. Gehört
als eigenes Vorhaben angelegt, nicht in dieses Ticket. Die Sprachfestlegung im Scheme steht dem
nicht im Weg und wäre danach ersatzlos entfernbar.

**Kippt eine frühere Entscheidung?** Nein. Für CI/Teststrategie existiert keine ADR oder Spec.

### Dependencies

- Upstream: `xcodebuild`-Scheme-`TestAction`, GitHub-Runner `macos-26`, „neuestes verfügbares Xcode".
- Downstream: Jeder künftige CI-Lauf. `ui-test` wird erst dadurch wieder zur echten Schranke.

### Definition of Done / Beweis

Derselbe Ablauf, der heute rot ist, muss danach grün sein:

1. CI-Job `ui-test` (unverändert aufgerufen): von `1 test skipped and 3 failures` auf
   `1 test skipped and 0 failures`.
2. Lokale Gegenprobe auf frisch geleertem Simulator, Aufruf **ohne** `-testLanguage`/`-testRegion`
   (nutzt also den neuen Scheme-Standard): 0 Fehlschläge.
3. Negativkontrolle: derselbe Lauf **mit** `-testLanguage en -testRegion US` muss weiterhin die
   drei ursprünglichen Meldungen zeigen — belegt, dass wirklich die Scheme-Einstellung greift und
   nicht ein Zufallseffekt.

### Open Questions

Keine. Die Scope-Entscheidung (Befund 3 mit in dieses Ticket, Befund 2 und die Umstellung auf
Kennungen als eigene Issues) ist eine technische Entscheidung und getroffen.
