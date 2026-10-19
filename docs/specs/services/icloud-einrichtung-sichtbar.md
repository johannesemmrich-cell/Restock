---
entity_id: icloud-einrichtung-sichtbar
type: bugfix
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: fix-166-icloud-einrichtung-sichtbar
tags: [bugfix, cloudkit, swiftdata, diagnose, entwicklermodus, issue-166]
---

# iCloud-Einrichtung sichtbar (Issue #166)

## Approval

- [ ] Approved

Entscheidungen des PO vom 2026-10-19, hier übernommen und nicht neu verhandelt: **Entwurf A** (gescheiterte
Einrichtung samt Ursache in der Dev-Diagnose, Quelle ist das Einrichtungsereignis der Spiegelung) und der
Umfang **6 Code-/Testdateien plus 2 Dokumentationsdateien, ca. +170/−15 Zeilen, ein Durchgang** (über der
Dateigrenze der Scoping-Limits, vom PO akzeptiert). Quelle: `docs/context/fix-166-icloud-einrichtung-sichtbar.md`,
freigegebener Entwurf: `docs/artifacts/fix-166-icloud-einrichtung-sichtbar/entwurf.html`.

## Purpose

Die Entwickler-Diagnose „iCloud-Abgleich“ (Issue #156) zeigt „noch kein Lauf“, wenn die private iCloud-Spiegelung
gar nicht erst startet, etwa ohne iCloud-Konto. Die Einrichtung ist dann gescheitert, die Anzeige verschweigt es.
Diese Spec zeigt die gescheiterte Einrichtung samt Ursache im Entwicklermodus (reine Anzeige) und schließt dabei
einen möglichen Wettlauf, durch den ein Einrichtungsereignis verloren gehen könnte.

Hat es bisher funktioniert? Nein, das ist eine Diagnoselücke aus #156, keine Verschlechterung: Die Festlegung
„Einrichtungsläufe werden ignoriert“ stand von Anfang an in der Spec von #156.

## Ist-Zustand (belegt)

- Durchlauf 2026-10-18 auf `Restock-Validate` ohne iCloud-Konto
  (`docs/artifacts/fix-156-icloud-abgleich-sichtbar/durchlauf-echte-app.txt`):
  `NSCloudKitMirroringDelegate _performSetupRequest: Failed to set up CloudKit integration …`,
  `NSCocoaErrorDomain 134400 "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."`.
  Danach kamen keine Export-/Import-Ereignisse, `smartcart.cloudMirror.*` blieb leer, die Anzeige sagte „noch kein Lauf“.
- Ursache im Code: `CloudMirrorMonitor.handle(type:succeeded:error:endDate:)` hat den Guard
  `guard let endDate, type == .export || type == .import` und verwirft damit `type == .setup`.
- Die Einrichtung läuft bei **jedem App-Start** erneut (im Protokoll zwei Prozesse, 22:54:10 und 22:55:32, je
  `_performSetupRequest` mit 134400). Eine spätere erfolgreiche Einrichtung (Konto angemeldet) löst den Fehler
  deshalb zuverlässig ab, ein eigener Rücksetzweg ist nicht nötig.
- Startreihenfolge: `CloudMirrorMonitor.shared.start()` steht im `defer` von `SmartCartApp.init()`, also nach der
  Container-Erzeugung (`SharedModelContainer.make()`). Im Durchlauf lagen rund 10 ms zwischen Kontoabfrage und
  Fehler. Apple rät, Beobachter vor dem Laden des Stores zu registrieren, sonst können Einrichtungsereignisse
  verloren gehen (https://developer.apple.com/forums/thread/701564,
  https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer).
- Recherche zum Ereignis: 134400 entsteht im Setup-Schritt von `NSPersistentCloudKitContainer`; das Ereignis kommt
  über `eventChangedNotification` mit `type == .setup`, `succeeded == false` und gesetztem `error`
  (Apple Forums 119457 und 771870, TN3164).

## Lösung (Entwurf A)

1. **`handle` nimmt `.setup` an.** Neben `.export` und `.import` wird `.setup` verarbeitet; ein beendetes
   Einrichtungsereignis wird als `lastSetup` gespeichert (Schlüssel `smartcart.cloudMirror.lastSetup`). Laufende
   Ereignisse (`endDate == nil`) bleiben ignoriert. Ein Erfolg überschreibt einen früheren Fehler, weil jeder Start
   eine Einrichtung meldet. Die Export-Zähler zählen weiter nur Exporte; `lastExport` und `lastImport` bleiben
   unberührt, damit `firstImportFinished` (Onboarding) nicht reagiert.
2. **Untertitel der Dev-Zeile.** Eine gescheiterte letzte Einrichtung hat Vorrang:
   „Einrichtung fehlgeschlagen · HH:mm“ in `Color.destructive`. Ohne gescheiterte Einrichtung bleibt die
   Export-Logik wie heute („Export erfolgreich · HH:mm“, „Export fehlgeschlagen · HH:mm“, „noch kein Lauf“).
   Neue Signatur: `devRowSubtitle(lastSetup:lastExport:)`.
3. **Detailansicht `CloudMirrorStatusView`.** Ganz oben der Abschnitt „Einrichtung (beim App-Start)“ mit den
   Zeilen Zustand, Zeit und Fehler (bei Erfolg ohne Fehler, ohne Lauf „noch kein Lauf“). Bei Fehler folgt direkt
   darunter ein Ursache-Abschnitt: die Überschrift „Ursache: kein iCloud-Konto“ für bekannte Codes, sonst nur
   „Ursache“; im Abschnitt steht der Systemtext. Die Abschnitte Letzter Export, Letzter Import und Seit Installation
   bleiben unverändert. Die Klartext-Zuordnung ist eine reine Funktion in `CloudMirrorMonitor`:
   `NSCocoaErrorDomain` 134400 → „kein iCloud-Konto“; jeder andere Code liefert keinen Klartext.
4. **Beobachter vor dem Container.** `CloudMirrorMonitor.shared.start()` wird in `SmartCartApp.init()` vor die
   erste Container-Erzeugung gezogen (vor `SharedModelContainer.make()`), nicht mehr im `defer`.
   `startedAt` wird dadurch früher gesetzt; `firstImportFinished` vergleicht `run.date >= startedAt` und bleibt
   korrekt. Der Beobachter liest nur und schreibt nur `smartcart.cloudMirror.*`.
   Nur in DEBUG-Builds und nur mit einem der Argumente `-seedCloudMirrorStatusForUITests` oder
   `-seedCloudMirrorSetupFailureForUITests` wird `start()` nicht aufgerufen, damit ein echtes Einrichtungsereignis
   (Simulator ohne Konto meldet bei jedem Start 134400) den gesäten Zustand nicht überschreibt und die
   bestehenden UI-Tests deterministisch bleiben. Release-Builds sind davon nicht berührt.
5. **Nachweis.** Unit-Tests und UI-Test mit Seed (RED vorher), danach echter Durchlauf auf `Restock-Validate`
   ohne iCloud-Konto, ohne Seed-Argumente: die Diagnose zeigt die Einrichtung mit 134400 statt „noch kein Lauf“.

Texte der Ansicht sind wörtlich die aus dem Entwurf: Zeilenuntertitel „Einrichtung fehlgeschlagen · 22:54“,
Abschnitt „Einrichtung (beim App-Start)“, Zeilen „Zustand“ / „fehlgeschlagen“, „Zeit“, „Fehler“
(„NSCocoaErrorDomain 134400“), Überschrift „Ursache: kein iCloud-Konto“, darunter
`Unable to initialize without an iCloud account (CKAccountStatusNoAccount).`

## Source

- **File:** `SmartCart/Services/CloudMirrorMonitor.swift`
- **Identifier:** `CloudMirrorMonitor.handle`, `CloudMirrorMonitor.devRowSubtitle`, `CloudMirrorStatusStore`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NSPersistentCloudKitContainer.eventChangedNotification` / `.Event` / `.EventType.setup` (CoreData) | system | Quelle des Einrichtungsereignisses (`type`, `succeeded`, `error`, `endDate`) |
| `CloudMirrorMonitor.summarize(error:)`, `CloudMirrorSummary` | module | Zusammenfassung des Einrichtungsfehlers (Domain, Code, Text) |
| `CloudMirrorStatusStore` (`UserDefaults.standard`, Präfix `smartcart.cloudMirror.`) | module | Ablage von `lastSetup`; `clear()` löscht per Präfix auch den neuen Schlüssel |
| `OnboardingView` / `OnboardingCloudGate` (`firstImportFinished`) | module | darf durch Einrichtungseinträge nicht beeinflusst werden |
| `SettingsView` Dev-Sektion, `CloudMirrorStatusView` | views | Untertitel und Detailansicht |
| `SharedModelContainer.make()` | module | Reihenfolge: Beobachter muss vorher starten |
| `RestockTests/CloudMirrorMonitorTests.swift`, `RestockUITests/ICloudDiagnosticsUITests.swift` | test | Ausgangspunkt der neuen Tests |
| `UITestWait` / `UITestLaunch` | test helper | Wartehilfen der UI-Tests |
| `docs/specs/services/icloud-abgleich-sichtbar.md` (#156) | spec | Festlegung „Einrichtungsläufe werden ignoriert“ wird geändert |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/CloudMirrorMonitor.swift` | MODIFY | `handle` nimmt `.setup` an (Zähler nur Export, Import unberührt); `runKey` um `lastSetup`; `devRowSubtitle(lastSetup:lastExport:)` mit Vorrang; reine Klartext-Zuordnung 134400 |
| `SmartCart/Views/Settings/CloudMirrorStatusView.swift` | MODIFY | Abschnitt „Einrichtung (beim App-Start)“ oben, Ursache-Abschnitt mit Klartext-Überschrift |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | Untertitel-Aufruf übergibt zusätzlich `lastRun(.setup)` (1–2 Zeilen) |
| `SmartCart/SmartCartApp.swift` | MODIFY | `start()` vor die Container-Erzeugung; DEBUG-Seed `-seedCloudMirrorSetupFailureForUITests`; DEBUG-Auslassen von `start()` bei Seed-Argumenten; Aufräumen über das bestehende `-clearCloudMirrorStatusForUITests` |
| `RestockTests/CloudMirrorMonitorTests.swift` | MODIFY | neue Unit-Tests (siehe Test Plan) |
| `RestockUITests/ICloudDiagnosticsUITests.swift` | MODIFY | neuer UI-Test mit Setup-Seed |
| `docs/specs/services/icloud-abgleich-sichtbar.md` | MODIFY | „Einrichtungsläufe werden ignoriert“ ersetzen, Verweis auf diese Spec |
| `CLAUDE.md` | MODIFY | Absatz #156: offene Grenze „Einrichtungsfehler unsichtbar“ streichen, neues Seed-Argument eintragen |

Nicht angefasst: `OnboardingView.swift` (eigene Kontoabfrage bleibt), `SharedModelContainer.swift`,
`RestockShareExtension/`, `SmartCartWidgets/`, die Modelle, das CloudKit-Schema, `project.pbxproj` (keine neue Swift-Datei).

### Estimated Changes

- Dateien: 6 Code-/Testdateien (davon 2 Tests) plus 2 Doku
- LoC: ca. +170/−15 (Produkt ca. +70, Tests ca. +100); vom PO am 2026-10-19 in einem Durchgang akzeptiert

## Implementation Details

**`handle`.** Der Guard wird zu `type == .export || type == .import || type == .setup`. Der Aufruf
`statusStore.record(_:for:)` nutzt für `.setup` den Schlüssel `lastSetup`; der Zähler-Zweig (`guard type == .export`)
bleibt, sodass Setup weder Zähler noch `lastExport`/`lastImport` berührt. Das Protokoll (`os.Logger`, Kategorie
`sync`, Domain und Code `.public`, Text `.private`) benennt den Typ „setup“.

**Untertitel.** `devRowSubtitle(lastSetup:lastExport:)`: ist `lastSetup` vorhanden und nicht erfolgreich, ist das
Ergebnis „Einrichtung fehlgeschlagen · HH:mm“ mit `isFailure == true`; in allen anderen Fällen gilt die bisherige
Export-Logik. Der Aufruf in `SettingsView` (Zeilen um 287–290) ergänzt `lastSetup: CloudMirrorStatusStore().lastRun(.setup)`.

**Klartext.** Reine statische Funktion, z. B. `setupCauseText(for: CloudMirrorSummary) -> String?`:
`domain == NSCocoaErrorDomain` und `code == 134400` ergibt „kein iCloud-Konto“, alles andere `nil`. Die
Überschrift der Ursache-Sektion lautet damit „Ursache: kein iCloud-Konto“ oder bei `nil` „Ursache“.

**Seed.** `-seedCloudMirrorSetupFailureForUITests` ruft in `SmartCartApp.init()` (DEBUG) über
`CloudMirrorMonitor.handle(type: .setup, succeeded: false, error: NSError(domain: NSCocoaErrorDomain, code: 134400, userInfo: [NSLocalizedDescriptionKey: "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."]), endDate: Date())`
den echten Datenweg. Aufräumen erledigt das bestehende `-clearCloudMirrorStatusForUITests` (Präfixlöschung erfasst
`lastSetup`), im `tearDown()` des neuen Tests (CLAUDE.md-Regel: Seed braucht Aufräumer).
Argument-Domain-Falle: Der neue Test benutzt `-developerMode YES` nur als Startargument, liest es nur und schreibt
den Schlüssel nie.

**Startreihenfolge.** `CloudMirrorMonitor.shared.start()` wandert an den Anfang von `init()` vor
`migrateStoreToAppGroupIfNeeded()` und vor jede Container-Erzeugung. Der `defer`-Block behält die DEBUG-Seed- und
Aufräumaufrufe, denn die hängen am fertigen Container oder an `handle`. In DEBUG wird `start()` bei den beiden
Seed-Argumenten für die Diagnose ausgelassen.

**Konventionen.** Sichtbare Texte über `String(localized:)`; die Diagnosetexte der #156-Ansicht stehen bewusst
nicht in `Localizable.strings` (Dev-only), die neuen folgen dem. Farben über Tokens (`Color.destructive`,
`Color.textSecondary`, `Color.ink`). `.devFeedback(context: "iCloud-Abgleich")` bleibt.

## Expected Behavior

- **Input:** Einrichtungsereignis der Spiegelung (`type == .setup`) beim App-Start, mit oder ohne Fehler.
- **Output:** Dev-Zeile „iCloud-Abgleich“ zeigt bei gescheiterter Einrichtung „Einrichtung fehlgeschlagen · HH:mm“
  (rot); Detailansicht zeigt Abschnitt „Einrichtung (beim App-Start)“ und bei 134400 „Ursache: kein iCloud-Konto“.
  Nach erfolgreicher Einrichtung beim nächsten Start zeigt die Zeile wieder den Export.
- **Side effects:** Beobachter startet früher (liest nur); ein neuer `UserDefaults`-Schlüssel
  `smartcart.cloudMirror.lastSetup` in `UserDefaults.standard`; keine neuen Permissions; keine Änderung an
  `Localizable.strings`, AppStorage-Schlüsseln, Läden, Artikeln, Audio-Dateien oder am CloudKit-Schema. Nutzer ohne
  Entwicklermodus sehen nichts davon.

## Nicht im Umfang

- Kein Eingriff in die Spiegelung selbst, kein Wiederholen der Einrichtung, keine Reparatur.
- Keine Kontostatus-Abfrage in der Diagnose (`CKContainer.accountStatus()`, siehe Alternative B).
- Kein Klartext für andere Einrichtungsfehler als 134400.
- Keine Anzeige für Nutzer außerhalb des Entwicklermodus; keine Änderung am Onboarding-Warten.
- Keine Änderung am Schema oder an `OnboardingView`.

## Alternativen

- **B, Kontostatus abfragen (verworfen):** `CKContainer.accountStatus()` beim Öffnen der Ansicht, wie das
  Onboarding. Einfacher, sagt aber nur „Konto ja oder nein“ und behauptet nichts über die Spiegelung selbst;
  scheitert die Einrichtung aus anderem Grund (Schema, Rechte), bliebe die Ansicht leer wie heute. Kippt keine ADR.
- **C, nur Text ändern (verworfen):** „noch kein Lauf — Einrichtung prüfen“. Kein Beleg, nur Vermutung; löst die
  Diagnoselücke nicht.
- **Gekippt wird mit A:** die Festlegung der #156-Spec „Einrichtungsläufe werden ignoriert“. Ein ADR ist nicht nötig.
- **Ohne Vorziehen des Beobachters (verworfen):** Würde den Wettlauf offen lassen; das Vorziehen kostet eine
  Zeile und ändert nur den Zeitpunkt einer rein lesenden Registrierung.

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests in `RestockTests/CloudMirrorMonitorTests.swift` (eigene `UserDefaults`-Suite je Test, wie bestehend):

- [ ] T1: GIVEN ein beendetes `.setup`-Ereignis mit Fehler 134400 WHEN `handle` THEN speichert die Statusablage `lastSetup` (nicht erfolgreich, Domain `NSCocoaErrorDomain`, Code 134400); ein laufendes Ereignis (`endDate == nil`) ändert nichts.
- [ ] T2: GIVEN vorhandene Export-/Import-Läufe und Zähler WHEN ein `.setup`-Ereignis behandelt wird THEN bleiben Export-Zähler, `lastExport` und `lastImport` unverändert und `firstImportFinished` wird nicht wahr.
- [ ] T3: GIVEN eine gescheiterte Einrichtung WHEN danach eine erfolgreiche `.setup`-Meldung eintrifft THEN ist `lastSetup` erfolgreich und ohne Zusammenfassung.
- [ ] T4: GIVEN die Untertitelfunktion WHEN Einrichtung fehlgeschlagen und Export erfolgreich THEN „Einrichtung fehlgeschlagen · HH:mm“ mit Fehlerkennzeichen; bei erfolgreicher oder fehlender Einrichtung gilt die bisherige Export-Logik (Bestandstest `testDevRowSubtitleForFailedSucceededAndNoRun` bleibt grün, mit angepasster Signatur).
- [ ] T5: GIVEN Zusammenfassungen WHEN Klartext-Zuordnung THEN `NSCocoaErrorDomain` 134400 ergibt „kein iCloud-Konto“; ein unbekannter Code und eine andere Domain mit Code 134400 ergeben keinen Klartext.
- [ ] T6: GIVEN `SmartCartApp.swift` (Quelltext über `#filePath` gelesen) WHEN die Reihenfolge in `init()` geprüft wird THEN steht `CloudMirrorMonitor.shared.start()` vor dem ersten `SharedModelContainer.make()`.

UI-Test in `RestockUITests/ICloudDiagnosticsUITests.swift`:

- [ ] T7: GIVEN Start mit `-developerMode YES -seedCloudMirrorSetupFailureForUITests -hasCompletedOnboarding YES` WHEN Einstellungen geöffnet THEN zeigt die Zeile „iCloud-Abgleich“ „Einrichtung fehlgeschlagen“; WHEN Tipp auf die Zeile THEN zeigt die Ansicht „Einrichtung (beim App-Start)“, „kein iCloud-Konto“ und „134400“. `tearDown()` räumt mit `-clearCloudMirrorStatusForUITests`.
- [ ] T8: Regression: `testFailedExportIsShownWithCause`, `testDuplicatesShownAndNothingChanged`, `testRowsHiddenOutsideDeveloperMode` bleiben unverändert grün (auch mit dem DEBUG-Auslassen von `start()` bei Seed-Argumenten).

Echter Durchlauf (kein Test, sondern Beleg, siehe AC-9): App auf `Restock-Validate` ohne iCloud-Konto starten,
Entwicklermodus aktiv, Einstellungen → „iCloud-Abgleich“ öffnen, Bildschirmfoto und Protokollauszug ablegen unter
`docs/artifacts/fix-166-icloud-einrichtung-sichtbar/`.

RED-Phase: Alle Unit- und UI-Tests werden vor der Implementierung geschrieben und müssen mit Compilerfehlern
(neue Signatur, neues Argument) oder Assertions fehlschlagen.

## Acceptance Criteria

Belegart: **[Unit]**, **[UI]**, **[Beleg]** (Werkzeug-Artefakt aus echtem Lauf), **[Gerät]** (offene Grenze, kein Gate).

- **AC-1:** [Unit] GIVEN ein beendetes `.setup`-Ereignis mit Fehler 134400 WHEN `handle` THEN steht es als `lastSetup` (nicht erfolgreich, Code 134400) in der Statusablage, ein laufendes Ereignis ändert nichts. Test: `CloudMirrorMonitorTests::testSetupFailureIsStored`
- **AC-2:** [Unit] GIVEN vorhandene Export-/Import-Läufe WHEN ein `.setup`-Ereignis behandelt wird THEN bleiben Export-Zähler, `lastExport`, `lastImport` und `firstImportFinished` unverändert. Test: `CloudMirrorMonitorTests::testSetupLeavesCountersAndImportUntouched`
- **AC-3:** [Unit] GIVEN eine gescheiterte Einrichtung WHEN danach eine erfolgreiche Einrichtung gemeldet wird THEN ist `lastSetup` erfolgreich und ohne Zusammenfassung. Test: `CloudMirrorMonitorTests::testSetupSuccessReplacesFailure`
- **AC-4:** [Unit] GIVEN die Untertitelfunktion WHEN die Einrichtung fehlgeschlagen ist THEN lautet der Untertitel „Einrichtung fehlgeschlagen · HH:mm“ mit Fehlerkennzeichen, auch bei vorhandenem Export; bei erfolgreicher oder fehlender Einrichtung gilt die bisherige Export-Logik. Test: `CloudMirrorMonitorTests::testSubtitlePrefersFailedSetupOverExport`
- **AC-5:** [Unit] GIVEN Zusammenfassungen WHEN der Klartext bestimmt wird THEN ergibt `NSCocoaErrorDomain` 134400 „kein iCloud-Konto“ und jeder andere Code oder eine andere Domain keinen Klartext. Test: `CloudMirrorMonitorTests::testPlainTextOnlyForKnownSetupCode`
- **AC-6:** [UI] GIVEN gesäte gescheiterte Einrichtung und Entwicklermodus WHEN Einstellungen geöffnet THEN zeigt „iCloud-Abgleich“ „Einrichtung fehlgeschlagen“, und die Detailansicht nennt „Einrichtung (beim App-Start)“, „kein iCloud-Konto“ und „134400“. Test: `ICloudDiagnosticsUITests::testFailedSetupIsShownWithCause`
- **AC-7:** [Unit] GIVEN der Quelltext von `SmartCartApp.init()` WHEN die Reihenfolge geprüft wird THEN steht `CloudMirrorMonitor.shared.start()` vor der ersten Container-Erzeugung (`SharedModelContainer.make()`); Prüfweg: Test liest die Quelldatei über `#filePath` und vergleicht die Positionen (Wettlauf geschlossen, Quelle Apple Forum 701564). Test: `CloudMirrorMonitorTests::testObserverStartsBeforeContainerCreation`
- **AC-8:** [UI] GIVEN das DEBUG-Auslassen von `start()` bei Seed-Argumenten WHEN die bestehenden Diagnose-UI-Tests laufen THEN bleiben `testFailedExportIsShownWithCause`, `testDuplicatesShownAndNothingChanged` und `testRowsHiddenOutsideDeveloperMode` grün (kein Einrichtungsereignis des Simulators überschreibt den Seed). Test: Klasse `ICloudDiagnosticsUITests` im gemeinsamen Lauf
- **AC-9:** [Beleg] GIVEN die App läuft auf dem Simulator `Restock-Validate` ohne iCloud-Konto, im Entwicklermodus und ohne Seed-Argumente WHEN Einstellungen → „iCloud-Abgleich“ geöffnet wird THEN zeigt die Diagnose die gescheiterte Einrichtung mit „NSCocoaErrorDomain 134400“ und „kein iCloud-Konto“ statt „noch kein Lauf“. Beleg: Bildschirmfoto und Protokollauszug aus dem echten Lauf unter `docs/artifacts/fix-166-icloud-einrichtung-sichtbar/`, als Durchlauf-Artefakt registriert (Commit-Kennung und Zeitstempel passend zum Stand).
- **AC-10:** [Unit] GIVEN der Bestand WHEN die Regression läuft THEN bleiben die gesamte Unit-Suite (insbesondere `CloudMirrorMonitorTests` und die Onboarding-Warte-Tests) und die UI-Klassen `ICloudDiagnosticsUITests` und `OnboardingUITests` grün; `RestockShareExtension/` und `SmartCartWidgets/` bleiben unverändert. Test: Unit-Suite und genannte UI-Klassen
- **AC-11:** [Gerät, offene Grenze, kein Gate] Auf Hennings Gerät mit TestFlight-Build erscheint ein echter Einrichtungsfehler oder -erfolg in der Diagnose. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.

## Known Limitations (offene Grenzen)

- Nur 134400 bekommt einen deutschen Klartext; andere Einrichtungsfehler (Schema, Rechte, eingeschränktes Konto)
  erscheinen mit Domain, Code und Systemtext unter der Überschrift „Ursache“.
- Gerät und TestFlight sind nicht belegt (AC-11); der Simulatorlauf zeigt nur den Fall „kein Konto“.
- Der Simulatorlauf prüft den Live-Weg des Ereignisses nur für 134400; ein erfolgreiches Einrichtungsereignis ist
  nur über den Unit-Test belegt, nicht über echtes CloudKit.
- Die Reihenfolge „Beobachter vor Container“ ist per Quelltextvergleich belegt, nicht durch einen nachgestellten
  Wettlauf (der lässt sich nicht erzeugen).
- Die Anzeige sagt „Einrichtung beim App-Start gescheitert“, nicht, dass der Abgleich später nicht doch läuft;
  sie behauptet auch nach erfolgreicher Einrichtung nicht „alles in Ordnung“ (FB13773922, wie in #156).
- Die Diagnosetexte stehen nicht in `Localizable.strings` (Dev-only, wie in #156).

## Definition of Done

- [ ] Jede Acceptance Criterion ist durch Test oder Werkzeug-Artefakt belegt; AC-11 (Gerät) ist als offene Grenze genannt
- [ ] Die App ist im Simulator gestartet und der geänderte Ablauf durchgespielt (registrierter Durchlauf, AC-9)
- [ ] Regressionslauf grün (AC-8, AC-10)
- [ ] Alte Spec und `CLAUDE.md` sind aktualisiert (Doku-Änderungen unten)

## Doku-Änderungen

- `docs/specs/services/icloud-abgleich-sichtbar.md`: die Festlegung „Einrichtungsläufe werden ignoriert“ ersetzen
  durch „Einrichtungsläufe werden als `lastSetup` gespeichert, siehe `icloud-einrichtung-sichtbar.md`“; Changelog-Zeile.
- `CLAUDE.md`, Absatz „iCloud-Abgleich sichtbar (Issue #156)“: offene Grenze „Einrichtungsläufe (`.setup`) werden
  ignoriert, Einrichtungsfehler bleiben unsichtbar, ohne iCloud-Konto zeigt die Diagnose ‚noch kein Lauf‘“ streichen;
  Absatz zu #166 mit `lastSetup`, Vorrang im Untertitel, Klartext 134400 und dem DEBUG-Argument
  `-seedCloudMirrorSetupFailureForUITests` (Aufräumer `-clearCloudMirrorStatusForUITests`) ergänzen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der Beobachter bleibt rein lesend, es ändern sich weder Store-Adressierung noch Schema oder das
  Prinzip „ein Schema, ein Store für alle Prozesse“; es wird nur eine Festlegung der #156-Spec (`.setup` ignorieren)
  zurückgenommen und der Registrierungszeitpunkt des Beobachters vorverlegt.

## Changelog

- 2026-10-19: Initial spec created
