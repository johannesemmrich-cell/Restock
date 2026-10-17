# Context: fix-151-price-source (Issue #151)

## Request Summary
Die Artikelzeile zeigt eine reine Kategorie-Schätzung („Seitan“ bei DM: 2,90 € = Pauschale „Lebensmittel“) genauso an wie einen echten Bonpreis. Jeder Preis soll seine Quelle tragen (Bon mit Datum, bezahlt, gelernt, eigener Preis, Schätzung mit „ca.“), dazu im Dev-Modus eine Diagnose, warum ein gelernter Bonpreis greift oder verworfen wird. Umfang ~450 Zeilen in einem Durchgang vom PO freigegeben (2026-10-17).

## Ursache (Code)
- `SmartCart/Models/ShoppingItem.swift:468` — `PriceEstimator`, Kategorie „Lebensmittel“ = 2,90 € je Stück.
- `SmartCart/Models/ShoppingItem.swift:182-183` — `init` nimmt gelernten Preis oder Schätzung; Herkunft nur als Bool `estimatedPriceIsAutoDerived` (true = Schätzung, false = „irgendwie echt“). Bon, bezahlt, manuell, gelernt sind nicht unterscheidbar.
- `SmartCart/Views/Components/ItemRow.swift:153-160` — Preis wird ohne jede Herkunftsangabe gerendert.
- Keine Verschlechterung: Eine Unterscheidung gab es nie.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Models/ShoppingItem.swift` | neue Felder `priceSource`, `priceSourceDate`, berechnetes `priceOrigin`; `init` setzt Quelle (Zeile ~120-183); `learnedRateUsage` (Entscheidungstabelle, Basis der Diagnose); `matchingLearnedPriceKey`; Obergrenze `PriceEstimator.maxPlausibleLearnedLineTotal`; `PriceProvenanceMigration` (setzt nur das Bool, läuft einmalig) |
| `SmartCart/Models/Store.swift` | neues Feld `learnedPriceOrigins: [String: String]` neben `learnedPrices`/`learnedPriceDates`/`learnedPriceUnits` (Zeile 30-52, init 137-139) |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | `ReceiptLearning.apply` (Zeile ~263) und `save()` (Zeile ~754) — Quelle `receipt` + Datum |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | `apply(itemActualTotal:to:)` (Zeile ~153) — Quelle `paid` |
| `SmartCart/Views/Store/EditItemView.swift` | `save()` Zeile ~401-420: manueller Preis → `manual`, leeres Feld → Zurücksetzen → `estimate`; Ort für Dev-Diagnose (Formular-Sections, `@AppStorage("developerMode")`) |
| `SmartCart/Models/LegacyLearnedPriceReset.swift` | setzt auf Schätzung zurück → `estimate` |
| `SmartCart/Services/SharedStoreService.swift` | `LearnedPriceSync.apply` (Zeile ~594): Sync überschreibt lokale gelernte Preise → Herkunftseintrag entfernen, außer gleicher Preis |
| `SmartCart/Views/Components/ItemRow.swift` | Anzeige der Quelle unter dem Preis, „ca.“ bei Schätzung |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | neue Texte |
| `SmartCart/SmartCartApp.swift:395` | UI-Test-Seed setzt `estimatedPriceIsAutoDerived = false` (Altdaten-Ableitung greift → „gelernt“) |
| `RestockTests/*Price*`, `ReceiptLearningTests`, `LearnedPriceSyncTests`, `LegacyLearnedPriceResetTests` | bestehende Tests, neue Unit-Tests daneben |
| `CLAUDE.md` | Absatz zur Preisquelle |

## Existing Patterns
- Additive SwiftData-Felder mit Standardwert ohne Schema-Bump (`estimatedPriceIsAutoDerived`, `quantitySource`, `learnedPriceUnits`), CloudKit-tauglich.
- String-Kennungen statt Enums in Modellen (`quantitySource` = "user"/"history"/"package"/"none"), Logik als statische Funktionen (`learnedRateUsage`, `unitBucket`) für direkte Testbarkeit.
- „Annahme sichtbar“: `ItemRow` markiert angenommene Mengen bereits mit „ca. 400 g“ in Warnfarbe (Zeile ~95-99).
- Store-Dictionaries je Schlüssel (`name.lowercased()`), Sync-Merge per Zeitstempel in `LearnedPriceSync`.

## Dependencies
- Upstream: `PriceEstimator`, `Store.learnedPrices*`, `learnedRateUsage`, `unitBucket`, `matchingLearnedPriceKey`.
- Downstream: Alle Erzeuger von `ShoppingItem` laufen über `init` (Quick-Add, Siri, Widget, Share Extension, SyncCoordinator:321, MenuPlan, Rezepte) → Quelle wird dort automatisch richtig. Artikel-Sync geteilter Läden überträgt keine Preise (nur Name/Menge/Einheit/Notiz).

## Existing Specs
- `docs/specs/models/learned-price-unit-and-quantity-source.md` — Entscheidungstabelle gelernter Preise (Diagnose-Gründe „Einheit passt nicht“, „Altdatum ohne Bezugsgröße“)
- `docs/specs/models/legacy-price-reset-migration.md`
- `docs/specs/models/price-estimator-category-fallback.md`, `price-estimator-stages.md`
- `docs/specs/models/shopping-item-fuzzy-price-match.md`

## Risks & Considerations
- **CloudKit-Produktionsschema:** neue Felder an `ShoppingItem` und `Store` (privater Spiegel) müssen vor dem nächsten TestFlight-Upload deployt werden (cktool, siehe Memory).
- **UI-Tests auf Preistext:** Bestehende Tests prüfen per `CONTAINS` („0,99“, „/100 g“, „€“) → „ca.“-Präfix und Quellzeile brechen sie nicht. `AddItemQuantitySuggestionUITests` prüft `staticTexts["ca. 400 g"]` exakt (Menge) — Preis-„ca.“ muss ein eigener Text bleiben, keine Verwechslung.
- **Zwei „ca.“ in einer Zeile** (Menge angenommen + Preis geschätzt) — Lesbarkeit im Entwurf prüfen.
- **Altdaten:** `priceSource == ""` → Ableitung aus Bool; „Bon“ nie aus Altdaten (Bool false kann auch manuell/bezahlt sein → neutral „gelernt“).
- **Abgehakte Artikel** zeigen heute nur echte Preise (`!estimatedPriceIsAutoDerived`); das bleibt, Quelle kommt dazu.
- **Sync-Überschreiben:** Wenn ein Mitglied eines geteilten Ladens einen neuen Preis schickt, stimmt die lokale Herkunft nicht mehr → Eintrag in `learnedPriceOrigins` entfernen (dann „gelernt“), außer gleicher Preis.
- **Dev-Diagnose** braucht dieselbe Entscheidungskette wie `init` (Schlüssel, Obergrenze, `learnedRateUsage`) — als reine Funktion herausziehen, sonst laufen Anzeige und Wirklichkeit auseinander.
- Scope über Limit, vom PO freigegeben.

## Analysis

### Type
Feature (Preisherkunft sichtbar machen). Ein Bug im engeren Sinn liegt nicht vor: Eine Unterscheidung gab es nie, also auch keine Verschlechterung.

### Reproduktion (2026-10-17)
Simulator Restock-Validate, aktueller Stand, Seed `-seedLegacyLearnedPriceForUITests`, Lauf von `LegacyLearnedPriceResetUITests` (1 Test, 0 Fehler) mit Bildschirmfoto-Poller. Im Laden „Altbon“ zeigen „Laugenbrötchen groß“ (Schätzung, `estimatedPriceIsAutoDerived` = 1) und „Kontrollbrot“ (manuell, = 0) beide „2,50 €“ ohne jeden Unterschied. Die DB-Abfrage bestätigt die Werte. Foto: `docs/artifacts/fix-151-price-source/heute-liste.png`.

### Recherche
- Neue SwiftData-Eigenschaft mit Standardwert = leichte Migration, kein neues VersionedSchema; CloudKit verlangt optional oder Standardwert (hackingwithswift „lightweight vs complex migrations“, donnywals „deep dive SwiftData migrations“, Apple-Forum 764236).
- `[String: String]` am Laden ist schon erprobt (`learnedPriceUnits`, synchronisiert in Produktion). Die CloudKit-Produktionsschemata müssen vor dem nächsten Upload veröffentlicht werden (cktool).

### Entwurf (vor Spec)
Artefakt: https://claude.ai/artifact/43nw7ZKwMdoTFiq9zjN919 (Quelle `docs/artifacts/fix-151-price-source/entwurf.html`).
- A (Empfehlung): zweite kleine Zeile unter dem Betrag: „Bon · 12.10.“, „bezahlt“, „gelernt“, „eigener Preis“, „Schätzung“. Eine Schätzung trägt „ca.“ und dieselbe Warnfarbe wie eine angenommene Menge.
- B: Nur die Schätzung wird markiert (~60 LoC, ohne Migration). Bon und eigener Preis bleiben dabei ununterscheidbar.
- C: Symbol statt Wort. Kein Platz für das Datum, und VoiceOver braucht trotzdem Text.
- Dev-Diagnose im Bearbeiten-Dialog: Eintrag, Bezugsgröße, Obergrenze, Ergebnis mit Grund.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/Models/ShoppingItem.swift | MODIFY | `priceSource`, `priceSourceDate`, berechnetes `priceOrigin` (leer → aus Bool: estimate / learned, nie receipt). Kette aus `init` (:124-183) als reine Funktion `resolveLearnedPrice(...)` mit Grund herausziehen; `init` nutzt sie (inkl. `unitOverride` für `.rateOnly`). Neue Typen in dieser Datei, weil sie in 3 Targets steckt. |
| SmartCart/Models/Store.swift | MODIFY | `learnedPriceOrigins: [String: String] = [:]` |
| SmartCart/Views/Components/ItemRow.swift | MODIFY | Quellzeile unter dem Preis (VStack trailing), „ca.“ im selben Text wie der Betrag, kombiniertes Accessibility-Label; Abgehakt-Regel unverändert |
| SmartCart/Views/Store/EditItemView.swift | MODIFY | manual / estimate beim Speichern; Dev-Diagnose-Abschnitt |
| SmartCart/Views/Prices/ReceiptScannerView.swift | MODIFY | `ReceiptLearning.apply` (:270-275) → receipt + Datum; `save()` (:754-756) → `learnedPriceOrigins[key] = "receipt"` |
| SmartCart/Views/Prices/ActualPriceEntryView.swift | MODIFY | (:163-175) → paid, Origin `paid` |
| SmartCart/Models/LegacyLearnedPriceReset.swift | MODIFY | (:41-43) → estimate |
| SmartCart/Services/SharedStoreService.swift | MODIFY | `LearnedPriceSync.apply` (:594-605): fremder Preis → Origin-Eintrag löschen (außer gleicher Preis); Origins NICHT in den Sync-State |
| SmartCart/Resources/{de,en}.lproj/Localizable.strings | MODIFY | Quelltexte, Diagnosetexte |
| RestockTests/PriceSourceTests.swift | CREATE | Paritätstest init ↔ Resolver (Substring, Fuzzy, Obergrenze, alle Zeilen `learnedRateUsage`), Ableitung Altdaten, Schreibstellen, Sync-Origin |
| RestockUITests/ (bestehender Altbon-Test oder neue Klasse) | MODIFY/CREATE | Schätzung und eigener Preis in der Zeile unterscheidbar |
| CLAUDE.md | MODIFY | Absatz Preisquelle |
| Restock.xcodeproj/project.pbxproj | MODIFY | neue Testdatei(en) registrieren |
`PriceProvenanceMigration` bleibt unberührt: Sie läuft einmalig, und die Ableitung aus dem Bool deckt Altdaten ab.

### Scope Assessment
- Files: ~12 (Produkt 8, Tests 2–3, Doku 1)
- Estimated LoC: ~+450/-30 (Produkt ~260, Tests ~190); vom PO in einem Durchgang freigegeben
- Risk Level: MEDIUM. Die zentrale Preiswahl in `init` wird umgebaut (abgesichert per Paritätstest). Es gibt viele Schreibstellen, und eine vergessene ergibt eine falsche Quelle. CloudKit-Schema.

### Technical Approach
Fünf Quellen am Artikel, Resolver als reine Funktion zuerst (reines Refactoring, bestehende Preistests bleiben grün), dann Felder, Schreibstellen, Anzeige, Diagnose. Origin, Preis und Datum werden immer zusammen geschrieben. `learnedPriceOrigins` bleibt lokal. Ein gesynchter Fremdpreis zeigt deshalb „gelernt“.
Reihenfolge: Spec → Tests rot (Parität, Ableitung, Schreibstellen) → Resolver → Felder → Schreibstellen → ItemRow + Strings → Diagnose → Simulator-Durchlauf „Altbon“ → CloudKit-Schema vor Upload.
Folge-Idee außerhalb des Umfangs: „davon geschätzt“ im Kopf „Geschätzter Betrag“.

### Alternatives
- B „nur Schätzung markieren“ (siehe Entwurf): löst die Verwechslung Schätzung/echt, aber nicht Bon/eigener Preis/Alter.
- Quelle nur aus `learnedPriceOrigins` ableiten, ohne Feld am Artikel: spart Schreibstellen, zeigt aber „Bon“ für einen Artikel, dessen Preis gar nicht vom Bon kam, sobald ein späterer Bon den Laden-Eintrag überschreibt.
- C Symbol statt Wort.

### Dependencies
`PriceEstimator`, `matchingLearnedPriceKey` (fuzzy, Datum als Gleichstand-Brecher), `learnedRateUsage`, `unitBucket`, Obergrenze 200 €. Alle Erzeuger (Quick-Add, Siri, Widget, Share Extension, SyncCoordinator, Menüplan) laufen über `init`, damit wird die Quelle dort automatisch gesetzt.

### Open Questions
- [x] PO (2026-10-17): Bonpreis von einem Mitglied eines geteilten Ladens zeigt „gelernt“; Origins bleiben lokal, Sync-Format unverändert.
- [x] PO (2026-10-17): Entwurf A freigegeben (Quelle unter dem Preis, Schätzung mit „ca.“ in Warnfarbe).
- [x] Fuzzy-Treffer: Die Zeile zeigt die Quelle des Eintrags, die Diagnose nennt den gefundenen Schlüssel (technisch entschieden).
- [x] Altdaten ohne Datum: „gelernt“ statt „Bon“ ohne Datum (technisch entschieden, folgt der Vorgabe „nie Bon aus Altdaten“).
