# Restock (SmartCart) Backlog

## Implementiert

### EU AI Act Art. 50 — geprüft, kein Änderungsbedarf (2026-08-06)
Im Zuge einer App-übergreifenden EU-AI-Act-Prüfung (siehe auch `~/Developer/Lumio/BACKLOG.md` für die Sunwake-Änderungen) auch Restock durchleuchtet:
- `RecipeRecognitionService.swift` (Vision OCR + Apple Intelligence, Rezept-Foto → Zutaten): extrahiert echten Text aus einem fotografierten Rezept, keine Inhaltserzeugung — kein Art.-50(2)-Fall. `RecipeImportView.swift` sagt dem Nutzer ohnehin schon vorher „Restock erkennt die Zutaten automatisch".
- `MealIngredientService.aiIngredients(for:)` (gleiche Datei): der einzige wirklich *generative* Pfad — aus einem reinen Gerichtsnamen erfindet die KI eine plausible Zutatenliste. Hat aber bereits einen Vorab-Hinweis in `MenuPlanView.swift` (Footnote „Apple Intelligence erkennt Zutaten automatisch", String-Key `menuplan.aihint`, erscheint bevor der Nutzer die Funktion auslöst) — als ausreichend bewertet.
- `ReceiptParserService.swift` → `ReceiptNameAIResolver.expand(_:)`: erweitert abgekürzte Zeilen von echten gescannten Kassenbons — Erweiterung realer Daten, keine Erfindung, kein Art.-50-Fall.
- Kein Chat-/Konversations-Feature vorhanden.

**Fazit:** keine Code-Änderung nötig.

## Offen

### Optional: sichtbares Label für KI-generierte Menüplan-Zutaten
**Priorität:** Niedrig, optional
`MealIngredientService.ingredients(for:)` gibt bereits ein `Source`-Enum (`.ai`/`.database`/`.none`) zurück, das anzeigt, ob eine Zutatenliste von der KI erfunden oder aus der lokalen Datenbank kommt — wird aktuell aber vom Aufrufer (`MenuPlanView.ingredientsWithHardTimeout`) verworfen und nirgends als sichtbares Label genutzt. Der Vorab-Hinweis (`menuplan.aihint`) deckt die Art.-50-Pflicht schon ausreichend ab, ein Inline-Label auf der Ergebnisliste wäre nur ein Nice-to-have.

Falls das später nachgerüstet werden soll: `MealIngredient` (in `MenuPlanView.swift`) um ein **optionales** `var isAISuggested: Bool? = nil` erweitern (bewusst `Bool?`, nicht `Bool` — sonst bricht die synthetisierte `Codable`-Konformität beim Decodieren bereits gespeicherter `ingredientsMap`-JSON-Daten, die das Feld noch nicht kennen). Flag in `MealIngredientService.aiIngredients`s JSON-Parsing-Pfad setzen, dann in der Zutatenliste um `MenuPlanView.swift:866` (`ForEach(recipe.ingredients...)`) anzeigen.
