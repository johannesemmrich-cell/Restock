# Adversary Dialog — feat-234-d2b2-picker-uebernahme
Spec: docs/specs/views/station-picker-adoption.md
Datum: 2026-11-01 19:43

## Checkliste
- [x] **AC-1:** GIVEN die Kategorie-Auswahl eines Artikels in einem Laden mit Gängen WHEN der Nutzer eine Gang-Zeile nach links wischt THEN erscheinen „Bearbeiten“ und „Löschen“; die Zeile „Sonstiges“ zeigt keine Wischaktionen; Läden ohne Gänge verhalten sich unverändert. (Y1, Y2)
- [x] **AC-2:** GIVEN „Bearbeiten“ auf einem Gang WHEN Name und Emoji gespeichert werden THEN läuft es über `renameStation` (Merkungen, von Hand gesetzte Artikelkategorien, gelernter Weg und Sitzung ziehen mit); WHEN der Name abgelehnt wird (schon vergeben, „Sonstiges“, leer) THEN bleibt der Editor offen mit der Meldung „Diesen Namen gibt es schon oder er ist nicht erlaubt.“ und nichts ist geändert. (P4, Y1)
- [x] **AC-3:** GIVEN der umbenannte Gang ist in der Auswahl des offenen Dialogs gewählt WHEN er umbenannt wird THEN ist die Auswahl der neue Name, und das Sichern des Artikels legt ihn in diesen Gang (nicht zurück unter den alten Namen); eine andere Auswahl bleibt unverändert. (P1, Y1)
- [x] **AC-4:** GIVEN „Löschen“ auf einem Gang WHEN der Nutzer es wählt THEN fragt die App vorher („Gang „X“ löschen?“, Abbrechen ändert nichts); WHEN bestätigt und der Gang war gewählt (und nicht der letzte) THEN ist die Auswahl der Gang, in den der Artikel automatisch fiele, sonst „Sonstiges“ (Marke, nie die rohe Kategorie), und der Artikel wird nicht fälschlich als von Hand kategorisiert gespeichert. (P2, Y2)
- [x] **AC-5:** GIVEN der letzte Gang eines Ladens WHEN er in der Auswahl gelöscht wird THEN lautet die Rückfrage „Gänge entfernen?“ (dieselbe Logik wie `StationSetupView.delete`/`deleteDialog`), danach hat der Laden keine Gänge, und war er gewählt, ist die Auswahl die automatische Kategorie. (P3, Y3)
- [x] **AC-6:** GIVEN „Kategorien einrichten“ eines Ladens mit Gängen WHEN es eigene Kategorien gibt, die kein aktueller Gang sind und (deren Name in keiner Vorlage steht ODER die von Artikeln oder Merkungen genutzt werden) THEN zeigt ein Abschnitt „Eigene Kategorien von früher · N“ genau diese (Vergleich über `compareKey`, „Sonstiges“ und leere Namen nie); gibt es keine, ist der Abschnitt nicht da; in Läden ohne Gänge gibt es ihn nie. (A1, A2, A3, A4, Y8, Y9)
- [x] **AC-7:** GIVEN eine Zeile im Abschnitt WHEN „Übernehmen“ THEN entsteht ein neuer Gang am Ende mit dem Namen und dem eigenen Emoji der Kategorie, die Zeile verlässt den Abschnitt, und Artikel, die der Kategorie von Hand zugeordnet oder gemerkt waren (offen und erledigt), stehen sofort in diesem Gang, ohne dass Daten verschoben werden; ist der Name nicht annehmbar (schon Gang, „Sonstiges“, Laden ohne Gänge), ändert sich nichts. (A5, A7, A8, Y8)
- [x] **AC-8:** GIVEN der Abschnitt WHEN „Alle übernehmen“ THEN werden alle gezeigten Kategorien in Listenreihenfolge am Ende angelegt, mit genau einem Schreibvorgang (ein `updateStationConfig`), der Abschnitt verschwindet; ein zweiter Aufruf ändert nichts. (A6, Y9)
- [x] **AC-9:** GIVEN die Übersicht von „Kategorien einrichten“ WHEN ein Gang per Wischen gelöscht und bestätigt wird THEN verschwindet die Zeile und seine Artikel fallen in den Gang, der automatisch gälte, sonst „Sonstiges“; Abbrechen der Rückfrage lässt den Gang stehen. (Y4)
- [x] **AC-10:** GIVEN das Gang-Detail WHEN eine Kategorie zu einem anderen Gang gleichen Namens gehört THEN zeigt ihre Zeile den Untertitel „gehört zu Gang <Name>“; eine nicht gebundene Kategorie zeigt ihn nicht. (Y5)
- [x] **AC-11:** GIVEN das Gang-Detail WHEN ein Emoji im aufgeklappten Raster getippt wird THEN steht es sofort am Gang und im Abschnittskopf der Ladenliste. (Y6)
- [x] **AC-12:** GIVEN ein Laden mit `shareID` WHEN „Kategorien einrichten“ geöffnet wird THEN steht der Hinweis „Gänge bleiben bis zum Abgleich auf diesem Gerät.“ da; in einem Laden ohne `shareID` fehlt er. (Y7, Y4)
- [x] **AC-13:** GIVEN die vier neuen Texte WHEN die Tabellen geladen werden THEN haben sie deutsche und englische Fassung mit gleichen Schlüsseln und Platzhaltern. (A9, `LocalizationKeyParityTests`)
- [x] **AC-14:** GIVEN die Änderung insgesamt THEN gibt es kein neues `@Model`-Feld, keinen neuen `@AppStorage`-Schlüssel, keine Schemaänderung und keine `ci.yml`-Änderung; Läden ohne Gänge verhalten sich unverändert; die Seeds und Kennungen sind im Release-Build nicht kompiliert; alle Bestandstests bleiben grün. (A7, Gesamtlauf, Release-Strings-Nachweis)

## Dialog

Testlauf: `docs/artifacts/feat-234-d2b2-picker-uebernahme/adversary-test-output.txt` (Restock-Validate-272, iOS 27.2):
StoreStationsTests 60/0, LocalizationKeyParityTests 4/0, MirroredSchemaSnapshotTests 5/0, ShoppingRouteTests 29/0, gesamt 98 bestanden, 0 fehlgeschlagen, 0 übersprungen.
Die UI-Läufe (Extras 12/0, StoreStations 16/0) und die volle Unit-Suite stammen aus `test-green-output.txt` des Implementierers (nicht von mir wiederholt).
Runde 3 (Stand nach den Fixes), selbst gefahren auf Restock-Validate-272: Unit 99/0 (StoreStationsTests 61, LocalizationKeyParityTests 4, MirroredSchemaSnapshotTests 5, ShoppingRouteTests 29) und StationSetupExtrasUITests 13/0, beide `TEST SUCCEEDED`, 0 übersprungen; Ausgabe in derselben Datei (überschrieben).
Die 2 Fehlschläge der vollen Suite liegen in ConsumptionPatternTests, Issue #231 (OPEN, tageszeitabhängig), Dateien nicht im Diff.

### Runde 1
**Adversary:** Ich gehe die Änderung Datei für Datei durch und suche Fälle, in denen die Zusage der Spec nur im Testaufbau gilt.

Code reference: SmartCart/Models/StoreCategories.swift:412
Regel R3 (`adoptableCategories`): Filter über `resolveStation(...)` = `.new`, damit fallen Sonstiges/Other, Marke, leere Namen und vorhandene Gänge heraus (resolveStation, StoreCategories.swift:264). Vergleich über `compareKey` auf beiden Seiten (`used` und `templateNames` sind compareKeys, StoreTemplates.swift:128-131). Reihenfolge der Eingabe bleibt. Kein Defekt gefunden.

Code reference: SmartCart/Models/StoreTemplates.swift:116
`templateStationNames` wird einmal aus allen fünf Vorlagen gebildet. `adoptCategory`/`adoptAllCategories` (StoreTemplates.swift:137-155): Läden ohne Gänge liefern `[]`/`nil`, nichts geschrieben; `adoptAllCategories` ruft `updateStationConfig` höchstens einmal (nach der Schleife, nur bei nicht leerem Ergebnis); doppelte Schlüssel werden über `addingStation` = nil übersprungen. Die Datei steht laut pbxproj nur in der Sources-Phase des App-Ziels, Widget und Teilen-Erweiterung enthalten sie nicht (Festlegung bestätigt).

Code reference: SmartCart/Views/Store/StationAdoptionSection.swift:12
Abschnitt nur bei nicht leerer Liste; Alle übernehmen im Kopf, `adoptAll()` ruft die Hülle genau einmal. Kein Defekt.

Code reference: SmartCart/Views/Store/StationSetupView.swift:39
Der Abschnitt hängt direkt unter Gänge statt nach der Ausgeblendet-Sektion. Das weicht von der Spec-Zeile ab, ist aber durch den freigegebenen Entwurf gedeckt; AC-6 verlangt nur Existenz und Inhalt, keine Position. Festlegung akzeptiert, Spec-Text sollte nachgezogen werden (LOW, F005).

Code reference: SmartCart/Views/Store/CategoryPickerView.swift:260
Löschen in der Auswahl: `wasSelected` wird vor dem Löschen aus dem Getter-Wert gebildet, danach läuft `StationSetupView.delete` (eine Löschlogik). Nicht gewählter Gang: Auswahl unverändert. Letzter Gang: Auswahl wird `automaticCategory`. Marke bei verbleibenden Gängen bleibt. Das stimmt mit der Spec überein.
ABER: Der Setter schreibt in Add `chosenCategory` (AddItemView.swift:80) und in Edit `category` plus `categoryPicked = true` (EditItemView.swift:56). Sobald die Auswahl nach dem Löschen (oder nach dem Umbenennen, CategoryPickerView.swift:95-99) gesetzt wird, gilt der Artikel als gewählt: Add speichert dann `categoryManuallySet = !isOther` (AddItemView.swift:307-309), Edit ebenso (EditItemView.swift:477), und beide rufen `rememberCategory`. War der gelöschte Gang nur die automatische Auflösung (Add: `chosenCategory == nil`), wird der Artikel durch das Löschen von Hand gepinnt (Fallback-Gang) bzw. die Marke Sonstiges dauerhaft gemerkt. AC-4 verlangt ausdrücklich "nicht fälschlich als von Hand kategorisiert gespeichert". Y2 sieht das nicht, weil der Test den Gang vorher von Hand gewählt hat.

Code reference: SmartCart/Views/Store/AddItemView.swift:307
Der Gang-Fall setzt `categoryManuallySet = true` und `rememberCategory(chosen, ...)`. Die Spec-Annahme (Gang statt roher Kategorie vermeidet "von Hand") trifft nur für die Marke zu.

Code reference: SmartCart/Views/Store/EditItemView.swift:477
Dasselbe im Edit-Pfad (`item.categoryManuallySet = !isOther`).

Code reference: SmartCart/SmartCartApp.swift:409
Die Seeds liegen im DEBUG-Block (SmartCartApp.swift:192-949); der Release-Strings-Nachweis zeigt 0 Treffer für alle neuen Argumente. Der Aufräumer setzt `shareID = nil` (SmartCartApp.swift:464); `shareID` ist ein reiner UserDefaults-Schlüssel (Store.swift:85-91), also richtig. ABER: Der Seed `-seedStationStoreSharedForUITests` setzt `shareID`, und `StoreDetailView` pullt beim Erscheinen und pusht in `onDisappear` für jeden Laden mit `shareID` (StoreDetailView.swift:149-169; der Schutz `-skipCloudKitForScreenshots` gilt nur für den Pull, und Y7 übergibt ihn nicht). `SharedStoreService.syncToCloud` legt bei fehlendem Record einen neuen an und speichert ihn in der öffentlichen Datenbank (SharedStoreService.swift:69-78). Die Spec behauptet "kein Schreiben, höchstens Fehler-Banner"; auf einem Simulator mit iCloud-Konto stimmt das nicht. Ohne Konto (Restock-Validate, CI) scheitert der Aufruf nur.

Code reference: SmartCart/Views/Store/AddItemView.swift:150
`itemName: trimmedName` wird übergeben, gleiches in EditItemView.swift:162. Der Standardwert leer bleibt für andere Aufrufer.

**Implementierer:** Festlegungen aus red-hinweise.md (Phase 6): Reihenfolge alphabetisch, Abschnitt unter Gänge, Y1-Gegenprobe ans Ende, Rückfall ohne Gänge = automaticCategory, Aufräumer setzt shareID = nil, templateStationNames in StoreTemplates.swift. Zur Zusage "nicht von Hand": die Spec fordert die Gang-Auswahl nach dem Löschen und leitet daraus ab, dass nichts gepinnt wird.

### Runde 2
**Adversary:** Ich prüfe die Antwort gegen den Code.

Code reference: SmartCart/Views/Store/AddItemView.swift:80
Die Antwort trägt nicht: Der Setter kann "automatisch" nicht ausdrücken, `chosenCategory` ist danach nie `nil`. Folge in Add: `categoryLabel` zeigt nicht mehr "Automatisch: ..." (AddItemView.swift:86), Speichern pinnt den Fallback-Gang (manuell und gemerkt) oder merkt die Marke. Gleiches gilt für das Umbenennen eines nur automatisch gewählten Gangs (CategoryPickerView.swift:97-98). Das ist F002. Reparatur: im Add-Pfad `chosenCategory` nur setzen, wenn der Nutzer vorher schon gewählt hatte, sonst `nil` lassen; im Edit-Pfad `categoryPicked` nur setzen, wenn es schon wahr war.

Code reference: SmartCart/Views/Store/CategoryPickerView.swift:354
Der Namens-Editor im Gang-Modus bleibt bei einem abgelehnten Namen stehen und ändert nichts, weil `renameStation` vorher prüft (Store.swift:424-428). Bei leerem Namen ist Speichern deaktiviert.
Randfall (F003, LOW): Die Fehlermeldung `rejected` bleibt stehen, auch wenn der Nutzer danach den Namen ändert, bis zum erfolgreichen Speichern. Nur Schreibweise geändert: `renamedSelection` liefert über compareKey richtig den neuen Namen.

Code reference: SmartCart/Models/StoreCategories.swift:422
`renamedSelection` ignoriert die Marke und vergleicht über compareKey; `selectionAfterDeleting` ohne Gänge liefert `automaticCategory`, sonst die Auflösung oder die Marke. Fall Gang heißt wie feste Kategorie (Getränke gelöscht): Auflösung gibt nil, also Marke; kein Widerspruch zur Spec.

Kontrollen: Funktionen im Diff alle unter 50 Zeilen (größte: der Seed für Altladen rund 25, `StationAdoptionSection.body` 21). Kein neues Modellfeld, kein neuer Speicher-Schlüssel, keine Änderung der Workflow-Datei der CI (Projektdatei +4 Zeilen, je 4 neue Strings in de/en mit gleichen Schlüsseln und Platzhalter %d; LocalizationKeyParityTests grün). Läden ohne Gänge: `adoptionConfig` nil, `isStation` Standard false, Swipe-Aktionen nur im Gang-Zweig (CategoryPickerView.swift:137), die Zeile Sonstiges ohne Aktionen.

**Implementierer:** Keine Gegenargumente zu F001/F002; Festlegungen wie oben.

### Runde 3
**Adversary:** Nachprüfung der Fixes F001, F002, F003 am aktuellen Code, dann alle ACs erneut.

Code reference: SmartCart/Models/StoreCategories.swift:428
`followedChoice(chosen, next)` liefert `nil` ohne eigene Wahl, sonst `next`. Aufrufer: Add (AddItemView.swift:151) übergibt `chosenCategory` als Vorgabe, bleibt es `nil`, so bleibt der Artikel bei der Automatik: `categoryLabel` zeigt weiter "Automatisch: ...", `save()` pinnt nichts (der Zweig `if let chosen = chosenCategory` greift nicht). Mit eigener Wahl folgt sie dem neuen Gang bzw. der Marke, auch beim letzten Gang (dann Rohkategorie ohne Gänge: `categoryManuallySet = chosen != category`, also false bei Gleichheit). P5 prüft die reine Funktion einschließlich Marke.

Code reference: SmartCart/Views/Store/CategoryPickerView.swift:278
`follow` ruft `onFollow` oder (Vorgabe, alte Aufrufer) setzt `selection`. Beide Auslöser, Umbenennen (Zeile 99-100) und Löschen (Zeile 272), laufen über `follow`. Kein weiterer Setter-Pfad übrig.

Code reference: SmartCart/Views/Store/EditItemView.swift:61
`followSelection`: (a) eigene Wahl (`categoryPicked`): `category = next`, `categoryPicked` bleibt wahr, Verhalten wie zuvor. (b) keine eigene Wahl, aber gespeicherte Handwahl (`item.categoryManuallySet`): `category = item.category`, was nach `renameStation` schon der neue Name ist; `categoryPicked` wird nie neu gesetzt. (c) weder noch: nichts. Randfälle durchgedacht: Umbenennen statt Löschen ohne eigene Wahl: Automatik bleibt (Add nil, Edit Fall c), die Merkungen zieht `renameStation` nach; Handwahl-Gang gelöscht, keine eigene Wahl im Dialog: `category` bleibt der alte Name, `categoryPicked` false, `applyCategory` nimmt den Altpfad, `categoryManuallySet` bleibt wie vor dem Dialog, das ist das Verhalten von D2a beim Löschen aus der Übersicht, kein neuer Fehler; Sonstiges-Marke gewählt und Gang gelöscht: `wasSelected` ist falsch, nur ohne Gänge folgt die Automatik; Laden ohne Gänge: kein Gang-Zweig, `onFollow` wird nie gerufen. Y10 belegt Ende zu Ende: Gouda ohne eigene Wahl, Käse in der Auswahl gelöscht, Sichern, Gouda steht unter Milchprodukte, und nach dem Stichwort `gouda` in "Kühltheke Fertiges" wandert Gouda dorthin, also nicht als Handwahl gepinnt. F002 behoben.

Code reference: SmartCart/Views/Store/CategoryPickerView.swift:323
`.onChange(of: newName) { rejected = false }`. F003 behoben (Meldung verschwindet beim Weiterschreiben; wird beim erneuten Ablehnen wieder gesetzt, Zeile 376).

Code reference: SmartCart/Views/Store/StoreDetailView.swift:164
`skipPush` ist nur unter `#if DEBUG` an `-skipCloudKitForScreenshots` gekoppelt; in Release bleibt `false`, die Bedingung `store.shareID != nil && !skipPush` ist dort mit dem alten Verhalten identisch (nur eine "nie verändert"-Warnung möglich). Y7 startet mit dem Argument (StationSetupExtrasUITests.swift:747). F001 für den dokumentierten Weg behoben.
Andere Wege, auf denen der Shared-Seed in CloudKit schreiben kann (geprüft): periodisches `pullAllSharedStores` und `pull` lesen nur (SyncCoordinator.swift:98, 213); `AddItemView.save` und Home-Pushes laufen in Y7 nicht; aber `SyncCoordinator.resubscribeAll` (SmartCartApp.swift:978) legt beim App-Start für jeden Laden mit `shareID` eine `CKQuerySubscription` an und `pushWidgetCheckoffsIfNeeded` (SyncCoordinator.swift:171) pusht alle geteilten Läden, wenn ein veraltetes Widget-Flag in der App-Gruppe steht. Beide ignorieren `-skipCloudKitForScreenshots`. Keiner schreibt Ladendaten im Y7-Ablauf (Abo ist kein Record mit Ladeninhalt, Flag nur nach Widget-Abhaken); auf einem Simulator mit iCloud-Konto bleibt aber ein Restabonnement "sub-UITEST-NOSHARE". Das ist F006 (LOW), nicht blockierend.

Code reference: SmartCart/Models/StoreTemplates.swift:116
Erneut gelesen: `templateStationNames`, `adoptableCategories`-Aufruf (Zeile 131) und `adoptAllCategories` (Zeile 146) unverändert; AC-6, AC-7, AC-8 weiterhin durch A1-A8, Y8, Y9 grün.

Code reference: SmartCart/SmartCartApp.swift:409
Seed mit `shareID` und Aufräumer unverändert; Release-Strings-Nachweis `release-strings-check.txt` nennt Basis nach den Fixes (20:53), den Release-Build habe ich nicht wiederholt (vermerkt).

Code reference: SmartCart/Views/Store/StationAdoptionSection.swift:8
Abschnittsansicht unverändert (Unter-Abschnitt, Alle übernehmen mit einem Schreibvorgang).

Code reference: SmartCart/Views/Store/StationSetupView.swift:39
Position unter "Gänge" bleibt, F005 betrifft nur den Spec-Text (Doku).

Code reference: SmartCart/Views/Store/AddItemView.swift:151
Add: `itemName` und `onFollow` sind die einzigen Änderungen; `automaticCategory` unverändert.

**Regression-Gegenprobe:** Alle Bestandstests im gezielten Lauf grün (99/0); AC-1 bis AC-3, AC-5 bis AC-14 sind durch denselben Lauf (Unit) beziehungsweise Extras-UI (13/0) bestätigt; StoreStationsUITests (16) habe ich nicht wiederholt, die Fixes berühren dort nur den Picker über `onFollow`, Standardverhalten ohne Handler unverändert.

**Implementierer:** keine Einwände.

## Findings

Status Runde 3: BEHOBEN (Rest siehe F006)
Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/SmartCartApp.swift:409
  Description: Der Seed `-seedStationStoreSharedForUITests` gibt dem Laden `shareID` UITEST-NOSHARE. Beim Öffnen und Verlassen der Ladenliste (Y7) pullt `StoreDetailView` und pusht in `onDisappear` (StoreDetailView.swift:149-169); `SharedStoreService.syncToCloud` legt dabei einen neuen CloudKit-Record mit Ladenname und Artikeln in der öffentlichen Datenbank an (SharedStoreService.swift:69-78). `-skipCloudKitForScreenshots` schützt nur den Pull und wird von Y7 nicht gesetzt.
  Spec requirement: Known Limitations der Spec (kein Schreiben, höchstens Fehler-Banner); Repo-Regel aus #208 (keine Fremddaten aus UI-Tests).
  Conflict: Die Zusage stimmt nur ohne iCloud-Konto im Simulator; mit Konto entsteht Fremddaten-Müll in CloudKit. Nicht im Lauf belegt (Restock-Validate hat kein Konto), aber aus dem Code eindeutig.
  Remediation: Y7 mit `-skipCloudKitForScreenshots` starten und den Push in `onDisappear` ebenfalls darauf prüfen (oder den Hinweis prüfen, ohne die Ladenliste zu verlassen); Spec-Satz korrigieren.

Status Runde 3: BEHOBEN (P5, Y10 grün)
Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/Views/Store/CategoryPickerView.swift:260
  Description: Nach Löschen (ebenso nach Umbenennen, CategoryPickerView.swift:95-99) schreibt die Ansicht die Auswahl über den Setter. Add (AddItemView.swift:80, 307-309) und Edit (EditItemView.swift:56, 474-478) werten das als Handwahl: bei einem Gang `categoryManuallySet = true` plus `rememberCategory`, bei der Marke wird Sonstiges dauerhaft gemerkt. Das gilt auch, wenn der Gang vorher nur die automatische Auflösung war.
  Spec requirement: AC-4, der Artikel wird nicht fälschlich als von Hand kategorisiert gespeichert.
  Conflict: Gouda wird nach dem Löschen von Käse als von Hand in Milchprodukte gespeichert und gemerkt; ein später neu angelegter Gang Käse greift für Gouda nicht mehr. Y2 prüft es nicht (der Test wählt Käse vorher von Hand), P2 prüft nur die reine Funktion.
  Remediation: Auswahl nur nachziehen, wenn der Nutzer vorher gewählt hatte; sonst Add: `chosenCategory` bei nil lassen, Edit: `categoryPicked` nicht setzen; Test, der nach dem Löschen sichert und `categoryManuallySet` sowie die Merkung prüft.

Status Runde 3: BEHOBEN
Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Store/CategoryPickerView.swift:317
  Description: `rejected` wird nur beim erfolgreichen Speichern zurückgesetzt, nicht beim Weiterschreiben im Namensfeld; die rote Meldung bleibt neben einem inzwischen gültigen Namen stehen.
  Spec requirement: AC-2 (Meldung bei abgelehntem Namen).
  Conflict: Irreführende Anzeige, keine Datenwirkung.
  Remediation: Beim Ändern des Namens `rejected = false` setzen.

Status Runde 3: OFFEN (nur Doku, Spec-Changelog)
Finding:
  ID: F005
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Views/Store/StationSetupView.swift:39
  Description: Die Abschnittsposition weicht von der Spec-Zeile ab; die Spec nennt noch die alte Position.
  Spec requirement: Spec Abschnitt (b).
  Conflict: Dokumentationsabweichung, funktional gedeckt vom freigegebenen Entwurf.
  Remediation: Spec-Zeile anpassen (Changelog).

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/SmartCartApp.swift:978
  Description: `resubscribeAll` legt beim Start für jeden Laden mit `shareID` (auch den Seed UITEST-NOSHARE) eine Abfrage-Subskription in der öffentlichen CloudKit-Datenbank an; `pushWidgetCheckoffsIfNeeded` (SyncCoordinator.swift:171) pusht bei veraltetem Widget-Flag alle geteilten Läden. Beide kennen `-skipCloudKitForScreenshots` nicht.
  Spec requirement: Repo-Regel aus #208 (keine Fremddaten aus UI-Tests), Known Limitations der Spec.
  Conflict: Mit iCloud-Konto im Simulator bleibt ein Restabonnement; Ladendaten werden im Y7-Ablauf nicht geschrieben. Bestandsverhalten aller Seeds mit `shareID`, nicht durch diesen Durchgang eingeführt.
  Remediation: In der Spec als bekannte Grenze nennen; optional beide Aufrufe unter DEBUG am Argument vorbeiführen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Views/Store/CategoryPickerView.swift:137
  Evidence: Swipe-Aktionen Löschen/Bearbeiten nur an Gang-Zeilen; Sonstiges-Zeile ohne; ohne Gänge kein Gang-Zweig. Y1/Y2 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Views/Store/CategoryPickerView.swift:354
  Evidence: save() ruft renameStation, bei nil bleibt der Editor stehen und zeigt station.setup.name.rejected; Ablehnung ändert nichts (P4 grün). Nur F003 (LOW).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/StoreCategories.swift:422
  Evidence: renamedSelection zieht die Auswahl über compareKey nach, andere Auswahl unverändert (P1, Y1 grün). Einschränkung aus F002 betrifft die Handwahl-Markierung, nicht den Namen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Views/Store/StationSetupView.swift:246
  Evidence: Gemeinsame delete/deleteDialog (letzter Gang: Gänge entfernen); Auswahl dann automaticCategory (CategoryPickerView.swift:260-274); P3, Y3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Models/StoreTemplates.swift:126
  Evidence: Store.adoptableCategories ruft R3 mit customCategories, genutzten compareKeys und templateStationNames; leer ohne Gänge. A1-A4, Y8, Y9 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Views/Store/StationAdoptionSection.swift:48
  Evidence: adopt ruft Store.adoptCategory (addingStation mit eigenem Emoji, ein Schreibvorgang), keine Datenwanderung; A5, A7, A8, Y8 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Models/StoreTemplates.swift:146
  Evidence: Schleife über adoptableCategories, ein updateStationConfig nach der Schleife nur bei nicht leerem Ergebnis; zweiter Aufruf liefert leer. A6, Y9 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Store/StationSetupView.swift:246
  Evidence: Übersicht nutzt die bestehende delete-Logik samt Rückfrage (D2a); Y4 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Views/Store/StationSetupView.swift:582
  Evidence: Untertitel gehört zu Gang besteht (station.setup.detail.bound); Y5 grün mit Gegenprobe Konserven.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/Views/Store/StationSetupView.swift:759
  Evidence: Nur Kennung am Emoji-Raster ergänzt, Verhalten Bestand; Y6 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/SmartCartApp.swift:464
  Evidence: Hinweis hängt an store.shareID != nil (StationSetupView.swift:92); Y7/Y4 grün. Nebenwirkung des Seeds siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Views/Store/AddItemView.swift:150
  Evidence: Je vier neue Schlüssel in de/en mit gleichem Platzhalter %d; LocalizationKeyParityTests 4/0 in meinem Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Views/Store/EditItemView.swift:162
  Evidence: Kein neues Modellfeld, kein neuer Speicher-Schlüssel, keine CI-Änderung (Projektdatei +4 Zeilen, nur App-Ziel); Seeds im DEBUG-Block, Release-Strings 0 Treffer. Volle Suite des Implementierers: 2 Altfehler aus #231, nicht im Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Views/Store/EditItemView.swift:61
  Evidence: Rückfrage und Auswahl nach Löschen (CategoryPickerView.swift:272) bleiben; ohne eigene Wahl bleibt die Automatik (`followedChoice` nil, StoreCategories.swift:428; Edit nur gespeicherte Handwahl), kein Pinnen, keine Merkung. P2, P5, Y2, Y10 grün (Runde 3 selbst gefahren).
  Status: CONFIRMED

AC-4 war nach Runde 2 DISPROVEN (F002); nach dem Fix in Runde 3 PROVEN (siehe Confirmation AC-4).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
F002 (MEDIUM), F001 (MEDIUM) und F003 (LOW) sind behoben und am Code sowie im eigenen Lauf belegt. Offen bleiben nur F005 (Spec-Text) und F006 (LOW, Bestandsverhalten der Seeds mit shareID), beide nicht blockierend.
Tests: 112 passed (Unit 99 + UI StationSetupExtrasUITests 13), 0 failed, 0 übersprungen.
Edge cases: Umbenennen/Löschen ohne eigene Wahl, Handwahl-Gang, Marke, letzter Gang, Laden ohne Gänge geprüft, nichts gebrochen.
Regressions: keine gefunden (StoreStationsUITests 16 und Release-Build nicht wiederholt, Belege des Implementierers).
Checklist: 14/14 points proven

## Geprüfte Dateien

- sha256:b7f1d9d30f2f5a275eea971dcb16bc0bfd352ff0330861b50b5aa9cb3c441a43  SmartCart/Models/StoreCategories.swift
- sha256:0dde601f6502349a9839bf1c38e43fcc66391f1989fcc64de1bbbe5db93614e8  SmartCart/Models/StoreTemplates.swift
- sha256:e78ccdede04b2e335f1ebd264ee93cd5e28cd05ae41327eb717e5fddf527eb3a  SmartCart/SmartCartApp.swift
- sha256:c3e649c7ecd1bec8598e3d7b8d4c5ebdf2d5f664acf4fbde084ffaf8f8cb5385  SmartCart/Views/Store/AddItemView.swift
- sha256:d09993953a154153987fa4910a0716a7cb04587ecc559db48c08a0d49c97fafc  SmartCart/Views/Store/CategoryPickerView.swift
- sha256:28ef5634d81b41dadaa8af163a47970010e28e67e1047f9aeb53d8d5679bac0e  SmartCart/Views/Store/EditItemView.swift
- sha256:9cfe6fcefd869b2a28e6ee8bf8a0d4e7e13f507ae70df810befae64b89d86107  SmartCart/Views/Store/StationAdoptionSection.swift
- sha256:2917230fca9ee9c586a16b82798b7dba58a3dabc8c0d0d62d47349b9e2e357a9  SmartCart/Views/Store/StationSetupView.swift
- sha256:b2ac20eb3954128863e8fe8008f2ffaad9e1fe79da4f90f6397bd93311dcce48  SmartCart/Views/Store/StoreDetailView.swift

## Prüfbasis

- base: abb293bdca6edc45ec02f2e55dbaea68a8c982df
- blob:43cc758628d4fd479ee26dbe397015de505a16ac  SmartCart/Models/StoreCategories.swift
- blob:55dc454ac283b70bbe8bd1637f76a3d20cff9049  SmartCart/Models/StoreTemplates.swift
- blob:0750ed3db449a94fc2b1e19f46469da0f233f105  SmartCart/SmartCartApp.swift
- blob:1a181580250d034d80989e61a591778ebfd9ec58  SmartCart/Views/Store/AddItemView.swift
- blob:9e713d12aaae335a0499e6e2ec77e289d302335a  SmartCart/Views/Store/CategoryPickerView.swift
- blob:3e49bc71b289b4596af354856482c33e09416004  SmartCart/Views/Store/EditItemView.swift
- blob:14d3de80e53c60f106961dc97aff713361f70927  SmartCart/Views/Store/StationAdoptionSection.swift
- blob:adb1ab80fb68abbb80400bcdbe5010a0c84ebcad  SmartCart/Views/Store/StationSetupView.swift
- blob:ebccc3838bc46f53b0e4db0950dded825d58072e  SmartCart/Views/Store/StoreDetailView.swift
