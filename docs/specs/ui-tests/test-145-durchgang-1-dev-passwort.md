---
entity_id: test-145-durchgang-1-dev-passwort
type: test
created: 2026-10-15
updated: 2026-10-15
status: draft
workflow: test-145-testluecken-98
tags: [test, ui-test, dev-password, developer-mode, debug-launch-argument, issue-145, issue-98]
---

# Dev-Passwort Richtig-Pfad automatisiert prüfen (Issue #145, Durchgang 1)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Issue #145 bündelt die offenen Testlücken aus #98 (vier Durchgänge, Schnitt vom PO am 2026-10-15
bestätigt). Dieser Durchgang schließt die erste: den **Richtig-Pfad des Dev-Passworts**.

Stand heute: `PaywallUITests.testWrongDevPasswordShowsErrorAndKeepsSheetOpen` (#98 D5, AC-8) prüft nur
den Falsch-Pfad. Dass ein **richtiges** Passwort wirklich entsperrt (`verify()` → `onUnlock()` →
`developerMode = true` → Sheet schließt → „Pro aktiv“ → Dev-Abschnitt → DEV-Pill → Zustand überlebt den
Neustart), ist nirgends automatisiert. Ein Fehler dort (falscher `@AppStorage`-Schlüssel, Sheet schließt
nicht, Hash-Format) bliebe unbemerkt, bis Henning ihn bemerkt. Die Spec von D5 hatte das bewusst offen
gelassen (`test-98-durchgang-5-onboarding-paywall.md`, Abschnitt „Dev-Passwort: Entscheidung
Richtig-Pfad“) und als bessere Folgevariante genau das hier beschriebene DEBUG-Argument benannt. **Diese
Entscheidung wird mit diesem Durchgang gekippt.**

Lösung: zwei **nur im DEBUG-Build wirksame** Launch-Argumente.

- `-devPasswordHashForUITests <sha256-hex>` ersetzt an der Übergabestelle in `SettingsView` den
  Vergleichshash. `DevPasswordSheet` und `verify()` bleiben **unverändert**; der echte Vergleichsweg
  (SHA256, `%02x`) läuft mit einem Testpasswort. Das echte Passwort bleibt dem Test unbekannt.
- `-clearDeveloperModeForUITests` entfernt in `SmartCartApp.init()` den Schlüssel `developerMode` aus
  `UserDefaults.standard` (Aufräum-Argument nach CLAUDE.md-Pflicht, weil erfolgreiches Entsperren
  `developerMode = true` dauerhaft in den App-Container schreibt).

Eine neue Klasse `DeveloperModeUnlockUITests` fährt die ganze Kette über sichtbare Elemente, einschließlich
Neustart.

**Ticket-Rahmen:** #145 ist ein Ticket mit vier Durchgängen; die Scoping-Limits gelten je Durchgang
(Memory „#98 ein Ticket, mehrere Durchgänge“). Analyse: `docs/context/test-145-testluecken-98.md`.

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Geprüft wird die Kette mit einem **Testpasswort
und überschriebenem Hash**. Der Release-Pfad mit dem echten Passwort und dem festen Release-Hash bleibt
ungetestet, weil das Passwort dem Test unbekannt bleibt; dass der Release-Hash unverändert ist, wird nur
per Diff (AC-8) belegt, nicht per Eingabe. Durchgänge 2–4 von #145 (Mitteilungserlaubnis-Dialog,
`AppIntentsTesting`, Kauf/Wiederherstellen) sind **nicht** Teil dieser Spec.

## Source

Zeilennummern Stand 2026-10-15; maßgeblich sind die Namen.

- **Geändert:** `SmartCart/Views/Settings/SettingsView.swift` — `private let devPasswordHash = "fab0…7c86"`
  (Zeile 34) wird zu einer Konstante `releaseDevPasswordHash` (gleicher Wert, unverändert) plus einer
  berechneten Eigenschaft `devPasswordHash`. Unter `#if DEBUG` liefert sie
  `UserDefaults.standard.string(forKey: "devPasswordHashForUITests")`, wenn der Wert nicht leer ist
  (Launch-Argumente der Form `-key value` erscheinen in der Argument-Domain, kein eigenes Parsen);
  sonst und im Release-Build `releaseDevPasswordHash`. Die Übergabe an `DevPasswordSheet(passwordHash:…)`
  (Zeile ca. 324) nutzt unverändert `devPasswordHash`. `DevPasswordSheet` (Zeile ca. 608–659) und
  `verify()` bleiben unberührt.
- **Geändert:** `SmartCart/SmartCartApp.swift` — im DEBUG-Block von `init()` (Zeilen 28–48) neuer Aufruf
  `Self.clearDeveloperModeForUITestsIfNeeded()` und die Funktion dazu: bei
  `-clearDeveloperModeForUITests` wird `UserDefaults.standard.removeObject(forKey: "developerMode")`
  ausgeführt. Muster: `clearOnboardingForUITestsIfNeeded` (Zeile ca. 471).
- **Neu:** `RestockUITests/DeveloperModeUnlockUITests.swift` — eigene Klasse (siehe Implementation Details).
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — neue Testdatei an den vier Stellen
  (`PBXBuildFile`, `PBXFileReference`, `PBXGroup` von `RestockUITests`, `PBXSourcesBuildPhase` des
  UI-Test-Ziels). In der CI landet die Klasse ohne Eintrag automatisch in Hälfte B.
- **Geändert (Doku):** `CLAUDE.md` (ein Absatz), `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md`
  (Abschnitt „Dev-Passwort: Entscheidung Richtig-Pfad“ erhält einen Hinweis „geschlossen durch #145
  Durchgang 1“, Verweis auf diese Spec).
- **Nicht geändert:** `DevPasswordSheet`, `verify()`, `PremiumService`, `DevModeIndicator`,
  `CloudPreferencesSync` (`developerMode` steht nicht in der iCloud-Liste, bleibt lokal),
  `PaywallUITests` (der Falsch-Pfad-Test bleibt wie er ist), `UITestWait.swift`, Scheme, `ci.yml`.
- **Keine** neuen Produkt-Strings, **keine** neuen Dependencies, **keine** Änderung an `Info.plist`,
  `@AppStorage`-Schlüsseln oder Audio-Dateien. Beide Argumente werden nur gelesen bzw. entfernen einen
  bestehenden Schlüssel.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `UserDefaults.standard` (Argument-Domain) | framework | liefert `-devPasswordHashForUITests <hash>` ohne eigenes Parsen |
| `CryptoKit.SHA256` | framework | `verify()` (unverändert); der Test berechnet den Testhash zur Laufzeit |
| `@AppStorage("developerMode")` | state | Zielzustand des Richtig-Pfads; `PremiumService` leitet „Pro aktiv“ daraus ab |
| `RestockUITests/PaywallUITests.swift` (Zeilen 112–150) | test | Vorbild Mehrfachtipp, Fokus-Warten, Muster `tapWhenHittable`/`scrollTo` |
| `RestockUITests/UITestWait.swift` | test | `UITestLaunch.start`, `waitUntilHittable`, `defaultTimeout` |
| `docs/specs/ui-tests/test-111-durchgang-2-toast-dauer.md` | spec | Muster DEBUG-Argument mit Wert |
| Simulator `Restock-Validate` | tool | lokaler Lauf; nie parallel (Memory „Eigenes Testgerät je Projekt“) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | `releaseDevPasswordHash` + berechnetes `devPasswordHash`, DEBUG-Überschreibung per `devPasswordHashForUITests` (ca. +8/−1) |
| `SmartCart/SmartCartApp.swift` | MODIFY | `clearDeveloperModeForUITestsIfNeeded()` im DEBUG-Block (ca. +8) |
| `RestockUITests/DeveloperModeUnlockUITests.swift` | CREATE | Klasse mit Richtig-Pfad-Kette, Neustart-Beweis, Gegenprobe (ca. +70) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung der Testdatei (ca. +4 Zeilen) |
| `CLAUDE.md` | MODIFY | Absatz zu den beiden Argumenten (Doku) |
| `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` | MODIFY | Hinweis, dass die offene Grenze geschlossen ist (Doku) |

### Estimated Changes

- Code-Dateien: 4 (zwei Produktdateien, eine Testdatei, pbxproj; Limit 4–5), dazu zwei Doku-Dateien.
- LoC: ca. +90 / −2 (Limit ±250). Das LoC-Gate zählt Testcode als Produktivcode (Memory „LoC-Gate zählt
  Testcode als Produktivcode“); vor dem Abschluss `git diff --stat` gegen den Tip-Commit prüfen.
- Seiteneffekte: keine im Release; im DEBUG-Build nur, wenn eines der Argumente gesetzt ist.

## Definition of Done

- [ ] RED-Tests vor der Umsetzung rot, danach grün (AC-1 bis AC-6)
- [ ] Gegenprobe (falsches Passwort bei gesetzter Überschreibung) grün (AC-5)
- [ ] Release-Build kompiliert, Schlüssel `devPasswordHashForUITests` im Release-Binary nicht vorhanden (AC-7)
- [ ] Release-Hash unverändert, `DevPasswordSheet`/`verify()` unberührt (AC-8)
- [ ] Gesamte UI- und Unit-Suite im gemeinsamen Lauf auf `Restock-Validate` grün, Testzahl > 0, kein Abbruch, kein Retry-Flag (AC-9)
- [ ] Durchlauf der App im Simulator ohne Test-Argumente (AC-10)
- [ ] `CLAUDE.md`-Absatz und Hinweis in der D5-Spec vorhanden (AC-11)
- [ ] Diff innerhalb der Limits, nur die genannten Dateien (AC-12)
- [ ] Offene Grenzen in Ticket und Bericht benannt, #145 bleibt offen (AC-13)

## Implementation Details

**Produkt (`SettingsView.swift`).** Skizze (Form legt Phase 5 fest, Verhalten ist verbindlich):

```swift
private static let releaseDevPasswordHash = "fab0966f…7c86"   // Wert unverändert

private var devPasswordHash: String {
    #if DEBUG
    if let override = UserDefaults.standard.string(forKey: "devPasswordHashForUITests"),
       !override.isEmpty { return override }
    #endif
    return Self.releaseDevPasswordHash
}
```

**Produkt (`SmartCartApp.swift`).**

```swift
private static func clearDeveloperModeForUITestsIfNeeded() {
    guard ProcessInfo.processInfo.arguments.contains("-clearDeveloperModeForUITests") else { return }
    UserDefaults.standard.removeObject(forKey: "developerMode")
}
```

Aufruf im DEBUG-Block von `init()`, vor allem, was `developerMode` liest.

**Tests (`DeveloperModeUnlockUITests`).**

- Testpasswort `"uitest-dev-passwort"` als Konstante; der Hash wird im Test mit `CryptoKit.SHA256`
  berechnet (`%02x`, klein, wie `verify()`), kein fest einkopierter Hexwert.
- Start-Argumente: `-hasCompletedOnboarding YES -clearDeveloperModeForUITests -devPasswordHashForUITests <hash>`.
  **Niemals `-developerMode`** (weder `YES` noch `NO`), auch nicht im Aufräumer: Als Launch-Argument
  überlagert es in der Argument-Domain jeden Schreibvorgang bzw. jedes Entfernen, `developerMode` bliebe
  nach richtigem Passwort gelesen `NO` (Falle aus D5). Das Clear-Argument beim Start ist die zweite Hälfte
  des Doppelgurts gegen einen übrig gebliebenen Zustand eines früheren Laufs.
- Kette (Test 1): Zahnrad → „Version“ hineinscrollen → `tap(withNumberOfTaps: 5, numberOfTouches: 1)`
  mit einer Wiederholung nach 2,5 s (Muster `PaywallUITests:112-150`) → Sheet „Developer Mode“ →
  Feld „Passwort“ antippen, Fokus abwarten → Testpasswort tippen → „Entsperren“ → Sheet weg, Zeile
  „Pro aktiv“ vorhanden, „Developer Mode deaktivieren“ im Dev-Abschnitt vorhanden, Pill „DEV“ sichtbar.
  Vorab (Ausgangszustand): „Pro aktiv“ und „DEV“ existieren **nicht**, damit der Test den Schalter
  Fehler/Zustand da → weg belegt und nicht einen Altzustand liest.
- Neustart (Test 2, im selben Test wie die Kette, nach ihr): App beenden, neu starten **ohne**
  `-clearDeveloperModeForUITests` und **ohne** `-devPasswordHashForUITests` (nur
  `-hasCompletedOnboarding YES`) → Einstellungen → „Pro aktiv“ vorhanden und „Developer Mode
  deaktivieren“ vorhanden. Das belegt, dass der Schlüssel wirklich in den App-Container geschrieben wurde
  und der Zustand nicht nur im Speicher stand.
- Gegenprobe (Test 3): Start wie Test 1 (Überschreibung gesetzt), aber Eingabe `"falsch"` → „Falsches
  Passwort“, Sheet bleibt offen, nach „Abbrechen“ existieren „Pro aktiv“ und „DEV“ nicht. Beweist, dass
  die Überschreibung nicht jedes Passwort akzeptiert. Hält klein, weil sie die Hilfsfunktionen aus Test 1
  nutzt.
- `tearDown()`: Start eines Aufräumers mit **nur** `-clearDeveloperModeForUITests` (plus
  `-hasCompletedOnboarding YES`), warten bis die Startseite steht, beenden. Ohne Aufräumen liefen
  Folgetests (Paywall-Sperre, `StoreSetupUITests`, `OnboardingUITests`) mit Premium bzw. Nachkauf-Banner.
- Hilfsfunktionen (`tapWhenHittable`, `scrollTo`) sind in `PaywallUITests` `private`; in der neuen Klasse
  werden sie dupliziert (je wenige Zeilen), `UITestWait.swift` bleibt unverändert.

**RED-Verfahren.** Test 1 wird vor der Produktänderung geschrieben und fällt dann an einer belegten
Stelle: Das Argument `-devPasswordHashForUITests` ist unbekannt, der Release-Hash bleibt gültig, das
Testpasswort wird abgelehnt („Falsches Passwort“, Sheet bleibt). Nach der Umsetzung ist derselbe Test grün
(Schalter Fehler da → Fix → Fehler weg). Test 3 ist vor der Umsetzung ebenfalls grün (kein
Gegenbeispiel nötig, er sichert die Gegenrichtung ab) und wird deshalb nicht als RED-Beleg gezählt.

**Release-Nachweis.** `xcodebuild -configuration Release -destination 'generic/platform=iOS Simulator'
build`, danach `strings` auf die ausführbare Datei der gebauten `Restock.app`: Der Schlüssel
`devPasswordHashForUITests` und `clearDeveloperModeForUITests` kommen nicht vor. Gegenprobe mit dem
Debug-Build, in dem beide Schlüssel vorkommen (zeigt, dass die Suche greift).

**Durchlauf (Pflicht, „Die App wird benutzt, nicht nur gebaut“).** Nach grüner Suite startet die App im
Simulator **ohne** eines der beiden Argumente: Einstellungen → 5× auf „Version“ → Sheet erscheint →
falsches Passwort wird abgelehnt → Abbrechen; kein Dev-Modus. Ergänzend ein Start mit beiden Argumenten,
der die Kette mit dem Testpasswort zeigt. Der Durchlauf wird als Artefakt registriert (echter Lauf,
Commit-Kennung und Zeitstempel passend, nie von Hand gesetzt).

**Lokal:** Gesamte UI-Suite auf `Restock-Validate` im gemeinsamen Lauf, ohne zusätzliche Build-Settings
(Memory „CODE_SIGNING_ALLOWED=NO bricht die App-Gruppe“); Testzahl > 0 und Abbrüche prüfen (Memory
„Null-Test-Lauf ist kein Grün“). Zustandsleck wird nur im gemeinsamen Lauf sichtbar (Memory „UI-Test-Seeds
müssen aufräumen“).

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED): `DeveloperModeUnlockUITests.testCorrectDevPasswordUnlocksAndSurvivesRestart` — GIVEN Start
  mit Clear- und Hash-Argument, WHEN 5× „Version“, Testpasswort, „Entsperren“, THEN Sheet zu, „Pro aktiv“,
  „Developer Mode deaktivieren“, „DEV“-Pill; nach Neustart ohne Argumente bleibt „Pro aktiv“.
- [ ] T2: `testWrongPasswordWithOverrideDoesNotUnlock` — GIVEN gesetzte Überschreibung, WHEN „falsch“
  eingegeben, THEN „Falsches Passwort“, Sheet offen, nach „Abbrechen“ kein „Pro aktiv“, kein „DEV“.
- [ ] T3: `tearDown` — GIVEN erfolgreicher Entsperrlauf, WHEN der Aufräumer mit
  `-clearDeveloperModeForUITests` startet, THEN ist der Dev-Modus aus; belegt durch den nächsten Test der
  Suite (z. B. `PaywallUITests` sperrt weiter) im gemeinsamen Lauf.
- [ ] T4: Bestehender Falsch-Pfad-Test `PaywallUITests.testWrongDevPasswordShowsErrorAndKeepsSheetOpen`
  bleibt unverändert grün (Release-Hash greift ohne Argument).
- [ ] T5: GIVEN die gesamte UI- und Unit-Suite, WHEN sie lokal im gemeinsamen Lauf läuft, THEN alles grün,
  Testzahl > 0.
- [ ] T6: GIVEN Release-Build, WHEN `strings` auf das Binary läuft, THEN kommen
  `devPasswordHashForUITests` und `clearDeveloperModeForUITests` nicht vor; im Debug-Build kommen sie vor.
- [ ] T7: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat` läuft, THEN nur die genannten
  Dateien, ca. +90/−2 LoC, Release-Hash-Literal unverändert.

## Acceptance Criteria

- **AC-1:** GIVEN Start (DEBUG) mit `-clearDeveloperModeForUITests` und `-devPasswordHashForUITests <sha256("uitest-dev-passwort")>`
  ohne `-developerMode`, WHEN der Nutzer in den Einstellungen fünfmal auf „Version“ tippt, das Testpasswort
  eingibt und „Entsperren“ antippt, THEN schließt das Sheet „Developer Mode“, die Zeile „Pro aktiv“ und die
  Schaltfläche „Developer Mode deaktivieren“ erscheinen. Vorher existierten „Pro aktiv“ und „DEV“ nicht.
  Test: T1.
- **AC-2:** GIVEN derselbe Lauf, WHEN der Dev-Modus aktiv ist, THEN zeigt jeder Screen die DEV-Pill
  („DEV“); geprüft nach dem Schließen der Einstellungen auf der Startseite oder in den Einstellungen. Test: T1.
- **AC-3:** GIVEN der Zustand aus AC-1, WHEN die App beendet und ohne `-clearDeveloperModeForUITests` und
  ohne `-devPasswordHashForUITests` neu gestartet wird, THEN ist „Pro aktiv“ weiter sichtbar und
  „Developer Mode deaktivieren“ vorhanden (Schlüssel `developerMode` wirklich geschrieben). Test: T1.
- **AC-4:** GIVEN `-clearDeveloperModeForUITests` beim Start, WHEN vorher `developerMode = true`
  gespeichert war, THEN ist nach dem Start der Dev-Modus aus („Pro aktiv“ und „DEV“ existieren nicht);
  der `tearDown()` der Klasse räumt damit auf, sodass der folgende Test der Suite ohne Premium startet.
  Test: T1 (Start-Vorzustand), T3 im gemeinsamen Lauf.
- **AC-5:** GIVEN gesetzte Überschreibung, WHEN ein falsches Passwort eingegeben wird, THEN erscheint
  „Falsches Passwort“, das Sheet bleibt offen, und nach „Abbrechen“ gibt es weder „Pro aktiv“ noch „DEV“.
  Test: T2.
- **AC-6:** GIVEN die Tests ohne Überschreibung, WHEN der bestehende Falsch-Pfad-Test
  `testWrongDevPasswordShowsErrorAndKeepsSheetOpen` läuft, THEN ist er unverändert grün (der feste
  Release-Hash gilt, wenn das Argument fehlt). Test: T4.
- **AC-7:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert und `strings`
  auf die ausführbare Datei läuft, THEN gelingt der Build, und weder `devPasswordHashForUITests` noch
  `clearDeveloperModeForUITests` kommen vor (im Debug-Build kommen beide vor). Test: T6.
- **AC-8:** GIVEN der Diff, WHEN geprüft wird, THEN ist das Hash-Literal in `SettingsView` byte-gleich
  (nur Name und Sichtbarkeit ändern sich), `DevPasswordSheet` und `verify()` sind unberührt, und die
  Überschreibung steht ausschließlich in `#if DEBUG`. Test: T7.
- **AC-9:** GIVEN die gesamte UI- und Unit-Suite, WHEN sie im gemeinsamen Lauf auf `Restock-Validate`
  läuft (ohne zusätzliche Build-Settings), THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen
  Abbruch und kein Retry-Flag; insbesondere bleiben `PaywallUITests`, `OnboardingUITests` und
  `StoreSetupUITests` grün (kein übrig gebliebenes `developerMode = true`). Test: T5.
- **AC-10:** GIVEN die App im Simulator ohne eines der beiden Argumente, WHEN sie als Nutzer durchgespielt
  wird (5× „Version“, falsches Passwort, Abbrechen), THEN bleibt der Dev-Modus aus; ein Start mit beiden
  Argumenten zeigt die Kette mit dem Testpasswort. Der Durchlauf ist als Artefakt registriert (echter
  Lauf, Commit-Kennung und Zeitstempel passend).
- **AC-11:** GIVEN der Abschluss, WHEN die Doku geprüft wird, THEN beschreibt `CLAUDE.md` beide Argumente
  (Wirkung, Aufräumen, Argument-Domain-Falle, Release nicht kompiliert, offene Grenze), und die D5-Spec
  verweist im Abschnitt „Dev-Passwort: Entscheidung Richtig-Pfad“ auf die Schließung durch diese Spec.
- **AC-12:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er `SettingsView.swift`,
  `SmartCartApp.swift`, `DeveloperModeUnlockUITests.swift`, `project.pbxproj` sowie `CLAUDE.md` und die
  D5-Spec, ca. +90/−2 LoC im Code, ohne neue Produkt-Strings, Dependencies, `Info.plist`- oder
  `@AppStorage`-Änderung. Test: T7.
- **AC-13:** GIVEN der Abschluss des Durchgangs, WHEN Ticket und Berichte formuliert werden, THEN sind
  ausdrücklich als offen genannt: Release-Pfad mit echtem Passwort und festem Hash (ungetestet, Passwort
  dem Test unbekannt) sowie Durchgänge 2–4 von #145; #145 bleibt offen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue
- **Rationale:** DEBUG-only Launch-Argumente nach bestehendem Muster (`SmartCartApp.swift`,
  `HomeView.showQuickAddToast`). Gekippt wird die Arbeitsentscheidung aus der D5-Spec „Produktcode des
  Dev-Passworts bleibt unverändert, Richtig-Pfad offen“; sie war ausdrücklich als Arbeitsstand
  formuliert, keine ADR.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | DEBUG-Argument überschreibt den **Hash**, `verify()` unverändert, ganze Kette inkl. Neustart über die Oberfläche | prüft Verdrahtung, Sheet-Schließen, Premium, Dev-Abschnitt, Persistenz; Produktänderung nur unter `#if DEBUG`; echtes Passwort bleibt unbekannt |
| B | Unit-Test einer ausgegliederten Funktion `matches(input:hash:)` | ca. 20 LoC, stabil, aber prüft nur die Hash-Formel; Verdrahtung und Persistenz, die Lücke aus #98, blieben offen; höchstens als Zusatz, nicht als Ersatz |
| C | Klartext-Testpasswort per Argument | müsste `verify()` umgehen oder ändern, der echte Vergleichsweg bliebe ungetestet; verworfen |
| D | Offen lassen (Stand D5) | kein Aufwand, aber der Richtig-Pfad bleibt ungeschützt (z. B. gegen falschen Schlüssel oder Sheet, das nicht schließt); wird mit diesem Durchgang gekippt |
| E | Test als Methode in `PaywallUITests` statt eigener Klasse | spart pbxproj-Eintrag, aber der Aufräumer im `tearDown()` liefe nach jedem Paywall-Test (Mehrzeit) oder müsste bedingt sein; eigene Klasse gewählt |

Kein Modell beteiligt: deterministische Testlogik. Gekippte frühere Entscheidung: nur die D5-Arbeitsentscheidung
(siehe ADR-Abschnitt).

**Entscheidung:** Weg A.

## Risiken

- **Argument-Domain-Falle:** `-developerMode` im Test oder im Aufräumer überdeckt Schreiben bzw. Entfernen.
  Gegenmaßnahme: Argument kommt in der Klasse nie vor; AC-1/AC-3 würden sonst rot.
- **Zustandsleck:** Bleibt `developerMode = true` im Container, erben es Klassen ohne `-developerMode`
  (`StoreSetupUITests`, `OnboardingUITests`): Premium frei, Nachkauf-Banner. Gegenmaßnahme:
  Doppelgurt (Clear beim Start und im `tearDown()`), Nachweis im gemeinsamen Lauf (AC-9).
- **5-Tipp-Fenster 2 s / Tastaturfokus:** Mehrfachtipp mit einer Wiederholung nach 2,5 s und
  Fokus-Warten übernehmen (Muster aus `PaywallUITests`); Memory „UI-Test liest Feld nach typeText zu
  früh“: nach dem Tippen auf das Ergebnis warten, nicht sofort lesen.
- **Release-Sicherheit:** Überschreibung nur unter `#if DEBUG`; Absicherung durch `strings`-Nachweis
  (AC-7) und Diff (AC-8).
- **Neustart-Beweis zeigt nur den Container:** Der Neustart belegt Persistenz im Simulator-Container, nicht
  auf Hennings Gerät. Nichts wird auf Hennings Geräten gestartet (Regel „Hennings Geräte nur auf sein
  Wort“); Simulator genügt.
- **Zeilennummern verschieben sich:** Maßgeblich sind die Namen, nicht die Zeilen.
- **LoC-Gate zählt Testcode als Produktivcode:** ca. +90 deutlich unter dem Limit; trotzdem prüfen.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün.

## Folge-Durchgänge im selben Ticket

- Durchgang 2: Mitteilungserlaubnis-Dialog (Springboard-Alert bzw. `addUIInterruptionMonitor`; Ausgangszustand
  „nie gefragt“ nur über Neuinstallation herstellbar).
- Durchgang 3: `AppIntentsTesting` (iOS 27, CI-Runner-Version prüfen).
- Durchgang 4: Kauf/Wiederherstellen (`Restock.storekit`, `SKTestSession` statt Scheme-Änderung erwägen).
- Alle drei: nicht Teil dieser Spec, eigene Specs; #145 bleibt bis dahin offen.

## Changelog

- 2026-10-15: Initial spec created (Durchgang 1 von #145; Hash-Überschreibung und Aufräum-Argument als
  DEBUG-only Launch-Argumente, ganze Kette inkl. Neustart und Gegenprobe über die Oberfläche)
