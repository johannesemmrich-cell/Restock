---
entity_id: test-98-durchgang-8-siri-widget
type: test
created: 2026-10-14
updated: 2026-10-14
status: draft
workflow: test-98-durchgang-8-siri-widget
tags: [test, unit-test, ui-test, siri, widget, live-activity, app-intents, refactoring]
---

# Test-Durchlauf: Siri, Widget-Abhaken, Schnell-hinzufügen (Issue #98, Durchgang 8)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Punkt 6 aus #98. Drei Abläufe laufen in keinem Test:

1. **Siri „Artikel hinzufügen“** (`AddShoppingItemIntent`): Zuordnung zu einem Laden, Menge, Einheit.
2. **Abhaken per Dynamic Island / Sperrbildschirm / Homescreen-Widget** (`CheckOffItemIntent`,
   `CheckOffWidgetItemIntent`): Warteschlange `pendingCheckoffIDs_<Laden>` und ihr Abarbeiten.
3. **Schnell-hinzufügen-Knopf** im Control Center (`QuickAddControlIntent`): Merker `pendingQuickAdd`, den die
   Startseite beim Öffnen liest.

**Befund (Code gelesen, 2026-10-14):** Die Abarbeitung der Abhak-Warteschlange steht zweimal, wortgleich, beide
`private`: `WidgetStoreLoader.drainPendingCheckoffs`/`effectivePending` (nur Widget-Ziel) und
`StoreDetailView.applyPendingCheckoffs` (Kommentar „keep in sync“). Aus Tests nicht aufrufbar. Die Anlegelogik des
Siri-Befehls hängt an `SharedModelContainer.make()` (echter App-Gruppen-Speicher). Der Merker des
Schnell-hinzufügen-Knopfs wird von `HomeView.checkPendingQuickAdd()` gelesen; die Kette ist ungeprüft.

**Recherche (2026-10-14):** Apples `AppIntentsTesting` (Xcode 27) ruft Intents im echten Prozess auf, ist aber
`@available(iOS 27.0)`; Mindeststand der App ist iOS 18, Simulatoren 26.5 und 27.0. Es prüft `perform()`, nicht den
Systemweg davor (Siri-Stimme, Widget-Tipp). `XCUIDevice.siriService` ist im Simulator unzuverlässig (Apple-Forum).
Interaktive Live Activities rufen `perform()` unter iOS 18 teils nicht auf (Forum 760342): Systemverhalten.

**Regel vor Modell:** Kein Modell beteiligt. Ohne Systemweg geht es, weil die Logik deterministisch ist
(Warteschlange, Zuordnung, Merker). Die Logik wird aus den Intents in testbare Funktionen gezogen und direkt
geprüft; der Systemaufruf davor bleibt offene Grenze.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03). Der PO hat am
2026-10-14 entschieden: alle drei Abläufe in **einem** Durchgang, Überschreitung der Scoping-Limits freigegeben.

**Offene Grenzen (gelten für jede positive Zusage dieses Durchgangs):**

- **Echter Siri-Ruf** (Stimme, Phrasenerkennung, `AppShortcutsProvider`-Registrierung) ist nicht geprüft.
- **Widget-Tipp auf dem Homescreen**, **Tipp auf der Live Activity** (Sperrbildschirm/Dynamic Island) und
  **Tipp auf das Control** sind im Simulator nicht ausführbar; das System startet `perform()` nicht.
- **`CheckOffItemIntent.perform()` selbst** läuft nur mit laufender `Activity<ShoppingActivityAttributes>`;
  geprüft wird die ausgelagerte Warteschlangen-Logik, nicht der Activity-Teil (`update`/`end`).
- **Control-Center-Darstellung** des Controls (`QuickAddControl`) und `openAppWhenRun` durch das System.
- **Geräte:** Es läuft kein Test auf einem Gerät des Users (Regel: nur auf sein Wort).

## Source

- **Neu:** `SmartCart/Models/CheckoffQueue.swift` — gemeinsame Logik, im App- und im Widget-Ziel:
  `enqueue(itemID:storeName:defaults:)`, `effectivePending(for:defaults:)`,
  `drain(for:defaults:) -> Int` (Anzahl abgehakter Artikel). Inhalt 1:1 aus den beiden bisherigen Kopien
  (UUID-Warteschlange, Legacy-Zähler, `markCompleted()` + `store.recordCheckOff(item, batched: true)`).
- **Geändert:** `SmartCart/Views/Store/StoreDetailView.swift` — `applyPendingCheckoffs()` ruft
  `CheckoffQueue.drain`; danach wie bisher `context.save()` und `LiveActivityService.shared.update(for:)`.
- **Geändert:** `SmartCartWidgets/ShoppingListWidget.swift` — `WidgetStoreLoader.effectivePending`/
  `drainPendingCheckoffs` entfallen, Aufrufer nutzen `CheckoffQueue`. Sonst nichts.
- **Geändert:** `SmartCart/Intents/CheckOffItemIntent.swift` — Schreiben der UUID in die Warteschlange über
  `CheckoffQueue.enqueue`; Activity-, Legacy-Zähler-, Darwin- und Update-Teil unverändert.
- **Geändert:** `SmartCart/Intents/AddItemIntent.swift` — neue statische Funktion
  `AddShoppingItemIntent.add(name:quantity:unit:in:) -> ShoppingItem` (Zuordnung, Anlegen, `insert`, kein
  `save`/Dialog); `perform()` ruft sie und speichert. Verhalten gleich.
- **Geändert:** `SmartCart/SmartCartApp.swift` — DEBUG-Startargument `-pendingQuickAddForUITests` setzt vor dem
  Start `pendingQuickAdd = true` in der App-Gruppe (Merker, den sonst das Control setzt); kein eigener Zustand,
  der aufzuräumen wäre (die Startseite löscht den Merker beim Lesen). `-clearPendingQuickAddForUITests` entfernt ihn
  vorsorglich im `tearDown()`.
- **Neu:** `RestockTests/CheckoffQueueTests.swift`, `RestockTests/AddItemIntentTests.swift` (Unit).
- **Neu:** `RestockUITests/QuickAddControlUITests.swift` (UI).
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — `CheckoffQueue.swift` in App- **und** Widget-Ziel
  (Quellen-Phasen), drei Testdateien in ihre Ziele (je vier Stellen laut `CLAUDE.md`).
- **Geändert:** `CLAUDE.md` — Absatz „Durchgang 8“. **Neu:** diese Spec.
- **Nicht geändert (ausdrücklich):** `QuickAddControlIntent`, `HomeView`, `LiveActivityService`, `Store`,
  `ShoppingItem`, `AssignmentService`, `SharedModelContainer`, `SyncCoordinator`, alle Texte, `Info.plist`,
  Phrasen, Scheme, Entitlements. Kein neuer `@AppStorage`-Schlüssel.

Geschätzter Umfang: **9 Dateien** (`CheckoffQueue`, `StoreDetailView`, `ShoppingListWidget`, `CheckOffItemIntent`,
`AddItemIntent`, `SmartCartApp`, `project.pbxproj`, drei Testdateien, `CLAUDE.md`; dazu diese Spec), ca. **+420 / −70
LoC**, davon Produktcode ca. 110 (davon ca. 70 verschoben), Tests ca. 300. **Das überschreitet die Limits
(4–5 Dateien, ±250 LoC); PO-Ausnahme vom 2026-10-14.** Überschreitet die Umsetzung ±500 LoC oder 10 Dateien:
stoppen und mit Schätzung nachfragen.

## Verhalten

### Warteschlange `CheckoffQueue`

Reine Funktionen über App-Gruppen-`UserDefaults` (Parameter, Standard: die App-Gruppe) und einen `Store`:

- `enqueue`: hängt die UUID an `pendingCheckoffIDs_<Laden>` an; Duplikate sind harmlos.
- `effectivePending`: offene Artikel abzüglich gequeueter UUIDs und abzüglich des Legacy-Zählers
  `pendingCheckoffs_<Laden>` (die ersten N).
- `drain`: hakt **genau** die gequeueten UUIDs ab (`markCompleted()`, `store.recordCheckOff(item, batched: true)`),
  überspringt unbekannte/schon erledigte UUIDs, löscht den Schlüssel vorher, drained danach den Legacy-Zähler
  count-basiert (erste offene Artikel). Rückgabe: Anzahl. Speichern und Anzeige-Update bleiben beim Aufrufer.

Es gilt unverändert die dokumentierte Mikro-Lücke (App und Widget könnten dieselbe UUID gleichzeitig beanspruchen;
kein prozessübergreifendes Schloss).

### Unit-Tests `CheckoffQueueTests` (In-Memory-Container, eigene `UserDefaults`-Suite je Test)

- **Q1 Reihenfolge und Wirkung:** drei offene Artikel, zwei UUIDs gequeut → `drain` hakt genau diese ab, der
  dritte bleibt offen; je Haken entsteht ein `PurchaseRecord`; `store.recordCheckOff` hat den Einkauf in
  Queue-Reihenfolge fortgeschrieben (`batched`).
- **Q2 Doppelt/erledigt:** dieselbe UUID zweimal, bereits erledigter Artikel, unbekannte UUID → je einmal
  abgehakt, kein zweiter `PurchaseRecord`, kein Absturz; Rückgabe zählt nur echte Haken.
- **Q3 Anzeige:** `effectivePending` blendet gequeute Artikel aus, bevor `drain` lief; nach `drain` identisch zur
  gespeicherten Liste (keine Abweichung zwischen Widget-Anzeige und App-Stand).
- **Q4 Legacy-Zähler:** `pendingCheckoffs_<Laden> = 2` → `effectivePending` lässt die ersten 2 weg, `drain`
  hakt die ersten 2 ab und löscht den Zähler.
- **Q5 Laden getrennt:** Queue von Laden A berührt Laden B nicht (Schlüssel enthält den Namen).
- **Q6 `enqueue`:** schreibt die UUID in den Schlüssel, hängt an, ändert nichts anderes.

### Unit-Tests `AddItemIntentTests`

- **A1 Zuordnung:** mit Kaufhistorie, die einen Laden dominieren lässt, landet der Artikel dort
  (`AssignmentService.assign`, echter Pfad); ohne Historie bei Drogerie-Stichwort im Drogerie-Laden.
- **A2 Menge/Einheit:** `quantity: 3, unit: "kg"` → `quantity "3"`, `quantityAmount 3`, `unit "kg"`;
  Standard `quantity 1` → `"1"`; `unit nil` → `""`.
- **A3 Kein Laden:** ohne aktive Läden bleibt `store == nil` (kein Absturz).
- **A4 Ist-Verhalten festgehalten:** gleicher Name zweimal → zwei Artikel (keine Duplikatprüfung), kein
  Mengenvorschlag aus Historie (`quantitySource` bleibt `"none"` bzw. Initialwert). Kein Beschluss, nur Ist.

### UI-Test `QuickAddControlUITests` (Schnell-hinzufügen)

Start mit `-hasCompletedOnboarding YES -pendingQuickAddForUITests` und gesätem Laden
(`-seedQuickAddAssignmentForUITests`, `tearDown` räumt mit `-clearQuickAddAssignmentSeedForUITests`
und `-clearPendingQuickAddForUITests` auf). Prüft: Die Startseite erscheint, das Schnell-hinzufügen-Feld hat den
Fokus (Tastatur sichtbar) **und** der Merker ist verbraucht (zweiter Start ohne Argument: kein Fokus). Gegenprobe:
Start ohne das Argument → Feld ohne Fokus. Warten mit den Helfern aus `UITestWait.swift`.

## Acceptance Criteria

- **AC-1:** `CheckoffQueue` existiert in einer Datei, die in App- **und** Widget-Ziel kompiliert; die Kopien
  `WidgetStoreLoader.drainPendingCheckoffs`/`effectivePending` und der Schleifenkörper in
  `StoreDetailView.applyPendingCheckoffs` sind entfernt. Nachweis: Build beider Ziele grün, `grep` findet die
  Abhak-Schleife (`markCompleted()` + `recordCheckOff(…batched`) nur noch in `CheckoffQueue.swift`.
- **AC-2:** Q1: `drain` hakt genau die gequeueten UUIDs ab, in Queue-Reihenfolge, mit `PurchaseRecord` und
  Einkaufswegeintrag (`batched`); übrige Artikel bleiben offen.
- **AC-3:** Q2: Doppelte, bereits erledigte und unbekannte UUIDs ergeben keine zweite Buchung und keinen Absturz.
- **AC-4:** Q3: `effectivePending` stimmt vor dem `drain` mit dem Stand überein, den die App nach dem `drain`
  zeigt.
- **AC-5:** Q4: Der Legacy-Zähler wird berücksichtigt und anschließend gelöscht.
- **AC-6:** Q5/Q6: Die Warteschlange ist je Laden getrennt; `enqueue` schreibt nur den eigenen Schlüssel.
- **AC-7:** A1–A3: `AddShoppingItemIntent.add` ordnet über den echten `AssignmentService` zu und legt Menge,
  Einheit und Laden korrekt an; ohne Laden `store == nil`.
- **AC-8:** A4: Das Ist-Verhalten (keine Duplikatprüfung, kein Mengenvorschlag) ist durch Tests festgehalten und in
  der Testklasse als Ist, nicht als Beschluss, kommentiert.
- **AC-9:** UI-Test Schnell-hinzufügen: Mit gesetztem Merker erscheint die Startseite mit fokussiertem Feld; der
  Merker ist danach verbraucht; ohne Merker kein Fokus. Das Startargument existiert nur unter `#if DEBUG`.
- **AC-10:** Rot-vor-Fix/Mutation: Q1 und Q2 schlagen fehl, wenn im `drain` der `!item.isCompleted`-Schutz bzw.
  `recordCheckOff` entfernt wird (Mutationsprobe); die Ausgabe liegt unter
  `docs/artifacts/test-98-durchgang-8-siri-widget/`. Die UI-Gegenprobe (ohne Argument kein Fokus) beweist, dass
  der Test nicht leer läuft.
- **AC-11:** Echter Weg statt Nachbau: Tests rufen `CheckoffQueue` und `AddShoppingItemIntent.add` (die
  Funktionen, die Produkt und Intents benutzen), echte Modelle und echten `AssignmentService`; die Queue-Schlüssel
  werden nicht von Hand in `UserDefaults.standard` gesetzt, sondern über `enqueue` in eigener Suite.
- **AC-12:** Aufräumen: Unit-Tests nutzen je Test eine eindeutige `UserDefaults`-Suite und löschen sie in
  `tearDown()` (Prüfung, dass nichts übrig ist); der UI-Test räumt App-Gruppen-Merker und Seed auf. Nachweis:
  Bestandssuiten laufen im gemeinsamen Lauf mit den neuen Klassen grün; „Executed 0 tests“ oder Abbruch ist kein
  Grün, die Testzahl wird geprüft.
- **AC-13:** Stabilität: feste Zeit wo Zeit eine Rolle spielt (`RouteClock`/`at:`), keine Wartezeiten außer im
  UI-Test; drei Läufe der neuen Klassen hintereinander grün, der UI-Test zusätzlich unter Last.
- **AC-14:** Umfang: höchstens 10 geänderte Dateien, Summe höchstens ±500 LoC (PO-Ausnahme 2026-10-14); im
  Produktcode keine Änderungen außer Auslagerung, `add`-Funktion und DEBUG-Argument. Nachweis:
  `git diff --stat` gegen `origin/main`.
- **AC-15:** Pflicht-Durchlauf (siehe unten) ist als registriertes Artefakt vorhanden, aus einem echten Lauf,
  nicht von Hand gesetzt.
- **AC-16:** Offene Grenzen sind in Spec, Kopfkommentar der Testklassen, `CLAUDE.md` und Ticketkommentar von #98
  benannt (Siri-Ruf, Widget-/Live-Activity-/Control-Tipp, Activity-Teil von `perform`, keine Geräte). Keine Zusage
  lautet „Siri/Widget geprüft“ ohne diese Einschränkungen.
- **AC-17:** Hennings Geräte: Kein Schritt dieses Durchgangs startet, installiert oder liest ein Gerät des Users;
  alle Läufe nur im Simulator Restock-Validate bzw. im Unit-Test-Host.

## Tests

| # | Testfall | Datei | Art | Prüft |
|---|----------|-------|-----|-------|
| T1 | Q1 Drain hakt genau die UUIDs ab, Reihenfolge, Historie | `CheckoffQueueTests` | Unit | AC-2, 11 |
| T2 | Q2 doppelt/erledigt/unbekannt | `CheckoffQueueTests` | Unit | AC-3 |
| T3 | Q3 Anzeige vor/nach Drain | `CheckoffQueueTests` | Unit | AC-4 |
| T4 | Q4 Legacy-Zähler | `CheckoffQueueTests` | Unit | AC-5 |
| T5 | Q5/Q6 Läden getrennt, `enqueue` | `CheckoffQueueTests` | Unit | AC-6 |
| T6 | A1–A3 Zuordnung, Menge, kein Laden | `AddItemIntentTests` | Unit | AC-7 |
| T7 | A4 Ist-Verhalten | `AddItemIntentTests` | Unit | AC-8 |
| T8 | Schnell-hinzufügen mit/ohne Merker | `QuickAddControlUITests` | UI | AC-9, 10 |
| T9 | Mutationsprobe Drain | — | Unit | AC-10 |
| T10 | Bestandssuiten im gemeinsamen Lauf, Aufräumen | alle | Unit+UI | AC-12 |
| T11 | Wiederholung 3x, UI unter Last | neue Klassen | Unit+UI | AC-13 |
| T12 | Diff-Nachweis, Build beider Ziele, grep | — | Diff | AC-1, 14 |
| T13 | Durchlauf im Simulator, Artefakt durch Werkzeug | — | durch Werkzeug | AC-15, 17 |

TDD: Zuerst `CheckoffQueue` als reines Verschieben (Build grün, Verhalten gleich, Bestandssuiten grün), dann
`add`-Funktion, dann Testdateien schreiben; Q1–Q6 und A1–A4 sind danach grün, weil sie bestehendes Verhalten
festhalten. Rot-Nachweis über Mutationsprobe (AC-10). Der UI-Test wird vor dem DEBUG-Argument geschrieben und ist
dann rot (Argument unbekannt, kein Fokus).

## Risiken

- **Umbau der Abhak-Kette** berührt App, Widget und Einkaufsweg-Lernen: Verhalten muss gleich bleiben. Gegenmittel:
  reines Verschieben, Q1–Q5 als Festschreibung, Build beider Ziele, Mutationsprobe.
- **Widget-Ziel:** `CheckoffQueue` braucht dort `SwiftData`-Modelle; die Quelle liegt in `Models/` und ist bereits
  über `Store`/`ShoppingItem` im Widget-Ziel verfügbar. Ein Eintrag fehlt leicht in `project.pbxproj`; Gegenmittel:
  Build beider Ziele.
- **Gemeinsame `UserDefaults`:** eigene Suite je Test (Memory „UI-Test-Seeds müssen aufräumen“).
- **UI-Test Fokus:** Das Feld wird nach 0,45 s fokussiert; Warten mit `waitUntilHittable`/Tastaturprüfung statt
  fester Frist (Memory „Wartezeiten bei kaltem Start“).
- **CloudKit/Sync:** `markCompleted()` bumpt `lastModified`; `drain` ändert das nicht.
- **Umfang:** über den Limits (PO-Ausnahme); Überschreitung von ±500 = STOP.

## Alternativen

- **(a) `AppIntentsTesting` (iOS 27):** ruft Intents im echten Prozess; nur auf dem 27.0-Simulator, braucht
  `#available`, prüft nicht den Systemweg davor. Als spätere Ergänzung möglich. Kippt keine ADR.
- **(b) Duplikat nicht anfassen, Logik im Test nachbauen:** prüft die Kopie, nicht den Produktcode; abgelehnt.
  Kippt die „keep in sync“-Doppelung (kein ADR).
- **(c) `XCUIDevice.siriService`:** prüft nur die Wirkung in der App-Oberfläche, im Simulator unzuverlässig.
- **(d) Siri-Intent um Duplikatprüfung/Mengenvorschlag erweitern:** Produktänderung, PO-Thema, **nicht Teil
  dieses Durchgangs**.
- **Ohne Modell:** nichts hier braucht ein Sprachmodell.

**Entscheidung:** Auslagern in testbare Funktionen plus Unit-Tests und ein kleiner UI-Test, weil die Logik
deterministisch ist und nur so die echte (statt nachgebaute) Abhak-Kette bewiesen wird.

## Pflicht-Durchlauf

Grüne Tests sind kein Nachweis, dass das Feature lebt. Vor Übergabe wird die App im Simulator **Restock-Validate**
mit dem Stand dieses Durchgangs gebaut, installiert und gestartet, mit `-hasCompletedOnboarding YES
-seedQuickAddAssignmentForUITests`. Ablauf: (1) Lauf der Abhak-Kette über den echten Weg: UUID eines offenen
Artikels in `pendingCheckoffIDs_<Laden>` der App-Gruppe des Simulators schreiben (`xcrun simctl spawn … defaults
write` auf die Suite; die UUID stammt aus dem gesäten Laden), App starten, Laden öffnen → Artikel ist abgehakt,
Queue-Schlüssel leer (Screenshot, Schlüsselabfrage). (2) Merker setzen (`-pendingQuickAddForUITests`), Start →
Feld fokussiert (Screenshot). (3) Der Siri-Anlegeweg ist im Simulator nicht von außen auslösbar; hier gilt nur der
Unit-Nachweis (A1–A4), das steht so im Artefakt. Aufräumen mit den Aufräum-Argumenten. Artefakt durch das Werkzeug registriert (Commit-Kennung
und Zeitstempel passen zum Stand), nie von Hand gesetzt. Es läuft nichts auf Hennings Geräten.

## Offene Punkte

- Keine für den PO offen. Ist-Verhalten des Siri-Befehls (keine Duplikatprüfung, kein Mengenvorschlag) wird
  festgehalten, nicht geändert (Empfehlung aus der Analyse).
- Gehört nicht zu diesem Durchgang, als Folgearbeit im Ticketkommentar von #98: `AppIntentsTesting` auf iOS 27;
  Produktentscheidung zu Duplikatprüfung/Mengenvorschlag im Siri-Befehl; Punkt 7 aus #98.
- Offene Grenze (gilt für jede Zusage): echter Siri-Ruf, Widget-/Live-Activity-/Control-Tipp, Activity-Teil von
  `CheckOffItemIntent.perform()`, keine Tests auf Hennings Geräten.
