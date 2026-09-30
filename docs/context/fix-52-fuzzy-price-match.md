# Context: fix-52-fuzzy-price-match

## Request Summary
Ein per Bon gelernter Preis wird beim späteren manuellen Anlegen desselben Artikels nicht
gefunden, wenn der Bon-Name durch einen OCR- oder Tippfehler minimal vom später eingegebenen
Namen abweicht (Beispiel: "saitan" gelernt, "seitan" eingegeben trifft nicht). Ursache: der
Preisabgleich in `ShoppingItem.init` prüft nur, ob einer der beiden Namen den anderen als
Teilstring enthält — keine Fehlertoleranz.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Models/ShoppingItem.swift:120-152` | Der eigentliche Abgleich. `matchingKeys` filtert `store.learnedPrices.keys` per `key.contains(itemLower) \|\| itemLower.contains(key)` — reine Teilstring-Prüfung, kein Fehlertoleranz-Mechanismus. Tie-Breaking bei mehreren Treffern über `learnedPriceDates`, dann alphabetisch (Kommentar dokumentiert einen früheren Bug dazu, 19.08.2026). |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:576, 692` | `save()` lernt für jede eingeschlossene, bepreiste Zeile unter `line.name.lowercased()` (Zeile 692), unabhängig davon, ob der Name vom User bestätigt oder nur der rohe OCR-Text war. |
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | Bietet Namensoptionen zur Auswahl an, fällt aber ohne besseren Kandidaten auf `.currentName(name: line.name)` zurück (roher OCR-Text). |
| `SmartCart/Services/ReceiptAliasService.swift` | Bestehender, verwandter aber anderer Mechanismus: lernt Bon-Kürzel → Artikelname, aber nur bei **exaktem** normalisiertem Treffer (`aliases[normalize(receiptText)]`), keine Fehlertoleranz. Wird beim Scan (Stufe 1 der Namensauflösung) angewendet, nicht beim späteren manuellen Anlegen. |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift:163` | Weitere Schreibstelle für `learnedPrices[key]` — direkte manuelle Preiseingabe, Key ist der exakt eingegebene Artikelname. |
| `SmartCart/Services/SyncCoordinator.swift:241` | Schreibstelle beim Sync geteilter Preise — überträgt vorhandene Keys unverändert, keine eigene Matching-Logik. |
| `SmartCart/Models/Store.swift` | Hält `learnedPrices: [String: Double]`, `learnedPriceDates`, `learnedPriceUnits` — alle drei Dictionaries sind über denselben String-Key verknüpft. |

## Existing Patterns

- **Kein bestehender Fehlertoleranz-Mechanismus im Repo.** Weder Levenshtein-Distanz noch eine
  andere Fuzzy-Matching-Implementierung existiert (`grep` nach `evenshtein`, `editDistance`,
  `fuzzy` findet nichts außer den Kommentaren, die das Teilstring-Matching selbst als "fuzzy"
  bezeichnen).
- **Normalisierung vor String-Vergleich** ist etabliertes Muster: `ReceiptAliasService.normalize`
  senkt auf lowercase, ersetzt Satzzeichen durch Leerzeichen, trimmt. Eine neue Toleranzstufe
  würde sinnvollerweise auf einem ähnlich normalisierten String arbeiten.
- **Mindestlänge als Schutz vor Fehltreffern** ist ebenfalls etabliert: sowohl der bestehende
  Teilstring-Vergleich (`key.count >= 3 && itemLower.count >= 3`) als auch
  `ReceiptAliasService.learn` (`key.count >= 3`) verlangen mindestens 3 Zeichen, bevor überhaupt
  verglichen wird.
- **Determinismus ist Prinzip, kein Zufall:** CLAUDE.md (Nutzer-Regeln) verlangt explizit, alles
  Regelbasierte auch regelbasiert zu lösen statt mit einem Sprachmodell — Alternative (a) aus dem
  Issue (Levenshtein-Schwelle) folgt diesem Prinzip, ein Modell wäre hier ohnehin unpassend.

## Dependencies

- **Upstream:** `ShoppingItem.init` liest `store.learnedPrices`, `store.learnedPriceDates`,
  `store.learnedPriceUnits` — reine Dictionary-Lookups, keine weiteren Services beteiligt.
- **Downstream:** Das Ergebnis (`learnedPrice`, weiter unten in der Funktion) fließt in
  `estimatedPrice` / `estimatedLineTotal` des `ShoppingItem` ein und wird in der UI als
  Preis-Vorschlag angezeigt (`AssignmentService.category` als Fallback bei fehlendem Preis-Match,
  siehe Issue-Text). Keine weiteren Consumer der Matching-Logik selbst.

## Existing Specs

- `docs/specs/models/learned-price-unit-and-quantity-source.md` — beschreibt, wie Preis, Einheit
  und Quelle unter demselben Key geführt werden (relevant, falls der Fix den Key-Vergleich
  ändert: alle drei Dictionaries müssen konsistent bleiben).
- `docs/specs/models/price-estimator-stages.md`, `price-estimator-category-fallback.md` — der
  generische Preisschätzer, der greift, wenn kein gelernter Preis matcht. Nicht direkt betroffen,
  aber der Fallback-Pfad, den ein besseres Matching seltener auslösen sollte.
- `docs/specs/views/receipt-review-card.md`, `receipt-review-card-nachtrag-1b.md` — falls
  Alternative (b) (Namensbestätigung erzwingen) gewählt wird, ist das die Spec des betroffenen
  Screens.
- `docs/specs/services/receipt-parser-quantity-confirmation.md` — verwandtes Bestätigungs-Muster
  im selben Dialog, als Vorbild falls (b) umgesetzt wird.

## Risks & Considerations

- **Fehltreffer durch zu großzügige Toleranz:** Eine Edit-Distanz-Schwelle von 1–2 Zeichen kann
  bei kurzen, unterschiedlichen Wörtern falsch zuschlagen (Beispiele aus der eigenen Analyse:
  "Milch" ↔ "Mehl", "Reis" ↔ "Eis" — je nach genauer Distanzberechnung ggf. nicht alle davon
  tatsächlich unter der Schwelle, muss bei der Wahl der Schwelle konkret geprüft werden).
- **Interaktion mit dem bestehenden Tie-Breaking:** Kommt eine dritte Vergleichsart (Fehlertoleranz)
  zum bestehenden Teilstring-Vergleich hinzu, muss die Reihenfolge/Priorität zwischen exaktem
  Teilstring-Treffer und Fuzzy-Treffer klar sein — sonst könnte ein fuzzy-naher, aber falscher
  Key einen echten Teilstring-Treffer verdrängen.
- **Zwei mögliche Lösungsrichtungen mit unterschiedlichem Scope:** (a) nur den Abgleich in
  `ShoppingItem.init` erweitern (kleiner, lokaler Fix) vs. (b) den Bon-Import so ändern, dass nie
  mehr unter unbestätigtem OCR-Text gelernt wird (größerer Eingriff in `ReceiptReviewCard`/
  `ReceiptScannerView`, ändert den Dialog-Fluss sichtbar). Das Issue selbst nennt (c) Kombination
  und (d) Nichtstun als weitere Optionen — keine ist vorentschieden.
- **Kein Nachweis, wie oft dieser Fall in der Praxis auftritt** — Henning berichtet einen
  einzelnen beobachteten Fall (25.09.2026). Aufwand/Nutzen-Abwägung bleibt Teil der Analyse.

## Analysis

### Type
Bug

### Korrektur zu „Existing Patterns" oben
Die Aussage „kein bestehender Fehlertoleranz-Mechanismus im Repo" aus `/10-context` ist
**falsch** — Grep nach den Wörtern „evenshtein/editDistance/fuzzy" hat den tatsächlich
existierenden Mechanismus verfehlt, weil er anders benannt ist:
`ReceiptParserService.lcsSimilarity` (Dice-Koeffizient über der längsten gemeinsamen
Teilsequenz, `ReceiptParserService.swift:1110`) samt zweier bereits kalibrierter Schwellwerte
(`completedItemAutoApplyThreshold = 0.6`, `completedItemSuggestionFloor = 0.45`). Wird
produktiv genutzt in `ReceiptScannerView.swift:677`, `ReceiptResolutionService.swift:109,136`
und `AssignmentService.swift:370` — für Bon-Kürzel-Auflösung gegen bereits abgehakte Artikel
bzw. Store-Namen. `Store.swift:179-182` ruft bereits `AssignmentService` aus einem Model auf —
ein Model, das eine Service-Funktion nutzt, ist also etabliertes Muster, keine neue
Schichtenverletzung.

**Warum dieser bestehende Mechanismus hier trotzdem NICHT wiederverwendet werden sollte:**
Geprüft mit dem echten Algorithmus (`lcsSimilarity`) gegen den gemeldeten Fall und die im
Kontext bereits genannten Kollisions-Risiken:

| Paar | Score | Über Auto-Schwelle (0,6)? |
|------|-------|------|
| saitan / seitan (gemeldeter Fall) | 0,833 | ja |
| reis / eis | 0,857 | **ja — Fehltreffer** |
| milch / mehl | 0,444 | nein |
| bananen / mandeln | 0,571 | nein |

„Reis" und „Eis" sind unterschiedliche Artikel, würden mit dem bestehenden Schwellwert aber
als Treffer durchgehen — ein stiller Falsch-Match des Preises, nicht nur ein falscher
Namensvorschlag wie beim bestehenden Einsatzzweck. Grund: `lcsSimilarity` ist für einen
**engeren** Kontext kalibriert (Kandidaten sind bereits bekannte, abgehakte Artikel dieser
Einkaufsrunde bzw. die überschaubare Store-Liste). `store.learnedPrices` ist dagegen ein
offenes, über Monate gewachsenes Dictionary beliebiger Produktnamen — der Kollisionsraum ist
strukturell größer, und ein still falsch angewandter *Preis* wiegt schwerer als ein falscher
*Namensvorschlag* (der im Review antippbar bleibt).

### Technischer Ansatz (Empfehlung)
Eigene, bewusst konservative Prüfung in `ShoppingItem.init` ergänzen — nicht `lcsSimilarity`
wiederverwenden, sondern Alternative (a) aus dem Issue (Levenshtein-Schwelle), aber gezielt so
kalibriert, dass die oben gefundenen Kollisionsfälle ausgeschlossen bleiben:

- Klassische Levenshtein-Distanz (neue, kleine Hilfsfunktion, kein Fremdcode nötig).
- Nur als **Fallback**, wenn die bestehende Teilstring-Prüfung keinen Treffer liefert (bestehendes
  Verhalten bleibt für alle heute funktionierenden Fälle unverändert).
- Zwei Bedingungen zugleich: Distanz ≤ 1 **und** kürzerer der beiden Namen ≥ 5-6 Zeichen (exakter
  Wert Teil der Spec). Beleg, dass diese Kombination die bekannten Risiken trennt:

  | Paar | Levenshtein | kürzerer Name | Ergebnis |
  |------|-------------|----------------|----------|
  | saitan / seitan | 1 | 6 | **trifft** (gewünscht) |
  | reis / eis | 1 | 3 | verworfen (Längen-Gate) |
  | milch / mehl | 4 | 4 | verworfen (Distanz) |
  | bananen / mandeln | 4 | 7 | verworfen (Distanz) |
  | apfel / apfelsaft | 4 | 5 | verworfen (Distanz) |

- Tie-Breaking bei mehreren fuzzy-passenden Keys: dieselbe bestehende Logik (Datum, dann Key
  alphabetisch) wiederverwenden, nur auf die per Fuzzy-Prüfung gefundene Kandidatenmenge
  angewendet.

### Alternativen (keine ist vorentschieden)
1. **Empfehlung — neue, konservative Levenshtein-Prüfung** (oben). Klein, isoliert, durch
   Nachrechnen an den bekannten Risikofällen belegt.
2. **`lcsSimilarity` wiederverwenden.** Weniger neuer Code, aber nachweislich unsicher in diesem
   Kontext (Reis/Eis-Fehltreffer oben) — verworfen, es sei denn, ein zusätzliches Längen-Gate
   würde ohnehin nötig, was den Wiederverwendungs-Vorteil wieder aufhebt.
3. **Root Cause an der Quelle (Issue-Alternative b): beim Bon-Scan nie unter unbestätigtem
   OCR-Text lernen.** Behebt das Problem dort, wo der schlechte Key entsteht, verbessert auch
   sonstige Datenqualität von `learnedPrices`. Größerer Eingriff in `ReceiptReviewCard`/
   `ReceiptScannerView` (mehr Rückfragen in einem Screen, den Henning bereits als überladen
   markiert hat, siehe `docs/context/` zu Issue #23 / Memory `bon-import-result-screen-priority`).
   Behebt außerdem nicht rückwirkend bereits falsch gelernte Keys wie „saitan". Nicht empfohlen
   für diesen Fix, aber als spätere, unabhängige Härtung denkbar.
4. **Kombination (a)+(b) / Nichtstun (c/d aus dem Issue):** Kombination wäre Scope-Ausweitung
   ohne Not: Alternative 1 allein löst den gemeldeten Fall. Nichtstun spart bei diesem kleinen
   Umfang (1 Datei, siehe unten) keinen nennenswerten Aufwand gegenüber dem Nutzen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|--------------|
| `SmartCart/Models/ShoppingItem.swift` | MODIFY | Levenshtein-Hilfsfunktion + Fallback-Zweig in der `matchingKeys`/`bestKey`-Ermittlung, aktiv nur wenn die bestehende Teilstring-Prüfung leer bleibt |
| `RestockTests/…` (neue oder erweiterte Testdatei) | CREATE/MODIFY | Unit-Tests für den neuen Fallback (TDD RED, Phase 4) — inkl. der Kollisions-Fälle aus der Tabelle oben als Negativ-Tests |

### Scope Assessment
- Files: 1 Produktivdatei + 1 Testdatei
- Estimated LoC: ca. +30/-0 Produktivcode, plus Testcode (separat, TDD-Phase)
- Risk Level: LOW — reiner Fallback-Zweig, bestehendes Verhalten bei vorhandenem
  Teilstring-Treffer unverändert; Schwellwerte gegen konkrete Kollisionsfälle vorab durchgerechnet

### Dependencies
- Upstream: `Store.learnedPrices`/`learnedPriceDates`/`learnedPriceUnits` (unverändert, siehe
  bestehende Spec `docs/specs/models/learned-price-unit-and-quantity-source.md`).
- Downstream: `estimatedPrice`/`estimatedLineTotal` in `ShoppingItem`, UI-Anzeige des
  Preis-Vorschlags — keine neuen Consumer.
- Keine Abhängigkeit zu `ReceiptParserService`/`lcsSimilarity` (bewusst nicht wiederverwendet,
  siehe oben).

### Open Questions
- [ ] Exakte Werte für Distanz-Schwelle (1 vs. 2) und Mindestlänge (5 vs. 6) — Vorschlag oben
      (Distanz ≤ 1, Mindestlänge ≥ 5) deckt alle bekannten Fälle korrekt; PO-Bestätigung für die
      Spec-Phase ausreichend, keine Grundsatzfrage.
