# Context: fix-120-bon-lange-bilder (#120)

## Request Summary
PO 2026-10-07 (#120 „Kassenbon kommt nicht mit Rabatt zurecht“, Screenshot, „Scan erkennt nur drei Artikel“): Ein digitaler Lidl-Plus-Bon (langes Bild, 1206 × 9089 px, unter fast jedem Artikel eine blaue Zeile „Lidl Plus Rabatt −0,08“) wird nur mit 3 Artikeln erkannt. Zweite Priorität nach #121.

## Related Files
| File | Relevanz |
|------|----------|
| `SmartCart/Views/Prices/ReceiptScannerView.swift:678-724` | `process(_:)`: eine `VNRecognizeTextRequest` auf dem ganzen Bild (`.accurate`, de-DE/fr-FR/en-US, ohne Sprachkorrektur), danach `ReceiptParserService.reconstructLines` und `parse` |
| `SmartCart/Services/ReceiptParserService.swift:150,176,214` | `reconstructLines(blocks)`, `parse(rawLines)`, `detectedTotal` — unverändert brauchbar |
| `SmartCart/Services/ReceiptShareHandoff.swift` | Teilen-Erweiterung übergibt das Bild an die App; die Erkennung läuft dann ebenfalls in `ReceiptScannerView.process` (einzige Vision-Stelle neben `RecipeRecognitionService`) |
| `RestockTests/ReceiptParserLidlFullReceiptTests.swift` | bestehender Lidl-Volltext-Test (Parser-Ebene) |

## Recherche (Internet, 2026-10-07)
Keine Fundstelle zu „sehr hohes Bild verliert Text“ oder zu Streifen-Verfahren; verwandt: `minimumTextHeight` (relativ zur Bildhöhe, https://developer.apple.com/documentation/vision/recognizetextrequest), Vision-Warnung „Could not determine an appropriate width index for aspect ratio“ bei ungewöhnlichen Seitenverhältnissen (https://developer.apple.com/forums/thread/691708). **Eigene Messung** statt Vermutung (siehe unten).

## Reproduktion (mit dem Bild aus #120, dieselbe Vision-Anfrage wie die App, auf dem Mac)
Skripte: `docs/artifacts/fix-120-bon-lange-bilder/` (`ocr120.swift` Ganzbild, `ocr120blocks.swift` Blöcke als JSON, `ocr120tiles.swift` Streifen, `parse120-main.swift` Parser-Harness). Das Bild selbst liegt nicht im Repo (persönliche Angaben).
| Weg | Blöcke | Positionen | Endsumme erkannt |
|---|---|---|---|
| Ganzes Bild (heutiger Weg) | 110, fast nur Preise, Namen und alle 22 „Lidl Plus Rabatt“-Zeilen fehlen | 4 (auf dem Gerät: 3) | nein |
| Streifen 2400 px, Überlappung 300 px | 159 (Duplikate der Überlappung entfernt) | 18 | ja, 68,69 € |
| Ganzbild mit `minimumTextHeight` 0,001 / 0,002 / 0,003 | 110 / 110 / 110 | — | — |
| Ganzbild mit Revision 2 | 112 | — | — |
Der Parser kommt mit den Streifen-Zeilen zurecht; Rabattzeilen (negative Preise) werden wie bisher ignoriert.

## Root Cause
Die Apple-Texterkennung verliert bei einem Bild mit extremem Seitenverhältnis (ca. 1 : 7,5) den Großteil des Textes, wenn es in einem Zug erkannt wird (`ReceiptScannerView.swift:703-717`). Kein Parser-Fehler, keine Rabatt-Behandlung. Einstellungen (Mindest-Texthöhe, Revision) ändern nichts.

## Alternativen
- **A (gewählt, gemessen): Streifen.** Hohe Bilder in überlappende Streifen schneiden, je Streifen erkennen, Blöcke mit globalen Koordinaten zusammenführen, Duplikate der Überlappung entfernen. Regelbasiert, kein Modell.
- **B: Bild skalieren/umrechnen** (z. B. Breite verdoppeln): nicht gemessen; Streifen sind der belegte Weg.
- **C: Rabatt je Artikel abziehen** (Nettopreise): **Produktfrage** und eigenes Thema; erkannte Preise sind heute Regalpreise (Summe der 18 Positionen 70,67 € gegenüber Endsumme 68,69 €). Nicht Teil dieser Behebung; PO entscheidet.
- Regel vor Modell: kein Modell beteiligt.

## Analysis

### Type
Bug (Ursache nachgestellt und belegt)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptTextRecognizer.swift` | CREATE | Streifenbildung (reine Funktionen: Streifen aus Bildgröße, globale Boxen, Duplikat-Entfernung) und Erkennung je Streifen; Bilder bis zu einem Seitenverhältnis wie bisher in einem Zug |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `process(_:)` ruft den Erkenner statt der eigenen Vision-Anfrage |
| `RestockTests/ReceiptTextRecognizerTests.swift` | CREATE | Streifen-Mathematik, Zusammenführung, erzeugtes hohes Bon-Bild (RED: ganzes Bild verliert Text) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | zwei neue Dateien registrieren |

### Scope Assessment
- Files: 3 (+ pbxproj); ca. +150/−25 LoC; Risk: MEDIUM (zentrale Bon-Erkennung, aber Bilder normaler Höhe bleiben auf dem alten Weg)

### Technical Approach
Seitenverhältnis (Höhe/Breite) über einer Schwelle (Messung: 2400 px Streifenhöhe bei 1206 px Breite funktionierte; Schwelle und Streifenhöhe als Vielfache der Breite festlegen, z. B. Streifenhöhe ≈ 2 × Breite, Überlappung ≈ 0,25 × Breite) → Streifen. Normale Bon-Fotos (Hochkant, Seitenverhältnis ca. 1,3–2) bleiben im Einzelzug und damit unverändert.

### Open Questions
- [ ] (PO) Rabatt je Artikel abziehen (Nettopreis)? Eigenes Ticket, wenn ja.
- [ ] Reproduktion im Testprojekt: erzeugt ein selbst gezeichnetes hohes Bon-Bild (Monospace-Text) denselben Textverlust wie das Original? Phase 5 prüft; sonst Streifen-Mathematik + Fixture.
