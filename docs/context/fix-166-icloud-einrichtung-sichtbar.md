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
