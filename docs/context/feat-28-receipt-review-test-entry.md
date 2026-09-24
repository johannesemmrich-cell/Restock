# Context: feat-28-receipt-review-test-entry

Issue: #28 — „Bon-Prüf-Screen: automatisierter Testeinstieg ohne Kamera/OCR (Schritt A zu #23)"
Herkunft: Analyse zu #23 (`docs/context/feat-23-receipt-review-screen.md`, Abschnitt „Analysis",
PO-Entscheidung 2026-09-22: Aufteilung A = #28 → B = #23 → C = #29). Der Workflow
`feat-23-receipt-review-screen` steht in Phase 4 und setzt #28 als Voraussetzung voraus
(`docs/specs/views/receipt-review-card.md`, „Dependencies": „B kann nicht vor A starten").

## Request Summary
Der Bon-Prüf-Screen („Bon scannen — Laden") soll von einem UI-Test deterministisch erreichbar
werden — ohne Kamera und ohne OCR — über denselben Weg, den ein Nutzer nach dem Teilen eines
Bons geht (Handoff → Startseite → Sheet). Dazu: ein DEBUG-Startargument, das einen Laden mit
Artikeln anlegt und einen festen Bon hinterlegt; erste `accessibilityIdentifier`; eine neue
UI-Test-Datei mit Grundgerüst-Test plus dem RED-Test für #23.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/SmartCartApp.swift:26-31, 135-190` | Vorbild `seedSharedAssignmentForScreenshotsIfNeeded` — DEBUG-only, läuft im `init`-`defer` **vor** der ersten View, wischt alle Läden, legt „Lidl" + Artikel an, `try? context.save()`. Neues Argument wird direkt daneben eingehängt. |
| `SmartCart/Services/ReceiptShareHandoff.swift` | `store(_:)` schreibt `SharedReceiptPayload` als JSON in App-Group-`UserDefaults` (Key `pendingShareExtensionReceipt`); `takePending()` liest **und löscht** (einmaliger Konsum). Der Seed ruft `store(...)` — kein neuer Pfad. |
| `SmartCart/Services/ReceiptResolutionService.swift:8-44` | Wire-Format `ResolvedReceiptLine` (name, originalName, price, quantity, unit, weightBasis?, suggestions, matchedItemID?, resolvedByAI) und `ReceiptSuggestion(name:itemID:)` — Bausteine der festen Nutzlast. **Keine Feldänderung.** |
| `SmartCart/Views/Home/HomeView.swift:1565-1585` | `checkPendingReceiptScan()`: `guard pendingReceiptScan == nil, !activeStores.isEmpty, let payload = takePending()`; löst `storeID` gegen aktive Läden auf, sonst Laden mit höchster `visitsPerWeek`; setzt `pendingReceiptScan` → `.sheet(item:)` (Z. 195) öffnet `ReceiptScannerView(store:prefilled:storeConfidentlyDetected:)`. Aufrufer: `.task`/`onAppear` (Z. 281), `scenePhase == .active` (Z. 296), `onOpenURL restock://receiptscan` (Z. 212). |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:147-170` | `init(store:prefilled:storeConfidentlyDetected:)` — startet direkt in `.review`, `cameFromShareHandoff = true`. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:229-245` | Navigationstitel `"Bon scannen — \(store.name)"`, Toolbar „Abbrechen"/„Speichern" (`ChipToolbarItem`, `.disabled(!canSave)`). |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:285-296` | `reResolveAIIfNeeded()` läuft per `.task` bei jedem Handoff: Zeilen mit `!resolvedByAI && name == originalName` werden erneut durch `ReceiptResolutionService.resolve` (Stufen 1–5) geschickt. **Betrifft die Fixture** (siehe Risiken). |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:667-776` | Heutige `private struct ReceiptLineRow`: Toggle · `TextField("Artikelname")` · Stift · KI-Pille `Label("KI-Vorschlag", systemImage: "sparkles")` · Detailzeile · `TextField("0,00")` Preis · Chips-`ScrollView`. Hier landen die ersten `accessibilityIdentifier`. **Kein** `originalName` sichtbar (Bontext) — genau das, was der RED-Test für #23 nachweist. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:355-462` | `reviewView` (List mit Banner „Laden nicht sicher erkannt", Positionen, Summe). |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:271-274` | `.devFeedback(context:)` hängt im DEBUG Rohzeilen an den Kontext — nicht an den Nav-Titel; Titel bleibt testbar. |
| `RestockUITests/RestockUITests.swift` | Muster: `app.launchArguments += ["-hasCompletedOnboarding", "YES"]`, `waitForExistence(timeout:)`, `isHittable`-Expectation, Suche über deutsche Labels; Kommentar zur Testsprache (`Restock.xcscheme` pinnt `de`/`DE`). |
| `RestockUITests/ReceiptShareExtensionTests.swift` | Cross-App-Lauf über Fotos → Teilen; **nicht** der Weg für #28 (nicht deterministisch, nie parallel), aber Beleg, dass der Handoff-Weg real ist. |
| `Restock.xcodeproj/project.pbxproj:138-139, 297-298, 591-592, 917-918` | Registrierung der UI-Test-Dateien an 4 Stellen — die neue Datei `ReceiptReviewUITests.swift` muss dort ebenso eingetragen werden (kein Auto-Discovery; `project.yml` ist Referenz, das pbxproj ist eingecheckt). |
| `.github/workflows/ci.yml:149-160` | CI läuft `-only-testing:RestockUITests` — die neue Datei läuft automatisch mit. |
| `SmartCart/Models/SharedModelContainer.swift:24` | `appGroupID` — dieselbe Suite, die `ReceiptShareHandoff` nutzt. |

## Existing Patterns
- **DEBUG-Startargument mit Seed** (`-seedSharedAssignmentForScreenshots`, `-premiumForScreenshots`): `ProcessInfo.processInfo.arguments.contains(...)`, `#if DEBUG`, alle Läden vorher löschen (App-Group-Store überlebt Testläufe), dann anlegen und `save()`. Genau dieses Muster für `-seedReceiptReviewForUITests` (Name aus der #23-Spec).
- **Onboarding überspringen** ohne App-Code: `-hasCompletedOnboarding YES` (Argument-Domain der UserDefaults).
- **Handoff = App-Group-UserDefaults**, konsumiert einmalig in `checkPendingReceiptScan()` — der Seed muss die Nutzlast **vor** dem ersten `checkPendingReceiptScan()` ablegen; `init`-`defer` liegt sicher davor.
- **UI-Tests keyen auf sichtbaren Text**, es gibt bisher **null** `accessibilityIdentifier` im Produktcode (`grep` = 0 Treffer). #28 führt die ersten ein — sparsam, damit Copy-Änderungen den Test nicht mehr brechen.
- **Zeilen-Nachauflösung** beim Handoff (`reResolveAIIfNeeded`) ist bestehendes Verhalten und darf nicht umgangen werden — die Fixture muss damit leben.

## Dependencies
- Upstream (wird benutzt): `ReceiptShareHandoff.store`, `SharedReceiptPayload`/`ResolvedReceiptLine`/`ReceiptSuggestion`, `Store(name:emoji:colorHex:)`, `ShoppingItem(name:quantity:unit:store:)`, `ModelContext`.
- Downstream (nutzt unseren Code): `HomeView.checkPendingReceiptScan()` (unverändert), `ReceiptScannerView` (nur IDs), #23-Workflow (`ReceiptReviewUITests.swift` wird dort erweitert; RED-Test aus #28 wird dort grün), CI-UI-Test-Job.

## Existing Specs
- `docs/specs/views/receipt-review-card.md` — Spec zu #23; nennt #28 als Voraussetzung, den Argument-Namen `-seedReceiptReviewForUITests` und das Grundgerüst `RestockUITests/ReceiptReviewUITests.swift`. Die dort geplanten neun UI-Tests bauen auf den IDs aus #28 auf → ID-Namen in #28 so wählen, dass #23 sie unverändert nutzen kann.
- `docs/specs/testing/ui-test-language.md` — Testsprache Deutsch ist im Scheme fixiert.
- `docs/context/feat-23-receipt-review-screen.md` — Tabelle „Lieferung A" (≈ +170 LoC, 3 Dateien) und Fixture-Anforderungen: eine KI-aufgelöste Zeile, ein langer Name, ≥3 Vorschläge, eine Mengen-Zeile (#9).

## Risks & Considerations
1. **Nachauflösung verändert die Fixture.** `reResolveAIIfNeeded` schickt jede Zeile mit `name == originalName && !resolvedByAI` erneut durch Stufen 1–5. Stufe 5 (Apple Intelligence) ist im Simulator nicht verfügbar → übersprungen; Stufen 1–4 laufen aber: Abkürzungs-Wörterbuch und Fuzzy-Match gegen den geseedeten Laden. Fixture-Zeilen, die unverändert bleiben sollen, brauchen `name != originalName` oder `resolvedByAI == true`, oder einen Rohnamen, den das Wörterbuch nicht kennt. Wird in der Analyse festgelegt und im Test belegt.
2. **`resolvedByAI` in der Nutzlast ist nur ein Flag** — die Fixture kann „KI-aufgelöst" setzen, ohne dass ein Modell läuft. Das ist gewollt (deterministisch) und reicht für die Darstellung der KI-Marke.
3. **`storeID` muss den geseedeten Laden treffen**, sonst greift der Besuchsfrequenz-Notnagel und das Banner „Laden nicht sicher erkannt" erscheint; `storeConfidentlyDetected: true` setzen, damit „Speichern" nicht durch `storeNeedsConfirmation` gesperrt ist.
4. **Zustand überlebt Testläufe** (App-Group-Store + Handoff-Key). Seed muss Läden wischen (wie das Vorbild) und den Handoff-Key jedes Mal frisch setzen; ein liegengebliebener Key aus einem Abbruch wird durch `store(...)` überschrieben.
5. **Vierte Datei nötig:** Das Issue nennt 3 Dateien, `project.pbxproj` (Registrierung der neuen UI-Test-Datei an 4 Stellen) kommt hinzu → 4 Dateien, innerhalb des Limits.
6. **RED-Test für #23 muss am heutigen Layout fehlschlagen, der Grundgerüst-Test bestehen** — zwei Tests mit gegensätzlichem Sollzustand in derselben Datei; der RED-Test bleibt bis #23 rot (CI!). In der Analyse klären, wie der Lauf für #28 trotzdem „grün" abgenommen werden kann (z. B. RED-Test erst in #23 einchecken oder in #28 als bewusst rot dokumentiert — PO-/Prozessfrage).
7. **`-hasCompletedOnboarding YES` bleibt nötig**, sonst zeigt `OnboardingGate` die `OnboardingView` und `HomeView` (mit `checkPendingReceiptScan`) erscheint nie.
8. **Simulator-Läufe nie parallel** (Memory `ui-test-nachweis-laeufe`), Diagnose-Hänger nach 10 min bekannt (Issue #21).

## Analysis

### Type
Feature (Test-Infrastruktur: deterministischer Einstieg in den Bon-Prüf-Screen; keine sichtbare
Änderung am Produkt außer unsichtbaren `accessibilityIdentifier`s → kein Entwurf/Mockup nötig).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/SmartCartApp.swift` | MODIFY | Neuer DEBUG-Seed `seedReceiptReviewForUITestsIfNeeded(context:)` direkt neben dem Screenshot-Seed (Aufruf im `init`-`defer` Z. 28–30, Definition nach Z. 182). Wischt alle Stores, legt „Lidl" + Artikel an, `save()`, dann `ReceiptShareHandoff.store(payload)` mit `storeID = store.id`, `storeConfidentlyDetected: true`. ≈ +50 LoC |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `ForEach` Z. 425 reicht den Index an `ReceiptLineRow` durch; IDs auf den Blatt-Views: Name-`TextField` → `receiptReview.line.<i>.name`, Preis-`TextField` → `….price`, KI-`Label` → `….aiMark`; Toolbar-Button Z. 237 → `receiptReview.saveButton`. **Kein** `originalName`-Element (das ist die Lücke, die der RED-Test belegt). ≈ +20 LoC |
| `RestockUITests/ReceiptReviewUITests.swift` | CREATE | Launch mit `-hasCompletedOnboarding YES -seedReceiptReviewForUITests`; `testReviewSheetOpensFromShareHandoff` (Titel „Bon scannen — Lidl", alle Zeilen per ID sichtbar, Speichern hittable) + `testOriginalReceiptTextIsVisibleOnEveryLine` (RED für #23, in `XCTExpectFailure(strict)`). ≈ +100 LoC |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung an 4 Stellen (Vorlage `ReceiptShareExtensionTests.swift`: Z. 139 PBXBuildFile, 298 PBXFileReference, 592 PBXGroup, 918 Sources). 4 Zeilen, 2 neue UUIDs |

Nicht angefasst: `HomeView.swift` (echter Konsumpfad bleibt), `ReceiptShareHandoff.swift`,
`ReceiptResolutionService.swift`, `project.yml` (enthält kein RestockUITests-Target; die
bestehenden UI-Test-Dateien leben nur im eingecheckten pbxproj — gleiches Vorgehen hier).

### Scope Assessment
- Files: 4 (3 aus dem Issue + pbxproj)
- Estimated LoC: +≈170 / −≈2
- Risk Level: LOW — rein additiv (DEBUG-Argument, unsichtbare IDs, neue Testdatei); einziger
  Eingriff in bestehendes Verhalten ist die Index-Durchreichung im `ForEach`.

### Technical Approach
1. **Seed über den echten Weg.** Kein Sonderpfad: Nutzlast in App-Group-UserDefaults, `HomeView.
   checkPendingReceiptScan()` konsumiert sie wie nach einem echten Teilen. Alternative „Sheet direkt
   öffnen" verworfen (umgeht Store-Matching/Confidence, also genau die Logik, die #23 braucht);
   Alternative „Nutzlast per Launch-Environment" verworfen (Store/Artikel müssten trotzdem per
   ModelContext geseedet werden — nur mehr Komplexität).
2. **Fixture-Regel (deterministisch):** Jede Zeile hat `resolvedByAI == true` **oder**
   `name != originalName`. Dann liefert `EditableReceiptLine.linesNeedingAIReresolution` eine leere
   Menge und `reResolveAIIfNeeded()` (Z. 285–295) läuft gar nicht — kein Wörterbuch, kein
   Fuzzy-Match, kein gelernter Alias aus App-Group-UserDefaults früherer Läufe kann den Bon verändern.
   `suggestions` und `matchedItemID` kommen fertig aus der Nutzlast (IDs der soeben angelegten
   Artikel) — deshalb Artikel **vor** dem Bauen der Nutzlast anlegen.
   Vorschlag fester Bon (4 Zeilen, Spec legt Wortlaut fest):
   - Z0 KI-Zeile: `MILCH 3,5% FRISCH` → „Frische Vollmilch 3,5 %", `resolvedByAI: true`, 1,19 €
   - Z1 langer Name (≥ 40 Zeichen): `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` → „Bio-Hackfleisch
     gemischt Rind & Schwein 400 g", `matchedItemID` = Hackfleisch, 4,99 €
   - Z2 ≥ 3 Vorschläge: `MILCH` → „Milch", suggestions: Hafermilch, Buttermilch, Vollmilch, 0,99 €
   - Z3 Mengen-Zeile (#9): `BROETCHEN` → „Brötchen", `quantity: 4`, 1,56 € (Detailzeile „4 × 0,39 €")
   Seed-Artikel (alle offen, nicht abgehakt): Milch, Hafermilch, Buttermilch, Vollmilch,
   Hackfleisch, Brötchen. `rawLines` = die vier `originalName`s, `detectedTotal` = Summe.
3. **IDs nach #23-Schema** (`docs/specs/views/receipt-review-card.md` Z. 241–260): Präfix
   `receiptReview.line.<index>.` mit `name`, `price`, `aiMark`; Speichern `receiptReview.saveButton`.
   Index-Durchreichung per `ForEach(Array($parsedLines.enumerated()), id: \.element.id)` (behält
   die Zeilen-Identität; `indices`/`\.self` wäre die knappere Alternative). Identifier auf den
   Blatt-Views, nicht auf umgebenden Stacks — `ChipToolbarItem` ist ein reiner `ToolbarItem`-Wrapper,
   der Identifier am `Button` kommt durch.
4. **RED-Test ohne rote CI:** `testOriginalReceiptTextIsVisibleOnEveryLine` prüft
   `receiptReview.line.<i>.originalName` für jede Zeile — existiert heute nicht → schlägt fehl. Um
   die CI von #28 grün zu halten, steht die Prüfung in `XCTExpectFailure("Bontext erst mit #23
   sichtbar", strict: true)`. `strict` sorgt dafür, dass #23 die Erwartung entfernen **muss**, sonst
   wird der Test dort wieder rot. Verworfen: `XCTSkip` (im Repo für „Vorbedingung fehlt" belegt,
   würde die Lücke im CI-Log verstecken) und „RED-Test erst in #23" (kein automatisierter Nachweis
   der Lücke vor #23). Die beiden weiteren #23-Kriterien („Name vollständig", „KI-Marke einzeilig")
   sind per Accessibility nicht messbar (TextField-`value` ist immer der volle Text) — sie bleiben
   den Frame-Prüfungen der #23-Spec vorbehalten; #28 belegt die Lücke über den Bontext.
5. **Nachweis statt Handprüfung:** Der Grundgerüst-Test ist der Beweis, dass der Seed greift; ein
   Lauf ohne `-seedReceiptReviewForUITests` (bestehende `RestockUITests`) beweist, dass der Seed
   sonst nichts tut.

### Dependencies
- Upstream: `ReceiptShareHandoff.store(_:)` (Z. 12–15), `SharedReceiptPayload` (Z. 29–43),
  `ResolvedReceiptLine`/`ReceiptSuggestion` (ReceiptResolutionService Z. 8–44), `Store.init(name:
  emoji:colorHex:)`, `ShoppingItem.init(name:quantity:unit:store:)`.
- Downstream: `HomeView.checkPendingReceiptScan()` (Z. 1565–1583, unverändert), `.sheet(item:)`
  (Z. 194–196), `ReceiptScannerView.init(store:prefilled:storeConfidentlyDetected:)`,
  #23-Workflow (erweitert `ReceiptReviewUITests.swift`, entfernt `XCTExpectFailure`), CI-Job
  `ui-test` (`-only-testing:RestockUITests`, neue Datei läuft automatisch mit).
- Reihenfolge: Seed → Index+IDs → pbxproj-Registrierung → Testdatei → Lauf auf frischem Simulator
  (nie parallel zu anderen Simulator-Läufen, Memory `ui-test-nachweis-laeufe`).

### Open Questions
- [ ] Keine PO-Fragen. Technische Festlegungen (Fixture-Wortlaut, `XCTExpectFailure`, ID-Schema)
      werden in `/30-write-spec` ausformuliert.
