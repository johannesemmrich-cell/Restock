---
entity_id: price-source-display
type: feature
created: 2026-10-17
updated: 2026-10-17
status: draft
workflow: fix-151-price-source
tags: [feature, price-source, itemrow, swiftdata, cloudkit]
---

# Preisquelle sichtbar (Issue #151)

## Approval

- [ ] Approved — PO-Freigabe der Spec steht aus. Bereits vom PO entschieden (2026-10-17, siehe
  `docs/context/fix-151-price-source.md`, Abschnitt „Open Questions“): Entwurf A (Quelle unter dem
  Preis, Schätzung mit „ca.“ in Warnfarbe); ein Bonpreis, den ein Mitglied eines geteilten Ladens
  schickt, zeigt „gelernt“, die Herkunft bleibt lokal; **Umfang ~+450/−30 Zeilen in einem Durchgang**
  trotz Scoping-Limit (4–5 Dateien, ±250 LoC) ausdrücklich freigegeben, nicht splitten.

## Purpose

Die Artikelzeile zeigt eine reine Kategorie-Schätzung (z. B. „Seitan“ bei dm: 2,90 € = Pauschale
„Lebensmittel“) genauso wie einen echten Bonpreis; der Nutzer kann nicht erkennen, ob er sich auf die
Zahl verlassen kann. Jeder Preis soll seine Quelle tragen: „Bon · 12.10.“, „bezahlt“, „gelernt“,
„eigener Preis“ oder „Schätzung“. Zusätzlich erklärt eine Dev-Diagnose im Bearbeiten-Dialog, warum ein
gelernter Bonpreis greift oder verworfen wird. Eine Verschlechterung liegt nicht vor: Eine
Unterscheidung gab es nie (heute nur das Bool `estimatedPriceIsAutoDerived`).

Reproduktion am aktuellen Stand (2026-10-17, Simulator `Restock-Validate`, Seed
`-seedLegacyLearnedPriceForUITests`, `LegacyLearnedPriceResetUITests`): im Laden „Altbon“ zeigen
„Laugenbrötchen groß“ (Schätzung, Bool `true`) und „Kontrollbrot“ (manuell, Bool `false`) beide
„2,50 €“ ohne jeden Unterschied; Foto `docs/artifacts/fix-151-price-source/heute-liste.png`. Entwurf:
`docs/artifacts/fix-151-price-source/entwurf.html` (Variante A).

## Source

- **File:** `SmartCart/Models/ShoppingItem.swift`
- **Identifier:** `ShoppingItem.init` (Preiswahl, Zeilen 122–183), neue Felder `priceSource` /
  `priceSourceDate`, berechnetes `priceOrigin`, neue reine Funktion
  `ShoppingItem.resolveLearnedPrice(...)` mit Ergebnistyp `LearnedPriceResolution`.
- **Anzeige:** `SmartCart/Views/Components/ItemRow.swift` (Preiszelle, Zeilen 152–163).
- Neue Typen stehen in `ShoppingItem.swift`, weil die Datei in drei Zielen (App, Widget, Erweiterung)
  kompiliert wird.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ShoppingItem.matchingLearnedPriceKey` | function | Namenszuordnung (Teilstring, Fuzzy #52, Tie-Breaker Datum/Schlüssel); der Resolver ruft sie unverändert |
| `ShoppingItem.learnedRateUsage` / `unitBucket` | functions | Entscheidungstabelle apply / rateOnly / reject; bleibt unverändert, der Resolver nutzt sie |
| `PriceEstimator.maxPlausibleLearnedLineTotal` | constant (200 €) | Obergrenze für gelernte Zeilensummen |
| `PriceEstimator.estimate` | function | Katalogschätzung, wenn kein gelernter Preis greift |
| `Store.learnedPrices` / `learnedPriceUnits` / `learnedPriceDates` | model fields | Eintrag, Bezugsgröße und Datum des gelernten Preises |
| `ReceiptLearning.apply` / `ReceiptScannerView.save()` | functions | Schreibstellen Bon |
| `ActualPriceEntryView.apply(itemActualTotal:to:)` | function | Schreibstelle „bezahlt“ |
| `EditItemView.save()` | function | Schreibstelle „eigener Preis“ / Zurücksetzen |
| `LegacyLearnedPriceReset.runIfNeeded` | function | Schreibstelle Rücksetzen auf Schätzung |
| `LearnedPriceSync.apply` (`SharedStoreService.swift`) | function | Fremdpreis aus geteiltem Laden überschreibt lokalen Eintrag |
| `PriceProvenanceMigration` | migration | bleibt unberührt (setzt nur das Bool, läuft einmalig) |
| `SettingsView` / `@AppStorage("developerMode")` | setting | Sichtbarkeit der Dev-Diagnose |
| `Localizable.strings` (de, en) | resources | neue Quelltexte und Diagnosetexte |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/ShoppingItem.swift` | MODIFY | Felder `priceSource: String = ""`, `priceSourceDate: Date?`; berechnetes `priceOrigin`; Kette aus `init` (Zeilen 122–183) als `resolveLearnedPrice(...)` herausgezogen; `init` nutzt sie und setzt die Quelle |
| `SmartCart/Models/Store.swift` | MODIFY | `learnedPriceOrigins: [String: String] = [:]` (Zeilen 30–52 Felder, 137–139 init) |
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY | Quellzeile unter dem Betrag, „ca. “ im selben Text wie der Betrag, kombiniertes Accessibility-Label |
| `SmartCart/Views/Store/EditItemView.swift` | MODIFY | `save()` (Zeilen 404–419): manuell → `manual`, leer → `estimate`; Dev-Diagnose-Abschnitt |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `ReceiptLearning.apply` (Zeilen 263–277) → `receipt` + Datum; `save()` (Zeilen 754–756) → `learnedPriceOrigins[key] = "receipt"` |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | MODIFY | `apply` (Zeilen 163–175) → `paid`, Origin `paid` |
| `SmartCart/Models/LegacyLearnedPriceReset.swift` | MODIFY | Zeilen 41–43 → `estimate` |
| `SmartCart/Services/SharedStoreService.swift` | MODIFY | `LearnedPriceSync.apply` (Zeilen 594–605): fremder, abweichender Preis → Origin-Eintrag löschen; Origins nicht in `State` |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Seed `-seedLegacyLearnedPriceForUITests` (Zeilen 380–402): „Kontrollbrot“ bekommt `priceSource = "manual"`, ein vierter Artikel zeigt die Altdaten-Ableitung „gelernt“ |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | Quelltexte, Diagnosetexte |
| `RestockTests/PriceSourceTests.swift` | CREATE | Unit-Tests (Parität, Ableitung, Schreibstellen, Sync, Anzeigetext, Diagnose) |
| `RestockUITests/LegacyLearnedPriceResetUITests.swift` | MODIFY | Zusatztests: Schätzung / eigener Preis / gelernt in der Zeile unterscheidbar, Dev-Diagnose |
| `CLAUDE.md` | MODIFY | Absatz „Preisquelle“ |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | `PriceSourceTests.swift` an vier Stellen im Test-Target registrieren |

### Estimated Changes

- Files: 15 (Produktcode 9, Tests 2 + 1 Registrierung, Strings 2 zählen als eine Gruppe, Doku 1)
- LoC: +450/−30 (Produktcode ~260, Tests ~190). **Vom PO am 2026-10-17 in einem Durchgang
  freigegeben, obwohl über dem Scoping-Limit.** Keine Aufteilung.

## Implementation Details

### Datenmodell (additiv, ohne Schema-Bump)

- `ShoppingItem.priceSource: String = ""` — Kennungen `"receipt"`, `"paid"`, `"learned"`, `"manual"`,
  `"estimate"` (String statt Enum, Muster `quantitySource`). `ShoppingItem.priceSourceDate: Date?` —
  nur bei `receipt` belegt.
- `priceOrigin` (berechnet, nie gespeichert): ist `priceSource` eine bekannte Kennung, gilt sie. Ist
  sie leer oder unbekannt (Altdaten), gilt `estimatedPriceIsAutoDerived ? "estimate" : "learned"`.
  **Aus Altdaten wird nie `receipt`, `paid` oder `manual` abgeleitet**, weil `false` alle drei und
  „gelernt“ gleichermaßen bedeuten kann.
- `Store.learnedPriceOrigins: [String: String] = [:]` — Herkunft je `learnedPrices`-Schlüssel
  (`"receipt"` oder `"paid"`), gleiche Schlüssel wie `learnedPriceUnits`. **Lokal, nicht im Sync**
  (`LearnedPriceSync.State` bleibt unverändert).
- Alle drei Felder haben Standardwerte (leichte Migration, CloudKit-tauglich, Muster
  `estimatedPriceIsAutoDerived`, `learnedPriceUnits`).

### Reine Preiswahl

```swift
static func resolveLearnedPrice(
    forLowercasedName: String, itemUnit: String, quantityAmount: Double,
    quantitySource: String, in store: Store?
) -> LearnedPriceResolution
```

`LearnedPriceResolution` trägt: `matchedKey`, `entryPrice`, `entryUnit`, `exceedsCap` (Entry-Preis ×
`max(quantityAmount > 0 ? quantityAmount : 1)` > Obergrenze), `usage` (`LearnedRateUsage`),
`price` (angewendeter Preis oder `nil`), `unitOverride` (`"g"` bei `.rateOnly`) und `reason`
(`noStore`, `noEntry`, `exceedsCap`, `legacyNoUnit`, `unitMismatch`, `applied`, `appliedRateOnly`).
Vorrang der Gründe: `noStore` → `noEntry` → `exceedsCap` → Verwendung aus `learnedRateUsage`
(fehlende oder leere Bezugsgröße = `legacyNoUnit`, sonstiges `.reject` = `unitMismatch`).

`init` ruft den Resolver und übernimmt `price`/`unitOverride` bitgleich zum bisherigen Verhalten:
`estimatedPrice = price ?? PriceEstimator.estimate(...)`, `estimatedPriceIsAutoDerived = (price == nil)`,
bei `.rateOnly` `unit = "g"`. Neu setzt `init` die Quelle: greift ein gelernter Preis, ist
`priceSource` der Origin-Eintrag unter `matchedKey` (`receipt` oder `paid`), sonst `learned`;
`priceSourceDate` ist bei `receipt` `learnedPriceDates[matchedKey]`. Greift keiner, ist
`priceSource = "estimate"`.

### Schreibstellen (Quelle, Preis und Datum immer im selben Zug)

| Stelle | Quelle am Artikel | Eintrag in `learnedPriceOrigins` |
|---|---|---|
| `ReceiptLearning.apply` (`.apply`/`.rateOnly`) | `receipt` + `Date()` | — |
| `ReceiptScannerView.save()` (neben `learnedPriceDates[plan.key] = Date()`) | — | `[plan.key] = "receipt"` |
| `ActualPriceEntryView.apply` | `paid`, Datum `nil` | `[key] = "paid"` |
| `EditItemView.save()`, Preisfeld ausgefüllt | `manual`, Datum `nil` | unverändert |
| `EditItemView.save()`, Feld geleert (Zurücksetzen) | `estimate`, Datum `nil` | unverändert |
| `LegacyLearnedPriceReset` | `estimate`, Datum `nil` | unverändert |
| `LearnedPriceSync.apply`, fremder abweichender Preis (`!samePrice`) | — | Eintrag unter `key` entfernt (→ „gelernt“) |

`.reject` in `ReceiptLearning.apply` lässt den Artikel samt Quelle unangetastet (der bisherige,
geschätzte Preis bleibt). Eine Einheitenänderung in `EditItemView` (Zeilen 413–419), die nur einen
geschätzten Preis neu berechnet, setzt `estimate` mit.

### Anzeige (`ItemRow`, Entwurf A)

- Die Preiszelle wird ein `VStack(alignment: .trailing)`: Betrag oben (13 pt, wie heute), darunter die
  Quelle (11 pt).
- Texte: `receipt` mit Datum → „Bon · 12.10.“ (Datum ohne Jahr, lokalisiert über Vorlage `d.M.`);
  `receipt` ohne Datum → „Bon“; `paid` → „bezahlt“; `learned` → „gelernt“; `manual` → „eigener
  Preis“; `estimate` → „Schätzung“.
- Bei `estimate` steht „ca. “ **im selben Text wie der Betrag** („ca. 2,90 €“), und Betrag und
  Quellzeile erscheinen in der Warnfarbe der angenommenen Menge (`ItemRow`, Zeilen 95–99). Alle
  anderen Quellen behalten `.secondary`.
- Der „ca.“-Präfix des Preises ist ein **eigener Text**, getrennt vom Mengentext
  (`staticTexts["ca. 400 g"]` in `AddItemQuantitySuggestionUITests` prüft die Menge exakt und bleibt
  unberührt).
- Die Gramm-Rate („1,25 €/100 g“, Zeilen 158–163) bekommt dieselbe Quellzeile.
- Accessibility: die Preiszelle ist ein einziges Element (`.accessibilityElement(children: .ignore)`,
  Trait `.isStaticText`, damit `app.staticTexts` sie weiter findet) mit Label „<Betrag>, <Quelle>“,
  bei Schätzung „ca. <Betrag>, Schätzung“.
- Regel für abgehakte Artikel unverändert: Preis (und damit Quelle) nur, wenn
  `!isCompleted || !estimatedPriceIsAutoDerived`.
- Die Textbildung ist eine reine Funktion (`PriceSourceDisplay.text(origin:date:)` und
  `PriceSourceDisplay.amountPrefix(origin:)`), damit sie ohne Oberfläche prüfbar ist.

### Dev-Diagnose (`EditItemView`, nur bei `developerMode`)

Eigener Abschnitt „Preisdiagnose“ (nur wenn `@AppStorage("developerMode")` an ist) mit den Zeilen:
gefundener Eintrag (Schlüssel, Preis, Bezugsgröße, Datum, Herkunft), Bezugsgröße des Artikels
(`unitBucket`, `quantitySource`), Obergrenze (Preis × Menge gegen 200 €), Ergebnis mit Grund. Die
Texte kommen aus einer reinen Funktion über `resolveLearnedPrice` — **dieselbe Kette wie `init`,
keine zweite Logik**. Die Diagnose rechnet mit dem aktuellen Zustand des Artikels (siehe Offene
Grenzen).

## Test Plan

### Automated Tests (TDD RED)

Unit (`RestockTests/PriceSourceTests.swift`, In-Memory-`ModelContainer`, eigene `UserDefaults` wo
nötig):

- [ ] Test 1 (Parität, Entscheidungstabelle): GIVEN ein Laden mit Eintrag und jeder Kombination aus
  `learnedUnit` (`nil`, `""`, `"stk"`, `"g"`, `"kg"`, `"l"`) × Artikeleinheit (`""`, `"stk"`, `"g"`,
  `"kg"`, `"l"`) × `quantitySource` (`"none"`, `"user"`) WHEN ein `ShoppingItem` per `init` gebaut und
  der Resolver gerufen wird THEN stimmen `estimatedPrice`, `unit` und `estimatedPriceIsAutoDerived`
  des Artikels mit `price`/`unitOverride` des Resolvers überein.
- [ ] Test 2 (Parität, Namenszuordnung): GIVEN Teilstring-Treffer, Fuzzy-Treffer (#52, Schlüssel ≥ 5
  Zeichen), zwei Treffer mit gleichem Datum (Schlüssel als Tie-Breaker) und kein Treffer WHEN `init`
  und Resolver laufen THEN liefern beide denselben Preis; `matchedKey` ist der von
  `matchingLearnedPriceKey` gewählte.
- [ ] Test 3 (Parität, Obergrenze): GIVEN Preis × Menge = 200,00 € / 200,01 € / Menge 0 (zählt als 1)
  WHEN `init` und Resolver laufen THEN gilt 200,00 als `applied`, 200,01 als `exceedsCap` mit
  Schätzung, Menge 0 wird wie 1 gerechnet.
- [ ] Test 4 (Gründe): GIVEN je ein Fall pro Grund WHEN der Resolver läuft THEN ist `reason` genau
  `noStore`, `noEntry`, `exceedsCap`, `legacyNoUnit` (Einheit fehlt und leer), `unitMismatch`,
  `applied`, `appliedRateOnly`.
- [ ] Test 5 (Ableitung Altdaten): GIVEN `priceSource == ""` und Bool `true`/`false`, sowie ein
  unbekannter Wert `"xyz"` WHEN `priceOrigin` gelesen wird THEN `estimate`, `learned`, `learned`/`estimate`
  gemäß Bool; niemals `receipt`, `paid` oder `manual`.
- [ ] Test 6 (`init` setzt Quelle): GIVEN Eintrag mit Origin `receipt` und Datum / Origin `paid` / ohne
  Origin / `.reject` / kein Eintrag WHEN ein Artikel erzeugt wird THEN `priceSource` ist `receipt` mit
  `priceSourceDate == learnedPriceDates[key]`, `paid`, `learned`, `estimate`, `estimate`.
- [ ] Test 7 (Bon schreibt): GIVEN ein Bon-Plan WHEN `ReceiptLearning.apply` für `.apply`, `.rateOnly`,
  `.reject` läuft THEN stehen bei den ersten beiden `receipt` + Datum und der Preis zusammen, bei
  `.reject` bleiben Preis und Quelle unverändert; ein Lauf von `save()` setzt
  `learnedPriceOrigins[key] = "receipt"` zusammen mit Preis, Bezugsgröße und Datum.
- [ ] Test 8 (bezahlt): GIVEN ein eingegebener Gesamtbetrag WHEN `ActualPriceEntryView.apply` läuft
  THEN `priceSource == "paid"`, `learnedPriceOrigins[key] == "paid"`.
- [ ] Test 9 (manuell / Zurücksetzen): GIVEN `EditItemView`-Speicherlogik WHEN ein Preis eingetragen
  wird / das Feld geleert wird THEN `manual` / `estimate` (Preis = Katalogschätzung, Bool `true`).
- [ ] Test 10 (Migration): GIVEN der Fingerabdruck aus `legacy-price-reset-migration.md` trifft WHEN
  `LegacyLearnedPriceReset.runIfNeeded` läuft THEN `priceSource == "estimate"`; Läden unverändert.
- [ ] Test 11 (Sync): GIVEN ein lokaler Eintrag mit Origin `receipt` WHEN `LearnedPriceSync.apply` einen
  Fremdpreis (anderer Betrag, neueres Datum) einspielt THEN fehlt der Origin-Eintrag; bei gleichem
  Datum und gleichem Betrag bleibt er; `LearnedPriceSync.State` enthält keine Origins.
- [ ] Test 12 (Store-Feld): GIVEN ein neuer `Store` WHEN er angelegt und gesichert wird THEN ist
  `learnedPriceOrigins` leer und der In-Memory-Container lädt ohne Fehler.
- [ ] Test 13 (Anzeigetext): GIVEN jede Quelle, `receipt` mit und ohne Datum WHEN
  `PriceSourceDisplay.text` und `amountPrefix` laufen THEN „Bon · 12.10.“ (de), „Bon“, „bezahlt“,
  „gelernt“, „eigener Preis“, „Schätzung“; Präfix „ca. “ nur bei `estimate`; Accessibility-Label ist
  „Betrag, Quelle“.
- [ ] Test 14 (Abgehakt): GIVEN ein abgehakter Artikel mit `estimate` und einer mit `learned` WHEN die
  Sichtbarkeitsregel der Preiszelle geprüft wird THEN erscheint beim ersten weder Preis noch Quelle,
  beim zweiten Preis und Quelle.
- [ ] Test 15 (Diagnose): GIVEN ein Laden mit Treffer, mit überschrittener Obergrenze und mit
  Einheit-Konflikt WHEN die Diagnosezeilen gebildet werden THEN nennen sie Schlüssel, Bezugsgröße,
  Obergrenze und Ergebnis mit Grund passend zum Resolver-Ergebnis.
- [ ] Test 16 (Texte): GIVEN alle neuen Schlüssel WHEN sie im de- und im en-Bundle nachgeschlagen
  werden THEN liefern beide einen Text, der nicht der Schlüssel ist, und die beiden unterscheiden
  sich.

Durchlauf (`RestockUITests/LegacyLearnedPriceResetUITests.swift`, Start mit
`-hasCompletedOnboarding YES -seedLegacyLearnedPriceForUITests`, `tearDown()` mit
`-clearLegacyLearnedPriceSeedForUITests`, nie `-developerMode` als Schalter, den die App schreibt):

- [ ] Test 17: GIVEN der Seed (Basis des Bestandstests) WHEN der Laden „Altbon“ offen ist THEN zeigt
  „Laugenbrötchen groß“ nach der Migration einen Preistext, der mit „ca. “ beginnt und „Schätzung“
  enthält, „Kontrollbrot“ einen Preistext mit „2,50“ und „eigener Preis“, der vierte Artikel
  „gelernt“; Schätzung und eigener Preis sind damit in der Zeile unterscheidbar (heute identisch).
- [ ] Test 18: GIVEN derselbe Seed mit `-developerMode YES` WHEN „Laugenbrötchen groß“ bearbeitet wird
  THEN ist der Abschnitt „Preisdiagnose“ sichtbar; GIVEN derselbe Seed mit `-developerMode NO` THEN
  fehlt er.
- [ ] Test 19: GIVEN die Bestands-UI-Tests `AddItemQuantitySuggestionUITests` und
  `LegacyLearnedPriceResetUITests` (Altprüfung) WHEN sie laufen THEN bleiben sie grün
  (`staticTexts["ca. 400 g"]` exakt, „2,50“ und „1,56“-Abwesenheit über `staticTexts`).

## Acceptance Criteria

- **AC-1:** Die Preiswahl aus `ShoppingItem.init` ist als reine Funktion `resolveLearnedPrice` mit
  Grund herausgezogen; über alle Zeilen von `learnedRateUsage` (Bezugsgröße × Artikeleinheit ×
  `quantitySource`) liefert `init` dieselben Werte (`estimatedPrice`, `unit`,
  `estimatedPriceIsAutoDerived`) wie der Resolver.
  - Test: `RestockTests/PriceSourceTests.swift::testResolverMatchesInitForAllUsageRows`
- **AC-2:** Die Parität gilt auch für Teilstring-, Fuzzy- und Tie-Breaker-Treffer sowie für „kein
  Treffer“; `matchedKey` ist der von `matchingLearnedPriceKey` gewählte Schlüssel.
  - Test: `RestockTests/PriceSourceTests.swift::testResolverMatchesInitForSubstringFuzzyAndTieBreak`
- **AC-3:** Die Obergrenze gilt unverändert: 200,00 € greift, 200,01 € nicht (Grund `exceedsCap`,
  Schätzung), Menge 0 wird wie 1 gerechnet.
  - Test: `RestockTests/PriceSourceTests.swift::testResolverCapBoundaryMatchesInit`
- **AC-4:** Der Resolver nennt den Grund eindeutig: `noStore`, `noEntry`, `exceedsCap`,
  `legacyNoUnit`, `unitMismatch`, `applied`, `appliedRateOnly`.
  - Test: `RestockTests/PriceSourceTests.swift::testResolverReasons`
- **AC-5:** `priceOrigin` leitet bei leerem oder unbekanntem `priceSource` aus dem Bool ab (`true` →
  `estimate`, `false` → `learned`) und liefert aus Altdaten nie `receipt`, `paid` oder `manual`.
  - Test: `RestockTests/PriceSourceTests.swift::testPriceOriginDerivationFromLegacyBool`
- **AC-6:** `ShoppingItem.init` setzt die Quelle: gelernter Preis mit Origin `receipt` → `receipt` mit
  Datum aus `learnedPriceDates`; Origin `paid` → `paid`; gelernter Preis ohne Origin → `learned`;
  verworfener oder fehlender Eintrag → `estimate`.
  - Test: `RestockTests/PriceSourceTests.swift::testInitSetsPriceSource`
- **AC-7:** `ReceiptLearning.apply` schreibt bei `.apply` und `.rateOnly` `receipt` + Datum zusammen
  mit dem Preis; bei `.reject` bleiben Preis und Quelle unverändert; `ReceiptScannerView.save()` setzt
  `learnedPriceOrigins[key] = "receipt"` zusammen mit Preis, Bezugsgröße und Datum.
  - Test: `RestockTests/PriceSourceTests.swift::testReceiptLearningWritesReceiptSource`
- **AC-8:** `ActualPriceEntryView.apply` setzt `paid` am Artikel und `learnedPriceOrigins[key] == "paid"`.
  - Test: `RestockTests/PriceSourceTests.swift::testActualPriceEntryWritesPaidSource`
- **AC-9:** `EditItemView.save()` setzt bei eingetragenem Preis `manual`, beim Leeren des Feldes
  `estimate` samt Katalogschätzung und Bool `true`.
  - Test: `RestockTests/PriceSourceTests.swift::testEditItemSaveWritesManualAndEstimate`
- **AC-10:** `LegacyLearnedPriceReset` setzt zurückgesetzte Artikel auf `estimate`; `learnedPrices`,
  `learnedPriceUnits`, `learnedPriceDates` und `learnedPriceOrigins` des Ladens bleiben unverändert.
  - Test: `RestockTests/PriceSourceTests.swift::testLegacyResetWritesEstimateSource`
- **AC-11:** `LearnedPriceSync.apply` entfernt bei einem fremden, abweichenden Preis den
  Origin-Eintrag (Anzeige danach „gelernt“), behält ihn bei gleichem Datum und gleichem Betrag, und
  `LearnedPriceSync.State` überträgt keine Origins.
  - Test: `RestockTests/PriceSourceTests.swift::testSyncApplyRemovesOriginForForeignPrice`
- **AC-12:** `Store.learnedPriceOrigins` und `ShoppingItem.priceSource`/`priceSourceDate` haben
  Standardwerte (leer bzw. `nil`) und laden im In-Memory-Container ohne Fehler (additiv, ohne
  Schema-Bump).
  - Test: `RestockTests/PriceSourceTests.swift::testNewFieldsHaveDefaultsAndContainerLoads`
- **AC-13:** Die Quelltexte lauten „Bon · 12.10.“ (ohne Datum „Bon“), „bezahlt“, „gelernt“, „eigener
  Preis“, „Schätzung“; nur bei `estimate` steht „ca. “ vor dem Betrag; das Accessibility-Label der
  Preiszelle kombiniert Betrag und Quelle.
  - Test: `RestockTests/PriceSourceTests.swift::testSourceTextsAndAccessibilityLabel`
- **AC-14:** Abgehakte Artikel zeigen weiter nur echte Preise: abgehakt mit `estimate` → weder Preis
  noch Quelle; abgehakt mit echter Quelle → Preis und Quelle.
  - Test: `RestockTests/PriceSourceTests.swift::testCompletedItemShowsOnlyRealPriceWithSource`
- **AC-15:** Die Dev-Diagnose nennt Schlüssel, Bezugsgröße, Obergrenze und Ergebnis mit Grund und
  stammt aus derselben Resolver-Kette wie `init`.
  - Test: `RestockTests/PriceSourceTests.swift::testDiagnosisLinesMatchResolverResult`
- **AC-16:** Alle neuen Texte existieren in de und en und sind dort verschieden vom Schlüssel.
  - Test: `RestockTests/PriceSourceTests.swift::testAllNewStringsExistInGermanAndEnglish`
- **AC-17:** In der Artikelzeile sind Schätzung („ca. …“ + „Schätzung“), eigener Preis („2,50“ +
  „eigener Preis“) und Altdaten-Preis („gelernt“) im echten Durchlauf unterscheidbar; vor der
  Änderung zeigten Schätzung und eigener Preis denselben Text.
  - Test: `RestockUITests/LegacyLearnedPriceResetUITests.swift::testPriceSourceDistinguishesEstimateManualAndLearned`
- **AC-18:** Die Preisdiagnose erscheint im Bearbeiten-Dialog nur im Entwicklermodus.
  - Test: `RestockUITests/LegacyLearnedPriceResetUITests.swift::testPriceDiagnosisOnlyInDeveloperMode`
- **AC-19:** Die Bestandstests bleiben grün: `AddItemQuantitySuggestionUITests` (Menge „ca. 400 g“
  exakt, Preis-„ca.“ ist ein eigener Text), `LegacyLearnedPriceResetUITests`
  (`testLegacyPricesAreResetAfterLaunchButManualPriceStays`) und alle Unit-Tests zu gelernten Preisen
  (`ShoppingItemFuzzyPriceMatchTests`, `PriceProvenanceMigrationTests`, `LegacyLearnedPriceResetTests`,
  `ReceiptLearningTests`, `LearnedPriceSyncTests`).
  - Test: `RestockUITests/AddItemQuantitySuggestionUITests` und
    `RestockUITests/LegacyLearnedPriceResetUITests::testLegacyPricesAreResetAfterLaunchButManualPriceStays`
    (unverändert, im gemeinsamen Lauf)

## Alternativen

- **B — nur die Schätzung markieren** (~60 LoC, ohne Migration): löst die Verwechslung Schätzung /
  echt, lässt aber Bon, eigener Preis, bezahlt und das Alter ununterscheidbar. Gekippt würde: der
  Entwurf A, den der PO freigegeben hat.
- **Quelle nur aus `learnedPriceOrigins` ableiten, ohne Feld am Artikel:** spart die meisten
  Schreibstellen, zeigt aber „Bon“ für einen Artikel, dessen Preis gar nicht vom Bon kam, sobald ein
  späterer Bon den Eintrag des Ladens überschreibt, und kennt „eigener Preis“ nicht. Gekippt würde:
  die Entscheidung, die Quelle am Artikel zu speichern.
- **C — Symbol statt Wort:** kein Platz für das Datum, und VoiceOver braucht trotzdem Text.
- **Herkunft im Sync mitschicken:** würde „Bon“ auch für Fremdpreise zeigen, ändert aber das
  CloudKit-Format des geteilten Ladens; vom PO verworfen (Origins bleiben lokal).
- **Diagnose als zweite, eigene Logik** statt Resolver: verworfen, weil Anzeige und Wirklichkeit
  auseinanderlaufen würden (Paritätstest AC-1 bis AC-3 sichert das Gegenteil).
- Modell oder Heuristik zur Herkunftserkennung kommen nicht in Frage: Die Quelle ist an jeder
  Schreibstelle bekannt, es braucht nur Regeln.

## Offene Grenzen

- **CloudKit-Produktionsschema:** Die neuen Felder an `ShoppingItem` und `Store` (privater Spiegel)
  müssen **vor dem nächsten TestFlight-Upload per `cktool` im Produktionsschema veröffentlicht
  werden** (Ablauf siehe `docs/testflight-setup.md` und Memory „CloudKit-Schema per cktool“). Ohne
  das lehnt CloudKit das Speichern ab, wie bei #121. Echtes Speichern gegen CloudKit-Produktion ist
  nicht automatisiert prüfbar.
- **Fremdpreis aus geteiltem Laden zeigt „gelernt“**, auch wenn er auf dem Bon des anderen Mitglieds
  stand; die Herkunft bleibt lokal, Sync-Format unverändert (PO-Entscheidung). Ebenso zeigt ein
  Altdaten-Preis „gelernt“ statt „Bon“ ohne Datum.
- **Fuzzy-Treffer:** Die Zeile zeigt die Quelle des gefundenen Eintrags, nicht des getippten Namens;
  die Diagnose nennt den gefundenen Schlüssel.
- **Diagnose rechnet mit dem heutigen Zustand** des Artikels (Einheit, Menge, `quantitySource`),
  nicht mit dem bei der Erstellung. Bei `.rateOnly` stellt `init` die Einheit auf „g“ um; die
  Diagnose zeigt dann `applied`, nicht `appliedRateOnly`.
- **Zwei „ca.“ in einer Zeile** (angenommene Menge und geschätzter Preis) sind möglich; die
  Lesbarkeit ist im Entwurf geprüft, am Gerät nicht.
- **Folge-Idee außerhalb des Umfangs:** im Kopf „Geschätzter Betrag“ zusätzlich „davon geschätzt“
  ausweisen.
- `PriceProvenanceMigration` bleibt unverändert; bestehende Artikel haben `priceSource == ""` und
  folgen der Ableitung aus dem Bool. Der Altdaten-Fall „eigener Preis“ ohne Quelle wird als
  „gelernt“ angezeigt.
- Nichts auf Hennings Geräten geprüft; Nachweis im Simulator.

## Side-Effects

- **Dateien:** siehe Tabelle „Affected Files“.
- **Info.plist / Permissions:** keine Änderung.
- **AppStorage/UserDefaults:** keine neuen Schlüssel; `developerMode` wird nur gelesen.
- **Schema/CloudKit:** drei additive Felder (`ShoppingItem.priceSource`, `ShoppingItem.priceSourceDate`,
  `Store.learnedPriceOrigins`); Produktionsschema vor dem Upload veröffentlichen (siehe Offene Grenzen).
- **Launch-Argumente:** keine neuen; der bestehende Seed `-seedLegacyLearnedPriceForUITests` bekommt
  zwei zusätzliche Artikelzustände und räumt weiter mit `-clearLegacyLearnedPriceSeedForUITests` auf.
- **Audio-Dateien:** keine.
- **Sichtbare Wirkung:** unter jedem angezeigten Preis steht eine kleine Quellzeile; Schätzungen
  tragen „ca.“ in der Warnfarbe.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion oben ist durch einen automatischen Test belegt
- [ ] In der Artikelzeile des Ladens „Altbon“ sind Schätzung, eigener Preis und gelernter Preis im
  Simulator-Durchlauf (Stand, den Henning bekommt) unterscheidbar
- [ ] Der Paritätstest (AC-1 bis AC-3) ist grün, und alle Bestandstests zu gelernten Preisen laufen
  im gemeinsamen Lauf grün (Regressionslauf)
- [ ] `CLAUDE.md` enthält den Absatz „Preisquelle“; das CloudKit-Produktionsschema ist als Schritt vor
  dem nächsten TestFlight-Upload vermerkt

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Additive Felder nach bestehendem Muster (`quantitySource`, `learnedPriceUnits`) und
  eine Funktionsextraktion; keine neue Architektur, keine neue Abhängigkeit.

## Changelog

- 2026-10-17: Initial spec created (Issue #151, Variante A).
