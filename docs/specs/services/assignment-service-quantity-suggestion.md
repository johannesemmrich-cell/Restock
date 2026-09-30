---
entity_id: assignment-service-quantity-suggestion
type: feature
created: 2026-09-30
updated: 2026-09-30
status: draft
workflow: fix-57-menge-vorbelegen
tags: [feature, quantity, assignment-service, add-item]
---

# Mengen-Vorbelegung beim Anlegen eines Artikels

## Approval

- [x] Approved — PO, 2026-09-30, auf Grundlage des unabhängigen Briefings
  `docs/briefings/fix-57-menge-vorbelegen.md`. Mit der Auflage, dass die Known Limitation
  „Schnell-Eingabe/Siri" nicht dauerhaft offen bleibt: als eigenes Ticket angelegt, Issue #76.

## Purpose

Trägt der Nutzer einen Artikel ohne Menge ein, bleibt `quantitySource` bislang immer `"user"` und
die Menge stumm `1` — dadurch greift die in Issue #10 gebaute Entscheidungstabelle
(`ShoppingItem.learnedRateUsage`) praktisch nie in ihrer `.rateOnly`-Stufe, und eine belegbare
Menge aus dem letzten Kauf oder aus der Füllmenge im Namen bleibt ungenutzt. Diese Spec gibt
`AddItemView` eine reine, testbare Funktion (`AssignmentService.suggestQuantity`), die aus vier
gestuft geprüften Evidenzquellen eine Mengen-Voreinstellung ableitet, sie als Annahme kennzeichnet
(„ca. 400 g", getönt) statt wie eine eingetippte Menge, und ohne jede Evidenz statt eines
erfundenen Gesamtpreises nur die Rate zeigt („1,25 €/100 g"). Zweiter, aus Issue #10 abgespaltener
Teil derselben ursprünglichen Anforderung (PO-Entscheidung 2026-09-26, siehe
`docs/specs/models/learned-price-unit-and-quantity-source.md`, Abschnitt „Nach Issue #57
verschoben").

**Entwurf bereits freigegeben, keine neue Runde nötig.** `docs/artifacts/fix-10-preis-einheit/entwurf.html`
(veröffentlicht unter https://claude.ai/artifact/AwBQGPWJAdch2aNkPMonUL) zeigt den Ist-Zustand
neben drei Entwürfen in Hell und Dunkel; der PO hat am 2026-09-26 **Variante B** gewählt
(angenommene Menge sichtbar als Annahme markiert). Ihr Aussehen ist in `ItemRow` bereits
umgesetzt (siehe „Bereits im Code vorhanden" unten) — diese Spec liefert nur noch, was sie
erreichbar macht.

## Source

- **File:** `SmartCart/Services/AssignmentService.swift`
- **Identifier:** neu: `static func suggestQuantity(itemName:storeName:purchaseRecords:) ->
  (quantity: String, unit: String, source: String)`
- **Weitere Dateien:** `SmartCart/Views/Store/AddItemView.swift` (Ersetzung von
  `applySuggestedQuantity`, zwei berechnete Bindings, `addItem()`),
  `SmartCart/Views/Components/ItemRow.swift` (Preiszelle, AC-15-Fallback)

## Problem und Kontext

### Bereits im Code vorhanden (aus Issue #10, geprüft 2026-09-30)

| Was | Datei | Status |
|---|---|---|
| `quantitySource: String = "user"` am `ShoppingItem` + Konstruktor-Parameter | `Models/ShoppingItem.swift:62,106,114` | vorhanden |
| `estimatedLineTotal` liefert `nil` bei `quantitySource == "none"` | `Models/ShoppingItem.swift:261-264` | vorhanden |
| `learnedRateUsage` behandelt `quantitySource == "none"` als `.rateOnly` | `Models/ShoppingItem.swift:224-233` | vorhanden |
| Mengenzeile: `"ca. "`-Präfix + `Color.amber` bei `history`/`package`, keine Anzeige bei `none` (AC-14) | `Views/Components/ItemRow.swift:90-95` | vorhanden, aber **unerreichbar** — nichts setzt `quantitySource` auf etwas anderes als `"user"` |
| `quantitySource = "user"` beim manuellen Korrigieren in `EditItemView` (AC-16) | `Views/Store/EditItemView.swift:343` | vorhanden |
| `packageSizeFromName(_:) -> (amount: Double, unit: String)?` | `Services/ReceiptParserService.swift:924` | vorhanden (aus #10, für Stufe 3 gebaut, bisher ungenutzt) |

Dieser Code compiliert und bricht keinen Bestandstest, sein Verhalten ist aber **nicht
nachgewiesen** — die vier UI-Tests dafür wurden mit nach #57 gezogen (siehe Test Plan).

### Ist-Zustand von `AddItemView.applySuggestedQuantity` — abweichend von der #10-Spec-Beschreibung

Geprüft am aktuellen Code (`AddItemView.swift:182-198`):

- Filtert `allRecords` **nur nach Name**, laden-übergreifend über `contains()` in beide
  Richtungen — **kein** `storeName`-Filter.
- Bildet den **Durchschnitt der letzten 5 Käufe**, nicht „den letzten Kauf" (PO-Entscheidung 2
  spricht von „letzte gekaufte Menge", Singular).
- Setzt **kein** `quantitySource` — die Variable existiert im View noch nicht.
- Ruft **nicht** `packageSizeFromName` auf (Stufe 3 fehlt vollständig).
- Läuft für beide Aufrufer (`presetStore`-Fall `AddItemView.swift:170-172` und
  Auto-Zuweisungs-Fall `AddItemView.swift:174-179`) — beide bleiben erhalten, nur der
  Funktionskörper wandert um.

Diese bestehende Logik wird durch den Aufruf von `suggestQuantity` **vollständig ersetzt**, nicht
ergänzt — sonst entstehen zwei konkurrierende Mengen-Vorschläge.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `AssignmentService.namesRepresentSameItem(_:_:)` (`AssignmentService.swift:56-59`) | function | Wortbasierter, diakritik-gefalteter, qualifizierer-bereinigter Namensvergleich — Grundlage für Stufe 2 statt eines neuen Ad-hoc-`contains()`. |
| `AssignmentService.normalizedStoreKey(_:)` (`AssignmentService+Category.swift`-Nachbardatei, tatsächlich `AssignmentService.swift:75-77`) | function | Laden-Vergleich getrimmt/kleingeschrieben, dasselbe Muster wie `dominantStore`/`bestFallback`. |
| `PurchaseRecord.storeName` / `.quantityAmount` / `.unit` (`Models/PurchaseRecord.swift:11-14`) | property | Evidenzquelle Stufe 2 (letzter Kauf in diesem Laden). |
| `ReceiptParserService.packageSizeFromName(_:)` (`Services/ReceiptParserService.swift:924`) | function | Evidenzquelle Stufe 3 (Füllmenge im getippten Namen), bereits vorhanden aus #10. |
| `Color.amber` (`DesignSystem.swift`) | token | Tönung der Annahme-Markierung, bereits verdrahtet in `ItemRow`. |
| `QuantityStepperField(quantity:unit:)` (`Views/Components/QuantityStepperField.swift:9-10`) | view | Nimmt `@Binding<String>` entgegen — wird unverändert weiterverwendet, nur die übergebenen Bindings werden berechnet statt direkt. |
| `ShoppingItem.quantitySource` (Issue #10) | property | Zielfeld, an das `suggestQuantity`s `source`-Ergebnis über `addItem()` durchgereicht wird. |

**Downstream:** `ItemRow` (AC-14 wird erst durch diese Spec erreichbar, AC-15 wird hier gebaut),
`EditItemView` (AC-16 bereits verdrahtet, unverändert). Kein bekannter weiterer Abhängiger — #15
(Preisvergleich) und #11 (Altdaten-Reparatur) bauen fachlich auf #10, nicht auf #57.

## Scope

### In scope

| Datei | Change Type | Beschreibung | LoC |
|---|---|---|---|
| `SmartCart/Services/AssignmentService.swift` | MODIFY | `suggestQuantity(itemName:storeName:purchaseRecords:)` neu, vier Stufen | +45 |
| `SmartCart/Views/Store/AddItemView.swift` | MODIFY | `applySuggestedQuantity` ersetzt durch Aufruf von `suggestQuantity`; zwei Bindings an `QuantityStepperField`/Einheiten-Textfeld werden berechnet (`Binding(get:set:)`, setzen `quantitySource = "user"`); neuer `@State private var quantitySource`; `addItem()` reicht ihn durch | +20/-17 |
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY | Preiszelle: Fallback auf Rate `estimatedPrice × 100` mit „/100 g", wenn `estimatedLineTotal == nil`, `quantitySource == "none"`, `unit == "g"` (AC-15) | +9 |
| `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` | CREATE | 7 Unit-Tests zu den vier Stufen (AC-11–13) + 1 Unit-Test WCAG-Kontrast (AC-18) | +122 |
| `RestockUITests/ReceiptReviewUITests.swift` (oder eigene Klasse) | MODIFY/CREATE | 4 UI-Tests (AC-13, AC-14, AC-15, AC-16) | +80 |

Produktivcode: **3 Dateien, ~74 LoC** (innerhalb der 4-5-Dateien-/±250-LoC-Grenze). Mit Testcode
zusammengezählt (Issue #36 zählt ihn als Produktivcode) **~276 LoC** — über der 250er-Schwelle.
Siehe „Risiken" für die Gegenmaßnahme; das Gate wird während der Umsetzung anschlagen, das ist
eingeplant (Muster aus #10).

### Out of scope

- **Preisvergleich zwischen Läden** → Issue #15, baut fachlich auf #10, nicht auf #57.
- **Reparatur der einheitenlosen Altdaten** → Issue #11, baut fachlich auf #10, nicht auf #57.
- **Schnell-Eingabe (`HomeView`) und `AddItemIntent` (Siri)** bekommen die Stufenlogik nicht — sie
  rufen `suggestQuantity` nicht auf und legen weiterhin mit `quantityAmount = 1`, `unit = ""`,
  `quantitySource = "user"` an. Siri hat keinen Bildschirm, auf dem eine Annahme sichtbar und
  korrigierbar wäre; die vorhandene Entscheidungstabelle aus #10 schützt diese Pfade trotzdem vor
  einer falsch angewendeten Rate (siehe Known Limitations).
- **Sync geteilter Listen** — `quantitySource` reist bereits additiv über die bestehenden
  SwiftData-Felder, keine gesonderte Sync-Änderung nötig oder vorgesehen.

## Implementation Details

### 1. `AssignmentService.suggestQuantity` — vier Stufen als reine Funktion

```swift
/// Leitet aus nachweisbarer Evidenz eine Mengen-Voreinstellung für einen neu anzulegenden
/// Artikel ab. Reine Funktion über Werten — kein SwiftUI, kein ModelContext —, damit die vier
/// Stufen einzeln nachweisbar sind statt nur beschrieben.
static func suggestQuantity(itemName: String, storeName: String, purchaseRecords: [PurchaseRecord])
    -> (quantity: String, unit: String, source: String)
```

1. **Letzter Kauf in diesem Laden** (Stufe 2 der ursprünglichen Nummerierung — Stufe 1,
   „Nutzereingabe", bleibt Guard in `AddItemView` und ruft die Funktion gar nicht erst auf):
   `purchaseRecords` wird gefiltert über `namesRepresentSameItem(record.itemName, itemName)` UND
   `normalizedStoreKey(record.storeName) == normalizedStoreKey(storeName)`. Aus den Treffern wird
   **der letzte Kauf** (`max(by: date)`) genommen, nicht ein Durchschnitt. Findet sich darüber
   nichts, wird **nicht** laden-übergreifend zurückgefallen — PO-Entscheidung 2 nennt ausdrücklich
   „in diesem Laden". → `source == "history"`.
2. **Füllmenge im getippten Namen:** `ReceiptParserService.packageSizeFromName(itemName)`. →
   `source == "package"`.
3. **Keine Evidenz:** leere Menge, leere Einheit. → `source == "none"`.

**Zwei technische Detailentscheidungen** (nicht durch die #10-Spec abgedeckt, hier getroffen):

**a) Namensvergleich in Stufe „history".** Das zu ersetzende `applySuggestedQuantity` vergleicht
Namen ad-hoc über `contains()` in beide Richtungen (`AddItemView.swift:188`) — dieselbe
Fehlerklasse, gegen die `AssignmentService.namesRepresentSameItem` (`AssignmentService.swift:56-59`)
im selben Typ bereits gebaut wurde (verhindert z. B., dass „Eierlikör" als „Eier" zählt).
`suggestQuantity` nutzt `namesRepresentSameItem` + `normalizedStoreKey` für den Laden-Filter —
dieselbe Funktion, die `assign()` im selben Typ bereits verwendet, kein neuer Code, eine einzige
Quelle der Wahrheit für „gleicher Artikel". **Verworfene Alternative:** den bestehenden
`contains()`-Vergleich unverändert mitnehmen — kleinster Diff, reproduziert aber ohne Not die
Fehlerklasse, gegen die `namesRepresentSameItem` bereits gebaut wurde.

**b) Rücksetzen von `quantitySource`, wenn der Nutzer die vorbelegte Menge vor dem Speichern noch
ändert.** `EditItemView` hat für den Nachträglich-Fall bereits ein Vorbild
(`EditItemView.swift:343`: `quantitySource = "user"` direkt nach dem Schreiben), `AddItemView`
bisher keine Entsprechung. Die beiden Bindings, die an `QuantityStepperField(quantity:unit:)` und
das `unit`-Textfeld übergeben werden, werden durch je eine berechnete `Binding(get:set:)` ersetzt,
die bei jedem manuellen Schreiben zusätzlich `quantitySource = "user"` setzt.
`applySuggestedQuantity`s Nachfolger schreibt weiterhin direkt auf die `@State`-Variablen und
bleibt davon unberührt. **Verworfene Alternative:** `.onChange(of: quantity)` /
`.onChange(of: unit)` — verworfen, weil die Vorbelegung selbst `quantity`/`unit` beschreibt und ein
`onChange` die eigene Vorbelegung im selben Update-Zyklus sofort wieder auf `"user"`
zurücksetzen und das Feature dadurch wirkungslos machen würde.

**c) Einzelstück-Käufe ohne belegte Menge als Kaufhistorie-Evidenz** (im Intake zu #57 als offene
Detailfrage benannt, technische Entscheidung hier getroffen). Ein `PurchaseRecord` trägt keine
eigene Herkunftsangabe — `ShoppingItem.markCompleted()` (`ShoppingItem.swift:266-280`) übernimmt
beim Abhaken stets den aktuellen `quantityAmount`/`unit` des Artikels unverändert, unabhängig davon,
ob diese Werte vom Nutzer eingetippt oder nie angefasste Defaults sind (`quantityAmount: Double =
1`, Zeile 40). Das gilt bereits heute für jeden Alltagsartikel ohne Mengenangabe (z. B. „Milch") und
ist **kein neues Verhalten von #57** — `suggestQuantity` macht es nur erstmals sichtbar.
**Entscheidung:** Stufe „history" übernimmt jeden gefundenen `PurchaseRecord` unverändert, auch bei
`quantityAmount == 1` und `unit == ""`. Das ist von einem Nutzer, der bewusst „1 Stück" einträgt, im
Datenmodell nicht unterscheidbar — beide erzeugen denselben `PurchaseRecord`. Ein solcher Vorschlag
zeigt „ca. 1" ohne Einheit; einen falschen Gesamtpreis kann er nicht erzeugen, weil die
#10-Entscheidungstabelle (`ShoppingItem.learnedRateUsage`) jede gelernte Gramm-Rate für einen
Artikel mit `unit == ""`/`"stk"` verwirft — das Risiko ist rein kosmetisch, nicht rechnerisch.
**Verworfene Alternative:** `PurchaseRecord` um ein Feld erweitern, das festhält, ob die Menge beim
Kauf real vom Nutzer gesetzt war, und Stufe „history" nur auf solche Records anwenden. Verworfen,
weil das eine Schema-Erweiterung außerhalb des vereinbarten Scopes (3 Produktdateien) für ein
Verhalten wäre, das nicht neu und nicht als Fehler gemeldet ist; der Umgang mit unbelegten
Kaufmengen am `PurchaseRecord` selbst ist Gegenstand von **Issue #54** (Gewicht am
`PurchaseRecord`), nicht dieses Tickets.

### 2. Anbindung in `AddItemView`

`applySuggestedQuantity(for:)` (`AddItemView.swift:182-198`) wird vollständig ersetzt: der Guard
`quantity.isEmpty` bleibt (Stufe „Nutzereingabe"), danach wird `suggestQuantity` aufgerufen und das
Ergebnis in `quantity`, `unit` und einen neuen `@State private var quantitySource: String = "user"`
geschrieben. Beide bestehenden Aufrufer (`presetStore`-Fall, Auto-Zuweisungs-Fall) bleiben
unverändert an ihrer jeweiligen Stelle.

```swift
QuantityStepperField(
    quantity: Binding(
        get: { quantity },
        set: { quantity = $0; quantitySource = "user" }
    ),
    unit: Binding(
        get: { unit },
        set: { unit = $0; quantitySource = "user" }
    )
)
```

Die freistehende `TextField(.... text: $unit)` daneben bindet an dieselbe berechnete `unit`-Binding
statt direkt an `$unit`.

`addItem()` (`AddItemView.swift:200-219`) reicht `quantitySource` zusätzlich an den
`ShoppingItem`-Konstruktor durch (Parameter existiert bereits aus #10, Standardwert `"user"`).

### 3. Preiszelle in `ItemRow` (AC-15)

Die Preiszelle (`ItemRow.swift:146-150`) zeigt heute bei `estimatedLineTotal == nil` gar nichts.
Neuer Fallback: Ist `estimatedLineTotal == nil`, `item.quantitySource == "none"` und
`item.unit == "g"`, wird stattdessen die Rate als `item.estimatedPrice.map { $0 * 100 }` mit dem
Zusatz „/100 g" angezeigt (Formatierung analog zur bestehenden Betragsformatierung). In allen
übrigen Fällen bleibt die Zelle unverändert.

### 4. AC-18 — Kontrastnachweis statt Sichtprüfung (Recherche)

Der Intake verlangte „lesbar im Dunkelmodus" ohne Messwert. **Regel vor Modell:** Kontrast ist
über die WCAG-Formel exakt berechenbar, ein XCUITest kann Pixelkontrast ohnehin nicht messen
(nur Sichtbarkeit/Text), also ist ein deterministischer **Unit-Test** die richtige Nachweisform,
kein UI-Test.

**Standard:** WCAG 2.1, Kriterium 1.4.3 „Contrast (Minimum)", Level AA — 4,5 : 1 für Fließtext
unter 18 pt bzw. 14 pt fett, 3 : 1 für größeren Text
(https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html). Die „ca."-Mengenzeile in
`ItemRow` läuft in Fließtextgröße, also gilt die 4,5 : 1-Schwelle.

**Nachgerechnet** (relative Luminanz nach WCAG-Formel, Farbwerte aus
`Assets.xcassets/RCAmber.colorset` und `RCSurface.colorset`):

| Modus | Vordergrund (`RCAmber`) | Hintergrund (`RCSurface`) | Kontrast |
|---|---|---|---|
| Dunkel | 0,784 / 0,604 / 0,290 | 0,114 / 0,110 / 0,086 | **6,64 : 1** — erfüllt AA |
| Hell | 0,663 / 0,498 / 0,180 | 0,992 / 0,984 / 0,957 | **3,52 : 1** — erfüllt AA für Fließtext NICHT |

Der Dunkelmodus-Fall aus AC-18 ist damit unauffällig — der eigentlich grenzwertige Fall ist der
**Hellmodus**, der nach AC-18 nicht gefordert ist. `Color.amber` ist eine app-weite, bereits an
zahlreichen Stellen verwendete Design-Token („Nachkauf-Dringlichkeit", `DesignSystem.swift:7-8`);
sie hier nur für die Mengenzeile dieses Tickets zu ändern wäre ein inkonsistenter Fleck-Fix, eine
app-weite Korrektur wäre ein Eingriff weit außerhalb des Scopes (3 Dateien) und bräuchte nach der
Regel vom 2026-09-22 eine eigene Entwurfsvorschau, weil sie sichtbar wäre. **Als eigenes Ticket
angelegt: Issue #75** („Color.amber unterschreitet im Hellmodus WCAG-AA-Kontrast für Fließtext").
Vermerkt unter „Known Limitations".

**Umsetzung des Tests:** Ein neuer Unit-Test in `RestockTests/AssignmentServiceQuantitySuggestionTests.swift`
(pragmatisch dieselbe Datei — ein einzelner Kontrast-Test rechtfertigt keine eigene Datei mit
eigenen `project.pbxproj`-Einträgen) berechnet das WCAG-Kontrastverhältnis aus den zwei Farbwerten
oben und prüft `>= 4.5`. AC-18 wird damit **rechnerisch**, nicht durch Sichtprüfung im
Simulator-Screenshot, bewiesen.

## Invarianten

- **Lieber kein Preis als ein falscher.** Stufe „none" liefert bewusst keinen Gesamtpreis, nur die
  Rate — unverändert aus #10 übernommen, hier nur erreichbar gemacht.
- **Regeln vor Modell.** Alle vier Stufen sind deterministisch (Historie, RegEx auf dem Namen),
  kein Sprachmodell.
- **`applySuggestedQuantity` schreibt weiterhin direkt** auf `quantity`/`unit`/`quantitySource` —
  die berechneten Bindings betreffen nur manuelle Nutzereingaben, nicht die Vorbelegung selbst.
- **`suggestQuantity` bleibt eine reine Funktion** über Werten (kein `ModelContext`, kein
  SwiftUI-Environment) — damit einzeln, ohne View-Host, testbar.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten (AC-11 bis AC-16, AC-18) ist durch einen automatischen Unit-
      oder UI-Test belegt, im gemeinsamen Testlauf grün.
- [ ] `applySuggestedQuantity` ist vollständig durch den Aufruf von `AssignmentService.suggestQuantity`
      ersetzt, nicht ergänzt — kein doppelter Mengen-Vorschlag mehr möglich.
- [ ] Die App wurde mit dem geänderten Stand im Simulator durchgespielt: ein Artikel ohne Menge
      anlegen und die Annahme-Markierung „ca. …" bzw. die Rate „…/100 g" tatsächlich in der Liste
      sehen — nicht nur grüne Tests.
- [ ] Die Bestandssuite (Unit + UI) läuft im gemeinsamen Lauf unverändert grün weiter.

## Test Plan

### Unit-Tests — `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` (neu)

| Test | Beweist |
|---|---|
| `testSuggestsLastPurchaseFromSameStore` (AC-11) | GIVEN ein Kauf desselben Artikels im selben Laden liegt vor WHEN `suggestQuantity` aufgerufen wird THEN liefert es dessen Menge/Einheit und `source == "history"`. |
| `testIgnoresPurchaseFromDifferentStore` (AC-11) | GIVEN derselbe Artikel wurde nur in einem ANDEREN Laden gekauft WHEN `suggestQuantity` mit dem aktuellen Laden aufgerufen wird THEN wird NICHT laden-übergreifend zurückgefallen — Ergebnis ist Stufe „package" oder „none", nie „history". |
| `testUsesNamesRepresentSameItemNotSubstring` (AC-11) | GIVEN ein Kauf von „Eierlikör" liegt vor, der Nutzer tippt „Eier" WHEN `suggestQuantity` aufgerufen wird THEN wird der Eierlikör-Kauf NICHT als Treffer gewertet (kein `contains()`-Fehltreffer). |
| `testMatchesQualifierVariantViaNamesRepresentSameItem` (AC-11) | GIVEN ein Kauf von „Bio Eier" liegt vor, der Nutzer tippt „Eier" WHEN `suggestQuantity` aufgerufen wird THEN liefert es diesen Kauf mit `source == "history"` (Qualifizierer-Toleranz von `namesRepresentSameItem`). |
| `testPicksMostRecentPurchaseNotAverage` (AC-11) | GIVEN mehrere Käufe desselben Artikels im selben Laden mit unterschiedlichen Mengen und Daten liegen vor WHEN `suggestQuantity` aufgerufen wird THEN liefert es die Menge des Kaufs mit dem spätesten Datum, nicht einen Durchschnitt. |
| `testFallsBackToPackageSizeWhenNoHistory` (AC-12) | GIVEN keine Kaufhistorie liegt vor, der Name enthält „500G" WHEN `suggestQuantity` aufgerufen wird THEN liefert es `(500, "g")` und `source == "package"`. |
| `testReturnsNoneWhenNoEvidenceAtAll` (AC-13) | GIVEN keine Kaufhistorie und keine Füllmenge im Namen WHEN `suggestQuantity` aufgerufen wird THEN liefert es leere Menge, leere Einheit, `source == "none"`. |
| `testAmberDarkModeContrastMeetsWCAGAA` (AC-18) | GIVEN die RGB-Werte von `RCAmber` und `RCSurface` in der Dunkelmodus-Variante WHEN das WCAG-Kontrastverhältnis berechnet wird THEN ist es `>= 4.5` (Level AA für Fließtext) — rechnerischer Nachweis, siehe Implementation Details 4. |

AC-13s zweiter Teil (Bypass bei Nutzereingabe) wird durch den UI-Test
`testUserTypedQuantityIsNeverMarkedAsAssumption` unten nachgewiesen — er ist View-Verhalten
(Guard in `AddItemView`), nicht Teil der reinen Funktion `suggestQuantity`.

### UI-Tests — `RestockUITests/ReceiptReviewUITests.swift` (oder eigene Klasse)

Namen exakt wie in der #10-Spec vorgezogen:

| Test | Beweist |
|---|---|
| `testAssumedQuantityIsMarkedAsAssumptionInList` (AC-14) | GIVEN ein Artikel wird mit `quantitySource == "history"` oder `"package"` angelegt WHEN die Liste geöffnet wird THEN zeigt die Mengenzeile „ca. <Menge> <Einheit>" in `Color.amber` statt `.secondary`. |
| `testItemWithoutEvidenceShowsRateInsteadOfTotal` (AC-15) | GIVEN ein Artikel ohne belegte Menge und mit gelernter Gramm-Rate wird angelegt (`quantitySource == "none"`) WHEN die Liste geöffnet wird THEN zeigt die Preiszelle die Rate „<Betrag> €/100 g" statt eines Gesamtpreises oder gar nichts. |
| `testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal` (AC-16) | GIVEN ein Artikel mit angenommener Menge ist in der Liste WHEN der Nutzer die Menge in `EditItemView` manuell korrigiert und speichert THEN verschwindet die „ca."-Markierung und die Preiszelle zeigt wieder einen Gesamtpreis. |
| `testUserTypedQuantityIsNeverMarkedAsAssumption` (AC-13) | GIVEN der Nutzer tippt beim Anlegen selbst eine Menge ein (`quantity` nicht leer) WHEN der Artikel gespeichert und die Liste geöffnet wird THEN zeigt die Mengenzeile die Menge OHNE „ca."-Präfix und OHNE `Color.amber` — der Guard `quantity.isEmpty` (`AddItemView.swift:183`, unverändert aus dem Bestand) übersprang `suggestQuantity` komplett, `quantitySource` blieb beim Default `"user"`. |

Die ersten drei dieser vier UI-Tests weisen **erstmals** das bereits geschriebene
AC-14/AC-16-Verhalten nach — sie implementieren kein neues Anzeigeverhalten für diese beiden ACs,
nur die Testabdeckung dafür. AC-15 (Preiszelle) ist dagegen neu gebauter Code (siehe Implementation
Details 3). Der vierte Test (`testUserTypedQuantityIsNeverMarkedAsAssumption`, AC-13) sichert
unveränderten, bereits heute aktiven Bestandscode (den Guard `quantity.isEmpty`) gegen eine
Regression ab — ohne ihn wäre AC-13 nur zur Hälfte geprüft (Stufe „none" ja, Bypass bei
Nutzereingabe nicht). AC-18 wird **nicht** per UI-Test geprüft (siehe Implementation Details 4) —
ein XCUITest kann Pixelkontrast nicht messen, nur Sichtbarkeit; der Nachweis ist der Unit-Test
oben.

Tests laufen über die Test-Action des Schemas auf Deutsch (`language="de"`, `region="DE"`) und
prüfen Anzeigetexte — bekanntes Restrisiko #18/#20 (UI-Tests hängen an Anzeigetexten). Jede Klasse,
die Daten sät, räumt in `tearDown()` über ihr eigenes Aufräum-Argument wieder auf, weil der
App-Group-Container den Lauf überlebt.

**Gegenmaßnahme LoC-Grenze (Issue #36):** Nach den drei Produktdateien (Kernfunktion, Anbindung,
Anzeige) wird ein grüner Zwischenstand gesichert, bevor die beiden Testdateien wachsen.

**Bekanntes Restrisiko:** Testrunner-Hänger (#63, Xcode-26-Umgebungsproblem) — betraf 3 von 4
Anläufen bei #10, kein Code-Fehler, Wiederholung einplanen.

## Acceptance Criteria

- **AC-11:** `AssignmentService.suggestQuantity` liefert bei genau einem passenden Kauf desselben
  Artikels im selben Laden dessen Menge und Einheit und setzt `source == "history"`; ein Kauf
  desselben Artikels in einem ANDEREN Laden wird nicht laden-übergreifend übernommen. Liegen
  mehrere passende Käufe vor, liefert sie die Menge des **zeitlich letzten** Kaufs, nicht einen
  Durchschnitt; der Namensvergleich läuft über `AssignmentService.namesRepresentSameItem`, nicht
  über `contains()` (kein Fehltreffer wie „Eierlikör" für „Eier", aber Toleranz für Qualifizierer
  wie „Bio Eier" für „Eier").
- **AC-12:** Ohne passenden Kauf, aber mit einer im Namen erkennbaren Füllmenge, liefert
  `suggestQuantity` für `"Skyr Natur 500g"` das Ergebnis `("500", "g", "package")` und für
  `"Cola 0,5L"` das Ergebnis `("500", "ml", "package")`.
- **AC-13:** Ohne Historie und ohne Füllmenge liefert `suggestQuantity` leere Menge/Einheit und
  `source == "none"`. Hat der Nutzer selbst eine Menge eingetippt, wird `suggestQuantity` gar nicht
  erst aufgerufen (Guard `quantity.isEmpty` in `AddItemView`, unveränderter Bestandscode) — der
  Artikel entsteht mit `quantitySource == "user"`, nie mit einer „ca."-Markierung.
- **AC-14:** Ein in der Liste angezeigter Artikel mit `quantitySource == "history"` oder
  `"package"` zeigt seine Menge mit Präfix „ca. " in `Color.amber`; ein Artikel mit
  `quantitySource == "user"` zeigt seine Menge unverändert in `.secondary`; ein Artikel mit
  `quantitySource == "none"` zeigt gar keine Mengenangabe.
- **AC-15:** Ein Artikel mit `quantitySource == "none"`, `unit == "g"` und gesetztem
  `estimatedPrice` zeigt in der Preiszelle die Rate `estimatedPrice × 100` mit dem Zusatz
  „/100 g" statt eines Gesamtpreises oder gar keiner Zelle.
- **AC-16:** Korrigiert der Nutzer die Menge eines Artikels mit angenommener Menge in
  `EditItemView` und speichert, wird `quantitySource` auf `"user"` zurückgesetzt — die
  „ca."-Markierung verschwindet und die Preiszelle zeigt wieder einen Gesamtpreis.
- **AC-18:** Das Kontrastverhältnis zwischen `Color.amber` (Dunkelmodus-Variante, `RCAmber`
  dunkel: sRGB 0,784/0,604/0,290) und dem Zeilenhintergrund `Color.surface` (`RCSurface`
  dunkel: sRGB 0,114/0,110/0,086) erreicht mindestens **4,5 : 1** — WCAG 2.1 Level AA für
  Fließtext (siehe „Recherche" unten). Gemessen: **6,64 : 1**, die Anforderung ist bereits mit
  dem bestehenden `RCAmber`-Farbwert erfüllt, ohne Farbänderung.

## Alternativen (verworfen)

- **Bestehenden `contains()`-Namensvergleich in Stufe „history" unverändert mitnehmen** statt
  `namesRepresentSameItem` zu verwenden. Kleinster Diff, reproduziert aber ohne Not die
  Fehlerklasse (Substring-Fehltreffer wie „Eierlikör" ≈ „Eier"), gegen die `namesRepresentSameItem`
  im selben Typ bereits gebaut wurde. Verworfen zugunsten einer einzigen Quelle der Wahrheit für
  „gleicher Artikel" innerhalb von `AssignmentService`.
- **`.onChange(of: quantity)` / `.onChange(of: unit)`** statt berechneter Bindings, um
  `quantitySource` bei manueller Eingabe zurückzusetzen. Verworfen, weil `applySuggestedQuantity`s
  Nachfolger selbst `quantity`/`unit` beschreibt — ein `onChange` würde die eigene Vorbelegung im
  selben Update-Zyklus sofort wieder auf `"user"` zurücksetzen und das Feature wirkungslos machen.
- **Durchschnitt der letzten N Käufe statt des letzten Kaufs** (heutiges Verhalten von
  `applySuggestedQuantity`, Durchschnitt der letzten 5). Verworfen, weil PO-Entscheidung 2
  ausdrücklich „letzte gekaufte Menge" (Singular) verlangt — ein Durchschnitt würde bei
  schwankenden Mengen (z. B. mal 2 mal 6 Stück) einen Wert liefern, den der Nutzer nie tatsächlich
  gekauft hat.
- **Neue Entwurfsrunde für die Anzeige.** Nicht nötig — Variante B ist bereits freigegeben
  (`docs/artifacts/fix-10-preis-einheit/entwurf.html`) und ihr Aussehen in `ItemRow` bereits
  umgesetzt; diese Spec macht den Code nur erreichbar bzw. ergänzt den fehlenden AC-15-Fallback.

## Risiken

- **Umfang über der LoC-Grenze.** Produktivcode 3 Dateien/~74 LoC liegt sicher innerhalb der
  Hausgrenze; mit Testcode zusammengezählt (Issue #36 zählt ihn als Produktivcode) ~276 LoC, über
  der 250er-Schwelle. **Gegenmaßnahme:** nach den drei Produktdateien (Kernfunktion + Anbindung +
  Anzeige) einen grünen Zwischenstand sichern, bevor die beiden Testdateien wachsen — dasselbe
  Muster wie bei #10; das Gate wird während der Umsetzung anschlagen, das ist eingeplant.
- **UI-Tests hängen an Anzeigetexten** (#18/#20). „ca. 400 g" und „1,25 €/100 g" sind neue,
  geprüfte Texte; Copy-Änderungen daran brechen künftig diese Tests.
- **Testrunner-Hänger** (#63) — bekanntes Xcode-26-Umgebungsproblem, betraf 3 von 4 Anläufen bei
  #10 laut dortigem Changelog. Kein Code-Fehler, Wiederholung einplanen, kein automatisiertes
  endloses Retry.
- **Schnell-Eingabe und Siri bleiben ohne Vorbelegung** (siehe Out of scope/Known Limitations) —
  kein neues Risiko, unverändert aus #10 übernommene Einschränkung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — im Projekt existiert kein formales ADR-Verzeichnis (`docs/adr/` fehlt),
  wie bereits in der #10-Spec begründet.
- **Rationale:** Die Entscheidung, die Stufenlogik als eigene, reine `static func` auf
  `AssignmentService` zu bauen statt als private Methode einer SwiftUI-View, folgt demselben
  Muster wie `EditableReceiptLine.learningQuantity`/`learningUnit` (#10): eine reine Funktion über
  Werten ist ohne SwiftUI-Umgebung automatisiert nachweisbar, eine View-private Methode wäre es
  nicht. Die Wiederverwendung von `namesRepresentSameItem`/`normalizedStoreKey` statt neuer
  Ad-hoc-Vergleiche und die Ersetzung von `.onChange` durch berechnete Bindings sind beides
  gezielte Bugvermeidungen (Substring-Fehltreffer bzw. sofortiges Selbst-Zurücksetzen), keine
  Architektur-Entscheidungen im Sinne eines eigenen ADR-Dokuments — für ein Feature dieses Umfangs
  wäre ein solches Dokument unverhältnismäßig.

## Expected Behavior

- Tippt der Nutzer einen Artikelnamen ohne Menge, versucht die App zuerst, aus dem letzten Kauf
  desselben Artikels **in diesem Laden** eine Menge zu belegen. Findet sich keiner, versucht sie es
  über eine im Namen erkennbare Füllmenge („… 500G"). Findet sich auch das nicht, bleibt die Menge
  leer.
- Eine so vorbelegte Menge ist in der Liste sichtbar als Annahme markiert („ca. 400 g", getönt) —
  nie wie eine selbst eingetippte Menge.
- Korrigiert der Nutzer eine solche Menge — sei es noch beim Anlegen oder später über „Bearbeiten"
  — gilt sie ab sofort als seine eigene; die Markierung verschwindet.
- Ohne jede Evidenz und mit einer gelernten Gramm-Rate zeigt die Liste statt eines erfundenen
  Gesamtpreises nur die Rate selbst („1,25 €/100 g").

## Known Limitations

- **Schnell-Eingabe (`HomeView`) und `AddItemIntent` (Siri) bekommen die Stufenlogik nicht.** Sie
  rufen `suggestQuantity` nicht auf; ein Artikel, der über diese Pfade angelegt wird, hat weiterhin
  `quantitySource == "user"` und `quantityAmount == 1`. Siri hat keinen Bildschirm, auf dem eine
  Annahme sichtbar und korrigierbar wäre — die aus #10 bestehende Entscheidungstabelle schützt
  diese Pfade trotzdem davor, eine unpassende gelernte Rate als falschen Gesamtpreis anzuzeigen.
  **Bei der Freigabe von #57 (2026-09-30) hat der PO verlangt, dass dies nicht dauerhaft offen
  bleibt: als eigenes Ticket angelegt, Issue #76** („Schnell-Eingabe und Siri: Mengen-Vorbelegung
  nachziehen") — dort wird auch geklärt, ob die Begründung „kein Bildschirm" nur für Siri gilt oder
  ob die Schnell-Eingabe (die einen Bildschirm hat) die Stufenlogik nachträglich bekommen kann.
- **Die Kaufhistorie-Stufe wirkt nur innerhalb desselben Ladens.** Ein Nutzer, der denselben
  Artikel bisher nur in einem anderen Laden gekauft hat, bekommt beim erstmaligen Anlegen in einem
  neuen Laden keine Mengen-Vorbelegung aus dieser Historie — bewusst, PO-Entscheidung 2 verlangt
  „in diesem Laden".
- **Gramm und Milliliter bleiben in der gelernten Rate ununterscheidbar** (Issue #15, unverändert
  aus #10 übernommen) — betrifft auch die AC-15-Ratenanzeige, die beide unter „g" zusammenfasst.
- **`Color.amber` unterschreitet im Hellmodus die WCAG-AA-Schwelle für Fließtext** (3,52 : 1 statt
  4,5 : 1, siehe Implementation Details 4). Kein neues Problem — die Farbe ist app-weit etabliert
  und wird durch #57 nur an einer weiteren Stelle sichtbar. Da die Mengen-Vorbelegung im
  alltäglichen (hellen) Modus dieselbe Lesbarkeit haben soll wie im Dunkelmodus, ist das kein
  vernachlässigbarer Rand-Fall — deshalb als eigenes Ticket **Issue #75** angelegt, statt hier nur
  vermerkt und liegen gelassen. Außerhalb des Scopes dieses Tickets, da eine Korrektur die
  Design-Token app-weit anfassen und eine eigene Entwurfsvorschau brauchen würde.
- **Ein Kauf ohne real belegte Menge (`quantityAmount == 1`, `unit == ""`) ist von einem
  absichtlich mit „1 Stück" angelegten Artikel nicht unterscheidbar** (siehe Implementation
  Details 1c) — Stufe „history" kann daher für Alltagsartikel ohne Gewichtsangabe ein „ca. 1" ohne
  Einheit vorschlagen. Kein Fehlpreis-Risiko, nur eine kosmetische Unschärfe; Reparatur am
  Datenmodell selbst gehört zu Issue #54.

## Changelog

- 2026-09-30: Initial spec created
- 2026-09-30: Drei technische Lücken aus der PO-Freigabe-Rückfrage geschlossen, nach Recherche
  (WCAG 2.1) und Code-Analyse (`ShoppingItem.markCompleted`), Tech-Lead-Entscheidung ohne PO-Rückfrage:
  (1) Einzelstück-Historie-Fall als dritte technische Detailentscheidung (1c) dokumentiert —
  bewusst keine Modelländerung, da bestehendes, nicht neues Verhalten, Verweis auf #54.
  (2) AC-18 von „ausreichender Kontrast" auf einen harten WCAG-2.1-AA-Schwellwert (4,5 : 1)
  umgestellt, nachgerechnet (6,64 : 1 im Dunkelmodus, erfüllt), Nachweis auf einen deterministischen
  Unit-Test statt UI-Test umgestellt (Kontrast ist nicht per XCUITest messbar). Hellmodus-Befund
  (3,52 : 1, unter der Schwelle) als bestehende, app-weite Einschränkung unter Known Limitations
  vermerkt, nicht Teil des Scopes. (3) Test Plan und Scope-Tabelle entsprechend angepasst (3 statt
  4 UI-Tests, 8 statt 7 Unit-Tests).
- 2026-09-30: **Zweiter PO-Briefer-Durchlauf, drei weitere Korrekturen.** (1) Hellmodus-Kontrast-
  Befund als eigenes GitHub-Issue **#75** angelegt (statt nur in Known Limitations vermerkt), damit
  er nicht als erledigt missverstanden wird. (2) Strukturfehler in AC-11–13 behoben: Die erste
  Fassung hatte die vier Original-Stufen aus dem Issue falsch auf drei ACs verteilt (AC-12 trug
  fälschlich Historie-Detailinhalt statt der Package-Stufe, AC-13 verlor dadurch den
  Nutzereingabe-Bypass komplett). AC-11 = History (inkl. „letzter Kauf"/Namensvergleich), AC-12 =
  Package (Skyr/Cola-Beispiele aus dem Issue), AC-13 = None + Bypass — jetzt deckungsgleich mit der
  Nummerierung aus #10/Issue #57. (3) Neuer UI-Test `testUserTypedQuantityIsNeverMarkedAsAssumption`
  für den bislang ungetesteten AC-13-Bypass-Teil ergänzt (4 statt 3 UI-Tests). LoC-Schätzung
  entsprechend auf ~276 LoC korrigiert (über der 250er-Schwelle, Gegenmaßnahme unverändert aus #10
  übernommen).
- 2026-09-30: **Dritter PO-Briefer-Durchlauf, ein Fund.** Die vorherige LoC-Korrektur (~276) war nur
  punktuell in „Scope" und Changelog eingetragen, nicht im Abschnitt „Risiken" — der nannte noch
  die alte Zahl (~264). Beide Stellen per Suche gegengeprüft und vereinheitlicht (dasselbe Muster
  wie in einer früheren Spec-Korrektur: punktuell statt über alle Fundstellen).
- 2026-09-30: **PO-Freigabe erteilt** (vierter Briefing-Durchlauf ohne neue Funde). Der PO hat bei
  der Freigabe verlangt, dass die Known Limitation „Schnell-Eingabe/Siri" nicht dauerhaft offen
  bleibt — als eigenes Ticket angelegt, **Issue #76**, in Known Limitations referenziert. Ändert
  nichts an Scope, ACs oder Test Plan dieser Spec, daher kein erneuter Validierungs-/Briefing-Lauf.
