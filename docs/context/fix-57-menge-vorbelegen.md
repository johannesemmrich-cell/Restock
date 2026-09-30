# Context: fix-57-menge-vorbelegen (Issue #57)

## Request Summary

Trägt der Nutzer einen Artikel ohne Menge ein, soll die App eine Menge vorschlagen — aus dem
letzten Kauf desselben Artikels in diesem Laden, sonst aus der Packungsgröße im getippten Namen —
und sie in der Liste sichtbar als Annahme kennzeichnen („ca. 400 g", getönt), nie wie eine selbst
eingetippte Menge. Ohne Menge und ohne jede Evidenz zeigt die Liste statt eines Gesamtpreises die
Rate („1,25 €/100 g"). Zweiter, aus #10 abgespaltener Teil derselben Spezifikation
(PO-Entscheidung 2026-09-26).

## Related Specs — bereits vorhanden, nicht neu zu schreiben

`docs/specs/models/learned-price-unit-and-quantity-source.md` (Issue #10, Status: approved,
`workflow: fix-10-preis-einheit`) enthält bereits:

- Die vollständige technische Lösung für #57 unter „Implementation Details" Abschnitt 6–8
  (`suggestQuantity`, `packageSizeFromName`, `ItemRow`-Anzeige, `EditItemView`-Rücksetzung)
- Die Acceptance Criteria **AC-11 bis AC-16 und AC-18** — mit derselben Nummerierung, absichtlich
  in #10 freigehalten
- Den bereits freigegebenen Entwurf (`docs/artifacts/fix-10-preis-einheit/entwurf.html`,
  https://claude.ai/artifact/AwBQGPWJAdch2aNkPMonUL) mit PO-Entscheidung **Variante B** — **keine
  neue Entwurfsrunde nötig**, das ist im Changelog der Spec ausdrücklich vermerkt
- Alternativen A und C, vom PO bereits verworfen (siehe „Alternativen (verworfen)")

`/30-write-spec` für #57 überführt diese Abschnitte in eine eigene Spec-Datei (eigene
`entity_id`, eigener `workflow`), **nicht** neu entwerfen.

## Bereits im Code vorhanden (aus #10, geprüft 2026-09-30)

| Was | Datei | Status |
|---|---|---|
| `quantitySource: String = "user"` am `ShoppingItem` + Konstruktor-Parameter | `Models/ShoppingItem.swift:58-62,106,114` | ✅ vorhanden |
| `estimatedLineTotal` liefert `nil` bei `quantitySource == "none"` | `Models/ShoppingItem.swift:261-263` | ✅ vorhanden |
| `learnedRateUsage` behandelt `quantitySource == "none"` als `.rateOnly` | `Models/ShoppingItem.swift:224-231` | ✅ vorhanden |
| Mengenzeile: `"ca. "`-Präfix + `Color.amber` bei `history`/`package`, keine Anzeige bei `none` (AC-14) | `Views/Components/ItemRow.swift:90-94` | ✅ vorhanden, aber **unerreichbar** — nichts setzt `quantitySource` auf etwas anderes als `"user"` |
| `quantitySource = "user"` beim manuellen Korrigieren (AC-16) | `Views/Store/EditItemView.swift:342-343` | ✅ vorhanden |
| `packageSizeFromName(_:) -> (amount: Double, unit: String)?` | `Services/ReceiptParserService.swift:924-...` | ✅ vorhanden (aus #10, für Stufe 3 gebaut) |

**Wichtig:** Der vorhandene Code ist laut #10-Spec compiliert und bricht keinen Bestandstest,
sein Verhalten ist aber **nicht nachgewiesen** — die Tests dafür wurden mit nach #57 gezogen.

## Noch zu bauen

| Was | Datei | AC |
|---|---|---|
| `AssignmentService.suggestQuantity(itemName:storeName:purchaseRecords:) -> (quantity: String, unit: String, source: String)` — vier Stufen als reine, testbare Funktion | `Services/AssignmentService.swift` (neu) | AC-11–13 |
| Preiszelle: bei `estimatedLineTotal == nil`, `quantitySource == "none"`, `unit == "g"` Rate `estimatedPrice × 100` mit `/100 g` statt gar nichts | `Views/Components/ItemRow.swift:146-150` | AC-15 |
| `addItem()` reicht `quantitySource` an den `ShoppingItem`-Konstruktor durch | `Views/Store/AddItemView.swift:200-219` | Voraussetzung für alle |
| Neue Testdatei mit sieben Tests zu den vier Stufen | `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` (neu, + 4 pbxproj-Einträge) | AC-11–13 |
| Vier UI-Tests (Annahme-Kennzeichnung, Dunkelmodus-Lesbarkeit, Korrektur setzt zurück, Rate statt Gesamtpreis) | `RestockUITests/ReceiptReviewUITests.swift` oder eigene Klasse | AC-14, AC-15, AC-16, AC-18 |

## Ist-Zustand von `AddItemView.applySuggestedQuantity` — abweichend von der Spec-Beschreibung

Geprüft am aktuellen Code (`Views/Store/AddItemView.swift:182-198`), **nicht** wie die #10-Spec es
beschreibt:

- Filtert `allRecords` **nur nach Name**, laden-übergreifend — **kein** `storeName`-Filter. Die
  Spec nahm an, das sei „zu 90 % fertig"; tatsächlich fehlt der Laden-Filter komplett.
- Bildet den **Durchschnitt der letzten 5 Käufe**, nicht „den letzten Kauf" (PO-Entscheidung 2
  spricht explizit von „letzte gekaufte Menge", Singular).
- Setzt **kein** `quantitySource` — die Variable existiert im View noch gar nicht.
- Ruft **nicht** `packageSizeFromName` auf (Stufe 3 fehlt vollständig).
- Läuft für **jeden** Store-Zweig (`presetStore`-Fall und Auto-Zuweisungs-Fall) — beide Aufrufer
  bleiben erhalten, nur der Funktionskörper wandert in `AssignmentService.suggestQuantity` um.

Diese bestehende Logik wird durch den Aufruf von `suggestQuantity` **ersetzt**, nicht ergänzt —
sonst gibt es zwei konkurrierende Mengen-Vorschläge.

## Existing Patterns

- **Reine Funktion statt View-Logik, damit sie ohne SwiftUI-Umgebung testbar ist** — dasselbe
  Muster wie `EditableReceiptLine.learningQuantity`/`learningUnit` (#10) und wie in #59 für
  `ReceiptScannerView.save()` empfohlen (dort noch offen, hier bereits PO-Entscheidung).
- **Additive Felder mit Standardwert** — `quantitySource` existiert schon nach diesem Muster
  (`learnedPriceDates`, `learnedPriceUnits`).
- **Lieber kein Preis als ein falscher** — Stufe 4 (`"none"`) liefert bewusst keinen
  Gesamtpreis, nur die Rate.
- **Regeln vor Modell** — alle vier Stufen sind deterministisch (Historie, RegEx auf dem Namen),
  kein Sprachmodell.

## Dependencies

**Upstream:**
- `PurchaseRecord.storeName` / `.quantityAmount` / `.unit` (`Models/PurchaseRecord.swift`) —
  Evidenzquelle Stufe 2
- `ReceiptParserService.packageSizeFromName` — Evidenzquelle Stufe 3, bereits vorhanden
- `Color.amber` (`DesignSystem.swift`) — Tönung, bereits verdrahtet in `ItemRow`

**Downstream:**
- `ItemRow` (Listenanzeige) — AC-14 wartet auf `suggestQuantity`, AC-15 noch zu bauen
- `EditItemView` — AC-16 bereits verdrahtet
- Kein bekannter weiterer Abhängiger; #15 (Preisvergleich) und #11 (Altdaten-Reparatur) bauen
  fachlich auf #10, nicht direkt auf #57.

## Risks & Considerations

- **Umfang.** 3 Produktdateien (`AssignmentService.swift` neu, `AddItemView.swift`,
  `ItemRow.swift`) + 2 Testdateien (1 neu, 1 erweitert) + 4 pbxproj-Einträge. Innerhalb der
  4–5-Datei-Grenze, sofern Testcode nicht mitgezählt wird — **Issue #36** zählt Testcode aber als
  Produktivcode; grünen Zwischenstand nach der Kernfunktion sichern, bevor die Tests wachsen.
- **Abweichung von der #10-Spec-Beschreibung** (siehe oben) muss in `/20-analyse` bewusst
  aufgelöst werden — die dortige Beschreibung „zu 90 % fertig" ist zu optimistisch.
- **UI-Tests hängen an Anzeigetexten** (#18/#20). „ca. 400 g" und „1,25 €/100 g" sind neue,
  geprüfte Texte.
- **Testrunner-Hänger** (#63) — bekanntes Xcode-26-Umgebungsproblem, betraf 3 von 4 Anläufen bei
  #10. Kein Code-Fehler, Wiederholung einplanen.
- **Keine neue Entwurfsrunde nötig** — Variante B ist bereits freigegeben und ihr Aussehen bereits
  im Code (`ItemRow`) umgesetzt.

## Existing Specs

- `docs/specs/models/learned-price-unit-and-quantity-source.md` — Issue #10, approved,
  enthält die technische Grundlage 1:1 für #57 (siehe oben)
- `docs/context/fix-10-preis-einheit.md` — Kontext + Analyse von #10, Entwurfs-Herleitung

## Analysis

### Type

Feature (Erweiterung von Add-Item-Flow und Listenanzeige um eine begründete, korrigierbare
Mengen-Vorbelegung; kein gemeldeter Fehlerfall).

### Verifikation gegen den aktuellen Code (2026-09-30, ohne Codeänderung)

Alle Aussagen aus Phase 1 stichprobenartig gegen den aktuellen Stand geprüft — keine Abweichung
gefunden:

- `AddItemView.applySuggestedQuantity` (Zeile 182-198): bestätigt namensbasiert
  laden-übergreifend (kein `storeName`-Filter), Durchschnitt der letzten 5 Käufe, kein
  `quantitySource`, kein `packageSizeFromName`-Aufruf, läuft für beide Aufrufer (`presetStore`-Fall
  Zeile 170-172 und Auto-Zuweisungs-Fall Zeile 174-179).
- `ItemRow.swift` Zeile 90-95: AC-14-Code (Präfix „ca. ", `Color.amber`) vorhanden. Zeile 146-150:
  AC-15-Fallback fehlt vollständig — bei `estimatedLineTotal == nil` erscheint keine Preiszelle.
- `ShoppingItem.swift` Zeile 62/106/114: `quantitySource`-Feld und Konstruktor-Parameter
  vorhanden und verdrahtet.
- `AssignmentService+Category.swift:9`: `AssignmentService` ist ein `struct`, über zwei Dateien
  erweitert — `suggestQuantity` gehört als neue `static func` in `AssignmentService.swift`.
- `ReceiptParserService.swift:924`: `packageSizeFromName(_:) -> (amount: Double, unit: String)?`
  vorhanden, ungenutzt.
- `PurchaseRecord.swift:11-14`: `storeName`, `date`, `quantityAmount`, `unit` vorhanden — Stufe-2-
  Evidenz ist ohne weitere Modelländerung abrufbar.
- `QuantityStepperField.swift:9-10`: nimmt `@Binding var quantity: String` / `@Binding var unit:
  String` entgegen — beliebig durch eine berechnete Binding ersetzbar, ohne die Komponente selbst
  anzufassen.

### Zwei technische Lücken, die die #10-Spec (Abschnitt 6-8) nicht schließt

Die freigegebene #10-Spec beschreibt `suggestQuantity` und die Anbindung nur auf Höhe der vier
Stufen und der Anzeige. Zwei für #57 nötige Detailentscheidungen fehlen dort und werden hier
getroffen, mit jeweils einer geprüften Alternative:

**1. Namensvergleich in Stufe 2 (Kaufhistorie).** Das heutige, zu ersetzende
`applySuggestedQuantity` vergleicht Namen ad-hoc über `contains()` in beide Richtungen (Zeile 188).
`AssignmentService.swift` selbst enthält bereits `namesRepresentSameItem(_:_:)` (Zeile 56-59) —
wortbasiert, diakritik-gefaltet, Qualifizierer-bereinigt, extra dafür gebaut, dass z. B. „Eierlikör"
nicht als „Eier" zählt (Kommentar Zeile 53-55). Der ad-hoc-Vergleich in `applySuggestedQuantity`
hat genau diese Schwäche nicht behoben.

- **Empfehlung:** `suggestQuantity`s Stufe 2 nutzt `namesRepresentSameItem` (+ `normalizedStoreKey`
  für den Laden-Filter) statt einer neuen Ad-hoc-Regel — dieselbe Funktion, die `assign()` im selben
  Typ bereits verwendet, kein neuer Code, eine einzige Quelle der Wahrheit für „gleicher Artikel".
- **Alternative (verworfen):** Den bestehenden `contains()`-Vergleich unverändert mitnehmen. Kleinster
  Diff, aber reproduziert im selben Zug die Fehlerklasse, gegen die `namesRepresentSameItem` im
  selben Ticket-Bereich bereits gebaut wurde — ohne Not, da die Funktion `internal` und im selben
  Typ bereits sichtbar ist.

**2. Rücksetzen von `quantitySource`, wenn der Nutzer die vorbelegte Menge in `AddItemView` noch vor
dem Speichern ändert.** Abschnitt 6 der #10-Spec sagt nur, `addItem()` reiche `quantitySource`
durch — nichts dazu, was passiert, wenn `quantity`/`unit` nach einer Vorbelegung manuell verändert
werden. `EditItemView` hat für den Nachträglich-Fall bereits ein Vorbild (Zeile 342-343:
`quantitySource = "user"` direkt nach dem Schreiben), aber `AddItemView` bislang keine
Entsprechung — ohne sie würde eine selbst eingetippte Menge fälschlich als „ca."-Annahme markiert.

- **Empfehlung:** Die beiden Bindings, die an `QuantityStepperField(quantity:unit:)` und das
  `unit`-Textfeld übergeben werden, durch je eine berechnete `Binding(get:set:)` ersetzen, die bei
  jedem Schreiben zusätzlich `quantitySource = "user"` setzt. `applySuggestedQuantity` selbst
  schreibt weiterhin direkt auf die `@State`-Variablen und bleibt davon unberührt.
- **Alternative (verworfen):** `.onChange(of: quantity)` / `.onChange(of: unit)` am Formular.
  Verworfen, weil `applySuggestedQuantity` selbst `quantity`/`unit` beschreibt — ein `onChange`
  würde die eigene Vorbelegung im selben Update-Zyklus sofort wieder auf `"user"` zurücksetzen und
  das Feature dadurch wirkungslos machen.

### Technischer Ansatz (Empfehlung, eine Linie)

Umsetzen wie in der #10-Spec, Abschnitte 6-8, freigegeben — ergänzt um die zwei Detailentscheidungen
oben. `applySuggestedQuantity` wird vollständig ersetzt (nicht ergänzt) durch einen Aufruf von
`AssignmentService.suggestQuantity`, dessen Ergebnis in `quantity`, `unit`,
`@State quantitySource` geschrieben wird; `addItem()` reicht `quantitySource` an den
`ShoppingItem`-Konstruktor durch. `ItemRow`s Preiszelle bekommt den AC-15-Fallback (Rate ×100 bei
`unit == "g"` und `quantitySource == "none"`).

### Scope Assessment

| Datei | Change | ~LoC |
|---|---|---|
| `SmartCart/Services/AssignmentService.swift` | MODIFY — `suggestQuantity` neu | +45 |
| `SmartCart/Views/Store/AddItemView.swift` | MODIFY — Ersetzen + 2 Bindings + `quantitySource`-State | +20/-17 |
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY — AC-15-Fallback | +9 |
| `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` | CREATE — 7 Tests (AC-11–13) + 4 pbxproj-Einträge | +110 |
| `RestockUITests/ReceiptReviewUITests.swift` oder neue Klasse | MODIFY/CREATE — 4 UI-Tests (AC-14–16, AC-18) | +80 |

Produktivcode: 3 Dateien, ~74 LoC (innerhalb 4-5-Dateien-/±250-LoC-Grenze). Mit Testcode
zusammengezählt (Issue #36 zählt ihn als Produktivcode) ~264 LoC — an der Grenze. **Gegenmaßnahme
wie bei #10:** nach den drei Produktdateien (Kernfunktion + Anbindung + Anzeige) einen grünen
Zwischenstand sichern, bevor die beiden Testdateien wachsen.

**Risk Level:** Niedrig-Mittel. Rein additiv (kein Schema-Bruch, kein Migrationscode), Entwurf
bereits freigegeben (Variante B), Verhalten isoliert auf Anlegen-Flow + Listenanzeige. Bekannte,
nicht-blockierende Restrisiken: UI-Tests hängen an Anzeigetexten (#18/#20), Testrunner-Hänger als
Umgebungsproblem, nicht Code-Fehler (#63).

### Dependencies und Reihenfolge

1. `AssignmentService.suggestQuantity` (reine Funktion, unabhängig testbar) — zuerst, da alles
   andere davon abhängt.
2. `AddItemView`-Anbindung (Ersetzen von `applySuggestedQuantity`, Bindings, `quantitySource`-State).
3. `ItemRow`-AC-15-Fallback — unabhängig von 1./2., kann parallel oder danach.
4. Tests — Unit zu 1., UI-Durchstich zu 2.+3. gemeinsam (AC-14/15/16/18 sind erst im Zusammenspiel
   sichtbar).

Keine Abhängigkeit zu #15 oder #11 (schätzfrei nachgelagert, siehe Kontext).

### Offene Fragen

Keine PO-Entscheidung nötig — beide oben getroffenen Detailentscheidungen sind rein technisch
(Wiederverwendung bestehender, bereits getesteter Funktionen bzw. Bug-Vermeidung durch Binding statt
onChange) und ändern weder sichtbares Verhalten noch die freigegebene Variante B.
