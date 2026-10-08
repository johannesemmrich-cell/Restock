# Context: fix-120-bon-teilen-weg

## Request Summary
Der echte Lidl-Bon (1206 × 9089 px) liefert auf Hennings iPhone (Build 10) über „Teilen → Restock“ weiterhin nur ~3
Artikel. Die Streifen-Erkennung aus #124 greift nur im App-Scanner, nicht in der Teilen-Erweiterung.

## Reproduktion (2026-10-08, Simulator Restock-Validate, iOS 27, Weg Fotos → Teilen → Restock)
`scripts/run-share-extension-uitest.sh` mit dem echten Bon: Übergabe in der App-Gruppe enthält **14 Positionen, keine
Endsumme** (93 Rohzeilen). Gegenprobe App-Scanner, gleiches Bild: 19 Positionen, Endsumme 68,69 €. Auf dem Gerät
verliert Vision im Gesamtbild noch mehr (~3). Ablauf-Beleg: `/private/tmp/.../scratchpad/repro-share-2.txt`
(Scratchpad, nicht im Repo; Bild enthält persönliche Angaben und bleibt außerhalb des Repos).

## Related Files
| File | Relevance |
|------|-----------|
| `RestockShareExtension/ShareViewController.swift:129-200,251-270` | `process()` und `recognizeText`: eigener `VNRecognizeTextRequest` auf dem Gesamtbild, ruft `ReceiptParserService.reconstructLines` |
| `SmartCart/Services/ReceiptTextRecognizer.swift` | Streifen-Erkenner aus #124 (`recognizeBlocks(in:orientation:)`), reine CoreGraphics/CoreImage/Vision-Abhängigkeit |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:678-700` | App-Scanner, Referenzaufruf des Erkenners |
| `Restock.xcodeproj/project.pbxproj` | `ReceiptTextRecognizer.swift` steht nur in der Sources-Phase des App-Ziels (Zeile 975); die Erweiterung hat `ReceiptParserService.swift` (Zeile 1014), nicht den Erkenner |
| `RestockUITests/ReceiptShareExtensionTests.swift:~210` | Teilen-Ablauf; Kachel-Tipp auf Koordinate umgestellt (Kachel war „not hittable“) |
| `scripts/run-share-extension-uitest.sh` | Nachweislauf; meldet nur „Nutzlast ja/nein“, zählt keine Positionen |
| `RestockTests/ReceiptTextRecognizerTests.swift` | bestehende Tests der Streifen-Mathematik |

## Existing Patterns
- Ein Erkenner für beide Eingangswege: `ReceiptScannerView` ruft `ReceiptTextRecognizer`; die Erweiterung soll dasselbe tun.
- Dateien werden in der Erweiterung über zusätzliche Sources-Einträge im pbxproj geteilt (so schon bei `ReceiptParserService`).
- Erweiterung läuft ohne KI-Auflösung wegen Speicherlimit (`allowAIResolution: false`, Kommentar in `ShareViewController`).

## Dependencies
- Upstream: Vision, CoreImage (`uprightImage`), `ReceiptParserService.reconstructLines`.
- Downstream: `ReceiptShareHandoff.store(payload)` und der Review-Screen der App lesen `lines`, `rawLines`, `detectedTotal`.

## Existing Specs
- `docs/specs/services/receipt-text-recognizer-tiling.md` (#120/#124): Mathematik der Streifen, AC-1 bis AC-18; Teilen-Weg dort nicht abgedeckt.

## Risks & Considerations
- **Speicherlimit der Erweiterung** (iOS ~120 MB): App-Scanner lag in der Messung bei 134 MB Spitze; der Simulator setzt das Limit nicht durch. Messung nur im Simulator ist für das Limit nicht aussagekräftig → Streifen nacheinander, Streifenbilder sofort freigeben, Spitze messen; Alternative bei Überschreitung: Erweiterung legt nur das Bild ab, die App erkennt beim Öffnen.
- Zwei Erkennungswege waren die Ursache der Lücke → nach der Änderung nur noch einer (alte `recognizeText` entfällt).
- Nachweis auf dem Gerät erst nach Build 11 und Hennings Wort „jetzt ist ein Test möglich“ (Gerätegrenze).
- Prüfskript soll die erkannte Positionszahl und Endsumme ausgeben, damit „Nutzlast ja“ nicht mehr genügt.

## Recherche (2026-10-08)
- Teilen-Erweiterungen haben ein Speicherlimit von ca. 120 MB ([Dealing with memory limits in iOS app extensions](https://cur.at/sykla3a?m=web), [React-Native-Doku App Extensions](https://reactnative.dev/docs/app-extensions)); die Simulator-Messung erzwingt es nicht.
- Vision meldet bei extremen Seitenverhältnissen „Could not determine an appropriate width index for aspect ratio“ ([Apple Developer Forums](https://developer.apple.com/forums/thread/842398), Suchtreffer); Teilen in Streifen ist der übliche Weg, Text an Schnittkanten geht ohne Überlappung verloren — beides deckt der Erkenner aus #124 ab (Überlappung 0,25×Breite).
- Keine Quelle zu Vision-Speicherspitze in Erweiterungen gefunden → nur durch Messung klärbar.

## Analysis

### Type
Bug (Fortsetzung #120): Teilen-Weg erkennt nur 14 statt 19 Positionen (Simulator), auf dem Gerät ~3; Endsumme fehlt.
Hat es bisher funktioniert? Nein, nie — der Teilen-Weg hatte nie Streifen; #124 hat nur den App-Scanner repariert.

### Root Cause (am Simulator reproduziert)
`ShareViewController.recognizeText` (Zeilen 251–270) ist ein zweiter, eigener Vision-Aufruf auf dem Gesamtbild und umgeht `ReceiptTextRecognizer`. Die Datei ist zudem nicht im Ziel der Erweiterung (pbxproj: nur `ReceiptParserService`, Zeile 1014).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `RestockShareExtension/ShareViewController.swift` | MODIFY | `recognizeText` entfällt, Aufruf von `ReceiptTextRecognizer.recognizeBlocks` + `reconstructLines` (ca. −20/+6) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | `ReceiptTextRecognizer.swift` in Sources-Phase der Erweiterung (+2 Zeilen) |
| `scripts/run-share-extension-uitest.sh` | MODIFY | Positionszahl und Endsumme der Nutzlast ausgeben, Mindestzahl prüfen (ca. +20) |
| `RestockUITests/ReceiptShareExtensionTests.swift` | MODIFY | Kachel-Tipp per Koordinate (liegt schon als Änderung vor, ca. +3) |
| `RestockTests/` (neu oder bestehend) | CREATE/MODIFY | Test: Erweiterung und App nutzen denselben Erkenner (Drift-Test über pbxproj-Mitgliedschaft) ca. +40 |

### Scope Assessment
- Files: 5 · Estimated LoC: ca. +90/−25 · Risk Level: MEDIUM (Speicherlimit nur auf dem Gerät prüfbar)

### Technical Approach (Empfehlung)
Weg A: Erweiterung nutzt denselben `ReceiptTextRecognizer`; ein Erkennungsweg statt zwei. Streifen laufen nacheinander (schon so umgesetzt), Streifenbilder werden pro Durchgang freigegeben.
Ohne Modell geht es: reine Vision-Regel, kein Sprachmodell beteiligt.

Alternative B (kippt „Erweiterung erkennt selbst“): Die Erweiterung legt nur das Bild in der App-Gruppe ab, die App erkennt beim Öffnen. Vorteil: kein Speicherrisiko in der Erweiterung, ein einziger Weg. Nachteil: Erfolgsmeldung „N Positionen erkannt“ und Laden-Erkennung in der Erweiterung entfallen, Bild liegt unverschlüsselt in der Gruppe. Wird nur gewählt, wenn Weg A am Gerät das Limit reißt.

### Dependencies
`ReceiptTextRecognizer` braucht nur CoreGraphics/CoreImage/Vision — keine App-Abhängigkeit, daher in der Erweiterung kompilierbar. Downstream (`ReceiptShareHandoff`, Review-Screen) unverändert.

### Open Questions
- [ ] Speicherspitze in der Erweiterung am echten Bon: Simulator-Messung als Näherung; Gerät erst nach Hennings Wort „jetzt ist ein Test möglich“.
- [ ] Entscheidung A/B fällt erst nach dieser Messung (Rückfall B als eigenes Ticket).
