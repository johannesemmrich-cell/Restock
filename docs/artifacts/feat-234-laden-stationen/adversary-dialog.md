# Adversary Dialog — feat-234-laden-stationen
Spec: docs/specs/models/store-stations.md
Datum: 2026-10-30 21:56

## Checkliste
- [x] **AC-1:** Ein Laden ohne Gänge (Feld leer, nicht dekodierbar oder ohne Gänge) verhält sich bitgenau wie bisher: `sortedIndices` mit `stationRank == nil` liefert in allen drei Modi dieselben Reihenfolgen wie vor der Änderung (festgeschriebene Regressionsfälle), `pendingItems`, Gruppierung, Auswahl und Menü unverändert; Bestandstests (`ShoppingRouteTests`, `ShoppingRouteManualOrderTests`, `StoreCategoriesTests`, `ShoppingRouteUITests`, `ShoppingRouteLearningUITests`) bleiben grün.
- [x] **AC-2:** Mit Lidl-Vorlage zeigt der Modus „Kategorie“ je nicht leerem Gang einen Abschnitt in der festen Gang-Reihenfolge, mit Gang-Emoji in der Überschrift; leere Gänge erscheinen nicht; Dringende bleiben im Abschnitt „Dringend“ oben.
- [x] **AC-3:** „Sonstiges“ ist der letzte Abschnitt (ohne Emoji) und erscheint nur, wenn mindestens ein offener Artikel dort liegt; die Vorlage hat genau die 12 Gänge der Tabelle in dieser Reihenfolge.
- [x] **AC-4:** Stichwort-Zuordnung: Salami → Kühltheke Fertiges, Gouda → Käse, Salatgurke → Obst & Gemüse, Bratwurst → Frisches Fleisch & Fisch, Leberkäse → Kühltheke Fertiges, ein unerkannter Name (automatische Kategorie „Lebensmittel“) → Sonstiges; ein Stichwort trifft, wenn ein Wort des Namens ihm gleicht oder darauf endet, das längste Stichwort gewinnt, bei Gleichstand der frühere Gang.
- [x] **AC-5:** Eine ausgeblendete feste Kategorie (Vorlage: Baumarkt, z. B. Werkzeug) ordnet ihre Artikel nie einem Gang zu; sie landen in „Sonstiges“, sofern weder Merkung noch Stichwort greifen. Feste Kategorien, die keinem Gang zugeordnet und nicht ausgeblendet sind (offen), landen ebenfalls in „Sonstiges“.
- [x] **AC-6:** Die Auflösung folgt der Reihenfolge Merkung > von Hand gesetzte Kategorie > Stichwort > automatische Kategorie > Sonstiges; die Sonstiges-Marke hält einen Artikel gegen Stichwort und feste Kategorie in „Sonstiges“.
- [x] **AC-7:** Im Modus „Einkaufsweg“ stehen die Artikel in Gang-Reihenfolge, innerhalb eines Gangs nach gelernter Artikelposition, dann nach Hinzufüge-Datum; der Modus „Kategorie“ gilt dieselbe Ordnung der Zeilen innerhalb der Abschnitte; „Hinzugefügt“ ist unverändert.
- [x] **AC-8:** Dringende Artikel stehen in beiden Modi zuerst, unabhängig vom Gang.
- [x] **AC-9:** Das Abhaken lernt nur die Reihenfolge innerhalb eines Gangs: Ein Artikel, der in einem späteren Gang zuerst abgehakt wurde, rückt nicht vor Artikel früherer Gänge; `recordCheckOff` zeichnet den Gang-Namen (Sonstiges: die Marke) als Kategorie auf.
- [x] **AC-10:** Im Modus „Einkaufsweg“ ist die Liste flach ohne Gang-Überschriften; der Untertitel jeder Zeile zeigt den Gang-Namen oder „Sonstiges“ statt der festen Kategorie.
- [x] **AC-11:** Die Kategorie-Auswahl eines Ladens mit Gängen zeigt nur dessen Gänge in Laden-Reihenfolge plus „Sonstiges“ (keine festen Kategorien, kein Abschnitt „Alle Kategorien“); „„<Name>“ als Gang anlegen“ hängt einen neuen Gang vor „Sonstiges“ an und wählt ihn; „Sonstiges“/„Other“ kann kein Gang werden.
- [x] **AC-12:** Die Wahl eines Gangs (auch eines, dessen Name einer festen Kategorie gleicht) wird je Artikelschlüssel gemerkt; ein neu hinzugefügter Artikel gleichen Namens landet wieder im gemerkten Gang (`ShoppingItem.init`).
- [x] **AC-13:** Die Wahl „Sonstiges“ wird als Marke gemerkt, steht nie in `ShoppingItem.category` und wird von `rememberedCategory(forItemNamed:)` nie als Kategorie zurückgegeben.
- [x] **AC-14:** „Gänge entfernen“ (mit Rückfrage) stellt das klassische Verhalten wieder her, ohne eigene Kategorien oder Merkungen zu löschen; „Lidl-Vorlage übernehmen“ (mit Rückfrage, nur ohne Gänge) setzt die Vorlage und legt die Gang-Namen, die keine festen Kategorien sind, als eigene Kategorien an, ohne Artikel zu ändern.
- [x] **AC-15:** In Läden mit Gängen fehlt „Reihenfolge anpassen“ im Modus „Kategorie“ und ist im Modus „Einkaufsweg“ vorhanden; in Läden ohne Gänge unverändert.
- [x] **AC-16:** Das neue Feld `stationConfigJSON` steht in der Feldliste von `MirroredSchemaSnapshotTests` (Store) und als `CD_stationConfigJSON STRING` in `docs/cloudkit/private-schema-aktuell.ckdb`; der Deploy-Pflichtpunkt steht in der Definition of Done.
- [x] **AC-17:** Alle neuen Texte haben deutsche und englische Fassung mit gleichen Schlüsseln und gleichen Platzhaltern (`LocalizationKeyParityTests` grün). Die Preisschätzung, Startseite und „Alle Artikel“ bleiben unverändert (automatische Kategorie, feste Kategorien).

## Dialog

### Runde 1
**Adversary:** Geprüft wurde der Diff gegen den RED-Stand, die Spec und die Rohprotokolle. Die Testprotokolle sind jünger als alle Quelldateien (Quellen zuletzt 19:32, UI-Stationen 19:42, Unit-Voll 20:16), gelten also für den Arbeitsbaum. Unit-Klassen 57/0, UI-Stationen 7/0, UI-Regression 29/0, Unit-Voll 772/0, 0 übersprungen.
- AC-1 PROVEN: `stationRank` hat Default nil; `sortedIndices` nimmt den neuen Pfad nur bei `mode != .added` und mindestens einem Rang (ShoppingRoute.swift:244-246), sonst läuft der alte Code unverändert. `activeStationConfig` liefert für leer, `{` und null Gänge nil (Store.swift:335). Tests T1 (testStoreWithoutUsableConfigBehavesAsBefore), T17 in ShoppingRouteTests, Bestandsklassen grün. Gruppierung/Menü: Zweige nur bei `hasStations` (StoreDetailView.swift:202, 565, 630).
- AC-2 PROVEN: groupedRegularItems gruppiert nach stationName, Reihenfolge config.stations plus Marke, leere Gruppen per compactMap entfernt (StoreDetailView.swift:200-208). UI testCategoryModeShowsStationSections grün.
- AC-3 PROVEN: Sonstiges zuletzt, Titel ohne Emoji (sectionTitle StoreDetailView.swift:749), Vorlage 12 Gänge (StoreCategories.swift:278ff, testTemplateIsConsistent).
- AC-4 PROVEN: stationForKeywords (StoreCategories.swift:234) nutzt hasSuffix auf Wörtern, strikt längeres gewinnt (key.count > best), bei Gleichstand bleibt der frühere Gang. Randfälle selbst durchgerechnet: Teewurst (wurst 5 > tee 3), Leberkäse (9 > käse 4), Hustensaft (10 > saft 4), Eistee (6 > tee 3), Reis trifft kein Stichwort (kein Stichwort "eis"). Faltung per compareKey auf beiden Seiten, Umlaute konsistent. Tests T2-T5.
- AC-5 PROVEN: stationForCategory prüft hidden vor builtIns; nicht zugeordnete Kategorien liefern nil. testHiddenBuiltInNeverMapsToStation.
- AC-6 PROVEN: Reihenfolge im Code Merkung (Marke -> nil), von Hand, Stichwort, automatisch (StoreCategories.swift:202-215). testResolutionPriority.
- AC-7/AC-8 PROVEN: stationSortedIndices (ShoppingRoute.swift:293): dringend, Rang, bekannte Position, Datum, Eingangsindex. testSortedIndicesWithStationRank, testPendingItemsFollowStationOrder; .added getrennt geprüft.
- AC-9 PROVEN: Rang ist erstes Kriterium nach Dringend, Kategorie-Mittel unbenutzt; recordCheckOff zeichnet Gangname bzw. Marke (Store.swift:254-262). T10 (Korrektur (b): finalizeStaleTrip bei 90 s + 31 min, tripGap 30 min, Rechnung stimmt) und T11.
- AC-10 PROVEN: ItemRow.displayCategory (ItemRow.swift:36) liefert Gang oder station.other. UI testRouteModeIsFlatInStationOrderWithStationSubtitles.
- AC-11 PROVEN: stationSections zeigt nur Gänge plus Sonstiges, kein Abschnitt "Alle Kategorien" (CategoryPickerView.swift:105-125). Neuer Gang per append vor Sonstiges; Other/Sonstiges -> .other, Marke -> .invalid (StoreCategories.swift:262, Store.swift:397). T14, UI testPickerShowsOnlyStationsAndOther, testCreatingStationFromPickerAppendsSection.
- AC-12 PROVEN: rememberCategory nimmt isStationChoice (Store.swift:618); ShoppingItem.init nutzt rememberedCategory. T13 plus UI testChosenStationIsRememberedForNewItem.
- AC-13 PROVEN im Modell, Beweislücke in den Ansichten: rememberedCategory schließt die Marke aus (Store.swift:625). Add: isOther -> item.category = automatische Kategorie (AddItemView.swift:300-306); Ladenwechsel: onChange setzt chosenCategory auf nil, weil die Marke weder feste noch eigene Kategorie noch Gang ist (AddItemView.swift:239-247), auch bei selectedStore == nil. Edit: applyCategory (EditItemView.swift:472) ersetzt die Marke durch die automatische Kategorie, wenn der Zielladen keine Gänge hat. Per Code-Lesung belegt, aber KEIN Test führt Add/Edit mit Sonstiges-Wahl oder Ladenwechsel aus (siehe F002).
- AC-14 PROVEN: applyStationConfig legt nur Gang-Namen als eigene Kategorie an, die keine feste Kategorie sind und noch nicht existieren (Store.swift:380); removeStations leert nur das Feld (Store.swift:389). T12 und UI testRemoveAndReapplyStations.
- AC-15 PROVEN: StoreDetailView.swift:565 versteckt "Reihenfolge anpassen" nur bei category und hasStations; Menüeintrag nach hasStations (629). UI testMenuEntriesInStoreWithStations.
- AC-16 PROVEN: Feld Store.swift:73, ckdb-Zeile alphabetisch korrekt, MirroredSchemaSnapshotTests 5/0; Deploy-Pflicht steht in der Spec (Abschnitt Deploy-Pflicht, Zeile 318ff, und DoD Zeile 479).
- AC-17 PROVEN: 9 Schlüssel je Sprache, LocalizationKeyParityTests 4/0; HomeView, AllItemsView, PriceEstimator und ShoppingItem.swift sind nicht im Diff; T19 vergleicht Preis/Kategorie mit Laden ohne Gänge. ItemRow wird nur von StoreDetailView benutzt.
Code reference: SmartCart/Models/ShoppingRoute.swift:244
Code reference: SmartCart/Models/Store.swift:335
Code reference: SmartCart/Models/StoreCategories.swift:234
Code reference: SmartCart/Views/Store/StoreDetailView.swift:200
Code reference: SmartCart/Views/Components/ItemRow.swift:36
Code reference: SmartCart/Views/Store/CategoryPickerView.swift:105
Code reference: SmartCart/Views/Store/AddItemView.swift:300
Code reference: SmartCart/Views/Store/EditItemView.swift:472
Code reference: SmartCart/SmartCartApp.swift:426
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Gezielter Angriff auf Randfälle.
- Ladenwechsel in Edit mit gewählter Sonstiges-Marke in einen Laden ohne Gänge: applyCategory ersetzt die Marke (EditItemView.swift:482). In einen Laden MIT Gängen bleibt die Marke gültig (isStationChoice) und wird dort gemerkt, gewollt.
- Gang-Wahl "Käse" in Edit, danach Ladenwechsel in Laden ohne Gang: oldStore.isCustomCategory("Käse") ist wahr, Kategorie wird zurückgesetzt. Bei Gang-Namen, die feste Kategorien sind (Obst & Gemüse, Getränke, Milchprodukte), bleibt die feste Kategorie bewusst stehen.
- Abbrechen: Merken geschieht nur in addItem()/save(), nie im Picker, PROVEN per Code. Der Picker legt einen neuen Gang allerdings sofort an (addStation), auch wenn der Dialog danach abgebrochen wird. Das entspricht der Mechanik eigener Kategorien (#85); die Spec verlangt es nicht anders.
- Gänge entfernen und rememberedCategory: Gang-Namen, die eigene Kategorien sind, werden danach als eigene Kategorie geliefert (Store.swift:625-629), Spec-Folge "Kategorien und Merkungen bleiben". Die Marke wird nie geliefert.
- Synchronisation: Die Marke steht in categoryAssignments und reist in assignmentsJSON zu Mitgliedern geteilter Läden; rememberedCategory gibt sie nie aus, daher kein Leck in item.category. Kein weiterer Leser von categoryAssignments außer Store.swift.
- Stichwörter: Fehltreffer durch die Endungsregel (z. B. Thunfisch -> "fisch" -> Frisches Fleisch & Fisch statt Konserven), von der Spec in Kauf genommen, LOW (F004).
- Nach dem Abhaken rückt kein späterer Gang nach vorn: stationSortedIndices ignoriert Kategorie-Positionen; belegt durch T10.
- Leistung: pendingCount(inStation:) (Store.swift:374) läuft für jede der 13 Auswahlzeilen und bei jedem Tastendruck im Suchfeld neu; jeder Aufruf dekodiert das JSON und faltet jedes Stichwort per compareKey (Locale-Faltung) neu. Nicht gemessen; bei ~100 Artikeln potenziell spürbar (F001).
- Funktionslänge: CategoryPickerView.body hat 54 Zeilen (vorher 106, also verbessert); alle anderen neuen Funktionen <= 50.
- Unverändert: HomeView, AllItemsView, PriceEstimator, ShoppingItem.swift nicht im Diff.
Offene Beweisforderungen: (1) Test für Edit-Speichern mit Sonstiges-Wahl und Ladenwechsel (Marke nie in item.category), etwa UI-Test oder Auslagerung von applyCategory in eine testbare Funktion; (2) measure-Test für pendingItems und pendingCount(inStation:) mit 200 Artikeln in StoreStationsTests.
Code reference: SmartCart/Models/Store.swift:374
Code reference: SmartCart/Models/StoreCategories.swift:234
Code reference: SmartCart/Views/Store/EditItemView.swift:472
Code reference: SmartCart/Views/Store/AddItemView.swift:239
Code reference: SmartCart/Views/Store/CategoryPickerView.swift:105
Code reference: SmartCart/Views/Store/StoreDetailView.swift:565
Code reference: SmartCart/Models/ShoppingRoute.swift:293
Code reference: SmartCart/SmartCartApp.swift:426
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachprüfung der Änderungen seit Runde 2 (F002: UI-Test U8, F005: Auslagerung searchSection) und der Testumgebung 27.2.
- U8 fängt F002: Der Test wählt "Sonstiges" in Bearbeiten (Salami) und Hinzufügen (Schinken), prüft beide im Modus Kategorie unter "Sonstiges", entfernt dann die Gänge und prüft zweierlei: die Liste (beide unter Fleisch & Wurst) und, entscheidend, die Kategorie-Zeile im Bearbeiten-Dialog. Nur dieser Dialog zeigt `item.category` roh, die Liste zeigt bei nicht von Hand gesetzter Kategorie ohnehin die automatische. Eine durchgesickerte Marke erscheint dort als "other" (Gegenprobe: "🏷️ other").
- Gegenproben schlüssig (u8-gegenproben.txt): Edit mit Marke und manuallySet=true rot, Edit mit Marke und manuallySet=false rot, Add mit Marke und manuallySet=false rot, jeweils mit der erwarteten Meldung; Ausgangsstand grün. Damit sind beide Schreibstellen (AddItemView.swift:306, EditItemView.swift:475) einzeln scharf. Zurücksetzen verifiziert: beide Zeilen stehen im Arbeitsbaum wieder als `isOther ? automaticCategory : category` bzw. `isOther ? category : chosen`. Nicht abgedeckt bleibt nur Add mit Marke und manuallySet=true; die Prüfung am Dialog hängt nicht an diesem Flag, daher gleichwertig zu Gegenprobe 1.
- Randfix schwächt nichts: Er wirkt nur direkt vor dem Öffnen des Bearbeiten-Dialogs (weniger als 150 pt über dem Fensterrand: einmal wischen) und gleicht eine angeschnittene Zeile aus, deren Lang-Drücken nichts öffnet (Videobild belegt). Alle Aussagen über Abschnitte und Dialog-Label bleiben unverändert und werden danach geprüft. Das Warten auf stehenden Rahmen versteckt nichts, es poll't mit Frist 5 s und prüft danach hart.
- Rest von F002 bleibt offen: Ladenwechsel in Edit/Add (Marke oder Gang in Laden ohne Gänge) hat weiterhin keinen Test. Code-Lesung unverändert tragfähig (EditItemView.swift:482, AddItemView.swift:239-247). Herabgestuft auf LOW.
- F005 Auslagerung verhaltensgleich: Der Suchabschnitt wurde unverändert (gleiche Modifikatoren, gleiche Kennung `categoryPicker.search`, gleicher `listRowBackground`) in `searchSection` verschoben und steht weiterhin als erstes Element der List. `body` hat jetzt 38 Zeilen (67 bis ~104). Fix gilt als erledigt.
- Testumgebung 27.2 statt 27.0: Die Testprotokolle (UI-Stationen 8/0 um 08:21, Unit-Klassen 57/0 08:21, volle Unit-Suite 772/0 08:22, UI-Regression 17/0 08:30) sind jünger als die letzten Quelländerungen (AddItemView 08:10, EditItemView 08:07, Tests 07:57, CategoryPickerView gestern). Lücke: Die UI-Regression umfasst nur 4 Klassen (17 Tests, vorher 29); ItemRowTapUITests (12 Tests, öffnet Dialoge über UITestItemEditor) wurde auf 27.2 nicht gefahren. Die Dialogcode-Änderungen in Add/Edit seit Runde 2 sind laut Gegenprobe-Protokoll nur Aus- und Einbau, die Zeilen sind wortgleich zurück. Forderung: ItemRowTapUITests einmal auf dem Stand laufen lassen, wenn möglich. Zusätzlich ist 27.2 eine andere Runtime als der frühere Nachweis auf 27.0; die iOS-26-Linie wird ohnehin nur in CI gefahren.
- Bestand der früheren Befunde: F001 (Leistung, ungemessen) bleibt als bekannte Grenze offen, F003 (Marke beim Wechsel zwischen Gang-Läden) und F004 (Thunfisch) bleiben als LOW bestehen, keine der Änderungen berührt diese Stellen.
Code reference: SmartCart/Views/Store/AddItemView.swift:306
Code reference: SmartCart/Views/Store/EditItemView.swift:475
Code reference: SmartCart/Views/Store/CategoryPickerView.swift:47
Code reference: SmartCart/Models/Store.swift:374
Code reference: SmartCart/Models/StoreCategories.swift:234
Code reference: SmartCart/Models/ShoppingRoute.swift:293
Code reference: SmartCart/Views/Store/StoreDetailView.swift:565
Code reference: SmartCart/Views/Components/ItemRow.swift:36
Code reference: SmartCart/SmartCartApp.swift:426
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

### F001: Wiederholte JSON-Dekodierung und Stichwort-Faltung bei jedem Aufruf (stationName, pendingCount(inStation:)); nicht gemessen. Bekannte Grenze.
- ID: F001
- **Severity:** MEDIUM
- **Category:** edge_case
- **Evidence:** SmartCart/Models/Store.swift:335 und :374, SmartCart/Models/StoreCategories.swift:234
- **Remediation:** Konfiguration und gefaltete Stichwörter je Render einmal berechnen, measure-Test mit 200 Artikeln.

### F002: Marke in Add und Edit: jetzt durch U8 samt dreier Gegenproben abgedeckt. Offen nur noch der Ladenwechsel (kein Test).
- ID: F002
- **Severity:** LOW
- **Category:** edge_case
- **Evidence:** RestockUITests/StoreStationsUITests.swift:429-483, docs/artifacts/feat-234-laden-stationen/u8-gegenproben.txt, SmartCart/Views/Store/EditItemView.swift:482
- **Remediation:** Optional Ladenwechsel-Test in Edit und Add.

### F003: Beim Wechsel zwischen zwei Läden mit Gängen verwirft AddItemView die gewählte Sonstiges-Marke, eine Gang-Wahl bleibt erhalten.
- ID: F003
- **Severity:** LOW
- **Category:** edge_case
- **Evidence:** SmartCart/Views/Store/AddItemView.swift:243-247
- **Remediation:** Marke beim Prüfen ausnehmen, wenn der neue Laden Gänge hat.

### F004: Die Endungsregel erzeugt Fehltreffer wie Thunfisch -> Frisches Fleisch & Fisch; von der Spec in Kauf genommen.
- ID: F004
- **Severity:** LOW
- **Category:** edge_case
- **Evidence:** SmartCart/Models/StoreCategories.swift:278
- **Remediation:** Ausnahme in der Vorlage oder Merkung durch den Nutzer.

### F005: CategoryPickerView.body war 54 Zeilen, jetzt 38 (searchSection ausgelagert, verhaltensgleich). Erledigt.
- ID: F005
- **Severity:** LOW
- **Category:** anti_pattern
- **Evidence:** SmartCart/Views/Store/CategoryPickerView.swift:47-104
- **Remediation:** keine.

### F006: UI-Regression auf 27.2 nur 17 Tests in 4 Klassen; ItemRowTapUITests (12) nicht erneut gefahren, obwohl sie Bearbeiten-Dialoge öffnet.
- ID: F006
- **Severity:** LOW
- **Category:** edge_case
- **Evidence:** docs/artifacts/feat-234-laden-stationen/test-green-ui-regression-272.txt (Suiten: AddItemQuantitySuggestion, LegacyLearnedPriceReset, ShoppingRouteLearning, ShoppingRoute)
- **Remediation:** ItemRowTapUITests einmal auf 27.2 fahren und das Protokoll ablegen.

## Verdict
**VERIFIED**
Offene Punkte: 0 / 17 (Beweisforderung: ItemRowTapUITests auf 27.2, keine Blocker)

## Geprüfte Dateien

- sha256:753428114baff4e51cdcb20249cb8e1607a2cbc08ba5b023ddd53d45775ecee1  SmartCart/Models/ShoppingRoute.swift
- sha256:6a6885f691d193ab297075564d52d76ca442d709bf6ec82ee96cfcf176eb9e23  SmartCart/Models/Store.swift
- sha256:0b934839b853df007d5241a5e440fda0307848084aedb5312c99965e4728bd73  SmartCart/Models/StoreCategories.swift
- sha256:8977d1e436e72b3bb500507a08a806fe27b7c480d9214f63f471bb4b8f1f2979  SmartCart/SmartCartApp.swift
- sha256:1e9c46354d662953e088c998e478bf06d972a1c3f8c6bb9127b689496cf15fb9  SmartCart/Views/Components/ItemRow.swift
- sha256:fe0660a4280ce8900a72f97e772c7b9e5dc216b81cd9c16cb8d1ce83904dc8af  SmartCart/Views/Store/AddItemView.swift
- sha256:fb628608a8529b1c233d01189943559b3f2f650742c981ba6df5ed95c7dfad9f  SmartCart/Views/Store/CategoryPickerView.swift
- sha256:a18c05434cab9fbe136832213eab940db6913b83cac3d9a5e40ab2c1522c02d3  SmartCart/Views/Store/EditItemView.swift
- sha256:a08e165b82d2bd185aadd0a8b47fb9e4a8206e75c89f085f8b4b826133fb35e3  SmartCart/Views/Store/StoreDetailView.swift

## Prüfbasis

- base: df3fe488980f38f8fc886633c64045d73d36d65a
- blob:26e4941caec988a791b224948ae01d0a0b37a357  SmartCart/Models/ShoppingRoute.swift
- blob:96b42fba2749a3281df1b69b51f469d587912e99  SmartCart/Models/Store.swift
- blob:3e290a0ca16bf0f75182b4415e6d1d68d4d5aea0  SmartCart/Models/StoreCategories.swift
- blob:c1ca179ac7080d0a4a2e54e93017ca8ee8887589  SmartCart/SmartCartApp.swift
- blob:7d901af2d1bc51ba8cb252ed340141985042a321  SmartCart/Views/Components/ItemRow.swift
- blob:7969928fc17cdf4fbce03067f3075d73251e0869  SmartCart/Views/Store/AddItemView.swift
- blob:5d3fcb6d33b88aaf5d9fb9d02eff5b5930489246  SmartCart/Views/Store/CategoryPickerView.swift
- blob:8e65722b049fba0e6536b08a079520eec31ca27c  SmartCart/Views/Store/EditItemView.swift
- blob:535f25c21fc7dcdabc4889a1fa067d04a5cdceb5  SmartCart/Views/Store/StoreDetailView.swift
