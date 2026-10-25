# Context: feat-221-nonfood-kategorien

## Request Summary
PO (2026-10-25): „Die bestehenden Kategorien funktionieren ganz gut für Lebensmittelmärkte aber nicht für
Baumärkte oder Drogerie-Märkte. Analysiere das Angebot von DM und Hornbach (und anderen). Welche
zusätzlichen Kategorien brauchen diese Märkte? Lege sie an. Lerne auch etwas über die Artikel, das dir als
abstraktes Wissen dienen kann.“ Issue #221.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/AssignmentService+Category.swift` | Feste Kategorien (`categoryOrder`, 26), Anzeige (`displayCategory`), Emoji (`categoryEmoji`), Lebensmittel-Stichwörter (`categoryMap`, 432, von `PriceCatalogTests` gezählt — unverändert), `category(for:)` mit den drei Ladentyp-Listen und `detect*`-Fallbacks. Kompiliert in App, Widget und Teilen-Erweiterung. |
| `SmartCart/Services/AssignmentService+NonFoodCategories.swift` | **Neu:** Warenkunde `nonFoodCategoryMap` (Stichwörter → Kategorie → Ladentyp), `nonFoodCategoryEndings`, `nonFoodMatch`, `nonFoodCategoryByEnding`, `nonFoodStoreGroup`, `nonFoodCategoriesAddedIn221`. Gleiche drei Ziele. |
| `SmartCart/Services/AssignmentService.swift` | `assignDetailed`: Ladentyp-Erkennung (`isHardware/isVariety/isDrugstore`) jetzt zuerst aus der Warenkunde. |
| `SmartCart/Models/Store.swift` | `Category.drugstore`/`.hardware` (Ladentyp-Etiketten, auch Auswahl in `AddCustomStoreView` und `DefaultStoresSettingsView`). |
| `SmartCart/Models/ShoppingItem.swift` | `PriceEstimator.categoryFlatRate` — Pauschale je Kategorie, muss jede Kategorie aus `categoryOrder` kennen. |
| `SmartCart/Models/StoreCategories.swift` | Emoji-Vorschläge und -Auswahl für eigene Kategorien. |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `category.*`-Schlüssel; `LocalizationKeyParityTests` erzwingt Gleichstand. |
| `Restock.xcodeproj/project.pbxproj` | Neue Quelle in drei Sources-Phasen (App `B10ADA3F…`, Widget/Erweiterung `B823CC6E…`, `67BDC10E…`), neuer Test in `E4CC99CA…`. |
| `RestockTests/PriceEstimatorCategoryFallbackTests.swift` | Zählte 26 Kategorien und Pauschalen. |
| `RestockTests/PriceCatalogExpansionTests.swift` | Zählt `drugstoreKeywords` (100) — Liste bleibt unverändert, Ladentyp kommt zusätzlich aus der Warenkunde. |
| `RestockTests/AssignmentServiceTests.swift` | Nutzt Milch, Hackfleisch, Nudeln, Bohrmaschine — Verhalten unverändert (Bohrmaschine → hardware). |

## Existing Patterns
- Rohwerte deutsch, persistiert in `ShoppingItem.category`; Anzeige über `String(localized:)`, nie übersetzen.
- Längstes Stichwort gewinnt (`categoryMap` seit dem „weingummi“-Fix); Teilstring-Treffer, kleingeschrieben.
- Ladentyp-Gruppen `grocery/drugstore/variety/hardware` in `assignDetailed`, Standard-Laden je Gruppe (`DefaultStoreService`).
- Neue Swift-Dateien: vier Stellen im pbxproj, 24-stellige Hex-IDs (`C0DE1221…`).

## Dependencies
- Upstream: `categoryMap` (Lebensmittel), `PriceEstimator`, `StoreCategories`.
- Downstream: `Store.pendingItems` (Widget-Sortierung), `ShoppingRoute.orderedCategories` (statische Reihenfolge), `CategoryPickerView` (`categoryOrder`), `AddCustomStoreView`/`DefaultStoresSettingsView` (`Category.*`), `CatalogEstimateRefresh.priceCategory` (prüft `categoryOrder.contains`).

## Risks & Considerations
- Bestehende Artikel ohne von Hand gesetzte Kategorie wechseln sichtbar das Regal (gewollt); gelernte Kategorie-Reihenfolgen kennen neue Regale nicht (statische Reihenfolge greift).
- Teilstring-Fallen: siehe `docs/context/warenkunde-drogerie-baumarkt.md` Abschnitt 3; Python-Nachbildung in `docs/artifacts/feat-221-nonfood-kategorien/` vor dem CI-Lauf.
- Kein Xcode in der Cloud: Nachweis ist der CI-Lauf.
