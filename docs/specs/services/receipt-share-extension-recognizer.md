---
entity_id: receipt-share-extension-recognizer
type: bugfix
created: 2026-10-08
updated: 2026-10-08
status: draft
workflow: fix-120-bon-teilen-weg
tags: [receipt, ocr, vision, share-extension, tiling, lidl-plus, issue-120]
---

# Bon-Teilen-Weg: Erweiterung nutzt denselben Streifen-Erkenner wie die App (Issue #120, Fortsetzung)

## Approval

- [ ] Approved — PO (offen)

## Purpose

PO-Meldung 2026-10-08 (#120, Build 10): Der echte Lidl-Plus-Bon (1206 × 9089 px) liefert auf Hennings iPhone über
„Teilen → Restock“ weiterhin nur ca. 3 Artikel. Die Streifen-Erkennung aus #124
(`docs/specs/services/receipt-text-recognizer-tiling.md`) greift nur im App-Scanner, nicht in der
Teilen-Erweiterung. Hat es bisher funktioniert? Nein, nie: Der Teilen-Weg hatte nie Streifen.

**Root Cause (am Simulator nachgestellt, Restock-Validate, iOS 27, Weg Fotos → Teilen → Restock, mit
`scripts/run-share-extension-uitest.sh` und dem echten Bon):**
`ShareViewController.recognizeText` ist ein zweiter, eigener `VNRecognizeTextRequest` auf dem Gesamtbild und
umgeht `ReceiptTextRecognizer`. `ReceiptTextRecognizer.swift` ist zudem nicht im Ziel der Erweiterung (pbxproj:
`BuildFile A1200D0000000000000000B1` steht nur in der Sources-Phase des App-Ziels; die Erweiterung hat nur
`ReceiptParserService`, `52C8EBC70575CE1543785171`). Messung:

| Weg (gleiches Bild) | Positionen | Endsumme |
|---|---|---|
| Teilen-Erweiterung, Simulator, heute | 14 (93 Rohzeilen) | nein |
| App-Scanner, Simulator | 19 | 68,69 € |
| Teilen-Erweiterung, Gerät (Build 10, Hennings Meldung) | ca. 3 | — |

Analyse und Ablaufbeleg: `docs/context/fix-120-bon-teilen-weg.md` (der Beleg selbst liegt im Scratchpad, das Bild
mit persönlichen Angaben bleibt außerhalb des Repos).

Diese Spec (Weg A, vom Analysebefund vorgegeben) macht aus zwei Erkennungswegen einen:

1. `ShareViewController.recognizeText` entfällt. Die Erweiterung ruft
   `ReceiptTextRecognizer.recognizeBlocks(in:orientation:)` und danach `ReceiptParserService.reconstructLines`.
   Vision-Einstellungen bleiben dieselben (liegen im Erkenner, unverändert).
2. `ReceiptTextRecognizer.swift` wird in der Sources-Phase des Erweiterungsziels registriert.
3. Das Nachweisskript zählt Positionen und Endsumme der Nutzlast und prüft eine Mindestzahl; „Nutzlast: ja“
   genügt nicht mehr.
4. Ein Drift-Test hält fest, dass Erweiterung und App denselben Erkenner benutzen, damit die Lücke nicht
   wiederkommt.

**Offene Grenze, in jeder positiven Zusage dieser Spec mitzulesen:** Das Speicherlimit einer Teilen-Erweiterung
(iOS ca. 120 MB) wird im Simulator nicht erzwungen. Der App-Scanner lag in der Messung bei einer Spitze von
134 MB. Ob die Erweiterung mit Streifen am echten Bon auf dem Gerät unter dem Limit bleibt, ist **nicht bewiesen**
und erst nach Build 11 am Gerät prüfbar. Das darf nur geschehen, wenn Henning ausdrücklich „jetzt ist ein Test
möglich“ schreibt; auf seinen Geräten wird nie ungefragt getestet. Bis dahin lautet die Aussage höchstens:
„im Simulator erkennt der Teilen-Weg N Positionen und die Endsumme“, nie „Teilen-Weg repariert“.

Regel vor Modell: Es ist reine Vision-Regel (Geometrie, Streifen, Duplikat-Entfernung); kein Sprachmodell
beteiligt, die KI-Auflösung bleibt in der Erweiterung wie bisher aus (`allowAIResolution: false`).

## Source

- **File:** `RestockShareExtension/ShareViewController.swift` (`process()` ab ca. Z. 129; `recognizeText`
  ca. Z. 251-270 entfällt)
- **File:** `SmartCart/Services/ReceiptTextRecognizer.swift` (unverändert; `recognizeBlocks(in:orientation:)`
  liefert `[Block]` mit `typealias Block = (text: String, box: CGRect)`)
- **File:** `Restock.xcodeproj/project.pbxproj` (neuer `PBXBuildFile` + Eintrag in der Sources-Phase des
  Erweiterungsziels, `67BDC10E19FEF56A93370E2E`, bei `ReceiptParserService`, ca. Z. 1014)
- **File:** `scripts/run-share-extension-uitest.sh` (Auswertung am Ende)
- **File:** `RestockUITests/ReceiptShareExtensionTests.swift` (Kachel-Tipp per Koordinate, liegt als
  uncommittete Änderung vor)
- **File (Test):** `RestockTests/ReceiptTextRecognizerTests.swift` (neuer Drift-Test)
- **Unverändert, aber Verbraucher:** `ReceiptParserService` (`reconstructLines`, `parse`, `detectedTotal`),
  `ReceiptShareHandoff.store`, Review-Screen der App (`lines`, `rawLines`, `detectedTotal`).

Zeilennummern verschieben sich; maßgeblich sind die Funktionen.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ReceiptTextRecognizer.recognizeBlocks(in:orientation:)` | function | Streifen-Erkennung aus #124; reine CoreGraphics/CoreImage/Vision-Abhängigkeit, daher im Erweiterungsziel kompilierbar. |
| `ReceiptParserService.reconstructLines(_:)` | function | Nimmt die Blöcke, liefert `[String]`; unverändert. |
| `ReceiptParserService.parse` / `detectedTotal(from:)` | function | Unverändert. |
| `CGImagePropertyOrientation(_:)` | extension | Ausrichtung wie heute aus `image.imageOrientation`; die Erweiterung benutzt sie schon (Quelle prüfen: im Erweiterungsziel verfügbar, sonst Phase 5 klärt). |
| `ReceiptShareHandoff.store(_:)`, `SharedReceiptPayload` | type | Unverändert. |
| `scripts/run-share-extension-uitest.sh` | script | Nachweislauf Fotos → Teilen → Restock auf `Restock-Validate`. |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `RestockShareExtension/ShareViewController.swift` | MODIFY | `recognizeText` entfällt; Aufruf `reconstructLines(ReceiptTextRecognizer.recognizeBlocks(...))` (ca. −20/+6). `import Vision` darf entfallen, wenn die Datei Vision sonst nicht braucht. |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Neuer `PBXBuildFile` `A1200D0000000000000000B3` (fileRef `A1200D0000000000000000B2`, vorher auf Kollision geprüft: 0 Treffer) + Eintrag in Sources-Phase `67BDC10E19FEF56A93370E2E` (+2 Zeilen). `PBXFileReference` und Gruppe bleiben (Datei ist schon registriert). |
| `scripts/run-share-extension-uitest.sh` | MODIFY | Positionszahl und Endsumme aus `pendingShareExtensionReceipt` lesen, ausgeben, Mindestzahl prüfen (ca. +25). |
| `RestockUITests/ReceiptShareExtensionTests.swift` | MODIFY | Kachel-Tipp per Koordinate (ca. +3, liegt vor). |
| `RestockTests/ReceiptTextRecognizerTests.swift` | MODIFY | Drift-Test (ca. +40). |

### Estimated Changes
- Dateien: 5 (Grenze 4-5 eingehalten). LoC: ca. +90/−25 (Testcode zählt im LoC-Gate als Produktivcode;
  unter ±250).
- Risiko: mittel. Zentrale Bon-Erkennung im Teilen-Weg; das Speicherlimit der Erweiterung ist nur am Gerät
  prüfbar (siehe Purpose und Risiken).
- Seiteneffekte: keine neuen Dependencies, keine `Info.plist`-Änderung, kein `@AppStorage`-Schlüssel,
  keine neuen Berechtigungen, keine Audio-Dateien. Normale (nicht hohe) Bilder laufen im Einzelzug wie zuvor.
  Die Erweiterung erhält zusätzlichen Code (`ReceiptTextRecognizer`) im Binary.

## Definition of Done

- [ ] Reproduktion vorher belegt: Skript meldet am echten Bon 14 Positionen, keine Endsumme (AC-1)
- [ ] Drift-Test vor der Umsetzung rot, danach grün (AC-2, AC-3)
- [ ] Erweiterung nutzt `ReceiptTextRecognizer`, `recognizeText` und eigener `VNRecognizeTextRequest` entfernt (AC-3, AC-4)
- [ ] Erkennungsfehler → leere Zeilen → `.noItemsFound` wie bisher (AC-5)
- [ ] Skript gibt Positionszahl und Endsumme aus und prüft Mindestzahl (AC-6)
- [ ] Nachher am Simulator mit dem echten Bon: ≥ 18 Positionen und Endsumme 68,69 €, kein neuer Absturzbericht (AC-7)
- [ ] Kachel-Tipp per Koordinate (AC-8)
- [ ] Unit-Suite grün, Testzahl > 0 (AC-9); ganze UI-Suite lokal grün (AC-10); Release-Build kompiliert (AC-11)
- [ ] Offene Grenze (Speicherlimit, Gerätenachweis erst nach Build 11 und Hennings Wort) in Ticket und Bericht (AC-12)
- [ ] Diff gegen Tip-Commit: genau die fünf Dateien, keine neuen Dependencies, Parser unverändert (AC-13)

Nicht Teil der DoD, ausdrücklich offen: Gerätenachweis des Speicherlimits.

## Implementation Details

### 1. `ShareViewController.process()`

Im Zweig `.image` ersetzt
`lines = ReceiptParserService.reconstructLines(ReceiptTextRecognizer.recognizeBlocks(in: cgImage, orientation: orientation))`
den Aufruf `await recognizeText(...)`. Die Erkennung ist synchron (Streifen nacheinander, Streifenbilder
leben nur im Zuschnitt-Durchgang); ob `process()` sie zum Schutz der Oberfläche in einen
`Task.detached` auslagert, legt Phase 6 fest (die App tut das schon). Alles danach (`parse`, `.noItemsFound`,
Store-Erkennung, Auflösung mit `allowAIResolution: false`, `ReceiptShareHandoff.store`, Mitteilung, Erfolgsanzeige)
bleibt. Der `@MainActor`-Kommentar, der sich auf die Vision-Continuation bezog, wird angepasst, weil keine
Continuation mehr existiert; die `@MainActor`-Isolation bleibt. Der PDF-Zweig (`.pdfLines`) bleibt unberührt.

Rückfall bei Fehler: Wirft Vision oder scheitert ein Streifen, liefert der Erkenner leere Blöcke bzw. die
übrigen Streifen (Verhalten aus #124, AC-11 dort). Leere Zeilen → `parse` leer → `state = .noItemsFound`,
wie heute bei `recognizeText` mit `catch → []`.

### 2. pbxproj

Ein `PBXBuildFile`-Eintrag `A1200D0000000000000000B3 /* ReceiptTextRecognizer.swift in Sources */` mit
`fileRef = A1200D0000000000000000B2` und ein Eintrag in `files = (…)` der Sources-Phase
`67BDC10E19FEF56A93370E2E`. Registrierung der Datei in Gruppe und `PBXFileReference` existiert bereits.

### 3. Prüfskript

Nach dem Lauf liest das Skript die Nutzlast aus dem App-Gruppen-Eintrag `pendingShareExtensionReceipt`
(Binärdaten in der plist; Dekodierung z. B. per PlistBuddy-Export der Daten und Python/`plutil`/`jq`, Form
legt Phase 6 fest, kein neues Werkzeug außerhalb der Mac-Bordmittel) und gibt aus:
`Positionen in der Nutzlast: N`, `Endsumme: X,XX €` bzw. `keine`. Eine Mindestzahl (Umgebungsvariable
`MIN_POSITIONS`, Vorgabe 18 für den echten Bon; mit `TEST_IMAGE` auf ein anderes Bild setzbar, `0` schaltet die
Prüfung ausdrücklich ab) und die Endsumme-Prüfung (`EXPECT_TOTAL`, Vorgabe `68,69`) gehören zum Urteil:
GRÜN nur bei Nutzlast ja, keine neuen Absturzberichte, Positionen ≥ Mindestzahl, Endsumme wie erwartet. Lässt
sich die Nutzlast nicht dekodieren, ist das Urteil ROT mit klarer Meldung (nie stillschweigend GRÜN).
Das Standard-Testbild liegt weiter außerhalb des Repos (`TEST_IMAGE`).

### 4. UI-Test

`ReceiptShareExtensionTests`: Kachel per `coordinate(withNormalizedOffset:)` antippen, weil die schwebende
Leiste der Fotos-App die unterste Reihe teilweise verdeckt und `tap()` „not hittable“ meldet. Liegt als
Änderung vor.

### 5. Drift-Test

In `ReceiptTextRecognizerTests`: liest `Restock.xcodeproj/project.pbxproj` und
`RestockShareExtension/ShareViewController.swift` per `#filePath` (Repo-Wurzel zwei Ebenen über `RestockTests/`)
und prüft (a) in der Sources-Phase des Erweiterungsziels steht `ReceiptTextRecognizer.swift`, (b)
`ShareViewController.swift` enthält weder `VNRecognizeTextRequest` noch `func recognizeText`. Der Test findet das
Erweiterungsziel über den Namen im pbxproj (`PBXNativeTarget` mit `RestockShareExtension`) und die zugehörige
`buildPhases`-Sources-Phase, nicht über feste UUIDs, damit er nicht an Umbenennungen von UUIDs hängt. Er muss
**vor** der Umsetzung rot sein (RED), danach grün.

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED zuerst): GIVEN der Stand vor der Umsetzung, WHEN der Drift-Test läuft, THEN fehlt
  `ReceiptTextRecognizer.swift` in der Sources-Phase des Erweiterungsziels und `ShareViewController.swift`
  enthält `VNRecognizeTextRequest` → Test rot. Nach der Umsetzung grün.
- [ ] T2: GIVEN der Drift-Test, WHEN er auf einer Kopie des pbxproj-Textes ohne den Erweiterungs-Eintrag bzw. auf
  einem Quelltext mit `VNRecognizeTextRequest` läuft (die Prüffunktion nimmt Texte als Eingabe), THEN schlägt sie
  an; auf dem echten Stand besteht sie (beweist, dass der Test nicht leer prüft).
- [ ] T3: GIVEN die Erweiterung mit dem echten Bon im Simulator (`scripts/run-share-extension-uitest.sh`
  auf Restock-Validate), WHEN der Teilen-Ablauf durchläuft, THEN meldet das Skript Nutzlast ja, Positionen ≥ 18,
  Endsumme 68,69 €, 0 neue Absturzberichte. **Vorher** (Stand vor der Umsetzung, am selben Bon): 14 Positionen, keine
  Endsumme → Skript ROT (Reproduktion; Schalter Fehler da → Fix → Fehler weg).
- [ ] T4: GIVEN das Skript, WHEN die Nutzlast weniger Positionen als `MIN_POSITIONS` enthält oder die Endsumme
  fehlt, THEN endet es mit ROT und benennt die Zahl (am Vorher-Stand aus T3 belegt).
- [ ] T5: GIVEN ein Bild ohne erkennbaren Text (leere Blöcke), WHEN `process()` läuft, THEN
  `state == .noItemsFound`. Der Pfad ist unverändert (`parse([])` leer); belegt durch den Code-Lesetest/Diff
  (kein neuer Code im Pfad) und, soweit Phase 6 es mit der vorhandenen UI-Testbasis kann, durch den Ablauf;
  ist er nicht automatisierbar, steht das offen im Bericht.
- [ ] T6 (AC-9): GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN grün, Testzahl > 0 (kein
  „Null-Test-Lauf“), bestehende Tests der Streifen-Mathematik und Parser unverändert grün.
- [ ] T7 (AC-10): GIVEN die gesamte UI-Suite im gemeinsamen Lauf auf `Restock-Validate`, WHEN sie läuft, THEN
  grün ohne Abbruch und Retry-Flag (`ReceiptShareExtensionTests` nur mit gesetztem `RESTOCK_SHARE_E2E`, sonst
  überspringt er sich).
- [ ] T8 (AC-11): GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN
  gelingt er, einschließlich Erweiterungsziel.
- [ ] T9 (AC-13): GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat` läuft, THEN genau die fünf Dateien,
  ca. +90/−25 LoC, `ReceiptParserService.swift` und `ReceiptTextRecognizer.swift` unverändert.

Nicht automatisiert: Speicherspitze der Erweiterung am echten Bon auf dem Gerät (AC-12). Der Simulator erzwingt
das Limit nicht. Eine Simulator-Messung der Spitze (z. B. `xcrun simctl spawn … footprint` oder Instruments
auf dem Erweiterungsprozess) ist erlaubt und wird, falls gemessen, als Näherung beschriftet, nicht als Nachweis.

## Acceptance Criteria

- **AC-1:** GIVEN der Stand vor der Umsetzung und das echte Bon-Bild aus #120 (außerhalb des Repos), WHEN
  `scripts/run-share-extension-uitest.sh` auf `Restock-Validate` läuft, THEN enthält die Nutzlast 14 Positionen
  und keine Endsumme (Reproduktion, Ist-Zustand; die erweiterte Auswertung aus AC-6 macht den Wert sichtbar und
  das Skript ROT).
- **AC-2:** GIVEN der Drift-Test vor der Umsetzung, WHEN er läuft, THEN ist er rot (RED), weil
  `ReceiptTextRecognizer.swift` nicht in der Sources-Phase des Erweiterungsziels steht und
  `ShareViewController.swift` einen `VNRecognizeTextRequest` enthält.
- **AC-3:** GIVEN das pbxproj nach der Umsetzung, WHEN der Drift-Test läuft, THEN steht
  `ReceiptTextRecognizer.swift` in der Sources-Phase des Erweiterungsziels (neuer `PBXBuildFile`
  `A1200D0000000000000000B3`, kollisionsfrei) und der Test ist grün; er schlägt an, wenn der Eintrag fehlt (T2).
- **AC-4:** GIVEN `ShareViewController.swift` nach der Umsetzung, WHEN der Drift-Test läuft, THEN enthält die Datei
  weder `VNRecognizeTextRequest` noch `func recognizeText`, und `process()` erzeugt die Zeilen aus
  `ReceiptParserService.reconstructLines(ReceiptTextRecognizer.recognizeBlocks(in:orientation:))`; Einstellungen
  der Vision-Anfrage bleiben die des Erkenners (`.accurate`, `["de-DE","fr-FR","en-US"]`,
  `usesLanguageCorrection == false`), Parser, `ReceiptShareHandoff` und Review-Screen sind unverändert.
- **AC-5:** GIVEN die Erkennung liefert keine Zeilen (kein Text, Vision wirft, alle Streifen scheitern), WHEN
  `process()` läuft, THEN ist `state == .noItemsFound` wie bisher, ohne Absturz und ohne hängenden Zustand; bei
  gescheitertem einzelnen Streifen werden die übrigen weiter ausgewertet (Verhalten des Erkenners aus #124).
- **AC-6:** GIVEN das Skript nach der Umsetzung, WHEN es eine Nutzlast auswertet, THEN gibt es Positionszahl und
  Endsumme der Nutzlast aus und beendet sich ROT, wenn die Positionszahl unter `MIN_POSITIONS` (Vorgabe 18)
  liegt, die Endsumme fehlt oder von `EXPECT_TOTAL` (Vorgabe 68,69) abweicht oder die Nutzlast nicht dekodierbar
  ist; „Nutzlast ja“ allein führt nicht mehr zu GRÜN.
- **AC-7:** GIVEN die Umsetzung und das echte Bon-Bild, WHEN `scripts/run-share-extension-uitest.sh` auf
  `Restock-Validate` im Simulator durchläuft, THEN meldet es mindestens 18 Positionen (Referenz App-Scanner: 19)
  und die Endsumme 68,69 € bei 0 neuen Absturzberichten der Erweiterung; die Ausgabe ist als Artefakt
  registriert (Commit-Kennung und Zeitstempel passen zum Stand). Diese Zusage gilt für den Simulator und nicht für
  das Gerät (AC-12).
- **AC-8:** GIVEN `ReceiptShareExtensionTests`, WHEN der Test die unterste Bildkachel in der Fotos-App antippt,
  THEN geschieht das per Koordinate (`coordinate(withNormalizedOffset:)`), und der Ablauf erreicht den
  Teilen-Knopf auch bei teilweise verdeckter Kachelreihe.
- **AC-9:** GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN sind alle Tests grün, die Testzahl ist > 0,
  es gab keinen Abbruch.
- **AC-10:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN
  sind alle Tests grün, die Testzahl ist > 0, ohne Abbruch und Retry-Flag. (Bei Flakes #111 bleibt eine Ausnahme
  dem PO vorbehalten und wird nicht vorab angenommen.)
- **AC-11:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt er
  ohne Fehler, Erweiterungsziel eingeschlossen.
- **AC-12:** GIVEN Ticket und Berichte, WHEN sie formuliert werden, THEN nennen sie ausdrücklich: das
  Speicherlimit der Erweiterung (ca. 120 MB) wird im Simulator nicht erzwungen, die Spitze des App-Scanners lag bei
  134 MB, die Erweiterung ist am Gerät **nicht** bewiesen; der Gerätenachweis folgt erst nach Build 11 und
  Hennings ausdrücklichem Wort „jetzt ist ein Test möglich“, es wird nie ungefragt auf seinen Geräten getestet;
  es gibt keine Aussage „Teilen-Weg auf dem Gerät repariert“ vor diesem Nachweis; Rückfall bei Limit-Verletzung ist
  Alternative B als eigenes Ticket.
- **AC-13:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau
  `RestockShareExtension/ShareViewController.swift`, `Restock.xcodeproj/project.pbxproj`,
  `scripts/run-share-extension-uitest.sh`, `RestockUITests/ReceiptShareExtensionTests.swift` und
  `RestockTests/ReceiptTextRecognizerTests.swift` (ca. +90/−25 LoC), ohne neue Dependencies,
  `Info.plist`-Änderung, neuen `@AppStorage`-Schlüssel, und ohne Änderung an `ReceiptParserService.swift`,
  `ReceiptTextRecognizer.swift` oder `ReceiptResolutionService.swift`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Ein Erkennungsweg für App und Erweiterung statt zwei (die Lücke entstand durch den zweiten,
  unabhängigen Vision-Aufruf). Regelbasiert, kein Modell: „Ohne Modell geht es“ ist belegt (App-Scanner mit
  denselben Streifen: 19 Positionen und Endsumme). Gekippt wird keine frühere Entscheidung; die Entscheidung
  „Erweiterung erkennt selbst und läuft ohne KI-Auflösung“ bleibt.

## Folge-Durchgänge/Abgrenzung

- **Ausdrücklich nicht Teil:**
  - **Gerätenachweis und Speichermessung am Gerät:** erst nach Build 11 und Hennings Wort „jetzt ist ein Test
    möglich“ (nie ungefragt auf seinen Geräten).
  - **Alternative B** (siehe unten) als Umbau; nur als eigenes Ticket, falls das Limit am Gerät verletzt wird.
  - **Gesamtabgrenzung aus `receipt-text-recognizer-tiling.md` gilt unverändert fort:** Rabatt je Artikel
    abziehen (Nettopreise, Produktfrage), Pfand im Streifenweg nicht zugeordnet, Namensqualität einzelner
    Zeilen, PDF-/Mehrseiten-Bons, und `RecipeRecognitionService` mit demselben Ganzbild-Aufruf (#123).
- **Offene Grenze:** Das Speicherlimit der Erweiterung ist im Simulator nicht prüfbar. Streifenhöhe,
  Überlappung und Schwelle bleiben an einem Bild gemessen (siehe Tiling-Spec).

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Erweiterung nutzt `ReceiptTextRecognizer` (Streifen nacheinander), danach `reconstructLines`; ein Erkennungsweg | Kleinster Eingriff (5 Dateien), Erfolgsmeldung mit Positionszahl bleibt, im Simulator gemessen 14 → ≥ 18 + Endsumme; Speicherlimit am Gerät offen |
| B | Die Erweiterung legt nur das Bild in der App-Gruppe ab, die App erkennt beim Öffnen | Kein Speicherrisiko in der Erweiterung, ein einziger Weg. Kippt „Erweiterung erkennt selbst“. Nachteile: keine Erfolgsmeldung mit Positionszahl, Laden-Erkennung und Mitteilung „N Positionen“ entfallen, Bild liegt unverschlüsselt in der App-Gruppe. Nur wählen, wenn A am Gerät das Limit reißt; dann eigenes Ticket |
| C | `recognizeText` in der Erweiterung belassen und Streifenlogik dort duplizieren | zwei Wege wieder auseinanderlaufend, genau die Ursache; verworfen |
| D | Sprachmodell zur Nachbesserung der 3 Positionen | in der Erweiterung wegen Speicher ausgeschlossen; Regelweg löst es nachweislich; verworfen |

Regel vor Modell: Der Regelweg (Vision + Geometrie) ist der Vorschlag; ein Modell ist nicht beteiligt.
Gekippte frühere Entscheidung bei A: keine. Bei B: „Erweiterung erkennt selbst“.

**Entscheidung:** Weg A; Rückfall B nur nach Limit-Verletzung am Gerät.

## Risiken

- **Speicherlimit der Erweiterung (ca. 120 MB):** Im Simulator nicht erzwungen, App-Scanner-Spitze 134 MB. Die
  Erweiterung hält zusätzlich Bild und Streifenzuschnitt; sie könnte vom System beendet werden (stiller Abbruch,
  keine Nutzlast). Maßnahmen: Streifen nacheinander, Zuschnitte nur kurz leben lassen. Nachweis nur am Gerät, nach
  Build 11 und Hennings Wort. Fällt das durch, greift Alternative B.
- **Neue Datei im Erweiterungsziel:** Kompiliert nur, wenn `ReceiptTextRecognizer` keine App-Abhängigkeit hat
  (nach Analyse rein CoreGraphics/CoreImage/Vision); Release-Build (AC-11) prüft das.
- **Drift-Test prüft Quelltext, nicht Verhalten:** Er schützt gegen das Wiederauftreten eines zweiten
  Erkennungswegs, ersetzt aber nicht den Durchlauf (AC-7).
- **Skript-Dekodierung der Nutzlast:** Die Nutzlast ist kodiert in der Gruppen-plist; schlägt die Dekodierung
  fehl, ist das Urteil ROT (AC-6), nicht still GRÜN.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün. Die
  Cross-App-Läufe nie parallel fahren.
- **Datenschutz:** Das echte Bild bleibt außerhalb des Repos (`TEST_IMAGE`).
- **Zeilennummern verschieben sich:** maßgeblich sind die Funktionen.

## Changelog

- 2026-10-08: Initial spec created (Issue #120, Fortsetzung; Teilen-Erweiterung nutzt `ReceiptTextRecognizer`,
  Drift-Test, Prüfskript mit Positionszahl und Endsumme)
