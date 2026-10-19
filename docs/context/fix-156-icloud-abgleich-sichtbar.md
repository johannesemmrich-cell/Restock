# Context: fix-156-icloud-abgleich-sichtbar

## Request Summary
Issue #156, Folgearbeit aus #155: Der eigene (private) iCloud-Abgleich soll über mehrere Geräte zuverlässig und sichtbar sein. Drei Teile in **einem** Durchgang (PO 2026-10-18, „Alles in einem“, ~400–500 Zeilen vorab akzeptiert): (A) Exportfehler sichtbar machen, (B) Doppelungen von Läden messen und auflösen (Auflösungsregel ist Produktfrage), (C) Überlauffeld `CD_photoData_ckAsset` ins private Schema.

Vorgeschichte: kein Rückschritt. Der private Abgleich lief in TestFlight bis 2026-10-18 nie (Production-Schema fehlte). Seit Build 32 + Deploy belegt er hoch (Gerätetest #155: Artikel „Test“ 13:51 UTC in Production).

## Recherche (Pflicht, zuerst)
Volltext mit Quellen: `docs/artifacts/fix-156-icloud-abgleich-sichtbar/recherche-2026-10-18.md`. Kern:
- SwiftData spiegelt über `NSPersistentCloudKitContainer`; `eventChangedNotification` mit `object: nil` beobachtbar; `Event` mit `type`, `succeeded`, `error`, `endDate` (Forum 763876).
- `partialFailure` → `partialErrorsByItemID`; in eigener Zone sind unschuldige Items `batchRequestFailed` → den anderen Eintrag melden. `quotaExceeded` kommt nicht zuverlässig an (FB13773922).
- Dedup-Gewinner laut Apple DTS: **kleinste UUID**, nicht ältestes Datum; Regel muss auf allen Geräten deterministisch sein (Forum 772421). SwiftData hat keine Persistent-History-API → Dedup per Fetch nach beendetem Import.
- Jedes String-/Data-Attribut hat ein `CD_<attr>_ckAsset` (ASSET), genutzt ab 1 MB Record-Größe. Im Schema fehlt **jedes** davon (Development wie Production); praktisch erreichbar nur bei `photoData`.
- Keine neue Sync-Status-API in iOS 26/27.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Models/SharedModelContainer.swift` | Container-Aufbau (`[cloud, local]` App, `[local]` Erweiterung), Kopfwarnung Z.4–50, `lastFailureKey` „smartcart.lastContainerError“ (Z.57) wird **nirgends gelesen** (#5) |
| `SmartCart/SmartCartApp.swift` | `init()` Z.21–106, `defer` Z.26–52 (Ort für Beobachter-Start), DEBUG-Seeds, `DevModeIndicator` Z.826 |
| `SmartCart/Services/SyncCoordinator.swift` | Muster: `SyncFailureKind`, `Logger(category: "sync")`, `classify` für CKError inkl. `partialFailure` (Z.78–91), `SyncLog.message` (Z.360) — wiederverwendbar |
| `SmartCart/Services/CloudPreferencesSync.swift` | Einziger NotificationCenter-Beobachter (Z.54–65), spiegelt `hasCompletedOnboarding` und `shareID_`/`isSharedByMe_` über den KV-Store |
| `SmartCart/Views/Settings/OnboardingView.swift:305-314` | `finishOnboarding()` fügt **alle** Presets ein (nicht gewählte mit `isActive=false`), ohne Abgleich mit vorhandenen Läden |
| `SmartCart/Views/Settings/SettingsView.swift:406-411` | `seedStores(for:)` bei Länderwechsel, prüft nur „schon Läden dieses Landes“; Dev-Sektion Z.258–296 (Ort für neue Diagnoseansicht) |
| `SmartCart/Views/Settings/BrowseStoresView.swift:245-266` | Einzige Namensprüfung (exakt, reaktiviert inaktiven Laden) |
| `SmartCart/Views/Settings/StoreSetupView.swift:347-359` | Eigener Laden, keine Namensprüfung |
| `SmartCart/Views/Store/StoreShareSheet.swift:380-425` | Beitritt prüft nur lokale `shareID` → zwei Store-Objekte mit gleicher shareID möglich (Kommentar Z.383) |
| `SmartCart/Models/Store.swift` | Felder Z.14–70 (`id: UUID`, kein unique), `items` cascade Z.79; per-Gerät-UserDefaults `<key>_<store.id>` (shareID, members, sortMode, shoppingRoute, shoppingTrip …); `presets(for:)` Z.558 (DE: 17 Läden) |
| `SmartCart/Models/PurchaseRecord.swift:11` | `storeName` denormalisiert (Name, keine Beziehung) |
| `SmartCart/Services/StoreAssignmentOverrideService.swift` | Zuordnung/Standardladen über **Namen** (case-insensitiv) → gleichnamige Doppel mehrdeutig |
| `SmartCart/Models/ShoppingItem.swift:83` | `@Attribute(.externalStorage) var photoData: Data?` |
| `SmartCart/Services/PhotoCompressor.swift:8` | ≤1600 px, ≤500 KB → 1 MB nur im Ausnahmefall |
| `SmartCart/Views/Settings/ReceiptResolutionStatsView.swift` | Muster Dev-Statistikansicht (List, `.alert` statt confirmationDialog, `.devFeedback`) |
| `SmartCart/Views/Store/StoreDetailView.swift:1375-1402` | `SyncBanner.decision` (reine Funktion, Detailzeile nur im Dev-Modus) — Muster |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | T1/T2/T3; Regex `block(_:containsField:)` Z.98–100 akzeptiert `(_ckAsset)?` → fehlendes Asset-Feld fällt **nicht** auf |
| `docs/cloudkit/private-schema-aktuell.ckdb` | `CD_ShoppingItem` Z.43–79, `CD_photoData BYTES` Z.61, kein `_ckAsset` |
| `docs/testflight-setup.md:50-76` | cktool-Rezept (import ersetzt ganzes Dev-Schema), nennt `_ckAsset` als offen für #156 |
| `SmartCart/Services/SchemaVersions.swift` | `SchemaV1`, Migrationsplan ohne Stages, beim Öffnen nicht übergeben |

## Existing Patterns
- Reine Entscheidungsfunktionen für Anzeige (`SyncBanner.decision`, `SyncLog.message`) → unit-testbar ohne CloudKit.
- Dev-Ansichten unter Settings → Developer, Zähler in UserDefaults, nur Domain/Code `.public`, Fehlertext `.private` im `os.Logger`.
- Neue Modellfelder additiv mit Standardwert, ohne Versionssprung.
- DEBUG-Launch-Argumente für Seeds mit Pflicht-Aufräumargument (CLAUDE.md).
- Unit-Tests mit In-Memory-Container `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)` (`SharedStoreMergeTests.swift:36`).

## Dependencies
- Upstream: CoreData `NSPersistentCloudKitContainer` (intern), CloudKit `CKError`, `NotificationCenter`, cktool + Dashboard für Schema.
- Downstream: Jede Zusammenführung von Läden berührt Artikel (cascade!), per-Gerät-Schlüssel `<key>_<store.id>`, Namensbezüge (PurchaseRecord, Override/Default-Store), geteilte Läden (shareID, öffentliche DB, `SyncCoordinator.pullStore` nimmt den ersten Treffer).

## Existing Specs
- `docs/specs/models/private-cloudkit-schema.md` (#155; Abgrenzung zu #156 Z.226–229)
- `docs/specs/models/shared-model-container.md`
- `docs/specs/services/shared-store-schema-fallback.md` (#121, SyncBanner)
- `docs/specs/fast/doc-126-cktool-schema.md`

## Messbefund Doppelungen (vorläufig)
- Production (Hennings Konto, 2026-10-18): 19 `CD_Store`.
- DE-Presets: 17, und `finishOnboarding()` legt **alle 17** an (nicht gewählte inaktiv). 19 = 17 + 2 weitere (eigene/geteilte) ist plausibel → **wahrscheinlich keine Doppelung** bei einem Gerät. Zu bestätigen: Namensliste der 19 (Konsole) bzw. Ladenzahl inkl. ausgeblendeter in der App.
- Doppelungen entstehen erst mit zweitem Gerät (Onboarding vor KV-Store-Ankunft, `seedStores`, Beitritt zu geteiltem Laden auf beiden Geräten).

## Risks & Considerations
- Auflösung von Doppelungen löscht Nutzerdaten: Artikel vorher umhängen (cascade), per-Gerät-Schlüssel und shareID übertragen, Regel deterministisch (kleinste UUID), sonst löschen sich Geräte gegenseitig.
- Name allein reicht nicht als Duplikatkriterium (geteilter Laden „Lidl“ neben Preset „Lidl“, verschiedene Länder) → shareID/isCustom/countryCode beachten.
- Beobachter nur im App-Prozess (Erweiterungen haben keinen Mirror); `object: nil`, Ereignisse kommen auf beliebiger Queue.
- Export-Ereignisse und Fehler im Simulator nur eingeschränkt erzeugbar (kein iCloud-Konto → `noAccount`); Production-Ablehnung lokal nicht nachstellbar → Fehlerklassifikation als reine Funktion testen, Live-Weg am Gerät.
- `import-schema` ersetzt das ganze Development-Schema; Production-Deploy nur über Dashboard (Henning über Claude Desktop). Für vollständigen Schutz alle `_ckAsset`-Felder der String/Data-Attribute erwägen, nicht nur Foto (Analyse-Frage).
- Alternative zu B (Analyse): Doppelungen verhindern statt auflösen (Onboarding wartet auf Import / prüft Namen), oder nur anzeigen und PO entscheidet je Fall.

## Analysis

### Type
Bug/Feature-Mischung: Sichtbarkeit (A) und Schema (C) sind Absicherung, Doppelungen (B) Fehlervermeidung. Workflow läuft als Fix.

### Neuer Befund (2026-10-18)
Doppelungen brauchen **kein zweites Gerät**: Neuinstallation genügt. `CloudPreferencesSync.start()` übernimmt nur, was im KV-Store lokal schon liegt. Ist `hasCompletedOnboarding` noch nicht angekommen, läuft das Onboarding, `finishOnboarding()` fügt alle 17 DE-Presets ein (nicht gewählte inaktiv), danach importiert die Spiegelung die 17 alten → jeder Laden doppelt. Kommt der KV-Wert während des Onboardings an, schaltet `@AppStorage` die Ansicht von selbst um (kein Doppel). Zweite Quelle: `StoreShareSheet`-Beitritt prüft nicht auf vorhandene gleiche `shareID`.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/CloudMirrorMonitor.swift` | CREATE | Beobachter `eventChangedNotification` (`object: nil`, nur App-Prozess), reine Funktion `summarize` (partialFailure → Einzelfehler ohne `batchRequestFailed`, `NSUnderlyingError` mitprüfen), letzter Export/Import in UserDefaults |
| `SmartCart/Services/StoreDuplicateService.swift` | CREATE | `StoreSnapshot`, `StoreDuplicateFinder.groups/winner` (kleinste UUID), Klassen 1–3 |
| `SmartCart/Views/Settings/StoreDuplicatesView.swift` | CREATE | Dev-Ansicht Duplikatgruppen (Muster `ReceiptResolutionStatsView`) |
| `SmartCart/SmartCartApp.swift` | MODIFY | Monitor im `init()`-`defer` starten; DEBUG-Seed/Clear-Argumente für Doppel |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | Dev-Sektion: Diagnosezeile iCloud-Abgleich + Link Duplikatansicht; `seedStores` gegen Kriterium prüfen |
| `SmartCart/Views/Settings/OnboardingView.swift` | MODIFY | nur fehlende Presets einfügen; ggf. Warten auf ersten Import (PO-Frage) |
| `SmartCart/Views/Store/StoreShareSheet.swift` | MODIFY | Beitritt: vorhandenen Laden gleicher `shareID` wiederverwenden |
| `docs/cloudkit/private-schema-aktuell.ckdb` | MODIFY | `CD_photoData_ckAsset ASSET` (Umfang PO-Frage) |
| `docs/testflight-setup.md` | MODIFY | Vermerk „offen für #156“ |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | MODIFY | Test auf `_ckAsset`-Feld |
| `RestockTests/CloudMirrorMonitorTests.swift`, `RestockTests/StoreDuplicateFinderTests.swift` | CREATE | reine Funktionen, In-Memory-Container |
| `RestockUITests/…` | CREATE | Diagnosezeile + Duplikatansicht mit Seed/Aufräumargument |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Dateien registrieren |

### Duplikat-Kriterium
1. Gleiche, nicht leere `shareID` → sicher derselbe Laden.
2. `isCustom == false`, gleiches `countryCode`, Name normalisiert (trim, Groß/Klein, diakritikfrei) → Preset-Wiederholung.
3. `isCustom == true`, gleicher Name → nur melden, nie automatisch.
Nicht gruppiert: verschiedene Länder; geteilter Laden vs. gleichnamiges Preset.

### Variantenvergleich B (Schätzung, nicht gemessen)
| Variante | Produkt-LoC | Test-LoC | Datenrisiko | deckt ab |
|---|---|---|---|---|
| B1 messen + anzeigen (Dev) | ~140 | ~100 | keines | alle sichtbar, keine verhindert |
| B2 verhindern (Onboarding, seedStores, Beitritt) | ~60 | ~60 | sehr gering | Neuinstallation, zweites Gerät, Doppelbeitritt; Offline-Rest bleibt |
| B3 automatisch zusammenführen | +200–250 | +150 | hoch (cascade, Geräterennen, per-Gerät-Schlüssel) | auch Altlasten |
| B4 = B2 + B3 | ~310 | ~210 | hoch | alle |
Alternative ohne Code-Logik: Onboarding legt nur die gewählten Presets an (nicht alle 17) → Schadensbild kleiner; ändert aber die Laden-Einrichtung (inaktive Presets fehlen dort) — verworfen als Nebenwirkung, nur genannt.

### Scope Assessment
- Dateien: ~9 Produkt/Doku + 3–4 Test (+ pbxproj)
- Geschätzte LoC: A+B1+B2+C ≈ 320 Produkt + 270 Unit + 80 UI ≈ 670 inkl. Tests (PO hat 400–500 vorab akzeptiert; im Spec Zahl nennen)
- Risk Level: MEDIUM (Onboarding-Pfad und Beitritt geändert; kein Löschen bei B1/B2)

### Technical Approach
Empfehlung: A + C + B1 + B2 in diesem Durchgang, Gewinnerregel (kleinste UUID) als reine Funktion vorbereitet; B3 erst nach Messung am Gerät. Reihenfolge: C (Schema, Dashboard-Deploy durch Henning braucht Vorlauf) → A → B1 → B2.

### Dependencies
`NSPersistentCloudKitContainer.Event` (CoreData), `CKError`, `SyncCoordinator.classify`/`SyncLog`, KV-Store-Spiegelung `CloudPreferencesSync`, cktool + Dashboard.

### Open Questions
- [x] PO 2026-10-18: Doppel **verhindern + anzeigen** (Dev-Ansicht), nichts löschen, kein Zusammenführen in diesem Durchgang (B1+B2)
- [x] PO 2026-10-18: Ersteinrichtung wartet **bis 10 s** mit Hinweis „Läden werden aus iCloud geladen“; kommen Läden an, entfällt die Einrichtung, sonst normal weiter
- [x] PO 2026-10-18: `_ckAsset` **nur Foto** (`CD_photoData_ckAsset`)
- [x] PO 2026-10-18: Exportfehler **nur im Entwicklermodus** (Diagnosezeile)
- [x] PO 2026-10-18 freigegeben: **Entwurf A** (Onboarding) und **zwei Zeilen** (Entwickler) — `docs/artifacts/fix-156-icloud-abgleich-sichtbar/entwurf.html` (https://claude.ai/artifact/5DcDQrxbEd4Um8KRHjiydD). Empfohlen: Onboarding Entwurf A (Hinweis „Deine Läden werden aus iCloud geladen …“ auf dem Startbildschirm, „Loslegen“ gesperrt bis erster Import fertig oder 10 s; kommen Läden an → Einrichtung entfällt, `hasCompletedOnboarding` setzen; ohne iCloud-Konto kein Warten), Alternative B (Prüfen erst bei „Los geht's!“). Entwickler: zwei Zeilen „iCloud-Abgleich“ (Untertitel letzter Export, rot bei Fehler) und „Doppelte Läden“ mit Detailansichten; Alternative: eine kombinierte Zeile.
