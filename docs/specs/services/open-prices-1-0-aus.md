---
entity_id: open-prices-1-0-aus
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: fix-244-open-prices-aus
tags: [feature, open-prices, app-review, release-1-0, issue-244]
---

# Open Prices für 1.0 ausblenden und sperren (Issue #244)

## Approval

- [ ] Approved

Entscheidung des PO vom 2026-11-01, hier übernommen und nicht neu verhandelt: Apple hat 1.0 mit Guideline 2.1
zurückgegeben. „Open Prices“ (öffentlicher Upload von Bonfotos an Open Food Facts, bisher gegen den Testserver)
wird für 1.0 ausgeblendet. Danach folgen ein neuer Build, die Notes und die Antwort an Apple. Quellen:
`docs/context/fix-244-open-prices-aus.md` (Kontext und Analyse), Issue #244, Funktionsspec
`docs/specs/services/open-prices-contribution.md` (#184).

## Purpose

Die Funktion „Open Prices“ soll in 1.0 weder auffindbar noch wirksam sein. Ein Ausblenden des Einstiegs allein
genügt nicht: Wer seit Build 34 (2026-10-22) den Schalter eingeschaltet und sich angemeldet hat, würde ohne Einstieg
weiter Bonfotos senden. Deshalb sperrt eine einzige Konstante sowohl den Einstieg in den Einstellungen als auch den
Sendeweg im Dienst.

Hat es bisher funktioniert? Ja, die Funktion arbeitete wie in #184 beschrieben (Builds 34 bis 38); es ist keine
Verschlechterung, sondern eine Produktentscheidung wegen der App-Review-Rückmeldung.

## Source

- **File:** `SmartCart/Services/OpenPricesContributionService.swift`, `SmartCart/Views/Settings/SettingsView.swift`
- **Identifier:** `OpenPricesContribution.isAvailable`, `OpenPricesContributionService.init(…, available:)`,
  `OpenPricesContributionService.readiness(for:hasImage:)`, Abschnitt „Funktionen“ in `SettingsView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `OpenPricesContribution` (#184) | Enum | Heimat der neuen Konstante `isAvailable`; `Readiness` kennt bereits `.disabled` |
| `OpenPricesContributionService` (#184) | Actor | Bereitschaftsprüfung vor jedem Senden; Nähte per Initialisierer (`api`, `tokens`, `defaults`, `locations`, `now`) |
| `ReceiptScannerView.save()` | View | einziger Sendeaufruf (`contributeInBackground`), bleibt unverändert |
| `OpenPricesSettingsView` (#184) | View | bleibt als Code bestehen, ist nur nicht mehr erreichbar |
| `RestockTests/OpenPricesContributionTests.swift` | Test | Bestandstests bleiben grün über `available: true` |
| `RestockUITests/UITestWait.swift` | Testhilfe | `UITestWait.defaultTimeout`, `waitUntilHittable()` |
| Launch-Argumente `-hasCompletedOnboarding YES`, `-developerMode YES` | UI-Test | Startzustand; beide werden nur gelesen, nichts wird in den App-Gruppen-Container geschrieben |

## Lösung

Eine Konstante als einziger Schalter für die Verfügbarkeit, an zwei Stellen gelesen:

1. `OpenPricesContribution.isAvailable` (`static let`, Wert `false`, Kommentar mit Verweis auf Issue #244). Der Wert
   gilt in DEBUG und Release gleich, damit UI-Test und Simulator-Durchlauf genau das Release-Verhalten zeigen. Ein
   Release-Nachweis per `strings` ist deshalb nicht nötig.
2. `OpenPricesContributionService.init` bekommt den Parameter `available: Bool = OpenPricesContribution.isAvailable`.
   `readiness(for:hasImage:)` liefert ohne Verfügbarkeit `.disabled`, bevor Schalter, Anmeldung, Filiale oder Foto
   gelesen werden. `contribute(lines:imageData:storeID:date:)` verlangt `.ready` und kehrt deshalb mit `nil` zurück:
   kein Foto-Upload, keine Preise, kein Auth-Aufruf, kein Schreiben von `openPricesLastResult`. Der Singleton
   `shared` nutzt den Standardwert und ist damit gesperrt.
3. `SettingsView` zeigt den `NavigationLink` „Open Prices“ im Abschnitt „Funktionen“ nur, wenn
   `OpenPricesContribution.isAvailable` wahr ist. Der Eintrag fehlt auch im Entwicklermodus.

Der Aufruf in `ReceiptScannerView.save()` bleibt, der Dienst sperrt selbst. Das ist die schwächere Kopplung und
vermeidet eine zweite Stelle, die vergessen werden könnte.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/OpenPricesContributionService.swift` | MODIFY | Konstante `isAvailable`; Init-Parameter `available`; `readiness` meldet `.disabled` ohne Verfügbarkeit |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | `NavigationLink` „Open Prices“ (Z. ~139–144) nur bei `isAvailable` |
| `RestockTests/OpenPricesContributionTests.swift` | MODIFY | Helfer `service(...)` baut mit `available: true`; neue Unit-Tests |
| `RestockUITests/RestockUITests.swift` | MODIFY | Zwei UI-Tests: Einstellungen ohne Zeile „Open Prices“ (normal und mit `-developerMode YES`) |
| `CLAUDE.md` | MODIFY | Absatz „Open Prices beitragen“ um „in 1.0 ausgeblendet (#244)“ ergänzen |

### Estimated Changes

- Files: 4 Code/Test + CLAUDE.md
- LoC: +~65/−~3 (davon ~45 Testcode)

### Außerhalb des Umfangs

- Build-Nummer 39 (`CURRENT_PROJECT_VERSION` in `project.yml` und `project.pbxproj`), TestFlight-Upload, Zuordnung zu
  1.0, Notes-Feld und Antwort an Apple: eigene kleine Schritte danach (wie #239), jeder außenwirksame Schritt nur auf
  Hennings Wort. Die Bildschirmaufnahme für Apple macht Henning auf seinem iPhone, nur auf sein Wort.
- Datenschutztexte (`LegalView`, `PrivacyInfo.xcprivacy`, `docs/appstore/datenschutz.md`) bleiben unverändert. Zu viel
  deklariert ist zulässig; eine Änderung an `LegalView` zöge `datenschutz.md` und die von einem Dritten gepflegte
  Datenschutzseite nach sich und gehört nicht in dieses Ticket.
- Code von `OpenPricesSettingsView`, `ReceiptScannerView`, Lokalisierung: unverändert.

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (Unit): GIVEN die Konstante WHEN gelesen THEN `OpenPricesContribution.isAvailable == false`.
- [ ] T2 (Unit): GIVEN Schalter an, Token vorhanden, Filiale gesetzt, Foto vorhanden und Dienst mit `available: false`
  WHEN `contribute(lines:imageData:storeID:date:)` aufgerufen wird THEN Ergebnis `nil`, die Fake-API hat null Aufrufe
  (kein `authenticate`, `uploadProof`, `createPrice`) und `lastResult()` ist `nil`.
- [ ] T3 (Unit): GIVEN dieselbe Ausgangslage WHEN `readiness(for:hasImage: true)` gefragt wird THEN `.disabled`; mit
  `available: true` und sonst gleichen Eingaben `.ready` (Gegenprobe).
- [ ] T4 (Unit): GIVEN `OpenPricesContributionService.shared` WHEN `readiness(for: UUID(), hasImage: true)` gefragt
  wird THEN `.disabled`, unabhängig vom Zustand des Schalters in `UserDefaults.standard` (Test setzt und entfernt den
  Schalter nicht; `shared` liest ihn zwar, die Sperre greift vorher).
- [ ] T5 (Unit): GIVEN die Bestandstests S1–S5 mit Helfer `service(...)` und `available: true` WHEN sie laufen THEN
  bleiben sie unverändert grün (Funktion selbst weiter geprüft).
- [ ] T6 (UI): GIVEN Start mit `-hasCompletedOnboarding YES` WHEN Einstellungen über das Zahnrad geöffnet werden THEN ist
  „Standard-Läden“ sichtbar (Gegenprobe, dass der Abschnitt „Funktionen“ geladen ist) und eine Zeile „Open Prices“
  existiert nicht.
- [ ] T7 (UI): GIVEN Start mit `-hasCompletedOnboarding YES -developerMode YES` WHEN Einstellungen geöffnet werden THEN
  „Standard-Läden“ sichtbar und „Open Prices“ existiert nicht. Das Argument wird nur gelesen; es wird nichts
  geschrieben, daher kein Aufräum-Argument nötig (Argument-Domain-Falle betrifft nur Klassen, die den Schlüssel
  selbst schreiben oder entfernen).

UI-Tests warten mit den Hilfen aus `RestockUITests/UITestWait.swift` und prüfen die Abwesenheit erst, nachdem die
Gegenprobe sichtbar ist (die Einstellungen sind eine Form, die nur sichtbare Zeilen in den Baum stellt; bei Bedarf
vor dem Prüfen der Abwesenheit bis zum Ende des Abschnitts „Funktionen“ scrollen).

### Simulator-Durchlauf (Pflicht vor Übergabe)

Die App wird im Simulator gestartet und als Nutzer durchgespielt: Einstellungen öffnen, Abschnitt „Funktionen“
ansehen; dann mit vorher gesetztem Schalter `openPricesContributionEnabled=true` einen Bon speichern und per
`openPricesLastResult` belegen, dass nichts gesendet wurde.

## Acceptance Criteria

- [ ] AC-1: `OpenPricesContribution.isAvailable` ist `false` und trägt einen Kommentar mit Verweis auf Issue #244. Test: `OpenPricesContributionTests::testOpenPricesIsUnavailableInRelease1_0` (T1).
- [ ] AC-2: Ein Dienst mit `available: false` sendet nie, auch nicht bei eingeschaltetem Schalter, vorhandenem Token,
  gesetzter Filiale und Foto: `contribute(lines:…)` liefert `nil`, die Fake-API verzeichnet keinen Aufruf.
  Test: `OpenPricesContributionTests::testUnavailableServiceNeverSends` (T2).
- [ ] AC-3: `readiness(for:hasImage:)` liefert bei `available: false` `.disabled`, bei `available: true` mit sonst
  gleichen Eingaben `.ready`. Test: `OpenPricesContributionTests::testReadinessIsDisabledWhenUnavailable` (T3).
- [ ] AC-4: Der Singleton `OpenPricesContributionService.shared` ist gesperrt (`.disabled`).
  Test: `OpenPricesContributionTests::testSharedServiceIsUnavailable` (T4).
- [ ] AC-5: Alle bisherigen Open-Prices-Unit-Tests laufen mit `available: true` unverändert grün.
  Test: alle übrigen Testfälle der Klasse `OpenPricesContributionTests` im Klassenlauf (T5).
- [ ] AC-6: In den Einstellungen gibt es ohne Entwicklermodus keine Zeile „Open Prices“; „Standard-Läden“ ist als
  Gegenprobe sichtbar. Test: `RestockUITests::testSettingsHideOpenPrices` (T6).
- [ ] AC-7: Auch mit `-developerMode YES` gibt es keine Zeile „Open Prices“.
  Test: `RestockUITests::testSettingsHideOpenPricesInDeveloperMode` (T7).
- [ ] AC-8: Simulator-Durchlauf mit dem Stand, den Henning bekommt: Einstellungen → Funktionen zeigt keinen Eintrag
  „Open Prices“; ein gespeicherter Bon mit vorher gesetztem `openPricesContributionEnabled=true` löst keinen Sendeversuch
  aus, `openPricesLastResult` bleibt unverändert bzw. leer (Nachweis als Artefakt unter
  `docs/artifacts/fix-244-open-prices-aus/`). Beleg: Simulator-Durchlauf (Abschnitt oben) mit Bildschirmfoto der
  Einstellungen und `defaults read` vor und nach dem Speichern; kein automatisierter Test, weil der Bon-Weg über Kamera
  bzw. Teilen-Erweiterung führt.
- [ ] AC-9: Die volle Unit-Suite und die UI-Klasse `RestockUITests` sind grün, der Build kompiliert. Test: Unit-Suite
  `RestockTests` und Klasse `RestockUITests` per `xcodebuild test` auf `Restock-Validate`, Protokolle unter
  `docs/artifacts/fix-244-open-prices-aus/`; Gesamtsuite in der CI.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, Tests T1–T7 grün
- [ ] Simulator-Durchlauf als Artefakt registriert
- [ ] CLAUDE.md-Absatz zu Open Prices um den Stand „in 1.0 ausgeblendet“ ergänzt
- [ ] Issue #244 mit Stand aktualisiert (Build 39, Notes und Antwort folgen getrennt)

## Alternativen

- **Nur im Entwicklermodus zeigen** (Muster KI-Preisschätzung #164): Henning könnte weiter testen. Verworfen, weil die
  Funktion nur an den Testserver sendet und App Review keinen Weg zu einem öffentlichen Bonfoto-Upload finden soll.
- **`#if DEBUG`**: Release ohne Funktion, Debug mit. Verworfen, weil der UI-Test (DEBUG) dann nicht das
  Release-Verhalten zeigt.
- **Code ganz entfernen**: größter Umfang und kippt #184; für eine spätere Version nicht nötig.
- **Gespeicherten Schalter beim Start auf aus setzen**: ändert Nutzerdaten, schützt nicht gegen späteres Einschalten;
  schwächer als die Sperre im Dienst.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Eine Verfügbarkeitskonstante für eine Funktion einer Version ist ein lokaler Schalter ohne
  Architekturwirkung; die Entscheidung selbst (Open Prices in 1.0 aus) steht im Ticket #244 und in dieser Spec.

## Offene Grenzen

- Der Altzustand bleibt gespeichert: Schalter `openPricesContributionEnabled`, Token im Schlüsselbund, Nutzername und
  Filialen von Testern seit Build 34 werden nicht gelöscht, nur nicht mehr genutzt. Wer die Funktion in einer späteren
  Version freischaltet, findet sie wieder eingeschaltet vor.
- Die Datenschutzangaben (`LegalView`, `PrivacyInfo.xcprivacy`, `datenschutz.md`, App-Privacy-Fragebogen) nennen Open
  Prices und den ungefähren Standort weiter; das ist zu viel deklariert, aber zulässig. Eine Bereinigung wäre ein
  eigenes Ticket mit Abstimmung zur Datenschutzseite des Dritten.
- Bereits an den Testserver gesendete Beiträge bleiben dort; es gibt keinen Rückruf.
- Das Verhalten ist nur im Simulator und in Tests geprüft; nichts auf Hennings Geräten geprüft.
- Die Konstante ist eine Kompilierzeit-Entscheidung; es gibt keine Fernschaltung.

## Changelog

- 2026-11-01: Initial spec created
- 2026-11-01: Umsetzung validiert. AC-9 mit PO-Ausnahme (Auswahl „Ausnahme, weiter“): drei Fremdfehler, die mit dem Produktcode von main identisch auftreten (`ConsumptionPatternTests` ×2 → #231, `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` → #17). Adversary AMBIGUOUS mit PO-OK; offene Grenze F002: `contribute(_ plan:)` prüft `available` nicht selbst, produktiv nur über `contribute(lines:)` erreichbar.
