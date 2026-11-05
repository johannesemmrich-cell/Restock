# Context: fix-214-181-legal-pfeil

## Request Summary
Zwei sichtbare Darstellungsfehler vor Release 1.0 in einem Durchgang beheben (PO: Bündel #214 + #181, Folgearbeit nach Zielen bündeln):
- #214: Rechtstexte (Datenschutz, Nutzungsbedingungen, Impressum) laufen ohne Absatz- und Zeilenumbrüche ineinander.
- #181: Rezeptplan zeigt „u{2192}“ statt „→“ im Hinweis „Noch keine Rezepte gespeichert …“.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Settings/LegalView.swift:21-39` | #214: `Text(content)` mit `AttributedString(markdown:, interpretedSyntax: .full)`. `.full` legt Absätze nur als `PresentationIntent`-Attribute ab, ein einzelnes `Text` zeigt sie nicht an, alles steht in einem Block. |
| `SmartCart/Views/Settings/LegalView.swift:51-290` | Rechtstexte als Swift-String-Literale (privacyPolicy, termsOfUse, imprint); Absätze durch Leerzeile getrennt, Zeilen im Absatz durch einfachen Umbruch (Adresse), Trennlinie `---`, Fettdruck `**…**`. |
| `SmartCart/Views/Settings/LegalView.swift:274-290` | `LegalOverviewView`, Einstieg: Einstellungen → „Rechtliches“. |
| `SmartCart/Resources/de.lproj/Localizable.strings:357` | #181: `menuplan.noSavedRecipes` mit `\u{2192}` (Swift-Schreibweise, in .strings ungültig; gültig wäre `\U2192` oder das Zeichen direkt). |
| `SmartCart/Resources/en.lproj/Localizable.strings:357` | dasselbe, englisch. Einzige Treffer von `u{` in beiden Dateien. |
| `SmartCart/Views/Home/MenuPlanView.swift:458` | Verbraucher des Schlüssels, leere Liste „Gespeicherte Rezepte“. |
| `RestockTests/PrivacyManifestTests.swift:31` | liest `LegalView.swift` als Quelltext und prüft Wortlaut (Fotos-/Open-Prices-Absatz, „Oktober 2026“). Die Literale müssen in der Datei bleiben. |
| `RestockTests/LocalizationKeyParityTests.swift` | prüft gleiche Schlüssel und Platzhalter de/en; ein Zeichenfehler in einem Wert fällt dort nicht auf. |
| `docs/appstore/datenschutz.md` | Datenschutzseite; `## Deutsch` wortgleich zu `LegalView.privacyPolicy`, geprüft durch `scripts/test_asc_texts.py`. Text bleibt unverändert, Fix ändert nur die Darstellung. |
| `RestockUITests/RestockUITests.swift:334-372` | Muster für „Zahnrad → Einstellungen“ in UI-Tests (`UITestLaunch.start`, `attachScreenshot`). |

## Existing Patterns
- Rechtstext ist Markdown-Subset in Swift-Literalen; Darstellung nur über `LegalView`.
- Kein bestehender UI-Test für `LegalView` und keiner für den Rezeptplan-Hinweis. Neue UI-Tests brauchen `UITestLaunch.start` mit Gegenprobe und Wartehelfer aus `UITestWait.swift`; Klassen ohne Eintrag landen in CI-Hälfte B (Hälfte B liegt bei ~59 min, Issue #219), daher besser in eine bestehende leichte Klasse oder in `HEAVY_CLASSES` prüfen.
- Lokalisierte Werte stehen als Klartext in .strings, Sonderzeichen entweder direkt (UTF-8) oder `\UXXXX`.

## Dependencies
- Upstream: SwiftUI `Text`, `AttributedString(markdown:)`; `String(localized:)`.
- Downstream: `LegalView` wird nur von `LegalOverviewView` benutzt; `menuplan.noSavedRecipes` nur von `MenuPlanView`. Kein Schema, keine Launch-Argumente, keine neuen Dateien in `project.pbxproj` nötig, wenn Tests in bestehende Dateien kommen.

## Existing Specs
- Keine Spec zu `LegalView`. Verwandt: `docs/specs/appstore/app-store-auftritt.md` (Gleichlauf Datenschutztext/Seite).

## Ursachenhypothese (noch NICHT nachgestellt, Phase 2)
- #214: `.full` verliert die Absatzgrenzen im flachen `Text`. Mögliche Wege: Absätze selbst teilen und je ein `Text` (Option `inlineOnlyPreservingWhitespace`) in `VStack`; oder `.full` mit `PresentationIntent`-Auswertung. Alternative ohne Parser: Absätze nach `\n\n` trennen, `---` als `Divider`.
- #181: `\u{2192}` durch das Zeichen „→“ direkt ersetzen (beide Sprachen).
- Belege vorhanden: Screenshot `docs/artifacts/feat-175-app-store-auftritt/a2-datenschutz-de.png` (#214), `docs/artifacts/test-145-d4-kauf-wiederherstellen/chip-nachher-rezeptplan-hell.png` (#181).

## Risks & Considerations
- Darstellung der Fettüberschriften und Adresszeilen (einfacher Umbruch innerhalb eines Absatzes) darf nicht verloren gehen; Dynamic Type bis AX-Größen bleibt lesbar (kein fester Zeilenumbruch).
- Textinhalt unverändert lassen (Drift-Tests `PrivacyManifestTests`, `test_asc_texts.py`).
- Nachstellen auf demselben Weg wie Henning (Simulator, Einstellungen → Rechtliches), erst dann ändern.
- Scoping: erwartet 4 Dateien, ~40 LoC, innerhalb der Limits.
- Offene Grenze beachten: Nutzungsbedingungen und Impressum sind vermutlich genauso betroffen; Fix und Test sollten alle drei Dokumente abdecken.

## Analysis

### Type
Bug (zwei Darstellungsfehler, ein Bündel nach gemeinsamem Ziel „Release 1.0 sichtbar sauber“).

### Recherche (vor allem anderen)
- Apple-Forum „New lines not being rendered in SwiftUI's markdown“ (developer.apple.com/forums/thread/682957) und MacRumors-Thread 2367417: `AttributedString(markdown:)` mit `.full` parst Absätze korrekt, legt sie aber nur als `PresentationIntent` ab; ein einzelnes `Text` zeigt sie nicht. `.inlineOnlyPreservingWhitespace` erhält Umbrüche, verwirft aber Blockstruktur. Gängiger Ausweg: Absätze selbst teilen, je ein `Text`. Quellen sind Community-Berichte ab iOS 15; Gegenprobe auf iOS 26/27 erfolgt über den UI-Test (RED).
- Belegbild #214 (Hennings Weg, Einstellungen → Rechtliches): `a2-datenschutz-de.png` zeigt „…2026———1. Verantwortlicher Johannes Emmrich Eichenaue 14, …“ — Absätze, Adresszeilen und `---` verschmelzen.

### Ursache (Code belegt, Nachstellen folgt als RED-Test)
- #214: `LegalView.swift:36-39` rendert ein einziges `Text(AttributedString(markdown:, .full))`. Absatzgrenzen sind nur Attribute, `---` wird zu „———“ (ThematicBreak ohne Blockdarstellung), Listen „- …“ (20 Zeilen in Nutzungsbedingungen/Datenschutz) werden ohne Aufzählung ineinandergeschoben. Betrifft alle drei Dokumente (23 Trennlinien `---`).
- #181: `Localizable.strings` (de und en, Zeile 357) enthält `\u{2192}` (Swift-Schreibweise); .strings kennt nur `\UXXXX`, daher Ausgabe „u{2192}“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Settings/LegalView.swift` | MODIFY | Inhalt in Blöcke zerlegen (reine Funktion): Absatz, Trennlinie → `Divider`, Aufzählung → Zeile mit „•“; je Block ein `Text` mit `inlineOnlyPreservingWhitespace` (Fett bleibt, Adresszeilen behalten Umbruch) in `VStack` |
| `SmartCart/Resources/de.lproj/Localizable.strings` | MODIFY | Zeile 357: „→“ direkt |
| `SmartCart/Resources/en.lproj/Localizable.strings` | MODIFY | dasselbe |
| `RestockTests/LegalTextBlocksTests.swift` (oder bestehende Datei, Registrierung in pbxproj) | CREATE | Unit: Zerlegung (Absatz/Trennlinie/Liste/Umbruch), alle drei Texte ohne Rest-`---`; Strings ohne `\u{` |
| `RestockUITests/…` (bestehende leichte Klasse) | MODIFY | UI-Test: Einstellungen → Rechtliches → je Dokument: Absätze als getrennte Elemente vorhanden, „1. Verantwortlicher“ nicht im selben Element wie „Stand: Oktober 2026“; Rezeptplan-Hinweis enthält „→“ und nicht „u{2192}“ |

### Scope Assessment
- Files: 4–5 (eine neue Testdatei, plus UI-Test in bestehender Klasse)
- Estimated LoC: ca. +110/−10 (Produkt ~45, Tests ~65) — innerhalb der Limits
- Risk Level: LOW (Text bleibt wortgleich; Drift-Tests `PrivacyManifestTests` und `test_asc_texts.py` lesen die Literale, bleiben unberührt)

### Technical Approach (Empfehlung)
Regel statt Parser: Quelltext nach Leerzeilen in Absätze teilen, `---` → Trennlinie, Zeilen mit „- “ → Aufzählung, Rest → Text. Kein neuer Markdown-Renderer, keine Dependency.
Alternative A: `.full` beibehalten und `PresentationIntent` selbst auswerten (mehr Code, fehleranfälliger). Alternative B: Texte als `LocalizedStringKey`/Markdown-Ressource auslagern (kippt die Gleichlauf-Prüfung gegen `docs/appstore/datenschutz.md`; zu groß für dieses Ticket).
Für #181: Zeichen „→“ direkt in UTF-8 setzen (Alternative `\U2192` ist unleserlicher); zusätzlich Unit-Test, der alle .strings auf `\u{` prüft, damit der Fehler nicht wiederkehrt.

### Befunde gegen den Plan
Keine bekannten. Ungeprüft: Verhalten auf iOS 26/27 (Quellen aus iOS 15); der RED-Test zeigt es. Dynamic Type bleibt, da keine festen Umbrüche.

### Dependencies
`LegalView` nur von `LegalOverviewView` benutzt; `menuplan.noSavedRecipes` nur von `MenuPlanView:458`.

### Open Questions
- [ ] UI-Test-Klasse: in bestehende leichte Klasse (nicht CI-Hälfte B, ~59 min, #219) oder `HEAVY_CLASSES` — in der Spec festlegen.
- [ ] Entwurfsvorschau: Die Zerlegung stellt die im Text angelegte Struktur her (Absatzabstand, Trennlinie, Aufzählungspunkte), kein neues Design. Falls Henning dennoch eine Vorschau will, vor `/30-write-spec` nachreichen.
