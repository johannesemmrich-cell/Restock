---
entity_id: replenishment-uitest
type: test
created: 2026-10-03
updated: 2026-10-03
status: draft
workflow: test-98-durchgang-2-banner-schnelleingabe
tags: [test, ui-test, replenishment, banner, store, developer-mode, debug-only]
---

# UI-Test-Durchlauf: Nachkauf-Banner und „Vielleicht auch fällig“ (Issue #98, Durchgang 2)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Die Regeln der Nachkauf-Vorschläge (`HabitService`, `ReplenishmentSnoozes`,
`ReplenishmentBlocklist`) sind unit-getestet (`ReplenishmentPackageCTests` u. a.). Kein Test fährt
aber den echten Weg: Kaufhistorie → App berechnet Fälligkeit → Banner auf dem Startbildschirm bzw.
Abschnitt „Vielleicht auch fällig“ in der Ladenliste → `+`, „Hab noch“, „Nicht mehr vorschlagen“,
„Alle hinzufügen“ → Artikel steht in der Liste, Vorschlag verschwindet, Sperre hält auch nach
App-Neustart. Dieser Durchgang fügt diese Durchläufe als UI-Tests hinzu. Der Seed legt **nur
Rohdaten** an (Läden, rückdatierte Käufe); ob etwas fällig ist, rechnet die App selbst. Kein
Produktverhalten ändert sich, der Produktcode bekommt nur Accessibility-Identifier.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03), die
Scoping-Limits gelten je Durchgang. Dies ist Durchgang 2 (Punkt 2 aus #98).
**Die Schnelleingabe (Punkt 3 aus #98: Artikel landet nach Return wirklich in der Ladenliste, „Laden
ändern“ im Toast, Mengen-Anzeige) ist ausdrücklich nicht Teil dieses Durchgangs und wird in
Durchgang 3 im selben Ticket #98 umgesetzt** (im Ticket festzuhalten).

Wichtiger Befund: Beide Oberflächen gibt es nur im Entwicklermodus (`HomeView.swift:162`
`if developerMode && !dueSoonItems.isEmpty`; `refreshDueSoon()` Z. 1622 und
`StoreDetailView.refreshAlsoDue()` Z. 770 leeren die Vorschläge ohne `developerMode`). Die Tests
starten deshalb mit `-developerMode YES`. Ob die Funktion bewusst dort bleibt, ist ein Produktthema
und nicht Gegenstand dieses Durchgangs.

## Source

- **Neu:** `RestockUITests/ReplenishmentUITests.swift`
- **Geändert:**
  - `SmartCart/SmartCartApp.swift` — zwei DEBUG-Funktionen `seedReplenishmentForUITestsIfNeeded` und
    `clearReplenishmentForUITestsIfNeeded` (Vorbild `seedShoppingRouteForUITestsIfNeeded`, Z. ~275),
    in der `defer`-Liste der `init()` (Z. ~30–43) eingetragen, hinter den Launch-Argumenten
    `-seedReplenishmentForUITests` / `-clearReplenishmentForUITests`
  - `SmartCart/Views/Home/HomeView.swift` — nur Identifier in `replenishmentBanner` (Z. ~853):
    „Alle hinzufügen“-Knopf, `+`-Knopf und `Menu` je Zeile
  - `SmartCart/Views/Store/StoreDetailView.swift` — nur Identifier in `alsoDueRow` (Z. ~720):
    `+`-Knopf und `Menu`
  - `Restock.xcodeproj/project.pbxproj` — neue Testdatei in `PBXBuildFile`, `PBXFileReference`,
    `PBXGroup` (RestockUITests), `PBXSourcesBuildPhase` des UITests-Targets
- **Nicht geändert:** `HabitService.swift` und alle Regeln (Fälligkeit, Snooze, Sperrliste,
  Zuordnung), `PurchaseRecord.swift`, Texte und Layout der Views, Schnelleingabe
  (`QuickAddAssignmentUITests` bleibt unverändert).

Geschätzter Umfang: 5 Dateien, ca. +210 LoC (tatsächlich ca. +330, davon ca. 65 Produktcode; Überschreitung des LoC-Limits vom PO am 2026-10-03 ausdrücklich akzeptiert, weil sie fast nur Testcode betrifft), davon ca. 12 Zeilen Produktcode (Identifier) und ca. 60
Zeilen DEBUG-Seed.

## Verhalten

### Testhilfe: Seed `-seedReplenishmentForUITests`

Läuft nur in DEBUG und löscht zuerst alle Läden/Artikel (`deleteAllStoresAndItems`) und die
`PurchaseRecord`s der beiden Seed-Läden (Hinweis: `deleteAllStoresAndItems` entfernt heute nur
Käufe von „Quittenhof“; die Seed-Käufe werden in der eigenen Funktion über `storeName` gelöscht,
`deleteAllStoresAndItems` selbst bleibt unverändert). Danach:

- Laden **„Bannerladen“** und Laden **„Listenladen“** (beide ohne Artikel, `visitsPerWeek` 1).
- **Banner-Artikel „Bannerbutter“ und „Bannerquark“**, gekauft nur im Bannerladen
  (`storeName: "Bannerladen"`): je drei Kaufdaten im Abstand von 10 Tagen, das letzte vor 9 Tagen
  (also −29, −19, −9 Tage relativ zu jetzt). Die App errechnet daraus „in 1 Tag fällig“ und damit
  Banner-Fenster (Fenster bei 10-Tage-Zyklus: 2 Tage).
- **Listen-Artikel „Listenreis“ und „Listennudeln“**, gekauft nur im Listenladen: je drei Kaufdaten
  im Abstand von 20 Tagen, das letzte vor 6 Tagen (−46, −26, −6). Nächster Kauf in 14 Tagen: außerhalb
  des Banner-Fensters (4 Tage), aber vor dem nächsten Besuch (Besuchsabstand aus den Kaufdaten 20
  Tage), also genau der Fall von „Vielleicht auch fällig“ und **nicht** im Banner. Begründung
  (Issue #115): die alten Werte −37/−23/−9 hatten nur 1 Tag Reserve; Schließtag-Regel (Di) und
  Uhrzeit ließen „Listenreis“ in 678 von 8760 Stunden eines Jahres im Banner erscheinen
  (`ReplenishmentSeedYearTests`).
- `PurchaseRecord.date` wird nach `init` von Hand gesetzt (der Konstruktor setzt `Date()`).
  Alle Daten relativ zu `Date()`, keine festen Kalendertage. Kaufdaten Mittag (12:00) des jeweiligen
  Tages, damit die Tagesgrenze um Mitternacht keine Rolle spielt.
- Der Seed setzt **weder** `dueSoonItems` **noch** Snoozes, Sperren oder irgendeinen UserDefaults-
  Eintrag, schaltet den Entwicklermodus nicht um und lässt `notificationsEnabled` unberührt (keine
  Berechtigungsabfrage im Test). Der Entwicklermodus kommt über `-developerMode YES`.
- Vor dem Anlegen werden die unten genannten UserDefaults-Schlüssel ebenfalls entfernt, damit ein
  Rest eines abgebrochenen Laufs den Start nicht verfälscht.

Die Trennung der Artikel ist Absicht: Ein Banner-Artikel erscheint auch in der Ladenliste seines
Ladens (`dueBeforeNextVisit` enthält alles, was das Banner zeigt), „Alle hinzufügen“ nimmt alles
aus dem Banner. Die Listen-Artikel liegen außerhalb des Banner-Fensters, sodass die Aktionen in einer
Oberfläche die andere nicht beeinflussen. Die Zuordnung zum Laden folgt der Kaufhistorie
(`AssignmentService.assign`, Regel „Kaufhistorie dominiert“): Bannerladen-Käufe → Bannerladen.

### Testhilfe: Aufräumen `-clearReplenishmentForUITests`

Löscht Läden, Artikel und Seed-Käufe wie der Seed und entfernt zusätzlich die UserDefaults-
Schlüssel, die die Tests berühren (App-Container überlebt den Test, siehe CLAUDE.md):
`snoozedReplenishments` (`ReplenishmentSnoozes.defaultsKey`), `blockedReplenishments`
(`ReplenishmentBlocklist.defaultsKey`), `dismissedReplenishments` und `acceptedReplenishments`
(`ReplenishmentKeyMigration.dismissedKey/acceptedKey`), `replenishmentKeysByPurchaseDate`
(`ReplenishmentKeyMigration.doneKey`), `replenishmentMetricsCounts` und `replenishmentMetricsShown`
(`ReplenishmentMetrics.countsKey/shownKey`), `notifiedOverdueReplenishments`
(`OverdueNotificationLedger.defaultsKey`). Die Namen werden über die `static let`-Konstanten
gelesen, nicht als Literale kopiert. Seed und Clear laufen nie im selben Start.

### Identifier (Produktcode)

Banner (`HomeView.replenishmentBanner`):
- `replenish.addAll` — Knopf „Alle hinzufügen“
- `replenish.add.<Name>` — `+` der Zeile, z. B. `replenish.add.Bannerbutter`
- `replenish.menu.<Name>` — das ✕-`Menu` der Zeile

„Vielleicht auch fällig“ (`StoreDetailView.alsoDueRow`):
- `replenish.also.add.<Name>` — `+` der Zeile
- `replenish.also.menu.<Name>` — das ✕-`Menu` der Zeile

Die Menüpunkte „Hab noch“ und „Nicht mehr vorschlagen“ werden über ihr Label bedient (Texte aus
`Localizable.strings`, Scheme pinnt Deutsch), da sie nur im geöffneten Menü existieren. Die
Präfixe `replenish.add.`/`replenish.also.add.` sind getrennt, damit Banner (liegt unter der
geöffneten Ladenansicht noch im Navigationsstapel) und Ladenliste nie denselben Identifier tragen.

### Ablauf Banner (Startbildschirm)

Start: `-hasCompletedOnboarding YES -developerMode YES -seedReplenishmentForUITests`. Der Banner
„Zeit zum Nachkaufen“ zeigt „Bannerbutter“ und „Bannerquark“, nicht „Listenreis“/„Listennudeln“.

- **B1 Anzeige:** Beide Banner-Artikel sichtbar, mit `replenish.add.*` und `replenish.menu.*`.
- **B2 `+`:** `replenish.add.Bannerbutter` tippen. Danach: Zeile „Bannerbutter“ aus dem Banner
  verschwunden, „Bannerquark“ bleibt. Kachel „Bannerladen,“ öffnen: „Bannerbutter“ steht als offener
  Artikel in der Liste.
- **B3 Hab noch:** `replenish.menu.Bannerquark` öffnen, „Hab noch“ wählen. Die Zeile ist
  verschwunden. App beenden und neu starten (ohne Seed): „Bannerquark“ bleibt aus dem Banner (der
  Termin liegt um mindestens Fenster + 2 Tage hinter jetzt, `ReplenishmentSnoozes`).
- **B4 Nicht mehr vorschlagen:** `replenish.menu.Bannerbutter` öffnen, „Nicht mehr vorschlagen“
  wählen. Zeile weg. App neu starten ohne Seed: „Bannerbutter“ erscheint nicht wieder, „Bannerquark“
  schon (Gegenprobe: der Banner ist nicht einfach leer).
- **B5 Alle hinzufügen:** `replenish.addAll` tippen. Der Banner verschwindet ganz; Kachel
  „Bannerladen,“ öffnen: „Bannerbutter“ und „Bannerquark“ stehen beide offen in der Liste;
  „Listenreis“/„Listennudeln“ wurden nicht hinzugefügt (Liste des Listenladens bleibt ohne offene
  Artikel).

### Ablauf Ladenliste („Vielleicht auch fällig“)

Start wie oben, Kachel „Listenladen,“ öffnen. Abschnitt „Vielleicht auch fällig“ mit „Listenreis“ und
„Listennudeln“.

- **L1 Anzeige:** beide Listen-Artikel im Abschnitt mit `replenish.also.add.*`/`.menu.*`; der
  Banner-Artikel „Bannerbutter“ erscheint hier nicht (anderer Laden).
- **L2 `+`:** `replenish.also.add.Listenreis` tippen. Die Zeile verschwindet aus dem Abschnitt,
  „Listenreis“ steht als offener Artikel in derselben Liste, „Listennudeln“ bleibt im Abschnitt.
- **L3 Hab noch:** `replenish.also.menu.Listennudeln`, „Hab noch“: Zeile weg, „Listenreis“ unberührt.
  Laden schließen und wieder öffnen: „Listennudeln“ bleibt weg (Snooze bis mindestens zum nächsten
  Besuch).
- **L4 Nicht mehr vorschlagen:** `replenish.also.menu.Listenreis`, „Nicht mehr vorschlagen“: Zeile
  weg. App beenden, neu starten ohne Seed, Laden öffnen: „Listenreis“ bleibt weg, „Listennudeln“
  ist wieder da (Gegenprobe).
- **N Negativ-Kontrolle:** Start mit Seed, aber **ohne** `-developerMode YES` (Developer-Mode
  bleibt aus): kein Banner „Zeit zum Nachkaufen“, in „Listenladen“ kein Abschnitt „Vielleicht auch
  fällig“. Das belegt den Befund oben und sichert, dass die Positiv-Tests nicht zufällig laufen.

## Acceptance Criteria

- AC-1: Mit `-seedReplenishmentForUITests` startet die App mit Laden „Bannerladen“ und
  „Listenladen“ und Käufen für „Bannerbutter“, „Bannerquark“ (nur Bannerladen, −29/−19/−9 Tage) sowie
  „Listenreis“, „Listennudeln“ (nur Listenladen, −46/−26/−6 Tage), alle relativ zu `Date()` gesetzt;
  der Seed setzt nur Läden und `PurchaseRecord`s, keine Vorschlagsliste, keinen Snooze/Sperr-Eintrag.
- AC-2: Mit `-developerMode YES` zeigt der Startbildschirm den Banner „Zeit zum Nachkaufen“ mit
  genau „Bannerbutter“ und „Bannerquark“ (Test B1); die Listen-Artikel stehen nicht im Banner.
- AC-3: `+` im Banner (Test B2): „Bannerbutter“ verschwindet aus dem Banner und steht danach als
  offener Artikel in der Liste von „Bannerladen“.
- AC-4: „Hab noch“ im Banner (Test B3): „Bannerquark“ verschwindet und bleibt auch nach App-Neustart
  ohne Seed aus dem Banner.
- AC-5: „Nicht mehr vorschlagen“ im Banner (Test B4): „Bannerbutter“ verschwindet und erscheint auch
  nach App-Neustart nicht wieder, während „Bannerquark“ nach dem Neustart noch im Banner steht.
- AC-6: „Alle hinzufügen“ (Test B5): Banner verschwindet, beide Banner-Artikel stehen offen in
  „Bannerladen“, die Liste von „Listenladen“ bekommt keinen offenen Artikel.
- AC-7: Die Ladenliste „Listenladen“ zeigt unter „Vielleicht auch fällig“ genau „Listenreis“ und
  „Listennudeln“ (Test L1), nicht „Bannerbutter“.
- AC-8: `+` in der Ladenliste (Test L2): „Listenreis“ verschwindet aus dem Abschnitt und steht
  offen in der Liste von „Listenladen“; „Listennudeln“ bleibt im Abschnitt.
- AC-9: „Hab noch“ in der Ladenliste (Test L3): „Listennudeln“ verschwindet und bleibt nach
  Schließen und erneutem Öffnen des Ladens weg; „Listenreis“ bleibt unverändert.
- AC-10: „Nicht mehr vorschlagen“ in der Ladenliste (Test L4): „Listenreis“ verschwindet und bleibt
  nach App-Neustart ohne Seed weg; „Listennudeln“ steht nach dem Neustart wieder im Abschnitt.
- AC-11: Negativ-Kontrolle (Test N): ohne `-developerMode YES` und mit Seed erscheinen weder der
  Banner noch der Abschnitt „Vielleicht auch fällig“.
- AC-12: Alle Tests bedienen die echten Elemente der App (Identifier `replenish.*`, die Menüpunkte
  über ihr Label „Hab noch“ / „Nicht mehr vorschlagen“); kein Vorschlag, keine Fälligkeit, kein
  Snooze und keine Sperre wird von Hand gesetzt, außer den Rohdaten aus AC-1.
- AC-13: Die Identifier `replenish.addAll`, `replenish.add.<Name>`, `replenish.menu.<Name>`,
  `replenish.also.add.<Name>`, `replenish.also.menu.<Name>` stehen im Produktcode; sichtbare Texte
  und Layout ändern sich nicht (Diff in `HomeView.swift`/`StoreDetailView.swift` nur
  `.accessibilityIdentifier`-Zeilen).
- AC-14: `tearDown()` der Testklasse startet die App einmal mit `-clearReplenishmentForUITests` und
  beendet sie; danach existieren „Bannerladen“, „Listenladen“ und ihre Seed-Käufe nicht mehr und die
  UserDefaults-Schlüssel `snoozedReplenishments`, `blockedReplenishments`, `dismissedReplenishments`,
  `acceptedReplenishments`, `replenishmentKeysByPurchaseDate`, `replenishmentMetricsCounts`,
  `replenishmentMetricsShown`, `notifiedOverdueReplenishments` sind entfernt. Nachweis: Ein
  Folgetest (Reihenfolge egal) sieht bei erneutem Seed wieder beide Banner-Artikel; die
  Bestandssuiten laufen im gemeinsamen Lauf ohne Wechselwirkung.
- AC-15: Die Tests starten die App bei fehlender Seed-Kachel einmal neu (Muster `openStore` aus
  `ShoppingRouteLearningUITests`, #105) und warten auf Feldzustand statt einmal zu lesen
  (Wartezeiten Kachel 15 s, App-Idle nach kaltem Start bis 15 s).
- AC-16: Der Seed- und Clear-Code steht vollständig unter `#if DEBUG`; `xcodebuild -configuration
  Release` baut fehlerfrei; im Release liest `SmartCartApp` die neuen Launch-Argumente nicht.
- AC-17: Alle bestehenden Unit- und UI-Suiten bleiben grün im gemeinsamen Lauf (`xcodebuild test`,
  Scheme `Restock`, deutsch), insbesondere `ReplenishmentPackageCTests`, `QuickAddAssignmentUITests`
  und `ShoppingRouteUITests`.
- AC-18: Stabilität: drei Gesamtläufe der neuen Testklasse in Folge, alle grün (jeweils
  Testzahl > 0, keine Abbrüche, kein Retry-Flag).
- AC-19: Pflicht-Durchlauf: App im Simulator (Stand, den Henning bekommt) mit Seed und
  Entwicklermodus starten, Banner und Ladenliste ansehen und bedienen (`+`, „Hab noch“, „Nicht mehr
  vorschlagen“, „Alle hinzufügen“); Nachweis als registriertes Artefakt (Commit-Kennung und
  Zeitstempel passen zum Stand), nicht von Hand gesetzt.
- AC-20: Umfang: ≤ 5 Dateien; das LoC-Limit (±250) ist mit ca. +330 überschritten, überwiegend Testcode, vom PO am 2026-10-03 ausdrücklich akzeptiert; keine Änderung an Regeln in `HabitService.swift`
  oder `PurchaseRecord.swift`; Schnelleingabe nicht angefasst.

## Tests

| # | Testfall | Art | Prüft |
|---|----------|-----|-------|
| T1 | `testBannerShowsDueItems` (B1) | UI | AC-1, 2, 12 |
| T2 | `testBannerPlusAddsItemToStoreList` (B2) | UI | AC-3 |
| T3 | `testBannerStillHaveItHidesSuggestion` (B3, mit Neustart) | UI | AC-4 |
| T4 | `testBannerBlockSurvivesRestart` (B4) | UI | AC-5 |
| T5 | `testBannerAddAllAddsEverything` (B5) | UI | AC-6 |
| T6 | `testAlsoDueShowsStoreItems` (L1) | UI | AC-7 |
| T7 | `testAlsoDuePlusAddsItem` (L2) | UI | AC-8 |
| T8 | `testAlsoDueStillHaveItHidesSuggestion` (L3) | UI | AC-9 |
| T9 | `testAlsoDueBlockSurvivesRestart` (L4) | UI | AC-10 |
| T10 | `testNothingWithoutDeveloperMode` (N) | UI | AC-11 |
| T11 | tearDown-Prüfung (Folgetest sieht frischen Seed) | UI | AC-14 |
| T12 | Release-Build, `#if DEBUG`-Prüfung | Build | AC-16 |
| T13 | Bestandssuiten gemeinsamer Lauf | UI+Unit | AC-17 |
| T14 | Wiederholung 3x | UI | AC-18 |
| T15 | Durchlauf im Simulator, Artefakt | durch Werkzeug | AC-19 |

TDD: Die Tests werden vor Seed und Identifier geschrieben und scheitern zuerst (RED: Argument
unbekannt, Identifier fehlen); danach Seed und Identifier, Tests grün.

Randbedingungen: Wartezeiten großzügig; Tests laufen auf Deutsch (Scheme pinnt `de`/`DE`); Seeds
räumen in `tearDown()` auf; Simulator nie parallel nutzen, eigenes Testgerät Restock-Validate.

## Risiken

- **Menü-Bedienung (Hauptrisiko):** SwiftUI-`Menu` ist in XCUITest seit iOS 15 heikel — der
  Identifier steht teils nicht auf `app.buttons`, bei Menüs in `List`/`Form` gibt es Tap-Probleme.
  Quellen: https://developer.apple.com/forums/thread/690882 ·
  https://developer.apple.com/forums/thread/760070 · https://developer.apple.com/forums/thread/713900.
  Gegenmaßnahme: früh am echten Simulator prüfen; Reihenfolge der Suche `app.buttons[id]` →
  `app.images[id]` → `app.otherElements[id]`; Fallback Label-Suche („Mehr“/Symbol `xmark.circle`)
  innerhalb der Zeile; Menüpunkt über `app.buttons["Hab noch"]`. Die Ladenliste ist eine `List`
  mit `.buttonStyle(.borderless)` — dort besonders prüfen. Scheitert die Bedienung dort grundsätzlich,
  Rückmeldung mit Schätzung statt Auslassen des Tests.
- **Fälligkeit hängt von `Date()`:** Seed relativ zu jetzt, mittags, mit 1 bzw. 14 Tagen Reserve; das
  Banner-Fenster (2 Tage) und das Listen-Fenster (4 Tage) überlappen so nicht.
- **Kaufhistorie-Zuordnung:** „Vielleicht auch fällig“ erscheint nur im Laden, den
  `AssignmentService.assign` wählt. Die Seed-Käufe tragen den passenden `storeName`; AC-7/AC-3 belegen
  die Zuordnung im echten Lauf. Der Besuchsabstand der Ladenliste (`StoreVisitForecast`) hängt von
  den Seed-Kaufdaten ab (alle Käufe eines Ladens an denselben drei Tagen → Abstand 20 Tage bei den Listen-Artikeln, mind. 3).
- **Zustand außerhalb von SwiftData:** Snoozes, Sperrliste, Feedback und Metrik liegen in
  UserDefaults und überleben den Test → Clear-Argument löscht sie (AC-14); ohne das würden Tests
  einander die Banner-Artikel wegnehmen.
- **App startet ohne Launch-Argumente (#105):** zweiter Start wie in `ShoppingRouteLearningUITests`
  (AC-15); gilt auch für die Neustart-Schritte (Neustart ohne Seed, Entwicklermodus muss erneut per
  `-developerMode YES` übergeben werden).
- **Verspätete Tasten auf dem Runner:** auf Zustand warten, kein einmaliges Lesen.
- **Benachrichtigungen:** `refreshDueSoon` plant bei `notificationsEnabled`; der Seed lässt das
  unverändert (Standard aus), keine Berechtigungsabfrage.
- **Umfang:** Banner + Ladenliste in 10 Tests ist an der Grenze der Limits (5 Dateien, ca. +210 LoC);
  wird es mehr, Rückmeldung mit Schätzung. Kandidat zum Verschieben wäre ein Teil der Ladenlisten-Tests,
  nicht die Schnelleingabe (die ist schon Durchgang 3).

## Alternativen

- **Fälligkeit hart setzen** (UserDefaults oder `dueSoonItems` direkt): verworfen, prüft nur die
  Anzeige, nicht die Kette Kaufhistorie → Fälligkeit (Lehre vom 2026-09-27: Testaufbau, der sich den
  Ausgangszustand selbst herstellt, prüft den halben Weg).
- **Uhr-Offset statt rückdatierter Käufe** (Muster `RouteClock` aus Durchgang 1): gangbar, braucht
  aber mehr Produktcode; rückdatierte Käufe sind einfacher und näher an echten Daten. Kippt keine ADR.
- **Funktion aus dem Entwicklermodus holen:** würde Commit 3e4eb55 („kein Feature der normalen
  Version“) kippen; Produktthema, nicht Teil dieses Durchgangs (Frage an PO, siehe Offene Punkte).
- **Nur Unit-Test für den Neustart der Sperrliste:** verworfen, die Kette Menü → UserDefaults →
  Refresh ist genau die Lücke.
- **Menüpunkte über eigene Identifier statt Label:** möglich, aber die Punkte existieren nur im
  geöffneten Menü; Labels sind durch das deutsche Scheme stabil. Nur falls die Label-Suche im Test
  scheitert, ergänzen.
- **Ein Seed-Laden für beide Oberflächen:** verworfen, Aktionen in einer Oberfläche würden die
  andere beeinflussen (Banner-Artikel erscheint auch in der Ladenliste, „Alle hinzufügen“ nimmt
  alles).
- Gekippte Entscheidung: keine.
- Seed und Clear entfernen zusätzlich die Einklapp-Zustände `replenishmentCollapsed` und `storeReplenishmentCollapsed` (@AppStorage), damit ein eingeklappter Bereich aus einem früheren Lauf die Tests nicht verfälscht (Befund der Prüfung, Runde 1).

## Offene Punkte

- PO: Bleiben Banner und „Vielleicht auch fällig“ bewusst im Entwicklermodus? (Die Tests laufen so
  oder so mit `-developerMode YES`; die Negativ-Kontrolle hält den heutigen Stand fest und müsste bei
  einer Änderung angepasst werden.)
- PO: Schnelleingabe als Durchgang 3 von #98 — im Ticket festhalten (Inhalt: Artikel landet nach
  Return in der Ladenliste, „Laden ändern“ im Toast mit gemerkter Korrektur, Mengen-Anzeige in der
  Liste).
- Nach Abschluss: Verweis auf die neuen DEBUG-Argumente in `CLAUDE.md` (Abschnitt Build/UI-Tests),
  falls das Limit es erlaubt, sonst im Folgedurchgang.
