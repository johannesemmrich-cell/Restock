# Adversary Dialog — test-98-durchgang-8-siri-widget
Spec: docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md
Datum: 2026-10-14 16:12

## Checkliste
- [x] **AC-1:** `CheckoffQueue` in einer Datei für App- und Widget-Ziel; Kopien in Widget und `StoreDetailView.applyPendingCheckoffs` entfernt; beide Ziele bauen, die Abhak-Schleife (`markCompleted()` + `recordCheckOff(…batched`) steht nur in `CheckoffQueue.swift`.
- [x] **AC-2:** Q1: `drain` hakt genau die gequeueten UUIDs ab, in Queue-Reihenfolge, mit `PurchaseRecord` und Einkaufswegeintrag (`batched`); übrige Artikel bleiben offen.
- [x] **AC-3:** Q2: Doppelte, bereits erledigte und unbekannte UUIDs ergeben keine zweite Buchung und keinen Absturz.
- [x] **AC-4:** Q3: `effectivePending` stimmt vor dem `drain` mit dem Stand überein, den die App nach dem `drain` zeigt.
- [x] **AC-5:** Q4: Der Legacy-Zähler wird berücksichtigt und anschließend gelöscht.
- [x] **AC-6:** Q5/Q6: Die Warteschlange ist je Laden getrennt; `enqueue` schreibt nur den eigenen Schlüssel.
- [x] **AC-7:** A1–A3: `AddShoppingItemIntent.add` ordnet über den echten `AssignmentService` zu und legt Menge, Einheit und Laden korrekt an; ohne Laden `store == nil`.
- [x] **AC-8:** A4: Ist-Verhalten (keine Duplikatprüfung, kein Mengenvorschlag) durch Tests festgehalten und als Ist, nicht als Beschluss, kommentiert.
- [x] **AC-9:** UI-Test Schnell-hinzufügen: Mit Merker fokussiertes Feld; Merker danach verbraucht; ohne Merker kein Fokus. Startargument nur unter `#if DEBUG`.
- [x] **AC-10:** Mutationsprobe: Q1 und Q2 schlagen fehl, wenn `!item.isCompleted`-Schutz bzw. `recordCheckOff` entfernt wird; Ausgaben unter `docs/artifacts/test-98-durchgang-8-siri-widget/`. UI-Gegenprobe ohne Argument beweist, dass der Test nicht leer läuft.
- [x] **AC-11:** Echter Weg statt Nachbau: Tests rufen `CheckoffQueue` und `AddShoppingItemIntent.add`, echte Modelle, echten `AssignmentService`; Queue-Schlüssel nur über `enqueue` in eigener Suite.
- [-] **AC-12:** Aufräumen (eigene Suite je Test, UI-Test räumt auf: belegt); Bestandssuiten im gemeinsamen Lauf grün — offen bis Phase 7, nicht Defekt der Implementierung.
- [-] **AC-13:** Stabilität (feste Zeit, keine Wartezeiten, drei Läufe grün: new-classes-run1-3 belegt); UI-Test zusätzlich unter Last — offen bis Phase 7, nicht Defekt der Implementierung.
- [x] **AC-14:** Umfang: 10 Dateien, +399/-122 = 521 Zeilen (Spec ±500; erweiterte PO-Ausnahme 2026-10-14 bis 11 Dateien/ca. 700, docs/context Zeile 99-100); Produktcode nur Auslagerung, `add`, DEBUG-Argument.
- [-] **AC-15:** Pflicht-Durchlauf als registriertes Werkzeug-Artefakt — offen bis Phase 7, nicht Defekt der Implementierung.
- [-] **AC-16:** Offene Grenzen in Spec, Testkopfkommentaren und `CLAUDE.md` benannt (belegt); Ticketkommentar von #98 — offen bis Phase 7, nicht Defekt der Implementierung.
- [x] **AC-17:** Hennings Geräte: Kein Schritt startet, installiert oder liest ein Gerät des Users; alle Läufe nur im Simulator Restock-Validate bzw. im Unit-Test-Host.

## Dialog

### Runde 1
**Adversary:** Alle Dateien selbst gelesen, nichts aus dem Implementiererbericht übernommen.

Code reference: SmartCart/Models/CheckoffQueue.swift:64
Code reference: SmartCart/Views/Store/StoreDetailView.swift:1206
Code reference: SmartCartWidgets/ShoppingListWidget.swift:24
Code reference: SmartCart/Intents/CheckOffItemIntent.swift:35
Code reference: SmartCart/Intents/AddItemIntent.swift:41
Code reference: SmartCart/SmartCartApp.swift:197

1. Verhaltensgleichheit: Diffs von StoreDetailView, ShoppingListWidget und CheckOffItemIntent gegen origin/main gelesen. `drain` ist Zeile für Zeile der alte Rumpf (UUID-Queue zuerst, `removeObject` vor der Schleife, `!item.isCompleted`-Schutz, `markCompleted()` + `recordCheckOff(batched: true)`, danach Legacy-Zähler über `pendingItems.first`). Neu ist nur der Rückgabewert `applied` (vorher lokale Variable in der App, im Widget ungenutzt, jetzt `@discardableResult`). `effectivePending` ist wortgleich. Speichern und `LiveActivityService.update` bleiben beim Aufrufer (`guard applied > 0` in StoreDetailView). Das Widget-Intent ruft `drain` und speichert wie zuvor. Die App nutzte vorher ein Literal für die App-Gruppe, jetzt `SharedModelContainer.appGroupID`: gleicher Wert `group.com.johannesemmrich.SmartCart`.
2. Einzige Schleife: grep nach `recordCheckOff`/`markCompleted()` in SmartCart und SmartCartWidgets. Die Batched-Variante steht nur in CheckoffQueue.swift:80 und :94; übrige Treffer sind Einzelhaken ohne `batched` (StoreDetailView:1170, EditItemView, Widget-Intent:132) und gehören nicht zur Warteschlange. AC-1 hält.
3. Ziele: pbxproj enthält zwei Build-Einträge für CheckoffQueue.swift (App- und Widget-Sources). Der Testlauf baute `SmartCartWidgets.appex` mit.
4. DEBUG: Beide neuen Funktionen werden nur im `#if DEBUG`-Block des `defer` aufgerufen und liegen im DEBUG-Bereich (ab Zeile 166 bis 730). Im Release nicht kompiliert. Reihenfolge clear vor set: setzt ein Test beides, gewinnt der Merker.
5. Produktänderung in `add`: Laden-Fetch war `try` (Abbruch von `perform()`), jetzt `try?`; bei Fehler entsteht der Artikel ohne Laden. Kommentiert, praktisch nicht auftretend (F001, LOW).
6. Testqualität: Q1 prüft Queue-Reihenfolge über `currentTrip.entries` (käse vor milch) und `batched`; Q2 prüft Zählung und Kaufdatensätze. Mutation 1 (ohne `isCompleted`-Schutz) lässt Q2 mit 3 Assertions scheitern, Mutation 2 (ohne `recordCheckOff`) lässt Q1 am Einkaufsweg scheitern; beide Ausgaben im Artefaktordner. Unit-Tests nutzen `UT-CheckoffQueue-<UUID>`, löschen die Suite und prüfen Reste; der Einkaufsweg wird über `removeRouteData()` entfernt. Der UI-Test räumt in `tearDown` mit beiden Clear-Argumenten auf; die Gegenprobe ohne Merker beweist, dass der Fokus-Test nicht leer läuft.

Ergebnis Runde 1: kein Defekt, aber alles hält auf Anhieb, deshalb Runde 2 mit eigenem Neulauf.

**Implementierer:** Keine Änderung nötig.

### Runde 2
**Adversary:** Eigener Neulauf statt Vertrauen in vorhandene Ausgaben: `xcodebuild test` auf Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7), nur CheckoffQueueTests (6), AddItemIntentTests (6), QuickAddControlUITests (2), Ausgabe `adversary-run.txt`: 14 Tests, 0 Fehler, 0 übersprungen, `** TEST SUCCEEDED **`. Widget-Ziel mit gebaut.

Code reference: SmartCart/Models/CheckoffQueue.swift:73
Code reference: SmartCartWidgets/ShoppingListWidget.swift:121

- Abbruch mitten im Drain: `removeObject` vor der Schleife heißt, ein Prozessende in der Schleife verliert den Rest. Identisch zum Altcode, keine Regression; Mikro-Lücke ist im Kommentar benannt.
- UUID-Queue plus Legacy-Zähler zugleich: `drain` und `effectivePending` ziehen in gleicher Reihenfolge (erst UUIDs, dann `dropFirst(legacy)`). Q3/Q4 testen sie nur einzeln (F002, LOW, Testlücke, kein Verhaltensfehler).
- Q5 (Trennung je Laden) und Q6 (nur eigener Schlüssel) sind echte Prüfungen: `drain(b)` lässt a unberührt, die Schlüsselmenge wird exakt verglichen.
- AC-14: Diffstat gegen origin/main ohne docs: 10 Dateien, +399/-122 = 521 Zeilen, knapp über dem Spec-Text, gedeckt durch die erweiterte PO-Ausnahme (docs/context). Produktcode außerhalb Auslagerung, `add` und DEBUG-Argument unverändert.
- AC-17: Läufe nur auf Restock-Validate und im Testhost, auch mein Neulauf. Kein Gerät angesprochen.
- Offen bis Phase 7, nicht Defekt der Implementierung: AC-12 (gesamte UI-Suite im gemeinsamen Lauf), AC-13 (UI-Test unter Last), AC-15 (Pflicht-Durchlauf als Werkzeug-Artefakt), AC-16 (Ticketkommentar in #98).

**Implementierer:** Keine Änderung nötig; F001 und F002 als Hinweise akzeptiert.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Intents/AddItemIntent.swift:47
  Description: Der Laden-Fetch in `add` ist `try?`; bei Fehler entsteht der Artikel ohne Laden statt Abbruch von `perform()`.
  Spec requirement: AC-7 — Zuordnung über AssignmentService, ohne Laden `store == nil`
  Conflict: Kleine Verhaltensänderung bei einem praktisch nicht auftretenden Fehler, kommentiert; kein Spec-Verstoß.
  Remediation: Keine nötig; im Ticketkommentar erwähnen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/CheckoffQueue.swift:43
  Description: Die Kombination UUID-Queue plus Legacy-Zähler gleichzeitig ist nicht durch einen Test abgedeckt.
  Spec requirement: AC-5 — Legacy-Zähler wird berücksichtigt und gelöscht
  Conflict: Einzelfall getestet (Q4), Verhalten identisch zum Altcode; nur Testlücke.
  Remediation: Optional ein Test Q7.

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Models/CheckoffQueue.swift:80
  Evidence: Batched-Schleife nur hier (grep), beide Ziele bauen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/SmartCartApp.swift:203
  Evidence: Argument nur im DEBUG-Block; UI-Test mit Merker und Gegenprobe grün im Neulauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Intents/AddItemIntent.swift:41
  Evidence: `add` nutzt den echten AssignmentService; A1–A4 grün im Neulauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCartWidgets/ShoppingListWidget.swift:121
  Evidence: Widget-Intent ruft dasselbe `CheckoffQueue.drain`; Q2 mit Mutation 1 rot.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Nebenbefund `pendingQuickAdd`: Produktionsschreiber ist das Control (`QuickAddControlIntent`). Bedingung davor: Nutzer tippt den Knopf im Control Center. Test für diesen Weg: keiner im Simulator möglich (offene Grenze); Lese- und Verbrauchsweg prüft `QuickAddControlUITests` über das DEBUG-Argument.

## Verdict: VERIFIED
Kein Defekt gefunden. Tests: 14 neu gelaufen, 0 Fehler, 0 übersprungen (Vorlauf 498 Unit-Tests grün). Offen bis Phase 7, nicht Defekt der Implementierung: AC-12, AC-13 (Last), AC-15, AC-16.

## Geprüfte Dateien

- sha256:ff2e4dbcc6d820dccc9febdef6de3ff2f8e869b4314f201be8c1c2ad9baeeeda  SmartCart/Intents/AddItemIntent.swift
- sha256:29567b3388c681089ba9248edd6719678b33a8a34d11e27008d002d44ed0eb8f  SmartCart/Intents/CheckOffItemIntent.swift
- sha256:a5de405fbb06924af8bdd25957909a2c91e32264a13e48494aaf4e68fc04b25c  SmartCart/Models/CheckoffQueue.swift
- sha256:9a69123682afdbde68e031bbd7aaa8344b4a502fe46556b8eb0527199f7daf29  SmartCart/SmartCartApp.swift
- sha256:ad9d5de2e5bbf6e2660c07fd8141d7e665d00cb523fb96c56dc036642529ef24  SmartCart/Views/Store/StoreDetailView.swift
- sha256:5a02301910083d6468b307c30c9bd2c9124de5ffd1389562406cb0bfc80ce523  SmartCartWidgets/ShoppingListWidget.swift

## Prüfbasis

- base: f0be715e5876d93e7ceddf4870bb623a7da30a1e
- blob:2517efe7569a059212109d54236917531a68a386  SmartCart/Intents/AddItemIntent.swift
- blob:86fd5502c82c6badeccec4876f9e206a0d3416fe  SmartCart/Intents/CheckOffItemIntent.swift
- blob:8945956891c3e568cece7dde44b8499d69798597  SmartCart/Models/CheckoffQueue.swift
- blob:54f3a3b90bf16712f44d4498bb920da7d14ea7ed  SmartCart/SmartCartApp.swift
- blob:760ef5784f272ce989ef53c9ccf1aa65d75fae99  SmartCart/Views/Store/StoreDetailView.swift
- blob:56c5d72ec701e788d7cdbe270e630228f960a2aa  SmartCartWidgets/ShoppingListWidget.swift
