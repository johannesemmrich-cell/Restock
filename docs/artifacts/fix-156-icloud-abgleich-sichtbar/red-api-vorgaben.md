# API-Vorgaben aus den RED-Tests (#156)

Die RED-Tests legen diese Namen fest; die Implementierung übernimmt sie unverändert.

## SmartCart/Services/CloudMirrorMonitor.swift
- `static func CloudMirrorMonitor.summarize(error: Error) -> CloudMirrorSummary`
- `CloudMirrorSummary`: `domain: String`, `code: Int`, `detail: String` (localizedDescription des Einzelfehlers), `kind` (vergleichbar mit `.schemaIncomplete`, Empfehlung `SyncFailureKind`, ggf. `: String` zum Speichern), `failedItemCount: Int` (ohne batchRequestFailed), `totalItemCount: Int`, `itemCountText: String?` („1 von 3“, ohne Teilfehler nil)
- „production schema“ im Text eines Einzelfehlers → `.schemaIncomplete` (heutiges privates `classify` erkennt das nicht → erweitern/ergänzen)
- T3: NSError (NSCocoaErrorDomain 134419) mit `NSUnderlyingError` = CKError.partialFailure → verschachtelter Einzelfehler, `itemCountText == "1 von 2"`
- `CloudMirrorMonitor(statusStore: CloudMirrorStatusStore)`, `func handle(type: NSPersistentCloudKitContainer.EventType, succeeded: Bool, error: Error?, endDate: Date?)` (nicht @MainActor; `endDate == nil` → nichts schreiben)
- `static func CloudMirrorMonitor.shouldObserve(bundleURL: URL) -> Bool`
- `static func CloudMirrorMonitor.devRowSubtitle(lastExport: CloudMirrorRun?) -> (text: String, isFailure: Bool)` → „Export fehlgeschlagen · 19:02“, „Export erfolgreich · 19:02“, „noch kein Lauf“ (HH:mm, lokale Zeitzone)
- `CloudMirrorRun(date: Date, succeeded: Bool, summary: CloudMirrorSummary?)` — `date` nach Speichern exakt gleich
- `CloudMirrorStatusStore(defaults: UserDefaults)`: `lastRun(_ type: NSPersistentCloudKitContainer.EventType) -> CloudMirrorRun?`, `exportSuccessCount`, `exportFailureCount`, `clear()` (alle `smartcart.cloudMirror.*`)
- `OnboardingCloudGate.decision(accountAvailable:firstImportFinished:storeCount:elapsed:) -> OnboardingCloudGate.Decision` (`.proceed/.wait/.skipOnboarding`); Frist ab `elapsed >= 10`; `storeCount > 0` → `.skipOnboarding` auch bei laufendem Import

## SmartCart/Services/StoreDuplicateService.swift (inkl. StoreShareJoin, StoreSeeding; T18 sucht `delete(`)
- `StoreSnapshot(id:name:countryCode:isCustom:shareID:isActive:itemCount:)` und `StoreSnapshot(_ store: Store)`
- `StoreDuplicateFinder.groups(_:) -> [StoreDuplicateGroup]`; Gruppe: `kind` (`.sameShareID/.samePreset/.sameCustomName`), `stores`, `reportOnly` (nur Klasse 3); Klasse 2 schließt Läden mit shareID aus
- `StoreDuplicateFinder.winner(of:) -> StoreSnapshot?` (kleinste UUID, leer → nil)
- `StoreDuplicateFinder.missingPresets(_ presets: [StoreSnapshot], existing: [StoreSnapshot]) -> [StoreSnapshot]`
- `@MainActor @discardableResult static func StoreSeeding.insertMissingPresets(_ presets: [Store], into context: ModelContext) throws -> Int` (finishOnboarding setzt isActive vorher und ruft sie; seedStores ebenso)
- `@MainActor static func StoreShareJoin.existingStore(shareID: String, in context: ModelContext) -> Store?`

## UI
- Zeilen „iCloud-Abgleich“ / „Doppelte Läden“: Buttons, Label beginnt mit Titel, Untertitel im selben Label; Navigationstitel gleichlautend; Einstellungen schließen mit „Fertig“
- Detail iCloud: staticText enthält „CD_ShoppingItem“
- Doppelte Läden: staticText „Doppelgruppen“, Element `accessibilityIdentifier("storeDuplicates.groupCount")` mit Label genau „1“, staticText enthält „bliebe“
- Onboarding: staticText beginnt „Deine Läden werden aus iCloud geladen“; „Loslegen“ `isEnabled == false` während Warten

## Launch-Argumente (DEBUG)
- `-seedCloudMirrorStatusForUITests` / `-clearCloudMirrorStatusForUITests`
- `-seedDuplicateStoresForUITests` (zwei aktive Preset-„Lidl“ DE, feste UUIDs) / `-clearDuplicateStoresForUITests`
- `-simulateCloudImportForUITests <s>` (Konto vorhanden, Import nach s fertig)
- `-simulateCloudStoresArriveForUITests <s>` (Konto vorhanden; nach s „Lidl“ und „Rewe“ DE über echten Datenweg)
- tearDown Diagnose: `-hasCompletedOnboarding YES -clearCloudMirrorStatusForUITests -clearDuplicateStoresForUITests`; Onboarding: `-hasCompletedOnboarding YES -clearOnboardingForUITests`

## Bekannte Risiken der Tests
- T23: 4-s-Fenster kann unter Last zu knapp sein (Hinweis schon weg, bevor antippbar)
- T21: „Doppelgruppen = 1“ setzt sauberen Simulator voraus
- T8: deutsche Texte, Testsprache de (Scheme)
