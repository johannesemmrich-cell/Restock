---
entity_id: receipt-review-test-entry
type: feature
created: 2026-09-22
updated: 2026-09-22
status: draft
version: "1.0"
tags: [ui-tests, testing, receipt, debug-seed]
test_targets: [RestockUITests]
---

# Bon-Prüf-Screen: automatisierter Testeinstieg ohne Kamera/OCR

## Approval

- [ ] Approved

## GitHub Issue

- **Issue:** #28 — „Bon-Prüf-Screen: automatisierter Testeinstieg ohne Kamera/OCR (Schritt A zu #23)"

## Purpose

Der Bon-Prüf-Screen (`ReceiptScannerView` im `.review`-Modus, Navigationstitel „Bon scannen —
<Laden>") ist heute nur über Kamera-OCR oder einen echten Fotos-→-Teilen-Sprung erreichbar — beides
nicht deterministisch genug für einen UI-Test. Diese Spec führt einen DEBUG-Startargument-Seed ein,
der einen Laden mit Artikeln anlegt und einen festen, vierzeiligen Bon über den echten Handoff-Weg
(`ReceiptShareHandoff` → `HomeView.checkPendingReceiptScan()`) einspeist, dazu die ersten
`accessibilityIdentifier`s im Produktcode und eine neue UI-Test-Datei. Das ist Schritt A der
dreiteiligen Aufteilung von Issue #23 (A = #28 → B = #23 → C = #29): ohne einen reproduzierbaren
Einstieg gibt es für #23 keinen automatisierten RED-Nachweis. Es entsteht keine sichtbare
Produktänderung — nur ein Test-Zugang und unsichtbare Identifier.

## Source

- **File:** `SmartCart/SmartCartApp.swift` (neuer Seed), `RestockUITests/ReceiptReviewUITests.swift`
  (neu)
- **Identifier:** `seedReceiptReviewForUITestsIfNeeded(context:)`,
  `testReviewSheetOpensFromShareHandoff`, `testOriginalReceiptTextIsVisibleOnEveryLine`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ReceiptShareHandoff.store(_:)` / `takePending()` | Service | Schreibt/liest `SharedReceiptPayload` als JSON in App-Group-`UserDefaults` (Key `pendingShareExtensionReceipt`, einmaliger Konsum). Der Seed nutzt ausschließlich `store(_:)` — kein neuer Pfad. |
| `SharedReceiptPayload` / `ResolvedReceiptLine` / `ReceiptSuggestion` (`ReceiptResolutionService.swift:8-44`) | Wire-Format | Bausteine der festen Nutzlast. Keine Feldänderung. |
| `HomeView.checkPendingReceiptScan()` (`HomeView.swift:1565-1585`) | Downstream Consumer | Konsumiert die Nutzlast wie nach einem echten Teilen: löst `storeID` gegen aktive Läden auf, öffnet `.sheet(item:)` mit `ReceiptScannerView`. Bleibt unverändert. |
| `ReceiptScannerView.init(store:prefilled:storeConfidentlyDetected:)` (`ReceiptScannerView.swift:147-170`) | Consumer | Startet direkt in `.review`, setzt `cameFromShareHandoff = true`. Unverändert. |
| `ReceiptScannerView.reResolveAIIfNeeded()` (`ReceiptScannerView.swift:285-296`) | Bestehendes Verhalten | Löst jede Zeile mit `!resolvedByAI && name == originalName` erneut über `ReceiptResolutionService` auf. Bestimmt die Fixture-Invariante (siehe Implementation Details). Nicht angefasst. |
| `Store.init(name:emoji:colorHex:)`, `ShoppingItem.init(name:quantity:unit:store:)` | Model | Legen den Seed-Laden und die Seed-Artikel an. |
| `seedSharedAssignmentForScreenshotsIfNeeded` (`SmartCartApp.swift:26-31, 135-190`) | Vorbild | Bestehendes DEBUG-Seed-Muster (Guard auf Startargument, alle Läden wischen, Laden+Artikel anlegen, `try? context.save()`), neben dem der neue Seed eingehängt wird. |
| `docs/specs/views/receipt-review-card.md`, Abschnitt „`accessibilityIdentifier`-Schema" (Z. 241-260) | Spec | Bindendes ID-Schema für #23. #28 führt die Teilmenge `name`/`price`/`aiMark`/`saveButton` ein; #23 übernimmt sie unverändert. |
| `Restock.xcodeproj/project.pbxproj` (Vorlage `ReceiptShareExtensionTests.swift`, Z. 139/298/592/918) | Build-Konfiguration | Registrierung der neuen Testdatei an 4 Stellen — kein Auto-Discovery neuer Swift-Dateien. |
| `.github/workflows/ci.yml:149-160` | CI | Ruft `-only-testing:RestockUITests` — die neue Datei läuft automatisch mit. Unverändert. |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/SmartCartApp.swift` | MODIFY | Neuer DEBUG-Seed `seedReceiptReviewForUITestsIfNeeded(context:)`, Aufruf im `init`-`defer` direkt neben `seedSharedAssignmentForScreenshotsIfNeeded` (Z. 28-30), Definition nach Z. 182 im bestehenden `#if DEBUG`-Block. ≈ +50 LoC |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `ForEach` (Z. 425-426) reicht den Zeilenindex an `ReceiptLineRow` durch; vier neue `accessibilityIdentifier`s auf den Blatt-Views (Name-`TextField`, Preis-`TextField`, KI-`Label`, Speichern-`Button`). ≈ +20 LoC |
| `RestockUITests/ReceiptReviewUITests.swift` | CREATE | Zwei Tests: Grundgerüst-Nachweis und RED-Test für #23 (siehe Test Plan). ≈ +100 LoC |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung der neuen Datei an 4 Stellen (PBXBuildFile, PBXFileReference, PBXGroup-Children, PBXSourcesBuildPhase), 2 neue 24-stellige Hex-UUIDs. ≈ +16 LoC |

**Ausdrücklich NICHT geändert:** `HomeView.swift` (der echte Konsumpfad bleibt unangetastet),
`ReceiptShareHandoff.swift`, `ReceiptResolutionService.swift`, `project.yml` (enthält kein
`RestockUITests`-Target — die bestehenden UI-Test-Dateien leben bereits ausschließlich im
eingecheckten `pbxproj`, gleiches Vorgehen hier).

### Estimated Changes

- Files: 4 (innerhalb des Projekt-Limits „max. 4-5 Dateien")
- LoC: ≈ +170 / −2 (innerhalb des Projekt-Limits ±250 LoC)
- Risiko: NIEDRIG — rein additiv (DEBUG-Startargument, unsichtbare Identifier, neue Testdatei);
  einziger Eingriff in bestehendes Verhalten ist die Index-Durchreichung im `ForEach`.

### Out of Scope

- **Das Karten-Layout selbst** (neue `ReceiptReviewCard`-View, Auswahlzeilen, Mengen-Editor) —
  gehört zu #23.
- **Die sichtbare Bontext-Anzeige** (`originalName` an der Karte) — gehört zu #23; #28 belegt nur
  die heutige Lücke über den RED-Test.
- **Preis-Themen** (#10–#15).
- **`ReceiptResolutionService`, `ReceiptShareHandoff`, `HomeView`** — keine Änderung an Auflösung,
  Handoff-Mechanik oder Konsumpfad.
- **Vorschlags-Regel** (Floor/Limit, #29).

## Implementation Details

### 1. Seed-Funktion `seedReceiptReviewForUITestsIfNeeded(context:)`

DEBUG-only, aufgerufen im `init`-`defer` von `SmartCartApp` neben
`seedSharedAssignmentForScreenshotsIfNeeded`, mit Guard auf das Startargument
`-seedReceiptReviewForUITests`. Ablauf, in dieser Reihenfolge:

1. Alle bestehenden `Store`s löschen (der App-Group-Container überlebt Testläufe — ohne dieses
   Wischen würden sich Läden über mehrere Läufe ansammeln, wie im Vorbild-Seed).
2. Laden „Lidl" anlegen (`Store(name:emoji:colorHex:)`).
3. Die sechs Seed-Artikel anlegen (`ShoppingItem(name:quantity:unit:store:)`), alle offen, keiner
   abgehakt: Milch, Hafermilch, Buttermilch, Vollmilch, Hackfleisch, Brötchen.
4. `try? context.save()` — **erst danach** die Nutzlast bauen, weil `suggestions` und
   `matchedItemID` die soeben vergebenen `id`s der Artikel referenzieren.
5. `ReceiptShareHandoff.store(SharedReceiptPayload(storeID: store.id,
   storeConfidentlyDetected: true, lines: …, rawLines: …, detectedTotal: …))`.

```swift
#if DEBUG
private func seedReceiptReviewForUITestsIfNeeded(context: ModelContext) {
    guard ProcessInfo.processInfo.arguments.contains("-seedReceiptReviewForUITests") else { return }

    if let existing = try? context.fetch(FetchDescriptor<Store>()) {
        existing.forEach { context.delete($0) }
    }

    let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
    context.insert(store)

    let milch = ShoppingItem(name: "Milch", quantity: 1, unit: "", store: store)
    let hafermilch = ShoppingItem(name: "Hafermilch", quantity: 1, unit: "", store: store)
    let buttermilch = ShoppingItem(name: "Buttermilch", quantity: 1, unit: "", store: store)
    let vollmilch = ShoppingItem(name: "Vollmilch", quantity: 1, unit: "", store: store)
    let hackfleisch = ShoppingItem(name: "Hackfleisch", quantity: 1, unit: "", store: store)
    let broetchen = ShoppingItem(name: "Brötchen", quantity: 1, unit: "", store: store)
    [milch, hafermilch, buttermilch, vollmilch, hackfleisch, broetchen]
        .forEach { context.insert($0) }

    try? context.save()

    let lines: [ResolvedReceiptLine] = [
        ResolvedReceiptLine(
            name: "Frische Vollmilch 3,5 %", originalName: "MILCH 3,5% FRISCH",
            price: 1.19, quantity: 1, unit: "", weightBasis: nil,
            suggestions: [], matchedItemID: vollmilch.id, resolvedByAI: true),
        ResolvedReceiptLine(
            name: "Bio-Hackfleisch gemischt Rind & Schwein 400 g",
            originalName: "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G",
            price: 4.99, quantity: 1, unit: "400g", weightBasis: nil,
            suggestions: [], matchedItemID: hackfleisch.id, resolvedByAI: false),
        ResolvedReceiptLine(
            name: "Milch", originalName: "MILCH",
            price: 0.99, quantity: 1, unit: "", weightBasis: nil,
            suggestions: [
                ReceiptSuggestion(name: "Hafermilch", itemID: hafermilch.id),
                ReceiptSuggestion(name: "Buttermilch", itemID: buttermilch.id),
                ReceiptSuggestion(name: "Vollmilch", itemID: vollmilch.id),
            ], matchedItemID: milch.id, resolvedByAI: false),
        ResolvedReceiptLine(
            name: "Brötchen", originalName: "BROETCHEN",
            price: 1.56, quantity: 4, unit: "", weightBasis: nil,
            suggestions: [], matchedItemID: broetchen.id, resolvedByAI: false),
    ]

    ReceiptShareHandoff.store(SharedReceiptPayload(
        storeID: store.id,
        storeConfidentlyDetected: true,
        lines: lines,
        rawLines: lines.map(\.originalName),
        detectedTotal: lines.reduce(0) { $0 + $1.price }))
}
#endif
```

`storeConfidentlyDetected: true` ist Pflicht — sonst greift der Besuchsfrequenz-Notnagel in
`checkPendingReceiptScan()`, das Banner „Laden nicht sicher erkannt" erscheint, und
`canSave`/`receiptReview.saveButton` bleibt gesperrt (`storeNeedsConfirmation`).

### 2. Fixture-Determinismus (Invariante 1)

`reResolveAIIfNeeded()` (`ReceiptScannerView.swift:285-296`) läuft bei **jedem** Handoff per
`.task` und schickt jede Zeile mit `!resolvedByAI && name == originalName` erneut durch
`ReceiptResolutionService.resolve` (Stufen 1-5: Abkürzungs-Wörterbuch, Fuzzy-Match gegen den
geseedeten Laden, gelernte Aliasse aus früheren Läufen, Apple Intelligence — Stufe 5 im Simulator
nicht verfügbar, übersprungen). Damit die Fixture nicht von einem dieser vier laufenden Stufen
verändert werden kann, muss **jede** Zeile mindestens eine der beiden Bedingungen erfüllen:

> **Invariante 1 — Fixture-Determinismus:** Jede Bon-Zeile erfüllt `resolvedByAI == true` **oder**
> `name != originalName`. Dann ist `EditableReceiptLine.linesNeedingAIReresolution` für die gesamte
> Fixture leer, `reResolveAIIfNeeded()` läuft überhaupt nicht, und weder Wörterbuch noch
> Fuzzy-Match noch ein aus einem früheren Testlauf gelernter Alias kann eine Zeile verändern.

Die Fixture erfüllt beide Halbbedingungen redundant (Sicherheitsmarge):

| Zeile | `resolvedByAI` | `name` vs. `originalName` | Erfüllt Invariante 1 über |
|---|---|---|---|
| Z0 | `true` | verschieden | beide Hälften |
| Z1 | `false` | stark verschieden (KI-Kürzel → Klartext) | `name != originalName` |
| Z2 | `false` | verschieden **nur durch Groß-/Kleinschreibung** (`"MILCH"` vs. `"Milch"`) | `name != originalName` (String-Vergleich ist case-sensitiv) |
| Z3 | `false` | verschieden (`"BROETCHEN"` vs. `"Brötchen"`) | `name != originalName` |

Z2 ist der subtilste Fall: `originalName` und `name` unterscheiden sich ausschließlich in der
Schreibweise. Da der Vergleich in `linesNeedingAIReresolution` ein exakter Swift-String-Vergleich
ist, reicht dieser Unterschied bereits aus, um die Zeile von der Nachauflösung auszunehmen — ein
bewusst genutzter, aber nicht offensichtlicher Nebeneffekt der bestehenden Bedingung.

### 3. Fester Bon (4 Zeilen)

Wortlaut verbindlich für diese Spec. Alle vier `ResolvedReceiptLine`-Werte werden direkt als
Fixture konstruiert (nicht über `ReceiptParserService` aus Rohtext geparst) — die
Parser-Korrektheit selbst ist nicht Gegenstand dieser Spec.

| Feld | Z0 (KI-Zeile) | Z1 (langer Name) | Z2 (3 Vorschläge) | Z3 (Mengen-Zeile, #9) |
|---|---|---|---|---|
| `originalName` | `MILCH 3,5% FRISCH` | `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` (43 Zeichen) | `MILCH` | `BROETCHEN` |
| `name` | `Frische Vollmilch 3,5 %` | `Bio-Hackfleisch gemischt Rind & Schwein 400 g` | `Milch` | `Brötchen` |
| `price` | `1.19` | `4.99` | `0.99` | `1.56` |
| `quantity` | `1` | `1` | `1` | `4` |
| `unit` | `""` | `"400g"` | `""` | `""` |
| `weightBasis` | `nil` | `nil` | `nil` | `nil` |
| `suggestions` | `[]` | `[]` | `[Hafermilch, Buttermilch, Vollmilch]` (3 Einträge) | `[]` |
| `matchedItemID` | id von „Vollmilch" | id von „Hackfleisch" | id von „Milch" | id von „Brötchen" |
| `resolvedByAI` | `true` | `false` | `false` | `false` |

Seed-Artikel (Laden „Lidl", alle offen/nicht abgehakt): Milch, Hafermilch, Buttermilch, Vollmilch,
Hackfleisch, Brötchen.

`rawLines`: `["MILCH 3,5% FRISCH", "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G", "MILCH",
"BROETCHEN"]` (= die vier `originalName`-Werte, in Zeilenreihenfolge).

`detectedTotal`: `1.19 + 4.99 + 0.99 + 1.56 = 8.73` (Summe der vier `price`-Werte).

### 4. `accessibilityIdentifier`-Schema (Teilmenge des #23-Schemas, koordiniert)

Grundlage ist der Schlusssatz des Schemas in `docs/specs/views/receipt-review-card.md`
(Z. 258-260): „sollte #28 zuerst abweichende Identifier für Bontext/Preis/KI-Marke/Speichern
einführen, wird bei der Implementierung von #23 auf die dort bereits gemergten Strings
angeglichen (keine zwei parallelen Schemata)." #28 führt deshalb genau die vier Identifier ein,
die das heutige `ReceiptLineRow` überhaupt tragen kann — zwei davon stehen wortgleich in der
#23-Tabelle, zwei nicht (Begründung unter der Tabelle):

| Element | Identifier |
|---|---|
| Name-`TextField` | `receiptReview.line.<index>.nameField` |
| Preis-`TextField` | `receiptReview.line.<index>.priceField` |
| KI-Marke (`Label("KI-Vorschlag", …)`) | `receiptReview.line.<index>.aiMark` |
| Speichern-Button (Toolbar, `ReceiptScannerView.swift:237`) | `receiptReview.saveButton` |

Herkunft je Identifier, damit #23 nichts umbenennen muss:

- `aiMark` — steht wortgleich in der #23-Tabelle. Unverändert übernehmbar.
- `priceField` — die #23-Tabelle trennt `price` (Preiszeilen-**Text** der Karte) von `priceField`
  (Eingabefeld nach „Ändern"). Das heutige Element ist ein `TextField`, also ein Eingabefeld:
  es bekommt `priceField`. `price` bleibt für #23 frei — sonst trügen in #23 zwei verschiedene
  Elemente denselben Namen.
- `nameField` — hat in der #23-Tabelle **kein** Gegenstück: die Karte ersetzt das freie Namensfeld
  durch Auswahlzeilen (`option.<k>`) und ein Feld „Anderer Name" (`customNameField`). Der
  Identifier ist deshalb ausdrücklich **übergangsweise**; er verschwindet mit #23 zusammen mit dem
  heutigen `TextField`, und `testReviewSheetOpensFromShareHandoff` wird dort auf die Auswahlzeilen
  umgestellt. Bewusst **nicht** `customNameField` genannt: das heutige Feld ist das einzige, primäre
  Namensfeld der Zeile, nicht die „anderer Name"-Ausweichoption der Karte — gleiche Namen für
  verschiedene Rollen wären die schlechtere Erblast.
- `saveButton` — der Toolbar-Knopf gehört nicht zur Karte und steht deshalb nicht in der
  #23-Tabelle; ihr Schlusssatz nennt „Speichern" aber ausdrücklich als einen der Identifier, die
  #28 zuerst einführen darf. #23 übernimmt ihn unverändert.

Identifier sitzen auf den Blatt-Views selbst (`TextField`, `Label`, `Button`), nicht auf
umgebenden `HStack`/`VStack`-Containern — sonst würde `XCUIElement.exists` je nach
SwiftUI-Accessibility-Zusammenfassung fehlschlagen.

**Bewusst NICHT eingeführt:** `receiptReview.line.<index>.originalName`. Dieses Element existiert
im heutigen `ReceiptLineRow` nicht — der Bontext wird nirgends separat angezeigt. Genau diese
Lücke belegt `testOriginalReceiptTextIsVisibleOnEveryLine` (siehe Test Plan); #23 führt den
Identifier zusammen mit der sichtbaren Anzeige ein.

Dafür wird der Zeilenindex an `ReceiptLineRow` durchgereicht. Heute:

```swift
ForEach($parsedLines) { $line in ReceiptLineRow(line: $line) }
```

Neu — Index zusätzlich zur Binding-Identität, damit jede Zeile ihren eigenen Identifier-Suffix
bekommt:

```swift
ForEach(Array($parsedLines.enumerated()), id: \.element.id) { index, $line in
    ReceiptLineRow(line: $line, index: index)
}
```

Verworfene, knappere Alternative: `ForEach($parsedLines.indices, id: \.self)` mit Zugriff über
`$parsedLines[index]` — spart die `enumerated()`-Zwischenstruktur, verworfen, weil sie die
Bindung von der Zeilen-`Identifiable`-Identität auf den reinen Array-Index umstellt und damit ein
SwiftUI-`List`-Diffing-Risiko einführt, das die bestehende `ForEach($parsedLines)`-Form heute nicht
hat. `ReceiptLineRow` bekommt einen zusätzlichen `let index: Int`-Parameter; die vier neuen
Identifier werden mit `"receiptReview.line.\(index).…"` gebildet.

### 5. Neue Testdatei `RestockUITests/ReceiptReviewUITests.swift`

```swift
import XCTest

final class ReceiptReviewUITests: XCTestCase {

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests"]
        app.launch()
        return app
    }

    func testReviewSheetOpensFromShareHandoff() {
        let app = launchedApp()

        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 10))

        for index in 0...3 {
            XCTAssertTrue(
                app.textFields["receiptReview.line.\(index).nameField"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["receiptReview.line.\(index).priceField"].exists)
        }

        XCTAssertTrue(app.otherElements["receiptReview.line.0.aiMark"].exists
            || app.staticTexts["receiptReview.line.0.aiMark"].exists)

        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isHittable)
    }

    func testOriginalReceiptTextIsVisibleOnEveryLine() {
        let app = launchedApp()
        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 10))

        XCTExpectFailure("Bontext erst mit #23 sichtbar", strict: true) {
            for index in 0...3 {
                XCTAssertTrue(app.staticTexts["receiptReview.line.\(index).originalName"].exists)
            }
        }
    }
}
```

### 6. `Restock.xcodeproj/project.pbxproj`

Registrierung von `ReceiptReviewUITests.swift` an den vier laut `CLAUDE.md` nötigen Stellen, nach
Vorlage der bestehenden Datei `ReceiptShareExtensionTests.swift`:

1. `PBXBuildFile` (Vorbild Z. 139) — Build-UUID → Dateireferenz-UUID.
2. `PBXFileReference` (Vorbild Z. 298) — Dateipfad `RestockUITests/ReceiptReviewUITests.swift`.
3. `PBXGroup`-Children (Vorbild Z. 592) — Einordnung in die `RestockUITests`-Gruppe.
4. `PBXSourcesBuildPhase` (Vorbild Z. 918) — Aufnahme in die Compile-Sources-Liste des
   `RestockUITests`-Targets.

Zwei neue, mit den bestehenden UUIDs nicht kollidierende 24-stellige Hex-UUIDs (eine für
`PBXBuildFile`, eine für `PBXFileReference`). `project.yml` bleibt unangetastet — es enthält kein
`RestockUITests`-Target; die bestehenden UI-Test-Dateien leben bereits ausschließlich im
eingecheckten `pbxproj`.

## Invarianten

1. **Fixture-Determinismus** (siehe Implementation Details Abschnitt 2): Jede Bon-Zeile erfüllt
   `resolvedByAI == true` oder `name != originalName`, damit `reResolveAIIfNeeded()` beim Handoff
   nie ausgeführt wird und die Fixture unverändert bleibt.
2. **Der Seed wirkt ausschließlich mit explizitem Startargument.** Ohne
   `-seedReceiptReviewForUITests` löscht/erstellt die Funktion nichts — bestehende Läden, Artikel
   und ein eventuell anstehender echter Handoff bleiben unberührt. Belegt durch die Negativkontrolle
   im Test Plan.
3. **`accessibilityIdentifier`s sitzen auf Blatt-Views**, nie auf umgebenden Containern — sonst
   wäre `XCUIElement.exists` von SwiftUIs Accessibility-Zusammenfassung abhängig statt von einem
   stabilen Identifier.
4. **Kein neuer Identifier für den Bontext.** `receiptReview.line.<index>.originalName` wird in
   #28 bewusst nicht eingeführt — das ist die Lücke, die `testOriginalReceiptTextIsVisibleOnEveryLine`
   für #23 belegt.
5. **`storeID` der Nutzlast trifft immer den geseedeten Laden** (`store.id`), und
   `storeConfidentlyDetected` ist immer `true` — sonst wäre `receiptReview.saveButton` gesperrt und
   der Grundgerüst-Test könnte die Ladenerkennung nicht als funktionierend nachweisen.

## Test Plan

### Automated Tests (TDD RED)

**UI — `RestockUITests/ReceiptReviewUITests.swift`:**

- [ ] **Test 1 — `testReviewSheetOpensFromShareHandoff`**
  - *Vorbedingung:* Frischer Start, Launch-Argumente `-hasCompletedOnboarding YES
    -seedReceiptReviewForUITests`.
  - *Schritte:* App starten → auf Navigationstitel „Bon scannen — Lidl" warten (Beweis: Seed hat
    den Laden angelegt, Handoff wurde konsumiert, Store-Matching hat gegriffen) → für jeden Index
    0-3 `receiptReview.line.<i>.nameField` und `receiptReview.line.<i>.priceField` auf Existenz
    prüfen → die
    KI-Marke `receiptReview.line.0.aiMark` auf Existenz prüfen → `receiptReview.saveButton` auf
    `isHittable == true` prüfen.
  - *Erwartung:* Alle Prüfungen bestehen. `saveButton.isHittable` beweist, dass `canSave` erfüllt
    ist — also dass `storeConfidentlyDetected: true` durchgereicht wurde und mindestens eine
    Position ausgewählt ist.

- [ ] **Test 2 — `testOriginalReceiptTextIsVisibleOnEveryLine`** (RED-Test für #23)
  - *Vorbedingung:* Wie Test 1.
  - *Schritte:* App starten → auf den Navigationstitel warten → innerhalb von
    `XCTExpectFailure("Bontext erst mit #23 sichtbar", strict: true)` für jeden Index 0-3 prüfen,
    ob `receiptReview.line.<i>.originalName` existiert.
  - *Erwartung:* Die Prüfung schlägt fehl (das Element existiert heute nicht) — `strict: true`
    lässt den Gesamttest nur dann als bestanden gelten, wenn *tatsächlich* ein Fehlschlag auftritt.
    Damit bleibt die CI von #28 grün, und #23 **muss** den `XCTExpectFailure`-Block entfernen,
    sobald der Bontext eingeführt ist — tut #23 das nicht, wird der Test dort automatisch wieder
    rot (kein stillschweigendes Weiterschleppen der Lücke).

- [ ] **Negativ-Nachweis (kein neuer Test, Beobachtung am bestehenden Lauf):** Ein Lauf der
  bestehenden `RestockUITests`-Suite **ohne** `-seedReceiptReviewForUITests` bleibt unverändert
  grün — das beweist, dass der neue Seed ohne das Startargument nichts tut (Invariante 2) und
  keine bestehende Funktion beeinflusst.

**Reihenfolge des Nachweises:** frisch geleerter Simulator (kein anderer Simulator-Lauf parallel,
bekannter 10-Minuten-Diagnose-Hänger bei Parallelität, Issue #21) → Test 1 → Test 2 → vollständige
`RestockUITests`-Suite ohne das neue Startargument als Negativkontrolle.

## Acceptance Criteria

- **AC-1:** Given der Seed-Aufruf mit `-seedReceiptReviewForUITests` / When die App startet /
  Then öffnet sich automatisch der Bon-Prüf-Screen mit Navigationstitel „Bon scannen — Lidl".
  Test: `testReviewSheetOpensFromShareHandoff`.
- **AC-2:** Given der geseedete Bon / When der Screen geöffnet ist / Then sind alle vier Zeilen
  über `receiptReview.line.<i>.nameField` und `receiptReview.line.<i>.priceField` (i = 0…3)
  auffindbar.
  Test: `testReviewSheetOpensFromShareHandoff`.
- **AC-3:** Given Zeile 0 mit `resolvedByAI: true` / When der Screen geöffnet ist / Then ist
  `receiptReview.line.0.aiMark` sichtbar. Test: `testReviewSheetOpensFromShareHandoff`.
- **AC-4:** Given `storeConfidentlyDetected: true` in der Nutzlast / When der Screen geöffnet ist
  / Then ist `receiptReview.saveButton` `isHittable` (Ladenerkennung hat gegriffen, `canSave`
  erfüllt). Test: `testReviewSheetOpensFromShareHandoff`.
- **AC-5:** Given die vier Fixture-Zeilen, jede mit `resolvedByAI == true` oder
  `name != originalName` / When `reResolveAIIfNeeded()` beim Handoff läuft / Then bleibt jede
  Zeile unverändert — kein Einfluss von Wörterbuch, Fuzzy-Match oder gelernten Aliassen. Nachweis:
  Code-Lesung, nicht Wertprüfung im Test — `reResolveAIIfNeeded()` bricht am `guard
  !indices.isEmpty` ab, weil `EditableReceiptLine.linesNeedingAIReresolution`
  (`ReceiptScannerView.swift:68-72`) für diese Fixture leer ist. Die UI-Tests lesen ausschließlich
  `exists`/`waitForExistence`, nie `XCUIElement.value` — sie belegen AC-5 also NICHT.
- **AC-6:** Given kein Startargument `-seedReceiptReviewForUITests` / When die bestehende
  `RestockUITests`-Suite läuft / Then bleibt sie unverändert grün — der Seed hat ohne Argument
  keine Wirkung. Test: bestehende Suite in `RestockUITests/RestockUITests.swift` (Negativkontrolle,
  kein neuer Testcode).
- **AC-7:** Given das heutige Layout (`ReceiptLineRow` ohne Bontext-Anzeige) / When
  `receiptReview.line.<i>.originalName` für jede Zeile geprüft wird / Then schlägt die Prüfung
  fehl — belegt in `XCTExpectFailure("Bontext erst mit #23 sichtbar", strict: true)`. Test:
  `testOriginalReceiptTextIsVisibleOnEveryLine`.

## Alternativen (verworfen)

- **(a) Sheet direkt öffnen** statt über `HomeView.checkPendingReceiptScan()` (z. B. eigener
  DEBUG-Navigationspfad, der `ReceiptScannerView` unmittelbar präsentiert): Verworfen, weil dieser
  Weg das Store-Matching und die Confidence-Prüfung umgeht — genau die Logik, die #23 testen muss.
  Ein Sonderpfad hätte einen anderen Code-Pfad getestet als den, den ein echtes Teilen durchläuft.
- **(b) Nutzlast per Launch-Environment** statt per Seed-Argument und `ModelContext` (z. B. JSON
  direkt als Environment-Variable an `ReceiptShareHandoff` übergeben): Verworfen, weil Laden und
  Artikel trotzdem über `ModelContext` angelegt werden müssten, damit `matchedItemID` und
  `suggestions` auf echte `id`s zeigen können — der Weg über Launch-Environment hätte nur mehr
  Komplexität ohne Vorteil erzeugt.
- **(c) `XCTSkip` bzw. „RED-Test erst mit #23 einchecken"** statt `XCTExpectFailure(strict: true)`
  für `testOriginalReceiptTextIsVisibleOnEveryLine`: `XCTSkip` ist im Repo bereits für „Vorbedingung
  fehlt" reserviert und hätte die Lücke im CI-Log versteckt statt sie sichtbar zu machen; „RED-Test
  erst in #23" hätte vor #23 keinen automatisierten Nachweis der Lücke geliefert. Beide verworfen
  zugunsten von `XCTExpectFailure(strict: true)`, das die CI von #28 grün hält und #23 zwingt, die
  Erwartung explizit zu entfernen.

## Risiken

- **Index-Durchreichung im `ForEach`.** Einziger Eingriff in bestehendes Verhalten der bereits
  produktiven `ReceiptScannerView`. Fehler hier (z. B. falscher Index bei Zeilen-Neuordnung durch
  `reResolveAIIfNeeded`) würden sich als falsch zugeordnete Identifier zeigen, nicht als Absturz.
- **`project.pbxproj`-Handarbeit.** Eine fehlerhafte UUID oder ein vergessener der vier Einträge
  fällt nicht als Build-Fehler auf, sondern erst als „Test not found"/„No such module" beim
  Testlauf — schwerer zu diagnostizieren als ein Compile-Fehler.
- **Accessibility-Zusammenfassung von `List`-Zeilen durch SwiftUI.** Ob `XCUITest` die vier neuen
  Identifier zuverlässig einzeln erreicht oder SwiftUI die Zeile zu einem einzigen
  Accessibility-Element zusammenfasst, ist erst im ersten grünen Lauf endgültig bewiesen — die
  Wahl „Identifier auf Blatt-Views" mindert dieses Risiko, beseitigt es aber nicht vorab.
- **App-Group-Persistenz zwischen Läufen.** Der Seed muss bei jedem Lauf sowohl alle `Store`s
  wischen als auch den Handoff-Key frisch überschreiben — ein liegengebliebener Key aus einem
  abgebrochenen vorherigen Lauf wird durch `ReceiptShareHandoff.store(...)` überschrieben, aber nur
  wenn der Seed tatsächlich läuft (siehe Invariante 2).
- **Simulator-Läufe nie parallel.** Bekannt aus Memory `ui-test-nachweis-laeufe`: ein paralleler
  zweiter Simulator-Lauf führt zu einem 10-Minuten-Diagnose-Hänger (Issue #21). Der Nachweis dieser
  Spec muss auf einem exklusiv genutzten Simulator laufen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — es gibt im Projekt kein formales ADR-Verzeichnis (`docs/adr/` existiert
  nicht, wie bereits in `docs/specs/views/receipt-review-card.md` festgehalten).
- **Rationale:** Diese Änderung ist reine Test-Infrastruktur ohne Eingriff in Datenmodelle,
  Sync-Architektur oder Wire-Formate — ein separates ADR-Dokument wäre unverhältnismäßig. Die eine
  architekturnähere Entscheidung dieser Spec — der Seed geht über den echten Handoff-Weg
  (`ReceiptShareHandoff` → `HomeView.checkPendingReceiptScan()`) statt über einen DEBUG-Sonderpfad
  — ist unter „Alternativen (verworfen), (a)" begründet: Ein Sonderpfad hätte eine frühere
  Entscheidung nicht gekippt (es gab noch keinen Testeinstieg), aber er hätte für #23 dauerhaft
  einen zweiten, ungetesteten Konsumpfad neben dem echten geschaffen. Kein bestehendes ADR wird
  durch diese Spec zurückgenommen.

## Definition of Done

Beobachtbar für den PO, ohne Code zu lesen:

- Am Produkt selbst ändert sich nichts Sichtbares — der Bon-Prüf-Screen sieht für echte Nutzer
  exakt wie heute aus.
- Automatisierte Tests können den Bon-Prüf-Screen ab jetzt zuverlässig öffnen und prüfen, ohne
  Kamera oder eine echte Bon-Erkennung zu benötigen.
- Die Lücke, dass der aufgedruckte Bontext heute nirgends zu sehen ist, ist jetzt automatisiert
  belegt (nicht nur im Screenshot von Issue #23 behauptet) — und dieser Beweis wird automatisch
  wieder rot, falls #23 den Text einführt, ohne den Testeinstieg dafür zu nutzen.
- Beide neuen Tests sind grün; die bestehende Testsuite bleibt unverändert grün, wenn das neue
  Startargument nicht gesetzt wird.

## Expected Behavior

- **Input:** Launch-Argumente `["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests"]`.
- **Output:** Die App startet direkt (kein Onboarding), legt beim ersten Start des `ModelContainer`
  den Laden „Lidl" mit sechs Artikeln an und öffnet automatisch den Bon-Prüf-Screen mit dem festen
  Vier-Zeilen-Bon aus Abschnitt „Implementation Details, 3".
- **Side effects:** Alle vorher im App-Group-Store vorhandenen `Store`s werden gelöscht (wie beim
  bestehenden Screenshot-Seed). Der Handoff-Key `pendingShareExtensionReceipt` wird überschrieben
  und beim ersten `checkPendingReceiptScan()`-Aufruf einmalig konsumiert (gelöscht). Ohne das
  Startargument passiert keine dieser Nebenwirkungen (Invariante 2).

## Known Limitations

- Die Fixture wird direkt als `ResolvedReceiptLine`-Werte konstruiert, nicht aus Rohtext über
  `ReceiptParserService` geparst — die Korrektheit des Parsers selbst wird durch diese Spec nicht
  geprüft (dafür existieren eigene Tests, z. B. `ReceiptParserPriceTests.swift`).
- Die Determinismus-Garantie (Invariante 1) setzt voraus, dass Apple-Intelligence-Auflösung (Stufe
  5 in `ReceiptResolutionService`) im Simulator weiterhin nicht verfügbar ist. Ändert sich das mit
  einer künftigen iOS-/Simulator-Version, muss die Fixture erneut gegen `reResolveAIIfNeeded`
  geprüft werden.
- Von den drei #23-Prüfkriterien aus der Analyse (Bontext sichtbar, Name vollständig, KI-Marke
  einzeilig) belegt der RED-Test hier nur die Bontext-Sichtbarkeit automatisiert. „Name vollständig"
  und „KI-Marke einzeilig" sind über Accessibility nicht messbar (`TextField.value` liefert immer
  den vollständigen Text unabhängig von der Darstellung) — sie bleiben den Frame-Prüfungen in der
  #23-Spec (`docs/specs/views/receipt-review-card.md`) vorbehalten.
- `accessibilityIdentifier`s existieren nach dieser Spec ausschließlich in `ReceiptScannerView` und
  nur für die vier hier genannten Elemente — der Rest des Produktcodes hat weiterhin keine
  Identifier (siehe `docs/specs/testing/ui-test-language.md`, „Known Limitations").

## Changelog

- 2026-09-22: Initial spec created
