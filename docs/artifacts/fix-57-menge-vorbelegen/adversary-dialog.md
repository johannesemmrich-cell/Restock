# Adversary Dialog — fix-57-menge-vorbelegen
Spec: docs/specs/services/assignment-service-quantity-suggestion.md
Datum: 2026-09-30
Iteration: 1 / 3

## Checkliste

- [x] EB1: Beim Anlegen ohne Menge versucht die App zuerst Historie (dieser Laden), dann Fuellmenge im Namen, sonst bleibt Menge leer — Beweis: AssignmentService.swift:108-121 (Stufenlogik), 8 gruene Unit-Tests (Runde 1), ABER F001 zeigt eine Staleness-Luecke in der Aufrufstelle.
- [x] EB2: Vorbelegte Menge ist sichtbar als Annahme markiert ("ca. 400 g", getoent), nie wie eine eingetippte Menge — Beweis: ItemRow.swift:97-101, UI-Test testAssumedQuantityIsMarkedAsAssumptionInList gruen, ABER F001 zeigt eine FALSCHE Annahme-Markierung fuer ein anderes Item als das, dessen Historie zitiert wird.
- [x] EB3: Korrektur (beim Anlegen oder in Bearbeiten) macht die Menge zur eigenen, Markierung verschwindet — Beweis: EditItemView.swift:343, UI-Test testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal gruen; AddItemView.swift:47-53 (userQuantity/userUnit Bindings).
- [x] EB4: Ohne Evidenz + gelernte Gramm-Rate zeigt die Liste die Rate statt eines erfundenen Gesamtpreises — Beweis: ItemRow.swift:38-41,157-163, UI-Test testItemWithoutEvidenceShowsRateInsteadOfTotal gruen.
- [x] AC-11: History-Stufe — letzter Kauf im selben Laden, namesRepresentSameItem statt contains(), kein laden-uebergreifender Rueckfall, letzter Kauf statt Durchschnitt — Beweis: AssignmentService.swift:108-121, 5 gruene Unit-Tests (testSuggestsLastPurchaseFromSameStore, testIgnoresPurchaseFromDifferentStore, testUsesNamesRepresentSameItemNotSubstring, testMatchesQualifierVariantViaNamesRepresentSameItem, testPicksMostRecentPurchaseNotAverage).
- [x] AC-12: Package-Stufe — "Skyr Natur 500G" -> (500,g,package), "Cola 0,5L" -> (500,ml,package) — Beweis: AssignmentService.swift:117-119, Unit-Test testFallsBackToPackageSizeWhenNoHistory gruen (beide Beispiele).
- [x] AC-13: None-Stufe liefert leere Menge/Einheit/source==none; Nutzereingabe bypasst suggestQuantity komplett — Beweis: AssignmentService.swift:120, AddItemView.swift:200 (Guard quantity.isEmpty), Unit-Test testReturnsNoneWhenNoEvidenceAtAll + UI-Test testUserTypedQuantityIsNeverMarkedAsAssumption gruen — ABER F002 zeigt einen Bypass-Leck bei manuell getippter EINHEIT (Reihenfolge Einheit-vor-Name).
- [x] AC-14: history/package zeigen "ca. " in Color.amber, user zeigt unveraendert .secondary, none zeigt keine Mengenangabe — Beweis: ItemRow.swift:91-102, UI-Test testAssumedQuantityIsMarkedAsAssumptionInList gruen — ABER F003 zeigt eine Luecke fuer quantity==1 && unit=="" (Spec-Abschnitt 1c behauptet "ca. 1", tatsaechlich wird NICHTS angezeigt).
- [x] AC-15: quantitySource==none, unit==g, estimatedPrice gesetzt -> Rate statt Gesamtpreis/leerer Zelle — Beweis: ItemRow.swift:36-41,153-163, UI-Test testItemWithoutEvidenceShowsRateInsteadOfTotal gruen (1,25 EUR/100 g nachgewiesen).
- [x] AC-16: Korrektur in EditItemView setzt quantitySource auf user zurueck — Beweis: EditItemView.swift:335-345, UI-Test testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal gruen.
- [x] AC-18: WCAG-Kontrast RCAmber(dark)/RCSurface(dark) >= 4,5:1 — Beweis: Assets.xcassets/RCAmber.colorset/Contents.json + RCSurface.colorset/Contents.json (Werte stimmen mit dem Test ueberein), Unit-Test testAmberDarkModeContrastMeetsWCAGAA gruen (6,64:1).

## Findings

### F001: Stale-Match-Vorschlag bleibt haengen, wenn der Nutzer nach einem Zwischentreffer weitertippt — falsche "ca."-Annahme fuer ein anderes Item
- **Severity:** HIGH
- **Category:** edge_case
Code reference: SmartCart/Views/Store/AddItemView.swift:199-207
- **Description:** `applySuggestedQuantity(for:)` wird bei jedem Tastendruck ueber `onChange(of: name)` aufgerufen (AddItemView.swift:66-68), aber der Guard ist ausschliesslich `quantity.isEmpty` (Zeile 200). Tippt der Nutzer einen Namen, der bei einem ZWISCHENSTAND exakt einem frueheren Kauf entspricht (z. B. "Milch" als Praefix von "Milchreis"), setzt `suggestQuantity` `quantity`/`unit`/`quantitySource` auf die Historie von "Milch". Sobald `quantity` dadurch nicht mehr leer ist, verhindert genau dieser Guard jede weitere Neubewertung — auch wenn der Nutzer danach zu einem voellig anderen, unverwandten Endnamen weitertippt ("Milchreis"). Das Ergebnis ist in der Liste sichtbar: "Milchreis" traegt die Annahme-Markierung "ca. 2 l", obwohl fuer "Milchreis" nie ein Kauf vorlag — die Markierung behauptet Evidenz, die nicht existiert.
- **Spec requirement:** Expected Behavior Bullet 1 ("...aus dem letzten Kauf DESSELBEN Artikels..."), Bullet 2 ("...ist... als Annahme markiert" impliziert evidenzbasiert fuer das tatsaechliche Item), AC-11 (Matching muss sich auf denselben Artikel beziehen).
- **Conflict:** Die angezeigte "ca."-Annahme bezieht sich nachweislich NICHT auf "Milchreis", sondern auf einen voelligen anderen, zufaelligen Praefix-Treffer aus einer frueheren Tastatureingabe. Live reproduziert (Adversary-Probe, siehe Testausgabe unten) — kein theoretisches Konstrukt.
- **Remediation:** Guard erweitern auf `quantity.isEmpty || quantitySource != "user"` (die App-eigene Vorbelegung darf sich selbst weiter aktualisieren, solange der Nutzer sie nicht manuell bestaetigt/korrigiert hat) — oder `applySuggestedQuantity` bei jedem Namenswechsel `quantity="";unit=""` zuruecksetzen, bevor neu bewertet wird, solange `quantitySource != "user"`.
- **Reproduction (live, adversary probe — nicht Teil des finalen Diffs):** Seed: PurchaseRecord("Milch", storeName:"Quittenhof", 2, "l"). AddItemView (presetStore=Quittenhof) -> Namensfeld "Milch" eintippen (quantity wird "2", unit "l", quantitySource "history") -> Namensfeld um "reis" ergaenzen zu "Milchreis" -> Artikel speichern. Testausgabe: `PROBE afterMilch=2 afterMilchreis=2 rowExists=true caLabelExists=true` (xcodebuild-Log, Testlauf 2026-09-30 09:46, Exit-Code 65, Assertion-Message wortwoertlich uebernommen). Nach dem Beweis vollstaendig aus dem Arbeitsbaum entfernt (git diff gegen origin/main vor/nach dem Probe identisch, siehe Runde 2).

### F002: Manuell eingetippte Einheit wird stillschweigend geloescht, wenn sie VOR dem Artikelnamen eingegeben wird
- **Severity:** HIGH
- **Category:** spec_violation
Code reference: SmartCart/Views/Store/AddItemView.swift:199-207
- **Description:** `applySuggestedQuantity` schreibt unconditional `unit = suggestion.unit` (Zeile 205), OHNE zu pruefen, ob `unit` bereits einen vom Nutzer getippten Wert traegt. Der einzige Guard ist `quantity.isEmpty` (Zeile 200). Tippt der Nutzer zuerst in das Einheit-Feld (z. B. "kg" ueber das `userUnit`-Binding, das dabei korrekt `quantitySource="user"` setzt, AddItemView.swift:51-53) und danach erst den Artikelnamen, laeuft `applySuggestedQuantity` trotzdem (weil `quantity` noch leer ist) und ueberschreibt sowohl `unit` (geloescht auf "" bei source "none") als auch `quantitySource` (zurueckgesetzt von "user" auf "none"/"history"/"package") — die bereits vom Nutzer getroffene Entscheidung wird spurlos vernichtet.
- **Spec requirement:** Kern-Versprechen der Spec (Purpose, Invarianten: "Regeln vor Modell", "Lieber kein Preis als ein falscher") und AC-13s zugrundeliegendes Prinzip (suggestQuantity darf eine Nutzereingabe nicht ueberschreiben) — AC-13 benennt woertlich nur "Menge", der gleiche Schutzmechanismus fehlt aber fuer "Einheit", obwohl beide ueber denselben Aufruf laufen.
- **Conflict:** Der Nutzer tippt aktiv "kg", das Feld zeigt danach wieder den Platzhalter "Einheit" (leer) — ohne jede Fehlermeldung oder sichtbaren Hinweis. Der gespeicherte Artikel zeigt in der Liste GAR KEINE Mengenangabe (ItemRow.swift:97 blendet quantity=="1"+unit=="" komplett aus), obwohl der Nutzer explizit eine Einheit gewaehlt hatte. Live reproduziert.
- **Remediation:** Denselben Schutz wie fuer `quantity` auch fuer `unit` einziehen: `applySuggestedQuantity` nur ausfuehren, wenn WEDER `quantity` NOCH `unit` bereits vom Nutzer gesetzt wurden (z. B. eigenes `@State private var unitTouchedByUser` oder Guard `quantitySource == "user" && !unit.isEmpty` zusaetzlich pruefen, bevor `unit` ueberschrieben wird).
- **Reproduction (live, adversary probe):** AddItemView (Seed "-seedQuantitySuggestionForUITests") -> Einheit-Feld tippen "kg" -> Namensfeld tippen "Kaffeebohnen" (keine Historie/Package-Evidenz) -> Artikel speichern. Testausgabe: `PROBE2 unitFieldAfterTypingName=Einheit rowExists=true kgLabelVisibleInList=false` (xcodebuild-Log, Testlauf 2026-09-30 09:50, Exit-Code 65). "Einheit" ist der lokalisierte Platzhaltertext, XCUITest liefert ihn als `.value`, wenn das Feld leer ist — der Wert "kg" ist verschwunden. Nach dem Beweis vollstaendig aus dem Arbeitsbaum entfernt.

### F003: AC-14/Spec-Abschnitt 1c widersprechen sich fuer quantityAmount==1 und leere Einheit — Annahme-Markierung verschwindet komplett statt "ca. 1" zu zeigen
- **Severity:** MEDIUM
- **Category:** anti_pattern
Code reference: SmartCart/Views/Components/ItemRow.swift:97
- **Description:** Die (unveraendert aus #10 uebernommene) Sichtbarkeitsbedingung `item.quantitySource != "none", item.quantity != "1" || !item.unit.isEmpty` blendet die gesamte Mengenzeile aus, sobald `quantity=="1"` UND `unit==""` — unabhaengig von `quantitySource`. `AssignmentService.suggestQuantity` liefert aber genau diese Kombination fuer einen `PurchaseRecord` mit `quantityAmount==1, unit==""` (spec-eigene Analyse in Implementation Details 1c: "Einzelstueck-Kaeufe ohne belegte Menge als Kaufhistorie-Evidenz" — ein durchaus realistischer, von der Spec selbst als erwartbar beschriebener Fall, z. B. "Milch" ohne je gesetzte Menge).
- **Spec requirement:** AC-14 ("Ein... Artikel mit quantitySource == history... zeigt seine Menge mit Praefix ca. ") kennt keine Ausnahme fuer diesen Fall; Implementation Details 1c behauptet woertlich: "Ein solcher Vorschlag zeigt ca. 1 ohne Einheit".
- **Conflict:** Die tatsaechliche Codepfad-Konsequenz ist NICHT "ca. 1 ohne Einheit", sondern gar keine Anzeige. Die Spec macht hier eine falsche Vorhersage ueber das eigene System — kein neuer Fehler durch #57 (die Bedingung ist unveraendert aus #10), aber #57 macht sie ERSTMALS erreichbar (vorher war quantitySource immer "user", der Fall also gar nicht ueber Historie ausloesbar) und die Spec dokumentiert explizit ein falsches Ergebnis fuer genau diesen neu erreichbaren Fall.
- **Remediation:** Entweder Implementation Details 1c korrigieren (richtig waere: "kein Vorschlag sichtbar" statt "ca. 1 ohne Einheit"), oder die ItemRow-Bedingung um `quantitySource != "user"` erweitern, damit eine ECHTE Annahme (history/package) auch bei quantity==1/unit=="" sichtbar bleibt.

## Confirmations

### AC-11
Code reference: SmartCart/Services/AssignmentService.swift:108-121
- **Evidence:** `suggestQuantity` filtert `purchaseRecords` ueber `namesRepresentSameItem($0.itemName, itemName) && normalizedStoreKey($0.storeName) == storeKey` und nimmt `.max { $0.date < $1.date }` — kein Durchschnitt, kein laden-uebergreifender Fallback, kein `contains()`. 5 Unit-Tests decken alle im AC genannten Teilaspekte einzeln ab und liefen gruen (RestockTests/AssignmentServiceQuantitySuggestionTests.swift, Testlauf 2026-09-30 09:39, 0 Failures).
- **Status:** CONFIRMED (mit Einschraenkung F001 fuer den Aufrufkontext in AddItemView)

### AC-12
Code reference: SmartCart/Services/AssignmentService.swift:117-119
- **Evidence:** `ReceiptParserService.packageSizeFromName(itemName)` wird als zweite Stufe aufgerufen; Unit-Test testFallsBackToPackageSizeWhenNoHistory prueft beide Spec-Beispiele exakt (500G->g, 0,5L->ml) und lief gruen.
- **Status:** CONFIRMED

### AC-13
Code reference: SmartCart/Views/Store/AddItemView.swift:200
- **Evidence:** `guard quantity.isEmpty else { return }` verhindert jeden Aufruf von suggestQuantity, sobald der Nutzer selbst etwas eingetippt hat; UI-Test testUserTypedQuantityIsNeverMarkedAsAssumption bestaetigt das End-zu-Ende (Artikel "Kaffeebohnen" mit selbst eingetippter Menge "3" zeigt nie "ca. 3").
- **Status:** CONFIRMED fuer den in der Spec woertlich beschriebenen Fall (Menge zuerst) — SIEHE F002 fuer eine vom AC nicht abgedeckte, aber analoge Luecke bei der Einheit.

### AC-14
Code reference: SmartCart/Views/Components/ItemRow.swift:91-102
- **Evidence:** `isAssumed = item.quantitySource == "history" || item.quantitySource == "package"`, Text-Praefix "ca. " nur bei isAssumed, Farbe Color.amber vs. .secondary. UI-Test testAssumedQuantityIsMarkedAsAssumptionInList bestaetigt "ca. 400 g" fuer den history-Fall.
- **Status:** CONFIRMED fuer den getesteten Fall — SIEHE F003 fuer eine vom AC-Text nicht beruecksichtigte Randkombination.

### AC-15
Code reference: SmartCart/Views/Components/ItemRow.swift:36-41,153-163
- **Evidence:** `ratePer100g` liefert nur bei `estimatedLineTotal == nil && quantitySource == "none" && unit == "g"` einen Wert; die Preiszelle zeigt dann `rate/100 g`. UI-Test testItemWithoutEvidenceShowsRateInsteadOfTotal bestaetigt "1,25 EUR/100 g" fuer den Seed (estimatedPrice 0,0125 EUR/g).
- **Status:** CONFIRMED

### AC-16
Code reference: SmartCart/Views/Store/EditItemView.swift:335-345
- **Evidence:** `save()` setzt `item.quantitySource = "user"` bei jedem Speichern; UI-Test testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal bestaetigt End-zu-Ende, dass nach einer Korrektur "ca. 400 g" verschwindet, "450 g" ohne Praefix erscheint und die Preiszelle wieder einen Gesamtpreis zeigt.
- **Status:** CONFIRMED

### AC-18
Code reference: SmartCart/Assets.xcassets/RCAmber.colorset/Contents.json
- **Evidence:** Die dunklen sRGB-Werte im Asset (0.784/0.604/0.290) stimmen exakt mit den im Unit-Test hartkodierten Werten ueberein (gegengeprueft per Read-Tool); ebenso RCSurface dark (0.114/0.110/0.086). testAmberDarkModeContrastMeetsWCAGAA berechnet 6,64:1 und lief gruen — ueber der 4,5:1-Schwelle.
- **Status:** CONFIRMED

### SmartCartApp.swift (Seed-Infrastruktur, keine eigene AC)
Code reference: SmartCart/SmartCartApp.swift:215-238
- **Evidence:** `seedQuantitySuggestionForUITestsIfNeeded`/`clearQuantitySuggestionSeedForUITestsIfNeeded` erzeugen deterministisch genau die drei quantitySource-Zustaende (history/none via Seed, user via echte Eingabe), die AC-14/15/16 beweisen; DEBUG-only, raeumt in tearDown() korrekt auf (Issue #28-Muster eingehalten).
- **Status:** CONFIRMED

## Dialog

### Runde 1
**Adversary:** Spec vollstaendig gelesen (11 Checklistenpunkte extrahiert), Produktivcode gelesen (AssignmentService.swift, AddItemView.swift, ItemRow.swift, SmartCartApp.swift, EditItemView.swift), Test Suite gezielt ausgefuehrt: `-only-testing:RestockTests/AssignmentServiceQuantitySuggestionTests -only-testing:RestockUITests/AddItemQuantitySuggestionUITests`. Ergebnis: 8/8 Unit-Tests, 4/4 UI-Tests gruen (TEST SUCCEEDED, docs/artifacts/fix-57-menge-vorbelegen/adversary-run1.txt). RCAmber/RCSurface-Werte gegen die Assets.xcassets-Contents.json gegengeprueft (stimmen exakt mit dem Test ueberein). Die zwei vom Entwickler gemeldeten, bewusst nicht behobenen Randfaelle (Guard nur quantity.isEmpty, nicht quantitySource!=user; Einheit-vor-Name-Ueberschreibung) wurden NICHT einfach als spec-konform akzeptiert, sondern live nachgestellt.
**Implementierer:** (kein Ruecksprache-Partner in diesem Context — Context-Isolation gemaess Adversary-Protokoll; Bewertung erfolgt ausschliesslich gegen Spec + Code + Testlauf.)
**Bewertung:** Alle 12 offiziellen Tests gruen; alle 11 Checklistenpunkte durch Code+Test belegt. Die zwei gemeldeten Randfaelle erschienen zunaechst als moegliche AMBIGUOUS-Kandidaten (Spec deckt sie nicht explizit ab).

### Runde 2
**Adversary:** Frueh-Konvergenz-Skepsis: Grüne Tests allein wurden NICHT als Beweis akzeptiert, dass die zwei gemeldeten Randfaelle harmlos sind. Zwei live Adversary-Probes gebaut (temporaerer Seed-Helfer + temporaere Testmethode in einer Kopie von AddItemQuantitySuggestionUITests.swift, NICHT Teil des finalen Diffs), auf dem dedizierten Simulator Restock-Validate (8F696920-...) ausgefuehrt, danach vollstaendig entfernt (git diff gegen origin/main vor und nach den Probes identisch: 1982 insertions/17 deletions in beiden Faellen). Probe 1 (Stale-Match): PurchaseRecord "Milch"@Quittenhof -> Name "Milch" tippen (Vorschlag greift) -> zu "Milchreis" weitertippen -> Ergebnis PROBE afterMilch=2 afterMilchreis=2 rowExists=true caLabelExists=true — Menge/Annahme bleibt haengen und wird faelschlich an "Milchreis" angezeigt (F001). Probe 2 (Einheit-vor-Name): Einheit "kg" tippen -> Name "Kaffeebohnen" tippen -> Ergebnis PROBE2 unitFieldAfterTypingName=Einheit (=leer) rowExists=true kgLabelVisibleInList=false — die manuell getippte Einheit wird spurlos geloescht (F002). Zusaetzlich beim Code-Lesen ItemRow.swift:97 gegen Spec-Implementation-Details-1c geprueft: Widerspruch gefunden (F003). Nach jeder Probe wurde die offizielle Test-Suite erneut gruen bestaetigt (docs/artifacts/fix-57-menge-vorbelegen/adversary-run2-after-revert.txt, 12/12 gruen), um auszuschliessen, dass die Probes selbst Schaden hinterlassen haben.
**Implementierer:** (kein Ruecksprache-Partner — s.o.)
**Bewertung:** Die zwei vom Entwickler gemeldeten Randfaelle sind KEINE harmlosen, von der Spec bewusst akzeptierten Known Limitations — beide sind live reproduzierbare, in der Liste sichtbare Fehlzustaende, die vom bestehenden Test Plan nicht erfasst werden und in der Known-Limitations-Sektion der Spec NICHT dokumentiert sind (anders als die vier dort tatsaechlich gelisteten Einschraenkungen). F001 und F002 werden daher als BROKEN-Findings gefuehrt, nicht als AMBIGUOUS.

## Verdict

VERDICT: BROKEN

Finding F001: Stale-Match-Vorschlag bleibt beim Weitertippen haengen und markiert ein anderes Item faelschlich als Annahme belegt (HIGH, live reproduziert).
Finding F002: Manuell eingetippte Einheit wird stillschweigend geloescht, wenn sie vor dem Artikelnamen eingegeben wird (HIGH, live reproduziert, widerspricht dem Kernversprechen "Nutzereingabe wird nie ueberschrieben").
Finding F003: Spec-Abschnitt 1c behauptet ein falsches Anzeigeverhalten fuer quantityAmount==1/unit=="" — die Zeile verschwindet komplett statt "ca. 1" zu zeigen (MEDIUM, Spec-Code-Diskrepanz).

Tests: 12 passed (8 Unit + 4 UI), 0 failed, im offiziell vorgesehenen Testlauf.
Checkliste: 11/11 Punkte mit Beweis belegt (Tests + Code-Referenzen) — 3 davon (EB1, EB2, AC-13, AC-14 s.o.) mit dokumentierter Einschraenkung durch F001/F002/F003.
Regressionen: keine gefunden ausserhalb der zwei Findings (Diff ist additiv bis auf AddItemView.swift, dort gezielt auf die Bindings/den Guard begrenzt; volle Ziel-Suite zweimal gruen).
Bekannter Flake: Zwei separate Wiederholungslaeufe der vollen offiziellen Suite (adversary-run3-final.txt, adversary-run4-retry.txt) endeten mit "The test runner hung before establishing connection" — deckungsgleich mit dem dokumentierten Xcode-26-Umgebungsproblem #63 (memory/testrunner-haenger-gemeinsamer-lauf.md), kein Code-Fehler: in beiden Faellen liefen die 4 UI-Tests bereits gruen durch, bevor der RestockTests-Runner beim Verbindungsaufbau haengen blieb. Die urspruenglichen Laeufe (Runde 1, Runde 2 nach Revert) belegen 8/8 + 4/4 gruen zweifelsfrei.



## Iteration 2 - Nachpruefung F001/F002-Fix

Kontext: Der Developer-Agent hat laut Auftragsbeschreibung AddItemView.swift um
`@State private var quantityTouchedByUser = false` erweitert: `applySuggestedQuantity` prueft
jetzt `!quantityTouchedByUser` statt `quantity.isEmpty`; `userQuantity`/`userUnit` setzen den Flag
bei jedem manuellen Schreiben. Zwei neue Regressionstests wurden ergaenzt. Diese Iteration prueft
das UNABHAENGIG nach, akzeptiert die Behauptung nicht.

### Geaenderte Dateien seit Iteration 1 (Hash-Vergleich gegen die in Iteration 1 gestempelten Werte)

- SmartCart/Views/Store/AddItemView.swift - GEAENDERT (Iter.1: 8b6703c2..., jetzt: ecb44ced...)
- SmartCart/SmartCartApp.swift - GEAENDERT (Iter.1: e51b6dfe..., jetzt: 68f22bc0...) - neuer
  PurchaseRecord("Milch", "Quittenhof", 2, "l") im Seed fuer die F001-Regressionstests.
- SmartCart/Services/AssignmentService.swift - UNVERAENDERT (9e4077e9..., identisch zu Iter. 1).
- SmartCart/Views/Components/ItemRow.swift - UNVERAENDERT (4775d3b4..., identisch zu Iter. 1).
- SmartCart/Views/Store/EditItemView.swift - UNVERAENDERT (9c40ed67..., identisch zu Iter. 1).

Da AssignmentService.swift/ItemRow.swift/EditItemView.swift byteidentisch zu den in Iteration 1
geprueften und dort VERIFIED bewerteten Staenden sind, koennen AC-11, AC-12, AC-14, AC-15, AC-16,
AC-18 durch diesen Fix nicht regressiert sein - vorbehaltlich eines erneuten gruenen Testlaufs
(unten), da ein Regressionsrisiko auch aus der geaenderten AddItemView.swift/SmartCartApp.swift
kommen koennte (z. B. falsch durchgereichte Werte).

### Code-Lesung: AddItemView.swift

```
21:    @State private var quantitySource = "user"
24:    @State private var quantityTouchedByUser = false
50:    private var userQuantity: Binding<String> {
51:        Binding(get: { quantity }, set: { quantity = $0; quantitySource = "user"; quantityTouchedByUser = true })
54:    private var userUnit: Binding<String> {
55:        Binding(get: { unit }, set: { unit = $0; quantitySource = "user"; quantityTouchedByUser = true })
203:    private func applySuggestedQuantity(for name: String) {
204:        guard !quantityTouchedByUser else { return }
205:        let suggestion = AssignmentService.suggestQuantity(...)
208:        quantity = suggestion.quantity
209:        unit = suggestion.unit
210:        quantitySource = suggestion.source
```

F001-Mechanismus: Solange `quantityTouchedByUser == false`, laeuft `applySuggestedQuantity` bei
JEDEM Namenswechsel (`onChange(of: name)` -> `autoAssign` -> `applySuggestedQuantity`) erneut und
schreibt `quantity`/`unit`/`quantitySource` komplett neu - ein Zwischenstand-Treffer ("Milch") wird
beim Weitertippen zu "Milchreis" also nicht als Altlast stehen gelassen, weil die Funktion fuer
"Milchreis" erneut (mit dem dann leeren Ergebnis, `source == "none"`) aufgerufen wird und
`quantity`/`unit` ueberschreibt.

F002-Mechanismus: `userQuantity`/`userUnit` setzen `quantityTouchedByUser = true` bei jedem
manuellen Tastendruck in eines der beiden Felder - WELCHES der beiden Felder zuerst angefasst wird,
ist irrelevant, der Flag ist gemeinsam fuer beide. Jede nachfolgende `applySuggestedQuantity`-
Ausfuehrung bricht sofort ueber den Guard ab, kann also weder `quantity` noch `unit` mehr
ueberschreiben, unabhaengig von der Eingabereihenfolge.

### Unabhaengiger Testlauf (frisch, nicht der vom Entwickler mitgelieferte)

Befehl (dediziertes Geraet Restock-Validate, UDID per -destination ...,id=... statt ,name=...,
weil die Name-basierte Destination-Aufloesung bei diesem xcodebuild-Aufruf mit "no available
devices matched" fehlschlug, obwohl der Simulator lief und in der Kompatibilitaetsliste auftauchte
- Workaround dokumentiert, kein Produktfehler):

```
xcodebuild ... -destination 'platform=iOS Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7' \
  -only-testing:RestockTests/AssignmentServiceQuantitySuggestionTests \
  -only-testing:RestockUITests/AddItemQuantitySuggestionUITests test
```

Ergebnis: 8/8 Unit-Tests, 6/6 UI-Tests gruen, TEST SUCCEEDED
(docs/artifacts/fix-57-menge-vorbelegen/adversary-round2-run1.txt). Die zwei NEUEN Regressionstests
liefen mit:
- testStaleSuggestionIsDroppedWhenNameIsTypedFurther (F001) - 28.592s, passed
- testUserTypedUnitIsNeverOverwrittenBySuggestion (F002) - 45.913s, passed

### Eigene, vom Entwickler-Testcode unabhaengige Live-Probe (Round-2-Adversary, nicht Teil des finalen Diffs)

Der mitgelieferte F001-Test prueft nur EINEN Pfad (Weitertippen ohne Backspace) und nur das
unit-Feld. Probe deckt einen zweiten, haerteren Pfad ab: Backspace zurueck zu einem Zwischenstand
OHNE Treffer, dann Weitertippen zu einem neuen Namen - UND prueft zusaetzlich das quantity-Feld
(nicht nur unit), das der offizielle Test nie einzeln abfragt.

Temporaer angehaengte Testmethode testAdversaryProbeBackspaceThenRetypeDropsStaleSuggestion in
einer Arbeitskopie von AddItemQuantitySuggestionUITests.swift (Diff vor/nach der Probe identisch
geprueft, siehe unten):

1. "Milch" tippen -> Vorbedingung geprueft: unit == "l" UND quantityField == "2" (beide Felder,
   nicht nur unit wie im offiziellen Test).
2. Zwei Backspaces -> "Mil" (kein Namenstreffer mehr) -> geprueft: WEDER unit == "l" NOCH
   quantityField == "2" bleiben stehen.
3. "chreis" weitergetippt -> "Milchreis" -> geprueft: unit != "l".
4. Gespeichert -> Liste geoeffnet -> "Milchreis" vorhanden, "ca. 2 l" NICHT vorhanden.

Ergebnis: PASSED (27.105s, docs/artifacts/fix-57-menge-vorbelegen/adversary-round2-probe1.txt,
Testlauf 2026-09-30 11:05). Nach der Probe die Testdatei vollstaendig auf den urspruenglichen Stand
zurueckgesetzt, verifiziert ueber grep (0 Treffer fuer den Probe-Testnamen) und einen
Zeilenzahl-Vergleich der geaenderten Dateien (identisch zum Stand vor der Probe:
AssignmentService.swift | 31, SmartCartApp.swift | 46, ItemRow.swift | 13, AddItemView.swift | 50,
keine Testdatei mehr enthalten).

### AC-13 - veraltete Spec-Prosa vs. beobachtbarer Vertrag

Spec-Text (Implementation Details 2, AC-13-Wortlaut, Test Plan) beschreibt weiterhin den Guard als
`quantity.isEmpty`. Tatsaechlicher Code: `!quantityTouchedByUser`. Das ist ein anderer Mechanismus,
aber das AC selbst verlangt nur ein beobachtbares Ergebnis: "Hat der Nutzer selbst eine Menge
eingetippt, wird suggestQuantity gar nicht erst aufgerufen - der Artikel entsteht mit
quantitySource == user, nie mit einer ca.-Markierung." Geprueft: Sobald quantityTouchedByUser auf
true steht, bricht applySuggestedQuantity beim Guard ab, BEVOR suggestQuantity aufgerufen wird
(Zeile 204, return vor Zeile 205) - der woertliche Kern der Aussage ("gar nicht erst aufgerufen")
stimmt nach wie vor, nur die Bedingung, WANN das gilt, ist strenger/korrekter als vorher
(persistent statt nur bei aktuell leerem Feld - das ist exakt die Korrektur, die F002 behebt).
testUserTypedQuantityIsNeverMarkedAsAssumption bestaetigt den Endzustand unveraendert gruen.
Bewertung: AC-13 bleibt CONFIRMED - die Spec-Prosa ist veraltet (Implementierungsdetail), der
Vertrag (extern beobachtbares Verhalten) ist unveraendert erfuellt, keine Verhaltensaenderung im
Sinne des ACs.

### Neue Beobachtung (F004, nicht blockierend)

Beim Code-Lesen zusaetzlich geprueft: AddItemView.swift:136-139/152-155 (Store-Zeile antippen,
onTapGesture) ruft applySuggestedQuantity NICHT erneut auf - nur selectedStore = store;
autoAssigned = false. Tippt ein Nutzer zuerst einen Namen (Vorschlag greift fuer den
auto-zugewiesenen Laden, oder KEINER greift, weil dort keine Historie existiert) und korrigiert
DANACH manuell den Laden ueber die Store-Liste, wird die Menge nicht gegen den neu gewaehlten
Laden neu bewertet - der Vorschlag bleibt auf Basis des vorherigen Ladens stehen (ggf.
source == "none", obwohl der neu gewaehlte Laden echte Historie haette). Live nicht nachgestellt
(der Seed hat nur einen Store "Quittenhof", ein zweiter Laden waere eine Seed-Erweiterung
ausserhalb des Auftragsrahmens dieser Runde gewesen) - Befund beruht auf Code-Lesung, nicht auf
Beobachtung im Simulator. Bewertung: Kein Regressions-Befund dieser Runde (Verhalten strukturell
unveraendert seit Iteration 1 - der onTapGesture-Handler wurde von diesem Fix nicht angefasst) und
von keinem Expected-Behavior-Punkt oder AC woertlich verlangt (Implementation Details 2 nennt
explizit nur die zwei bestehenden Aufrufer presetStore-Fall/Auto-Zuweisungs-Fall als
Integrationspunkte). Als LOW/edge_case-Finding F004 gefuehrt, NICHT blockierend fuer das Verdict
dieser Runde.

## Findings (Iteration 2)

### F004: Manuelle Laden-Korrektur nach der Namenseingabe loest keine Neubewertung der Mengen-Vorbelegung aus
- Severity: LOW
- Category: edge_case
- Code reference: SmartCart/Views/Store/AddItemView.swift:136-139,152-155
- Description: Der onTapGesture-Handler der Store-Auswahlzeile setzt nur selectedStore/
  autoAssigned, ruft aber nicht applySuggestedQuantity erneut auf. Eine bereits (auto-)ermittelte
  Mengen-Vorbelegung bleibt nach einer manuellen Laden-Korrektur auf dem alten Laden stehen.
- Spec requirement: Kein AC/Expected-Behavior-Punkt verlangt explizit eine Neubewertung bei
  Laden-Wechsel; Implementation Details 2 nennt nur die zwei bestehenden Aufrufer als
  Integrationspunkte.
- Conflict: Eher eine Luecke als ein Widerspruch - AC-11 beschreibt die reine Funktion
  suggestQuantity, nicht diese View-Interaktion.
- Remediation: Falls gewuenscht, applySuggestedQuantity(for: name) zusaetzlich aus dem
  Store-Zeile-onTapGesture aufrufen (mit demselben quantityTouchedByUser-Schutz). Kein Fix in
  dieser Runde noetig - vorbestehendes, unveraendertes Verhalten, kein neuer Fund durch
  F001/F002-Fix.
- Status: Nicht blockierend, zur Kenntnisnahme (analog F003).

## Confirmations (Iteration 2)

### F001-Fix
Code reference: SmartCart/Views/Store/AddItemView.swift:204
- Evidence: `guard !quantityTouchedByUser else { return }` erlaubt applySuggestedQuantity bei
  JEDER Namensaenderung erneut zu laufen, solange der Nutzer nichts manuell angefasst hat - ein
  Zwischentreffer wird beim Weitertippen also durch das neue (leere) Ergebnis ueberschrieben, nicht
  eingefroren. Bestaetigt durch testStaleSuggestionIsDroppedWhenNameIsTypedFurther (gruen,
  28.592s) UND durch die unabhaengige Adversary-Probe mit Backspace-Pfad + Pruefung des
  quantity-Feldes (gruen, 27.105s, danach vollstaendig entfernt).
- Status: CONFIRMED - F001 ist behoben.

### F002-Fix
Code reference: SmartCart/Views/Store/AddItemView.swift:50-56
- Evidence: userQuantity/userUnit setzen quantityTouchedByUser = true bei jedem manuellen
  Schreiben in eines der beiden Felder, unabhaengig von der Reihenfolge; jede nachfolgende
  applySuggestedQuantity-Ausfuehrung bricht sofort ab. Bestaetigt durch
  testUserTypedUnitIsNeverOverwrittenBySuggestion (gruen, 45.913s, Einheit-vor-Name-Reihenfolge).
- Status: CONFIRMED - F002 ist behoben.

### AC-13 (erneut geprueft)
Code reference: SmartCart/Views/Store/AddItemView.swift:204-205
- Evidence: s. Abschnitt "AC-13 - veraltete Spec-Prosa vs. beobachtbarer Vertrag" oben. Der externe
  Vertrag ("suggestQuantity nicht aufgerufen, wenn Nutzer selbst getippt hat, nie
  ca.-Markierung") ist unveraendert erfuellt, nur der interne Mechanismus hat sich geaendert
  (Spec-Freeze verhindert das Nachziehen der Prosa, siehe Auftrag).
- Status: CONFIRMED (mit dokumentierter Spec-Prosa-Diskrepanz, kein Verhaltensfehler).

### AC-11, AC-12, AC-14, AC-15, AC-16, AC-18 (Regressionspruefung)
Code reference: SmartCart/Services/AssignmentService.swift:108-121 (AC-11/12),
SmartCart/Views/Components/ItemRow.swift:91-102,153-163 (AC-14/15),
SmartCart/Views/Store/EditItemView.swift:335-345 (AC-16),
SmartCart/Assets.xcassets/RCAmber.colorset/Contents.json (AC-18)
- Evidence: Alle vier Dateien byteidentisch zu den in Iteration 1 als CONFIRMED geprueften
  Staenden (SHA-256-Vergleich, s. o.) - keine Codeaenderung, die diese ACs betreffen koennte.
  Frischer Testlauf dieser Runde bestaetigt alle zugehoerigen Tests weiterhin gruen
  (testSuggestsLastPurchaseFromSameStore, testIgnoresPurchaseFromDifferentStore,
  testUsesNamesRepresentSameItemNotSubstring, testMatchesQualifierVariantViaNamesRepresentSameItem,
  testPicksMostRecentPurchaseNotAverage, testFallsBackToPackageSizeWhenNoHistory,
  testAssumedQuantityIsMarkedAsAssumptionInList, testItemWithoutEvidenceShowsRateInsteadOfTotal,
  testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal,
  testAmberDarkModeContrastMeetsWCAGAA).
- Status: CONFIRMED - keine Regression durch den F001/F002-Fix.

## Dialog (Iteration 2)

### Runde 1
Adversary: Round-1-Protokoll gelesen (11 Checklistenpunkte, F001-F003). Auftragsbeschreibung NICHT
unkritisch uebernommen - Behauptung "F001/F002 behoben" zunaechst als unbewiesen behandelt.
Aktuellen Code gelesen (AddItemView.swift vollstaendig), SHA-256 aller fuenf relevanten Dateien
gegen die in Iteration 1 gestempelten Werte verglichen: nur AddItemView.swift und SmartCartApp.swift
geaendert, die drei anderen byteidentisch. Mechanismus (quantityTouchedByUser) gegen beide Findings
einzeln durchgespielt (Codepfad-Analyse, nicht nur "sieht plausibel aus"). Offiziellen Testlauf
frisch auf dem dedizierten Simulator ausgefuehrt (nicht die Behauptung "12/12 gruen" aus der
Auftragsbeschreibung uebernommen) - 14/14 gruen, inkl. der zwei neuen Regressionstests fuer
F001/F002.
Bewertung: Mechanismus UND Testergebnis stimmen ueberein - erste Runde spricht fuer VERIFIED, aber
Fruehkonvergenz vermeiden: eigene Probe noetig, da der mitgelieferte F001-Test nur einen von
mehreren plausiblen Pfaden (Weitertippen ohne Backspace, nur unit-Feld geprueft) abdeckt.

### Runde 2
Adversary: Fruehkonvergenz-Skepsis: eigene, vom Entwickler-Testcode unabhaengige Probe gebaut
(Backspace-Pfad + quantity-Feld-Pruefung, s. o.), auf dem dedizierten Simulator ausgefuehrt, PASSED,
danach sauber entfernt (Stand vor/nach identisch). Zusaetzlich beim Code-Lesen eine neue, vom Fix
nicht abgedeckte Randstelle gefunden (Store-Zeile-Tap loest keine Neubewertung aus, F004) - nicht
einfach ignoriert, sondern als eigenstaendigen, nicht-blockierenden Fund dokumentiert, mit
Begruendung, warum er das Verdict nicht kippt (kein AC verlangt es, kein neues Verhalten durch
diesen Fix, strukturell unveraendert seit Iteration 1). AC-13 explizit gegen den beobachtbaren
Vertrag statt gegen die veraltete Prosa bewertet (Auftrag verlangte das explizit) - Guard-Reihenfolge
im Code nachgelesen (Zeile 204 vor 205), bestaetigt: suggestQuantity wird tatsaechlich nicht
aufgerufen, sobald der Nutzer etwas angefasst hat.
Bewertung: F001 und F002 sind durch unabhaengige Beweisfuehrung (frischer Testlauf + eigene Probe +
Code-Lesung) als BEHOBEN bestaetigt. F003 bleibt wie vom Auftrag vorgegeben bewusst offen (MEDIUM,
kein neuer Fund). F004 ist neu, aber LOW und nicht-blockierend. Keine Regression bei den in
Iteration 1 bereits VERIFIED-Punkten (Datei-Hashes + frischer Testlauf). Alle 11 urspruenglichen
Checklistenpunkte weiterhin durch Code+Test belegt, zwei davon (F001/F002-Einschraenkungen) jetzt
OHNE Einschraenkung.

## Verdict (Iteration 2, final)

VERDICT: VERIFIED

F001 (Stale-Match-Vorschlag) - BEHOBEN, unabhaengig bestaetigt: frischer Lauf des mitgelieferten
Regressionstests (testStaleSuggestionIsDroppedWhenNameIsTypedFurther, 28.592s, passed) UND eigene
Backspace-Probe mit Pruefung von Menge UND Einheit (27.105s, passed, danach entfernt).

F002 (Einheit wird ueberschrieben) - BEHOBEN, unabhaengig bestaetigt: frischer Lauf des
mitgelieferten Regressionstests (testUserTypedUnitIsNeverOverwrittenBySuggestion, 45.913s, passed).

F003 (AC-14/Spec-Widerspruch bei quantity==1/unit=="") - weiterhin offen, wie vom Auftrag
vorgegeben bewusst nicht in dieser Runde behoben (MEDIUM, kein neuer Fund, keine
Verschlechterung).

F004 (Store-Korrektur nach Namenseingabe loest keine Neubewertung aus) - NEU in dieser Runde
gefunden, LOW, nicht-blockierend, vorbestehendes Verhalten (kein Regressions-Fund durch
F001/F002-Fix), von keinem AC woertlich verlangt.

AC-13: CONFIRMED trotz veralteter Spec-Prosa - der beobachtbare Vertrag ("suggestQuantity nie
aufgerufen, wenn Nutzer selbst getippt hat") ist durch den neuen Mechanismus
(quantityTouchedByUser) weiterhin erfuellt, keine Verhaltensaenderung im Sinne des ACs.

Tests: 14 passed (8 Unit + 6 UI), 0 failed, im offiziell vorgesehenen Testlauf
(docs/artifacts/fix-57-menge-vorbelegen/adversary-round2-run1.txt) plus 1 zusaetzlicher, selbst
gebauter und wieder entfernter Adversary-Probe-Test, ebenfalls gruen
(docs/artifacts/fix-57-menge-vorbelegen/adversary-round2-probe1.txt).

Checkliste: 11/11 Punkte weiterhin durch Code+Test belegt - zwei davon (EB1/AC-11 betroffen von
F001, AC-13 betroffen von F002) jetzt OHNE Einschraenkung, da beide zugrundeliegenden Findings
behoben sind. F003 bleibt mit MEDIUM-Einschraenkung bei AC-14, wie in Iteration 1 dokumentiert und
im Auftrag dieser Runde ausdruecklich als bewusst offen bestaetigt.

Regressionen: keine gefunden - AssignmentService.swift/ItemRow.swift/EditItemView.swift
byteidentisch zum in Iteration 1 geprueften Stand, alle zugehoerigen Tests liefen erneut gruen.

## Geprüfte Dateien

- sha256:1d0a6df17b91f10a75b2bb3d8e0d3d3be583a32e8e1a2dd45930f9eded78d6b3  SmartCart/Assets.xcassets/RCAmber.colorset/Contents.json
- sha256:9e4077e9b043b8cd5f25f9e84acf1a39dad9ba39afcd9ef87f1f3860a7334333  SmartCart/Services/AssignmentService.swift
- sha256:68f22bc09eb2720a111d980cf5eb378f2824f9e14f0634ce838a02ad91f59075  SmartCart/SmartCartApp.swift
- sha256:4775d3b4b6f98ed67feadbcdf9b7031872f3eb58db2fc4fefe4ec0bce7f5b3d5  SmartCart/Views/Components/ItemRow.swift
- sha256:ecb44ced7f95eb9d3b57f165a3000af4e318068cf11f56ba8848e8fdafe82aa5  SmartCart/Views/Store/AddItemView.swift
- sha256:9c40ed675277cbc4c68961bd7a6cebcb6ca21af0743620ccfb9e6ace7b6632df  SmartCart/Views/Store/EditItemView.swift
