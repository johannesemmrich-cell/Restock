# Context: fix-150-checkoff-intent-verbergen

## Request Summary
`CheckOffItemIntent` (Knopf „Nächsten Artikel abhaken“ der Live Activity) meldet Erfolg ohne Wirkung, wenn für den Laden keine Live Activity läuft. Erreichbar ist das für Nutzer nur, weil der Intent in der Kurzbefehle-App (und damit für Siri/Spotlight) auffindbar ist. PO-Entscheidung (2026-10-17, Issue #150): Intent verbergen (`isDiscoverable = false`) wie `CheckOffWidgetItemIntent`; der Knopf der Live Activity muss weiter funktionieren.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Intents/CheckOffItemIntent.swift` | Der Intent; hier kommt `static var isDiscoverable = false` hinzu. Kompiliert in App- **und** Widget-Ziel (`project.pbxproj` zwei Build-Files, `project.yml:59`). Nichtstun ohne Activity ist gewollt (Zeilen 43–45: Schutz vor liegengebliebenem Knopf). |
| `SmartCartWidgets/ShoppingLiveActivity.swift:55`, `:133` | Einzige Produkt-Aufrufer: `Button(intent: CheckOffItemIntent(storeName:))` in Dynamic Island und Sperrbildschirm. |
| `SmartCartWidgets/ShoppingListWidget.swift:85–89` | Vorbild: `CheckOffWidgetItemIntent` mit `isDiscoverable = false`. |
| `SmartCart/Intents/AddItemIntent.swift:73` | `SmartCartShortcuts` (AppShortcutsProvider) enthält nur `AddShoppingItemIntent`; kein Siri-Satz zum Abhaken. App Shortcuts verlangen `isDiscoverable = true` — betrifft `CheckOffItemIntent` nicht. |
| `RestockUITests/AppIntentsUITests.swift:70–71` | T2/T3 (#145 D3) rufen `intents["CheckOffItemIntent"].makeIntent(storeName:).run()` über `AppIntentsTesting`. Müssen nach der Änderung weiter laufen (nur über `scripts/run-appintents-uitest.sh`, iOS 27). Kopfkommentar Zeile 14 nennt den „stillen Erfolg“. |
| `RestockTests/CheckoffQueueTests.swift` | Warteschlange, `perform()` selbst nicht geprüft; unberührt. |
| `CLAUDE.md` (Absatz AppIntentsUITests, Siri/Widget #98 D8) | Doku „stiller Erfolg … Beobachtung fürs Issue“ ist anzupassen. |

## Existing Patterns
- Knopf-only-Intents sind verborgen: `CheckOffWidgetItemIntent.isDiscoverable = false`.
- `LiveActivityIntent`, damit `perform()` im App-Prozess läuft (Kommentar am Kopf von `CheckOffItemIntent`).

## Dependencies
- Upstream: `CheckoffQueue`, ActivityKit, WidgetKit, Darwin-Notification `…pendingCheckoff`.
- Downstream: Live-Activity-Knöpfe, `AppIntentsUITests` T2/T3.

## Existing Specs
- `docs/specs/ui-tests/test-145-durchgang-3-app-intents.md` (T2/T3, Offene Grenze „stiller Erfolg“)
- `docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md` (Abhak-Warteschlange)

## Recherche
- Apple: `isDiscoverable = false` → Intent aus App-UI/Widget ausführbar, aber nicht für Siri, Spotlight, Kurzbefehle-App: https://developer.apple.com/documentation/appintents/appintent/isdiscoverable , https://developer.apple.com/forums/thread/761318
- AppIntentsTesting: verborgene Intents bleiben über `IntentDefinitions(...).intents["Name"]` erreichbar (laut https://www.theswift.dev/posts/test-siri-spotlight-shortcuts-appintentstesting/ und https://antongubarenko.substack.com/p/ios-27-app-intents-testing ; WWDC26 Session 295). **Unbelegt für dieses Projekt — in der Analyse nachstellen.**

## Risks & Considerations
- Knopf der Live Activity könnte bei `isDiscoverable = false` nicht mehr feuern (laut Apple nein; Widget-Knopf läuft schon so) — belegen.
- Fällt `CheckOffItemIntent` aus den App-Metadaten, scheitern T2/T3 mit Fehler 400 „is not present“ → Tests umbauen oder Grenze dokumentieren.
- Nutzer, die sich schon einen Kurzbefehl damit gebaut haben, verlieren ihn (praktisch keine; Release 1.0 noch nicht erschienen).
- Ob der Intent wirklich aus der Kurzbefehle-App verschwindet, ist im Simulator nur über die Metadaten (`Metadata.appintents/extract.actionsdata`, Feld `isDiscoverable`) prüfbar, nicht per UI-Test der Kurzbefehle-App.

## Analysis

### Type
Bug (Nutzer kann über die Kurzbefehle-App einen Befehl ausführen, der Erfolg meldet und nichts tut). Umsetzung nach PO-Entscheidung vom 2026-10-17: Befehl verbergen.

### Nachstellung und Beleg (2026-10-17)
- **Heute (Fehlerzustand):** In den vom Build erzeugten Befehls-Metadaten (`Metadata.appintents/extract.actionsdata`, Quelle für Siri, Spotlight, Kurzbefehle) steht `CheckOffItemIntent` mit `isDiscoverable = true`, in App **und** Widget-Erweiterung; `CheckOffWidgetItemIntent` steht dort mit `false`. Gelesen aus `build/dd-appintents` (Stand `c901ae5`).
- **Wegwerf-Kopie mit `static var isDiscoverable = false`:** Metadaten zeigen `CheckOffItemIntent isDiscoverable=False` in App und Widget; alle anderen Befehle unverändert (`AddShoppingItemIntent`, `QuickAddControlIntent` weiter `True`).
- **Ausführbarkeit bleibt:** `scripts/run-appintents-uitest.sh` in der Wegwerf-Kopie, iOS 27.0, Xcode 27.1: 3 von 3 grün, 0 Fehlschläge, 0 Übersprungene, 0 Wiederholungen wegen Fehler 400 (2026-10-17 07:09). T2 (Abhaken mit laufender Live Activity → „1 von 2 erledigt“) belegt, dass der verborgene Befehl über den Systemweg mit Activity weiter wirkt; T3 (Gegenprobe ohne Activity) bleibt grün. Protokoll: `docs/artifacts/fix-150-checkoff-intent-verbergen/repro-verborgen-appintents.log`.
- Damit ist das Risiko „Fehler 400 is not present nach dem Verbergen“ widerlegt: verborgene Befehle bleiben für `AppIntentsTesting` erreichbar, die Tests müssen nicht umgebaut werden.
- Nicht automatisierbar: der echte Tipp auf den Knopf der Live Activity (offene Grenze seit #145 D3). Stütze: Apple-Doku (verborgen = aus App-UI/Widget ausführbar) und das Vorbild `CheckOffWidgetItemIntent`, dessen Knopf mit `false` seit Langem funktioniert.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Intents/CheckOffItemIntent.swift` | MODIFY | `static var isDiscoverable = false` + ein Kommentarsatz (warum: nur Knopf der Live Activity, ohne Activity tut er bewusst nichts) |
| `RestockTests/CheckOffIntentVisibilityTests.swift` | CREATE | Regressionstest: liest `Metadata.appintents/extract.actionsdata` aus `Bundle.main` (Test-Host ist `Restock.app`) und aus `PlugIns/SmartCartWidgets.appex`, prüft `CheckOffItemIntent.isDiscoverable == false` in beiden und als Gegenprobe `AddShoppingItemIntent == true` (sonst würde ein kaputtes Lesen den Test grün machen) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Testdatei registrieren |
| `RestockUITests/AppIntentsUITests.swift` | MODIFY | nur Kopfkommentar: „stiller Erfolg“ ist für Nutzer nicht mehr erreichbar (#150) |
| `CLAUDE.md` | MODIFY | Absatz AppIntentsUITests: Beobachtung „stiller Erfolg“ → durch #150 verborgen |

### Scope Assessment
- Files: 5 (davon 2 nur Doku/Kommentar)
- Estimated LoC: +60/-3
- Risk Level: LOW — eine Eigenschaft, kein Ablauf geändert; Ausführbarkeit belegt

### Technical Approach
`isDiscoverable = false` an `CheckOffItemIntent` (wirkt auf App- und Widget-Ziel, da dieselbe Datei). Regressionstest auf die Build-Metadaten statt auf die Swift-Eigenschaft, weil die Metadaten das sind, was Kurzbefehle tatsächlich lesen. Nachweis in Phase 6: Unit-Test + `scripts/run-appintents-uitest.sh` (3/3) + Bestandssuite.

### Alternativen
- **Statt verbergen: Rückmeldung ohne Activity** (`perform()` liefert einen Dialog „Kein Einkauf aktiv“ oder wirft). Würde den Befehl in Kurzbefehlen ehrlich machen, aber einen Knopf-Befehl zum Nutzerbefehl aufwerten, ohne dass es einen Nutzen dafür gibt; ein Dialog beim liegengebliebenen Knopf wäre zudem störend. Vom PO verworfen (Issue #150).
- **Nichts tun:** Release 1.0 noch nicht draußen, praktisch kein Nutzer hat einen Kurzbefehl damit. Verworfen, weil der Befehl sonst mit 1.0 in die Kurzbefehle-App ginge.

### Dependencies
Upstream unverändert (`CheckoffQueue`, ActivityKit). Downstream: Live-Activity-Knöpfe (`ShoppingLiveActivity.swift:55`, `:133`), `AppIntentsUITests` T2/T3 (belegt unberührt).

### Open Questions
- keine
