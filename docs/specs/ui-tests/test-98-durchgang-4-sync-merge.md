---
entity_id: test-98-durchgang-4-sync-merge
type: test
created: 2026-10-05
updated: 2026-10-05
status: draft
workflow: test-98-durchgang-4-sync
tags: [test, unit-test, sync, shared-stores, merge, cloudkit, mutation-probe]
---

# Merge-Logik geteilter Läden ohne CloudKit prüfen (Issue #98, Durchgang 4)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Wenn zwei Personen einen Laden teilen, entscheidet reine Merge-Logik, was auf beiden Geräten steht:
wer gewinnt bei zwei Änderungen am selben Artikel, ob ein gelöschter Artikel wiederkommt, ob
Mitglieder, eigene Kategorien, gemerkte Zuordnungen und Preise zusammenfinden. Diese Logik hat
heute **keinen einzigen Test**. Sie sitzt an zwei Stellen:

1. `SyncCoordinator.apply(items:members:deletedIDs:prices:priceDates:priceUnits:categories:assignments:modifiedAt:to:)`
   (`SmartCart/Services/SyncCoordinator.swift`, `@MainActor`) wendet einen Remote-Stand auf einen lokalen
   `Store` an und rückt den Sync-Wasserstand erst nach erfolgreichem `context.save()` vor.
2. `SharedStoreService.mergeIntoRecord(_:store:code:isNewRecord:)` und
   `merge(local:remote:tombstones:)` (Actor in `SmartCart/Services/SharedStoreService.swift`) bauen beim
   Hochladen den Merge aus lokalem Stand und dem zuvor geholten Server-Record. Beide sind `private`.

Beide lassen sich ohne Netz prüfen: `apply` braucht nur einen In-Memory-`ModelContext`;
`mergeIntoRecord` berührt `db` nie, nur ein `CKRecord`, und der lässt sich per
`CKRecord(recordType:recordID:)` ohne Server erzeugen.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03), die
Scoping-Limits gelten je Durchgang. Dies ist Durchgang 4 = Punkt 4 (geteilte Läden/Sync) plus drei
Nachschärfen aus der Prüfung von Durchgang 3. Die Punkte 5 (Tagesmitteilung), 6 (Siri/Widget) und
7 (Paywall/Onboarding) bleiben Durchgang 5.

Kein Produktverhalten ändert sich. Produktcode ändert sich nur um zwei Schlüsselwörter
(`private` entfällt bei `merge` und `mergeIntoRecord`). Kein Modell beteiligt, alles deterministisch
(Regel vor Modell: es gibt hier nichts, was ein Sprachmodell lösen könnte).

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Echtes Teilen mit einem zweiten
iCloud-Konto bleibt ungeprüft, ebenso Einladung/Annahme, stille Push-Benachrichtigung, serverseitige
Rechte der `publicCloudDatabase` und die Wiederholung nach `serverRecordChanged` in
`syncToCloud`. Geprüft wird nur, was lokal vor dem Server passiert.

## Source

- **Neu:** `RestockTests/SharedStoreMergeTests.swift` — Unit-Tests für `apply` und den Push-Merge
  (~170 LoC).
- **Geändert:** `SmartCart/Services/SharedStoreService.swift` — nur `private func mergeIntoRecord` →
  `func mergeIntoRecord` und `private func merge(local:remote:tombstones:)` → `func merge(...)`
  (Zeilen 83 und 134). Sonst keine Änderung (`pruneDeletions`, `persistDeletions`, `syncToCloud`,
  Encode/Decode bleiben).
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — `SharedStoreMergeTests.swift` in
  `PBXBuildFile`, `PBXFileReference`, `PBXGroup` (RestockTests), `PBXSourcesBuildPhase` des
  Unit-Test-Targets.
- **Geändert:** `RestockUITests/QuickAddAssignmentUITests.swift` — Nachschärfen 1 und 2 (~20 LoC).
- **Geändert (nur temporär, Nachweis):** `SmartCart/SmartCartApp.swift` und/oder
  `RestockUITests/DataResetUITests.swift` — Nachschärfen 3; die Änderung wird nach dem Nachweis
  vollständig zurückgenommen und steht nicht im Endstand des Diffs (die Datei zählt für den Umfang
  mit, weil sie angefasst wird).
- **Nicht geändert:** `SyncCoordinator.apply` (Logik und Sichtbarkeit), `StoreCategories`,
  `LearnedPriceSync`, `Store`, `ShoppingItem`, `syncToCloud`, `SharedModelContainer`.

Geschätzter Umfang: 6 Dateien (Testdatei, `SharedStoreService.swift`, `project.pbxproj`,
`QuickAddAssignmentUITests.swift`, `SmartCartApp.swift`, `DataResetUITests.swift`; die letzten beiden
nur im Nachweis berührt), ca. +230 / −2 LoC. Das liegt über dem Dateilimit (4–5) und nahe am
Zeilenlimit (±250). **Im PO-Briefing offenzulegen**; Henning hat Splitten für #98 abgelehnt, die
Limits gelten je Durchgang (Memory „#98 ein Ticket, mehrere Durchgänge“). Wird der Zeilenumfang
überschritten, Rückmeldung mit Schätzung; Kandidat zum Verschieben: die Mengen-Einengung aus
Nachschärfen 2 ist dann nicht verschiebbar, wohl aber ein Teil der Randfälle bei Preisen (schon in
`LearnedPriceSyncTests` einzeln geprüft).

## Verhalten

Keine Verhaltensänderung. Festgehalten wird das **Ist-Verhalten**; die Tests laufen deshalb von
Anfang an grün. Der Nachweis, dass sie nicht leer laufen, sind die Mutationsproben (AC-12).

### Testaufbau

- In-Memory-Container wie `ReplenishmentPackageATests.makeInMemoryContext()`:
  `Schema(versionedSchema: SchemaV1.self)`, `ModelConfiguration(schema:isStoredInMemoryOnly: true,
  cloudKitDatabase: .none)`, `ModelContext(container)`. Der Container wird in einer Instanzeigenschaft
  gehalten, damit er den Test überlebt.
- `SyncCoordinator.shared.modelContext` wird je Test gesetzt (Rückfall `store.modelContext` genügt,
  wenn der Store im Kontext eingefügt ist). Testklasse `@MainActor`.
- Je Test eine **eindeutige `shareID`** (`"UT-" + UUID().uuidString`), gesetzt am `Store`. `tearDown()`
  entfernt aus `UserDefaults.standard` die Schlüssel `lastSync_<shareID>` und
  `deletedTombstones_<shareID>` aller im Test benutzten IDs.
- `SharedItemData` wird per Memberwise-Initialisierer gebaut (Felder `id, name, category,
  categoryManuallySet, quantity, quantityAmount, unit, isCompleted, isUrgent, note, assignedTo,
  addedBy, completedBy, lastModified, hasPhoto`), über eine Testhilfe mit Standardwerten.
- Push-Merge: `CKRecord(recordType: "SharedStore", recordID: CKRecord.ID(recordName: shareID))`;
  Felder `itemsJSON`, `membersJSON`, `deletedJSON`, `pricesJSON`, `categoriesJSON`,
  `assignmentsJSON`, `ownerDevice` werden mit `SharedStoreService.shared.encodeItems/encodeMembers/…`
  vorbefüllt und nach `mergeIntoRecord` mit `decodeItems/decodeMembers/…` gelesen. Der Aufruf ist
  `await SharedStoreService.shared.mergeIntoRecord(record, store: store, code: shareID, isNewRecord: …)`
  (Actor, daher `await`).

### Teil A: `SyncCoordinator.apply`

- **S1 Mitglieder:** Namen aus `members` landen per `addMember` im Laden; bereits vorhandene Namen
  entstehen nicht doppelt.
- **S2 Kategorien:** `categories` wird über `StoreCategories.merge` eingearbeitet; ein neuerer
  Remote-Eintrag gewinnt, ein neuerer lokaler bleibt (die Merge-Regel selbst ist in
  `StoreCategoriesTests` geprüft, hier nur die Einbindung in `apply`).
- **S3 Zuordnungen:** `assignments` wie S2 über `StoreCategories.mergeAssignments`.
- **S4 Preise:** `prices`/`priceDates`/`priceUnits` landen über `LearnedPriceSync.apply` in
  `store.learnedPrices`/`learnedPriceUnits`; Last-write-wins pro Schlüssel (Regel selbst in
  `LearnedPriceSyncTests`, hier die Einbindung).
- **S5 Löschvermerke:** Ein lokaler Artikel, dessen `id` in `deletedIDs` steht, ist nach `apply`
  weg. Ein lokaler Artikel, der nur **fehlt** im Remote-Stand, bleibt (Löschen nur per Vermerk, nie
  durch Abwesenheit).
- **S6 Last-write-wins pro Artikel:** Remote `lastModified` neuer als lokal: lokale Felder werden
  überschrieben (Name, `isCompleted`, `isUrgent`, Menge, Einheit, Notiz, Kategorie, `assignedTo`,
  `addedBy`, `completedBy`, `lastModified`, `hasPhoto`). Remote älter: lokaler Artikel unverändert.
- **S7 Neuanlage:** Ein Remote-Artikel mit unbekannter `id` wird mit derselben `id` angelegt, mit der
  Kategorie des Absenders (`categoryManuallySet` und `category` aus Remote, nicht aus der lokal
  gemerkten Kategorie) und den Remote-Feldern.
- **S8 Wasserstand:** Nach erfolgreichem `save` mit gesetzter `shareID` und `modifiedAt` steht
  `lastSyncDate(shareID:)` auf `modifiedAt`. Mit `modifiedAt == nil` bleibt er `.distantPast`
  (Push-Fall). Ohne `shareID` am Laden wird nichts geschrieben.
- **S9 Wasserstand nur nach Save:** Der Wasserstand wird gesetzt, **nachdem** `context.save()`
  gelungen ist (im Code Zeilen 300–309: `markSynced` steht innerhalb des `do`-Blocks hinter `save`).
  Nachgewiesen über die Mutationsprobe (AC-12): Verschiebt man `markSynced` vor `save`, muss ein Test
  rot werden, in dem das `save` fehlschlägt. Der fehlschlagende Save wird ohne Produktcodeänderung
  erzeugt, indem `apply` mit einem Laden aufgerufen wird, dessen Kontext einen nicht speicherbaren
  Zustand hat; ist das im Testhost nicht ohne Eingriff zu erzeugen, belegt die Mutationsprobe stattdessen
  die Reihenfolge direkt, indem der Test den Wasserstand **nach einem erfolgreichen `apply` mit
  `modifiedAt`** prüft und die Probe die Anweisung hinter `try context.save()` an den Anfang der
  Funktion stellt (Test „Wasserstand nur nach Save“ prüft dann, dass bei `guard`-Abbruch durch einen
  Laden ohne Kontext der Wasserstand unverändert `.distantPast` bleibt). Die genaue Form legt
  Phase 4 fest; der Nachweis über Mutationsprobe ist verbindlich.

### Teil B: Push-Merge (`mergeIntoRecord`, `merge`)

- **P1 Pull-vor-Push:** Ein Artikel, der nur im Server-Record steht, ist nach `mergeIntoRecord` im
  Rückgabewert und in `itemsJSON` enthalten (die Gegenseite wird nicht überschrieben); ein Artikel, der
  nur lokal steht, ebenfalls.
- **P2 Last-write-wins:** Derselbe Artikel lokal und remote: der mit dem größeren `lastModified`
  gewinnt, in beiden Richtungen.
- **P3 Tombstones wachsen nur:** `deletedJSON` im Record nach dem Merge ist die Vereinigung aus
  Remote-Vermerken und lokalen (`recordLocalDeletion`) Vermerken; kein Vermerk verschwindet. Ein
  Artikel mit Vermerk (lokal oder remote) fehlt im Ergebnis, auch wenn er auf der anderen Seite noch
  steht.
- **P4 Mitglieder:** Ergebnis = Remote-Mitglieder ∪ `store.members` ∪ eigener Name
  (`UserIdentity.displayName`), ohne leere Namen, sortiert, ohne Doppelte.
- **P5 Besitzername:** `ownerDevice` wird nur bei `isNewRecord == true` auf
  `UserIdentity.displayName` gesetzt; bei `false` bleibt ein vorhandener Wert unverändert.
- **P6 Metadaten und Kategorien/Zuordnungen/Preise:** `storeName`, `storeEmoji`, `storeColorHex`
  werden aus dem Laden geschrieben; Kategorien, Zuordnungen und Preise werden mit dem Server-Stand
  per `StoreCategories.merge`, `StoreCategories.mergeAssignments` und `LearnedPriceSync.merge`
  zusammengeführt und kodiert zurückgeschrieben.
- **P7 Gleichstand (Ist-Verhalten festnageln, kein Fix):** Bei identischem `lastModified` gewinnt im
  Push-Merge der **lokale** Artikel (`existing.lastModified > item.lastModified` ist falsch, also wird
  überschrieben). In `apply` gewinnt bei Gleichstand der **Remote**-Artikel (`>=`). Beide Tests
  tragen im Kommentar, dass das Absicht des Festhaltens ist, nicht der Beschluss, dass es so sein
  soll: Bei identischem Zeitstempel sind die Daten praktisch gleich, es ist kein Produktfehler; wer
  die Regel ändert, macht das bewusst und passt den Test an.

### Teil C: Nachschärfen aus Durchgang 3

1. **Negativprobe „Lidl nicht im Dialog“** in `QuickAddAssignmentUITests`: heute nur gegen
   `app.sheets` geprüft. Zusätzlich gegen `app.buttons` (Knopf mit Label, das „Lidl“ enthält, darf
   im Dialog „Zu welchem Laden?“ nicht existieren; die Ladenkachel „Lidl,“ darunter wird über das
   Dialog-Fenster abgegrenzt, nicht pauschal). Hinweis aus Memory „Emoji-Text bricht
   Accessibility-Label“: Suche per `label CONTAINS`, nicht per exaktem Label.
2. **Mengenzeile eingrenzen** in `testQuantityAndUnitShownInList`: Die Zeile „500 gramm“ wird nicht
   mehr irgendwo auf dem Schirm gesucht, sondern innerhalb der Listenzelle, die „Hackfleisch“
   enthält (`app.cells.containing(.staticText, identifier: "Hackfleisch")`, darin die
   `staticText` „500 gramm“).
3. **Wirksamkeit der Markerdatei-`precondition`** (`SmartCartApp`, DEBUG-Zweig mit
   `-forceContainerFailureForUITests`): Bisher ist nicht gezeigt, dass die `precondition` auslöst,
   wenn `deleteStoreFiles()` eine Fremddatei trifft. Einmaliger Nachweis: Der Löschfilter wird
   temporär so verbreitert, dass er auch `uitest-foreign-marker.txt` trifft (z. B. zusätzlich alle
   `.txt`-Dateien); `DataResetUITests` läuft und muss rot werden (App beendet, keine Kachel/kein
   Alert, Absturzbericht nennt die `precondition`). Danach wird die Änderung vollständig
   zurückgedreht; der Nachweis (Testausgabe und Absturzbericht) wird als Artefakt abgelegt. Kein
   dauerhafter Code, `deleteStoreFiles()` bleibt im Endstand unverändert und `private`.

### Aufräumen

- Unit-Tests: `tearDown()` räumt je benutzter `shareID` die Schlüssel `lastSync_<shareID>` und
  `deletedTombstones_<shareID>` aus `UserDefaults.standard` und setzt
  `SyncCoordinator.shared.modelContext` zurück auf den Ausgangswert.
- UI-Tests (Teil C): bestehende `tearDown()` bleiben; es kommen keine neuen Seeds hinzu.

## Acceptance Criteria

- AC-1: `apply` übernimmt Mitglieder: Namen aus `members` stehen nach dem Aufruf in `store.members`,
  Doppelte entstehen nicht (Test S1).
- AC-2: `apply` arbeitet Kategorien, Zuordnungen und Preise über `StoreCategories.merge`,
  `StoreCategories.mergeAssignments` und `LearnedPriceSync.apply` ein: neuerer Stand gewinnt je
  Schlüssel, ein neuerer lokaler Eintrag bleibt (Tests S2–S4).
- AC-3: `apply` löscht nur per Löschvermerk: Artikel in `deletedIDs` sind weg, ein lokaler Artikel, der
  im Remote-Stand bloß fehlt, bleibt (Test S5).
- AC-4: `apply` entscheidet pro Artikel nach `lastModified`: neuerer Remote-Stand überschreibt alle
  synchronisierten Felder, ein älterer lässt den lokalen Artikel unverändert (Test S6).
- AC-5: `apply` legt unbekannte Remote-Artikel mit derselben `id` und der Absender-Kategorie neu an
  (`category`, `categoryManuallySet` aus Remote, auch wenn lokal eine eigene Kategorie für den Namen
  gemerkt ist) (Test S7).
- AC-6: `apply` rückt `lastSyncDate(shareID:)` nur nach erfolgreichem `save` und nur mit `shareID` und
  `modifiedAt` vor; mit `modifiedAt == nil` bleibt der Wasserstand `.distantPast` (Tests S8, S9).
- AC-7: Der Push-Merge holt zuerst den Server-Stand und führt ihn mit dem lokalen zusammen: Artikel,
  die nur auf einer Seite stehen, bleiben erhalten; bei beiden Seiten gewinnt der größere
  `lastModified` in beiden Richtungen (Tests P1, P2).
- AC-8: Löschvermerke wachsen nur: `deletedJSON` ist nach dem Merge Remote ∪ lokal; ein Artikel mit
  Vermerk fehlt im Ergebnis, auch wenn er auf der anderen Seite noch steht (Test P3).
- AC-9: Mitglieder im Push-Merge sind Remote ∪ `store.members` ∪ eigener Name, ohne leere Namen und
  Doppelte, sortiert (Test P4).
- AC-10: `ownerDevice` wird nur bei neuem Record gesetzt und bei bestehendem Record nicht
  überschrieben; Laden-Metadaten, Kategorien, Zuordnungen und Preise werden in den Record
  zurückgeschrieben (Tests P5, P6).
- AC-11: Gleichstand bei `lastModified` ist als Ist-Verhalten festgehalten: Push-Merge lässt den
  lokalen Artikel gewinnen (`>`), `apply` den Remote-Artikel (`>=`); keine Produktänderung, Kommentar
  im Test benennt den Unterschied (Test P7 und Gegenstück in Teil A).
- AC-12: Mutationsproben, je einmal: (a) Last-write-wins-Vergleich in `apply` oder `merge` kippen,
  (b) Tombstone-Löschung in `apply` (`context.delete(item)` für `deletedIDs`) entfernen,
  (c) `markSynced` in `apply` vor `try context.save()` verschieben. Jede Probe macht mindestens einen
  Test rot; danach wird die Änderung zurückgedreht und die Suite ist wieder grün. Der
  Nachweis (rote Testnamen, Ausgabe) wird als Artefakt abgelegt; die Mutation steht nie im Endstand.
- AC-13: Aufräumen: Jeder Test benutzt eine eigene `shareID`; nach dem Lauf stehen keine
  `lastSync_*`- und `deletedTombstones_*`-Schlüssel dieser IDs in `UserDefaults.standard`
  (Nachweis über einen Test oder `tearDown`-Prüfung); die Suite ist in beliebiger Reihenfolge und im
  gemeinsamen Lauf mit den Bestandstests grün.
- AC-14: Nachschärfen 1: Der Test prüft, dass im Dialog „Zu welchem Laden?“ kein Knopf mit „Lidl“
  existiert, und zwar gegen `app.buttons` im Dialog, nicht nur gegen `app.sheets`; die Probe ist
  wirksam (Gegenprobe: derselbe Zugriff findet „dm“).
- AC-15: Nachschärfen 2: `testQuantityAndUnitShownInList` sucht „500 gramm“ innerhalb der
  Listenzelle von „Hackfleisch“ und nicht mehr schirmweit; eine andere Zeile mit „500 gramm“ könnte
  den Test nicht grün machen.
- AC-16: Nachschärfen 3: Mit verbreitertem Löschfilter wird `DataResetUITests` nachweislich rot
  (die `precondition` löst aus, der Absturzbericht nennt sie); die Änderung ist danach vollständig
  zurückgenommen, `deleteStoreFiles()` und `SmartCartApp.swift` stehen im Endstand unverändert zu
  `origin/main`; Nachweis liegt als Artefakt vor.
- AC-17: Produktcode-Diff gegen `origin/main` besteht ausschließlich aus dem Entfernen von `private` bei
  `merge` und `mergeIntoRecord` in `SharedStoreService.swift` (2 Zeilen); `syncToCloud`,
  `pruneDeletions`, `SyncCoordinator.apply` und alle Modelle bleiben unverändert. Nachweis per
  `git diff --stat`/Diff-Suche.
- AC-18: Umfang: 6 Dateien, ca. +230 / −2 LoC, im PO-Briefing offengelegt (Überschreitung des
  Dateilimits wegen der drei Nachschärfen; Entscheidung des PO, ein Durchgang).
- AC-19: Offene Grenze ist in Spec, Testdatei-Kommentar und Ticketkommentar benannt: Echtes Teilen mit
  zweitem iCloud-Konto, Einladung/Annahme, Push-Benachrichtigung, serverseitige Rechte der
  `publicCloudDatabase` und die Wiederholung nach `serverRecordChanged` in `syncToCloud` sind nicht
  automatisiert geprüft; Begründung: zwei angemeldete iCloud-Konten auf echten Geräten nötig, Simulator
  und CI haben das nicht.

## Tests

| # | Testfall | Datei | Art | Prüft |
|---|----------|-------|-----|-------|
| T1 | `testApplyAddsMembersWithoutDuplicates` (S1) | `SharedStoreMergeTests` | Unit | AC-1 |
| T2 | `testApplyMergesCategoriesAssignmentsAndPrices` (S2–S4, je neuerer Stand gewinnt, lokal neuer bleibt) | `SharedStoreMergeTests` | Unit | AC-2 |
| T3 | `testApplyDeletesOnlyTombstonedItems` (S5, Abwesenheit löscht nicht) | `SharedStoreMergeTests` | Unit | AC-3 |
| T4 | `testApplyLastWriteWinsPerItem` (S6, neuer Remote überschreibt Felder; alter Remote ändert nichts) | `SharedStoreMergeTests` | Unit | AC-4 |
| T5 | `testApplyCreatesUnknownRemoteItemWithSenderCategory` (S7) | `SharedStoreMergeTests` | Unit | AC-5 |
| T6 | `testApplyAdvancesWatermarkOnlyAfterSaveAndWithModifiedAt` (S8/S9, inkl. `nil`-Fall und Laden ohne `shareID`) | `SharedStoreMergeTests` | Unit | AC-6 |
| T7 | `testPushMergeKeepsItemsFromBothSides` (P1) | `SharedStoreMergeTests` | Unit | AC-7 |
| T8 | `testPushMergeLastWriteWinsBothDirections` (P2) | `SharedStoreMergeTests` | Unit | AC-7 |
| T9 | `testPushMergeTombstonesOnlyGrowAndRemoveItems` (P3) | `SharedStoreMergeTests` | Unit | AC-8 |
| T10 | `testPushMergeMembersIncludeOwnNameSortedUnique` (P4) | `SharedStoreMergeTests` | Unit | AC-9 |
| T11 | `testPushMergeOwnerOnlyForNewRecord` (P5) | `SharedStoreMergeTests` | Unit | AC-10 |
| T12 | `testPushMergeWritesMetadataCategoriesAssignmentsPrices` (P6) | `SharedStoreMergeTests` | Unit | AC-10 |
| T13 | `testTieOnLastModifiedPushLocalWinsApplyRemoteWins` (P7, Ist-Verhalten) | `SharedStoreMergeTests` | Unit | AC-11 |
| T14 | `testTearDownLeavesNoSyncKeys` (Aufräumprüfung, eindeutige `shareID`) | `SharedStoreMergeTests` | Unit | AC-13 |
| T15 | Mutationsprobe (a) LWW-Vergleich kippen → rot → zurück | — | Probe | AC-12 |
| T16 | Mutationsprobe (b) Tombstone-Löschung entfernen → rot → zurück | — | Probe | AC-12 |
| T17 | Mutationsprobe (c) `markSynced` vor `save` → rot → zurück | — | Probe | AC-12 |
| T18 | `testChangeStoreDialogOffersOnlyOtherStore` erweitert: `app.buttons`-Negativprobe „Lidl“ plus Gegenprobe „dm“ (Nachschärfen 1) | `QuickAddAssignmentUITests` | UI | AC-14 |
| T19 | `testQuantityAndUnitShownInList` auf Zelle „Hackfleisch“ eingegrenzt (Nachschärfen 2) | `QuickAddAssignmentUITests` | UI | AC-15 |
| T20 | Einmaliger Nachweis `precondition` mit verbreitertem Filter → `DataResetUITests` rot → Rücknahme (Nachschärfen 3) | `DataResetUITests` | Nachweis | AC-16 |
| T21 | Diff-Nachweis: Produktcode nur 2 Schlüsselwörter, Dateizahl, LoC (Scope-Gate, `git diff --stat` gegen `origin/main`) | — | Diff | AC-17, 18 |
| T22 | Bestandssuiten im gemeinsamen Lauf (Unit + UI), drei Wiederholungen der geänderten UI-Tests | alle | Unit+UI | AC-13, 14, 15 |
| T23 | Durchlauf im Simulator, Artefakt durch Werkzeug | — | durch Werkzeug | AC-16, 19 |

TDD: Das Verhalten besteht schon, die Unit-Tests sind von Anfang an grün. RED entsteht hier **nur**
über die Mutationsproben (AC-12): Erst nach erfolgreicher Probe zählt der jeweilige Test als
wirksam. Testfälle werden vor der Sichtbarkeitsänderung geschrieben; sie kompilieren erst nach dem
Entfernen von `private` (Compilerfehler „inaccessible due to private“ ist das RED für Teil B). Teil C
Nachschärfen 1 und 2 sind RED nachweisbar, indem die Eingrenzung kurz auf ein falsches Ziel gelenkt wird
(Test wird rot), dann korrigiert.

Randbedingungen: Simulator nie parallel, eigenes Testgerät Restock-Validate; „Executed 0 tests“ ist
kein Grün (Testzahl prüfen); Unit-Suite läuft im gemeinsamen Lauf (Memory „Testrunner-Hänger im
gemeinsamen Lauf“, Issue #63: bei Start-Hänger Aufräum-Rezept, nicht Test ändern).

## Risiken

- **`SharedStoreService.shared` im Testhost:** Der Actor hält `CKContainer(identifier:)` als
  Instanzeigenschaft. Ob das Erzeugen im Unit-Test-Host ohne Absturz klappt, ist **nicht belegt**
  und wird in Phase 4 zuerst geprüft (kleinster Probe-Test). `apply` selbst ruft
  `SharedStoreService.shared.markSynced` und braucht die Instanz ohnehin. Wenn das Erzeugen
  scheitert, wird Alternative B (Merge als reine Funktionen auslagern) gewählt und die Spec neu
  bewertet (Umfang steigt).
- **Globaler Zustand `UserDefaults.standard`:** `lastSync_*`/`deletedTombstones_*` sind global.
  Schutz: eindeutige `shareID` je Test, `tearDown` räumt auf (AC-13). Ohne das würden Läufe in
  anderer Reihenfolge einander färben (Memory „UI-Test-Seeds müssen aufräumen“ analog).
- **`UserIdentity.displayName` und `WidgetCenter`:** `mergeIntoRecord` schreibt den eigenen Namen,
  `apply` ruft `WidgetCenter.shared.reloadAllTimelines()`. Beides im Testhost harmlos erwartet; bei
  Fehlschlag zuerst hier suchen. Tests rechnen mit `UserIdentity.displayName` statt mit festem Namen.
- **Fehlschlagender Save nicht ohne Eingriff erzeugbar (S9):** Siehe Verhalten; die Mutationsprobe
  (c) ist der verbindliche Nachweis. Reicht ein Test allein nicht, bleibt die Lücke in „Offene
  Punkte“ benannt.
- **Gleichstand-Unterschied (`>` vs. `>=`):** Wird als Ist-Verhalten festgenagelt, nicht
  korrigiert. Risiko: Der Test macht eine künftige, bewusste Änderung rot. Gewollt; Kommentar
  im Test erklärt es.
- **Sichtbarkeitsänderung:** `merge`/`mergeIntoRecord` werden `internal`. Keine neue Außenwirkung (App-
  Target, kein öffentliches Modul); Aufrufer bleiben dieselben. Risiko minimal.
- **Mutationsproben hinterlassen Spuren:** Eine vergessene Rücknahme wäre ein Produktfehler.
  Schutz: Probe in einer Wegwerf-Kopie oder mit anschließendem Diff-Nachweis (AC-17) gegen
  `origin/main`.
- **Nachschärfen 3 löst Absturz im Testsimulator aus:** Nur im Test-Simulator, nur mit dem
  DEBUG-Argument; das Löschen betrifft Testdaten. Nach der Rücknahme einmal den normalen
  `DataResetUITests`-Lauf grün zeigen.
- **Umfang:** 6 Dateien über dem Dateilimit, Zeilen nahe am Limit; siehe Source. Kandidat zum Kürzen
  vor Überschreiten: Randfälle in P6.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | `private` → `internal` bei `merge` und `mergeIntoRecord`; Tests mit echtem `CKRecord` ohne Netz plus `apply` mit In-Memory-Container | kleinster Eingriff (2 Schlüsselwörter), prüft den echten Pfad inklusive Encode/Decode und Schreiben ins Record |
| B | Merge als reine `static`-Funktionen/Struct (ohne `CKRecord`) auslagern | sauberer getrennt, aber Umbau von `SharedStoreService`, prüft das Schreiben ins Record nicht mit; **Rückfall**, falls `SharedStoreService.shared` im Testhost nicht erzeugbar ist |
| C | `CKDatabase` per Protokoll einspritzen und `syncToCloud` komplett testen | würde auch die Wiederholung bei `serverRecordChanged` prüfen, braucht aber einen großen Umbau und einen Mock von `CKError.serverRecord`; Nutzen gegenüber Risiko schlecht, bleibt offene Grenze |
| D | Nur `apply` testen, Push-Weg lassen | spart die Sichtbarkeitsänderung, lässt aber die Hälfte der Merge-Logik (Tombstones wachsen, Besitzername, Mitglieder, Pull-vor-Push) ungeprüft; verworfen |

Weitere Entscheidungen: Nachschärfen aus Durchgang 3 werden nicht abgetrennt, weil Henning Splitten
für #98 abgelehnt hat und sie dasselbe Ziel haben („Durchgang 3 und 4 beweisbar zu Ende bringen“);
dafür wird das 6-Dateien-Ergebnis offen ausgewiesen. Kein Modell beteiligt: Merge ist Regel
(`lastModified`, Mengenoperationen), die Nulllinie ist hier die Regel selbst. Gekippte frühere
Entscheidung: keine ADR; nur die Arbeitsannahme „Merge ist ohne CloudKit nicht testbar“.

**Entscheidung:** Weg A plus die drei Nachschärfen, ein Durchgang.

## Offene Punkte

- PO (im Briefing): 6 Dateien / ca. +230 LoC als ein Durchgang freigeben. Empfehlung: ja.
- Phase 4: Ist `SharedStoreService.shared` im Testhost ohne Absturz erzeugbar? Wenn nein, Wechsel auf
  Alternative B und neue Umfangsschätzung vor weiterer Arbeit.
- Phase 4: Form des Tests für S9 (fehlschlagender `save` ist ohne Produktcodeänderung evtl. nicht
  erzeugbar; dann trägt die Mutationsprobe (c) den Nachweis).
- Offene Grenze (jede Zusage): Echtes Teilen mit zweitem iCloud-Konto, Einladung/Annahme, stille
  Push-Benachrichtigung, serverseitige Rechte und die Wiederholung nach `serverRecordChanged` in
  `syncToCloud` bleiben ungeprüft. Begründung fürs Ticket: braucht zwei angemeldete iCloud-Konten auf
  echten Geräten; Simulator und CI haben das nicht.
- Nach Abschluss: Kommentar in #98 mit Durchgang 4 und Verweis auf Durchgang 5 (Punkte 5–7);
  Verweis auf die neue Testdatei in `CLAUDE.md` (Abschnitt Build/Tests), falls das Limit es erlaubt,
  sonst Folgedurchgang.
