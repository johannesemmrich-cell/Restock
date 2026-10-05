# Context: #98 Durchgang 4 — Geteilte Läden / Sync (Punkt 4)

## Request Summary
Die Merge-Logik beim Teilen von Läden soll ohne CloudKit automatisch geprüft werden. Echtes Teilen mit zweitem iCloud-Konto bleibt nicht automatisierbar und wird mit Begründung im Ticket festgehalten. Dazu das Nachschärfen aus der Prüfung von Durchgang 3. Vorarbeit: `docs/context/test-98-durchgang-3-schnelleingabe-sync.md`. Die Durchgänge 1–3 sind gemergt (PR #104, #106, #107). Die Punkte (5) Tagesmitteilung, (6) Siri/Widget und (7) Paywall/Onboarding stehen laut erstem Ticketkommentar noch aus (Durchgang 5, nicht Teil hier).

## Stand heute (Ist, am Code geprüft)
Zwei getrennte Merge-Stellen, beide ohne Test:

1. **`SyncCoordinator.apply(...)`** (`SmartCart/Services/SyncCoordinator.swift:229`), `@MainActor`-Klasse, internal. Reine Merge-Logik auf `Store` + `ModelContext`:
   Mitglieder (`addMember`), eigene Kategorien (`StoreCategories.merge`, #85), Zuordnungen (`mergeAssignments`, #94), Preise (`LearnedPriceSync.apply`),
   Löschvermerke (`deletedIDs` → `context.delete`), Last-write-wins pro Artikel (`remote.lastModified >= local.lastModified`), Neuanlage unbekannter Remote-Artikel,
   danach `save` und nur dann `markSynced` (nur wenn `shareID` und `modifiedAt` gesetzt). Der Kontext ist injizierbar (`modelContext ?? store.modelContext`).
   `markSynced` schreibt in `UserDefaults.standard` (`lastSync_<shareID>`), kein CloudKit-Zugriff.
2. **`SharedStoreService.mergeIntoRecord` / `merge(local:remote:tombstones:)`** (`SharedStoreService.swift:83`/`:134`), beide `private` im Actor.
   Der Actor hält `CKContainer(identifier:)` als Instanzeigenschaft; `CKRecord(recordType:recordID:)` lässt sich ohne Netz erzeugen. Der Push-Weg (Pull-vor-Push-Merge, Last-write-wins, Tombstones wachsen nur, Mitglieder inkl. eigener Name, Besitzername nur bei neuem Record) ist damit ohne Server prüfbar, sobald die Funktionen von außen erreichbar sind.
   `pendingDeletions`/`recordLocalDeletion`/`lastSyncDate` sind schon `internal` und laufen über `UserDefaults.standard` (Schlüssel je `shareID` → Test mit eindeutiger `shareID`, Aufräumen).

## Related Files
| Datei | Relevanz |
|-------|----------|
| `SmartCart/Services/SyncCoordinator.swift` | `apply` — Hauptprüfling |
| `SmartCart/Services/SharedStoreService.swift` | `mergeIntoRecord`, `merge` (privat), `encode/decode*`, Tombstones, `markSynced` |
| `SmartCart/Models/StoreCategories.swift` | `merge`, `mergeAssignments` (eigene Tests in `StoreCategoriesTests` — hier nur Einbindung prüfen) |
| `SmartCart/Models/Store.swift`, `ShoppingItem.swift` | Mitglieder, Preise, `lastModified`, Init mit gemerkter Kategorie |
| `RestockTests/LearnedPriceSyncTests.swift` | Vorbild + Abgrenzung (Preis-Merge selbst schon getestet) |
| `RestockTests/ReplenishmentPackageATests.swift:145` | Vorbild In-Memory-`ModelContainer` mit `cloudKitDatabase: .none` |
| `RestockTests/SharedItemDataPhotoRegressionTests.swift` | nur Encode/Decode der Foto-Flags |
| `RestockUITests/QuickAddAssignmentUITests.swift`, `DataResetUITests.swift`, `SmartCart/SmartCartApp.swift` | Nachschärfen aus Durchgang 3 |

## Existing Patterns
- Unit-Tests mit `ModelConfiguration(schema:isStoredInMemoryOnly: true, cloudKitDatabase: .none)`.
- Neue Swift-Datei = vier Stellen in `project.pbxproj`.
- Sichtbarkeit nur minimal ändern (kein Drive-by-Refactoring); `private` → `internal` ist die kleinste Änderung. Alternative: reinen Merge als `static`-Funktion/Struct auslagern (größerer Eingriff).
- Regel vor Modell: alles hier deterministisch, kein Modell beteiligt.

## Dependencies
- Upstream: SwiftData, CloudKit (nur Typ `CKRecord`, kein Netz), `UserDefaults.standard`, `UserIdentity.displayName`, `WidgetCenter` (in `apply` aufgerufen, im Test harmlos).
- Downstream: Ladenlisten (`StoreDetailView`), Widget, Periodischer Pull (`pullAllSharedStores`).

## Nachschärfen aus Durchgang 3 (niedrige Priorität, vom PO mitgegeben)
1. `QuickAddAssignmentUITests`: Negativprobe „Lidl nicht im Dialog“ auch gegen `app.buttons` prüfen (heute nur `app.sheets`).
2. `testQuantityAndUnitShownInList`: Mengenzeile auf die Zeile von „Hackfleisch“ eingrenzen.
3. `DataResetUITests`/`SmartCartApp`: Wirksamkeit der Markerdatei-`precondition` einmalig mit verbreitertem Filter zeigen (Nachweis, kein dauerhafter Code).

## Nicht automatisierbar (für Ticket zu begründen)
Echtes CloudKit-Teilen mit zweitem iCloud-Konto: Einladung/Annahme, Push-Benachrichtigung und serverseitige Rechte (`serverRecordChanged`-Wiederholung, Zugriff auf `publicCloudDatabase`) brauchen zwei angemeldete iCloud-Konten auf echten Geräten bzw. ein Server-Backend; im Simulator und in der CI gibt es das nicht. Geprüft wird alles, was lokal vor dem Server passiert (Merge, Löschvermerke, Wasserstand). Offene Grenze in jede Zusage.

## Risks & Considerations
- **Scope:** Neue Testdatei(en) (~150–200 LoC) + `SharedStoreService` (2× Sichtbarkeit) + `pbxproj` + drei Nachschärfen-Dateien → 6 Dateien, über dem 4–5-Dateien-Limit. In `/20-analyse` schneiden: Nachschärfen (3 Kleinstkorrekturen) abtrennen oder PO-Freigabe des Umfangs einholen. Schätzung großzügig ansetzen (Memory „Durchgang 3 Umfang akzeptiert“).
- `UserDefaults.standard` wird global verändert: Tests nutzen eindeutige `shareID` je Test und räumen `lastSync_*`/`deletedTombstones_*` in `tearDown` ab.
- `apply` ruft `WidgetCenter.shared.reloadAllTimelines()`; im Unit-Test-Host unproblematisch, aber bei Fehlschlag zuerst hier suchen.
- Unit-Tests laufen in der Testhost-App mit Entitlements; `CKContainer(identifier:)` darf erzeugt, aber nicht angesprochen werden. Das wird in Phase 4 belegt, nicht vorausgesetzt.
- Mutationsproben (wie in Durchgang 2): Last-write-wins-Vergleich, Tombstone-Löschung, `markSynced` nach `save` je einmal kippen und zeigen, dass der Test rot wird.

## Analysis

### Type
Feature (Testabdeckung, kein Produktfehler). Kein sichtbares UI betroffen → keine Entwurf-Vorschau nötig.

### Recherche (vor der Analyse, 2026-10-05)
- `CKRecord` lässt sich ohne Netz erzeugen (`CKRecord(recordType:recordID:)`); `CKContainer`/`CKDatabase` sind dagegen nicht frei instanziierbar, daher bauen Fremdlösungen Mock-Frameworks (MockCloudKitFramework) oder spritzen die Datenbank per Protokoll ein. Für uns unnötig: der Merge berührt `db` nie, nur `CKRecord`.
  Quellen: https://swiftpackageregistry.com/ccavnor/MockCloudKitFramework · https://www.hackingwithswift.com/forums/swift/how-to-unit-test-cloudkit-core-data/753
- Offen (Phase 4 belegt, nicht vorausgesetzt): ob `SharedStoreService.shared` (hält `CKContainer(identifier:)` als Instanzeigenschaft) im Unit-Test-Host ohne Absturz erzeugt wird. `apply` ruft `SharedStoreService.shared.markSynced`, also trifft es schon `apply`-Tests.

### Befund am Code
- `SyncCoordinator.apply` (`SyncCoordinator.swift:229`): `shared`-Singleton mit privatem init, aber `modelContext` ist setzbar, und `apply` nimmt `store.modelContext` als Rückfall → In-Memory-Container reicht, keine Codeänderung.
- `SharedStoreService.mergeIntoRecord` (`:83`) und `merge` (`:134`) sind `private`. `merge` nutzt keinen Actor-Zustand.
- **Auffällig (kein Fix, nur festnageln):** Gleichstand bei `lastModified` wird unterschiedlich entschieden — Push-Merge `>` (lokal gewinnt), `apply` `>=` (remote gewinnt). Bei identischem Zeitstempel sind die Daten praktisch gleich, daher kein Produktfehler; der Test hält das Ist-Verhalten fest, damit eine Änderung bewusst geschieht.

### Alternativen (Regel „in Alternativen denken“)
| | Weg | Urteil |
|---|---|---|
| **A (empfohlen)** | `private` → `internal` bei `merge` und `mergeIntoRecord`; Tests mit echtem `CKRecord` ohne Netz | kleinster Eingriff (2 Wörter), prüft den echten Pfad inkl. Encode/Decode |
| B | Merge als reine `static`-Funktionen/Struct auslagern (ohne `CKRecord`) | sauberer, aber Umbau von `SharedStoreService`, kippt kaum eine Entscheidung; prüft das Schreiben ins Record nicht mit |
| C | `CKDatabase` per Protokoll einspritzen, `syncToCloud` komplett testen | prüft auch Wiederholung bei `serverRecordChanged`, aber großer Umbau + Mock von `CKError.serverRecord`; Nutzen gegenüber Risiko schlecht |
| D | Nur `apply` testen, Push-Weg lassen | spart eine Sichtbarkeitsänderung, lässt aber die Hälfte der Merge-Logik (Tombstones wachsen, Besitzername, Mitglieder) ungeprüft |
Kein Modell beteiligt — alles deterministisch. Eine frühere ADR wird nicht gekippt; „nicht testbar ohne CloudKit“ war nur Arbeitsstand.

### Affected Files
| Datei | Change | Beschreibung |
|---|---|---|
| `RestockTests/SharedStoreMergeTests.swift` | CREATE | `apply` (Mitglieder, Kategorien, Zuordnungen, Preise, Löschvermerke, LWW, Neuanlage, `markSynced` nur nach Save) + Push-Merge (Pull-vor-Push, Tombstones wachsen, Mitglieder inkl. eigener Name, Besitzer nur bei neuem Record) |
| `SmartCart/Services/SharedStoreService.swift` | MODIFY | 2× `private` entfernen |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Testdatei registrieren (4 Stellen) |
| `RestockUITests/QuickAddAssignmentUITests.swift` | MODIFY | Nachschärfen 1 + 2 (`app.buttons`-Negativprobe, Mengenzeile auf „Hackfleisch“ eingrenzen) |
| `SmartCart/SmartCartApp.swift` / `RestockUITests/DataResetUITests.swift` | MODIFY (temporär) | Nachschärfen 3: Wirksamkeit der Markerdatei-`precondition` einmalig zeigen; Nachweis, kein dauerhafter Code |

### Scope Assessment
- Dateien: 6 (Limit 4–5) — Überschreitung durch das Nachschärfen.
- Geschätzt: +230/−2 LoC (Merge-Tests ~170, Nachschärfen ~40, Rest ~20); großzügig, da UI-Hilfsfunktionen im Durchgang 3 mehr kosteten als geschätzt.
- Risiko: **LOW** — Produktcode ändert sich nur um zwei Sichtbarkeits-Schlüsselwörter.
- Umfang-Empfehlung: ein Durchgang (Henning lehnt Splitten ab, Limits gelten je Durchgang; Memory „#98 ein Ticket, mehrere Durchgänge“). Dateizahl 6 ist im PO-Briefing offenzulegen.

### Technical Approach
1. Testdatei mit In-Memory-`ModelContainer` (`cloudKitDatabase: .none`, Vorbild `ReplenishmentPackageATests.swift:145`); je Test eindeutige `shareID`, `tearDown` räumt `lastSync_*` und Tombstone-Schlüssel in `UserDefaults.standard`.
2. `apply`-Tests über `SyncCoordinator.shared` mit gesetztem `modelContext`.
3. Push-Merge-Tests: `CKRecord(recordType: "SharedStore", recordID:)` erzeugen, Record vorbefüllen, `mergeIntoRecord` aufrufen, Record-Felder dekodieren und prüfen.
4. Mutationsproben (Durchgang-2-Muster): LWW-Vergleich, Tombstone-Löschung, `markSynced`-nach-`save` je einmal kippen → Test rot, zurückdrehen.
5. Nachschärfen aus Durchgang 3 als zweiter Teil derselben Definition of Done.

### Dependencies
SwiftData, CloudKit (nur Typ `CKRecord`), `UserDefaults.standard`, `UserIdentity.displayName`, `WidgetCenter` (in `apply`, im Testhost harmlos). Reihenfolge: Sichtbarkeit → Tests (RED gibt es hier nur über Mutationsproben, weil es sich um bestehendes Verhalten handelt) → Nachschärfen.

### Nicht automatisierbar (Begründung fürs Ticket)
Echtes Teilen mit zweitem iCloud-Konto: Einladung/Annahme, stille Push-Benachrichtigung, serverseitige Rechte der `publicCloudDatabase` und der `serverRecordChanged`-Wettlauf zweier Geräte brauchen zwei angemeldete iCloud-Konten auf echten Geräten; Simulator und CI haben das nicht. Geprüft wird alles, was lokal vor dem Server passiert. **Offene Grenze in jede Zusage:** Die Wiederholung nach `serverRecordChanged` in `syncToCloud` bleibt ungeprüft.

### Open Questions
- [ ] PO: 6 Dateien / ~230 Zeilen als ein Durchgang freigeben (Empfehlung: ja)?
- [ ] Phase 4: `SharedStoreService.shared` im Testhost ohne Absturz erzeugbar? Falls nein → Alternative B (Merge auslagern).
