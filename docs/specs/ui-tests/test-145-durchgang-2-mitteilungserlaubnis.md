---
entity_id: test-145-durchgang-2-mitteilungserlaubnis
type: test
created: 2026-10-15
updated: 2026-10-16
status: draft
workflow: test-145-d2-mitteilungserlaubnis
tags: [test, ui-test, notifications, system-dialog, springboard, issue-145, issue-98, ci]
---

# Mitteilungserlaubnis-Systemdialog im UI-Test (Issue #145, Durchgang 2, Teil 3)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Issue #145 bündelt die offenen Testlücken aus #98. Dieser Durchgang schließt Teil 3: Der echte Systemdialog
„„Restock“ möchte dir Mitteilungen senden“ wird in einem UI-Test bedient, und zwar **beide** Entscheidungen:
„Erlauben“ (Schalter „Nachkauf-Erinnerungen“ bleibt an) und „Nicht erlauben“ (Schalter springt auf aus).
Ticket-DoD: Test des echten Wegs ODER belegte Begründung, warum nicht automatisierbar. Die Recherche zeigt: Er
ist automatisierbar, aber nur mit **einer Entscheidung je frischem Gerät**. Deshalb je Weg ein Wegwerf-Simulator.

Stand heute: `docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md` (Abschnitt „Offene Grenzen“) hielt
fest, dass der Systemdialog nicht automatisiert ist und die Erlaubnis von außen nicht setzbar. Kein bestehender
UI-Test bedient den Schalter „Nachkauf-Erinnerungen“ (`grep` in `RestockUITests/` leer). Ein Fehler in der
Kette Schalter → Anfrage → Antwort → Schalterzustand (z. B. Schalter bleibt an trotz Ablehnung, dann plant
`HomeView.refreshDueSoon` Mitteilungen, die das System verwirft) bliebe unbemerkt.

**Ticket-Rahmen:** #145 ist ein Ticket mit vier Durchgängen; Scoping-Limits gelten je Durchgang (Memory „#98
ein Ticket, mehrere Durchgänge“). Analyse: `docs/context/test-145-d2-mitteilungserlaubnis.md`. Vorgänger:
`docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md`. Durchgänge 3 (`AppIntentsTesting`) und 4
(Kauf/Wiederherstellen) sind nicht Teil dieser Spec.

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Geprüft wird ausschließlich die Anfrage über den
**Schalter** in den Einstellungen. Die zweite Anfragestelle in der Teilen-Erweiterung bleibt ungeprüft. Der
Runner-Dialog auf iOS 26/27 mit englischem Simulator ist erst mit dem ersten CI-Lauf belegt. Nichts wird auf
Hennings Geräten geprüft. Einzelheiten im Abschnitt „Offene Grenzen“.

## Recherche (belegt, vor der Analyse)

Gemäß Regel „Recherche zuerst“; Befunde 1 und 2 zusätzlich lokal gegen Xcode 26 / das installierte SDK
geprüft.

1. **`simctl privacy` kennt keine Mitteilungen.** `xcrun simctl help privacy` listet calendar, contacts(-limited),
   location(-always), photos(-add), media-library, microphone, motion, reminders, siri, all — kein
   `notifications`. Auch `reset all` erfasst sie nicht. Die Erlaubnis lässt sich von außen weder erteilen noch
   zurücksetzen.
2. **`XCUIApplication.resetAuthorizationStatus(for:)` kennt keine Mitteilungen.** `XCUIProtectedResource` im
   SDK: contacts, calendar, reminders, photos, microphone, camera, mediaLibrary, homeKit, bluetooth,
   keyboardNetwork, location (+ macOS-Ordner). Quelle: WWDC20 10220 „Handle interruptions and alerts in UI
   tests“ — https://wwdcnotes.com/notes/wwdc20/10220
3. **Neuinstallation setzt erst nach einem Tag zurück; verlässlich ist nur ein frisches Gerät.** Apple merkt
   die Antwort auf den Mitteilungsdialog, bis die App mindestens einen Tag deinstalliert war oder das Gerät
   zurückgesetzt wird (Apple TN2265). Belegt im Lauf 2026-10-15 21:47: nach `simctl uninstall` + `install` kein
   Dialog, Schalter sofort an (`docs/artifacts/test-145-d2-mitteilungserlaubnis/notif-deny-20261015-214715.log`).
   Die früher zitierten Quellen (https://www.avanderlee.com/?p=2538,
   https://useyourloaf.com/blog/handling-system-alerts-in-ui-tests/) nennen Löschen als Rücksetzweg; für
   Mitteilungen trägt das nicht sofort.
4. **Löschen innerhalb eines XCUITests geht nicht:** Danach scheitert `launch()` mit
   `FBSOpenApplicationServiceErrorDomain Code=4 … returned nil`; XCTest installiert nicht neu, kein
   Apple-Workaround. https://developer.apple.com/forums/thread/722021 und
   https://www.jessesquires.com/blog/2021/10/25/delete-app-during-ui-tests/
5. **Der Dialog gehört SpringBoard.** Bedienbar über `XCUIApplication(bundleIdentifier:
   "com.apple.springboard").alerts` oder `addUIInterruptionMonitor`; im Repo bereits so genutzt
   (`RestockUITests/ReceiptShareExtensionTests.swift`, `dismissSystemAlerts()`, `watchForSystemDialogs()`).

**Folge:** Je frischem Gerät ist genau EINE Entscheidung testbar; danach ist der Zustand für alle folgenden Tests
festgelegt. Beide Wege brauchen zwei getrennte, frisch angelegte Simulatoren.

## Source

Zeilennummern Stand 2026-10-15; maßgeblich sind die Namen.

- **Anfrage:** `SmartCart/Services/NotificationService.swift` — `requestPermission()` (Z. 36–42) ruft
  `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])` und liefert bei
  Fehler `false`. `isAuthorized()` (Z. 48–51) zählt nur `.authorized`.
- **Schalter:** `SmartCart/Views/Settings/SettingsView.swift`, `NotificationSettingsView` (Z. 417–445):
  `Toggle(String(localized: "settings.notifications.replenish"), …)` (Z. 426), nur bei `developerMode`
  sichtbar. `onChange(of: notificationsEnabled)`: bei an `notificationsEnabled = await
  NotificationService.shared.requestPermission()`, bei aus `NotificationService.shared.cancelAll()`.
  `@AppStorage("notificationsEnabled")` hat den Default `true`.
- **Weg dorthin:** Zahnrad → Zeile „Benachrichtigungen“ (`SettingsView.swift` Z. 115–121, nur im Dev-Modus).
- **Beschriftung des Schalters:** `settings.notifications.replenish` = „Nachkauf-Erinnerungen“
  (`Resources/de.lproj/Localizable.strings` Z. 108), „Restock reminders“ (`en.lproj` Z. 108).
- **Ausgangszustand:** `SettingsView` `.task` (Z. 344–351): Ist `notificationsEnabled` an und
  `isAuthorized() == false`, wird der Schalter beim **Öffnen der Einstellungen** auf aus gesetzt. Bei frischer
  Installation (Default an, Status `.notDetermined`) steht der Schalter also nach dem Öffnen auf aus; der Test
  wartet darauf und schaltet dann an — das löst die Anfrage aus. Das ist zugleich der echte Nutzerweg.
- **Zweite Anfragestelle:** `RestockShareExtension/ShareViewController.swift` Z. 219–223
  (`requestNotificationPermissionIfNeeded`, nur bei `.notDetermined`). Das ist die Herkunft des ungewollten
  Dialogs in `ReceiptShareExtensionTests` (dort kommentiert). `AppDelegate.swift:15`
  `registerForRemoteNotifications()` zeigt keinen Dialog.
- **Bestehende Muster:** `RestockUITests/ReceiptShareExtensionTests.swift` (ENV-Gate `RESTOCK_SHARE_E2E` über
  `TEST_RUNNER_RESTOCK_SHARE_E2E=1`, `XCTSkip` ohne Gate; SpringBoard-Alert aktiv abgreifen),
  `scripts/run-share-extension-uitest.sh` (einmal bauen, per `simctl install` einspielen, einzelner Test per
  `xcodebuild test`), `RestockUITests/UITestWait.swift` (`UITestLaunch`, `waitUntilHittable`,
  `waitForLabel(contains:)`, `UITestWait.defaultTimeout`).
- **CI:** `.github/workflows/ci.yml` — `ui-test`-Matrix `half: [A, B]` (Z. 109–110), `HEAVY_CLASSES` (Z. 112),
  Schritt „Build and run UI tests“ (Z. 157–183): Hälfte A = `-only-testing:` je schwere Klasse, Hälfte B =
  `-only-testing:RestockUITests` plus `-skip-testing:` je schwere Klasse. Der Simulator wird je Job frisch
  gebootet; `simctl privacy grant camera/photos` (Z. 154–155), für Mitteilungen gibt es das nicht.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `UNUserNotificationCenter` | framework | Systemdialog, Status `.notDetermined` → `.authorized`/`.denied` |
| SpringBoard-Alert (`com.apple.springboard`) | system | Träger des Dialogs; Buttons „Erlauben“/„Nicht erlauben“ (de), „Allow“/„Don’t Allow“ (en) |
| `@AppStorage("developerMode")` | state | Sichtbarkeit von Zeile und Schalter; per `-developerMode YES` (Launch-Argument, im Test nicht geschrieben) |
| `RestockUITests/UITestWait.swift` | test | `UITestLaunch`, `waitUntilHittable`, `waitForLabel(contains:)` |
| `RestockUITests/ReceiptShareExtensionTests.swift` | test | Vorlage ENV-Gate und SpringBoard-Zugriff |
| `scripts/run-share-extension-uitest.sh` | script | Vorlage Bauen/Installieren/Testlauf |
| Simulator `Restock-Validate` | tool | Vorlage (Gerätetyp, Runtime) der Wegwerf-Simulatoren, wird nur gelesen und bleibt unberührt; nie parallel (Memory „Eigenes Testgerät je Projekt“) |
| `/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock` | lock | Abstimmung schwerer Läufe mit anderen Sitzungen (Memory „Schwere Läufe mit anderen Sitzungen abstimmen“) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/NotificationPermissionUITests.swift` | CREATE | `testAllow`, `testDeny`, ENV-Gate `RESTOCK_NOTIF_DECISION`, SpringBoard-Dialog, Meldung „Installation nicht frisch“ (ca. +130) |
| `scripts/run-notification-permission-uitest.sh` | CREATE | Sperren, einmal bauen, je Weg Wegwerf-Simulator anlegen → install → `test-without-building` → löschen, Prüfung der Testzahl, Schlusszustand: kein Wegwerf-Simulator übrig (ca. +95) |
| `.github/workflows/ci.yml` | MODIFY | Umgebungsvariable und Klassenauswahl je Hälfte (ca. +10) |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY nur falls nötig | `accessibilityIdentifier` am Schalter, falls Label-Matching nicht trägt (±2) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung der Testdatei an den vier Stellen (ca. +4) |
| `CLAUDE.md` | MODIFY | Absatz zu Klasse, ENV und Skript (Doku) |
| `docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md` | MODIFY | Hinweis „Systemdialog geschlossen durch #145 Durchgang 2“ (Doku) |

### Estimated Changes

- Code-Dateien: 4 bis 5 (Testklasse, Skript, ci.yml, pbxproj, optional SettingsView; Limit 4–5). Dazu Doku.
- LoC: ca. +215 / −0 (Limit ±250). Das LoC-Gate zählt Testcode als Produktivcode (Memory „LoC-Gate zählt
  Testcode als Produktivcode“); vor Abschluss `git diff --stat` gegen den Tip-Commit prüfen. Bei Überschreitung
  STOP und Rückfall auf „Klasse + Skript“ (ci.yml als Folgeschritt).
- Seiteneffekte: Produktcode praktisch unberührt (höchstens ein Identifier). Die Klasse läuft in der normalen
  Suite nur als Skip. Das Skript hinterlässt am Ende **keinen** Wegwerf-Simulator und lässt `Restock-Validate`
  unberührt (siehe unten).

### Nicht-Ziele

- Keine Produktänderung außer einem eventuellen `accessibilityIdentifier`.
- Die Anfrage der Teilen-Erweiterung bleibt unverändert und ungeprüft.
- Kein neues DEBUG-Launch-Argument, kein Seed, kein Aufräum-Argument.
- Keine Prüfung echter Zustellung, von `.provisional` oder des Systemeinstellungs-Widerrufs.
- Keine Änderung an `HEAVY_CLASSES`, am Scheme oder an anderen Testklassen.

## Definition of Done

- [ ] RED vor Umsetzung der Klasse: Beide Tests fallen mit belegter Meldung (AC-1, AC-2)
- [ ] Lokaler Lauf beider Wege über das Skript auf je einem Wegwerf-Simulator (Vorlage `Restock-Validate`), Protokoll abgelegt (AC-9, AC-10, AC-11)
- [ ] Normale Suite unberührt, Klasse ohne Gate übersprungen (AC-3)
- [ ] Dialog-Beschriftungen de und en abgedeckt (AC-5)
- [ ] CI-Anschluss grün in beiden Hälften ODER begründeter Rückfall (AC-12, AC-13)
- [ ] `CLAUDE.md`-Absatz vorhanden (AC-14)
- [ ] Diff innerhalb der Limits, nur die genannten Dateien (AC-15)
- [ ] Offene Grenzen in Ticket und Bericht benannt, #145 bleibt offen (AC-16)

## Implementation Details

### Testklasse `NotificationPermissionUITests`

- **ENV-Gate** `RESTOCK_NOTIF_DECISION`, gesetzt über `TEST_RUNNER_RESTOCK_NOTIF_DECISION=allow|deny` (Präfix
  wird von `xcodebuild` abgestreift; Muster `RESTOCK_SHARE_E2E`). `setUpWithError()`: `continueAfterFailure =
  false`; ohne Wert wirft `XCTSkip` mit Grund (Hinweis auf das Skript und darauf, dass die Erlaubnis nur auf einem
  frischen Simulator offen ist; Neuinstallation reicht erst nach einem Tag). Ein Wert außer `allow`/`deny` ist ein Fehlschlag mit klarer
  Meldung, kein Skip.
- **Je Lauf nur der Test, der zur Entscheidung passt:** `testAllow` überspringt sich bei `deny`, `testDeny` bei
  `allow` (`XCTSkip` mit Grund „andere Entscheidung dieses Laufs“). So wird jedes frische Gerät genau einmal
  entschieden und das Skript prüft je Weg, dass der passende Test **gelaufen** ist (nicht übersprungen).
- **Start:** `UITestLaunch` mit `-developerMode YES -hasCompletedOnboarding YES`. **Nie**
  `-notificationsEnabled` (weder `YES` noch `NO`): Als Launch-Argument überlagert es in der Argument-Domain
  das, was der Schalter schreibt (Falle aus #98 D5 / #145 D1). Auch kein `-clearDeveloperModeForUITests`
  (nicht nötig: `-developerMode YES` schreibt die Klasse nie, und es gibt keinen Zustand aufzuräumen).
- **Ablauf gemeinsam:** Zahnrad → Zeile „Benachrichtigungen“ (`waitUntilHittable`, tippen) → Schalter
  „Nachkauf-Erinnerungen“ bzw. „Restock reminders“ suchen. Schalterzustand lesen über `value` (`"1"`/`"0"`).
  Auf **aus** warten (das `.task` der Einstellungen setzt ihn bei frischer Installation herunter; ggf. kurz zur
  Hauptliste zurück und wieder hinein, falls das `.task` erst nach dem Öffnen der Unterseite lief — der Zustand
  wird gelesen, nicht angenommen). Schalter antippen (aus → an). Das löst die Anfrage aus.
- **Dialog:** Aktiv in `XCUIApplication(bundleIdentifier: "com.apple.springboard")` auf `alerts.firstMatch`
  warten (Frist `UITestWait.defaultTimeout`), zusätzlich `addUIInterruptionMonitor` als zweites Netz (Muster
  `ReceiptShareExtensionTests`). Erscheint kein Dialog, schlägt der Test mit der Meldung „Installation nicht
  frisch: kein Mitteilungsdialog erschienen — die Erlaubnis wurde schon früher entschieden; Lauf auf frischem
  Simulator nötig (scripts/run-notification-permission-uitest.sh)“ fehl. **Kein Skip** an dieser Stelle, damit
  ein Lauf auf nicht frischem Gerät nicht grün wirkt.
- **Beschriftungen:** Erlauben: „Erlauben“, „Allow“. Nicht erlauben: „Nicht erlauben“, „Don’t Allow“ (typografischer
  Apostroph) sowie „Don't Allow“ (gerader). Der Alert-Titel wird nicht auf Wortlaut geprüft (enthält den
  App-Namen), nur sein Vorhandensein; die Schaltflächen werden über die Liste beider Sprachen gesucht, damit
  der Test auf dem englischen CI-Runner und lokal im deutschen Simulator gleichermaßen läuft.
- **`testAllow`:** Dialog → Erlauben → Schalter hat `value == "1"` und bleibt es (kurz abwarten, nicht
  sofort lesen; Memory „UI-Test liest Feld nach typeText zu früh“) → Einstellungen schließen (Zurück bzw. Sheet
  schließen), wieder öffnen → Zeile „Benachrichtigungen“ → Schalter weiterhin an. Das belegt, dass das
  `.task` (`isAuthorized() == true`) den Schalter nicht herunterschaltet.
- **`testDeny`:** Dialog → Nicht erlauben → Schalter wechselt auf `value == "0"` (Warten auf den Zustand, nicht
  sofortiges Lesen) → Einstellungen schließen/öffnen → weiterhin aus.
- **Hilfsfunktionen** (`tapWhenHittable` o. ä.) werden in der Klasse dupliziert (wenige Zeilen), `UITestWait.swift`
  bleibt unverändert.

### Skript `scripts/run-notification-permission-uitest.sh`

Aufruf: `scripts/run-notification-permission-uitest.sh [<simulator-udid>]`; das Argument ist die **Vorlage**,
Standard `Restock-Validate` (per Name aufgelöst), nie Hennings Gerät. Aus `simctl list devices -j` werden nur
`deviceTypeIdentifier` und der Runtime-Schlüssel der Vorlage gelesen; die Vorlage wird weder gebootet noch
verändert.

1. **Sperren (vereinbartes Verfahren der lokalen Sitzungen):** Beide Sperren sind **Verzeichnisse**, genommen
   in dieser Reihenfolge per atomarem `mkdir /tmp/heavy-build.lock`, dann `mkdir /tmp/loose-ends-testlauf.lock`;
   in jede schreibt das Skript die Zeile `run-notification-permission-uitest <zweck> <datum>` nach
   `<sperre>/owner`. Scheitert ein `mkdir` (Sperre belegt), bricht das Skript mit klarer Meldung samt Inhalt der
   fremden `owner`-Datei ab (Exitcode ≠ 0), ohne etwas zu verändern; eine schon genommene erste Sperre gibt es
   dabei wieder frei. Eine fremde Sperre wird **nie** gelöscht oder übernommen, auch keine scheinbar verwaiste.
   `trap` entfernt bei jedem Ende nur die Sperren, die das Skript selbst angelegt hat (`rm -rf`).
2. **Einmal bauen:** `xcodebuild build-for-testing` (Scheme `Restock`, Ziel `generic/platform=iOS Simulator`,
   `-derivedDataPath build/dd-notif`, keine zusätzlichen Build-Settings; Memory „CODE_SIGNING_ALLOWED=NO bricht
   die App-Gruppe“).
3. **Je Weg (`allow`, dann `deny`):** `xcrun simctl create "Restock-Notif-<weg>-<zeitstempel>" <gerätetyp>
   <runtime>` (udid gemerkt) → `boot` + `bootstatus -b` → `xcrun simctl install <wegwerf-udid> <gebaute .app>` →
   `TEST_RUNNER_RESTOCK_NOTIF_DECISION=<weg> xcodebuild test-without-building -destination id=<wegwerf-udid> …
   -only-testing:RestockUITests/NotificationPermissionUITests -resultBundlePath <eigener Pfad je Weg>
   -collect-test-diagnostics never` → Screenshots → `simctl shutdown` + `simctl delete` des Wegwerf-Simulators.
4. **Auswertung je Weg (Null-Test-Lauf ist kein Grün):** aus dem Protokoll bzw. `xcresulttool` die Zahl
   ausgeführter Tests lesen; Bedingung: ≥ 1 Test **gelaufen** (der zur Entscheidung passende), 0 Fehlschläge,
   kein Abbruch („Restarting after unexpected exit“, „Executed 0 tests“, „TEST EXECUTE FAILED“ gelten als Rot),
   der passende Test ist nicht übersprungen. Das Gesamturteil ist grün nur, wenn beide Wege grün sind.
5. **Schlusszustand:** Nach beiden Wegen (auch bei Fehlschlag, per `trap`) sind alle selbst angelegten
   Wegwerf-Simulatoren gelöscht; `simctl list devices` enthält keinen Namen `Restock-Notif-…-<zeitstempel>` mehr,
   sonst ist der Lauf rot. Auf `Restock-Validate` entsteht keine Erlaubnis, die spätere Läufe anderer Klassen
   beeinflusst (Downstream: erteilte Erlaubnis lässt `HomeView.refreshDueSoon` echte Mitteilungen planen).
6. **Ausgabe:** Ergebnisblock mit Commit-Kennung, Vorlage (udid/Runtime), Zeitstempel, Ergebnis je Weg (Testzahl,
   Fehlschläge, Wegwerf-udid), Pfad der Ergebnisbündel und „Wegwerf-Simulatoren nach dem Lauf übrig: nein (muss:
   nein)“.

### CI-Anschluss

**Stand 2026-10-20: angeschlossen** (Entwurf `docs/artifacts/test-145-d2-mitteilungserlaubnis/ci-anschluss-vertagt.diff`
unverändert übernommen; Strukturtest `scripts/test_ci_notification_permission.py`). Erster CI-Lauf: siehe Nachtrag am
Ende dieses Abschnitts.

- Hälfte A bekommt `TEST_RUNNER_RESTOCK_NOTIF_DECISION=allow` und zusätzlich
  `-only-testing:RestockUITests/NotificationPermissionUITests`; Hälfte B bekommt `deny`. Die Klasse steht
  **nicht** in `HEAVY_CLASSES` (die Liste bleibt unverändert, einzige Quelle). In Hälfte B läuft sie damit
  automatisch mit (sie ist Teil von `RestockUITests`); in A wird sie ergänzt.
- Begründung der Verteilung: Der Simulator ist je Job frisch, die App bleibt über die ganze Hälfte installiert
  → genau eine Entscheidung je Job. Hälfte A enthält die schweren Klassen und keine Nachkauf-Tests; ein
  „Erlauben“ dort lässt keine echte Planung in anderen Tests auslaufen. In B stören „Nicht erlauben“ die
  folgenden Tests kaum.
- **Reihenfolge-Risiko in B:** Läuft vor dieser Klasse ein Test, der `requestAuthorization` auslöst, ist die
  Installation nicht mehr frisch (kein Dialog). Das fällt bewusst laut aus (AC-4). Gegenmaßnahme: Außer dem
  Schalter dieser Klasse gibt es in der CI keine Anfragestelle (die Teilen-Erweiterung wird dort nicht
  gestartet); sollte der Lauf in B doch rot werden, wird der Weg nach der Messung entschieden (siehe Rückfall).
- **Rückfall:** Wird der CI-Anschluss instabil (Dialog auf dem Runner erscheint nicht oder nicht bedienbar), ist
  D2 mit Klasse + Skript erfüllt (DoD des Tickets: Test des echten Wegs); der CI-Anschluss wird als eigener
  Folgeschritt in #145 geführt, ohne die Hälften rot zu lassen. Vorbedingung für den Anschluss: lokaler
  Grün-Lauf beider Wege.

**Nachtrag erster CI-Lauf:** wird nach dem Lauf des Anschluss-PRs ergänzt (Hälfte A `testAllow`, Hälfte B
`testDeny`, Runner-Dialog englisch). Wechselwirkung mit #173: Scheitert `testAllow`/`testDeny` im ersten Durchlauf,
startet die Wiederholung die App neu, die Entscheidung ist dann aber schon gespeichert; die Wiederholung endet mit
„Installation nicht frisch“, der Job bleibt rot. Das ist beabsichtigt (AC-4), kein Fall für den Rückfall.

### Reihenfolge der Umsetzung

Spec → Klasse (RED) → Skript → lokaler Lauf beider Wege auf je einem Wegwerf-Simulator unter beiden Sperren → erst bei
Grün CI-Anschluss → Push-Lauf beider Hälften.

### Durchlauf (Pflicht, „Die App wird benutzt, nicht nur gebaut“)

Der Skriptlauf **ist** der Durchlauf des geänderten Ablaufs: Er installiert die App auf einem frischen Simulator, schaltet den
Schalter wie ein Nutzer und bedient den echten Systemdialog. Ergänzend Screenshot (`simctl io … screenshot`)
des Dialogs und des Schalterzustands je Weg als Beleg. Registrierung als Artefakt aus dem echten Lauf (Commit-
Kennung und Zeitstempel passend, nie von Hand gesetzt).

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED, vor Umsetzung): `NotificationPermissionUITests.testAllow` — GIVEN frische Installation,
  `RESTOCK_NOTIF_DECISION=allow`, WHEN Zahnrad → Benachrichtigungen, Schalter aus → an, THEN erscheint der
  Systemdialog, nach „Erlauben“ bleibt der Schalter an, auch nach Schließen/Öffnen der Einstellungen.
  RED-Beleg: Die Klasse existiert noch nicht bzw. der Test fällt an der ersten belegten Stelle.
- [ ] T2 (RED): `testDeny` — GIVEN frische Installation, `RESTOCK_NOTIF_DECISION=deny`, WHEN derselbe Ablauf,
  THEN nach „Nicht erlauben“ springt der Schalter auf aus und bleibt es.
- [ ] T3: `testSkipsWithoutGate` (als Beobachtung im normalen Suite-Lauf) — GIVEN kein `RESTOCK_NOTIF_DECISION`,
  WHEN die Klasse läuft, THEN werden beide Tests mit Grund übersprungen, die Suite bleibt grün.
- [ ] T4: Nicht frische Installation — GIVEN Erlaubnis bereits entschieden, `RESTOCK_NOTIF_DECISION=allow`,
  WHEN `testAllow` läuft, THEN schlägt er mit „Installation nicht frisch“ fehl (Gegenprobe zum Skip).
- [ ] T5: Skript `scripts/run-notification-permission-uitest.sh` — GIVEN Vorlage `Restock-Validate` und freie
  Sperren, WHEN es läuft, THEN beide Wege grün, Testzahl je Weg ≥ 1, am Ende sind keine Wegwerf-Simulatoren
  des Laufs übrig und `Restock-Validate` ist unberührt.
- [ ] T6: Skript bei belegter Sperre — GIVEN ein bestehendes Verzeichnis `/tmp/heavy-build.lock` mit fremder
  `owner`-Datei, WHEN das Skript startet, THEN bricht es mit klarer Meldung (samt `owner`-Inhalt) ab, verändert
  nichts und die fremde Sperre besteht unverändert weiter.
- [ ] T7: CI — GIVEN Push, WHEN beide Hälften laufen, THEN `testAllow` in A und `testDeny` in B grün (oder
  begründeter Rückfall).
- [ ] T8: Diff gegen den Tip-Commit — nur die genannten Dateien, ca. +215 LoC.

## Acceptance Criteria

- **AC-1:** GIVEN frisch installierte App und `RESTOCK_NOTIF_DECISION=allow`, WHEN `testAllow` die Schalter-
  Kette fährt (Zahnrad → „Benachrichtigungen“ → Schalter „Nachkauf-Erinnerungen“/„Restock reminders“ von aus
  auf an), THEN erscheint der Mitteilungsdialog, und nach „Erlauben“ steht der Schalter auf an und bleibt es,
  auch nach Schließen und erneutem Öffnen der Einstellungen. Test: T1.
- **AC-2:** GIVEN frisch installierte App und `RESTOCK_NOTIF_DECISION=deny`, WHEN `testDeny` dieselbe Kette
  fährt, THEN springt der Schalter nach „Nicht erlauben“ auf aus und bleibt es, auch nach Schließen und
  erneutem Öffnen der Einstellungen. Test: T2.
- **AC-3:** GIVEN die normale Suite ohne `RESTOCK_NOTIF_DECISION`, WHEN `NotificationPermissionUITests` läuft,
  THEN werden beide Tests per `XCTSkip` mit Grund übersprungen; die übrigen Klassen sind unberührt, die Suite
  bleibt grün. Test: T3.
- **AC-4:** GIVEN gesetztes Gate, aber schon entschiedene Erlaubnis (kein Dialog trotz Auslösung), WHEN der Test
  läuft, THEN schlägt er fehl mit der Meldung „Installation nicht frisch …“ und überspringt **nicht**. Test: T4.
- **AC-5:** GIVEN Simulator in Deutsch (lokal) oder Englisch (CI-Runner), WHEN der Dialog erscheint, THEN
  bedient der Test die Schaltflächen „Erlauben“/„Nicht erlauben“ bzw. „Allow“/„Don’t Allow“; der Alert-Titel
  wird nur auf Vorhandensein geprüft. Test: T1, T2 (de lokal, en aus dem CI-Lauf T7).
- **AC-6:** GIVEN die Launch-Argumente der Klasse, WHEN sie geprüft werden, THEN sind genau `-developerMode YES`
  und `-hasCompletedOnboarding YES` (plus die von `UITestLaunch` gesetzten) gesetzt, und `-notificationsEnabled`
  kommt in der Klasse nicht vor (Argument-Domain-Falle). Test: T8 (`grep`).
- **AC-7:** GIVEN die Klasse, WHEN sie geprüft wird, THEN erzeugt sie keinen Zustand im App-Group-Container und
  braucht kein Aufräum-Argument; der Zustand (Erlaubnis) entsteht nur auf dem Wegwerf-Simulator des Skripts
  und verschwindet mit ihm (AC-10). Test: T8.
- **AC-8:** GIVEN das Skript, WHEN es startet, THEN nimmt es beide Sperren `/tmp/heavy-build.lock` und
  `/tmp/loose-ends-testlauf.lock` in dieser Reihenfolge per `mkdir` samt `owner`-Datei, bricht bei belegter
  Sperre mit klarer Meldung ab, ohne die fremde Sperre anzutasten, und gibt bei jedem Ende nur die selbst
  angelegten Sperren frei. Test: T5, T6.
- **AC-9:** GIVEN das Skript, WHEN es läuft, THEN baut es genau einmal (`build-for-testing`, keine zusätzlichen
  Build-Settings) und führt je Weg `simctl create` (Gerätetyp und Runtime der Vorlage `Restock-Validate`) →
  `simctl install` → `xcodebuild test-without-building -only-testing:RestockUITests/NotificationPermissionUITests`
  auf diesem Wegwerf-Simulator → `simctl delete` aus. Test: T5.
- **AC-10:** GIVEN der Skriptlauf, WHEN er endet (grün oder rot), THEN ist kein Wegwerf-Simulator des Laufs mehr
  vorhanden und die Vorlage `Restock-Validate` ist unverändert. Test: T5 (`simctl list devices` enthält keinen
  Namen `Restock-Notif-…-<zeitstempel>`).
- **AC-11:** GIVEN die Auswertung je Weg, WHEN sie läuft, THEN zählt ein Weg nur als grün bei ≥ 1 gelaufenem
  (nicht übersprungenem) Test, 0 Fehlschlägen und ohne Abbruch; „Executed 0 tests“ oder ein Runner-Neustart
  ist Rot. Test: T5.
- **AC-12:** GIVEN `ci.yml`, WHEN der Anschluss geprüft wird, THEN setzt Hälfte A `allow` und wählt zusätzlich
  die Klasse, Hälfte B setzt `deny`; `HEAVY_CLASSES` ist unverändert und enthält die Klasse nicht. Test: T7, T8.
- **AC-13:** GIVEN der Push-Lauf, WHEN beide Hälften laufen, THEN sind sie grün und `testAllow` (A) bzw.
  `testDeny` (B) sind nicht übersprungen; ODER (Rückfall) der CI-Anschluss ist nicht im Diff, die Gründe sind
  als Messung dokumentiert, und der Anschluss steht als Folgeschritt in #145. Test: T7.
- **AC-14:** GIVEN der Abschluss, WHEN die Doku geprüft wird, THEN beschreibt `CLAUDE.md` Klasse, ENV
  `RESTOCK_NOTIF_DECISION`, Skript, Sperren, Wegwerf-Simulator je Weg (Neuinstallation setzt erst nach einem Tag zurück), die offenen Grenzen und den
  Hinweis in der D7-Spec ist gesetzt.
- **AC-15:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er höchstens
  `NotificationPermissionUITests.swift`, `run-notification-permission-uitest.sh`, `ci.yml`, `project.pbxproj`,
  optional `SettingsView.swift` (≤ ±2 Zeilen, nur Identifier) sowie die Doku, ca. +215 LoC, ohne neue
  Produkt-Strings, Dependencies, `Info.plist`- oder `@AppStorage`-Änderung. Test: T8.
- **AC-16:** GIVEN der Abschluss, WHEN Ticket und Berichte formuliert werden, THEN sind ausdrücklich als offen
  genannt: Anfrage der Teilen-Erweiterung ungeprüft, `.provisional`, echte Zustellung, Runner-Verhalten bis
  zum ersten CI-Lauf, nichts auf Hennings Geräten; #145 bleibt offen (Durchgänge 3 und 4).
- **AC-17:** GIVEN der Durchlauf, WHEN der Skriptlauf beider Wege erfolgt ist, THEN liegt ein Protokoll mit
  Commit-Kennung, Zeitstempel, Testzahl je Weg und Screenshots (Dialog, Schalterzustand) als Artefakt aus dem
  echten Lauf vor. Ein Lauf unter Last ist nicht erforderlich.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue
- **Rationale:** Systemfremder Zustand, der nur auf einem frischen Gerät offen ist, läuft wie beim
  Teilen-Test als Skript außerhalb der normalen Suite (Muster `run-share-extension-uitest.sh`), die Klasse mit
  ENV-Gate. Gekippt wird die Aussage aus der D7-Spec „Systemdialog nicht automatisiert“; sie war Arbeitsstand.

## Alternativen

Kein Modell beteiligt: deterministische Testlogik. Die Tabelle stammt aus der Analyse.

| Variante | Echter Weg | Beide Entscheidungen | CI | Dateien | LoC | Risiko |
|---|---|---|---|---|---|---|
| A Skript | ja | ja | nein | 3–4 | ca. 200 | niedrig; Zustand bleibt auf dem Wegwerf-Simulator, der gelöscht wird |
| B Suite + XCTSkip | nur zufällig | nein | bedingt | 1–2 | ca. 100 | hoch: stilles Skip verdeckt Fehler, hängt von der Reihenfolge ab |
| C nur Doku | nein | nein | – | 1 | 0 | DoD-Ausweg greift nicht, weil automatisierbar |
| D CI-Hälften | ja | ja (verteilt) | ja | 3–4 | ca. 150 | mittel, Runner-Verhalten ungemessen |
| **A+D (gewählt)** | ja | ja, doppelt | ja | 4–5 | ca. 215 | mittel, durch lokalen Vorlauf begrenzt |

- **Verworfen:** Simulator-Klon je Test (ein Klon übernimmt den Zustand der Vorlage und setzt die Entscheidung
  nicht verlässlich zurück); gewählt ist stattdessen ein per `simctl create` neu angelegter Wegwerf-Simulator je
  Weg (PO-Entscheidung 2026-10-16). Deinstallieren und neu installieren (wirkt erst nach einem Tag: Lauf
  2026-10-15 21:47, TN2265). Löschen der App innerhalb des Tests (Recherche 4: geht nicht).
- **Produkt-Alternative (nicht empfohlen, eigener PO-Entscheid):** Die Anfrage aus der Teilen-Erweiterung
  entfernen und nur über den Schalter fragen. Das würde den ungewollten Dialog in `ReceiptShareExtensionTests`
  beseitigen, kippt aber die Entscheidung aus dem Nutzerbericht vom 20.09.2026 (Erweiterung soll bei der ersten
  Nutzung fragen, sonst schlägt `scheduleOpenReminder()` lautlos fehl). Gehört nicht in dieses Testticket.
- **Gekippte frühere Entscheidung:** nur die Arbeitsaussage der D7-Spec („Systemdialog nicht automatisiert“).

**Entscheidung:** A+D, mit Rückfall auf A.

## Offene Grenzen

- Die Anfrage der **Teilen-Erweiterung** (`ShareViewController.swift` Z. 219–223) wird nicht durch diesen Test
  geprüft, nur der Schalter. `ReceiptShareExtensionTests` läuft nicht in der CI.
- **`.provisional`** ist nicht abgedeckt (der Code fragt keine provisorische Erlaubnis an); `isAuthorized()`
  zählt nur `.authorized`, `performDigestScheduling` auch `.provisional` — Befund, nicht Teil von D2.
- **Echte Zustellung** um 9:00 und der Widerruf in den Systemeinstellungen sind nicht geprüft.
- **Runner-Verhalten** (iOS 26/27, englischer Simulator, Dauer der Dialoganzeige) ist erst mit dem ersten
  CI-Lauf belegt; bis dahin gilt der lokale Nachweis auf Wegwerf-Simulatoren vom Typ von `Restock-Validate`.
- **Nichts** wird auf Hennings Geräten gestartet oder geprüft (Regel „Hennings Geräte nur auf sein Wort“).
- Die Klasse prüft je Lauf nur eine Entscheidung; beide Wege zusammen belegt erst das Skript bzw. die beiden
  CI-Hälften.

## Risiken

- **Dialog erscheint nicht (Installation nicht frisch):** Schlägt laut fehl (AC-4) statt zu überspringen.
  Gegenmaßnahme im Skript: frisch angelegter Wegwerf-Simulator je Weg (Deinstallation reicht nicht, TN2265).
- **Reihenfolge in CI-Hälfte B:** Ein früherer Test, der die Anfrage auslöst, würde den Dialog verbrauchen.
  Nach heutigem Code gibt es in der CI keinen anderen Auslöser; Messung im ersten Lauf, sonst Rückfall.
- **Zustandsleck nach „Erlauben“:** Bleibt die Erlaubnis lokal bestehen, planen spätere Läufe echte
  Mitteilungen. Gegenmaßnahme: Die Erlaubnis entsteht nur auf dem Wegwerf-Simulator, der am Ende gelöscht ist
  (AC-10).
- **Argument-Domain-Falle:** `-notificationsEnabled` als Launch-Argument würde das Schreiben des Schalters
  überlagern; kommt nie vor (AC-6).
- **`.task` stellt den Schalter beim Öffnen auf aus:** Der Test liest den Zustand und wartet darauf, statt ihn
  anzunehmen.
- **Lokalisierung des Dialogs:** de/en abgedeckt; weitere Sprachen nicht (Scheme fixiert de, Runner en).
- **Runner-Dauer:** Einzelne XCUITest-Abfragen dauern auf dem Runner 4–31 s (Memory „CI-UI-Abfragen dauern
  4 s“); Warten über `UITestWait`-Hilfen, keine 5-s-Fristen.
- **Schwere parallele Läufe:** Das Skript nimmt beide Sperren (Memory „Schwere Läufe mit anderen Sitzungen
  abstimmen“); nie parallel zu anderen Simulator-Läufen.
- **Null-Test-Lauf:** „Executed 0 tests … TEST SUCCEEDED“ ist kein Grün (Memory „Null-Test-Lauf ist kein
  Grün“); AC-11.
- **LoC-Gate:** ca. +215 nah am Limit; bei Überschreitung Rückfall auf Klasse + Skript.
- **Zeilennummern verschieben sich:** Maßgeblich sind die Namen, nicht die Zeilen.

## Folge-Durchgänge im selben Ticket

- Durchgang 3: `AppIntentsTesting` (iOS 27, CI-Runner-Version prüfen).
- Durchgang 4: Kauf/Wiederherstellen (`Restock.storekit`, `SKTestSession`).
- Beide nicht Teil dieser Spec; #145 bleibt bis dahin offen.

## Changelog

- 2026-10-15: Initial spec created (Durchgang 2 von #145; Klasse mit ENV-Gate plus Neuinstallations-Skript,
  CI-Anschluss je Hälfte mit Rückfall)
- 2026-10-16: Rücksetzweg korrigiert (Neuinstallation setzt die Mitteilungserlaubnis erst nach einem Tag zurück, belegt im Lauf 2026-10-15 21:47 und Apple TN2265); Skript nutzt je Weg einen Wegwerf-Simulator, PO-Entscheidung, Freigabe per override.
