# Restock (SmartCart) Backlog

## Implementiert

### Bon-Parser: Stückzahl/Gewicht aus Bestätigungszeilen (Issue #9, 2026-09-22)
`droppingRedundantQuantityConfirmationLines` löschte Mengen-/Gewichts-Bestätigungszeilen ("4 Stk x 0,39", "0,706 kg x 2,49 EUR/kg") unter einer Rewe-Positionszeile mit eigenem Gesamtpreis ersatzlos — beim Preis-Lernen (`ReceiptScannerView.save()`) wurde dadurch der volle Zeilen-Gesamtpreis statt des Stück-/Gramm-Preises gelernt (z. B. 1,56 € statt 0,39 € pro Brötchen).

- **`ReceiptParserService.parseClassic`**: neuer Zweig wertet die Bestätigungszeile jetzt aus und schreibt `quantity`/`weightBasis` der vorangehenden Position zu (Rechenprobe |Menge × Rate − Zeilenpreis| ≤ 0,01), ohne deren Preis zu ändern. Eine reine Bestätigungszeile ohne offene Namenszeile wird immer konsumiert, nie zur eigenen Position (Phantom-Schutz).
- Details, Reproduktion und Test-Nachweis: `docs/specs/services/receipt-parser-quantity-confirmation.md`.

### "Zeit zum Nachkaufen" einklappbar + Laden-Zuordnung überarbeitet (2026-09-14)
Nutzerbericht: Artikel landeten trotz nie dort getätigter Käufe immer bei Rewe statt beim tatsächlich genutzten Lidl.

- **HomeView.swift** (`replenishmentBanner`): Header ist jetzt tippbar (Chevron), Liste einklappbar, Zustand in `@AppStorage("replenishmentCollapsed")` persistiert.
- **AssignmentService.swift**: `bestFallback` entscheidet jetzt primär anhand echter aggregierter Kaufanzahl pro Laden (über alle Artikel, nicht nur namensgleiche) statt anhand der kaum sichtbaren `Store.visitsPerWeek`-Einstellung. `visitsPerWeek` ist nur noch Tie-Breaker bzw. Fallback für Läden ganz ohne Kaufhistorie.
- **Neu: `DefaultStoreService`** (`StoreAssignmentOverrideService.swift`): Nutzer kann in Settings → "Standard-Läden" pro Kategorie-Gruppe (Lebensmittel/Drogerie/Sonstiges/Baumarkt) einen festen Laden festlegen — schlägt die automatische Zuordnung, siehe `preferredDefault(for:among:)` in `AssignmentService.assign`.
- **Neu: `DefaultStoresSettingsView`** (`SettingsView.swift`).

**Bewusst nicht enthalten:** "Sport"-Kategorie-Gruppe (`Category.sports`) — `assign()` hat dafür aktuell gar keine Keyword-Erkennung (Sport-Artikel fallen immer durch auf den Lebensmittel-Fallback), ein Settings-Eintrag dafür wäre wirkungslos gewesen. Bräuchte eigene Sport-Keyword-Liste analog zu `hardwareStoreKeywords`, nicht Teil dieser Änderung.

### Offen (vertagt): Preis-Bug beim Bon-Scan — falscher Preis bei Eiern
Nutzer berichtete (2026-09-14): bei einem gescannten Kassenbon zeigte Restock für Eier 3 € an, obwohl auf dem Bon ein anderer Preis stand. Kein Repro-Material (Bon-Foto/genaue Zahlen) verfügbar — `ReceiptParserService.swift` (1300+ Zeilen) ist bereits sehr fein auf viele dokumentierte Einzelfälle austariert; ein Fix auf Verdacht riskiert, andere bereits gelöste Fälle zu brechen. **Nächster Schritt, sobald der Bug erneut auftritt:** Bon-Foto (oder zumindest die genaue Artikelzeile + echter Preis + Laden) sichern, dann gezielt in `ReceiptParserService.parse`/`parseClassic` nachvollziehen.

**Hinweis (2026-09-22):** Ein möglicher Mechanismus dafür ist mit Issue #9 behoben (Bestätigungszeile "N Stk x Preis" wurde verworfen, Gesamtpreis als Stückpreis gelernt) — ohne Bon-Repro aber nicht bestätigt.

### EU AI Act Art. 50 — geprüft, kein Änderungsbedarf (2026-08-06)
Im Zuge einer App-übergreifenden EU-AI-Act-Prüfung (siehe auch `~/Developer/Lumio/BACKLOG.md` für die Sunwake-Änderungen) auch Restock durchleuchtet:
- `RecipeRecognitionService.swift` (Vision OCR + Apple Intelligence, Rezept-Foto → Zutaten): extrahiert echten Text aus einem fotografierten Rezept, keine Inhaltserzeugung — kein Art.-50(2)-Fall. `RecipeImportView.swift` sagt dem Nutzer ohnehin schon vorher „Restock erkennt die Zutaten automatisch".
- `MealIngredientService.aiIngredients(for:)` (gleiche Datei): der einzige wirklich *generative* Pfad — aus einem reinen Gerichtsnamen erfindet die KI eine plausible Zutatenliste. Hat aber bereits einen Vorab-Hinweis in `MenuPlanView.swift` (Footnote „Apple Intelligence erkennt Zutaten automatisch", String-Key `menuplan.aihint`, erscheint bevor der Nutzer die Funktion auslöst) — als ausreichend bewertet.
- `ReceiptParserService.swift` → `ReceiptNameAIResolver.expand(_:)`: erweitert abgekürzte Zeilen von echten gescannten Kassenbons — Erweiterung realer Daten, keine Erfindung, kein Art.-50-Fall.
- Kein Chat-/Konversations-Feature vorhanden.

**Fazit:** keine Code-Änderung nötig.

## Offen

### Optional: CKShare-Migration für geteilte Listen (Sicherheits-Audit 2026-08-11)
**Priorität:** Niedrig, kein akutes Risiko
Geteilte Listen (`SharedStoreService.swift`, `SharedItemPhotoService.swift`) laufen über CloudKits **public** Database statt über Apples `CKShare`-Mechanismus (teilnehmerbeschränkt). Wer den Einladungscode kennt/errät, kann theoretisch auf den Record zugreifen — je nach CloudKit-Dashboard-Sicherheitsrollen evtl. sogar schreibend.

**Sofortmaßnahme bereits umgesetzt (2026-08-11):** Code-Länge von 6 auf 10 Zeichen erhöht (`SharedStoreService.generateCode()`, `StoreShareSheet.swift`) — ~1,15 Billiarden statt ~1,07 Mrd. Kombinationen, damit ist Erraten/Durchprobieren praktisch ausgeschlossen. Datenschutzerklärung (`LegalView.swift`) korrigiert (behauptete fälschlich, es würden keine personenbezogenen Mitgliederdaten gespeichert — echte Anzeigenamen werden aber gespeichert).

**Bewusst nicht weiterverfolgt:** Die betroffenen Daten (Einkaufslisten-Items, Mengen, Notizen, Vornamen) sind niedrig-sensibel, die App hat keine große Nutzerzahl, und ohne den (jetzt sehr langen) Code kommt niemand an die Daten. Eine vollständige `CKShare`-Migration (teilnehmerbeschränkter Zugriff statt geteiltes Geheimnis) wäre die architektonisch korrekte Lösung, ist aber ein größerer Umbau der Teilen-Logik, der sich nur mit mehreren echten Geräten/Apple-IDs sauber testen lässt — aufgeschoben bis ein triftiger Grund (z. B. deutlich mehr Nutzer oder sensiblere Daten in geteilten Listen) das rechtfertigt.

**Randnotiz:** Bereits vor dem 2026-08-11-Fix aktiv geteilte Listen haben noch den alten 6-stelligen Code — nur "Teilen beenden" + neu starten würde sie auf den langen Code heben, nicht dringend.

### Optional: sichtbares Label für KI-generierte Menüplan-Zutaten
**Priorität:** Niedrig, optional
`MealIngredientService.ingredients(for:)` gibt bereits ein `Source`-Enum (`.ai`/`.database`/`.none`) zurück, das anzeigt, ob eine Zutatenliste von der KI erfunden oder aus der lokalen Datenbank kommt — wird aktuell aber vom Aufrufer (`MenuPlanView.ingredientsWithHardTimeout`) verworfen und nirgends als sichtbares Label genutzt. Der Vorab-Hinweis (`menuplan.aihint`) deckt die Art.-50-Pflicht schon ausreichend ab, ein Inline-Label auf der Ergebnisliste wäre nur ein Nice-to-have.

Falls das später nachgerüstet werden soll: `MealIngredient` (in `MenuPlanView.swift`) um ein **optionales** `var isAISuggested: Bool? = nil` erweitern (bewusst `Bool?`, nicht `Bool` — sonst bricht die synthetisierte `Codable`-Konformität beim Decodieren bereits gespeicherter `ingredientsMap`-JSON-Daten, die das Feld noch nicht kennen). Flag in `MealIngredientService.aiIngredients`s JSON-Parsing-Pfad setzen, dann in der Zutatenliste um `MenuPlanView.swift:866` (`ForEach(recipe.ingredients...)`) anzeigen.
