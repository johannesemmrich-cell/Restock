# Context: test-98-durchgang-8-siri-widget

## Request Summary
Punkt 6 aus Issue #98: Siri-Kurzbefehl „Artikel hinzufügen“, Widget-/Dynamic-Island-Abhaken und Schnell-hinzufügen-Knopf laufen in keinem Test. PO-Entscheidung (2026-10-14): alle drei Abläufe in einem Durchgang.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Intents/AddItemIntent.swift` | `AddShoppingItemIntent.perform()`: eigener `ModelContext` über `SharedModelContainer.make()`, Zuordnung per `AssignmentService.assign`, legt `ShoppingItem` an. Dazu `SmartCartShortcuts` (Phrasen). Ziele: App. |
| `SmartCart/Intents/CheckOffItemIntent.swift` | `CheckOffItemIntent: LiveActivityIntent`. Legt UUID des ersten offenen Artikels in `pendingCheckoffIDs_<Laden>` (App-Gruppe), Legacy-Zähler `pendingCheckoffs_<Laden>`, Darwin-Notification, aktualisiert die Activity. Ziele: App und Widget-Erweiterung. |
| `SmartCart/Intents/QuickAddControlIntent.swift` | Setzt nur `pendingQuickAdd = true` in der App-Gruppe, `openAppWhenRun = true`. Ziele: App und Widget-Erweiterung. |
| `SmartCartWidgets/ShoppingListWidget.swift` | `CheckOffWidgetItemIntent.perform()` (draint Queue, hakt Artikel ab mit `markCompleted()` + `recordCheckOff`, setzt `widgetDidCheckOffItem`), `WidgetStoreLoader` (privat, `drainPendingCheckoffs`, `effectivePending`), `ShoppingListProvider`. Nur Widget-Ziel. |
| `SmartCart/Views/Store/StoreDetailView.swift:1211` | `applyPendingCheckoffs()`: App-seitiger Drain derselben Queue (Kommentar „keep in sync“, zwei Kopien). Private. |
| `SmartCart/Views/Home/HomeView.swift:1600` | `checkPendingQuickAdd()` liest und löscht `pendingQuickAdd`, ruft `activateQuickAdd()`. |
| `SmartCart/Services/LiveActivityService.swift:142` | liest `pendingCheckoffIDs_` beim Neuaufbau. |
| `SmartCart/Models/SharedModelContainer.swift` | einziger Zugang zum Speicher; Warnkommentar zum früheren Datenverlust. |
| `RestockUITests/UITestWait.swift`, `QuickAddAssignmentUITests.swift` | Muster für Seeds (`-seedQuickAddAssignmentForUITests`), `UITestLaunch`, Warte-Helfer. |
| `RestockTests/LiveActivityServiceReattachTests.swift` | einziger bestehender Test im Umfeld; deckt Intents nicht ab. |

## Existing Patterns
- Naht plus Fake statt Systemdienst (Durchgang 7: `DigestNotificationCenter`).
- In-Memory-Container für Unit-Tests (`SharedStoreMergeTests`), eindeutige UserDefaults-Schlüssel, `setUp`/`tearDown` prüfen Aufräumen.
- DEBUG-Startargumente mit passendem Aufräum-Argument für UI-Tests; Container der App-Gruppe überlebt den Test.
- Projektdatei: Dateien müssen in vier Stellen von `project.pbxproj` eingetragen werden. `CheckOffItemIntent` und `QuickAddControlIntent` liegen in zwei Zielen (App, Widget), `AddItemIntent` nur in der App, `ShoppingListWidget` nur im Widget.

## Dependencies
- Upstream: `SharedModelContainer`, `AssignmentService`, `Store.recordCheckOff`, `ShoppingItem.markCompleted`, App-Gruppen-`UserDefaults`, ActivityKit, WidgetKit.
- Downstream: Widget-Anzeige (`effectivePending`), Live Activity, Einkaufsweg-Lernen (#79), Kaufhistorie/Nachkauf, Sync-Flagge `widgetDidCheckOffItem`.

## Recherche (Stand 2026-10-14)
- Apple hat das Framework **AppIntentsTesting** (Artikel „Testing your App Intents code“): Tests in einem UI-Test-Ziel, `IntentDefinitions(bundleIdentifier:)`, `definitions.intents["Name"].makeIntent(...).run()`, läuft im laufenden App-Prozess über den echten System-Weg. Für Aufbau-/Aufräum-Zustand empfiehlt Apple Intents nur für Tests (`#if DEBUG`, `isDiscoverable = false`).
- **Gemessen im SDK (Xcode 27.0):** `AppIntentsTesting.framework` liegt im iPhone-Simulator-SDK; die Schnittstelle trägt `@available(iOS 27.0, …)`. Unser Mindeststand ist iOS 18; Simulatoren iOS 26.5 und 27.0 vorhanden. Der Weg gilt also nur auf dem 27.0-Simulator und braucht `#available`-Schutz, sonst bricht der Lauf auf 26.5.
- Siri-Sprachweg: nur `XCUIDevice.siriService.activate(voiceRecognitionText:)`, prüft die Wirkung in der App-Oberfläche, nicht das System davor. Foren: Siri im Simulator unzuverlässig (Thread 832339, offen zu prüfen).
- Forum zu iOS 18: interaktive Live Activity ruft `perform()` teils nicht auf (Thread 760342). Das ist Systemverhalten und nicht automatisierbar.

## Vorläufige Lücken (Messung aus Code, noch nicht bewiesen)
- Zwei Kopien des Drains (App: `applyPendingCheckoffs`, Widget: `drainPendingCheckoffs`), beide privat und nicht aufrufbar aus Tests.
- `CheckOffItemIntent.perform()` hängt an `Activity<…>.activities`; ohne laufende Activity (Simulator) schreibt er nichts in die Queue. Der Schreibweg ist im Test nur mit einer Naht prüfbar.
- `AddShoppingItemIntent` legt den Artikel ohne `quantitySource`-Vorschlag und ohne Duplikatprüfung an; ob das gewollt ist, klärt die Analyse.

## Existing Specs
- `docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md` (Vorlage für Aufbau), `docs/specs/ui-tests/shopping-route-learning-uitest.md` (nennt Abhak-Kette).

## Risks & Considerations
- Mindeststand iOS 18 versus AppIntentsTesting ab iOS 27: Unit-/Direkttests als Hauptweg, Framework nur ergänzend.
- Gerät: nichts auf Hennings Geräten. Nur Simulator Restock-Validate.
- Scoping: 4–5 Dateien, ±250 Zeilen je Durchgang; Nähte im Produktcode zählen mit.
- Datenschutz des Speichers: Tests dürfen den App-Gruppen-Container nicht ohne Aufräumen verändern.
- Offene Grenzen vorab: echter Siri-Ruf, Widget-Tipp auf dem Homescreen, Live-Activity-Tipp auf der Sperre sind im Simulator nicht ausführbar.

## Analysis

### Type
Feature (Testabdeckung, #98 Punkt 6). Kein Fehler gemeldet; Produktfehler können beim Testen auftauchen (wie in Durchgang 5–7).

### Befund (aus Code gelesen, Stand 2026-10-14)
1. **Abhaken (Insel/Sperrbildschirm + Widget):** Die Drain-Logik steht zweimal, wortgleich, beide `private`: `WidgetStoreLoader.drainPendingCheckoffs` + `effectivePending` (nur Widget-Ziel) und `StoreDetailView.applyPendingCheckoffs` (Kommentar „keep in sync“). Nicht aus Tests aufrufbar. Der Schreibweg `CheckOffItemIntent.perform()` hängt an `Activity.activities`; im Simulator ohne Activity wird bewusst nichts gequeut.
2. **Siri „Artikel hinzufügen“:** `AddShoppingItemIntent.perform()` mischt Container-Beschaffung und Anlegen. Die Anlegelogik ist nicht ohne `SharedModelContainer.make()` (echter App-Gruppen-Speicher) aufrufbar. Kein `suggestQuantity`, keine Duplikatprüfung (Intent setzt Menge immer, Default 1) → Produktfrage, nicht Teil dieses Durchgangs.
3. **Schnell-hinzufügen-Knopf:** `QuickAddControlIntent` (Control im Widget-Ziel) setzt nur `pendingQuickAdd`; `HomeView.checkPendingQuickAdd()` liest/löscht und fokussiert das Eingabefeld (`activateQuickAdd`, 0,45 s). Beide Hälften einzeln einfach; die Kette ist ungeprüft.

### Regeln statt Framework (Nulllinie)
Ohne Systemweg geht es nicht, weil … : doch, es geht. Die Logik hinter allen drei Wegen ist deterministisch (Warteschlange, Zuordnung, Merker). Der Systemaufruf (Siri-Stimme, Widget-Tipp, Live-Activity-Tipp) ist im Simulator nicht ausführbar; AppIntentsTesting existiert nur ab iOS 27 (Mindeststand 18) und ruft nur `perform()` auf, nicht den Systemweg davor. **Empfehlung: Logik aus den Intents in testbare Funktionen ziehen und direkt testen; AppIntentsTesting nur als Alternative.**

### Empfohlener Ansatz
- **A. `CheckoffQueue`** (neue Datei `SmartCart/Models/CheckoffQueue.swift`, in App- und Widget-Ziel): `enqueue(itemID:storeName:defaults:)`, `pendingIDs`, `effectivePending(for:defaults:)`, `drain(for:defaults:)`. `StoreDetailView`, `ShoppingListWidget` und `CheckOffItemIntent` rufen sie auf → Duplikat weg. Unit-Tests: Reihenfolge, No-op bei erledigtem, Legacy-Zähler, Einkaufsweg (`batched`), PurchaseRecord entsteht, Doppel-Drain.
- **B. `AddShoppingItemIntent.add(name:quantity:unit:in:)`** statisch mit `ModelContext`; `perform()` ruft sie. Unit-Tests: Zuordnung nach Kaufhistorie/Drogerie, Menge/Einheit, kein Laden.
- **C. Schnell-hinzufügen:** Unit-Test, dass `QuickAddControlIntent.perform()` den Merker setzt; UI-Test (DEBUG-Startargument `-pendingQuickAddForUITests` setzt den Merker vor dem Start) prüft: Tastatur/Eingabefeld ist fokussiert und der Merker verbraucht.

### Alternativen
1. AppIntentsTesting (iOS 27) ruft die Intents als UI-Test im echten Prozess → kippt den Mindeststand-18-Gedanken nicht, läuft aber nur auf dem 27.0-Simulator; als Ergänzung später.
2. Nur Widget-Duplikat nicht anfassen, Kopie in Test nachbauen → prüft die Kopie, nicht den Produktcode (abgelehnt).
3. `XCUIDevice.siriService` → Simulator unzuverlässig (Forum), prüft nur UI-Wirkung.
Gekippte Entscheidung: die „keep in sync“-Doppelung (kein ADR) wird aufgegeben.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/Models/CheckoffQueue.swift | CREATE | gemeinsame Queue/Drain |
| SmartCart/Views/Store/StoreDetailView.swift | MODIFY | `applyPendingCheckoffs` ruft `CheckoffQueue.drain` |
| SmartCartWidgets/ShoppingListWidget.swift | MODIFY | Loader ruft `CheckoffQueue` |
| SmartCart/Intents/CheckOffItemIntent.swift | MODIFY | Queue-Schreiben über `enqueue` |
| SmartCart/Intents/AddItemIntent.swift | MODIFY | `add(...)` herausgelöst |
| SmartCart/SmartCartApp.swift | MODIFY | DEBUG-Argument Merker |
| Restock.xcodeproj/project.pbxproj | MODIFY | Datei in 2 Ziele |
| RestockTests/CheckoffQueueTests.swift, AddItemIntentTests.swift | CREATE | Unit |
| RestockUITests/QuickAddControlUITests.swift | CREATE | UI |

### Scope Assessment
- Files: 9 (Limit 4–5) · Estimated LoC: ca. +420/-70 · Risk: MITTEL (Umbau des Drains berührt Abhak-Kette, Einkaufsweg-Lernen, Widget; Widget-Ziel nur durch Bauen prüfbar).
- Überschreitet die Scoping-Limits → Entscheidung des PO nötig (Ausnahme wie bei #98 Durchgang 3/4 oder Reduktion).

### Offene Grenzen (vorab)
Echter Siri-Ruf, Widget-Tipp auf Homescreen, Live-Activity-Tipp, Control-Center-Tipp, Zustellung `perform()` durch das System; nichts auf Hennings Geräten.

### Open Questions
- [x] Umfang: PO 2026-10-14 — alles in einem Durchgang, Ausnahme (~9 Dateien/~490 Zeilen) freigegeben.
- [ ] Siri-Intent legt ohne Duplikatprüfung/Mengenvorschlag an: Ist-Verhalten festhalten oder Produktänderung? (Empfehlung: festhalten, keine Änderung)

## Umfang-Ausnahme 2 (PO 2026-10-14, während Phase 6)
Stand: 11 Dateien, ca. 620 Zeilen (Tests über die Hälfte). PO hat erweiterte Ausnahme freigegeben: bis 11 Dateien / ca. 700 Zeilen. Spec-Text (AC-14: 10 Dateien/±500) bleibt unverändert, damit das PO-Briefing gültig bleibt; diese Freigabe gilt darüber hinaus.
