---
entity_id: ai-price-estimation
type: module
created: 2026-10-22
updated: 2026-10-22
status: draft
version: "1.0"
tags: [pricing, services, ai, issue-164]
---

# KI-Preisschätzung als Stufe vor der Kategorie-Pauschale (aus bis zum Nachweis)

## Approval

- [ ] Approved

## Ziel (Issue #164, Entscheidungen des Tech Leads vom 2026-10-19)

Für Artikel, für die eigene Preise, Community (#163) und Katalog (#162) nichts liefern (heute
`priceSource == "category"`, Zeile „Preis?“), schätzt das Gerätemodell (`FoundationModels`, iOS 26+)
typische Packung und Preisspanne. Regeln bleiben Code, das Ergebnis wird je Namensschlüssel
zwischengespeichert, die Zeile zeigt „ca. 2,40 € · KI-Schätzung“ in der Warnfarbe, das
Bearbeiten-Sheet Spanne und Packung mit „Stimmt so“. **Die Stufe ist aus**, bis der Nachweis gegen den
Prüfsatz bestanden ist (Gate ≥ 70 % innerhalb ±30 %); bis dahin nur Schalter im Entwicklermodus.

## Quelle

- `SmartCart/Services/AIPriceEstimationService.swift` (nur App-Ziel):
  - `AIPriceRequest` (Name, Menge/Einheit, Kategorie, Land, Währung; `cacheKey` = Artikelschlüssel|Bezugsgröße),
    `AIPriceGuess` (Packung, low/typical/high), `PriceLanguageModel` (Naht), `SystemPriceLanguageModel`
    (`@Generable AIPriceGuessGenerable`, greedy, 20 s echte Zeitgrenze über `withRealTimeout`),
  - `AIPriceEstimation` (Schlüssel `aiPriceEstimationEnabled`, Standard aus; `validate` = Regeln;
    `maximumRangeFactor` 3; `retryAfterDays` 30; `maximumCallsPerFill` 8),
  - `AIPriceCache` (App-Gruppe, `aiPrices.v1`, Treffer und Fehlversuche mit Datum),
  - `AIPriceEstimationService` (`fill(store:)`, `applyCache`, `apply`, `confirm`, `isCandidate`).
- `SmartCart/Models/ShoppingItem.swift` — `knownPriceSources` + `"ai"`, `PriceSourceDisplay.text` „KI-Schätzung“,
  `amountPrefix` „ca. “ auch für `ai`, Schlüsselliste.
- `SmartCart/Views/Components/ItemRow.swift` — Warnfarbe auch für `ai`.
- `SmartCart/Views/Store/EditItemView.swift` — Abschnitt „KI-Schätzung“ (`editItem.aiRange`, `editItem.aiConfirm`),
  `aiRangeText(for:cache:locale:)`.
- `SmartCart/Views/Store/StoreDetailView.swift` — `.task`: nach `CommunityPriceService.refreshAndApply` → `fill`.
- `SmartCart/Views/Settings/SettingsView.swift` — Entwickler-Abschnitt: Schalter „KI-Preisschätzung“ mit Fußnote.
- Texte: `price.source.ai`, `item.price.ai.section`, `item.price.ai.range`, `item.price.ai.confirm`,
  `settings.dev.aiPrice`, `settings.dev.aiPrice.footer` (de/en).

## Regeln (`AIPriceEstimation.validate`)

1. Spanne: 0 < low ≤ typical ≤ high und high/low ≤ 3 (Entscheidung 2), sonst verworfen.
2. Packung: Einheit g/ml/stk (kg/l werden auf g/ml umgerechnet, Wortformen normalisiert), Menge > 0.
3. Bezugsgröße: Gewichts-/Volumenartikel (`unitBucket == "g"`) brauchen eine Gewichts-/Volumenpackung
   (Entscheidungstabelle aus #10), sonst verworfen.
4. Rate je Einheit über `PriceCatalog.perUnitPrice` (gleiche Umrechnung wie der Katalog); Gesamtpreis der
   Zeile ≤ `PriceEstimator.maxPlausibleLineTotal` (30 €), sonst verworfen.
5. Verworfen oder keine Antwort → Pauschale bleibt, der Schlüssel ist 30 Tage gesperrt.

## Ablauf

- Beim Öffnen der Liste: Community zuerst, dann `fill`: Zwischenspeicher immer anwenden (auch bei
  ausgeschalteter Stufe), Modell nur mit Schalter und verfügbarem Modell, höchstens 8 Aufrufe je Öffnung,
  gleiche Namen einmal. Kandidaten: offen, automatisch hergeleitet, Quelle `category`, `ai` oder ohne Preis.
  Community- und Katalogartikel sowie eigene Preise werden nie angefasst; ein späterer Community-Wert
  ersetzt den KI-Wert (`CommunityPriceService.apply` läuft über alle automatisch hergeleiteten Preise).
- „Stimmt so“ (Entscheidung 3): `priceSource = "manual"`, `estimatedPriceIsAutoDerived = false`, ohne Netz.
- Was das Gerät verlässt: nichts (Gerätemodell). Prompt enthält Name, Menge/Einheit, Kategorie, Land,
  Währung — keinen Laden, keinen Nutzernamen, keine Historie (`testPromptCarriesOnlyHarmlessFields`).

## Nachweis (Entscheidung 4)

`RestockTests/AIPriceEvaluationTests.swift` (ganz in `#if AI_EVAL`), `scripts/run-ai-price-eval.sh [runtime]`
(Sperren, Wegwerf-Simulator `Restock-AIPriceEval-<zeit>`, Bericht nach `docs/artifacts/test-164-ai-price-eval/`):
Prüfsatz 100 Katalogartikel (jeder n-te Eintrag ohne Alt-Stichwörter, nur ≤ 30 €), Referenz Katalogwert
auf gleicher Packungsbasis; Kennzahlen angenommen, vergleichbar, innerhalb ±30 %, Ø/Median-Fehler, Ausreißer
(> Faktor 3), Timeouts, Ø s; Gate: ≥ 70 % angenommen UND ≥ 70 % innerhalb ±30 %. Erst nach einem
bestandenen Lauf auf dem Mac wird `isEnabledDefault` auf `true` gesetzt (eigener PR mit dem Bericht).
Echte Bonpreise als zweite Referenz: offen (die Testbons tragen Kürzelnamen; Zuordnung in der Messung
wäre handgepflegt und ist im Bericht als Folgeschritt vermerkt).

## Tests

`RestockTests/AIPriceEstimationTests.swift`: R1–R6 Regeln, C1–C3 Zwischenspeicher, S1–S6 Dienst mit
Schein-Modell (Standard aus → kein Aufruf; nur Pauschal-Artikel; Zwischenspeicher spart den zweiten
Aufruf; verworfene Antwort sperrt; nicht verfügbares Modell; Obergrenze je Öffnung; Community vor KI),
D1–D3 Anzeige, „Stimmt so“, Sheet-Text; Prompt-Inhalt.

## Offene Grenzen

- Nachweislauf nur auf einem Mac mit Apple Intelligence (nicht in dieser Umgebung, nicht in CI); bis dahin
  Standard aus. Ergebnis des Gates entscheidet über das Einschalten, nicht dieser PR.
- Die Stufe läuft nicht in `ShoppingItem.init` (Widget, Siri, Teilen-Erweiterung): neue Artikel zeigen
  „Preis?“, bis die Liste in der App geöffnet wird; `fill` läuft nur dort.
- Ein Einheitenwechsel im Bearbeiten-Sheet setzt einen KI-Preis auf die Pauschale zurück
  (`applyPriceEdit` rechnet automatisch hergeleitete Preise neu); die nächste Öffnung füllt ihn wieder.
- `@Generable`/`@Guide` nur mit Beschreibung (keine Wertebereiche), die Prüfung liegt vollständig in
  `validate`; Cloud-Modell nicht gebaut (eigenes Issue nach dem Nachweis).
- Nichts auf Hennings Geräten geprüft.
