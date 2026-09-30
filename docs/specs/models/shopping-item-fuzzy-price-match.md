---
entity_id: shopping-item-fuzzy-price-match
type: bugfix
created: 2026-09-30
updated: 2026-09-30
status: draft
version: "1.0"
tags: [bugfix, price-learning, matching]
test_targets: [RestockTests/Models/ShoppingItemFuzzyPriceMatchTests.swift]
workflow: fix-52-fuzzy-price-match
---

# Fehlertoleranter Namensabgleich für gelernte Preise (Tippfehler/OCR)

## Approval

- [ ] Approved

## GitHub Issue

- **Issue:** #52

## Purpose

`ShoppingItem.init` findet einen unter `store.learnedPrices` gelernten Preis nur, wenn einer der
beiden verglichenen Namen den anderen vollständig als Teilstring enthält. Ein Bon-Name, der durch
einen OCR- oder Tippfehler minimal vom später eingegebenen Artikelnamen abweicht (gemeldeter Fall:
„saitan" gelernt, „seitan" eingegeben), erzeugt keinen Teilstring-Treffer und der gelernte Preis
geht scheinbar verloren — obwohl er im Dictionary vorhanden ist. Diese Spec ergänzt einen engen,
regelbasierten Fallback (Levenshtein-Distanz ≤ 1, Mindestlänge 5 Zeichen), der genau diesen Fall
abdeckt, ohne bei erkennbar unterschiedlichen Artikeln (z. B. „milch"/„mehl") fälschlich
zuzuschlagen.

## Source

- **File:** `SmartCart/Models/ShoppingItem.swift`
- **Identifier:** `init(name:category:quantity:quantityAmount:unit:note:store:quantitySource:)`,
  darin die `rawLearnedMatch`-Closure mit `matchingKeys`/`bestKey` (Zeile ca. 137-153); neu:
  private statische Hilfsfunktion für die Levenshtein-Distanz plus Gate-Prüfung, unit-testbar
  isoliert von `init` aufrufbar.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Store.learnedPrices` (`Store.swift`) | property | Enthält die per Key gelernten Preise; Key-Auswahl ist Gegenstand dieser Änderung, die Struktur bleibt unangetastet. |
| `Store.learnedPriceDates` (`Store.swift`) | property | Bestehender Tie-Breaker bei mehreren Kandidaten; wird unverändert wiederverwendet, jetzt auch auf die fuzzy gefundene Kandidatenmenge angewendet. |
| `Store.learnedPriceUnits` (`Store.swift`) | property | Bezugsgröße unter demselben Key (Issue #10); von dieser Änderung nicht berührt, bleibt nach dem Fund unverändert im Ablauf. |
| `learned-price-unit-and-quantity-source` (`docs/specs/models/learned-price-unit-and-quantity-source.md`) | spec | Beschreibt die drei parallelen Dictionaries und deren gemeinsamen Key; diese Änderung ändert nur, welcher Key gefunden wird, nicht deren Zusammenspiel danach. |

## Scope

- **Affected Files:** `SmartCart/Models/ShoppingItem.swift` (MODIFY),
  `RestockTests/Models/ShoppingItemFuzzyPriceMatchTests.swift` (CREATE, TDD RED in Phase 4)
- **Estimated Changes:** ~30 LoC Produktivcode (nur `ShoppingItem.swift`), Testcode separat in
  Phase 4

## Implementation Details

**Bestehendes Verhalten bleibt die erste Stufe, unverändert.** Die heutige Teilstring-Prüfung
(`key.count >= 3 && itemLower.count >= 3 && (key.contains(itemLower) || itemLower.contains(key))`)
läuft weiterhin zuerst. Liefert sie mindestens einen Treffer, wird **nicht** in den neuen
Fallback-Zweig gewechselt — ein bestehender Teilstring-Treffer hat unbedingten Vorrang vor einem
fuzzy gefundenen.

**Neuer Fallback, nur wenn die Teilstring-Prüfung leer bleibt:**

1. Neue, kleine, eigene Hilfsfunktion für die klassische Levenshtein-Distanz (kein Fremdcode, kein
   externes Paket). Sie ist so zu bauen, dass die Distanz- und Längen-Gate-Prüfung auch isoliert
   für ein einzelnes Namenspaar unit-testbar ist, unabhängig vom vollständigen `ShoppingItem.init`
   — das braucht der Test Plan unten für zwei Beleg-Fälle, bei denen die bestehende
   Teilstring-Prüfung dasselbe Paar aus anderem Grund bereits selbst matchen würde (siehe dort).
2. Über `store.learnedPrices.keys` wird geprüft: Levenshtein-Distanz zwischen `key` und `itemLower`
   ≤ 1 **und** die Länge des kürzeren der beiden Strings ≥ 5 Zeichen. Nur wenn **beide** Bedingungen
   zugleich gelten, zählt der Key als fuzzy-Kandidat.
3. Aus der so gefundenen Kandidatenmenge wird der Key exakt mit der bestehenden Tie-Breaking-Logik
   ausgewählt (zuerst jüngstes `learnedPriceDates`, bei Gleichstand/Fehlen alphabetisch nach Key —
   siehe Code-Kommentar zum Bug vom 19.08.2026 in `ShoppingItem.swift`), nur angewendet auf diese
   kleinere Menge statt auf alle Teilstring-Treffer.
4. Das Mindestlängen-Gate von 5 Zeichen ist ein **eigenes**, zusätzliches Gate für den Fuzzy-Zweig
   und ersetzt nicht die bestehende Mindestlänge 3 der Teilstring-Prüfung.

**Beleg-Tabelle (durchgerechnet, bindend für die Kalibrierung):**

| Paar | Levenshtein-Distanz | kürzerer Name (Zeichen) | Ergebnis der Fuzzy-Prüfung |
|------|---------------------|--------------------------|----------|
| saitan / seitan | 1 | 6 | Treffer (gewünschter Fall) |
| reis / eis | 1 | 3 | kein Treffer (Längen-Gate) |
| milch / mehl | 4 | 4 | kein Treffer (Distanz) |
| bananen / mandeln | 4 | 7 | kein Treffer (Distanz) |
| apfel / apfelsaft | 4 | 5 | kein Treffer (Distanz) |

*Hinweis zu zwei Zeilen dieser Tabelle:* „reis"/„eis" und „apfel"/„apfelsaft" sind zufällig
**zusätzlich** bereits über die bestehende Teilstring-Prüfung verknüpft („reis" enthält „eis";
„apfelsaft" beginnt mit „apfel"). Als vollständiges `ShoppingItem`-Szenario mit genau diesen
beiden Namen würde also bereits die bestehende, unveränderte Teilstring-Stufe zuschlagen — die
Fuzzy-Prüfung käme dort laut Vorrangregel gar nicht erst zum Zug. Die Tabelle bleibt trotzdem
bindend als Aussage über die **Fuzzy-Prüfung selbst**: Für diese beiden Zeilen weist der Test Plan
das über die isolierte Hilfsfunktion nach (Punkt 1 oben), nicht über ein widersprüchliches
End-to-End-Szenario. Für „milch"/„mehl" und „bananen"/„mandeln" besteht keine solche
Teilstring-Überschneidung; dort erfolgt der Nachweis unmittelbar über `ShoppingItem.init`.

**Bewusst nicht wiederverwendet:** `ReceiptParserService.lcsSimilarity` (Dice-Koeffizient,
Schwellwerte 0.6/0.45). Gegen den Fall „reis"/„eis" ergibt dieser Algorithmus einen Score von
0.857 — über der bestehenden Auto-Anwenden-Schwelle 0.6 — und würde hier einen stillen
Fehltreffer beim *Preis* erzeugen, was schwerer wiegt als ein falscher Namensvorschlag (wofür
`lcsSimilarity` an seinen bestehenden Einsatzstellen kalibriert ist). Deshalb eine eigene,
konservativere Prüfung statt Wiederverwendung.

## Expected Behavior

- **Input:** Ein Artikelname beim Anlegen eines `ShoppingItem` (z. B. „seitan"), ein `Store` mit
  gelerntem Preis unter einem minimal abweichenden Key (z. B. „saitan").
- **Output:** Findet die bestehende Teilstring-Prüfung nichts, aber Levenshtein-Distanz ≤ 1 bei
  einer Mindestlänge von 5 Zeichen im kürzeren Namen, wird der gelernte Preis wie ein regulärer
  Treffer weiterverarbeitet (Plausibilitäts-Obergrenze, Bezugsgrößen-Entscheidungstabelle aus
  Issue #10 — beide unverändert nachgelagert).
- **Side effects:** Keine. Reine Lesezugriffe auf bestehende Dictionaries, keine Schreibzugriffe,
  keine Änderung an `store.learnedPrices`/`learnedPriceDates`/`learnedPriceUnits`.

## Error Handling

- Kein Kandidat erfüllt beide Fuzzy-Bedingungen → Verhalten bleibt wie heute: kein gelernter Preis,
  `PriceEstimator` liefert den Schätzwert, `estimatedPriceIsAutoDerived == true`.
- Mehrere Keys erfüllen die Fuzzy-Bedingungen gleichzeitig → deterministische Auswahl über das
  bestehende Tie-Breaking (Datum, dann alphabetisch), kein zufälliges Ergebnis zwischen App-Starts.
- Ein bestehender Teilstring-Treffer und ein zusätzlicher fuzzy-naher, aber anderer Key existieren
  gleichzeitig → der Teilstring-Treffer gewinnt unbedingt; der Fuzzy-Zweig wird in diesem Fall gar
  nicht ausgeführt.

## Known Limitations

- Deckt nur Abweichungen bis Levenshtein-Distanz 1 bei mindestens 5 Zeichen im kürzeren Namen ab.
  Größere Tippfehler oder sehr kurze Namen bleiben unerreicht — bewusst konservativ, um Fehltreffer
  wie „milch"/„mehl" auszuschließen.
- Bereits falsch gelernte Keys (z. B. „saitan") werden durch diesen Fix nicht rückwirkend bereinigt
  oder umbenannt; sie werden ab sofort lediglich auch bei abweichender Schreibweise gefunden.
- Keine Änderung an der Stelle, an der `learnedPrices`-Keys entstehen
  (`ReceiptScannerView.save()`, Zeile ca. 692) — ein unbestätigter OCR-Name wird weiterhin
  ungeprüft als Key gelernt. Eine Härtung dort (Alternative b: Lernen nur bei vom Nutzer
  bestätigtem Namen) wurde für diesen Fix explizit geprüft und verworfen: größerer Eingriff in
  `ReceiptReviewCard`/`ReceiptScannerView`, ein laut vorheriger PO-Priorisierung bereits als
  überladen markierter Screen, und löst nicht rückwirkend bereits falsch gelernte Keys.
- Keine Wiederverwendung von `ReceiptParserService.lcsSimilarity` (siehe Begründung oben unter
  „Implementation Details").
- Keine Änderung an der Datenstruktur von `learnedPrices`/`learnedPriceDates`/`learnedPriceUnits`.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Unit-Test belegt
- [ ] Der gemeldete Fall ist beobachtbar behoben: ein Artikel „seitan" ohne Menge übernimmt den
      unter „saitan" gelernten Preis, statt auf den generischen Schätzwert zurückzufallen
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf der gesamten
      Bestandssuite grün, insbesondere alle bestehenden Tests zum Teilstring-Match und zum
      Tie-Breaking bei mehreren Treffern)

## Acceptance Criteria

- **AC-1:** Given ein `Store` mit `learnedPrices["saitan"] = 4.99` und
  `learnedPriceUnits["saitan"] = "stk"` / When ein `ShoppingItem` mit `name: "Seitan"` und diesem
  Store angelegt wird / Then `estimatedPrice == 4.99` und `estimatedPriceIsAutoDerived == false`
  (Fuzzy-Treffer greift, da Levenshtein-Distanz 1 bei kürzerem Namen „seitan" = 6 Zeichen).
  - Test: *(populated after TDD RED phase)*

- **AC-2:** Given die Namen „reis" und „eis" / When die neue Fuzzy-Gate-Hilfsfunktion isoliert
  darauf angewendet wird / Then liefert sie „kein Treffer" (Levenshtein-Distanz 1, aber kürzerer
  Name „eis" hat nur 3 Zeichen und unterschreitet das Mindestlängen-Gate von 5). Isolierter
  Nachweis statt über `ShoppingItem.init`, weil „reis" und „eis" zusätzlich bereits über die
  bestehende, unveränderte Teilstring-Prüfung verknüpft sind (siehe Implementation Details).
  - Test: *(populated after TDD RED phase)*

- **AC-3:** Given ein `Store` mit `learnedPrices["milch"] = 1.19` / When ein `ShoppingItem` mit
  `name: "Mehl"` angelegt wird / Then wird der gelernte Preis **nicht** übernommen
  (`estimatedPriceIsAutoDerived == true`) — Levenshtein-Distanz 4 liegt über der Schwelle 1, und
  „milch"/„mehl" haben keine bestehende Teilstring-Beziehung.
  - Test: *(populated after TDD RED phase)*

- **AC-4:** Given ein `Store` mit `learnedPrices["bananen"] = 2.29` / When ein `ShoppingItem` mit
  `name: "Mandeln"` angelegt wird / Then wird der gelernte Preis **nicht** übernommen
  (`estimatedPriceIsAutoDerived == true`) — Levenshtein-Distanz 4 liegt über der Schwelle 1, und
  „bananen"/„mandeln" haben keine bestehende Teilstring-Beziehung.
  - Test: *(populated after TDD RED phase)*

- **AC-5:** Given die Namen „apfel" und „apfelsaft" / When die neue Fuzzy-Gate-Hilfsfunktion
  isoliert darauf angewendet wird / Then liefert sie „kein Treffer" (Levenshtein-Distanz 4 liegt
  über der Schwelle 1). Isolierter Nachweis statt über `ShoppingItem.init`, weil „apfel" bereits
  ein Präfix von „apfelsaft" ist und damit über die bestehende, unveränderte Teilstring-Prüfung
  ohnehin einen Treffer ergäbe (siehe Implementation Details).
  - Test: *(populated after TDD RED phase)*

- **AC-6:** Given ein `Store` mit zwei fuzzy-passenden Kandidaten für denselben eingegebenen Namen
  „seitan" — `learnedPrices["saitan"]` (älteres `learnedPriceDates`) und `learnedPrices["seiten"]`
  (jüngeres `learnedPriceDates`), beide mit Levenshtein-Distanz 1 zu „seitan" und keiner der drei
  Namen in einer bestehenden Teilstring-Beziehung zueinander / When ein `ShoppingItem` mit
  `name: "Seitan"` angelegt wird / Then wird der Preis unter dem Key mit dem jüngeren
  `learnedPriceDates`-Eintrag übernommen (dieselbe bestehende Tie-Breaking-Logik wie beim
  Teilstring-Match, nur angewendet auf die fuzzy gefundene Kandidatenmenge).
  - Test: *(populated after TDD RED phase)*

- **AC-7:** Given ein `Store` mit `learnedPrices["hackfleisch gemischt 500g"] = 4.99` / When ein
  `ShoppingItem` mit `name: "Hackfleisch"` angelegt wird / Then greift weiterhin ausschließlich der
  bestehende Teilstring-Treffer (`estimatedPrice == 4.99`); der neue Fuzzy-Zweig wird dabei gar
  nicht erst ausgeführt, weil die Teilstring-Prüfung bereits einen Treffer liefert.
  - Test: *(populated after TDD RED phase)*

## Test Plan

Automated tests (linked to AC above), neue Datei
`RestockTests/Models/ShoppingItemFuzzyPriceMatchTests.swift`:
- `testFuzzyMatchFindsLearnedPriceForTyposaitanSeitan` (AC-1)
- `testFuzzyGateRejectsReisEisBelowLengthGate` (AC-2, isolierte Hilfsfunktion)
- `testFuzzyMatchRejectsDistanceAboveThresholdMilchMehl` (AC-3)
- `testFuzzyMatchRejectsDistanceAboveThresholdBananenMandeln` (AC-4)
- `testFuzzyGateRejectsApfelApfelsaftAboveDistanceThreshold` (AC-5, isolierte Hilfsfunktion)
- `testFuzzyMatchAppliesExistingTieBreakingAmongMultipleCandidates` (AC-6)
- `testExistingSubstringMatchTakesPrecedenceOverFuzzyMatch` (AC-7)

Regressionslauf: gesamte `RestockTests`-Suite (insbesondere bestehende Tests in
`RestockTests/PriceProvenanceMigrationTests.swift` zum Teilstring-Match und zum Tie-Breaking bei
mehreren Treffern) muss im gemeinsamen Lauf grün bleiben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reiner, isolierter Fallback-Zweig innerhalb einer bestehenden Funktion
  (`ShoppingItem.init`), der nur greift, wenn der bestehende Mechanismus keinen Treffer liefert,
  ohne dessen Verhalten zu ändern. Kein neues Architektur-Konzept, keine neue Schicht, keine
  Änderung an Datenmodell oder Modulgrenzen — eine private, isoliert testbare Hilfsfunktion in
  derselben Datei genügt.

## Changelog

- 2026-09-30: Initial spec created
- 2026-09-30: Zwei Beleg-Fälle korrigiert, bei denen die bestehende Teilstring-Prüfung dasselbe
  Namenspaar zusätzlich aus eigenem Grund verknüpft hätte („reis" enthält „eis"; „apfelsaft"
  beginnt mit „apfel") — ein vollständiges `ShoppingItem`-Szenario hätte dort wegen des Vorrangs
  des Teilstring-Treffers nicht die Fuzzy-Ablehnung gezeigt, sondern einen (unveränderten,
  bestehenden) Treffer. AC-2 und AC-5 weisen die Fuzzy-Gate-Werte für diese beiden Zeilen deshalb
  über die isolierte Hilfsfunktion nach statt über `ShoppingItem.init`.
