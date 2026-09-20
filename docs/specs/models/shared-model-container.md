---
entity_id: shared-model-container
type: module
created: 2026-09-20
updated: 2026-09-20
status: draft
version: "1.1"
tags: [bugfix, cloudkit, share-extension, swiftdata]
---

# SharedModelContainer

## Approval

- [ ] Approved

## Purpose

`SharedModelContainer` ist der einzige Einstiegspunkt, über den alle Prozesse (Haupt-App, Siri-Intent, Widget, Share Extension) den gemeinsamen App-Gruppen-SwiftData-Store öffnen; er entscheidet dabei zwischen CloudKit-gespiegeltem und rein lokalem Store. Mit diesem Fix erkennt `make()` zusätzlich, ob der aufrufende Prozess eine App-Erweiterung ist, und überspringt dort sowohl den CloudKit-Versuch als auch die einmalige Vor-Cloud-Sicherung, weil Erweiterungen kein iCloud-Entitlement besitzen und der CloudKit-Versuch dort den Prozess per Assertion (SIGTRAP) abstürzen lässt.

## Source

- **File:** `SmartCart/Models/SharedModelContainer.swift`
- **Identifier:** `enum SharedModelContainer`, `static func make() -> ModelContainer?`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `SchemaV1` (`SmartCart/Models/SchemaVersions.swift`) | schema | Versionierte Schema-Deklaration, mit der der Store geöffnet wird — darf sich nicht ändern (Datenverlust-Vorgeschichte). |
| App-Gruppe `group.com.johannesemmrich.SmartCart` | app group container | Ablageort der SQLite-Store-Dateien und des app-gruppenweiten Sicherungs-Flags. |
| CloudKit-Container `iCloud.com.johannesemmrich.SmartCart` | CloudKit container | Ziel der Spiegelung im Haupt-App-Prozess. |
| `UserDefaults` (`.standard` und App-Gruppen-Suite) | system API | Diagnose-Schlüssel (`lastFailureKey`, ungelesen, Folge-Issue #5) bzw. das Sicherungs-Flag `smartcart.preCloudBackupDone.v2`. |
| `FileManager` | system API | Kopiert Store-Dateien vor dem ersten Cloud-Versuch in `PreCloudBackup`. |
| `SmartCartApp.swift` (`SmartCartApp.init()`) | caller | Erster Aufrufer im Haupt-App-Prozess; hat zwei weitere Fallback-Stufen hinter `make()`. Bleibt unverändert. |
| `SmartCart/Intents/AddItemIntent.swift` | caller | Läuft ohne eigenes Extension-Target im App-Prozess und behält damit das iCloud-Entitlement. Bleibt unverändert. |
| `SmartCartWidgets/ShoppingListWidget.swift` (5 Aufrufstellen) | caller | Widget-Extension-Prozess, wird vom Fix automatisch mitgeheilt, ohne eigenen Nachweis in diesem Auftrag (Folge-Issue #6). Bleibt unverändert. |
| `RestockShareExtension/ShareViewController.swift` | caller | Löst den nachgestellten Absturz aus; Ziel des Cross-App-Nachweises. Bleibt unverändert. |
| `RestockTests/SchemaCloudKitCompatibilityTests.swift` | test | Bestehender Test gegen `.private(...)` fürs aktuelle Schema; muss grün bleiben. |
| `RestockTests/ExistingDataSurvivesCloudEnableTests.swift` | test | Bestehender Test für den Übergang lokal → Cloud; muss grün bleiben. |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/SharedModelContainer.swift` | MODIFY | Neue reine Erkennungsfunktion (App-Erweiterung ja/nein) über eine `URL`; `make()` verzweigt vor dem Cloud-Versuch und überspringt in Erweiterungen sowohl `backupLocalStoreBeforeFirstCloudAttempt()` als auch den CloudKit-Konfigurationsversuch; Kommentar-Header Z. 29-36 (Verbot der Prozess-Verzweigung) wird als ausdrücklich zurückgenommen markiert, nicht gelöscht; Falschaussage Z. 37-39/53-55 über eine angebliche Auswertung des `[cloud]`-Präfix durch `SmartCartApp.init()` wird korrigiert. |
| `RestockTests/SharedModelContainerExtensionDetectionTests.swift` | CREATE | Unit-Tests für die Erkennungsfunktion (App-Pfad → `false`, `.appex`-Pfad → `true`) und, falls verifizierbar, für die im App-Prozess gewählte Store-Konfiguration. |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Neue Testdatei in den vier nötigen Abschnitten registrieren (`PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`) — Xcode erkennt neue Dateien nicht automatisch. |
| `RestockUITests/ReceiptShareExtensionTests.swift` | CREATE | Cross-App-Nachweis (Fotos-App → Teilen → Restock), wird in Phase 4 (TDD RED) gebaut. |

**Ausdrücklich NICHT geändert:** `RestockShareExtension/RestockShareExtension.entitlements`, `SmartCartWidgets/SmartCartWidgets.entitlements`, `SmartCart/SmartCart.entitlements`, `SmartCart/SmartCartApp.swift`, `SmartCartWidgets/ShoppingListWidget.swift`, `SmartCart/Intents/AddItemIntent.swift`, `RestockShareExtension/ShareViewController.swift`. Die Signatur von `make()` bleibt `static func make() -> ModelContainer?` ohne Parameter; alle acht bestehenden Aufrufstellen bleiben unangetastet. Das Speicherlimit von 120 MB für Erweiterungen wird nicht adressiert.

### Estimated Changes
- Files: 3 in Phase 5 (Produktivcode + Tests + Projektdatei), +1 Testdatei in Phase 4
- LoC: +70/-15 (Produktivcode und Unit-Tests), zzgl. pbxproj-Registrierung

## Implementation Details

1. **Erkennungsfunktion.** Eine neue, reine Funktion prüft `URL.pathExtension == "appex"` und arbeitet auf einer übergebenen `URL`, nicht direkt auf `Bundle.main` — nur so ist sie in beide Richtungen ohne echten Extension-Prozess testbar (App-Pfad → `false`, `.appex`-Pfad → `true`). Der Produktivaufruf in `make()` reicht `Bundle.main.bundleURL` hinein. Geprüft gegen alle fünf Laufzeitumgebungen (Haupt-App, Share Extension, Widget, Siri-Intent im App-Prozess, Unit-Test-Host = App-Prozess) — siehe `docs/context/fix-4-share-extension-cloudkit.md`, Abschnitt „A — Erkennungsmethode".
2. **Verzweigung in `make()`.** Wird eine App-Erweiterung erkannt, überspringt `make()` sowohl den Aufruf von `backupLocalStoreBeforeFirstCloudAttempt()` als auch den `try ModelContainer(... cloudKitDatabase: .private(...))`-Versuch und öffnet direkt den lokalen App-Gruppen-Store (`cloudKitDatabase: .none`). Die Schema-Deklaration (`Schema(versionedSchema: SchemaV1.self)`) und die Store-Adressierung (`groupContainer: .identifier(appGroupID)`) bleiben in beiden Zweigen identisch.
3. **Sicherungs-Flag mit umgestellt.** `backupLocalStoreBeforeFirstCloudAttempt()` wird nur noch im Nicht-Erweiterungs-Zweig aufgerufen, damit das app-gruppenweite Einmal-Flag `smartcart.preCloudBackupDone.v2` nicht von einer Erweiterung verbraucht wird, bevor die Haupt-App ihren ersten echten Cloud-Versuch macht.
4. **Kommentar-Korrekturen.** Der bestehende Warnhinweis „And do NOT add per-process branching here either" (Z. 29-36) wird durch einen Vermerk ergänzt, der die Rücknahme dieser Festlegung datiert und begründet (Verweis auf dieses Issue), ohne den ursprünglichen Text zu löschen. Die Behauptung, `SmartCartApp.init()` werte das `[cloud]`-Präfix des Diagnose-Schlüssels aus, wird entfernt bzw. korrigiert — diese Logik existiert im Code nicht (siehe Analyse, Korrektur 1).
5. **Zu verifizieren, nicht vorausgesetzt:** ob `ModelConfiguration` eine lesbare `cloudKitContainerIdentifier`-Eigenschaft anbietet, mit der sich im App-Prozess direkt prüfen lässt, dass die erste (erfolgreiche) Konfiguration die CloudKit-Variante ist. Falls nein, trägt der Cross-App-Nachweis (AC-5) diese Richtung allein.

## Expected Behavior

- **Input:** `make()` ohne Parameter, aufgerufen aus einem beliebigen Prozess des Projekts (Haupt-App, Siri-Intent im App-Prozess, Widget-Erweiterung, Share Extension). Intern ausgewertet wird `Bundle.main.bundleURL`.
- **Output:** Ein geöffneter `ModelContainer` auf dem App-Gruppen-Store mit Schema `SchemaV1` — im App-Prozess mit CloudKit-Spiegelung (`.private(iCloud.com.johannesemmrich.SmartCart)`), in App-Erweiterungen ohne Spiegelung (`.none`). Schlägt auch das fehl, gibt `make()` weiterhin `nil` zurück; die Aufrufer entscheiden wie bisher über die Degradierung.
- **Side effects:**
  - *App-Prozess:* `backupLocalStoreBeforeFirstCloudAttempt()` läuft unverändert und setzt beim ersten Mal das app-gruppenweite Flag `smartcart.preCloudBackupDone.v2` und legt eine Kopie der Store-Dateien unter `PreCloudBackup` ab.
  - *App-Erweiterung:* **keine** Sicherung, **kein** Verbrauch des Einmal-Flags, **kein** CloudKit-Kontakt. Der Öffnungspfad ist dort rein lesend — der Extension-Code schreibt nachweislich nicht in den SwiftData-Store.
  - *Diagnose:* `lastFailureKey` in `UserDefaults.standard` wird bei Fehlschlägen wie bisher geschrieben (und weiterhin nirgends gelesen — Folge-Issue #5).
  - Kein Einfluss auf Schema-Deklaration, Store-Adressierung, Signatur von `make()` oder die acht Aufrufstellen.

## Known Limitations

- Die Erkennung ist eine **Prüfung der Bundle-Hülle**, keine Abfrage des tatsächlichen Entitlements. Die dafür nötigen Security-APIs (`SecTaskCopyValueForEntitlement`) sind auf iOS nicht im öffentlichen SDK — in der Analyse belegt und verworfen.
- Bekäme eine App-Erweiterung künftig ein eigenes iCloud-Entitlement, liefe sie trotzdem weiter nur lokal. Das wäre dann eine bewusste Folgeänderung, kein Fehler dieses Fixes.
- Das Widget wird vom selben Fix mitgeheilt, in diesem Auftrag aber **nicht nachgewiesen** — sein Absturz ist nie aufgetreten (kein Absturzbericht vorhanden). Offen in Folge-Issue #6.
- Das Speicherlimit von 120 MB für App-Erweiterungen bleibt unangetastet; es ist der zweite, bisher nicht ausgelöste Risikofaktor der Share Extension.
- Ob sich die gewählte Store-Konfiguration im Unit-Test direkt auslesen lässt (AC-3), ist noch zu verifizieren. Falls nicht, trägt diesen Nachweis allein der Cross-App-Test AC-5.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test belegt (AC-1 bis AC-6)
- [ ] Ein Bon-Foto lässt sich aus der Fotos-App über „Teilen" an „Restock" übergeben: die Erweiterung zeigt die Erfolgsansicht mit der Anzahl erkannter Positionen, statt nach rund drei Sekunden zu verschwinden
- [ ] Nach diesem Ablauf liegt kein neuer Absturzbericht `RestockShareExtension-*.ips` unter `~/Library/Logs/DiagnosticReports/`
- [ ] Der Geräteabgleich der Haupt-App läuft unverändert weiter — die CloudKit-Spiegelung im App-Prozess ist nachweislich aktiv (AC-3, ersatzweise AC-5)
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün, AC-6)

## Acceptance Criteria

- **AC-1:** Given der App-Prozess (Unit-Test-Host `Restock.app`) / When die Erweiterungserkennung mit `Bundle.main.bundleURL` aufgerufen wird / Then liefert sie `false`.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-2:** Given eine `URL` mit der Pfad-Endung `.appex` / When die Erweiterungserkennung mit dieser `URL` aufgerufen wird / Then liefert sie `true`.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-3:** Given der App-Prozess / When `make()` aufgerufen wird / Then bleibt die CloudKit-Spiegelung aktiv (die erste, erfolgreiche Konfiguration ist die CloudKit-Variante — sofern `ModelConfiguration.cloudKitContainerIdentifier` lesbar ist; andernfalls trägt AC-5 diesen Nachweis).
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-4:** Given ein als App-Erweiterung erkannter Bundle-Pfad / When der `make()`-Ablauf für diesen Pfad ausgewertet wird / Then wird weder ein CloudKit-Konfigurationsversuch unternommen noch `backupLocalStoreBeforeFirstCloudAttempt()` ausgeführt, und der lokale App-Gruppen-Store wird direkt geöffnet.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-5:** Given die Fotos-App mit dem Testbild in der Bibliothek des Simulators (iPhone 17 / iOS 27.0) / When der Nutzer das letzte Bild über „Teilen" an „Restock" übergibt / Then zeigt die Erweiterung die Erfolgsansicht „N Positionen … erkannt", die Nutzlast liegt unter `pendingShareExtensionReceipt` in der App-Gruppe, und es entsteht kein neuer Absturzbericht `RestockShareExtension-*.ips`.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-6:** Given die bestehenden Tests `SchemaCloudKitCompatibilityTests` und `ExistingDataSurvivesCloudEnableTests` / When sie nach der Änderung erneut ausgeführt werden / Then bleiben beide grün (keine Regression).
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*

## Test Plan

### Automated Tests (TDD RED)
- [ ] Test 1: GIVEN der App-Prozess (Test-Host `Restock.app`) WHEN die Erweiterungserkennung mit `Bundle.main.bundleURL` aufgerufen wird THEN liefert sie `false`.
- [ ] Test 2: GIVEN eine `URL`, deren letzte Pfadkomponente auf `.appex` endet (z. B. `RestockShareExtension.appex`) WHEN die Erweiterungserkennung mit dieser `URL` aufgerufen wird THEN liefert sie `true`.
- [ ] Test 3: GIVEN der App-Prozess WHEN `make()` aufgerufen wird THEN wird — sofern `ModelConfiguration.cloudKitContainerIdentifier` lesbar ist — die CloudKit-Konfiguration verwendet, nicht die lokale.
- [ ] Test 4: GIVEN ein als Erweiterung erkannter Bundle-Pfad WHEN `make()` (bzw. die interne Verzweigungslogik) mit diesem Pfad ausgewertet wird THEN wird kein CloudKit-Konfigurationsversuch unternommen und `backupLocalStoreBeforeFirstCloudAttempt()` nicht ausgeführt.
- [ ] Test 5 (Cross-App, XCUITest, Simulator iPhone 17 / iOS 27.0): GIVEN die Fotos-App mit dem Testbild (`~/.claude/uploads/825e909c-a32a-4c05-a27e-7fd41a005c37/99bb697a-image.png`) in der Bibliothek WHEN das letzte Bild geteilt und „Restock" gewählt wird THEN zeigt die Erweiterung die Erfolgsansicht „N Positionen … erkannt", die Nutzlast liegt unter `pendingShareExtensionReceipt` in der App-Gruppe, und unter `~/Library/Logs/DiagnosticReports/` entsteht kein neuer `RestockShareExtension-*.ips`-Absturzbericht.
- [ ] Test 6 (Regression): GIVEN `RestockTests/SchemaCloudKitCompatibilityTests.swift` und `RestockTests/ExistingDataSurvivesCloudEnableTests.swift` WHEN sie nach der Änderung ausgeführt werden THEN bleiben beide grün.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — es gibt im Projekt kein formales ADR-Verzeichnis (`docs/adr/` existiert nicht). Die betroffene Festlegung ist ausschließlich als Kommentar in `SharedModelContainer.swift` (Z. 29-36) dokumentiert.
- **Rationale:** Der bestehende Kommentar verbietet ausdrücklich „per-process branching" in `make()`, weil bisher die Fallback-Reihenfolge für jeden Prozess identisch sein musste, um die im Kommentar dokumentierte historische Datenverlust-Ursache (abweichende Schema-Deklaration je Aufrufer) nicht zu wiederholen. Dieser Fix kippt diese Festlegung gezielt, aber eng begrenzt: verzweigt wird ausschließlich auf die Frage „läuft dieser Prozess als App-Erweiterung?", niemals auf Schema oder Store-Adressierung — beide bleiben für alle Prozesse identisch, damit die ursprüngliche Absicherung erhalten bleibt. Die Rücknahme wird im Kommentar selbst datiert vermerkt, nicht stillschweigend gelöscht (Repo-Konvention, siehe `docs/context/fix-4-share-extension-cloudkit.md`, Abschnitt „Existing Patterns"). Geprüfte und verworfene Alternative: ein Parameter `make(cloudKit:)` mit zwei benannten Einstiegspunkten, sodass jeder Aufrufer explizit entscheidet — verworfen, weil er die Fehlerquelle von einer zentralen Weiche auf acht Aufrufstellen in vier Dateien verlagert, genau die Aufrufer-Divergenz, wegen der `SharedModelContainer` überhaupt als Einzelpunkt existiert.

## Changelog

- 2026-09-20: Initial spec created
