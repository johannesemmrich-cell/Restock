# Context: test-145-d2-mitteilungserlaubnis (#145 Durchgang 2)

## Request Summary
Teil 3 aus #145: Der echte Systemdialog „„Restock“ möchte dir Mitteilungen senden“ soll in einem UI-Test
bedient werden — Erlauben (Schalter bleibt an) und Nicht erlauben (Schalter springt auf aus). DoD des
Tickets: Test des echten Wegs ODER belegte Begründung, warum nicht automatisierbar.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/NotificationService.swift:36` | `requestPermission()` → `UNUserNotificationCenter.requestAuthorization([.alert,.sound,.badge])`, einziger Aufrufer der Anfrage |
| `SmartCart/Views/Settings/SettingsView.swift:415-440` | `NotificationSettingsView`: Schalter „settings.notifications.replenish“, NUR im Dev-Modus sichtbar; `onChange` → bei an: `notificationsEnabled = await requestPermission()`, bei aus: `cancelAll()` |
| `SmartCart/Views/Settings/SettingsView.swift:344-351` | `.task`: steht der Schalter an, ist aber keine Erlaubnis da, wird er auf aus gesetzt (beim Öffnen der Einstellungen) |
| `SmartCart/Views/Home/HomeView.swift:1665` / `ReplenishmentDigest.swift:152` | lesen `notificationsEnabled` (Default `true`) für die Planung |
| `RestockUITests/ReceiptShareExtensionTests.swift:125-160` | bestehendes Muster: SpringBoard-Alert (`com.apple.springboard`) aktiv abgreifen + `addUIInterruptionMonitor`; dort tauchte der Mitteilungsdialog schon einmal ungewollt über Fotos auf |
| `RestockUITests/DeveloperModeUnlockUITests.swift`, `UITestWait.swift` | Vorlage für neue Testklasse, `UITestLaunch`, `waitUntilHittable` |
| `.github/workflows/ci.yml:140-155` | CI bootet frischen Simulator je Job, setzt `simctl privacy grant camera/photos` — für Mitteilungen gibt es das nicht |
| `docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md:52` | hielt fest: Systemdialog nicht automatisiert, Erlaubnis von außen nicht setzbar |

## Recherche (Pflicht, vor Analyse) — Befunde mit Quelle
1. **`simctl privacy` kennt keine Mitteilungen.** Lokal mit `xcrun simctl help privacy` (Xcode 26) geprüft:
   Dienste sind calendar, contacts(-limited), location(-always), photos(-add), media-library, microphone,
   motion, reminders, siri, all — kein `notifications`. Auch `reset all` erfasst Mitteilungen also nicht.
2. **`XCUIApplication.resetAuthorizationStatus(for:)` kennt keine Mitteilungen.** Im installierten SDK
   (`XCUIProtectedResource`) stehen contacts, calendar, reminders, photos, microphone, camera, mediaLibrary,
   homeKit, bluetooth, keyboardNetwork, location (+ macOS-Ordner) — kein notifications.
   Quelle: WWDC20 10220 „Handle interruptions and alerts in UI tests“ (https://wwdcnotes.com/notes/wwdc20/10220).
3. **Einziger Rücksetzweg: App löschen und neu installieren** (oder Simulator löschen).
   https://www.avanderlee.com/?p=2538, https://useyourloaf.com/blog/handling-system-alerts-in-ui-tests/
4. **Löschen innerhalb eines XCUITests geht nicht:** Danach scheitert `launch()` mit
   `FBSOpenApplicationServiceErrorDomain Code=4 … returned nil`; XCTest installiert nicht neu, kein Apple-Workaround.
   https://developer.apple.com/forums/thread/722021, https://www.jessesquires.com/blog/2021/10/25/delete-app-during-ui-tests/
5. Der Dialog gehört SpringBoard; bedienbar über `XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts`
   oder `addUIInterruptionMonitor` (im Repo schon so genutzt).

**Folge:** Je Installation lässt sich genau EINE Entscheidung (Erlauben ODER Nicht erlauben) im Dialog testen.
Beide Wege brauchen zwei getrennte Installationen; danach ist der Zustand für alle folgenden Tests festgelegt.

## Existing Patterns
- Systemfremde Abläufe mit frischem Installationszustand laufen als Skript außerhalb von XCUITest:
  `scripts/run-share-extension-uitest.sh` (installiert per `simctl install`, fährt dann einen einzelnen Test).
- DEBUG-Launch-Argumente nur, wenn kein Zustand des echten Wegs ersetzt wird; Argument-Domain-Falle:
  `-notificationsEnabled` NIE als Launch-Argument (der Schalter schreibt den Wert).
- `-developerMode YES` als Launch-Argument ist hier zulässig (wird im Test nicht geschrieben).

## Dependencies
- Upstream: `UNUserNotificationCenter`, SpringBoard-Dialog, Dev-Modus-Sichtbarkeit des Schalters.
- Downstream: Erteilte Erlaubnis bleibt im Simulator bis zur Neuinstallation → `HomeView.refreshDueSoon`
  plant danach echte Mitteilungen in anderen Tests (z. B. `ReplenishmentUITests`); der Schalter ist ab Werk `true`.

## Existing Specs
- `docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md` (offene Grenze „Systemdialog“)
- `docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md` (Vorgänger-Durchgang, Testmuster)

## Risks & Considerations
- **Reihenfolge-Abhängigkeit:** Ein Test innerhalb der normalen Suite sieht den Dialog nur, wenn vorher kein
  anderer Test/Lauf die Erlaubnis entschieden hat (lokal: Restock-Validate ist vermutlich längst entschieden).
- **CI:** frischer Simulator je Job, aber die App bleibt über die ganze Hälfte installiert → genau eine
  Entscheidung je Job; ein „Nicht erlauben“ würde nachfolgende Tests kaum stören, ein „Erlauben“ lässt echte
  Mitteilungen planen.
- Ungewollter Dialog: Schon heute erschien der Mitteilungsdialog in `ReceiptShareExtensionTests` — Herkunft
  klären (der einzige Aufrufer ist der Schalter).
- Schalter Default `true`: um die Anfrage auszulösen, muss er erst aus, dann an.
- `.task` in `SettingsView` schaltet einen „an, aber nicht erlaubt“-Schalter beim Öffnen auf aus — beeinflusst
  den Ausgangszustand.
- Gerät von Henning ist tabu; alles nur im Simulator. Schwere Läufe nur mit beiden Sperren
  (`/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock`).

## Lösungsrichtungen für /20-analyse (noch keine Entscheidung)
- A) Skript wie beim Teilen-Test: je Weg `simctl uninstall` → `install` → einzelner UI-Test (`-only-testing`);
  in der CI als eigener Schritt.
- B) Ein Test in der Suite, der nur läuft, wenn der Dialog kommt (sonst `XCTSkip` mit Grund) — prüft dann nur
  einen Weg und hängt von der Reihenfolge ab.
- C) Belegte Begründung „nicht in der Suite automatisierbar“ (DoD-Ausweg), nur Dokumentation.

## Analysis

### Type
Feature (Testlücke schließen, kein Produktfehler gemeldet). Keine sichtbare UI-Änderung → keine Entwurfsvorschau nötig.

### Neue Befunde der Analyse (verifiziert im Code)
- **Zweiter Aufrufer der Anfrage:** `RestockShareExtension/ShareViewController.swift:219-223`
  (`requestNotificationPermissionIfNeeded`, nur bei `.notDetermined`). Das ist die Herkunft des ungewollten Dialogs
  in `ReceiptShareExtensionTests` (dort Z. 106-118 kommentiert). Die Kontext-Aussage „einziger Aufrufer ist der
  Schalter“ ist damit korrigiert. `AppDelegate.swift:15` `registerForRemoteNotifications()` zeigt keinen Dialog.
- `ReceiptShareExtensionTests` läuft NICHT in der CI (ENV-Gate `TEST_RUNNER_RESTOCK_SHARE_E2E=1`, nur über
  `scripts/run-share-extension-uitest.sh`). In der CI fragt also nur der Schalter.
- Kein bestehender UI-Test bedient „Nachkauf-Erinnerungen“ (grep in `RestockUITests/` leer). Weg: Zahnrad →
  „Benachrichtigungen“ (nur Dev-Modus, `SettingsView.swift:115-121`) → Schalter (`SettingsView.swift:426-436`).
- `.task` hängt an `SettingsView` (Z. 344-351): Bei frischer Installation schaltet das Öffnen der Einstellungen den
  Schalter (Default `true`) auf aus. Der Test wartet daher auf „aus“ und schaltet dann an → Anfrage.
- „Nicht erlauben“: `requestPermission()` liefert `false` → Schalter aus → `onChange` → `cancelAll()`.
- `isAuthorized()` (`NotificationService.swift:48-50`) zählt nur `.authorized`, `performDigestScheduling` auch
  `.provisional` — Befund, nicht Teil von D2 (keine provisorische Anfrage im Code).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/NotificationPermissionUITests.swift` | CREATE | `testAllow`/`testDeny`, ENV-Gate `RESTOCK_NOTIF_DECISION` (ohne Wert: Skip wie Teilen-Test); Dialog über SpringBoard-Alert, Beschriftungen de+en; erscheint kein Dialog → Fehlschlag „Installation nicht frisch“, kein Skip; nach Erlauben Einstellungen schließen/öffnen, Schalter bleibt an |
| `scripts/run-notification-permission-uitest.sh` | CREATE | einmal bauen, je Weg `simctl uninstall` → `install` → `xcodebuild test-without-building -only-testing:` mit ENV; beide Sperren; Schlusszustand deinstalliert (keine dauerhafte Erlaubnis auf Restock-Validate) |
| `.github/workflows/ci.yml` | MODIFY | ENV je Hälfte: A = allow (enthält keine Nachkauf-Tests), B = deny; Hälfte A zusätzlich `-only-testing:` der Klasse (nicht in `HEAVY_CLASSES`) |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY (nur falls nötig) | `accessibilityIdentifier` am Schalter, falls das Label-Matching nicht trägt (±2 Zeilen) |
| `docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md` | CREATE | Spec |

### Scope Assessment
- Files: 4–5 (davon 1 Spec)
- Estimated LoC: ca. +210/-0 Code (Klasse ~130, Skript ~70, CI ~10)
- Risk Level: MEDIUM — Produktcode praktisch unberührt; Risiko liegt im CI-Anschluss (Dialog-Verhalten auf dem
  Runner ungemessen, ein Fehlschlag färbt eine ganze Hälfte rot)

### Technical Approach (Empfehlung)
Variante A+D: eine Testklasse mit ENV-Gate (normale Suite unberührt) + Skript, das je Entscheidung neu
installiert (deterministischer Beleg beider Wege lokal), danach dieselbe Klasse in der CI je Hälfte mit einer
Entscheidung (frische Installation pro Job). Reihenfolge: Spec → Klasse (RED) → Skript → lokaler Lauf beider Wege
auf Restock-Validate unter beiden Sperren → erst bei Grün CI-Anschluss → Push-Lauf beider Hälften.
Rückfall: Wird der CI-Anschluss instabil, liefert D2 Klasse + Skript (DoD erfüllt), CI als eigener Folgeschritt.

| Variante | Echter Weg | Beide Entscheidungen | CI | Dateien | LoC | Risiko |
|---|---|---|---|---|---|---|
| A Skript | ja | ja | nein | 3–4 | ~200 | niedrig, hinterlässt Zustand (→ deinstallieren) |
| B Suite + XCTSkip | nur zufällig | nein | bedingt | 1–2 | ~100 | hoch: stilles Skip verdeckt Fehler |
| C nur Doku | nein | nein | – | 1 | 0 | DoD-Ausweg greift nicht, da automatisierbar |
| D CI-Hälften | ja | ja (verteilt) | ja | 3–4 | ~150 | mittel, Runner ungemessen |
| **A+D** | ja | ja, doppelt | ja | 4–5 | ~220 | mittel, durch lokalen Vorlauf begrenzt |

Verworfen: Simulator-Klon je Test (eigene Infrastruktur, Klon setzt Entscheidung nicht verlässlich zurück).
Alternative mit Produktfolge (nicht empfohlen, eigener PO-Entscheid): Anfrage aus der Teilen-Erweiterung entfernen.

### Dependencies
`UNUserNotificationCenter`, SpringBoard-Alert, Dev-Modus-Sichtbarkeit (`-developerMode YES`,
`-hasCompletedOnboarding YES` als Launch-Argumente zulässig, `-notificationsEnabled` nie), `UITestLaunch`/
`waitUntilHittable` aus `UITestWait.swift`, Muster ENV-Gate + SpringBoard aus `ReceiptShareExtensionTests.swift`.

### Offene Grenzen (für Spec)
- Anfrageweg der Teilen-Erweiterung wird nicht durch diesen Test geprüft (nur Schalter).
- `.provisional` nicht abgedeckt; echte Zustellung weiter nicht geprüft; nichts auf Hennings Geräten.
- Runner-Verhalten des Dialogs (iOS 26/27, englischer Simulator) erst mit dem ersten CI-Lauf belegt.

### Open Questions
- keine PO-Fragen; alle Punkte technisch (CI-Anschluss entscheidet Tech Lead, Bedingung lokaler Grün-Lauf).
