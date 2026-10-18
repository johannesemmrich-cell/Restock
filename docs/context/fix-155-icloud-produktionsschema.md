# Context: fix-155-icloud-produktionsschema

## Request Summary
Der private iCloud-Abgleich der eigenen Läden und Listen (SwiftData-Spiegelung `.private`) hatte bis Build 31 kein Produktionsschema. Am 2026-10-18 wurden `CD_Store`, `CD_ShoppingItem` und `CD_PurchaseRecord` nach Production deployt. Offen sind vier Punkte (Issue #155):
1. `CD_FeedbackItem`/`CD_TodoItem` fehlen in beiden Umgebungen.
2. Doppelungen beim ersten Hochladen von mehreren Geräten.
3. Nachweis des Exports in Production.
4. Doku des Schema-Schritts für die private DB.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Models/SharedModelContainer.swift` | Einzige Stelle, an der der Store geöffnet wird. `storeConfigurations(forBundleAt:)` liefert `[cloud(.private), local]` für die App und nur `[local]` für Erweiterungen. Eine Konfiguration ohne Namen und ohne Teil-Schema spiegelt ALLE fünf Modelle. Kopfwarnung: Schema-Deklaration und Store-Adressierung nur für alle Prozesse gleichzeitig ändern (Datenverlust-Vorgeschichte, #4). |
| `SmartCart/Services/SchemaVersions.swift` | `SchemaV1.models` = Store, ShoppingItem, PurchaseRecord, FeedbackItem, TodoItem; Migrationsplan ohne Stufen. |
| `SmartCart/SmartCartApp.swift` (ca. Z. 62–105) | Notfallpfad Stufe 3/4 (Store löschen, In-Memory); `migrateStoreToAppGroupIfNeeded`. |
| `SmartCart/Models/FeedbackItem.swift`, `TodoItem.swift` | Dev-Modelle, alle Felder mit Standardwert (CloudKit-tauglich). |
| `SmartCart/Views/Feedback/FeedbackListView.swift`, `Views/Settings/TodoListView.swift`, `Views/Components/DevFeedbackButton.swift` | Einzige Schreiber/Leser der Dev-Modelle (`@Query`, `modelContext.insert`). |
| `SmartCart/Intents/AddItemIntent.swift`, `SmartCartWidgets/ShoppingListWidget.swift`, `RestockShareExtension/ShareViewController.swift` | Weitere Prozesse über `SharedModelContainer.make()`. Ändert sich das Schema oder die Adressierung, sind sie mit betroffen. |
| `RestockTests/SchemaCloudKitCompatibilityTests.swift` | Prüft, dass `.private`-Container mit `SchemaV1` öffnet (lokal, ohne Server). |
| `RestockTests/ExistingDataSurvivesCloudEnableTests.swift` | Bestandsdaten überleben das erste Öffnen mit CloudKit. |
| `RestockTests/SharedModelContainerExtensionDetectionTests.swift` | Stufen und gleicher Ablageort für App und Erweiterungen. |
| `docs/testflight-setup.md` (Abschnitt ab Z. 26) | Schema-Schritt bisher nur für den Record `SharedStore` (öffentliche DB), cktool-Weg mit Grenze „Production nur per Dashboard“. |
| `docs/specs/models/shared-model-container.md`, `docs/specs/fast/doc-126-cktool-schema.md` | Bestehende Specs zu Container und cktool-Doku. |

## Existing Patterns
- Ein gemeinsamer Helfer für alle Prozesse; Verzweigung nur nach „ist Erweiterung“.
- Schemaarbeit in CloudKit: cktool export/import nur in Development, Production nur per Dashboard „Deploy Schema Changes“. Seit 2026-10-18 hat Henning das über Claude Desktop gemacht ([[cloudkit-schema-per-cktool]]).
- Drift-Test-Muster für Feldlisten (`SharedStoreSchemaTests.testT8_…`) als Vorbild für einen Drift-Test der gespiegelten Typen.
- Sync-Status wird für den eigenen Abgleich nirgends beobachtet. Es gibt keinen Beobachter für `NSPersistentCloudKitContainer.eventChangedNotification` und keinen Diagnosepunkt (nur `lastContainerError` beim Öffnen).

## Dependencies
- Upstream: SwiftData `ModelConfiguration(cloudKitDatabase: .private(...))` → NSPersistentCloudKitContainer → CloudKit-Container `iCloud.com.johannesemmrich.SmartCart`, Zone `com.apple.coredata.cloudkit.zone`.
- Downstream: alle Views mit `@Query`, Intents, Widget, Teilen-Erweiterung. Geteilte Läden (`SharedStoreService`, öffentliche DB) sind unabhängig.

## Recherche (erste Runde, 2026-10-18)
- TestFlight nutzt Production. Fehlt dort ein Typ, gilt CKError 12 „Cannot create new type … in production schema“ (as designed). Quelle: https://developer.apple.com/forums/thread/819507, https://developer.apple.com/forums/thread/841397
- Einzelne Modelle von der Spiegelung ausnehmen geht nur mit getrennten `ModelConfiguration`s, jede mit eigenem Teil-Schema. Bekommen beide dasselbe Schema, wird trotzdem alles gespiegelt. Quelle: https://developer.apple.com/forums/thread/767238, https://developer.apple.com/forums/thread/782488
- Doppelungen: NSPersistentCloudKitContainer kennt keine Eindeutigkeit. Lädt jedes Gerät seinen Bestand hoch, entstehen Duplikate, die die App selbst auflösen muss, z. B. über die Persistent History. Quelle: https://developer.apple.com/forums/thread/699634, https://developer.apple.com/forums/thread/691338, https://developer.apple.com/forums/thread/772007
- Ungeklärt, Pflicht für `/20-analyse`: Blockiert ein Teilfehler, etwa ein fehlender Typ für FeedbackItem, den ganzen Export-Durchgang oder nur die betroffenen Records? Hinweise auf festhängende Exporte bei `partialFailure`: https://developer.apple.com/forums/thread/838743

## Risks & Considerations
- **Datenverlust:** Werden FeedbackItem/TodoItem in eine eigene, lokale Konfiguration verschoben, ändert sich die Store-Adressierung. Eine benannte Konfiguration bedeutet eine eigene Datei, also wären die Bestandsdaten der Dev-Modelle weg oder müssten migriert werden. Die Kopfwarnung in `SharedModelContainer.swift` und Vorfall #4 betreffen genau das. Gleiche Änderung in allen Prozessen nötig.
- **Alternative ohne Code:** `CD_FeedbackItem`/`CD_TodoItem` per cktool in Development anlegen und per Dashboard nach Production deployen. Dann ändert sich der Code nicht, die Dev-Daten liegen aber in iCloud.
- **Nachweis am Gerät:** Punkt 3 braucht Hennings Konto und Geräte und darf nur nach seinem wörtlichen „jetzt ist ein Test möglich“ laufen. Ohne Gerät bleibt der Weg über CloudKit-Konsole/cktool (Records zählen geht nur mit Benutzer-Token für die private DB).
- **Doppelungen:** Eine Dedup-Logik wäre ein eigenes, größeres Ziel. Zuerst messen, ob und wie sie bei Henning auftreten (Punkt 2).
- **Simulator:** Development-Umgebung, also nicht dasselbe Verhalten wie Production. Reproduktion von „fehlender Typ in Production“ lokal nur eingeschränkt möglich.
- Scoping-Limits: 4–5 Dateien, ±250 LoC je Durchgang. Punkt 2 (Dedup) sprengt das voraussichtlich.

## Analysis

### Type
Bug. Der eigene Abgleich hat nie funktioniert, es ist keine Verschlechterung: Bis Build 31 fehlten alle CD_-Typen in Production (Deploy-Diff vom 2026-10-18).

### Recherche (zweite Runde, 2026-10-18): Blockiert ein fehlender Typ den ganzen Export?
**Ja.** Ein abgelehnter Record lässt den ganzen Export-Durchgang scheitern, und der Mirroring-Delegate bleibt für den Rest der Sitzung aus.
- https://developer.apple.com/forums/thread/838743: „A single failed … op fails the whole export event and disables the mirroring delegate for the rest of the session.“
- https://github.com/martinkearn/wiggle-room/issues/38: Ein einziges fehlendes Prod-Feld führte dazu, dass alle Upload-Batches abgelehnt wurden („Syntax error in request“, partialFailure). Downloads liefen weiter, die Geräte liefen still auseinander. Behoben durch den Schema-Deploy.
- https://developer.apple.com/forums/thread/841397: In Production werden Typen nie angelegt („Cannot create new type … in production schema“).

**Folge für Restock:** Feedback (`DevFeedbackButton.swift:95`) und Todos (`TodoListView.swift:84`) entstehen nur im Entwicklermodus. Der lässt sich aber auch in TestFlight per Passwort freischalten (`SettingsView.swift:34`, `:336`), und der PO nutzt ihn. Liegt auf einem Gerät ein einziges Feedback oder Todo, das noch exportiert werden muss, scheitert damit voraussichtlich jeder Export dieses Geräts, auch für Läden und Artikel. Punkt 1 ist deshalb kein Randthema. Er ist Voraussetzung dafür, dass Build 32 bei Henning überhaupt hochlädt.

### Reproduktion
Lokal ist das nicht nachstellbar. Simulator- und Xcode-Builds nutzen Development, und dort legt CloudKit fehlende Typen just-in-time an. Der fehlerhafte Zustand ist durch das Deploy-Diff vom 2026-10-18 belegt (3 neue Typen, FeedbackItem/TodoItem nicht dabei). Wird der Ist-Zustand vor dem Fix noch einmal per `cktool export-schema` (Development) festgehalten, ist er reproduzierbar dokumentiert. Die Wirkung in Production lässt sich nur am Gerät mit TestFlight nachweisen, und nur nach Hennings „jetzt ist ein Test möglich“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| CloudKit-Schema (Container `iCloud.com.johannesemmrich.SmartCart`) | MODIFY (kein Repo-Code) | `CD_FeedbackItem`, `CD_TodoItem` in Development per `cktool import-schema`, Felder nach dem Muster der exportierten `CD_Store`-Definition. Danach Dashboard „Deploy Schema Changes“ nach Production. |
| `docs/cloudkit/` Schema-Export (.ckdb) | CREATE | Vorher/Nachher-Export als Beleg und Grundlage für den Import |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | CREATE | Snapshot-Test: Entitäten und Felder aus `Schema(versionedSchema: SchemaV1.self)` gegen eine feste Liste. Die Fehlermeldung verweist auf den Deploy-Schritt (Muster `SharedStoreSchemaTests.testT8_`). Vorab prüfen, ob `Schema.entities`/`attributes` die Namen liefern. |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Neue Testdatei registrieren |
| `docs/testflight-setup.md` (ab Z. 26) | MODIFY | Neuer Abschnitt für die private DB: SwiftData-Typen und -Felder vor jedem Upload in Production, Rezept (cktool, Deploy, Gegenprobe), Falle „nil-Felder erscheinen nicht“ |

### Scope Assessment
- Repo-Dateien: 3–4 (Test, pbxproj, Doku, Schema-Export)
- Estimated LoC: etwa +120/−0 (Test ~60, Doku ~40, pbxproj ~8, Schema-Datei nicht als Code gezählt)
- Risk Level: LOW für den Code. Am Container und an der Store-Adressierung ändert sich nichts. Das Schema in CloudKit wird nur ergänzt, nichts wird gelöscht (Production erlaubt ohnehin keine Löschungen).

### Technical Approach (Empfehlung)
**Weg A3: Schema per Werkzeug ergänzen, ohne App-Code.**
1. `cktool export-schema` (Development) sichern. Dann `CD_FeedbackItem`/`CD_TodoItem` mit allen Feldern ergänzen (`CD_id`, `CD_context`, `CD_text`, `CD_priority`, `CD_isResolved`, `CD_createdAt` bzw. `CD_id`, `CD_title`, `CD_notes`, `CD_isCompleted`, `CD_createdAt`). Die Systemfelder (`CD_entityName` usw.), Typen, Indizes und Rollen werden genau wie bei `CD_Store` übernommen. Danach `validate-schema`, `import-schema` und als Gegenprobe ein erneuter Export mit `diff`.
2. Production: Dashboard „Deploy Schema Changes“, das Diff darf nur die zwei Typen zeigen. cktool kann das nicht. Ablauf wie am 2026-10-18, über Claude Desktop bei Henning oder per Browser-Steuerung, wobei der Werkzeugweg Vorrang hat.
3. Snapshot-Test und Doku (Punkt 4) als Vorbeugung.
4. Punkt 3: Nachweis am Gerät nur auf Hennings Wort. Die App wird vorher fertig installiert, Prüfung über die CloudKit-Konsole oder das zweite Gerät.

**Alternativen:**
- A1, Debug-Lauf auf einem Gerät mit iCloud-Login: Die Typen entstehen just-in-time, kein Handschreiben der .ckdb. Das braucht aber Hennings Gerät. Die Falle dabei: `TodoItem.notes` muss gefüllt sein, sonst fehlt das Feld.
- A2, `initializeCloudKitSchema` über einen parallelen Core-Data-Stack: Das bedeutet mehr Code und einen doppelten Mirror, was gegen die Kopfwarnung verstößt.
- **B, Dev-Modelle aus der Spiegelung nehmen** (eigene lokale `ModelConfiguration` mit Teil-Schema): Das ist die einzige echte Alternative mit Code und der richtige Weg, falls Feedback und Todos grundsätzlich nicht in iCloud gehören. Dafür müssten die Store-Adressierung in allen Prozessen geändert werden (Kopfwarnung, Vorfall #4) und die Bestandsdaten in eine zweite Datei migriert werden. Das ist deutlich mehr Umfang und Risiko. Gekippt würde die bisherige Entscheidung „ein Schema, ein Store für alle Prozesse“.

### Dependencies
- Für den cktool-Import braucht es ein Management-Token. Es wird im Dashboard erzeugt und nach der Arbeit wieder entfernt ([[cloudkit-schema-per-cktool]]).
- Den Production-Deploy kann nur das Dashboard ausführen.
- Punkt 3 hängt an Punkt 1 und an Hennings Wort.

### Out of Scope → Folge-Issue #156
Folgende Punkte gehören in ein eigenes Ziel („eigener Abgleich über mehrere Geräte zuverlässig und sichtbar“):
- Beobachter für `NSPersistentCloudKitContainer.eventChangedNotification` mit Diagnosezeile; heute ist ein gescheiterter Export unsichtbar.
- Doppelungen messen und auflösen (Punkt 2): `OnboardingView.finishOnboarding()` und `SettingsView.seedStores` legen Standardläden je Gerät ohne Namensprüfung an.

### Open Questions
- [x] PO (2026-10-18): Feedback und Todos bleiben in iCloud → Weg A. Weg B entfällt.
