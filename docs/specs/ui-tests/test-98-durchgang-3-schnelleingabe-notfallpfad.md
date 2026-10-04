---
entity_id: test-98-durchgang-3-schnelleingabe-notfallpfad
type: test
created: 2026-10-04
updated: 2026-10-04
status: draft
workflow: test-98-durchgang-3-schnelleingabe-sync
tags: [test, ui-test, quick-add, store-correction, emergency-path, data-reset, debug-only]
---

# UI-Test-Durchlauf: Schnelleingabe bis in die Liste und Notfallpfad „Daten neu geladen“ (Issue #98, Durchgang 3)

## Approval

- [ ] Approved — PO (offen)

## Purpose

`QuickAddAssignmentUITests` (9 Tests) prüft Ziel-Karte, Grund, Chips, Toast, Rückgängig und die Karte
„Ohne Laden“. Es fehlt das Ende der Kette: Kein Test öffnet danach die Ladenliste. Es ist also
unbewiesen, dass der Artikel nach Return dort steht, dass „Laden ändern“ ihn wirklich verschiebt und
die Korrektur beim nächsten Eintippen wirkt, und dass „500 gramm Hackfleisch“ in der Liste mit Menge
und Einheit erscheint (der Parser ist unit-getestet, die Anzeige nicht).

Zweitens: `SmartCartApp.deleteStoreFiles()` (Stufe 3 des Notfallpfads in `SmartCartApp.init()`) wurde
nie ausgeführt. Sie löscht `*.store`, `-shm`, `-wal` und hat Vorgeschichte (Datenverlust vom
31.07.2026). Ob der Pfad bis zum einmaligen Hinweis in `HomeView` schließt, weiß heute niemand. Ein
DEBUG-Launch-Argument lässt `SharedModelContainer.make()` übersprungen scheitern, sodass Stufe 3 echt
durchlaufen wird.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03), die
Scoping-Limits gelten je Durchgang. Dies ist Durchgang 3 = Schnelleingabe-Rest (Punkt 3) +
`deleteStoreFiles` (Punkt 8). **Geteilte Läden/Sync (Punkt 4) ist Durchgang 4** (nur Hinweis, nicht
Teil dieser Spec): `SyncCoordinator.apply` mit In-Memory-Container sowie `SharedStoreService.merge`
(Sichtbarkeit `private` → `internal` oder Auslagerung); echtes CloudKit-Teilen mit zweitem Konto ist
nicht automatisierbar und wird im Ticket begründet.

Kein Produktverhalten ändert sich. Produktcode bekommt nur einen `#if DEBUG`-Zweig. Kein Modell
beteiligt, alles deterministisch.

Wichtiger Befund zum Hinweistext: Der Alert in `HomeView` (Z. ~306) heißt tatsächlich **„Daten neu
geladen“** (`data.reset.title`, `de.lproj/Localizable.strings`), nicht „Daten zurückgesetzt“. Die
Tests prüfen den echten Text.

## Source

- **Geändert:** `RestockUITests/QuickAddAssignmentUITests.swift` — drei neue Tests (Punkt 3), eigene
  Hilfen `openStore`/`listRow` nach Vorbild `ReplenishmentUITests`.
- **Neu:** `RestockUITests/DataResetUITests.swift` — Notfallpfad-Test(s).
- **Geändert:** `SmartCart/SmartCartApp.swift` — nur `#if DEBUG`:
  - Launch-Argument `-forceContainerFailureForUITests`: Der Aufruf `SharedModelContainer.make()` in
    `init()` wird in diesem Fall übersprungen (Bedingung `if !Self.forceContainerFailure, let c = …`),
    sodass Stufe 3 (`dataResetOccurred` setzen → `deleteStoreFiles()` → neuer Container) echt läuft.
  - Fremddatei-Prüfung: Mit demselben Argument legt die App vor `deleteStoreFiles()` eine Markerdatei
    `uitest-foreign-marker.txt` in `Library/Application Support` des App-Group-Containers an und
    prüft danach per `precondition`, dass sie noch existiert (löscht sie dann selbst). Ein Treffer von
    `deleteStoreFiles` auf Fremddateien beendet die App; der Test sieht keine Ladenkachel und scheitert.
  - `-clearDataResetForUITests`: entfernt `smartcart.dataResetOccurred` aus `UserDefaults.standard`
    (für den Fall, dass ein Test vor dem Alert abbricht).
- **Ggf. geändert:** `SmartCart/Views/Home/QuickAddTargetViews.swift` / `HomeView.swift` — nur falls beim
  Schreiben der Tests ein Identifier fehlt. Geprüft im Code: Toast (`quickAdd.toast.change`,
  `quickAdd.toast.undo`, `quickAdd.toast.message`), Ziel-Karte (`quickAdd.target`, `quickAdd.reason`,
  `quickAdd.storeChip.<Name>`) haben welche. Das Korrektur-Sheet ist ein `confirmationDialog` mit Knöpfen
  „<Emoji> <Name>“ (Titel „Zu welchem Laden?“) und wird über den Knopf-Text bedient (`app.buttons["💄 dm"]`),
  Listenzeilen über `app.cells.containing(.staticText, identifier: <Name>)`. Erwartet: keine neuen
  Identifier nötig.
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — `DataResetUITests.swift` in `PBXBuildFile`,
  `PBXFileReference`, `PBXGroup` (RestockUITests), `PBXSourcesBuildPhase` des UITests-Targets.
- **Nicht geändert:** `SharedModelContainer.make()` (Warnkommentar am Dateikopf beachtet; Verzweigung
  und Fallback-Reihenfolge bleiben unangetastet, nur die aufrufende Stelle bekommt den DEBUG-Zweig),
  `deleteStoreFiles()` (bleibt `private`), `AssignmentService`, `QuickAddParser`,
  `StoreAssignmentOverrideService`, Texte und Layout.

Geschätzter Umfang: 4 Dateien (+ pbxproj = 5 Registrierungsstellen), ca. +200 LoC, davon ca. 25 Zeilen
DEBUG-Produktcode.

## Verhalten

### Punkt 3: Schnelleingabe (bestehender Seed)

Start wie bisher: `-hasCompletedOnboarding YES -seedQuickAddAssignmentForUITests` (Läden „Lidl“
Lebensmittel, „dm“ Drogerie, keine Standard-Läden, keine gemerkten Korrekturen). Der Seed leert
Läden, Artikel, `StoreAssignmentOverrideService` und `DefaultStoreService`; das tearDown der
Klasse (`-clearQuickAddAssignmentSeedForUITests`) räumt dasselbe wieder weg. Es braucht **keinen
neuen Seed**.

- **Q1 Artikel steht in der Liste (3a):** „Nudeln“ tippen, Return. Ladenkachel „Lidl,“ öffnen:
  „Nudeln“ steht als offener Artikel in der Liste. Gegenprobe: Die Liste von „dm“ enthält ihn nicht.
- **Q2 Laden ändern + Korrektur gilt (3b):** „Nudeln“ tippen, Return, im Toast
  `quickAdd.toast.change` tippen. Dialog „Zu welchem Laden?“ zeigt nur den anderen Laden („💄 dm“).
  Tippen. Der Toast nennt „Zu dm verschoben“. „dm,“ öffnen: „Nudeln“ steht dort; „Lidl,“ enthält ihn
  nicht mehr. Zurück zur Startseite, „Nudeln“ erneut tippen: `quickAdd.target` nennt „dm“ und
  `quickAdd.reason` „Du hast diesen Artikel früher in diesen Laden verschoben.“ (`AssignmentReason.
  userCorrection`). Gegenprobe: ein anderer Artikel („Joghurt“) wird weiter automatisch nach „Lidl“
  geleitet, die Korrektur gilt nur für den Namen.
- **Q3 Menge in der Liste (3c):** „500 gramm Hackfleisch“ tippen, Return. Ziel-Karte nennt „Lidl“
  (Lebensmittel). In der Liste von „Lidl“ steht eine Zeile mit „Hackfleisch“ als Name (nicht
  „500 gramm Hackfleisch“) und der Mengenzeile „500 gramm“ ohne Vorsilbe „ca. “ (selbst getippte Menge,
  `quantitySource` „user“; `ItemRow` Z. ~97).

### Punkt 8: Notfallpfad, Argument `-forceContainerFailureForUITests`

Zwei Starts, beide im Test-Simulator:

1. **Vorlauf mit Seed:** `-hasCompletedOnboarding YES -seedQuickAddAssignmentForUITests`. Kacheln
   „Lidl,“ und „dm,“ stehen da; die Läden liegen damit in den Store-Dateien des App-Group-Containers.
   Die App wird beendet.
2. **Notfalllauf:** `-hasCompletedOnboarding YES -forceContainerFailureForUITests` (ohne Seed).
   `init()` überspringt `make()`, setzt `smartcart.dataResetOccurred`, ruft die echte
   `deleteStoreFiles()` auf und öffnet einen frischen Container. Erwartet: Alert „Daten neu geladen“
   (mit „OK“) erscheint, nach „OK“ ist die Startseite bedienbar (Schnell-Eingabe-Feld vorhanden),
   „Lidl,“ und „dm,“ existieren **nicht** mehr. Die Markerdatei (Fremddatei) überlebt (sonst Absturz).
3. **Einmaligkeit:** Dritter Start ohne Flag und ohne Seed: der Alert erscheint **nicht** erneut
   (`HomeView.onAppear` entfernt den Schlüssel), die Seed-Läden sind weiterhin weg.

Der frische Container nach dem Löschen ist leer, die App bleibt ohne Läden bedienbar (Karte „Läden
anlegen“ bzw. leere Startseite; der Test prüft nur Bedienbarkeit über das Schnell-Eingabe-Feld).

### Aufräumen

- `QuickAddAssignmentUITests.tearDown()` bleibt (`-clearQuickAddAssignmentSeedForUITests`).
- `DataResetUITests.tearDown()` startet die App einmal mit
  `-clearQuickAddAssignmentSeedForUITests -clearDataResetForUITests` und beendet sie. Danach gibt es
  keine Läden, keine gemerkten Korrekturen, keinen Schlüssel `smartcart.dataResetOccurred`.
- Die Markerdatei entfernt die App selbst nach der Prüfung (Seed und Clear laufen nie im selben Start,
  Marker und Flag nie ohne `-forceContainerFailureForUITests`).

## Acceptance Criteria

- AC-1: Nach Eintippen von „Nudeln“ und Return steht „Nudeln“ als offener Artikel in der Liste von
  „Lidl“ und nicht in der Liste von „dm“ (Test Q1). Nutzen: Der Artikel ist wirklich angekommen, nicht
  nur der Toast erschienen.
- AC-2: „Laden ändern“ im Toast öffnet den Dialog „Zu welchem Laden?“ mit genau dem anderen Laden;
  nach der Wahl von „dm“ steht „Nudeln“ in der Liste von „dm“ und nicht mehr in „Lidl“ (Test Q2).
- AC-3: Dieselbe Korrektur wird gemerkt: Beim erneuten Eintippen von „Nudeln“ nennt `quickAdd.target`
  „dm“ und `quickAdd.reason` den Satz „Du hast diesen Artikel früher in diesen Laden verschoben.“;
  ein anderer Artikel („Joghurt“) wird weiter nach „Lidl“ geleitet (Test Q2).
- AC-4: „500 gramm Hackfleisch“ erscheint in der Liste von „Lidl“ mit Name „Hackfleisch“ und Mengenzeile
  „500 gramm“ (ohne „ca. “); der eingetippte Rohtext „500 gramm Hackfleisch“ steht nicht als Name da
  (Test Q3).
- AC-5: Mit `-forceContainerFailureForUITests` läuft Stufe 3 des Notfallpfads echt: Nach dem Vorlauf mit
  Seed existieren „Lidl“ und „dm“ nach dem Notfalllauf nicht mehr (Test D1). Nutzen: `deleteStoreFiles`
  löscht nachweislich die Store-Dateien.
- AC-6: Im Notfalllauf erscheint der Alert „Daten neu geladen“ genau einmal; nach „OK“ ist die App
  bedienbar (Schnell-Eingabe-Feld findbar), und ein dritter Start ohne Flag zeigt den Alert nicht
  erneut (Test D1/D2).
- AC-7: `deleteStoreFiles` trifft keine Fremddateien: Die vom DEBUG-Zweig angelegte Markerdatei
  `uitest-foreign-marker.txt` im Application-Support-Ordner des App-Group-Containers existiert nach dem
  Löschen noch; sonst beendet die App sich per `precondition` und der Test scheitert (Test D1).
- AC-8: Alle Tests bedienen die echten Elemente der App (Identifier `quickAdd.*`, Kachel-Label,
  Dialog-Knopf, Alert-Knopf „OK“); weder Zuordnung noch gemerkte Korrektur noch der Hinweisschlüssel
  wird vom Test von Hand gesetzt. Einzig erlaubt sind die Seed-Rohdaten (zwei Läden) und das
  Flag aus AC-5.
- AC-9: Aufräumen: `QuickAddAssignmentUITests.tearDown()` und `DataResetUITests.tearDown()` leeren
  Läden, Korrekturen und `smartcart.dataResetOccurred`. Nachweis: Die Bestandssuiten (insbesondere die
  bisherigen neun `QuickAddAssignmentUITests` und `ReplenishmentUITests`) laufen im gemeinsamen Lauf
  grün; ein Folgetest sieht bei erneutem Seed die frischen Läden ohne Korrekturen.
- AC-10: Produktcode: `-forceContainerFailureForUITests`, die Fremddatei-Prüfung und
  `-clearDataResetForUITests` existieren ausschließlich unter `#if DEBUG` (Release-Build enthält keinen
  Verweis darauf; nachgewiesen durch Release-Build und Suche im Diff). `SharedModelContainer.make()`
  und `deleteStoreFiles()` bleiben im Diff unverändert (`deleteStoreFiles` weiter `private`).
- AC-11: Umfang: ≤ 5 Dateien, ca. +200 LoC, keine Änderung an Regeln (`AssignmentService`,
  `QuickAddParser`, `StoreAssignmentOverrideService`), keine Änderung an sichtbaren Texten oder
  Layout.
- AC-12: Offene Grenze ist in Spec, Testkommentar und Ticketkommentar benannt: Der natürliche Auslöser
  (`make()` liefert `nil`, weil CloudKit/Schema/Dateisystem wirklich scheitern) lässt sich im
  Simulator nicht erzeugen. Bewiesen wird alles ab Stufe 3 (löschen, Hinweis, frischer Container,
  Bedienbarkeit); dass `make()` in der Praxis `nil` liefert, deckt dieser Durchgang nicht ab.

## Tests

| # | Testfall | Datei | Art | Prüft |
|---|----------|-------|-----|-------|
| T1 | `testAddedItemAppearsInStoreList` (Q1) | `QuickAddAssignmentUITests` | UI | AC-1, 8 |
| T2 | `testChangeStoreMovesItemAndRemembersCorrection` (Q2) | `QuickAddAssignmentUITests` | UI | AC-2, 3, 8 |
| T3 | `testQuantityAndUnitShownInList` (Q3, „500 gramm Hackfleisch“) | `QuickAddAssignmentUITests` | UI | AC-4 |
| T4 | `testEmergencyPathDeletesStoresAndShowsNoticeOnce` (D1) | `DataResetUITests` | UI | AC-5, 6, 7, 8 |
| T5 | `testAppUsableAfterEmergencyReset` (D2, App nach Notfalllauf bedienbar, kein zweiter Alert) | `DataResetUITests` | UI | AC-6 |
| T6 | Release-Build, `#if DEBUG`-Prüfung | — | Build | AC-10 |
| T7 | Bestandssuiten im gemeinsamen Lauf | alle | UI+Unit | AC-9 |
| T8 | Wiederholung 3x (Stabilität) | alle neuen | UI | AC-9 |
| T9 | Durchlauf im Simulator, Artefakt | — | durch Werkzeug | AC-5, 12 |
| T10 | Diff-Nachweis: Dateizahl, LoC, keine Änderung an Regel-Diensten, sichtbaren Texten, Layout (Scope-Gate und `git diff --stat` gegen `origin/main`) | — | Diff | AC-11 |

Seed/Clear-Muster: Q1–Q3 nutzen den vorhandenen Seed und das vorhandene Clear; D1/D2 nutzen den
vorhandenen Seed für den Vorlauf, das neue Flag für den Notfalllauf und beim Aufräumen
`-clearQuickAddAssignmentSeedForUITests -clearDataResetForUITests`. Wiederholter Start gegen #105
(App startet gelegentlich ohne Launch-Argumente): Wie in `ReplenishmentUITests.launch(_:waitingFor:)`
wird auf eine Ladenkachel (Q1–Q3, Vorlauf) bzw. das Schnell-Eingabe-Feld (Notfalllauf, dort gibt es
keine Kachel) gewartet und einmal neu gestartet. Beim Notfalllauf zählt ein Start ohne Argument als
Fehlstart: kein Alert, die Seed-Läden stünden noch da, der Test erkennt das über die Kacheln.

TDD: Q1–Q3 und D1/D2 werden vor dem DEBUG-Zweig geschrieben. Q1–Q3 testen bestehendes Verhalten und
dürften schon grün sein (Nachweis, dass sie nicht leer laufen: Gegenprobe-Assertions, z. B. Liste von
„dm“ ohne „Nudeln“); RED sind D1/D2 (Argument unbekannt, Seed-Läden bleiben, kein Alert). Danach DEBUG-
Zweig, Tests grün.

Randbedingungen: Wartezeiten großzügig (Tastatur und Dialoge kommen auf dem Runner verspätet); Tests
laufen auf Deutsch (Scheme pinnt `de`/`DE`); Simulator nie parallel, eigenes Testgerät
Restock-Validate; „Executed 0 tests“ ist kein Grün.

## Risiken

- **Notfallpfad löscht Daten.** Das Flag darf nur im Test-Simulator (Restock-Validate) laufen, nie
  gegen Entwicklerdaten oder ein echtes Gerät. Schutz: nur `#if DEBUG`, nur mit explizitem Argument;
  der Test startet es erst nach einem Seed-Lauf und räumt auf. Der Warnkommentar in
  `SharedModelContainer.swift` (Datenverlust, Schema-Mismatch zwischen Prozessen) wurde gelesen:
  `make()` bleibt unverändert, der DEBUG-Zweig sitzt auf der Aufrufer-Seite.
- **Echter Löschpfad auf dem Testgerät:** `deleteStoreFiles()` entfernt auch Store-Dateien im alten
  App-Container. Im Simulator ohne Daten der Entwickler unkritisch; Restock-Validate hat nur Testdaten.
- **Dialog-Bedienung:** `confirmationDialog` zeigt sich auf dem iPhone als Action Sheet, Knöpfe tragen
  „<Emoji> <Name>“. Suche über `app.buttons["💄 dm"]`; scheitert sie (Emoji im Label, siehe Memory
  „Emoji-Text bricht Accessibility-Label“), über `label CONTAINS "dm"` innerhalb des Sheets
  (`app.sheets`) — nicht über die Ladenkachel „dm,“, die darunter noch im Hierarchiebaum liegt.
- **Gleiche Namen an mehreren Stellen:** „Nudeln“ steht auch im Toast, in der Ziel-Karte und in der
  Kachelzeile. Die Liste wird deshalb als Zelle (`app.cells.containing(...)`) nach dem Öffnen des Ladens
  gesucht und der Toast vorher abgewartet bzw. geschlossen (Toast steht 6 s, bei Korrektur 3 s).
- **Persistenz außerhalb von SwiftData:** Die gemerkte Korrektur liegt in UserDefaults; der Seed ruft
  `StoreAssignmentOverrideService.removeAll()`, das Clear ebenfalls (im Code geprüft, Z. 369–376).
  Ohne das würde „Nudeln → dm“ aus Q2 die anderen Tests färben.
- **Hinweis-Schlüssel in `.standard`:** `smartcart.dataResetOccurred` überlebt Abbrüche vor dem Alert
  und würde in einem Folgetest einen unerwarteten Alert zeigen → eigenes Clear-Argument.
- **App startet ohne Launch-Argumente (#105):** siehe Seed/Clear-Muster; im Notfalllauf besonders
  heikel, weil ein Start ohne Flag den Pfad gar nicht berührt. Gegenmaßnahme: Erwartung auf den Alert
  mit großzügigem Timeout, bei Ausbleiben einmal neu starten, danach rot.
- **Fremddatei-Prüfung als Absturz:** `precondition` macht einen Treffer als fehlende App im Test
  sichtbar, ist aber nur eine Hilfsprüfung. Das Absturzprotokoll im Fehlerfall nennt den Grund.
- **Umfang:** Q1–Q3 plus D1/D2 plus DEBUG-Zweig sind an der Grenze von ±250 LoC. Wird es mehr,
  Rückmeldung mit Schätzung; Kandidat zum Verschieben: Q3 (Mengen-Anzeige) in einen späteren Durchgang.

## Alternativen

- **(a) `deleteStoreFiles` auf Verzeichnis-Parameter umstellen und per Unit-Test im Wegwerf-Verzeichnis
  prüfen:** billiger, prüft auch Fremddateien gezielt. Bewusst **verworfen** für diesen Durchgang:
  (1) Es kippt die Entscheidung vom 31.07.2026 („wieder `private`, nur der automatische Notfallpfad darf
  das auslösen“), (2) es prüft nur die Funktion, nicht die Kette bis zum Hinweis und zum frischen
  Container (Lehre vom 2026-09-27: nur der echte Durchlauf prüft, ob die Kette schließt). Als
  Ergänzung später möglich; dann würde diese Entscheidung bewusst überprüft.
- **Fremddateien über den Test statt über den DEBUG-Marker anlegen:** verworfen, der Testprozess kann
  den App-Group-Container der App nicht verlässlich beschreiben.
- **Schnelleingabe als Unit-Test (Parser, Override-Service):** existiert bereits
  (`QuickAddParserTests`, `AssignmentServiceTests`); beweist nicht, dass etwas in der Liste ankommt.
  Verworfen.
- **Sync zuerst (Durchgang 3 = 4 + 8):** möglich, aber Sync braucht Sichtbarkeitsänderungen in
  `SharedStoreService` und eine eigene Testdatei mit In-Memory-Container; zusammen mit (3)+(8)
  sprengt das die Limits, und (3)/(8) und (4) haben kein gemeinsames Ziel (UI-Kette vs. Merge-Logik).
  Daher Durchgang 4.
- **Natürlichen Fehler erzeugen (z. B. App-Group-Container unbeschreibbar machen oder korrupte Store-
  Datei vorlegen):** im Simulator nicht zuverlässig und riskant für das Testgerät; das Flag ist die
  kleinste Änderung, die Stufe 3 echt durchläuft. Ein korrupter Store wäre die nähere Nachbildung;
  Kosten und Instabilität sprechen im Moment dagegen (offene Grenze AC-12).
- Gekippte frühere Entscheidung: keine. Entscheidung vom 31.07.2026 bleibt erhalten (`deleteStoreFiles`
  bleibt `private`, kein neuer Auslöser im Produkt).

**Entscheidung:** DEBUG-Flag und echter UI-Durchlauf (Weg b) für Punkt 8, vorhandener Seed für
Punkt 3, Sync in Durchgang 4.

## Offene Punkte

- Keine für den PO (technische Entscheidungen).
- Offene Grenze (gilt für jede Zusage dieses Durchgangs): Der natürliche Auslöser des Notfallpfads
  (`SharedModelContainer.make()` liefert `nil`) ist im Simulator nicht erzeugbar; geprüft wird alles ab
  Stufe 3.
- Durchgang 4 (Sync) als Kommentar in #98 festhalten.
- Nach Abschluss: Verweis auf `-forceContainerFailureForUITests` und `-clearDataResetForUITests` in
  `CLAUDE.md` (Abschnitt Build/UI-Tests), falls das Limit es erlaubt, sonst im Folgedurchgang.
