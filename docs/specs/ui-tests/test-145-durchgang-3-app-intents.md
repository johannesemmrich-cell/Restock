---
entity_id: test-145-durchgang-3-app-intents
type: test
created: 2026-10-16
updated: 2026-10-16
status: draft
workflow: test-145-d3-app-intents-testing
tags: [test, ui-test, siri, app-intents, appintentstesting, ios27, issue-145, issue-98]
---

# Siri-/Kurzbefehl-Intents über den Systemweg mit AppIntentsTesting (Issue #145, Durchgang 3, Teil 4)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Issue #145 bündelt die offenen Testlücken aus #98. Dieser Durchgang schließt Teil 4: Die Intents
`AddShoppingItemIntent` (Siri „Artikel hinzufügen“) und `CheckOffItemIntent` (Abhaken per Dynamic Island,
Sperrbildschirm, Widget) werden mit Apples `AppIntentsTesting` (Xcode 27, iOS 27) **im eigenen Prozess über den
Systemweg** ausgeführt, so wie Siri und Kurzbefehle es tun, und ihre Wirkung wird in der echten App-Oberfläche
geprüft. Bisher (#98 Durchgang 8) war nur die ausgelagerte Logik per direktem Aufruf geprüft (`AddItemIntentTests`,
`CheckoffQueueTests`), nicht der Weg über das System: Metadaten-Auflösung, Prozessstart des Intents, App-Gruppen-
Speicher aus einem zweiten Prozess, Warteschlange bis zur Anzeige.

Ticket-DoD von #145: Test des echten Wegs ODER belegte Begründung. Der Probelauf vom 2026-10-16 belegt, dass der
echte Weg im iOS-27-Simulator läuft. Produktcode bleibt unverändert.

**Ticket-Rahmen:** #145 hat vier Durchgänge, die Scoping-Limits gelten je Durchgang (Memory „#98 ein Ticket,
mehrere Durchgänge“). Vorgänger: `docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md`. Analyse:
`docs/context/test-145-d3-app-intents-testing.md`. Durchgang 4 (Kauf/Wiederherstellen) ist nicht Teil dieser Spec.

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Geprüft wird die Wirkung der Intents nach dem Aufruf über
`AppIntentsTesting`, nicht der Aufruf durch Siri-Stimme, Widget-Tipp, Live-Activity-Tipp oder Control. Der Lauf
findet lokal auf einem iOS-27-Wegwerf-Simulator statt, nicht in der CI. Nichts wird auf Hennings Geräten geprüft.
Einzelheiten im Abschnitt „Offene Grenzen“.

## Recherche und Probelauf (belegt, vor der Analyse)

Gemäß Regel „Recherche zuerst“. Belege: `docs/artifacts/test-145-d3-app-intents-testing/` (`probe-tests.swift.txt`,
`run-probe.sh.txt`, `probe-log-auszug.txt`).

1. **API und Plattform.** WWDC26 Session 295 „Validate your App Intents adoption with AppIntentsTesting“
   (https://developer.apple.com/videos/play/wwdc2026/295/): Tests liegen in einem XCUITest-Bundle, Intents werden
   per Bundle-ID und Name gefunden und out-of-process ausgeführt. Externe Berichte (Gubarenko, Berthly-Issue #189)
   nennen „nur macOS 27“; **am Werkzeug widerlegt:** Die `swiftinterface` in Xcode 27.1 (27A9275) trägt
   `@available(macOS 27.0, iOS 27.0, …)`, das Framework liegt unter `iPhoneSimulator.platform`. Der Probelauf auf
   iOS 27.0 (24A434) bestätigt, dass es im iOS-Simulator läuft.
2. **Aufruf.** `IntentDefinitions(bundleIdentifier: "com.johannesemmrich.Restock").intents["AddShoppingItemIntent"]`
   (Swift-Typname ohne Modulpräfix; mit Präfix `Restock.` ebenfalls auflösbar, aber nicht nötig), dann
   `.makeIntent(itemName: …)` und `.run()`. Die App muss beim `run()` laufen. Namen laut `Metadata.appintents`:
   `AddShoppingItemIntent`, `CheckOffItemIntent`, `QuickAddControlIntent`. Das Ergebnis (`ResolvedIntentResult`)
   liefert hier `valueContainer: nil`; **der Dialogtext ist nicht lesbar.** Folge: Die Wirkung wird in der App
   geprüft, nie über das `run()`-Ergebnis.
3. **Kompiliert ohne Projektänderung.** `#if canImport(AppIntentsTesting)` plus `#available(iOS 27.0, *)`,
   Deployment Target bleibt 18.0, kein Linken nötig (Framework liegt neben XCTest).
   **Nachtrag Umsetzung (2026-10-16, belegt):** Mit Xcode 27.1 gebaut lädt das ganze Paket `RestockUITests` auf
   einem iOS-26.5-Simulator nicht mehr (`Library not loaded: …/AppIntentsTypeSupport.framework`, harte Abhängigkeit
   von `AppIntentsTesting`), `XCTSkip` greift nie. Bekannt aus Fremdberichten
   (https://github.com/coryparrry/Intents/pull/60). Daher steht die Klasse zusätzlich hinter der eigenen
   Kompilierbedingung `APPINTENTS_UITESTS`, die nur das Skript setzt (PO-Wahl 2026-10-16).
4. **Add (belegt).** „Probe Zahnpasta“ landet über die Drogerie-Zuordnung in **dm**, nicht in Lidl; sichtbar in
   Kachel und Liste. `run()` dauert 3 bis 5,5 s.
5. **Fehler 400 unter Last (belegt, Ursache offen).** Versuch 2 bei Rechnerlast ca. 600: jedes `run()` scheitert mit
   `AppIntentsServicesMetadataErrorDomain Code=400 "com.johannesemmrich.Restock is not present"`, dazu
   `kAXErrorIPCTimeout`. Bei Last ca. 2 mit Wiederholschleife grün, 400 trat nicht mehr auf. Websuche ohne Treffer.
   Folge: Wiederholung nur für genau diesen Fehler (AC-5), die Ursache wird nicht behauptet.
6. **CheckOff (belegt).** Eine offene Liste des Ladens startet die Live Activity. `CheckOffItemIntent(storeName:
   "dm").run()` meldet Erfolg, die **offene** Liste ändert sich nicht sofort; nach Verlassen und Wiederöffnen ist
   der erste Artikel erledigt. Grund: Der Intent legt die UUID nur in die Warteschlange und sendet eine
   Darwin-Notification (`handlePendingCheckoff` aktualisiert nur die Insel); gespeichert wird in
   `StoreDetailView.applyPendingCheckoffs()` (`onAppear`, `scenePhase == .active`). Im echten Gebrauch ist die
   Insel nur bei Hintergrund-App sichtbar, daher der Testablauf „Liste öffnen, Home, Intent, App aktivieren“.
   Bewertung: kein Produktfehler, ausgelegtes Design aus #98.
7. **Gegenprobe (belegt).** Bei geschlossener Liste (Activity beendet) meldet `run()` Erfolg und ändert nichts
   (`checkoff(closed) OK`, danach unverändert „1 von 2 erledigt“). Beobachtung „stiller Erfolg ohne Wirkung“, siehe
   „Offene Grenzen“.
8. **CI.** GitHub-Image `xcode-27`/`xcode-27-xlarge` (Public Preview seit 2026-07-16, seit 2026-09-10 auf macOS 27,
   Xcode 27.0/27.1/27.2 beta), kein GA-Termin; `macos-26` (heutige CI) hat nur Xcode 26.6 und kennt das Framework
   nicht. Testrunner und App brauchen dasselbe Team, sonst `AppIntentsServicesSecurityErrorDomain 800` (berichtet
   für macOS, Berthly PR #191; für den iOS-Simulator unbelegt).
   https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md ·
   https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27 ·
   https://github.com/henrywang/Berthly/pull/191

**Regel vor Modell:** Kein Modell beteiligt, deterministische Testlogik. „Ohne Systemweg geht es nicht“ gilt hier
nicht für die Logik (die hat #98 D8), wohl aber für die Aussage „der Intent funktioniert, wenn das System ihn
ruft“; die ist nur über den Systemweg zu belegen.

## Source

Produktcode wird nicht geändert; gelesen werden:

- `SmartCart/Intents/AddItemIntent.swift` — `AddShoppingItemIntent` (`itemName`, `quantity`, `unit`), schreibt über
  `SharedModelContainer.make()`; `add(name:quantity:unit:in:)` und `perform()` speichern.
- `SmartCart/Intents/CheckOffItemIntent.swift` — `LiveActivityIntent`; wirkt nur mit laufender
  `Activity<ShoppingActivityAttributes>` des Ladens, sonst keine Warteschlange.
- `SmartCart/Models/CheckoffQueue.swift` — `enqueue`, `effectivePending`, `drain`.
- `SmartCart/Views/Store/StoreDetailView.swift` — `applyPendingCheckoffs()` (`onAppear`, `scenePhase`).
- `SmartCart/SmartCartApp.swift` — DEBUG-Seed `-seedQuickAddAssignmentForUITests` (Lidl „Lebensmittel“, dm
  „Drogerie“) und Aufräumer `-clearQuickAddAssignmentSeedForUITests`, hier unverändert wiederverwendet.
- `SmartCart/Services/AssignmentService.swift` — Zuordnung Drogerie-Stichwort → dm.
- `RestockUITests/UITestWait.swift`, `RestockUITests/QuickAddControlUITests.swift`,
  `scripts/run-notification-permission-uitest.sh` — Muster für Wartehilfen, gesäte Tests und Wegwerf-Simulator.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `AppIntentsTesting` (Xcode 27.1, iOS 27.0) | framework | `IntentDefinitions`, `makeIntent`, `run()` im Systemweg |
| iOS-27.0-Simulator-Runtime (24A434) | tool | Wegwerf-Simulator je Lauf, `iPhone 17 Pro` |
| `-seedQuickAddAssignmentForUITests` / `-clearQuickAddAssignmentSeedForUITests` | launch arg (DEBUG) | Läden Lidl und dm; Aufräumen im `tearDown()` |
| `AssignmentService.assign` | service | Drogerie-Artikel landet in dm |
| `LiveActivityService`, `StoreDetailView.applyPendingCheckoffs`, `CheckoffQueue` | product | Kette beim CheckOff |
| `RestockUITests/UITestWait.swift` | test | `UITestLaunch`, `waitUntilHittable`, `waitForLabel(contains:)`, neuer Helfer |
| `scripts/run-notification-permission-uitest.sh` | script | Vorlage für Sperren, Wegwerf-Simulator, Auswertung |
| `/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock` | lock | Abstimmung schwerer Läufe mit anderen Sitzungen (Memory „Schwere Läufe mit anderen Sitzungen abstimmen“) |
| Simulator `Restock-Validate` | tool | bleibt unberührt (iOS 26.5, Bestandssuite) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/AppIntentsUITests.swift` | CREATE | Klasse `AppIntentsUITests`, ganz in `#if canImport(AppIntentsTesting) && APPINTENTS_UITESTS`, T1 bis T3, `tearDown()` räumt Seed auf (ca. +130) |
| `RestockUITests/UITestWait.swift` | MODIFY | Helfer `AppIntentRetry.runIntentRetrying`, wiederholt nur bei Code 400 „is not present“, mit Messzeile, dazu `AppIntentRetryTests` (ca. +100) |
| `scripts/run-appintents-uitest.sh` | CREATE | Sperren, Wegwerf-Simulator iOS 27, Build einmal mit `APPINTENTS_UITESTS`, `test-without-building`, Auswertung (ca. +70) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Testdatei im UI-Testziel registrieren, vier Stellen (ca. +4) |
| `CLAUDE.md` | MODIFY | Absatz „Durchgang 3“ (Doku) |

### Estimated Changes

- Code-Dateien: 4 (Testklasse, Helfer, Skript, pbxproj; Limit 4–5), dazu Doku (`CLAUDE.md`, diese Spec).
- LoC: ca. +330 / −0 (Limit ±250; Überschreitung vom PO am 2026-10-16 freigegeben, Grund: Helfer-Prüfungen und
  Kompilierbedingung). Das LoC-Gate zählt Testcode als Produktivcode (Memory „LoC-Gate zählt Testcode
  als Produktivcode“); vor Abschluss `git diff --stat` gegen den Tip-Commit prüfen, bei Überschreitung STOP.
- Produktcode: unverändert. Keine neuen Strings, Dependencies, `Info.plist`-, `@AppStorage`- oder Scheme-Änderung.
- Seiteneffekte: Die Klasse ist in jedem Bau ohne `APPINTENTS_UITESTS` (CI, Xcode, Restock-Validate) eine leere
  Datei; `AppIntentRetryTests` laufen überall mit.
  Das Skript hinterlässt keinen Wegwerf-Simulator und lässt `Restock-Validate` unberührt.

### Nicht-Ziele

- Keine Produktänderung, auch nicht am „stillen Erfolg ohne Wirkung“ von `CheckOffItemIntent` (nur Beobachtung).
- Kein CI-Anschluss, keine Änderung an `ci.yml`, `HEAVY_CLASSES` oder am Scheme.
- Keine Prüfung von `QuickAddControlIntent` (hat `QuickAddControlUITests`) und des Dialogtexts.
- Kein neues DEBUG-Launch-Argument.

## Definition of Done

- [ ] T1 bis T3 laufen im Skript auf einem iOS-27-Wegwerf-Simulator grün, Protokoll abgelegt (AC-1 bis AC-3, AC-9 bis AC-12)
- [ ] Drei Läufe in Folge grün, mindestens einer unter Rechnerlast (AC-13)
- [ ] CI-Build (Xcode 26.6) bleibt grün, Klasse kompiliert ohne `APPINTENTS_UITESTS` leer; Bestandssuite auf `Restock-Validate` lädt und ist grün (AC-6, AC-14)
- [ ] `CLAUDE.md`-Absatz vorhanden, offene Grenzen in Ticket und Bericht benannt (AC-15, AC-16)
- [ ] Diff innerhalb der Limits, Produktcode unverändert (AC-17)

## Implementation Details

### Testklasse `AppIntentsUITests`

- **Kopf:** Die ganze Datei steht in `#if canImport(AppIntentsTesting) && APPINTENTS_UITESTS` (`import
  AppIntentsTesting` darin). Ohne die Bedingung (CI, normaler Xcode-Lauf, Restock-Validate) ist die Datei leer, das
  Paket lädt auch auf iOS 26. Jeder Test beginnt mit `guard #available(iOS 27.0, *) else { throw XCTSkip(…) }`. Der
  Kopfkommentar nennt die offenen Grenzen (AC-16).
- **Start:** `UITestLaunch` bzw. `XCUIApplication` mit `-hasCompletedOnboarding YES
  -seedQuickAddAssignmentForUITests`. **Nie** `-developerMode`, `-notificationsEnabled` oder andere Argumente, die in
  der Argument-Domain Schreibzugriffe überlagern. Die App läuft beim `run()` (Voraussetzung von
  `AppIntentsTesting`) und wird nicht vorher beendet.
- **Intent-Aufruf:** über den Helfer `runIntentRetrying` (siehe unten), nie direkt. Aufgelöst wird
  `IntentDefinitions(bundleIdentifier: "com.johannesemmrich.Restock").intents["…"]`.
- **Prüfung immer am App-Zustand:** Das Ergebnis von `run()` wird nie ausgewertet, weil es auch bei Wirkungslosigkeit
  Erfolg meldet (Probelauf, Gegenprobe). Gelesen wird über Kachelbeschriftung der Startseite
  (`label BEGINSWITH "dm,"`/`"Lidl,"`) und die Listenansicht des Ladens (`staticTexts`), mit `UITestWait`-Hilfen
  statt fester Fristen (Memory „CI-UI-Abfragen dauern 4 s“, „Wartezeiten bei kaltem Start“).
- **T1 `testAddIntentPutsItemIntoDm`:** Seed starten → `AddShoppingItemIntent` mit `itemName: "Zahnpasta"` ausführen →
  App neu starten bzw. in den Vordergrund holen (die App liest den von außen geschriebenen Stand beim Start) →
  Kachel „dm“ enthält „Zahnpasta“, Liste von dm zeigt den Artikel, Kachel „Lidl“ und Liste von Lidl nicht.
- **T2 `testCheckOffIntentChecksFirstItem`:** Seed, zwei Artikel (Add per Intent, Namen aus dem Test) in dm →
  Liste dm öffnen (startet die Live Activity) → `XCUIDevice.shared.press(.home)` → `CheckOffItemIntent` mit
  `storeName: "dm"` ausführen → App wieder aktivieren, Liste öffnen → der **erste** Artikel steht unter „Erledigt“,
  der zweite bleibt offen („1 von 2 erledigt“).
- **T3 `testCheckOffWithClosedListChangesNothing` (Gegenprobe):** gleiche Ausgangslage, Liste ist **geschlossen**
  (Startseite; die Liste wird in diesem Test vor dem Intent nie geöffnet, also läuft für diese Artikel keine
  Activity, keine Gnadenfrist nötig) → `CheckOffItemIntent` ausführen → Liste öffnen → nichts erledigt („0 von 2 erledigt“), obwohl `run()`
  Erfolg gemeldet hat. Der Test belegt damit, dass T2 nicht leer läuft.
- **`tearDown()`:** Startet die App mit `-hasCompletedOnboarding YES -clearQuickAddAssignmentSeedForUITests` und
  beendet sie (Pflicht laut `CLAUDE.md`: App-Gruppe überlebt den Test). Das Muster ist im Probelauf belegt.

### Helfer `runIntentRetrying` (`UITestWait.swift`)

- Ruft den Intent auf; fängt nur einen Fehler mit Domain `AppIntentsServicesMetadataErrorDomain`, Code 400 und
  Text „is not present“ ab und wiederholt dann alle 0,5 bis 1 s, insgesamt höchstens ca. 10 s (im Probelauf waren es
  bis zu 18 Versuche im Abstand von 10 s; die endgültige Frist wird in der Umsetzung gemessen und in der Messzeile
  belegt). Jeder andere Fehler wird sofort weitergereicht, ohne Wiederholung. Nach Ablauf der Frist wird der letzte
  400-Fehler geworfen (Test rot, mit Meldung).
- **Messzeile:** Bei jeder Wiederholung und beim Erfolg nach Wiederholung schreibt der Helfer eine Zeile ins
  Testprotokoll (`AppIntents: Wiederholung n nach x s wegen 400 …`, Rechnerlast soweit ermittelbar, sonst
  `unbekannt`). Es ist eine Messung, keine Erklärung der Ursache.
- Der Helfer steht in `UITestWait.swift` ohne Import des Frameworks (nur `Error`/`NSError`), baut und läuft daher
  überall; `AppIntentRetryTests` prüfen ihn mit Scheinuhr (T8).

### Skript `scripts/run-appintents-uitest.sh`

Aufruf: `scripts/run-appintents-uitest.sh`. Gerätetyp `iPhone 17 Pro`, Runtime iOS 27.0 (24A434) werden aus
`simctl list` aufgelöst; `Restock-Validate` wird weder gebootet noch verändert. `DEVELOPER_DIR` zeigt auf
Xcode 27.1 (`/Applications/Xcode.app`).

1. **Sperren:** `mkdir /tmp/heavy-build.lock`, dann `mkdir /tmp/loose-ends-testlauf.lock`, jeweils mit `owner`-Datei
   (`run-appintents-uitest <zweck> <datum>`). Ist eine belegt: Abbruch mit Meldung samt fremdem `owner`-Inhalt,
   Exitcode ≠ 0, schon genommene erste Sperre wird freigegeben, fremde Sperren werden nie gelöscht. `trap`
   entfernt nur selbst angelegte Sperren.
2. **Einmal bauen:** `xcodebuild build-for-testing` (Scheme `Restock`, Ziel `generic/platform=iOS Simulator`,
   eigener `-derivedDataPath`, als einzige zusätzliche Einstellung
   `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APPINTENTS_UITESTS'` (`DEBUG` bleibt erhalten, belegt durch die
   DEBUG-Seeds der Tests); nichts an der Signierung, Memory „CODE_SIGNING_ALLOWED=NO bricht die App-Gruppe“).
3. **Wegwerf-Simulator:** `simctl create "Restock-AppIntents-<zeit>" … iOS-27-0` → `boot` + `bootstatus -b` →
   `simctl install` → `xcodebuild test-without-building -destination id=<udid>
   -only-testing:RestockUITests/AppIntentsUITests -resultBundlePath … -collect-test-diagnostics never` → `shutdown`
   + `delete`. Ein Hänger-Timeout beendet `xcodebuild`, wenn nach dem letzten Testergebnis länger als ca. 15 min
   nichts passiert (Muster #21: im Probelauf ca. 10 min Hänger nach dem Test).
4. **Auswertung (Null-Test-Lauf ist kein Grün):** Aus Protokoll bzw. `xcresulttool` werden gelesen: ausgeführte
   Tests, Fehlschläge, Übersprungene. Grün nur bei genau 3 gelaufenen Tests, 0 Fehlschlägen, 0 Übersprungenen und
   ohne Abbruch („Executed 0 tests“, „Restarting after unexpected exit“, „TEST EXECUTE FAILED“ gelten als Rot).
   Übersprungene Tests im Skriptlauf sind Rot, weil sie auf iOS 27 laufen müssen.
5. **Schlusszustand:** Der Wegwerf-Simulator ist gelöscht (auch per `trap` bei Fehlschlag), `simctl list devices`
   enthält keinen Namen `Restock-AppIntents-<zeit>`, `Restock-Validate` ist unverändert.
6. **Ausgabe:** Ergebnisblock mit Commit-Kennung, Xcode-/Runtime-Stand, Zeitstempel, Rechnerlast zu Beginn,
   Testzahl, Fehlschlägen, Anzahl der 400-Wiederholungen (aus den Messzeilen), Pfad des Ergebnisbündels und
   „Wegwerf-Simulatoren nach dem Lauf übrig: nein (muss: nein)“. Protokolle unter
   `docs/artifacts/test-145-d3-app-intents-testing/`.

### Nachweis

Drei Läufe des Skripts hintereinander, mindestens einer unter künstlicher Rechnerlast (Muster „Leerer UI-Test-Start
nur unter Last“: Nachweise unter Last fahren). Die Bestandssuite läuft unverändert auf `Restock-Validate`
(iOS 26.5) und bleibt grün; die neue Klasse trägt dort nichts bei.

### Durchlauf (Pflicht, „Die App wird benutzt, nicht nur gebaut“)

Der Skriptlauf **ist** der Durchlauf: Er installiert den Stand auf einem frischen iOS-27-Simulator, startet die App,
ruft die Intents über den Systemweg und liest das Ergebnis in der App. Ergänzend je ein Screenshot (Kachel dm nach
Add, Liste nach CheckOff). Registrierung als Artefakt aus dem echten Lauf (Commit-Kennung und Zeitstempel passend,
nie von Hand gesetzt).

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED vor Umsetzung): `AppIntentsUITests.testAddIntentPutsItemIntoDm` — GIVEN gesäte Läden Lidl und dm,
  WHEN `AddShoppingItemIntent(itemName: "Zahnpasta")` über `AppIntentsTesting` läuft, THEN steht der Artikel in der
  dm-Kachel und -Liste und nicht in Lidl.
  RED-Beleg: Die Klasse existiert noch nicht bzw. der Test fällt an der ersten belegten Stelle (Helfer fehlt).
- [ ] T2 (RED): `testCheckOffIntentChecksFirstItem` — GIVEN dm-Liste mit zwei Artikeln geöffnet und App im
  Hintergrund (Home), WHEN `CheckOffItemIntent(storeName: "dm")` läuft und die App aktiviert wird, THEN ist der
  erste Artikel erledigt, der zweite offen.
- [ ] T3 (RED): `testCheckOffWithClosedListChangesNothing` — GIVEN dieselbe Ausgangslage, aber Liste geschlossen,
  WHEN der Intent läuft (`run()` meldet Erfolg), THEN ist nach dem Öffnen der Liste nichts erledigt.
- [ ] T4: Bestandssuite — GIVEN Xcode 26.6 bzw. iOS-26-Simulator `Restock-Validate`, WHEN die Suite läuft, THEN
  baut das Ziel (Klasse ohne `APPINTENTS_UITESTS` leer), das Paket lädt und alle Bestandstests sowie
  `AppIntentRetryTests` sind grün; Testzahl geprüft.
- [ ] T5: Skript `scripts/run-appintents-uitest.sh` — GIVEN freie Sperren und Xcode 27.1, WHEN es läuft, THEN genau
  3 Tests gelaufen, 0 Fehlschläge, 0 Übersprungene, am Ende kein Wegwerf-Simulator übrig, `Restock-Validate`
  unberührt.
- [ ] T6: Skript bei belegter Sperre — GIVEN ein Verzeichnis `/tmp/heavy-build.lock` mit fremder `owner`-Datei,
  WHEN das Skript startet, THEN bricht es mit Meldung samt `owner`-Inhalt ab, verändert nichts, die fremde Sperre
  besteht weiter.
- [ ] T7: Wiederholung — GIVEN drei Skriptläufe hintereinander, davon einer unter Last, THEN alle grün; die
  Messzeilen zeigen etwaige 400-Wiederholungen.
- [ ] T8: Retry-Helfer — GIVEN ein Fehler `AppIntentsServicesMetadataErrorDomain` Code 400 „is not present“,
  WHEN er auftritt, THEN wiederholt der Helfer mit Messzeile; GIVEN ein anderer Fehler, THEN wirft er sofort ohne
  Wiederholung (Code-Prüfung am Helfer, belegt durch Review und Messzeile im Lauf).
- [ ] T9: Diff gegen den Tip-Commit — nur die genannten Dateien, ca. +330 LoC, Produktcode unverändert.

## Acceptance Criteria

- **AC-1:** GIVEN gesäte Läden Lidl und dm, WHEN `testAddIntentPutsItemIntoDm` den `AddShoppingItemIntent` über
  `AppIntentsTesting` ausführt, THEN erscheint der Artikel in der dm-Kachel und in der dm-Liste und **nicht** in
  Lidl (Kachel und Liste). Test: T1.
- **AC-2:** GIVEN die dm-Liste mit zwei Artikeln war geöffnet und die App liegt im Hintergrund (Home), WHEN
  `testCheckOffIntentChecksFirstItem` den `CheckOffItemIntent` für dm ausführt und die App wieder aktiviert wird,
  THEN ist der erste Artikel erledigt („1 von 2 erledigt“), der zweite offen. Test: T2.
- **AC-3:** GIVEN die Liste ist geschlossen, WHEN `testCheckOffWithClosedListChangesNothing` den Intent ausführt
  (auch wenn `run()` Erfolg meldet), THEN ist nach dem Öffnen der Liste kein Artikel erledigt („0 von 2 erledigt“).
  Test: T3.
- **AC-4:** GIVEN die Tests T1 bis T3, WHEN sie ihre Aussage prüfen, THEN lesen sie ausschließlich den Zustand der
  App-Oberfläche und werten das Ergebnis von `run()` nie aus (kein `XCTAssert` auf dem Rückgabewert). Test: T9
  (`grep` bzw. Review der Klasse).
- **AC-5:** GIVEN `runIntentRetrying`, WHEN ein Aufruf mit `AppIntentsServicesMetadataErrorDomain` Code 400 und Text
  „is not present“ scheitert, THEN wird innerhalb einer festen Frist wiederholt und je Wiederholung eine Messzeile
  ins Testprotokoll geschrieben; WHEN ein anderer Fehler auftritt, THEN wird er sofort ohne Wiederholung
  weitergereicht; nach Fristablauf wird der letzte 400-Fehler geworfen. Test: T8, T7.
- **AC-6:** GIVEN Xcode 26.6 (CI) oder Xcode 27.1 mit einem iOS-26-Simulator, WHEN das UI-Testziel ohne
  `APPINTENTS_UITESTS` gebaut und die Suite gefahren wird, THEN steht die gesamte Datei `AppIntentsUITests.swift`
  hinter `#if canImport(AppIntentsTesting) && APPINTENTS_UITESTS`, der Helfer importiert das Framework nicht, jeder
  Test beginnt mit `#available(iOS 27.0, *)` und springt sonst per `XCTSkip` mit Grund, das Paket lädt und der Build
  bleibt grün. Test: T4.
- **AC-7:** GIVEN die Launch-Argumente der Klasse, WHEN sie geprüft werden, THEN sind es nur
  `-hasCompletedOnboarding YES` und der Seed `-seedQuickAddAssignmentForUITests` (plus die von `UITestLaunch`
  gesetzten); `-developerMode` und `-notificationsEnabled` kommen nicht vor (Argument-Domain-Falle). Test: T9
  (`grep`).
- **AC-8:** GIVEN jeder Testlauf (auch bei Fehlschlag), WHEN `tearDown()` läuft, THEN startet es die App mit
  `-clearQuickAddAssignmentSeedForUITests` und beendet sie; es bleibt kein Seed im App-Gruppen-Container. Test: T5,
  T7 (zweiter Lauf startet auf sauberem Simulator ohnehin; Prüfung im Bestandslauf T4 und per Review).
- **AC-9:** GIVEN das Skript, WHEN es startet, THEN nimmt es `/tmp/heavy-build.lock` und
  `/tmp/loose-ends-testlauf.lock` in dieser Reihenfolge per `mkdir` samt `owner`-Datei, bricht bei belegter Sperre
  mit Meldung ab, ohne die fremde Sperre anzutasten, und gibt bei jedem Ende nur selbst angelegte Sperren frei.
  Test: T5, T6.
- **AC-10:** GIVEN das Skript, WHEN es läuft, THEN baut es genau einmal (`build-for-testing`, einzige zusätzliche
  Einstellung `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APPINTENTS_UITESTS'`) und führt auf einem Wegwerf-Simulator mit Runtime iOS 27.0 `simctl install` und
  `xcodebuild test-without-building -only-testing:RestockUITests/AppIntentsUITests` aus. Test: T5.
- **AC-11:** GIVEN die Auswertung, WHEN sie läuft, THEN zählt der Lauf nur bei genau 3 gelaufenen Tests, 0
  Fehlschlägen, 0 Übersprungenen und ohne Abbruch als grün; „Executed 0 tests“, Runner-Neustart oder Übersprünge
  sind Rot (Null-Test-Lauf ist kein Grün). Test: T5.
- **AC-12:** GIVEN der Skriptlauf, WHEN er endet (grün oder rot), THEN ist der Wegwerf-Simulator gelöscht (`trap`),
  `simctl list devices` enthält keinen Namen `Restock-AppIntents-<zeit>` und `Restock-Validate` ist unverändert.
  Test: T5.
- **AC-13:** GIVEN der Nachweis, WHEN drei Skriptläufe hintereinander erfolgt sind, THEN sind alle drei grün, davon
  mindestens einer unter Rechnerlast; die Protokolle samt Messzeilen und Ergebnisblock (Commit-Kennung, Zeitstempel,
  Testzahl, Last) liegen unter `docs/artifacts/test-145-d3-app-intents-testing/`. Test: T7.
- **AC-14:** GIVEN die Bestandssuite auf `Restock-Validate` (iOS 26.5), WHEN sie nach der Änderung läuft, THEN lädt
  das Paket, sie bleibt grün mit der bisherigen Testzahl plus den 4 `AppIntentRetryTests` (die Klasse
  `AppIntentsUITests` ist dort leer); kein Abbruch, kein „Failed to load the test bundle“. Test: T4.
- **AC-15:** GIVEN der Abschluss, WHEN die Doku geprüft wird, THEN beschreibt `CLAUDE.md` Klasse, Skript, Sperren,
  Wegwerf-Simulator iOS 27, Retry-Helfer, die Kompilierbedingung `APPINTENTS_UITESTS` samt Grund (Ladefehler auf
  iOS 26), die leere Klasse in CI und Bestandssuite und die offenen Grenzen. Test: T9.
- **AC-16:** GIVEN Spec, Kopfkommentar der Klasse, `CLAUDE.md`, Ticketkommentar und Bericht, WHEN sie formuliert
  werden, THEN sind ausdrücklich als offen genannt: echter Siri-Ruf per Stimme, nicht prüfbarer Dialogtext, Tipp auf
  Widget/Live Activity/Control, CI-Anschluss (xcode-27-Runner Preview, Signierungsfehler 800 unbelegt), Fehler 400
  unter Last nur abgefangen und nicht erklärt, „stiller Erfolg ohne Wirkung“ von `CheckOffItemIntent` ohne Activity
  (Beobachtung fürs Issue), nichts auf Hennings Geräten; #145 bleibt offen (Durchgang 4). Keine Zusage lautet
  „Siri geprüft“ ohne diese Einschränkungen.
- **AC-17:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er höchstens
  `AppIntentsUITests.swift`, `UITestWait.swift`, `run-appintents-uitest.sh`, `project.pbxproj` sowie die Doku
  (`CLAUDE.md`, Spec, Artefakte), ca. +330 LoC (vom PO freigegeben); Produktcode (`SmartCart/`, `RestockShareExtension/`,
  `SmartCartWidgets/`), `ci.yml` und Scheme sind unverändert. Test: T9.
- **AC-18:** GIVEN der gesamte Durchgang, WHEN Schritte ausgeführt werden, THEN startet, installiert oder liest
  keiner ein Gerät des Users; alle Läufe nur auf Wegwerf-Simulatoren bzw. `Restock-Validate`. Test: Review des
  Skripts (`simctl`-Ziele nur selbst angelegte UDIDs).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue
- **Rationale:** Reine Testergänzung ohne Produktänderung. Wie bei Durchgang 2 läuft Zustand, der eine andere
  Werkzeug-/OS-Version braucht (hier Xcode 27/iOS 27), als Skript außerhalb der normalen Suite auf einem
  Wegwerf-Simulator; die Klasse kompiliert leer, wo das Skript die Bedingung `APPINTENTS_UITESTS` nicht setzt.

## Alternativen

Kein Modell beteiligt: deterministische Testlogik. Die Tabelle stammt aus der Analyse.

| Option | Vorteil | Nachteil / gekippte Entscheidung |
|---|---|---|
| **Lokales Skript + Skip in CI (gewählt)** | echter Weg belegt, klein, im Scope | läuft nicht automatisch bei jeder Änderung |
| CI jetzt auf `xcode-27`-Preview-Runner | automatisch | Preview, Signierung 800 unbelegt, CI-Umbau sprengt Scope; Regel „CI-Beleg nie als Pre-Push-AC“ |
| `Restock-Validate` auf iOS 27 hochziehen | dauerhaft lokal in der Suite | betrifft alle Tests, Bestandssuite wäre auf iOS 27 neu zu belegen |
| Teil 4 als „nicht automatisierbar“ schließen | kein Aufwand | durch Probelauf widerlegt, verfehlt die DoD |
| Eigenes UI-Testziel nur für AppIntents (Nachtrag Umsetzung) | Ladefehler sauber getrennt, wie im Fremdbericht | pbxproj- und Scheme-Änderung, gesch. 400+ Zeilen; vom PO am 2026-10-16 zugunsten der Kompilierbedingung verworfen |

- **Gekippte frühere Entscheidung:** die Arbeitsaussage der D8-Spec (`test-98-durchgang-8-siri-widget.md`),
  `AppIntentsTesting` sei „spätere Ergänzung, prüft nicht den Systemweg davor“ und der Annahme aus Berichten, es gebe
  das Framework nur auf macOS 27. Beides war Arbeitsstand; die swiftinterface und der Probelauf widerlegen die
  Plattformannahme. Eine ADR wird nicht gekippt.
- **Verworfen:** Teil der Logik erneut als Unit-Test (existiert seit #98 D8); `XCUIDevice.siriService` (im
  Simulator unzuverlässig, Apple-Forum, prüft die Stimme, nicht den Intent).

**Entscheidung:** Lokales Skript mit Klasse hinter `canImport` und `APPINTENTS_UITESTS`, weil es den echten Systemweg belegt, im Scope bleibt
und die CI nicht gefährdet. CI-Anschluss ist Folgeschritt in #145.

## Offene Grenzen

- **Echter Siri-Ruf per Stimme** (Phrasenerkennung, `AppShortcutsProvider`-Registrierung) ist nicht geprüft;
  `AppIntentsTesting` ruft den Intent, nicht Siri.
- **Dialogtext** ist nicht prüfbar (`ResolvedIntentResult` ohne Dialog); geprüft wird nur die Wirkung in der App.
- **Tipp auf Widget, Live Activity (Sperrbildschirm/Insel) und Control** sind im Simulator nicht ausführbar; die
  Insel-Darstellung selbst ist nicht geprüft (SpringBoard-Abfrage im Probelauf ohne Treffer).
- **CI-Anschluss:** Der `xcode-27`-Runner ist Public Preview ohne GA-Termin; ob dort die Signierung trägt
  (`AppIntentsServicesSecurityErrorDomain 800`, für den iOS-Simulator unbelegt) und ob die Läufe stabil sind, ist
  ungeprüft. Folgeschritt in #145. Bis dahin gilt nur der lokale Nachweis; in der CI und in jedem Bau ohne
  `APPINTENTS_UITESTS` kompiliert die Klasse leer. Ein Anschluss bräuchte dort dieselbe Kompilierbedingung.
- **Ladefehler auf iOS 26:** Mit `APPINTENTS_UITESTS` gebaut lädt das Paket auf iOS-26-Simulatoren nicht (siehe
  Nachtrag Recherche); das Skript fährt deshalb nur iOS 27.
- **Fehler 400 „is not present“ unter Last** wird nur abgefangen (Wiederholung mit Messzeile), nicht erklärt. Die
  Ursache (Last, Zeitpunkt der Registrierung der App-Metadaten) ist nicht bewiesen.
- **„Stiller Erfolg ohne Wirkung“:** `CheckOffItemIntent.run()` meldet Erfolg, auch wenn keine Live Activity läuft und
  nichts abgehakt wird (Gegenprobe T3). Für ein Widget/Siri wäre das ein möglicher Nutzerfehler. Beobachtung fürs
  Issue und als PO-Thema, **kein Fix in diesem Durchgang**.
- **Nichts** wird auf Hennings Geräten gestartet oder geprüft (Regel „Hennings Geräte nur auf sein Wort“).
- Prüfung nur gegen iOS 27.0 (24A434) und Xcode 27.1; andere Stände ungeprüft.

## Risiken

- **Stabilität unter Last:** Fehler 400 und `kAXErrorIPCTimeout` im Probelauf; Gegenmittel Retry-Helfer, Nachweis
  mit mindestens einem Lauf unter Last (AC-13).
- **Hänger nach dem Test:** `xcodebuild` braucht im Probelauf ca. 12 min je Lauf (ca. 10 min Hänger, Muster #21);
  Hänger-Timeout im Skript.
- **Schwere parallele Läufe:** beide Sperren (Memory „Schwere Läufe mit anderen Sitzungen abstimmen“); nie parallel
  zu anderen Simulator-Läufen.
- **CI bricht:** Ohne `canImport`-Klammer scheitert der Build unter Xcode 26.6; AC-6 und T4 sichern das ab.
- **Bestandssuite lädt nicht:** Ohne `APPINTENTS_UITESTS`-Klammer lädt das Paket unter Xcode 27 auf iOS 26 nicht
  (belegt 2026-10-16); AC-6, AC-14 und T4 sichern das ab.
- **Zustandsleck:** Seed bleibt im App-Gruppen-Container; `tearDown()` räumt auf (AC-8). Der Wegwerf-Simulator wird
  gelöscht (AC-12).
- **Null-Test-Lauf:** „Executed 0 tests … TEST SUCCEEDED“ ist kein Grün (Memory „Null-Test-Lauf ist kein Grün“);
  AC-11.
- **Test prüft Backdoor statt Weg:** Seed per Launch-Argument stellt nur Läden her; Artikel entstehen per Intent,
  Abhaken per Intent. Die App-Oberfläche liest den Stand; nichts wird von Hand in `UserDefaults` oder Speicher
  geschrieben.
- **LoC-Gate:** ca. +330, Überschreitung vom PO freigegeben (2026-10-16).
- **Gnadenfrist (T3):** Die Activity endet erst nach einer Frist (Probelauf ca. 12 s). T3 öffnet die Liste deshalb gar
  nicht; eine übrig gebliebene Activity aus T2 trägt nur die Kennungen gelöschter Artikel, die die Abarbeitung
  überspringt.

## Folge-Durchgänge im selben Ticket

- CI-Anschluss an den `xcode-27`-Runner nach GA bzw. Stabilitätsmessung, dort einmal Fehler 800 prüfen.
- Durchgang 4: Kauf/Wiederherstellen (`Restock.storekit`, `SKTestSession`).
- Beobachtung „stiller Erfolg ohne Wirkung“ als PO-Thema ins Issue.
- #145 bleibt bis dahin offen.

## Changelog

- 2026-10-16: Initial spec created (Durchgang 3 von #145; AppIntentsTesting auf iOS-27-Wegwerf-Simulator,
  Klasse hinter `canImport`, Skript, Retry-Helfer; CI-Anschluss als Folgeschritt)
- 2026-10-16 (Umsetzung, PO-`override`): Kompilierbedingung `APPINTENTS_UITESTS` nur im Skript, weil das Paket mit
  `AppIntentsTesting` auf iOS 26 nicht lädt; AC-6, AC-10, AC-14, AC-15, AC-17 und Umfang (+330) angepasst; T3 öffnet
  die Liste nicht (keine Gnadenfrist)
