# Context: fix-166-icloud-einrichtung-sichtbar

## Request Summary
Die Entwickler-Diagnose „iCloud-Abgleich“ (aus #156) soll auch eine gescheiterte **Einrichtung** der
privaten iCloud-Spiegelung samt Ursache zeigen (z. B. kein iCloud-Konto), statt „noch kein Lauf“.
Nur Entwicklermodus, reine Anzeige.

## Befund (belegt)
- Durchlauf 2026-10-18 auf `Restock-Validate` ohne iCloud-Konto
  (`docs/artifacts/fix-156-icloud-abgleich-sichtbar/durchlauf-echte-app.txt`):
  `NSCloudKitMirroringDelegate _performSetupRequest: Failed to set up CloudKit integration …`
  `NSCocoaErrorDomain 134400 "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."`
  Danach keine Export-/Import-Ereignisse; `smartcart.cloudMirror.*` blieb leer → Anzeige „noch kein Lauf“.
- Ursache im Code: `CloudMirrorMonitor.handle` (`SmartCart/Services/CloudMirrorMonitor.swift:54-61`)
  verwirft `type == .setup` (Guard Zeile 55); so in der Spec von #156 festgelegt.
- Recherche: 134400 entsteht im Setup-Schritt von `NSPersistentCloudKitContainer`; das Ereignis kommt
  über `eventChangedNotification` mit `type == .setup`, `succeeded == false`, `error` gesetzt
  (Apple Forums 119457, 771870; TN3164).

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/CloudMirrorMonitor.swift` | `handle` (Guard verwirft `.setup`), `CloudMirrorStatusStore.runKey` kennt nur export/import, `devRowSubtitle(lastExport:)` |
| `SmartCart/Views/Settings/CloudMirrorStatusView.swift` | Detailansicht: Abschnitte Export/Import/Zähler; Ursache nur für Export |
| `SmartCart/Views/Settings/SettingsView.swift:284-291` | Dev-Zeile „iCloud-Abgleich“, Untertitel aus `devRowSubtitle` |
| `SmartCart/SmartCartApp.swift:23-31, 528-548` | `CloudMirrorMonitor.shared.start()` im `defer` von `init()` (nach Container-Erzeugung); Seed/Clear-Argumente `-seed/-clearCloudMirrorStatusForUITests` |
| `SmartCart/Views/Settings/OnboardingView.swift:147-170` | Eigene Kontoabfrage `CKContainer.accountStatus()` für das Warte-Gate (unabhängig vom Monitor) |
| `RestockTests/CloudMirrorMonitorTests.swift` | T5 `testHandlePersistsOnlyFinishedEvents`, T8 `testDevRowSubtitleForFailedSucceededAndNoRun` — Ausgangspunkt neuer Tests |
| `RestockUITests/ICloudDiagnosticsUITests.swift` | UI-Test mit Seed-Argument; Muster für neuen Einrichtungsfehler-Test |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | neue sichtbare Texte |

## Existing Patterns
- Ereignis → `CloudMirrorRun(date:succeeded:summary:)` → `CloudMirrorStatusStore.record(_:for:)` (PropertyList in `UserDefaults.standard`, Präfix `smartcart.cloudMirror.`).
- Fehler → `CloudMirrorMonitor.summarize(error:)` → `CloudMirrorSummary` (Domain, Code, Text, Art).
- Dev-Zeile mit Untertitel + `isFailure` (rot) über reine statische Funktion, unit-testbar.
- UI-Test seedet über `CloudMirrorMonitor.handle` im DEBUG-Zweig von `SmartCartApp.init()`, räumt mit `-clearCloudMirrorStatusForUITests` (Präfix-Löschung erfasst neue Schlüssel automatisch).

## Dependencies
- Upstream: `NSPersistentCloudKitContainer.eventChangedNotification` (SwiftData-Spiegelung), `UserDefaults`.
- Downstream: `SettingsView` (Untertitel), `CloudMirrorStatusView`, `OnboardingView.firstImportFinished` (liest `lastRun(.import)` — darf durch Setup-Einträge nicht beeinflusst werden).

## Existing Specs
- `docs/specs/services/icloud-abgleich-sichtbar.md` (#156) — legt „Einrichtungsläufe werden ignoriert“ fest; wird durch #166 für `.setup` geändert.
- `docs/specs/models/private-cloudkit-schema.md` (#155).

## Risks & Considerations
- **Startreihenfolge (Wettlauf):** Der Beobachter wird erst im `defer` nach Container-Erzeugung registriert; die Einrichtung läuft asynchron. Im Durchlauf lag 1 s dazwischen, aber garantiert ist das nicht. Ein Einrichtungsereignis, das vor `start()` endet, ginge verloren. In der Analyse klären (z. B. `start()` vor Container-Erzeugung).
- **Alternative ohne Ereignis:** Kontostatus direkt abfragen (`CKContainer.accountStatus()`, wie im Onboarding). Einfacher, deckt aber nur „kein Konto“ ab, nicht andere Einrichtungsfehler (Schema, Rechte); und behauptet nichts über die Spiegelung selbst.
- **Untertitel-Priorität:** Wenn Einrichtung gescheitert ist, gibt es keinen Export — Untertitel muss den Einrichtungsfehler zeigen; nach späterer erfolgreicher Einrichtung (z. B. Konto angemeldet) darf der alte Fehler nicht stehen bleiben.
- **Zähler:** Setup-Läufe dürfen die Export-Zähler nicht verändern; `firstImportFinished` darf nicht reagieren.
- **Bestehender Test T5** prüft indirekt nur Export/Import; ein neuer Test muss das geänderte Verhalten für `.setup` belegen (RED vorher).
- Kein Gerätezugriff nötig: Simulator ohne Konto erzeugt den Fall echt (Durchlauf als Nachweis).

## Analysis

### Type
Bug (Diagnoselücke aus #156; die Anzeige behauptet „noch kein Lauf“, obwohl die Einrichtung scheiterte)

### Zusätzlicher Befund (2026-10-19)
- Protokoll `durchlauf-echte-app.txt`: Die Einrichtung läuft **bei jedem App-Start** erneut (22:54:10 und
  22:55:32, zwei Prozesse, je `_performSetupRequest` → 134400). Damit löst eine spätere erfolgreiche
  Einrichtung den Fehler zuverlässig ab (DoD 3) — kein eigener Rücksetzweg nötig.
- Zwischen Kontoabfrage und Fehler liegen ~10 ms nach `scheduler-register`; der Beobachter wird erst im
  `defer` von `SmartCartApp.init()` registriert. Apple-Forum/Doku: Beobachter **vor** dem Laden des Stores
  registrieren, sonst können Einrichtungsereignisse verloren gehen
  (https://developer.apple.com/forums/thread/701564, https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer).
- Die Diagnose-Texte stehen nicht in `Localizable.strings` (Dev-only, nur `String(localized:)` ohne Eintrag) → keine Übersetzungsdateien betroffen.
- `CloudMirrorSummary.kind` wird in keiner Ansicht angezeigt; Klartext „kein iCloud-Konto“ braucht eine
  eigene, reine Zuordnung (NSCocoaErrorDomain 134400 → Klartext), sonst nur „Ursache“ + Systemtext.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/CloudMirrorMonitor.swift` | MODIFY | `handle` nimmt `.setup` an (Zähler nur Export, `firstImportFinished` unberührt); `runKey` um `lastSetup`; `devRowSubtitle(lastSetup:lastExport:)` mit Vorrang der gescheiterten Einrichtung; reine Klartext-Zuordnung bekannter Einrichtungscodes (134400 → „kein iCloud-Konto“) |
| `SmartCart/Views/Settings/CloudMirrorStatusView.swift` | MODIFY | Abschnitt „Einrichtung (beim App-Start)“ oben, bei Fehler Ursache-Abschnitt (Überschrift mit Klartext) |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | Untertitel-Aufruf übergibt zusätzlich `lastRun(.setup)` (1–2 Zeilen) |
| `SmartCart/SmartCartApp.swift` | MODIFY | `CloudMirrorMonitor.shared.start()` vor die Container-Erzeugung; DEBUG-Seed `-seedCloudMirrorSetupFailureForUITests` (gescheiterte Einrichtung 134400 über `handle`); Aufräumen über bestehendes `-clearCloudMirrorStatusForUITests` (Präfix) |
| `RestockTests/CloudMirrorMonitorTests.swift` | MODIFY | neue Tests: `.setup` wird gespeichert, ändert Zähler/Import nicht, Erfolg überschreibt Fehler; Untertitel-Vorrang; Klartext 134400 |
| `RestockUITests/ICloudDiagnosticsUITests.swift` | MODIFY | neuer Test mit Setup-Seed: Zeile „Einrichtung fehlgeschlagen“, Ansicht zeigt „kein iCloud-Konto“ und 134400 |
| `docs/specs/services/icloud-abgleich-sichtbar.md` | MODIFY | „Einrichtungsläufe werden ignoriert“ ersetzen |
| `CLAUDE.md` | MODIFY | Absatz #156: offene Grenze „Einrichtungsfehler unsichtbar“ streichen, neues Seed-Argument |

### Scope Assessment
- Files: 6 Code-/Testdateien (+2 Doku) — **über dem Limit von 4–5 Dateien**, davon 2 Testdateien und 1 Mini-Änderung (`SettingsView`, 1–2 Zeilen)
- Estimated LoC: ca. +170 / −15 (Produkt ~+70, Tests ~+100)
- Risk Level: LOW — nur Dev-Anzeige; einzige Verhaltensänderung für alle Nutzer ist der frühere Start des Beobachters (liest nur, schreibt nur `smartcart.cloudMirror.*`)

### Technical Approach (Empfehlung: Entwurf A)
1. `handle` akzeptiert `.setup` neben `.export`/`.import`; beendete Einrichtung → `lastSetup` (Erfolg überschreibt Fehler, weil jeder Start eine Einrichtung meldet).
2. Untertitel: gescheiterte letzte Einrichtung hat Vorrang („Einrichtung fehlgeschlagen · HH:mm“, rot), sonst Export-Logik wie bisher.
3. Detailansicht: Abschnitt „Einrichtung“ oben (Zustand/Zeit/Fehler), bei Fehler Ursache mit Klartext für bekannte Codes.
4. Beobachter vor dem Öffnen des Containers registrieren (Wettlauf schließen); `startedAt` wird dadurch früher — `firstImportFinished` vergleicht `run.date >= startedAt`, bleibt korrekt.
5. Nachweis: Unit + UI-Test mit Seed (RED vorher), danach echter Durchlauf auf `Restock-Validate` ohne iCloud-Konto (Diagnose zeigt 134400 statt „noch kein Lauf“).

### Alternativen
- **B: Kontostatus abfragen** (`CKContainer.accountStatus()` beim Öffnen der Ansicht, wie Onboarding). Einfacher, aber nur „Konto ja/nein“; Schema-/Rechtefehler der Einrichtung blieben unsichtbar. Kippt nichts an ADRs.
- **C: Nur Text ändern** („noch kein Lauf — Einrichtung prüfen“). Kein Beleg, nur Vermutung; verworfen.
- Gekippt wird mit A die Festlegung der #156-Spec „Einrichtungsläufe werden ignoriert“.

### Entwurf (Pflicht bei sichtbarer Änderung)
`docs/artifacts/fix-166-icloud-einrichtung-sichtbar/entwurf.html`, veröffentlicht: https://claude.ai/artifact/Wjg7bytUjwsuQRLJSbH5cJ
(„Heute“ aus dem Code nachgebaut, kein Screenshot — offengelegt.)

### Open Questions
- [x] PO: Entwurf A freigegeben (2026-10-19)
- [x] PO: 6 Dateien / ca. 170 Zeilen in einem Durchgang akzeptiert (2026-10-19)
