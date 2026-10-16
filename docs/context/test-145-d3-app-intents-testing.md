# Context: test-145-d3-app-intents-testing

## Request Summary
#145 Teil 4 (Durchgang 3): Die Siri-/Kurzbefehl-Intents `AddShoppingItemIntent` und `CheckOffItemIntent` sollen mit
Apples `AppIntentsTesting` (Xcode 27, iOS 27) über den echten Systemweg (eigener Prozess, wie Siri/Kurzbefehle)
geprüft werden — oder es wird belegt begründet, warum nicht. PO-Wahl 2026-10-16: Siri-Test vor Kauf/CI-Anschluss.

## Recherche (2026-10-16)
- WWDC26 Session 295 „Validate your App Intents adoption with AppIntentsTesting“: Tests in einem XCUITest-Bundle,
  Intents per Bundle-ID und Name gefunden, out-of-process ausgeführt, kein geteilter Zustand.
  https://developer.apple.com/videos/play/wwdc2026/295/
- Gubarenko (Substack) und das Berthly-Spike-Issue #189 nennen es „nur macOS 27“. **Widerlegt am Werkzeug:** Die
  `swiftinterface` im lokalen Xcode 27.1 (27A9275) trägt `@available(macOS 27.0, iOS 27.0, …)`, das Framework liegt
  unter `iPhoneSimulator.platform/Developer/Library/Frameworks/AppIntentsTesting.framework` und für iPhoneOS.
  Ob es im Simulator tatsächlich läuft, ist erst mit dem Probelauf belegt (Analyse).
- API (aus der swiftinterface): `IntentDefinitions(bundleIdentifier:)` → `.intents` (DefinitionCollection von
  `AppIntentDefinition`) → `makeIntent(...)` (dynamicallyCall mit Keyword-Argumenten) → `AnyAppIntent.run()` →
  `ResolvedIntentResult` (nur `.value` per dynamic member). **Kein Zugriff auf den Dialog-Text** — die Wirkung muss
  in der App-Oberfläche oder im Speicher geprüft werden.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Intents/AddItemIntent.swift` | `AddShoppingItemIntent` (itemName, quantity, unit), schreibt über `SharedModelContainer.make()`; `add(...)` seit #98 D8 ausgelagert |
| `SmartCart/Intents/CheckOffItemIntent.swift` | `LiveActivityIntent`; wirkt nur mit laufender Live Activity des Ladens (sonst nichts in die Warteschlange) |
| `SmartCart/Models/CheckoffQueue.swift` | Warteschlange, die `CheckOffItemIntent` füllt und `StoreDetailView` abarbeitet |
| `SmartCart/SmartCartApp.swift` (Z. 416–440) | Seed `-seedQuickAddAssignmentForUITests` (Lidl Lebensmittel, dm Drogerie) und Aufräumer `-clearQuickAddAssignmentSeedForUITests` — wiederverwendbar |
| `RestockUITests/QuickAddControlUITests.swift`, `UITestWait.swift` | Muster für UI-Tests, `UITestLaunch`, Wartehilfen |
| `RestockTests/AddItemIntentTests.swift`, `CheckoffQueueTests.swift` | bestehende Logik-Tests aus #98 D8 (direkter Aufruf, kein Systemweg) |
| `scripts/run-notification-permission-uitest.sh` | Muster: Wegwerf-Simulator, Sperren, Build einmal, Auswertung |
| `.github/workflows/ci.yml` | CI: `macos-26`, Xcode 26.6 (17F113), Simulator iOS 26.5 (letzter Lauf 38864075780) |
| `Restock.xcodeproj/project.pbxproj` | UI-Testziel `com.johannesemmrich.Restock.RestockUITests`, App `com.johannesemmrich.Restock`, Mindeststand iOS 18.0 |

## Existing Patterns
- Gesäte UI-Tests: Seed-Argument beim Start, gleichnamiges Clear-Argument im `tearDown()` (Pflicht, App-Gruppe überlebt).
- Tests, die nur unter Bedingungen laufen können, überspringen sich mit Grund (`XCTSkip`) — z. B. `NotificationPermissionUITests` ohne Gate.
- Läufe auf anderem Simulator als `Restock-Validate`: eigenes Skript mit Wegwerf-Simulator und beiden Sperren
  (`/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock`).

## Dependencies
- Upstream: `AppIntentsTesting` (Xcode 27, iOS 27.0), App-Gruppen-Speicher über `SharedModelContainer.make()`,
  `AssignmentService.assign` (Zuordnung Lidl/dm).
- Downstream: keine — reine Testergänzung; Produktcode voraussichtlich unverändert.

## Existing Specs
- `docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md` — Logik-Tests, Alternative (a) = dieser Durchgang, offene Grenzen.
- `docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md` — Muster Wegwerf-Simulator/Gate.

## Risks & Considerations
- **CI kann nicht kompilieren:** Xcode 26.6 kennt `AppIntentsTesting` nicht → `import` nur hinter
  `#if canImport(AppIntentsTesting)`, sonst bricht der CI-Build. In der CI überspringt sich der Test also; der echte
  Lauf ist lokal (Xcode 27.1). Zu prüfen: gibt es einen GitHub-Runner mit Xcode 27?
- **iOS-27-Simulator nötig:** `Restock-Validate` ist iOS 26.5 → Wegwerf-Simulator mit Runtime iOS 27.0 (vorhanden, 24A434).
- **Linken:** Framework liegt im Plattform-Frameworks-Ordner (wie XCTest); ob Autolink reicht oder ein pbxproj-Eintrag
  nötig ist (der unter Xcode 26.6 bräche), klärt der Probelauf.
- **CheckOffItemIntent** tut ohne laufende Live Activity nichts. Ob die App im Simulator eine Live Activity startet und
  `Activity.activities` im Intent-Prozess sichtbar ist, ist offen → evtl. nur „ohne Activity keine Wirkung“ prüfbar,
  Rest begründete Grenze.
- **Dialog nicht prüfbar** (`ResolvedIntentResult` ohne Dialog) → Wirkung über die App-Oberfläche (Artikel in Lidl/dm).
- `SharedModelContainer.make()` im App-Prozess spiegelt nach CloudKit — im Simulator ohne Konto lokaler Rückfall.
- Offene Grenzen bleiben: echter Siri-Ruf (Stimme), Widget-/Live-Activity-Tipp, nichts auf Hennings Geräten.
- Alternative zum Ganzen: Teil 4 belegt als „nicht in CI automatisierbar“ schließen und nur lokal per Skript fahren
  (gleiches Muster wie Mitteilungsdialog).

## Analysis

### Type
Feature (Testergänzung, Teil 4 von #145). Produktcode bleibt unverändert.

### Probeläufe (2026-10-16, Wegwerf-Kopie + Wegwerf-Simulator iPhone 17 Pro, iOS 27.0 24A434, Xcode 27.1 27A9275 = /Applications/Xcode.app)
Belege: `docs/artifacts/test-145-d3-app-intents-testing/` (`probe-tests.swift.txt` = Probetest-Code, `run-probe.sh.txt` = Lauf-Skript mit Sperren/Wegwerf-Simulator/Lastwarten, `probe-log-auszug.txt`).
- **Kompiliert ohne Projektänderung:** `#if canImport(AppIntentsTesting)` + `#available(iOS 27.0, *)`, Deployment Target 18.0 bleibt, kein Linken nötig (Framework neben XCTest).
- **API:** `IntentDefinitions(bundleIdentifier: "com.johannesemmrich.Restock").intents["AddShoppingItemIntent"]` (Swift-Typname ohne Modul), `.makeIntent(itemName: …)`, `.run()`. Keine Liste aller Intents. Namen laut `Metadata.appintents`: `AddShoppingItemIntent`, `CheckOffItemIntent`, `QuickAddControlIntent`. App muss beim `run()` laufen.
- **Add:** „Probe Zahnpasta“ landete in dm (Drogerie-Zuordnung, korrekt), nicht Lidl; sichtbar in Kachel und Liste. `run()` 3–5,5 s, Ergebnis `valueContainer: nil` (Dialog nicht lesbar).
- **Fehler unter Last:** Versuch 2 (Rechnerlast ~600) alle `run()` mit `AppIntentsServicesMetadataErrorDomain Code=400 "com.johannesemmrich.Restock is not present"`, dazu `kAXErrorIPCTimeout`. Versuch 3/4 bei Last ~2 mit Wiederholschleife grün, 400 trat nicht mehr auf. Ursache nicht bewiesen (Last-Verdacht). Websuche ohne Treffer.
- **CheckOff mit Live Activity:** Offene dm-Liste startet Live Activity (Island-Screenshot „1/2“). `CheckOffItemIntent(storeName: "dm").run()` OK; offene Liste ändert sich NICHT sofort; nach Verlassen und Wiederöffnen ist der erste Artikel erledigt. Grund: Intent queued nur + Darwin-Notification (`handlePendingCheckoff` ändert nur die Island); gespeichert wird in `StoreDetailView.applyPendingCheckoffs()` (onAppear, scenePhase `.active`). Im echten Gebrauch ist die Island nur bei Hintergrund-App sichtbar → Testablauf: Liste öffnen, Home, Intent, App aktivieren, Artikel erledigt. Bewertung: kein Produktfehler (ausgelegtes Design aus #98).
- **Gegenprobe:** Liste geschlossen (Activity beendet) → `run()` meldet Erfolg, ändert nichts. Tests prüfen daher immer den App-Zustand, nie das `run()`-Ergebnis. Beobachtung „stiller Erfolg ohne Wirkung“ ins Issue, nicht in diesem Durchgang beheben.
- Laufzeit: Test 52–98 s, xcodebuild je ~12 min wegen ~10-min-Hänger nach dem Test (Muster #21).

### Recherche CI
- GitHub-Image `xcode-27` / `xcode-27-xlarge` (Public Preview seit 2026-07-16, seit 2026-09-10 auf macOS 27, Xcode 27.0/27.1/27.2 beta, iOS-27-Runtimes), kein GA-Termin. `macos-26` (heutige CI) nur Xcode 26.6 → Test kompiliert dort leer (`canImport`).
  https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md · https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27
- Signierung: Testrunner und App gleiches Team, sonst `AppIntentsServicesSecurityErrorDomain 800` (berichtet für macOS, Berthly PR #191, iOS-Simulator unbelegt). https://github.com/henrywang/Berthly/pull/191
- ActivityKit startet Live Activities im Simulator (belegt, auch selbst gesehen).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/AppIntentsUITests.swift` | CREATE | Testklasse, ganz in `#if canImport(AppIntentsTesting)`, jeder Test `#available(iOS 27.0, *)` sonst `XCTSkip`. T1 Add (Artikel per Intent → in dm sichtbar, nicht in Lidl), T2 CheckOff (Liste öffnen, Home, Intent, App aktivieren → erster Artikel erledigt), T3 Gegenprobe (Liste geschlossen → nichts erledigt). Seed `-seedQuickAddAssignmentForUITests`, tearDown `-clearQuickAddAssignmentSeedForUITests` |
| `RestockUITests/UITestWait.swift` | MODIFY | Helfer `runIntentRetrying`: wiederholt nur bei Code 400 „is not present“ (max. ~18× / 10 s), alle anderen Fehler sofort; Messzeile ins Protokoll |
| `scripts/run-appintents-uitest.sh` | CREATE | Muster `run-notification-permission-uitest.sh`: beide Sperren, Wegwerf-Simulator iOS 27, Build einmal, `test-without-building`, Auswertung Testzahl/Fehler/Skips, Hänger-Timeout, trap-Löschen |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Testdatei registrieren (4 Stellen, UI-Testziel) |
| `CLAUDE.md`, Spec | MODIFY/CREATE | Doku |

### Scope Assessment
- Files: 4 Code/Projekt + Doku
- Estimated LoC: ~+230 (Test ~130, Skript ~70, Helfer ~20, pbxproj ~4)
- Risk Level: LOW für das Produkt (nur Testcode, CI kompiliert die Datei leer), MEDIUM für Teststabilität (Fehler 400 unter Last)

### Technical Approach (Empfehlung)
Testklasse + lokales Skript auf Wegwerf-Simulator iOS 27; in der CI (Xcode 26.6) und auf iOS 26 überspringt sich der Test. Nachweis: 3 Läufe, davon mindestens einer unter Last. CI-Anschluss an den `xcode-27`-Runner als Folgeschritt im Issue (nach GA; dort einmal Fehler 800 prüfen).

### Alternativen
| Option | Vorteil | Nachteil / gekippte Entscheidung |
|---|---|---|
| **Lokales Skript + Skip in CI (empfohlen)** | echter Weg belegt, klein, im Scope | läuft nicht automatisch bei jeder Änderung |
| CI jetzt auf `xcode-27`-Preview-Runner | automatisch | Preview, Signierung 800 unbelegt, CI-Umbau sprengt Scope; Regel „CI-Beleg nie als Pre-Push-AC“ |
| `Restock-Validate` auf iOS 27 hochziehen | dauerhaft lokal in der Suite | betrifft alle Tests, Bestandssuite dann auf iOS 27 neu zu belegen |
| Teil 4 als „nicht automatisierbar“ schließen | kein Aufwand | durch Probe widerlegt, verfehlt DoD |

### Dependencies
Xcode 27.1 lokal, iOS-27.0-Runtime, Seed/Clear in `SmartCartApp.swift`, `AssignmentService` (Drogerie → dm), `LiveActivityService`, `StoreDetailView.applyPendingCheckoffs`.

### Open Questions
- [x] Läuft AppIntentsTesting im iOS-Simulator? Ja (belegt).
- [x] Ist das Nicht-Sofort-Abhaken bei offener Liste ein Fehler? Nein, Island nur im Hintergrund sichtbar.
- [ ] Keine PO-Frage offen; CI-Anschluss als Folgeschritt.
