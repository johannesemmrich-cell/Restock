---
entity_id: receipt-text-recognizer-tiling
type: bugfix
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: fix-120-bon-lange-bilder
tags: [receipt, ocr, vision, tiling, long-image, lidl-plus, issue-120]
---

# Bon-Erkennung: sehr hohe Bilder in überlappenden Streifen erkennen (Issue #120)

## Approval

- [ ] Approved — PO (offen)

## Purpose

PO-Meldung 2026-10-07 (#120, „Kassenbon kommt nicht mit Rabatt zurecht … Scan erkennt nur drei Artikel“):
Ein digitaler Lidl-Plus-Bon als langes Bild (1206 × 9089 px, Seitenverhältnis Höhe/Breite ca. 7,5, unter fast
jedem Artikel eine blaue Zeile „Lidl Plus Rabatt −0,08“) liefert im Scan nur drei Artikel (Analyse in
`docs/context/fix-120-bon-lange-bilder.md`, Abschnitte „Reproduktion“, „Root Cause“, „Alternativen“).

**Root Cause (nachgestellt, mit dem Original-Bild und derselben Vision-Anfrage wie die App, auf dem Mac):**
Die Apple-Texterkennung verliert bei einem Bild mit extremem Seitenverhältnis den Großteil des Textes, wenn das
ganze Bild in einem Zug erkannt wird (`ReceiptScannerView.process(_:)`, die eine `VNRecognizeTextRequest`
auf dem Gesamtbild). Messung:

| Weg | Blöcke | Positionen | Endsumme erkannt |
|---|---|---|---|
| Ganzes Bild (heutiger Weg) | 110, fast nur Preise; Namen und alle 22 Rabattzeilen fehlen | 4 (auf dem Gerät: 3) | nein |
| Streifen 2400 px, Überlappung 300 px | 159 (Duplikate der Überlappung entfernt) | 18 | ja, 68,69 € |
| Ganzbild mit `minimumTextHeight` 0,001 / 0,002 / 0,003 | 110 / 110 / 110 | — | — |
| Ganzbild mit Revision 2 | 112 | — | — |

**Die Rabattzeilen sind nicht die Ursache.** Der Parser (`ReceiptParserService.reconstructLines`, `parse`,
`detectedTotal`) kommt mit den Streifen-Zeilen zurecht und bleibt **unverändert**; negative Preise
(Rabattzeilen) werden wie bisher ignoriert.

Diese Spec ersetzt die eine Ganzbild-Anfrage in `process(_:)` durch einen eigenen Erkenner
(`ReceiptTextRecognizer`), der

1. nur bei **sehr hohen** Bildern (Höhe/Breite über einer Schwelle) das Bild in überlappende Streifen schneidet,
2. je Streifen mit **denselben Einstellungen wie heute** erkennt,
3. die Blöcke der Streifen in Koordinaten des Gesamtbildes umrechnet und Duplikate aus den
   Überlappungsbereichen entfernt,
4. und das Ergebnis in genau der Form zurückgibt, die `ReceiptParserService.reconstructLines` heute bekommt.

Normale Bon-Fotos (Hochkant, Seitenverhältnis ca. 1,3 bis 2) bleiben im Einzelzug und damit **unverändert**.
Rabatt je Artikel abzuziehen (Nettopreise) ist ausdrücklich nicht Teil (siehe Abgrenzung).

## Source

- **File (neu):** `SmartCart/Services/ReceiptTextRecognizer.swift` (reine Funktionen + Erkennung je Streifen)
- **File:** `SmartCart/Views/Prices/ReceiptScannerView.swift` (`process(_:)`, Zeilen ca. 678-754; die eigene
  Vision-Anfrage in ca. 691-724 entfällt, der Aufruf von `ReceiptParserService.detectedTotal`/`parse` und
  `ReceiptResolutionService.resolve` ab ca. 725 bleibt)
- **File (neu, Test):** `RestockTests/ReceiptTextRecognizerTests.swift`
- **Unverändert, aber Verbraucher:** `SmartCart/Services/ReceiptParserService.swift`
  (`reconstructLines` :150, `parse` :176, `detectedTotal` :214), `SmartCart/Services/ReceiptShareHandoff.swift`
  (die Teilen-Erweiterung übergibt das Bild; die Erkennung läuft danach ebenfalls in
  `ReceiptScannerView.process`, einzige Vision-Stelle für Bons neben `RecipeRecognitionService`)

Zeilennummern verschieben sich; maßgeblich sind die Funktionen.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ReceiptParserService.reconstructLines(_:)` | function | Nimmt `[(text: String, box: CGRect)]` (Box normiert, Ursprung unten links) und baut physische Bon-Zeilen; bleibt unverändert. Der Erkenner liefert Blöcke in dieser Form, jetzt in Gesamtbild-Koordinaten. |
| `ReceiptParserService.parse` / `detectedTotal(from:)` | function | Unverändert. |
| `VNRecognizeTextRequest`, `VNImageRequestHandler` (Vision) | framework | Erkennung je Streifen bzw. im Einzelzug; dieselben Einstellungen wie heute. |
| `CGImagePropertyOrientation(_:)` (Erweiterung bei `UIImage.imageOrientation`) | extension | Ausrichtung wie heute mitgeben. |
| `ReceiptScannerView.process(_:)` | function | Einziger Aufrufer; Fehler-/Nil-Verhalten (kein `cgImage`, Vision wirft) bleibt. |
| `ReceiptResolutionService.resolve` | function | Nachgelagert, unverändert. |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptTextRecognizer.swift` | CREATE (+pbxproj) | Reine Funktionen `needsTiling`, `tiles`, Umrechnung in globale Boxen, Duplikat-Entfernung; Erkennung je Streifen bzw. im Einzelzug. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `process(_:)` ruft den Erkenner statt der eigenen Vision-Anfrage. |
| `RestockTests/ReceiptTextRecognizerTests.swift` | CREATE (+pbxproj) | Streifen-Mathematik, Umrechnung, Duplikate, erzeugtes hohes Bon-Bild (RED: Einzelzug verliert Text). |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Zwei neue Dateien an allen vier Stellen registrieren (`PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`). `ReceiptTextRecognizer.swift` → Gruppe `Services`, Target `Restock`; `ReceiptTextRecognizerTests.swift` → Gruppe `RestockTests`, Target `RestockTests`. |

Der Erkenner wird nur von der App gebraucht (`ReceiptScannerView`); die Share Extension übergibt nur das Bild
und erkennt nicht selbst. Eine Registrierung im Share-Extension-Target ist nicht nötig (vor der Umsetzung per
Suche nach `VNRecognizeTextRequest` und nach `ReceiptScannerView` im Extension-Target gegenzuprüfen).

### Estimated Changes
- Dateien: 3 plus `project.pbxproj` (innerhalb der Grenze von 4-5).
- LoC: ca. +150/−25 (Testcode zählt im LoC-Gate als Produktivcode, Memory „LoC-Gate zählt Testcode“; unter
  ±250).
- Risiko: mittel. Es ist die zentrale Bon-Erkennung; normale Bilder bleiben auf dem alten Weg (Einzelzug, gleiche
  Einstellungen). Adversary 2 Runden.
- Seiteneffekte: keine neuen Dependencies, keine `Info.plist`-Änderung, kein neuer `@AppStorage`-Schlüssel,
  keine neuen Berechtigungen, keine Audio-Dateien. Das Datenformat der Parser-Eingabe bleibt gleich.

## Definition of Done

- [ ] Hohes Bild: RED belegt (Einzelzug verliert Text, Streifenweg nicht) bzw. offen benannt, falls mit erzeugtem
  Bild nicht erzeugbar; danach grün (AC-1, AC-2)
- [ ] Schwelle `needsTiling`: hohe Bilder ja, normale Bon-Fotos nein (AC-3)
- [ ] Streifen lückenlos, überlappend, letzter Streifen bis Bildende, keine Höhe 0 (AC-4, AC-5)
- [ ] Umrechnung der Boxen in Gesamtbild-Koordinaten (AC-6)
- [ ] Duplikate der Überlappung entfernt, echte Wiederholungen bleiben (AC-7, AC-8)
- [ ] Einstellungen und Ausrichtung wie heute, Einzelzug für normale Bilder unverändert (AC-9, AC-10)
- [ ] Fehler-/Nil-Verhalten wie heute, Spinner hängt nie (AC-11)
- [ ] Parser und Auflösung unverändert (AC-12)
- [ ] Unit-Suite grün, Testzahl > 0 (AC-13)
- [ ] Ganze UI-Suite lokal grün (AC-14)
- [ ] Release-Build kompiliert (AC-15)
- [ ] Durchlauf mit dem echten Bon-Bild aus #120 durch die echte Erkennungsstrecke der App im Simulator,
  als Artefakt registriert (AC-16)
- [ ] Offene Grenzen und Nicht-Ziele in Ticket und Bericht (AC-17)
- [ ] Diff gegen Tip-Commit: genau die genannten Dateien, keine neuen Dependencies, keine
  `Info.plist`-/`@AppStorage`-Änderung, kein Wegwerf-Haken mehr im Code (AC-18)

## Implementation Details

### 1. `ReceiptTextRecognizer` (reine Funktionen, testbar ohne Vision)

Form (Namen, Typen, Parameter legt Phase 5/6 fest; das Verhalten ist verbindlich):

```swift
enum ReceiptTextRecognizer {
    /// Höhe/Breite über der Schwelle -> Streifen.
    static func needsTiling(imageSize: CGSize) -> Bool
    /// Streifen als Pixel-Rechtecke (Ursprung oben links, wie CGImage.cropping), lückenlos, überlappend.
    static func tiles(imageSize: CGSize) -> [CGRect]
    /// Vision-Box (normiert, Ursprung unten links, bezogen auf den Streifen) -> normierte Box des Gesamtbildes.
    static func globalBox(_ box: CGRect, tile: CGRect, imageSize: CGSize) -> CGRect
    /// Entfernt Duplikate aus den Überlappungsbereichen.
    static func removingDuplicates(_ blocks: [(text: String, box: CGRect)], imageSize: CGSize)
        -> [(text: String, box: CGRect)]
    /// Erkennung (Streifen oder Einzelzug); Rückgabe in der Form von reconstructLines.
    static func recognizeBlocks(in cgImage: CGImage, orientation: CGImagePropertyOrientation)
        -> [(text: String, box: CGRect)]
}
```

- **Schwelle (`needsTiling`):** Höhe/Breite **> 2,5**. Begründung: normale Bon-Fotos liegen bei ca. 1,3 bis 2,
  das Problembild bei ca. 7,5; die Schwelle liegt dazwischen. Der Wert 2,5 ist eine Festlegung ohne Messung an
  Bildern zwischen 2,5 und 7,5 (offene Grenze). Breite oder Höhe 0 liefert `false`.
- **Streifen (`tiles`):** Streifenhöhe ≈ **2 × Breite** (Problembild: ca. 2400 px, dort gemessen), Überlappung ≈
  **0,25 × Breite** (ca. 300 px, dort gemessen), Schrittweite = Streifenhöhe − Überlappung. Ganzzahlige Pixel.
  Der erste Streifen beginnt bei 0, jeder weitere beginnt `Überlappung` über dem Ende des vorigen, der **letzte
  endet genau am Bildende** (kein abgeschnittener Rest). Streifen haben volle Bildbreite. Kein Streifen hat
  Höhe 0, und es entsteht kein Streifen, der nur aus dem Überlappungsbereich besteht. Bild ohne Bedarf
  (`needsTiling == false`) liefert **einen** Streifen = ganzes Bild.
- **Umrechnung (`globalBox`):** x und Breite bleiben (volle Breite). Die Vision-Box ist normiert mit Ursprung
  unten links bezogen auf den Streifen; für das Gesamtbild (Höhe H, Streifen mit Oberkante `tile.minY`,
  Unterkante `tile.maxY`, Höhe `tile.height`):
  `y_global = (H − tile.maxY + box.minY × tile.height) / H`, `h_global = box.height × tile.height / H`.
  Ergebnis wieder normiert, Ursprung unten links, damit `reconstructLines` (sortiert/gruppiert nach Box) ohne
  Änderung funktioniert.
- **Duplikate (`removingDuplicates`):** Zwei Blöcke gelten als Duplikat, wenn der Text **gleich** ist (nach
  Trimmen) **und** der Abstand der Mittelpunkte im Gesamtbild (in Pixeln) **kleiner als ca. 15 px** ist, genauer:
  kleiner als ein kleiner Bruchteil (ca. 0,5) der Texthöhe des kleineren Blocks, mindestens aber so, dass zwei
  Erkennungen derselben Zeile aus zwei Streifen (Abweichung wenige Pixel) sicher zusammenfallen. Von zwei
  Duplikaten bleibt einer. Gleicher Text mit größerem Abstand (z. B. zwei aufeinanderfolgende gleiche Artikel in
  getrennten Zeilen) bleibt **beides** erhalten.
- **Erkennung je Streifen (`recognizeBlocks`):** pro Streifen `cgImage.cropping(to:)`, dann eine
  `VNRecognizeTextRequest` mit **denselben Einstellungen wie heute**: `.accurate`,
  `recognitionLanguages = ["de-DE", "fr-FR", "en-US"]`, `usesLanguageCorrection = false`, `orientation` wie
  heute übergeben. Streifen nacheinander (nicht parallel; Speicher). Ein Block ist `(topCandidates(1).first.string,
  boundingBox)`. Ein Fehler in einem Streifen (Vision wirft, `cropping` liefert `nil`) lässt diesen Streifen
  leer, die übrigen laufen weiter.
- **Ausrichtung:** Die Streifen-Geometrie bezieht sich auf das von Vision interpretierte (ausgerichtete) Bild.
  Für die Ausrichtung `.up` (digitale Bons, Bilder aus „Teilen“) ist das die Pixelgröße des `CGImage`. Bei
  gedrehten Ausrichtungen legt Phase 6 fest, wie sicher dieselbe Geometrie entsteht (z. B. vorher auf `.up`
  normalisieren); das Ergebnis muss dem des `.up`-Bildes entsprechen. Die Entscheidung `needsTiling` richtet sich
  nach der **ausgerichteten** Größe.

### 2. `ReceiptScannerView.process(_:)`

Die eigene `VNRecognizeTextRequest` samt `withCheckedContinuation` entfällt. Stattdessen:
`ReceiptParserService.reconstructLines(ReceiptTextRecognizer.recognizeBlocks(in:orientation:))`. Alles danach
(`debugRawLines`, `detectedTotal`, `parse`, `ReceiptResolutionService.resolve`, `parsedLines`, `phase = .review`)
bleibt. Der Kommentar zur Ausrichtung („WICHTIG: orientation muss mitgegeben werden“) und der Kommentar zur
Sprachkorrektur wandern mit in den Erkenner. Fehler-/Nil-Verhalten:

- kein `cgImage` → `parsedLines = []`, `phase = .review` (wie heute, vor dem Aufruf)
- Vision wirft → leere Blöcke → leere Zeilen → Spinner endet (wie heute, wo der `catch` die Continuation mit `[]`
  fortsetzt)

### 3. Nachweis mit dem echten Bild (Hinweis für Phase 6)

Das Original-Bild aus #120 liegt **außerhalb des Repos** (persönliche Angaben) und wird nicht eingecheckt. Der
Weg für den Durchlauf durch die echte Erkennungsstrecke der App im Simulator (z. B. ein Wegwerf-Haken oder
Launch-Argument, das das Bild aus einem Pfad außerhalb des Repos in `process(_:)` einspeist und Positionen und
Endsumme protokolliert; danach restlos entfernt) legt Phase 6 fest. Ist kein Weg machbar, wird das offen benannt
(AC-16). Messung auf dem Mac mit demselben Verfahren: 18 Positionen, Endsumme 68,69 €.

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED): GIVEN ein erzeugtes hohes Bon-Bild (Monospace-Text, ca. 1206 × 9000 px, Namens- und
  Preisspalte, blaue Rabattzeilen unter den Artikeln), WHEN es im Einzelzug (wie der heutige Code) mit
  Vision erkannt wird, THEN verliert der Einzelzug Text gegenüber dem Streifenweg (weniger erkannte
  Positionszeilen), WHEN es über `recognizeBlocks` (Streifen) erkannt und durch `reconstructLines`/`parse`
  geführt wird, THEN sind alle erzeugten Artikelzeilen enthalten (Soll-Positionszahl aus dem Generator) und die
  Endsumme wird erkannt. **Vorbehalt:** Ob sich der Textverlust mit einem erzeugten Bild erzeugen lässt, prüft
  Phase 5. Gelingt es nicht, entfällt der Einzelzug-Vergleich als Test, T2 bis T8 sichern Mathematik und
  Zusammenführung, und die Grenze wird in Ticket und Bericht offen benannt (AC-1 nicht durch Unit-Test
  abgedeckt, statt dessen AC-16).
- [ ] T2: GIVEN Bildgrößen 1206 × 9089, 1206 × 3100, 1000 × 1500, 1000 × 2000, 1000 × 2500, 1000 × 2501,
  0 × 0, WHEN `needsTiling` läuft, THEN `true` für die beiden hohen (und für 2501 bei Breite 1000), `false` für
  1500, 2000, 2500 (Grenze exklusiv) und 0 × 0.
- [ ] T3: GIVEN 1206 × 9089, WHEN `tiles` läuft, THEN: erster Streifen beginnt bei y = 0, jeder Streifen hat volle
  Breite und Höhe > 0, aufeinanderfolgende Streifen überlappen um ca. 0,25 × Breite (kein Spalt: Beginn des
  nächsten ≤ Ende des vorigen), die Streifenhöhe ist ca. 2 × Breite (nur der letzte darf kürzer sein), der
  letzte Streifen endet genau bei 9089, die Vereinigung deckt 0…9089 lückenlos ab.
- [ ] T4: GIVEN Höhen am Rand (genau eine Streifenhöhe + 1 px, genau Streifenhöhe + Überlappung, Höhe knapp über
  Schwelle, sehr kleine Höhe, `needsTiling == false`), WHEN `tiles` läuft, THEN keine Höhe 0, kein Streifen nur aus
  Überlappung, letzter endet am Bildende; ohne Bedarf genau ein Streifen = ganzes Bild.
- [ ] T5: GIVEN eine Vision-Box im ersten, in einem mittleren und im letzten Streifen, WHEN `globalBox` läuft,
  THEN stimmen y und Höhe gegen von Hand gerechnete Werte (Ursprung unten links, normiert auf das Gesamtbild);
  x und Breite bleiben; eine Box am oberen bzw. unteren Rand des Streifens landet an der richtigen Stelle des
  Gesamtbildes.
- [ ] T6: GIVEN dieselbe Zeile, in zwei überlappenden Streifen erkannt (Texte gleich, Mittelpunkte um wenige Pixel
  verschoben), WHEN `removingDuplicates` läuft, THEN bleibt genau ein Block.
- [ ] T7: GIVEN zwei Blöcke mit gleichem Text (z. B. „Bio Eier 2,49“) in verschiedenen Zeilen (Abstand ≥ eine
  Zeilenhöhe), WHEN `removingDuplicates` läuft, THEN bleiben beide; GIVEN zwei Blöcke mit nahem Mittelpunkt aber
  verschiedenem Text, THEN bleiben beide.
- [ ] T8: GIVEN Blöcke aus mehreren Streifen (aus der Mathematik in T3/T5/T6 synthetisch erzeugt, ohne Vision),
  WHEN sie in `reconstructLines` und `parse` gehen, THEN ergeben sie dieselben Positionen wie die
  Gesamtbild-Blöcke derselben Zeilen, auch über die Streifengrenze hinweg (Zeile in der Überlappung).
- [ ] T9 (AC-9, AC-10): GIVEN ein normales Bon-Bild (Seitenverhältnis ca. 1,5, erzeugt), WHEN `recognizeBlocks`
  läuft, THEN genau ein Erkennungsdurchgang (ein Streifen = Gesamtbild) und dasselbe Ergebnis wie die bisherige
  Einzel-Anfrage (Blocktexte gleich).
- [ ] T10 (AC-11): GIVEN ein `CGImage` der Größe 0 oder ein Streifen, dessen Zuschnitt `nil` liefert (über eine
  einhängbare Zuschnitt-/Erkennungsfunktion simuliert, falls Phase 6 sie so schneidet), WHEN `recognizeBlocks`
  läuft, THEN wird nicht abgestürzt, die Rückgabe ist leer bzw. enthält die übrigen Streifen, und der Aufruf
  kehrt zurück.
- [ ] T11 (AC-13): GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN grün, Testzahl > 0 (Memory
  „Null-Test-Lauf ist kein Grün“), bestehende Tests (u. a. `ReceiptParserLidlFullReceiptTests`) unverändert
  grün.
- [ ] T12 (AC-14): GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft,
  THEN grün ohne Abbruch und Retry-Flag.
- [ ] T13 (AC-15): GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN
  gelingt er.
- [ ] T14 (AC-18): GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat` läuft, THEN 3 Dateien plus
  `project.pbxproj`, ca. +150/−25 LoC.
- Zuordnung der übrigen ACs, die in den Tests oben nicht namentlich stehen: AC-2 in T1, AC-4 und AC-5 in T3 und
  T4, AC-7 in T6, AC-8 in T7, AC-12 in T11 (bestehende Parser-/Auflösungstests unverändert grün, Diff in T14
  zeigt keine Änderung an `ReceiptParserService.swift`).

Nicht durch Unit-Tests abgedeckt: AC-1 (falls der Textverlust mit dem erzeugten Bild nicht erzeugbar ist, siehe
Vorbehalt T1), AC-16 (Pflicht-Durchlauf mit dem echten Bild im Simulator, als Artefakt registriert, kein
Unit-Test) und AC-17 (Berichts- und Ticket-Texte, Prüfung im Abschlussbericht).

Nicht automatisierbar (offene Grenze): Bestätigung von Streifenhöhe und Schwelle an weiteren hohen Bons
(AC-17); das Original-Bild darf nicht im Repo liegen.

## Acceptance Criteria

- **AC-1:** GIVEN ein erzeugtes hohes Bon-Bild (ca. 1206 × 9000 px, Monospace-Text, Namens- und Preisspalte,
  blaue Rabattzeilen), WHEN es vor der Umsetzung (aktueller Weg: Ganzbild in einem Zug) erkannt wird, THEN
  fehlt Text gegenüber dem Streifenweg (RED, Ist-Zustand der PO-Meldung belegt). Lässt sich der Textverlust
  mit einem erzeugten Bild nicht erzeugen, wird das ausdrücklich als offene Grenze benannt, und AC-2 bis AC-8
  sichern Mathematik und Zusammenführung.
- **AC-2:** GIVEN derselbe Test nach der Umsetzung, WHEN die Erkennung über den Streifenweg läuft, THEN sind alle
  erzeugten Artikelzeilen und die Endsumme erkannt (Schalter Fehler da → Fix → Fehler weg).
- **AC-3:** GIVEN eine Bildgröße, WHEN `needsTiling` läuft, THEN ist das Ergebnis `true` genau dann, wenn
  Höhe/Breite > 2,5 ist (1206 × 9089 ja; Seitenverhältnis 1,3 bis 2 nein; Breite oder Höhe 0 nein).
- **AC-4:** GIVEN ein Bild mit `needsTiling == true`, WHEN `tiles` läuft, THEN haben alle Streifen volle
  Bildbreite und Höhe > 0, der erste beginnt bei 0, der letzte endet genau am Bildende, jeder Streifen beginnt
  höchstens am Ende des vorigen (lückenlos), und die Überlappung benachbarter Streifen beträgt ca. 0,25 × Breite.
- **AC-5:** GIVEN ein Bild mit `needsTiling == true`, WHEN `tiles` läuft, THEN beträgt die Höhe aller Streifen
  außer dem letzten ca. 2 × Breite, und es entsteht kein Streifen, der nur aus Überlappung besteht; GIVEN
  `needsTiling == false`, THEN genau ein Streifen = ganzes Bild.
- **AC-6:** GIVEN eine Vision-Box (normiert, Ursprung unten links, bezogen auf einen Streifen), WHEN sie in
  Gesamtbild-Koordinaten umgerechnet wird, THEN ist `y_global = (H − tile.maxY + box.minY × tile.height) / H`
  und `h_global = box.height × tile.height / H`; x und Breite bleiben; das Ergebnis ist wieder normiert mit
  Ursprung unten links.
- **AC-7:** GIVEN dieselbe Zeile, in zwei überlappenden Streifen erkannt (gleicher Text, Mittelpunkt-Abstand im
  Gesamtbild < ca. 15 px bzw. < kleiner Bruchteil der Texthöhe), WHEN Duplikate entfernt werden, THEN bleibt
  genau ein Block.
- **AC-8:** GIVEN zwei Blöcke mit gleichem Text und Mittelpunkt-Abstand von mindestens einer Zeilenhöhe oder
  zwei Blöcke mit nahem Mittelpunkt aber verschiedenem Text, WHEN Duplikate entfernt werden, THEN bleiben beide
  (zwei gleiche Artikel nacheinander gehen nicht verloren).
- **AC-9:** GIVEN die Erkennung je Streifen, WHEN sie läuft, THEN verwendet jede Anfrage `.accurate`,
  `recognitionLanguages == ["de-DE", "fr-FR", "en-US"]`, `usesLanguageCorrection == false` und die
  `orientation` wie heute (Streifen-Geometrie bezogen auf das ausgerichtete Bild).
- **AC-10:** GIVEN ein normales Bon-Foto (`needsTiling == false`), WHEN es erkannt wird, THEN gibt es genau einen
  Erkennungsdurchgang auf dem Gesamtbild mit denselben Einstellungen und demselben Ergebnis wie vor der
  Änderung.
- **AC-11:** GIVEN kein `cgImage`, Vision wirft oder ein Streifen scheitert, WHEN `process(_:)` läuft, THEN
  endet der Spinner: ohne `cgImage` `parsedLines == []` und `phase == .review` wie heute; wirft Vision, ergibt
  das leere Zeilen und `phase == .review`; scheitert ein einzelner Streifen, werden die übrigen Streifen
  weiter ausgewertet.
- **AC-12:** GIVEN die Änderung, WHEN man `ReceiptParserService.swift` und
  `ReceiptResolutionService.swift` gegen den Tip-Commit vergleicht, THEN sind beide unverändert; Rabattzeilen
  (negative Preise) werden weiterhin ignoriert.
- **AC-13:** GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN sind alle Tests grün, die Testzahl ist
  > 0, es gab keinen Abbruch.
- **AC-14:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN
  sind alle Tests grün, die Testzahl ist > 0, ohne Abbruch und Retry-Flag. (Bei Flakes #111 bleibt eine
  Ausnahme dem PO vorbehalten und wird nicht vorab angenommen.)
- **AC-15:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt der
  Build ohne Fehler.
- **AC-16:** GIVEN das echte Bon-Bild aus #120 (liegt außerhalb des Repos, persönliche Angaben, nicht
  eingecheckt) und die App im Simulator mit dem Stand dieses Durchgangs, WHEN das Bild durch die echte
  Erkennungsstrecke der App (`process(_:)` mit `ReceiptTextRecognizer`, `reconstructLines`, `parse`,
  `detectedTotal`) läuft, THEN werden mindestens 17 Positionen erkannt (Messung auf dem Mac: 18) und die
  Endsumme 68,69 € wird erkannt; der Durchlauf ist als Artefakt registriert (Commit-Kennung und Zeitstempel
  passen zum Stand). Der Weg (Wegwerf-Haken/Launch-Argument, danach restlos entfernt) legt Phase 6 fest; ist
  er nicht machbar, wird das ausdrücklich als offen benannt.
- **AC-17:** GIVEN Ticket und Berichte, WHEN sie formuliert werden, THEN nennen sie ausdrücklich die offenen
  Grenzen: Streifenhöhe (2 × Breite), Überlappung (0,25 × Breite) und Schwelle (2,5) sind an einem einzigen
  Bild gemessen bzw. festgelegt und werden an weiteren hohen Bons erst im Gebrauch bestätigt; die Nicht-Ziele
  (Rabatt je Artikel abziehen, Namensqualität einzelner Zeilen, PDF-/Mehrseiten-Bons); die erkannten Preise
  bleiben Regalpreise (Summe der 18 Positionen 70,67 € gegenüber Endsumme 68,69 €); es gibt keine Aussage
  „Rabatt-Bons repariert“ vor AC-16.
- **AC-18:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau
  `SmartCart/Services/ReceiptTextRecognizer.swift`, `SmartCart/Views/Prices/ReceiptScannerView.swift`,
  `RestockTests/ReceiptTextRecognizerTests.swift` und `Restock.xcodeproj/project.pbxproj` (je zwei neue
  Dateien an allen vier Stellen registriert; ca. +150/−25 LoC), ohne neue Dependencies, `Info.plist`-Änderung,
  neuen `@AppStorage`-Schlüssel oder einen übrig gebliebenen Wegwerf-Haken aus AC-16.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Regelbasierte Vorverarbeitung vor der bestehenden Vision-Erkennung; kein Modell beteiligt
  („Ohne Modell geht es nicht, weil …“ entfällt: es ist rein geometrisch und deterministisch). Kein früherer
  Beschluss wird gekippt; die Parser-Architektur (`reconstructLines` → `parse`) bleibt.

## Folge-Durchgänge/Abgrenzung

- **Ausdrücklich nicht Teil:**
  - **Rabatt je Artikel abziehen (Nettopreise):** Produktfrage, PO entscheidet; erkannte Preise sind
    Regalpreise (Summe der 18 Positionen 70,67 € gegenüber Endsumme 68,69 € ist bekannt). Eigenes Ticket, wenn
    der PO es will.
  - **Namensqualität einzelner Zeilen** (z. B. doppelter Name „Antip.-Crem.Bärlauch Antip.-Crem.Barlauch“,
    Menge im Namen „Reese's Sh. B.Pieces 1,79 x“): eigene Aufgabe, nach gemeinsamem Ziel gebündelt als ein
    GitHub-Issue (nicht als Mini-Tickets).
  - **PDF-/Mehrseiten-Bons.**
- **Offene Grenze:** Streifenhöhe, Überlappung und Schwelle sind an einem Bild gemessen; weitere hohe Bons
  bestätigen sie erst im Gebrauch.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt, gemessen)** | Hohe Bilder in überlappende Streifen schneiden, je Streifen erkennen, Boxen global umrechnen, Duplikate der Überlappung entfernen | Regelbasiert, belegt (110 → 159 Blöcke, 4 → 18 Positionen, Endsumme erkannt); normale Bilder unverändert |
| B | Bild vor der Erkennung skalieren/umrechnen (z. B. Breite verdoppeln) | nicht gemessen; Streifen sind der belegte Weg; Speicher bei 1206 × 9089 wächst |
| C | Rabatt je Artikel abziehen (Nettopreise) | löst die gemeldete Ursache nicht (Rabattzeilen sind nicht schuld); Produktfrage, eigenes Thema |
| D | Einstellungen der Anfrage ändern (`minimumTextHeight`, Revision 2) | gemessen: 110/110/110 bzw. 112 Blöcke, keine Wirkung; verworfen |
| E | Für alle Bilder immer Streifen | ändert das Verhalten normaler Fotos ohne Bedarf und Messung; verworfen |

Kein Modell beteiligt. Gekippte frühere Entscheidung: keine.

**Entscheidung:** Weg A.

## Risiken

- **Zentrale Bon-Erkennung berührt:** `process(_:)` wird für jeden Scan durchlaufen. Normale Bilder bleiben im
  Einzelzug mit denselben Einstellungen (AC-9, AC-10, T9); Adversary 2 Runden.
- **Schwelle und Streifenmaße an einem Bild gemessen:** Zwischen Seitenverhältnis 2,5 und 7,5 liegt keine
  Messung; das Problem kann auch bei kleineren Verhältnissen auftreten oder die Streifen ungünstig schneiden.
  Offen benannt (AC-17).
- **Text in der Streifengrenze:** Eine Zeile, die genau auf einer Streifenkante liegt, kann zerschnitten werden;
  die Überlappung von 0,25 × Breite (ca. 300 px) ist deutlich größer als eine Zeilenhöhe und fängt das ab
  (T8 deckt eine Zeile in der Überlappung).
- **Duplikat-Regel zu eng/weit:** Zu eng lässt Doppelzeilen stehen (doppelte Positionen), zu weit löscht echte
  Wiederholungen. T6 und T7 begrenzen beides; die ca. 15 px sind am Problembild gemessen.
- **Erzeugtes Bild reproduziert den Textverlust nicht:** Dann sichern T2 bis T8 die Mathematik, und der
  Nachweis liegt allein in AC-16 (echtes Bild). Offen benannt.
- **Ausrichtung gedrehter Bilder:** Zuschnitt und Box-Umrechnung müssen auf dem ausgerichteten Bild rechnen;
  Fehler würden vertauschte Koordinaten ergeben. Phase 6 legt den Weg fest, T9/AC-9 prüfen die Ausrichtung
  `.up`; gedrehte Ausrichtungen sind für Bilder mit Bedarf (digitale Bons) selten und ggf. offen zu benennen.
- **Speicher und Dauer:** Bis zu mehrere Streifen nacheinander; der Lauf läuft schon heute in einem
  `Task.detached(priority: .userInitiated)`. Streifen nicht parallel.
- **Datenschutz:** Das echte Bild enthält persönliche Angaben und darf nicht ins Repo; Messskripte liegen unter
  `docs/artifacts/fix-120-bon-lange-bilder/`, das Bild nicht.
- **Wegwerf-Haken für AC-16 bleibt im Code:** AC-18 prüft, dass nichts übrig bleibt (DEBUG-only und restlos
  entfernt).
- **LoC-Gate zählt Testcode als Produktivcode:** ca. +150/−25 liegt unter dem Limit; vor Abschluss prüfen.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün.
- **Zeilennummern verschieben sich:** maßgeblich sind die Funktionen.

## Changelog

- 2026-10-07: Initial spec created (Issue #120; Streifenverfahren für sehr hohe Bon-Bilder in
  `ReceiptTextRecognizer`, Parser unverändert, Nachweis mit dem echten Bild im Simulator)
