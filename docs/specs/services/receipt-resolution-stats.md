---
entity_id: receipt-resolution-stats
type: feature
created: 2026-10-02
updated: 2026-10-02
status: draft
version: "1.0"
workflow: bon-namenserkennung-regelwerk-14
tags: [feature, receipt, measurement, dev-mode, issue-14]
---

# Bon-Auflösung: Messung je Stufe (Issue #14, Teil „Messung zuerst“)

## Approval

- [ ] Approved

## Purpose

Die Namensauflösung einer Bon-Zeile (`ReceiptResolutionService.resolve`) läuft in sechs Stufen
(Alias, Wörterbuch, abgehakte Artikel, Kaufhistorie, Apple Intelligence, Rohtext). Heute weiß
niemand, wie oft welche Stufe greift und wie oft der Nutzer ihr Ergebnis im Review korrigiert. Ohne
diese Nulllinie lässt sich nicht entscheiden, ob ein Regel-Hebel (Wörterbuch ausbauen,
ladenübergreifender Abgleich) oder die KI-Stufe etwas bringt. Diese Spec baut nur die Messung:

1. Jede aufgelöste Zeile trägt die Stufe, die ihren Namen bestimmt hat.
2. Beim Speichern eines Bons zählt ein lokaler Zähler je Stufe: Zeilen gesamt, vom Nutzer
   geänderte, abgewählte (nur Zahlen, keine Namen, keine Preise).
3. Ein eigener Entwickler-Bildschirm „Bon-Auflösung“ zeigt die Zahlen je Stufe.

**Das Auflösungsverhalten bleibt unverändert.** Kein Schwellenwert, keine Stufenreihenfolge, kein
Prompt, keine Auswahl im Review ändert sich. Freigegeben ist Variante A des Entwurfs
(`docs/artifacts/bon-namenserkennung-regelwerk-14/entwurf.html`, Henning 2026-10-02): eigener
Bildschirm im Entwicklermodus, alle Stufen einzeln, Zurücksetzen-Knopf.

Die Regel-Spalte (Stufen 1-4, 6) ist im Simulator messbar. Stufe 5 (KI) läuft dort nicht (Apple
Intelligence nicht verfügbar) und wird nur auf einem Gerät mit Apple Intelligence gezählt.

## Source

- **File:** `SmartCart/Services/ReceiptResolutionService.swift` (Stufe je Zeile setzen)
- **File (neu):** `SmartCart/Services/ReceiptResolutionStats.swift` (Zähler)
- **File (neu):** `SmartCart/Views/Settings/ReceiptResolutionStatsView.swift` (Dev-Bildschirm)
- **Aufrufstelle Zählung:** `ReceiptScannerView.save()` (`SmartCart/Views/Prices/ReceiptScannerView.swift`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ReceiptResolutionService.resolve` | function | Setzt die Stufe je Zeile; Verhalten unverändert. |
| `ResolvedReceiptLine` | struct (Codable) | Bekommt `stage`; Teil des Wire-Formats der Share Extension (`SharedReceiptPayload.lines`). |
| `EditableReceiptLine` (`ReceiptScannerView.swift`) | struct | Bekommt `stage` und `resolvedName` als Messgrundlage in `save()`. |
| `ReceiptScannerView.save()` | function | Einziger Zählpunkt (Nutzer hat bestätigt). |
| `SharedModelContainer.appGroupID` | constant | App-Gruppen-Suite für den Zähler (Muster `ReceiptAliasService`). |
| `SettingsView` (Dev-Abschnitt, `if developerMode`) | view | Link zum Bildschirm. |
| `ReplenishmentStatsView` / `ReplenishmentMetrics` | view / struct | Vorbild für Aufbau, Zurücksetzen mit Bestätigung, UserDefaults-Zähler. |
| `.devFeedback(context:)` | view modifier | Pflicht auf jedem Vollbild-Screen. |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptResolutionService.swift` | MODIFY | Enum `ReceiptResolutionStage` (neben `ResolvedReceiptLine`, damit auch das Share-Extension-Target es sieht); Feld `stage` in `ResolvedReceiptLine`; `resolve` merkt die Stufe je Index und gibt sie mit. |
| `SmartCart/Services/ReceiptResolutionStats.swift` | CREATE (+pbxproj) | Zähler in der App-Gruppe: reine Zähl-Funktion + Persistenz + Zurücksetzen. |
| `SmartCart/Views/Settings/ReceiptResolutionStatsView.swift` | CREATE (+pbxproj) | Dev-Bildschirm „Bon-Auflösung“. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `EditableReceiptLine.stage`/`resolvedName`; an den drei Konstruktionsstellen (Share-Handoff-Init ca. :229, `process()` ca. :619, `mergeAIReresolution` ca. :151) befüllen; `save()` ruft den Zähler. |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | `NavigationLink` im Dev-Abschnitt, direkt unter „Nachkauf-Statistik“. |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-only: `stage` in den Zeilen des Seeds `-seedReceiptReviewForUITests`; neues Aufräum-Argument `-clearReceiptResolutionStatsForUITests`. |
| `RestockTests/ReceiptResolutionStatsTests.swift` | CREATE (+pbxproj) | Unit-Tests. |
| `RestockUITests/ReceiptResolutionStatsUITests.swift` | CREATE (+pbxproj) | UI-Test des echten Durchlaufs. |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung der vier neuen Swift-Dateien (siehe unten). |

### pbxproj-Registrierung (Pflicht, Xcode entdeckt Dateien nicht selbst)

Alle vier neuen `.swift`-Dateien werden in je vier Abschnitten eingetragen (`PBXBuildFile`,
`PBXFileReference`, `PBXGroup`-Kinderliste, `PBXSourcesBuildPhase`), mit 24-stelligen, im Projekt
noch nicht vergebenen Hex-UUIDs:
- `ReceiptResolutionStats.swift` → Gruppe `Services`, Target `Restock` (nur App; die Share Extension zählt nicht).
- `ReceiptResolutionStatsView.swift` → Gruppe `Settings` (unter `Views`), Target `Restock`.
- `ReceiptResolutionStatsTests.swift` → Gruppe `RestockTests`, Target `RestockTests`.
- `ReceiptResolutionStatsUITests.swift` → Gruppe `RestockUITests`, Target `RestockUITests`.

`ReceiptResolutionStage` bleibt bewusst in `ReceiptResolutionService.swift`, das bereits im Target
der Share Extension liegt — eine neue Datei dort würde eine fünfte pbxproj-Registrierung in einem
weiteren Target nötig machen.

### Estimated Changes
- Dateien: 9 (4 neu, 4 geändert Produktivcode/Test-Seed, plus pbxproj). Das überschreitet die
  Grenze von 4-5 Dateien; die Überschreitung ist reine Registrierung und Testcode, der
  Produktivcode berührt 5 Dateien (ohne pbxproj, Seed und Tests).
- LoC: ca. +300 (Produktivcode ca. +170, Tests ca. +130). Überschreitet die ±250-LoC-Grenze, weil
  die Tests nach dem LoC-Gate als Produktivcode zählen (siehe Memory „LoC-Gate zählt Testcode“).
  Sollte das Gate blockieren: grünen Zwischenstand sichern und in zwei Teile trennen —
  Teil 1 Stufe + Zähler + Unit-Tests, Teil 2 Dev-Bildschirm + UI-Test. Nicht das Limit anheben.
- Risiko: niedrig (nur zählen; `resolve` liefert dieselben Namen, Auswahlen, IDs wie vorher).

### Out of Scope (Nicht-Ziele)

- **#89** ladenübergreifende Auto-Übernahme (kippt die bewusste Entscheidung in `historyMatch`).
- **#90** Nicht-Produkt-Regel im Filter statt im Prompt (`KEIN_PRODUKT`).
- **#91** Wörterbuch aus Korrekturen speisen / erweitern.
- Jede Änderung an Schwellen (`completedItemAutoApplyThreshold`, 0,6), Stufenreihenfolge,
  `lcsSimilarity`, `expandAbbreviations`, Prompt oder Timeout von Stufe 5.
- Ein Korpus-Messlauf mit anonymisierten Echtbons im Test-Target (spätere Ergänzung).
- Auswertung/Diagramme, Export, Übertragung der Zahlen aus dem Gerät (kein Netz, kein CloudKit).
- Zählung in der Share Extension (sie speichert nichts; gezählt wird erst in der App beim Speichern).
- Unterscheidung „Modell antwortet KEIN_PRODUKT“ von „Modell nicht verfügbar/Timeout“ (siehe unten, Stufe `nonProduct`).

## Implementation Details

### 1. Stufe je Zeile (`ReceiptResolutionService.swift`)

```swift
enum ReceiptResolutionStage: String, Codable, CaseIterable {
    case alias, dictionary, completed, history, ai, rawText, nonProduct
}
```

Deutsche Anzeigenamen (nur im Dev-Bildschirm, über `String(localized:)`): Alias, Wörterbuch,
Abgehakt, Historie, KI, Rohtext, Nicht-Produkt.

- `ResolvedReceiptLine` bekommt `var stage: ReceiptResolutionStage? = nil`. **Optional**, weil die
  vom Compiler erzeugte `Decodable`-Konformität Standardwerte nicht für fehlende Schlüssel nutzt:
  ein nicht-optionales Feld ohne eigenen `init(from:)` würde einen Alt-Payload der Share Extension
  (ohne `stage`) mit `keyNotFound` scheitern lassen. Optionale Felder werden mit `decodeIfPresent`
  decodiert; `nil` heißt „Stufe unbekannt“ und wird nicht gezählt (siehe Zählregeln). Die
  memberwise `init`-Aufrufe in `SmartCartApp.swift` (Seeds) bleiben ohne Änderung übersetzbar.
- In `resolve` wird in der `MainActor.run`-Schleife parallel zu `resolvedNames` ein
  `stages: [Int: ReceiptResolutionStage]` gefüllt, in genau den Zweigen der bestehenden
  `if/else if`-Kette: Alias → `.alias`, `expandAbbreviations` → `.dictionary`, abgehakter Artikel →
  `.completed`, `historyMatch` → `.history`; der `else`-Zweig (`needsAI.append`) setzt noch nichts.
  Nach dem KI-Block: Index in `aiResolvedIndices` → `.ai`; jeder Index ohne Eintrag → `.rawText`.
  Die nachgelagerte `matchedItemIDs`-Fallback-Prüfung ändert die Stufe **nicht** (sie liefert nur
  die Verknüpfung, nicht den Namen).
- Der Rückgabewert von `resolve` bleibt `[ResolvedReceiptLine]`; die Namen/IDs/Vorschläge sind
  bitgleich mit dem Stand vor der Änderung.
- **Stufe `nonProduct`:** Der Fall ist als Fall definiert und im Zähler/Bildschirm vorhanden, wird
  aber in diesem Ticket **nicht** vom Resolver gesetzt. Grund: `ReceiptNameAIResolver.sanitize`
  gibt für `KEIN_PRODUKT` `nil` zurück, und `expand` gibt dasselbe `nil` auch bei Timeout oder
  nicht verfügbarer KI zurück — die beiden Fälle sind am Aufrufer nicht unterscheidbar, ohne
  `ReceiptParserService.swift` (Rückgabetyp von `expand`) zu ändern. Das gehört zu #90. Bis dahin
  landen solche Zeilen in `.rawText`, und ihr Abwählen steht in der Spalte „Abgewählt“ der Stufe
  Rohtext. Der Bildschirm zeigt die Zeile „Nicht-Produkt“ trotzdem (immer 0) mit einer
  Fußnote, damit die Stufenliste vollständig und der Nachfolger anschlussfähig ist.

### 2. Lokaler Zähler (`ReceiptResolutionStats.swift`)

Struktur nach Muster `ReplenishmentMetrics`: injizierbare `UserDefaults`-Suite (Standard:
`UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard`), ein Schlüssel
`smartcart.receiptResolutionStats.v1`, Wert ein JSON-Wörterbuch `[stage.rawValue: {total, changed,
deselected}]` (drei `Int`). Gespeichert werden ausschließlich diese Zahlen.

```swift
struct ReceiptResolutionStats {
    struct Counts: Codable, Equatable { var total = 0, changed = 0, deselected = 0 }
    init(defaults: UserDefaults = …)
    func counts(for stage: ReceiptResolutionStage) -> Counts   // 0/0/0 wenn nie gezählt
    func record(_ lines: [EditableReceiptLine])                // zählt und persistiert
    func reset()
    static func tally(_ lines: [EditableReceiptLine]) -> [ReceiptResolutionStage: Counts]  // rein, ohne I/O
}
```

Zählregeln (`tally`, je Zeile mit `stage != nil`; Zeilen mit `stage == nil` werden übersprungen):
- `total` +1 für jede Zeile des Bons, auch für abgewählte.
- `deselected` +1, wenn `isIncluded == false`. Eine abgewählte Zeile zählt nie als `changed`.
- `changed` +1, wenn `isIncluded == true` **und** der finale Name nach Trimmen von Leerzeichen und
  ohne Beachtung von Groß-/Kleinschreibung vom `resolvedName` (Name unmittelbar nach der
  Auflösung) abweicht. Preis- und Mengenänderungen zählen nicht, ebenso wenig der Wechsel
  zwischen Namensoptionen, die zum gleichen Namen führen.
- Invariante je Stufe: `changed + deselected <= total`.
- Die Stufe einer Zeile ist die beim Öffnen des Reviews gesetzte; sie bleibt, auch wenn der Nutzer
  danach einen Vorschlags-Chip antippt oder frei tippt (genau das ist `changed`).

`EditableReceiptLine` bekommt `var stage: ReceiptResolutionStage? = nil` und
`var resolvedName: String = ""`. Befüllung an den drei Stellen:
- `process()` (Zeile aus frisch aufgelöstem `ResolvedReceiptLine`): `stage = line.stage`,
  `resolvedName = line.name`.
- Share-Handoff-Init: dasselbe aus `prefilled.lines`; Zeilen aus Alt-Payloads haben `stage == nil`.
- `mergeAIReresolution` (nachträgliche KI-Auflösung im Handoff-Pfad): `stage = r.stage`,
  `resolvedName = r.name` an den ausgewählten Indizes, alle anderen Zeilen unangetastet.
  (Hat die Handoff-Zeile vorher den Stand „Rohtext“ gehabt, überschreibt die neue Auflösung ihn
  mit der dann tatsächlichen Stufe; die Zeile wird nur einmal, beim Speichern, gezählt.)

`save()` ruft einmal am Anfang, vor der Schleife über `included`, `ReceiptResolutionStats().record(parsedLines)`
mit **allen** Zeilen (nicht nur `included`), weil `deselected` die abgewählten Zeilen braucht. Die
Zeilen werden vor `ReceiptAliasService.learn` bewertet; die weitere Logik von `save()` bleibt
unverändert. Ein Bon, der nicht gespeichert wird (Abbruch), zählt nicht.

### 3. Dev-Bildschirm (`ReceiptResolutionStatsView.swift`)

`List` im Stil der Nachkauf-Statistik, Titel „Bon-Auflösung“ (`.navigationTitle`),
`.devFeedback(context: "Bon-Auflösung")` auf dem äußersten View.
- Ein Abschnitt je Gruppe: Kopfzeile erklärt die Spalten. Eine Zeile je `ReceiptResolutionStage`
  (alle sieben, Reihenfolge wie im Enum): Name der Stufe, rechts „Zeilen gesamt“, „Geändert“
  (mit Prozent von gesamt, sonst „–“ bei gesamt = 0) und „Abgewählt“ (mit Prozent). Jede Zeile
  trägt die Accessibility-Identifier `resolutionStage.<rawValue>` (Zeile) und
  `resolutionStage.<rawValue>.total` / `.changed` / `.deselected` (Werte), weil die UI-Tests des
  Projekts sonst nur an angezeigtem Text hängen.
- Eine Summenzeile „Alle Stufen“ (`resolutionStage.all.total` etc.).
- Fußnote: „Gezählt beim Speichern eines Bons, nur Zahlen. Stufe KI läuft nur auf Geräten mit Apple
  Intelligence. Nicht-Produkt wird noch nicht unterschieden (siehe #90).“
- Knopf „Zurücksetzen“ (`role: .destructive`, Identifier `resolutionStatsResetButton`) mit
  `confirmationDialog`; nach Bestätigung `ReceiptResolutionStats().reset()` und die Zahlen
  zeichnen neu (State-Zähler wie `metricsVersion` in `ReplenishmentStatsView`).
- Erreichbar nur über `SettingsView`: im bestehenden `if developerMode { Section { … } }` ein
  `NavigationLink { ReceiptResolutionStatsView() } label: { Label("Bon-Auflösung", systemImage: "doc.text.magnifyingglass") }`
  unter „Nachkauf-Statistik“. Außerhalb des Entwicklermodus gibt es keinen Zugang.
- Alle sichtbaren Texte über `String(localized:)` bzw. `Text`/`Label` mit Literal wie im Rest der Datei.
- Design: bestehende Tokens (`Color.surface`, `Color.ink`, `Color.brand`), keine neuen Farben.

### 4. Test-Aufräumen (CLAUDE.md-Regel für Seeds)

Der Zähler liegt im App-Gruppen-Container und überlebt einen Testlauf. Die UI-Tests (siehe unten)
räumen deshalb in `tearDown()` über das neue DEBUG-Argument
`-clearReceiptResolutionStatsForUITests` auf (`SmartCartApp.swift`, ruft
`ReceiptResolutionStats().reset()`), zusätzlich zum bestehenden `-clearReceiptReviewSeedForUITests`.
Ohne das würden die Zahlen anderer Läufe in die Erwartungswerte hineinragen.

## Acceptance Criteria

- AC-1: `ReceiptResolutionStage` hat genau die sieben Fälle alias, dictionary, completed, history, ai, rawText, nonProduct und ist `Codable` (Rohwert String).
- AC-2: `resolve` setzt `stage = .alias` für eine Zeile, die ein gelernter Alias auflöst, `.dictionary` für eine über `expandAbbreviations` aufgelöste, `.completed` für eine per Auto-Übernahme gegen einen abgehakten Artikel aufgelöste, `.history` für eine per `historyMatch` aufgelöste (Unit-Tests, je ein Fall).
- AC-3: Eine Zeile ohne Treffer in Stufe 1-4 hat bei nicht verfügbarer KI (`allowAIResolution: false`) `stage == .rawText` und unveränderten Namen.
- AC-4: Eine Zeile, die Stufe 5 aufgelöst hat (`resolvedByAI == true`), hat `stage == .ai`; Zeilen mit `resolvedByAI == true` haben nie eine andere Stufe (nur auf einem Gerät mit Apple Intelligence prüfbar; im Simulator über die reine Tally-Logik mit `stage: .ai` abgedeckt).
- AC-5: Das Auflösungsverhalten ist unverändert: für jede Eingabe der bestehenden Tests (`ReceiptAbbreviationExpansionTests`, `ReceiptHistoryMatchTests`, `ReceiptKnownItemNamesTests`, `ReceiptNameAIResolverSanitizeTests`, `ReceiptParserSuggestionTests`) bleiben diese grün, und `resolve` liefert für einen Vergleichssatz dieselben `name`, `matchedItemID` und `suggestions` wie vor der Änderung.
- AC-6: Ein JSON-Payload im Format vor dieser Änderung (Zeile ohne Schlüssel `stage`) lässt sich als `ResolvedReceiptLine` decodieren und liefert `stage == nil`; ein Payload mit `stage` decodiert den Wert und codiert ihn beim Rückweg wieder aus (Round-Trip).
- AC-7: `tally` zählt je Zeile mit `stage != nil` genau einmal `total` bei der Stufe der Zeile; Zeilen mit `stage == nil` werden nicht gezählt.
- AC-8: `tally` zählt `changed` nur für eingeschlossene Zeilen, deren finaler Name sich vom `resolvedName` nach Trimmen und ohne Groß-/Kleinschreibung unterscheidet; unveränderte, nur in Groß-/Kleinschreibung oder Leerzeichen geänderte, Preis- und Mengenänderungen zählen nicht.
- AC-9: `tally` zählt abgewählte Zeilen (`isIncluded == false`) als `deselected` und `total`, nie als `changed`; je Stufe gilt `changed + deselected <= total`.
- AC-10: `record` addiert auf bereits gespeicherte Werte (zwei Bons ergeben die Summe) und liest sie nach erneutem Erzeugen von `ReceiptResolutionStats` mit derselben Suite unverändert zurück.
- AC-11: `reset()` setzt alle Zähler auf 0; `counts(for:)` liefert für nie gezählte Stufen `Counts()` (0/0/0).
- AC-12: Im gespeicherten Wert stehen ausschließlich Stufenschlüssel und Ganzzahlen: kein Zeilenname, kein Rohtext, kein Preis (Test liest den rohen Wert aus der Suite und prüft, dass er nach dem Zählen einer Zeile mit eindeutigem Namen diesen Namen nicht enthält).
- AC-13: `ReceiptScannerView.save()` ruft `record` genau einmal pro Speichern mit allen Zeilen des Bons (auch abgewählten); ein abgebrochener Scan (kein Speichern) verändert den Zähler nicht.
- AC-14: `EditableReceiptLine.stage`/`resolvedName` werden in `process()`, im Share-Handoff-Init und in `mergeAIReresolution` gesetzt; `mergeAIReresolution` ändert Zeilen außerhalb der übergebenen Indizes nicht (bestehende Tests grün, ein neuer Test für Stufe/`resolvedName`).
- AC-15: In `SettingsView` erscheint der Link „Bon-Auflösung“ nur bei `developerMode == true`, direkt unter „Nachkauf-Statistik“.
- AC-16: Der Bildschirm zeigt sieben Stufenzeilen (Identifier `resolutionStage.<rawValue>`), je mit Werten für gesamt, geändert und abgewählt, plus Summenzeile „Alle Stufen“, die der Summe der Stufen entspricht.
- AC-17: Der Bildschirm hat `.devFeedback(context: "Bon-Auflösung")` und einen Zurücksetzen-Knopf mit Bestätigung; nach Bestätigung zeigen alle Werte 0, nach „Abbrechen“ bleiben sie.
- AC-18: Echter Durchlauf (UI-Test): Seed `-seedReceiptReviewForUITests` öffnen, Bon speichern, im Entwicklermodus Einstellungen → „Bon-Auflösung“ öffnen: die Summenzeile zeigt die Zeilenzahl des Seeds, die Stufe der Seed-Zeilen zeigt ihren Zähler, und die UI-Test-Aufräumung (`-clearReceiptResolutionStatsForUITests`) entfernt sie wieder.
- AC-19: Die Gesamtsuite (Unit- und UI-Tests) bleibt im gemeinsamen Lauf grün; nach dem Aufräumen des neuen UI-Tests liegen keine Zählerwerte im App-Gruppen-Speicher.
- AC-20: `RestockTests/ReceiptResolutionStatsTests.swift`, `ReceiptResolutionStatsUITests.swift` und die zwei neuen Produktivdateien sind in `project.pbxproj` in allen vier Abschnitten eingetragen; `xcodebuild` kompiliert Haupt-App, Share Extension und beide Test-Targets ohne Fehler.

## Test Plan

### Unit-Tests (`RestockTests/ReceiptResolutionStatsTests.swift`, TDD RED zuerst)

Eigene `UserDefaults(suiteName:)` je Test (UUID im Namen) und `removePersistentDomain` in `tearDown`,
damit der App-Gruppen-Speicher unberührt bleibt.
1. Stufe Alias/Wörterbuch/Abgehakt/Historie je ein `resolve`-Aufruf mit passenden Daten (Alias über
   `ReceiptAliasService.shared.learn` mit Aufräumen am Ende, Wörterbuch über ein bekanntes Kürzel
   aus `ReceiptParserService.expandAbbreviations`, abgehakter Artikel/Historie als in-memory
   SwiftData-Container) → AC-2.
2. Zeile ohne Treffer, `allowAIResolution: false` → `.rawText`, Name = Rohtext → AC-3.
3. Alt-Payload-JSON ohne `stage` decodiert, `stage == nil`; Round-Trip mit `stage` → AC-6.
4. Vergleichssatz `resolve` (Namen, `matchedItemID`, Vorschläge) gegen feste Erwartungen → AC-5.
5. `tally`: unveränderte Zeile, geänderte Zeile, nur Groß-/Kleinschreibung, Leerzeichen, Preisänderung,
   abgewählte Zeile, Zeile ohne Stufe, Zeile mit `.ai` → AC-7/8/9/4.
6. `record` zweimal addiert; neue Instanz liest gleichen Wert → AC-10.
7. `reset` und Leerwert → AC-11.
8. Rohwert enthält keinen Zeilennamen → AC-12.
9. `mergeAIReresolution` setzt Stufe und `resolvedName` nur an den Indizes → AC-14.

### UI-Test (`RestockUITests/ReceiptResolutionStatsUITests.swift`, Pflicht, vor der Implementation rot)

Muster `ReceiptReviewUITests`: Launch-Argumente `-hasCompletedOnboarding YES`, `-developerMode YES`,
`-seedReceiptReviewForUITests`; die Zeilen dieses Seeds bekommen in `SmartCartApp.swift` Stufen
(Vollmilch `.ai`, Hackfleisch `.completed`, Milch `.completed`, Brötchen `.dictionary` o. ä.; die
genaue Zuordnung legt der Seed fest und der Test liest sie aus den Identifiern).
1. Bildschirm ohne Daten: sieben Stufenzeilen mit 0, Summenzeile 0 (AC-16).
2. Bon im Seed speichern (bestehender Ablauf), Einstellungen → „Bon-Auflösung“: Summenzeile = Anzahl
   Seed-Zeilen, Stufenwerte passen zum Seed (AC-18). Eine Zeile vorher umbenennen und eine
   abwählen, damit `changed`/`deselected` > 0 geprüft werden.
3. „Zurücksetzen“ → „Abbrechen“ lässt die Zahlen stehen, „Zurücksetzen“ → Bestätigen setzt auf 0 (AC-17).
4. Ohne `-developerMode YES` kein Link „Bon-Auflösung“ in den Einstellungen (AC-15).
5. `tearDown()`: App einmal mit `-clearReceiptReviewSeedForUITests` und
   `-clearReceiptResolutionStatsForUITests` starten (AC-19).

Sprache: der Scheme-Test-Action erzwingt Deutsch; die Tests suchen über Identifier und deutsche Labels.
Ein einzelner Lauf beweist keine Stabilität (Kaltstart-Wartezeiten ≥ 15 s): drei Läufe vorlegen, Simulator
nie parallel zu anderen Läufen, Nachweis auf Testzahl, Abbrüche und Retry-Flag prüfen.

### Durchlauf als Nutzer (vor Übergabe, nicht ersetzbar durch Tests)

App im Simulator mit dem Stand der Auslieferung starten, Entwicklermodus, Bon mit Seed speichern,
„Bon-Auflösung“ öffnen, Zahlen und Zurücksetzen ansehen. Stufe KI wird dort nicht gezählt
(Apple Intelligence nicht verfügbar) — das ist erwartet und wird im Bericht benannt, nicht als
Lücke versteckt. Eine Messung der KI-Stufe geschieht ab Auslieferung auf Hennings Gerät.

## Alternativen (verworfen)

- **Abschnitt in der bestehenden Nachkauf-Statistik (Variante B):** weniger Dateien, aber vermischt zwei
  fachfremde Messungen auf einem Bildschirm; Henning hat Variante A freigegeben.
- **Korpus-Harness im Test-Target mit anonymisierten Echtbons:** wiederholbar, braucht Echtdaten von
  Henning und deckt Stufe 5 nie ab; als spätere Ergänzung offen.
- **Stufe als nicht-optionales Feld mit eigenem `init(from:)`:** möglich, aber mehr Code für denselben
  Nutzen; ein Alt-Payload hätte dann eine erfundene Stufe (z. B. Rohtext), die die Zahlen verfälscht.
  `nil` = „unbekannt, nicht gezählt“ ist ehrlicher.
- **Zählen in der Share Extension:** nicht möglich/sinnvoll, dort wird nichts bestätigt, und ein
  zweiter Schreiber auf dem Zähler wäre ein Race (die Extension speichert nichts).
- **Streichen von Stufe 5 und Vorschlag statt automatisch setzen:** erst nach der Messung zu entscheiden;
  würde die KI-Kennzeichnung (Art. 50), das 25-s-Budget und den Sonderweg der Teilen-Erweiterung kippen.

## Risiken und offene Grenzen

- **Zählung nur beim Speichern:** Wer den Bon verwirft, liefert keine Messung. Verzerrung zugunsten
  gespeicherter Bons; für die Nulllinie hinnehmbar und im Fußtext benannt.
- **„Geändert“ ≠ „falsch“:** Der Nutzer kann einen richtigen Namen aus Geschmack umbenennen, und
  ein unverändertes Ergebnis kann nur aus Bequemlichkeit stehengeblieben sein. Die Quote ist eine
  Untergrenze/Näherung der Fehlerquote, kein Beleg. Gleiches gilt für „Abgewählt“.
- **Stufe 5 nicht im Simulator messbar** (Apple Intelligence). Die Regel-Spalte liefert die
  Nulllinie; ob die KI mehr trifft als sie erfindet, zeigt erst Hennings Gerät. Vor dort keine
  Aussage darüber.
- **Stufe `nonProduct` bleibt vorerst leer** (Abschnitt Implementation 1); die KEIN_PRODUKT-Antworten
  stehen unter `.rawText`. Folge: die Rohtext-Zeile mischt „nichts gefunden“ und „Modell sagte kein
  Produkt/Timeout/nicht verfügbar“. Das ist eine offene Grenze und gehört in jede Auswertung
  (#90).
- **Wire-Format der Share Extension:** Fehler im Codable-Verhalten würden den ganzen Handoff-Payload
  verwerfen. Deshalb optionales Feld und Alt-Payload-Test (AC-6). Beobachtung am Rande: das
  bestehende nicht-optionale Feld `resolvedByAI` hat denselben Mechanismus nicht abgesichert
  (Kommentar behauptet es); dieses Ticket ändert das nicht, ein Alt-Payload ohne `resolvedByAI`
  ließe sich daher heute schon nicht decodieren. Folge-Issue empfohlen, nicht Teil dieses Tickets.
- **Datenschutz:** nur Zahlen, in der App-Gruppe auf dem Gerät, kein Sync, keine Namen/Preise. Beim
  Löschen der App verschwinden sie mit.
- **Race:** `record` wird ausschließlich auf dem MainActor aus `save()` aufgerufen; die Share Extension
  schreibt nicht. Kein gleichzeitiger Schreiber.
- **LoC-/Dateigrenze:** siehe Estimated Changes; bei Gate-Blockade in zwei Teile trennen.
- **Seed-Aufräumen:** vergisst ein Test das Aufräumargument, tauchen Zahlen in späteren Läufen auf
  (Memory „UI-Test-Seeds müssen aufräumen“) — AC-19.

## Side-Effects

- Neue Datei(en) in `project.pbxproj` (4), keine neuen Targets, keine Berechtigungen, keine Info.plist-Änderung.
- Neuer UserDefaults-Schlüssel in der App-Gruppe: `smartcart.receiptResolutionStats.v1` (Zahlen). Keine
  Änderung an bestehenden AppStorage-/UserDefaults-Schlüsseln, SwiftData-Schema oder CloudKit.
- Wire-Format `SharedReceiptPayload`: ein optionales Feld `stage` je Zeile hinzugefügt, abwärtskompatibel
  (Alt-Payload ohne Feld decodiert); ältere App-Versionen ignorieren das unbekannte Feld.
- Neue Strings (nur Dev-Bildschirm und Einstellungen) über `String(localized:)`; keine Audio-Dateien.
- Neue DEBUG-Launch-Argumente: `-clearReceiptResolutionStatsForUITests`; geänderter Seed
  `-seedReceiptReviewForUITests` (nur zusätzliches Feld `stage` je Zeile).
- Keine Änderung am Verhalten von Bon-Import, Lernen von Preisen, Aliasen oder Review-Auswahl.

## Changelog

- 2026-10-02: Erstfassung (Issue #14, Teil „Messung zuerst“, Variante A freigegeben).
