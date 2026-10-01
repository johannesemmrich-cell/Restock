---
entity_id: legacy-price-reset-migration
type: bugfix
created: 2026-10-01
updated: 2026-10-01
status: draft
workflow: fix-11-falsch-gelernte-preise
tags: [bugfix, price-learning, migration, swiftdata]
---

# Einmalige Migration: Altlast-Preise auf die Schätzung zurücksetzen

## Approval

- [ ] Approved — PO-Freigabe der Spec steht aus. Die Grundentscheidung (Zurücksetzen auf die
  Katalogschätzung, Verlust richtiger Altpreise akzeptiert) hat der PO am 2026-10-01 getroffen
  (siehe `docs/context/fix-11-falsch-gelernte-preise.md`, Abschnitt „Offene Fragen").

## Purpose

Vor #9/#10 wurde auf Rewe-Bons die Zeilensumme als Stückpreis gelernt (z. B. 1,56 € statt 0,39 €
je Laugenbrötchen). Seit #10 sind solche `Store.learnedPrices`-Einträge ohne `learnedPriceUnits`
inert, aber bereits gespeicherte `ShoppingItem.estimatedPrice`-Werte mit
`estimatedPriceIsAutoDerived == false` tragen den Falschwert weiter und zeigen ihn bei abgehakten
Artikeln an bzw. summieren ihn nach Reaktivierung ins Budget. Diese Spec setzt genau diese Werte
einmalig, regelbasiert und ohne Modell auf die Katalogschätzung zurück.

## Source

- **Neue Datei:** `SmartCart/Models/LegacyLearnedPriceReset.swift` — `enum LegacyLearnedPriceReset`
  mit `static let flagKey`, reiner Kernfunktion `shouldReset(...)` und
  `@MainActor static func runIfNeeded(context:)`.
- **Geändert:** `SmartCart/Models/ShoppingItem.swift` — die Namenszuordnung aus
  `ShoppingItem.init` (Teilstring-Schlüssel, Fuzzy-Fallback #52, Tie-Breaker Datum/Schlüssel) wird
  1:1 in `static func matchingLearnedPriceKey(forLowercasedName:in:)` extrahiert; `init` ruft sie
  auf. Verhalten von `init` bleibt bitgleich (bestehende Tests `ShoppingItemFuzzyPriceMatchTests`
  belegen das).
- **Geändert:** `SmartCart/SmartCartApp.swift` — Aufruf direkt nach
  `PriceProvenanceMigration.runIfNeeded(context:)` (~Zeile 527) sowie DEBUG-Seed- und
  Aufräum-Launch-Argument (Muster ~Zeile 233).
- **Neu (Test):** `RestockTests/LegacyLearnedPriceResetTests.swift`;
  `RestockUITests/LegacyLearnedPriceResetUITests.swift`.
- **Xcode-Registrierung:** Jede neue `.swift`-Datei (Produktivcode, Unit-Test, UI-Test) muss in
  `Restock.xcodeproj/project.pbxproj` an vier Stellen registriert werden (`PBXBuildFile`,
  `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`; Test-Dateien im jeweiligen Test-Target).
  `LegacyLearnedPriceReset.swift` gehört nur ins App-Target (nicht in Widget/Extension).

## Scope

**In Scope**

- Einmalige Migration über `UserDefaults`-Flag, Stil `PriceProvenanceMigration`.
- Fingerabdruck (nächster Abschnitt), angewendet auf offene und abgehakte `ShoppingItem`s.
- Wirkung: `estimatedPrice = PriceEstimator.estimate(for:category:unit:quantityAmount:)` und
  `estimatedPriceIsAutoDerived = true`.

**Out of Scope**

- `Store.learnedPrices`, `learnedPriceUnits`, `learnedPriceDates` bleiben unangetastet: Die Altlast
  ist inert (`learnedRateUsage` → `.reject`) und heilt sich beim nächsten Bon selbst durch
  Überschreiben mit Einheit.
- `PurchaseRecord`s (Menge/Einheit vor #54 unzuverlässig) werden nicht verändert.
- Sync geteilter Listen (#53): `SyncCoordinator.apply` / `SharedStoreService.mergePrices`
  übernehmen weiter keine Einheit. Artikelpreise selbst werden nicht synchronisiert
  (`SharedItemData` enthält keinen Preis), eine Mitkorrektur bei anderen Mitgliedern ist weder
  nötig noch möglich.
- Keine Schemaänderung, keine neue UI, kein Modell.

**Scope-Schätzung:** 4 Dateien Produktivcode + 2 Testdateien, ca. +150 LoC (Extraktion in
`ShoppingItem.swift` ca. ±20, neue Datei ca. 60, App-Aufruf/Seed ca. 25, Tests ca. 100 zählen
laut LoC-Gate mit). Gegenüber dem Vorab-Plan (3 Dateien) kommt `ShoppingItem.swift` hinzu, weil
die Namenszuordnung wiederverwendet statt dupliziert wird (Duplikat wäre das Risiko, dass
Migration und `init` auseinanderlaufen).

## Fingerabdruck als Entscheidungstabelle

Größe, die `ShoppingItem.init` damals in `estimatedPrice` schrieb: der gelernte **Wert selbst**
(`estimatedPrice = learnedPrice`, kanonisch pro Einheit, nicht mit `quantityAmount`
multipliziert; die Zeilensumme `estimatedLineTotal = estimatedPrice × quantityAmount` entsteht
erst bei der Anzeige). Auch die späteren Schreibwege (`ReceiptScannerView.save()`,
`ActualPriceEntryView`, `EditItemView`) speichern pro Einheit. Eine „Altwert × Menge“-Variante
wurde nie in `estimatedPrice` geschrieben und wird deshalb **nicht** geprüft.

Sei `key = matchingLearnedPriceKey(...)` der Schlüssel, den `ShoppingItem.init` für den
Artikelnamen im Laden wählen würde (Teilstring, sonst Fuzzy #52, Tie-Breaker Datum/Schlüssel).

| # | Bedingung (alle in dieser Reihenfolge) | Ergebnis |
|---|---|---|
| 1 | `item.store == nil` | unberührt |
| 2 | `item.estimatedPriceIsAutoDerived == true` | unberührt (rein geschätzt) |
| 3 | `item.estimatedPrice == nil` | unberührt |
| 4 | kein `key` im Laden gefunden | unberührt (kein Altlast-Bezug erkennbar) |
| 5 | `store.learnedPriceUnits[key]` vorhanden (nicht leer) | unberührt (Rate mit Einheit, gilt als gültig) |
| 6 | `abs(estimatedPrice - store.learnedPrices[key]) > 0.005` | unberührt (manueller oder anderer Preis abweichenden Werts) |
| 7 | alle obigen nicht zutreffend | **zurücksetzen** |

Zurücksetzen: `estimatedPrice = PriceEstimator.estimate(for: name, category: category, unit: unit,
quantityAmount: quantityAmount)` (kann `nil` sein, dann bleibt der Artikel ohne Preis),
`estimatedPriceIsAutoDerived = true`. `isCompleted`, `quantityAmount`, `unit`, `quantitySource`
bleiben unverändert.

## Implementation Details

```swift
enum LegacyLearnedPriceReset {
    static let flagKey = "legacyLearnedPriceResetV1Applied"

    /// Reine Entscheidung ohne ModelContext (Tabelle oben).
    static func shouldReset(
        hasStore: Bool, isAutoDerived: Bool, estimatedPrice: Double?,
        matchedLearnedPrice: Double?, matchedLearnedUnit: String?
    ) -> Bool

    @MainActor
    static func runIfNeeded(context: ModelContext)
}
```

- `runIfNeeded`: Flag gesetzt → Rückkehr. Sonst alle `ShoppingItem` fetchen; je Artikel `key` über
  `ShoppingItem.matchingLearnedPriceKey` bestimmen, `shouldReset` aufrufen, bei `true`
  zurücksetzen. Danach `try? context.save()` und Flag setzen. Schlägt der Fetch fehl, wird das
  Flag **nicht** gesetzt (nächster Start versucht es erneut), wie bei `PriceProvenanceMigration`.
- Idempotenz: Nach dem Zurücksetzen ist `estimatedPriceIsAutoDerived == true` (Zeile 2 der
  Tabelle), ein zweiter Lauf ändert auch ohne Flag nichts.
- Aufruf in `SmartCartApp.swift` im selben `.task` direkt nach
  `PriceProvenanceMigration.runIfNeeded(context: container.mainContext)`. Reihenfolge ist
  wichtig: `PriceProvenanceMigration` Phase A rekonstruiert die Herkunft und setzt
  `estimatedPriceIsAutoDerived` ggf. neu; die neue Migration baut auf diesem Stand auf.
- DEBUG-Seed `-seedLegacyLearnedPriceForUITests` (Muster
  `seedQuantitySuggestionForUITestsIfNeeded`): `deleteAllStoresAndItems`, Flag
  (`UserDefaults.standard.removeObject(forKey: flagKey)`) entfernen, Laden „Altbon“ mit
  `learnedPrices["laugenbrötchen"] = 1.56` **ohne** `learnedPriceUnits`; vier Artikel, deren
  `estimatedPrice`/`estimatedPriceIsAutoDerived` nach der Konstruktion von Hand auf den
  Altzustand gesetzt wird (der Konstruktor würde den Altwert seit #10 selbst verwerfen):
  „Laugenbrötchen“ abgehakt (1,56, `false`), „Laugenbrötchen groß“ offen (1,56, `false`),
  „Kontrollbrot“ offen (manuell 2,50, `false`, kein Altlast-Schlüssel), alle mit
  `quantityAmount` 1. Die Migration läuft anschließend im normalen App-Start (`.task`) — der
  Durchlauf prüft damit die echte Kette Start → Migration → Anzeige.
- Aufräum-Argument `-clearLegacyLearnedPriceSeedForUITests`: `deleteAllStoresAndItems` + Flag
  entfernen.

## Test Plan

**Unit (`RestockTests/LegacyLearnedPriceResetTests.swift`, In-Memory-`ModelContainer`)**

1. Treffer: Artikel „Laugenbrötchen“, `estimatedPrice 1.56`, `isAutoDerived false`, Store mit
   `learnedPrices["laugenbrötchen"] = 1.56` ohne Einheit → Schätzung, `isAutoDerived true`.
2. Manueller Preis abweichenden Werts (2,50 bei Altwert 1,56) → unberührt.
3. Rate mit Einheit (`learnedPriceUnits["laugenbrötchen"] = "stk"`, Preis gleich) → unberührt.
4. Rein geschätzter Artikel (`isAutoDerived true`) → unberührt.
5. Name ≠ Bon-Name über Teilstring (Artikel „Brötchen“, Schlüssel „laugenbrötchen“) → zurückgesetzt;
   über Fuzzy #52 (Tippfehler, Schlüssel ≥ 5 Zeichen) → zurückgesetzt; Name ohne
   Teilstring/Fuzzy-Treffer → unberührt.
6. Abgehakter Artikel (`isCompleted true`) → zurückgesetzt, `isCompleted` bleibt `true`.
7. Artikel ohne Store → unberührt, kein Absturz.
8. Idempotenz/Flag: zweiter `runIfNeeded` ändert nichts; Flag nach erstem Lauf `true`; bei
   gesetztem Flag wird ein Treffer-Artikel nicht angefasst.
9. Toleranz: Abweichung 0,004 → zurückgesetzt; 0,006 → unberührt (`shouldReset` direkt).
10. `learnedPrices`, `learnedPriceUnits`, `learnedPriceDates` nach dem Lauf unverändert.
11. Gleichheit zu `init`: `matchingLearnedPriceKey` liefert für die Fälle aus
    `ShoppingItemFuzzyPriceMatchTests` denselben Schlüssel wie bisher (Regressionsschutz der
    Extraktion; die bestehende Testklasse bleibt unverändert grün).

**Durchlauf (`RestockUITests/LegacyLearnedPriceResetUITests.swift`)**

App-Start mit `-hasCompletedOnboarding YES -seedLegacyLearnedPriceForUITests`; `tearDown()` startet
die App einmal mit `-clearLegacyLearnedPriceSeedForUITests` (Container überlebt den Test, siehe
Projekt-CLAUDE.md). Test öffnet Laden „Altbon“ und prüft: der abgehakte „Laugenbrötchen“ und der
offene „Laugenbrötchen groß“ zeigen nicht mehr „1,56“; „Kontrollbrot“ zeigt weiter „2,50“.
Der Test läuft in der Scheme-Sprache Deutsch.

## Acceptance Criteria

- AC1: Ein Artikel mit Store, `estimatedPriceIsAutoDerived == false`, `estimatedPrice` gleich dem
  über die `init`-Namenszuordnung gefundenen `learnedPrices`-Wert (Toleranz ≤ 0,005) und ohne
  `learnedPriceUnits`-Eintrag zu diesem Schlüssel wird nach `runIfNeeded` auf
  `PriceEstimator.estimate(for:category:unit:quantityAmount:)` gesetzt und hat
  `estimatedPriceIsAutoDerived == true` (Unit-Test 1).
- AC2: Ein manuell eingetippter Preis, der vom Altwert um mehr als 0,005 abweicht, bleibt
  unverändert (Unit-Test 2).
- AC3: Ein Artikel, dessen zugeordneter `learnedPrices`-Eintrag ein nicht leeres
  `learnedPriceUnits`-Pendant hat, bleibt unverändert (Unit-Test 3).
- AC4: Ein Artikel mit `estimatedPriceIsAutoDerived == true` und ein Artikel ohne
  `estimatedPrice` bleiben unverändert (Unit-Test 4).
- AC5: Die Zuordnung Artikelname → Schlüssel nutzt dieselbe Funktion wie `ShoppingItem.init`
  (Teilstring, dann Fuzzy #52): Ein Artikel „Brötchen“ trifft den Schlüssel „laugenbrötchen“,
  ein Tippfehler-Name trifft per Fuzzy, ein Name ohne Treffer bleibt unverändert
  (Unit-Test 5 und 11; `ShoppingItemFuzzyPriceMatchTests` bleibt grün).
- AC6: Abgehakte und offene Artikel werden gleich behandelt; `isCompleted`, `quantityAmount`,
  `unit` und `quantitySource` bleiben nach dem Zurücksetzen unverändert (Unit-Test 6).
- AC7: Ein Artikel ohne Store bleibt unverändert und löst keinen Absturz aus (Unit-Test 7).
- AC8: Nach dem ersten Lauf ist `UserDefaults` `legacyLearnedPriceResetV1Applied == true`; ein
  zweiter Lauf ändert keinen Artikel; bei gesetztem Flag ändert ein Lauf keinen Artikel
  (Unit-Test 8).
- AC9: `shouldReset` liefert bei Abweichung 0,004 `true` und bei 0,006 `false` (Unit-Test 9).
- AC10: `Store.learnedPrices`, `learnedPriceUnits` und `learnedPriceDates` sind nach dem Lauf
  unverändert (Unit-Test 10).
- AC11: `SmartCartApp.swift` ruft `LegacyLearnedPriceReset.runIfNeeded` direkt nach
  `PriceProvenanceMigration.runIfNeeded` auf (belegt durch den Durchlauf AC12; zusätzlich
  Quellcode-Prüfung der Reihenfolge im Review).
- AC12: Im UI-Durchlauf mit dem Seed zeigt nach App-Start weder der abgehakte noch der offene
  Altlast-Artikel „1,56“, und der manuell bepreiste Kontrollartikel zeigt weiter „2,50“.
- AC13: Das Seed-Aufräum-Argument entfernt Läden, Artikel und das Migrations-Flag; die
  bestehende Test-Suite bleibt im gemeinsamen Lauf grün (keine Folgefehler durch Restdaten).
- AC14: Das Verhalten von `ShoppingItem.init` ändert sich nicht: die Extraktion in `ShoppingItem.init` ist
  verhaltensgleich (alle bestehenden Tests zu gelernten Preisen und `PriceProvenanceMigrationTests`
  bleiben grün).

## Alternativen (verworfen)

- **A. Rückrechnen aus Kaufdaten** (`actualPrice ÷ quantityAmount`, Muster Phase C): verworfen.
  Menge und Einheit der `PurchaseRecord`s sind vor #54 unzuverlässig; bei Menge 1 entstünde
  derselbe Falschwert, nun mit Einheit und damit „gültig“ — schlechter als heute, weil die
  Reparatur Falsches legitimieren würde. Gekippt würde: die Annahme, dass Kaufdaten Belegcharakter
  haben.
- **C. Nutzer korrigiert selbst** (gelernte Preise je Laden anzeigen, ändern, löschen): verworfen.
  Kippt die PO-Entscheidung „automatisch bereinigen“, braucht neue UI inkl. Entwurf vorab und löst
  das Budgetproblem erst nach manueller Arbeit. Bleibt als spätere Ergänzung denkbar.
- **E. Nichts tun:** Falschwerte verschwinden nur, wenn ein Artikel gelöscht oder neu gescannt wird.
  Reaktivierte Artikel verfälschen bis dahin das Budget. Verworfen, da der Fehler am Altstand
  reproduziert ist.
- **Gewählt (B/D):** Zurücksetzen auf die Schätzung — regelbasiert, ohne Modell, ohne Kriterium
  „ist falsch“. Kosten: richtige Altpreise (z. B. echter Teuer-Artikel mit Altwert) gehen
  verloren, der nächste Bon lernt sie mit Einheit neu. Der PO hat das akzeptiert.

## Risiken und offene Grenzen

- **Offene Grenze 1:** Ein manuell eingetippter Preis, der zufällig exakt (±0,005) dem Altwert
  des zugeordneten Schlüssels entspricht, ist von einem gelernten Preis nicht unterscheidbar
  (`estimatedPriceIsAutoDerived == false` gilt für beide) und wird ebenfalls zurückgesetzt.
- **Offene Grenze 2:** Die tatsächliche Population auf Hennings Gerät ist unbekannt (Daten nicht
  lesbar). Die Migration wurde nur an konstruiertem Altstand gezeigt, nicht an echten Daten.
  Der Nachweis liegt auf Unit- und Durchlauf-Ebene, nicht auf Hennings Bestand.
- **Offene Grenze 3:** Sync/#53 bleibt ungelöst. Ein remote stehender Falschpreis mit neuerem
  Datum kann `learnedPrices` lokal weiter überschreiben (ohne Einheit, daher inert). Diese
  Migration korrigiert nur lokale Artikelpreise, nicht die geteilte Preisbasis.
- **Offene Grenze 4:** Durch die Einmaligkeit (Flag) werden Artikel, die erst nach dem Lauf
  per Sync mit Altwerten entstehen, nicht erfasst; Artikelpreise werden jedoch nicht
  synchronisiert, daher kein bekannter Weg.
- **Risiko Datenänderung:** Werte an CloudKit-gespiegelten Modellen ändern sich (private
  Mirror), ohne Schema-Bump. Rückgängig machen nicht möglich; deshalb Fingerabdruck eng
  (Tabelle) statt breit.

## Side-Effects

- **Dateien:** `SmartCart/Models/LegacyLearnedPriceReset.swift` (neu),
  `SmartCart/Models/ShoppingItem.swift` (Extraktion Namenszuordnung),
  `SmartCart/SmartCartApp.swift` (Aufruf, DEBUG-Seed/-Aufräumen),
  `RestockTests/LegacyLearnedPriceResetTests.swift` (neu),
  `RestockUITests/LegacyLearnedPriceResetUITests.swift` (neu),
  `Restock.xcodeproj/project.pbxproj` (Registrierung, vier Stellen je neuer Datei).
- **Info.plist / Permissions:** keine Änderung.
- **AppStorage/UserDefaults:** ein neuer Key `legacyLearnedPriceResetV1Applied` (`UserDefaults`
  `.standard`), sonst keiner.
- **Schema/CloudKit:** keine Änderung; nur Werte vorhandener Felder.
- **Audio-Dateien:** keine.
- **Sichtbare Wirkung:** Betroffene Artikel zeigen statt des Altwerts die Katalogschätzung
  („ca.“-Herkunft wie bei anderen geschätzten Preisen), Budgetsumme in `PriceOverviewView`
  sinkt entsprechend.

## Changelog

- 2026-10-01: Erstfassung (Issue #11, Variante B/D).
