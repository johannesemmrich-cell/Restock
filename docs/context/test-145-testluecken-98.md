# Context: test-145-testluecken-98

## Request Summary
Issue #145 bündelt die offenen Testlücken aus #98: Wo technisch möglich, wird der echte Weg automatisiert
geprüft, sonst begründet, warum nicht. Ein Ticket, vier Durchgänge (Schnitt vom PO am 2026-10-15 bestätigt):
1. Dev-Passwort Richtig-Pfad, 2. Mitteilungserlaubnis-Dialog, 3. `AppIntentsTesting`, 4. Kauf/Wiederherstellen.
Dieser Kontext deckt **Durchgang 1** im Detail ab; die übrigen Teile sind unten nur mit Recherchestand vermerkt.

## Durchgang 1: Dev-Passwort Richtig-Pfad

### Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Settings/SettingsView.swift:34` | `private let devPasswordHash` (fester SHA256-Hex), wird an `DevPasswordSheet` übergeben (`:323-332`) |
| `SmartCart/Views/Settings/SettingsView.swift:225-241` | Versionszeile: 5 Tipps binnen je ≤2 s → `showDevPasswordPrompt = true` |
| `SmartCart/Views/Settings/SettingsView.swift:608-659` | `DevPasswordSheet` (private): `SecureField("Passwort")`, „Entsperren“, `verify()` vergleicht SHA256 mit `passwordHash`; richtig → `onUnlock()` → `developerMode = true`, Sheet zu, Haptik |
| `SmartCart/Views/Settings/SettingsView.swift:248-290` | sichtbarer Beweis des Richtig-Pfads: Dev-Abschnitt (Feedback, Todos & Ideen, Nachkauf-Statistik, Bon-Auflösung, Ausgeblendete Vorschläge, „Developer Mode deaktivieren“) |
| `SmartCart/SmartCartApp.swift:786-830` | `DevModeIndicator`: oranger „DEV“-Pill auf allen Screens bei `developerMode` |
| `SmartCart/SmartCartApp.swift:28-48` | DEBUG-Block mit allen `-…ForUITests`-Argumenten; hier gehört ein Aufräum-Argument hin |
| `SmartCart/Services/PremiumService.swift:16-29` | `developerMode` schaltet Premium frei („Pro aktiv“) |
| `RestockUITests/PaywallUITests.swift:112-150` | bestehender Falsch-Pfad-Test (AC-8 aus #98 D5): Mehrfachtipp, Feld-Fokus, Fehlertext, Abbrechen; Muster zum Wiederverwenden |
| `RestockUITests/UITestWait.swift` | `UITestLaunch.start`, `waitUntilHittable`, `defaultTimeout` |
| `SmartCart/Services/CloudPreferencesSync.swift:13-31` | `developerMode` ist **nicht** in der iCloud-Liste → bleibt lokal, kein Fremdgeräte-Risiko |

### Existing Patterns
- DEBUG-Launch-Argumente in `SmartCartApp.init()` unter `#if DEBUG`, je Seed ein Aufräum-Argument im `tearDown()` (CLAUDE.md-Pflicht).
- DEBUG-Überschreibung eines Produktwerts per Argument mit Wert: `-quickAddToastDurationForUITests <Sekunden>` in `HomeView.showQuickAddToast` (#111 D2) — dasselbe Muster für `-devPasswordHashForUITests <sha256>`.
- Bisherige Entscheidung (#98 D5, `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md:207-229`): Richtig-Pfad bewusst offen; empfohlene Folgevariante genau dieses DEBUG-Argument, ganze Kette fahren, `developerMode` aufräumen. Diese Entscheidung wird jetzt gekippt.

### Dependencies
- Upstream: `CryptoKit.SHA256`, `@AppStorage("developerMode")` (`UserDefaults.standard`).
- Downstream von `developerMode`: `HomeView` (Nachkauf-Banner), `StoreDetailView` (Vielleicht auch fällig, Sync-Detail), `DevFeedbackButton`, `PremiumService`, `ReplenishmentDigest.swift:151`, `DevModeIndicator`.

### Risks & Considerations
- **Argument-Domain-Falle:** Startet der Test mit `-developerMode NO`, überlagert die Argument-Domain jeden Schreibvorgang — nach richtigem Passwort bliebe `developerMode` gelesen `NO`. Der Richtig-Pfad-Test darf `-developerMode` nicht als Argument setzen; er braucht einen sauberen Ausgangszustand anders (Aufräum-Argument beim Start, analog `-clearOnboardingForUITests`).
- **Aufräumen Pflicht:** Erfolgreiches Entsperren schreibt `developerMode = true` dauerhaft in den App-Container; ohne Aufräumen laufen Folgetests (z. B. Paywall-Sperre) mit Premium. `tearDown()` muss es entfernen.
- **Sicherheit:** Überschreibung nur unter `#if DEBUG`; Release-Build darf den Hash nicht austauschbar machen. Das echte Passwort bleibt dem Test unbekannt.
- `DevPasswordSheet` ist `private`; die Überschreibung sitzt sinnvoll an `devPasswordHash` (Übergabestelle), nicht im Sheet.
- 5-Tipp-Zähler mit 2-s-Fenster: auf langsamen Läufern Mehrfachtipp-Muster aus dem Falsch-Pfad übernehmen.
- Erwarteter Umfang: `SettingsView.swift`, `SmartCartApp.swift`, `PaywallUITests.swift` (oder neue Klasse), Spec, CLAUDE.md — innerhalb der Limits.

## Analysis (Durchgang 1, 2026-10-15)

### Type
Feature (Testabdeckung, mit kleiner DEBUG-Naht im Produktcode). Kein Bug, keine sichtbare UI-Änderung → kein Entwurf vor der Spec nötig.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | `:34` `private let devPasswordHash` → `static let releaseDevPasswordHash` + computed `devPasswordHash`, das unter `#if DEBUG` `UserDefaults.standard.string(forKey: "devPasswordHashForUITests")` (nicht leer) bevorzugt. `DevPasswordSheet`/`verify()` bleiben unverändert (echter Vergleichsweg wird gefahren). ~+8 |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Block im `defer` von `init()` (`:30-48`): `clearDeveloperModeForUITestsIfNeeded()` → `UserDefaults.standard.removeObject(forKey: "developerMode")` bei `-clearDeveloperModeForUITests`. ~+8 |
| `RestockUITests/DeveloperModeUnlockUITests.swift` | CREATE | Eigene Klasse: Start mit `-hasCompletedOnboarding YES -clearDeveloperModeForUITests -devPasswordHashForUITests <sha256("…Testpasswort…")>`, NIE `-developerMode`. Mehrfachtipp auf „Version“ (Muster `PaywallUITests:112-150`), Testpasswort tippen, „Entsperren“. Beweise: Sheet „Developer Mode“ zu, „Pro aktiv“ (`SettingsView:129`), Dev-Abschnitt sichtbar (z. B. „Developer Mode deaktivieren“), „DEV“-Pill (`SmartCartApp.swift:798`, `Text("DEV")`); Neustart ohne Clear/Hash-Argument → „Pro aktiv“ bleibt (Schlüssel wirklich geschrieben). `tearDown`: Cleaner-Start mit `-clearDeveloperModeForUITests`. Hash als Konstante im Test (oder CryptoKit zur Laufzeit). ~50–60 |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Testdatei in 4 Stellen registrieren (UI-Test-Ziel). Landet in CI automatisch in Hälfte B. |
| `CLAUDE.md` + neue Spec `docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md`; Verweis in `test-98-durchgang-5-onboarding-paywall.md:207-229` (offene Grenze geschlossen) | MODIFY/CREATE | Doku |

### Scope Assessment
- Dateien: 3 Code (+ pbxproj) + Doku
- Geschätzt: ~+80–100 / −2 LoC
- Risiko: LOW — Produktänderung nur unter `#if DEBUG`, Release-Hash unverändert.

### Technical Approach
Hash-Überschreibung statt Klartext: so läuft `verify()` unverändert (SHA256-Hex klein, `%02x`), getestet wird die echte Kette Tipp → Sheet → Eingabe → `developerMode` → Sheet zu → Premium/Dev-Abschnitt → Neustart. Doppelgurt beim Aufräumen: Clear-Argument beim Teststart UND im `tearDown`.

### Risiken
- **Argument-Domain:** `-developerMode` darf weder im Test noch im Cleaner stehen, sonst überdeckt es den Schreibvorgang bzw. das Entfernen.
- **Zustandsleck:** Viele Klassen (z. B. `StoreSetupUITests`, `OnboardingUITests`) setzen `-developerMode` nicht und würden ein übrig gebliebenes `true` erben (Premium frei, Nachkauf-Banner) → Gesamtlauf der Suite als Nachweis.
- **2-s-Tippfenster** und **Tastaturfokus**: bestehende Mehrfachtipp-/Fokus-Muster aus dem Falsch-Pfad übernehmen.
- **Release-Sicherheit:** Prüfen, dass der Schlüssel `devPasswordHashForUITests` im Release-Build nicht vorkommt (`strings` auf das Release-Binary).

### Alternativen (bewertet)
1. **Unit-Test einer ausgegliederten `verify`-Funktion:** ~20 LoC, stabil, aber beweist weder Verdrahtung noch Sheet-Schließen, Premium, Persistenz — das ist genau die Lücke aus #98. Abgelehnt als Ersatz, höchstens Zusatz.
2. **Klartext-Testpasswort statt Hash:** müsste `verify()` umgehen oder ändern → echter Vergleichsweg ungetestet. Abgelehnt.
3. **Offen lassen** (Stand #98 D5): kein Aufwand, Richtig-Pfad bleibt ungeschützt (z. B. gegen falschen AppStorage-Schlüssel). Wird mit diesem Durchgang gekippt.
4. **Test in `PaywallUITests` statt eigener Klasse:** spart pbxproj-Eintrag, aber `tearDown`-Cleaner liefe nach jedem der Paywall-Tests (Mehrzeit) oder nur bedingt. Eigene Klasse empfohlen.

### Open Questions
- keine PO-Fragen; Richtung „Hash-Überschreibung, ganze Kette“ ist mit dem Schnitt vom 2026-10-15 vorgegeben.

## Durchgänge 2–4: Recherchestand (für spätere Kontexte)
- **2 Erlaubnis-Dialog:** `addUIInterruptionMonitor` bzw. Springboard-Alert (https://useyourloaf.com/blog/handling-system-alerts-in-ui-tests/); `simctl privacy` kennt `notifications` nicht (`RestockUITests/ReceiptShareExtensionTests.swift:112`) → Ausgangszustand „nie gefragt“ nur über Neuinstallation/Löschen der App herstellbar. Spec Durchgang 7: `docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md`.
- **3 App-Intents:** `AppIntentsTesting` (WWDC 2026, Session 295, https://developer.apple.com/videos/play/wwdc2026/295) läuft im UI-Test-Bündel, nur Bundle-ID, ohne Mocks; erfordert iOS 27 — CI-Runner-Version prüfen.
- **4 Kauf:** `Restock.storekit` im Repo, in keinem Scheme. Bekannte Probleme: `StoreKitError.Unknown` unter XCTest (https://developer.apple.com/forums/thread/736989), `xcodebuild test` überträgt `.storekit` auf iOS 26.5 nicht (https://developer.apple.com/forums/thread/826971). Alternative: Unit-Test mit `SKTestSession` statt Scheme-Änderung.
