---
entity_id: legal-text-darstellung
type: bugfix
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: fix-214-181-legal-pfeil
tags: [legalview, datenschutz, markdown, localization, strings, release-1-0, issue-214, issue-181]
---

# Rechtstexte mit Absätzen darstellen und kaputten Pfeil im Rezeptplan beheben (Issues #214, #181)

## Approval

- [ ] Spec-Freigabe durch den PO (steht aus)

## Purpose

Zwei sichtbare Darstellungsfehler vor Release 1.0, in einem Durchgang behoben (gemeinsames Ziel „Release 1.0 sichtbar sauber“, Bündel nach PO-Regel vom 2026-10-02).

**#214, Rechtstexte laufen ineinander.** Einstellungen → Rechtliches → Datenschutzerklärung, Nutzungsbedingungen und Impressum zeigen den Text ohne Absätze, Adresszeilen und Aufzählungen; die Trennlinien `---` erscheinen als „———“. Beleg: `docs/artifacts/feat-175-app-store-auftritt/a2-datenschutz-de.png` („…2026———1. Verantwortlicher Johannes Emmrich Eichenaue 14, …“). Ursache (Code gelesen, `SmartCart/Views/Settings/LegalView.swift:36-39`): Die Ansicht rendert ein einziges `Text(AttributedString(markdown:, interpretedSyntax: .full))`. `.full` erkennt Absätze, Trennlinien und Listen, legt sie aber nur als `PresentationIntent`-Attribute ab; ein einzelnes `Text` zeigt diese nicht an. Quellen: Apple-Forum „New lines not being rendered in SwiftUI's markdown“ (developer.apple.com/forums/thread/682957) und MacRumors-Thread 2367417; beides Community-Berichte ab iOS 15, die Gegenprobe auf iOS 26/27 liefert der RED-Lauf. Hat es bisher funktioniert? Nein, der Text wurde nie mit Absätzen angezeigt (fehlende Darstellung, keine Verschlechterung).

**#181, „u{2192}“ statt „→“.** Der Hinweis „Noch keine Rezepte gespeichert. Gericht im Wochenplan nach rechts wischen u{2192} „Speichern“.“ im Rezeptplan (`MenuPlanView.swift:458`, Schlüssel `menuplan.noSavedRecipes`) enthält in `SmartCart/Resources/de.lproj/Localizable.strings` und `en.lproj/Localizable.strings`, jeweils Zeile 357, die Swift-Schreibweise `\u{2192}`. In `.strings` ist nur `\UXXXX` gültig, deshalb erscheint „u{2192}“ (Beleg: `docs/artifacts/test-145-d4-kauf-wiederherstellen/chip-nachher-rezeptplan-hell.png`). Das sind die einzigen Treffer von `u{` in beiden Dateien.

Entwurfsvorschau (PO wollte sie sehen, 2026-11-05): `docs/artifacts/fix-214-181-legal-pfeil/entwurf-legal-darstellung.html` (Quelle `…src.html`), Heute gegen Entwurf A (hell, dunkel) und Alternative B (Karte je Abschnitt, nicht empfohlen). Gewählt ist Entwurf A, vorbehaltlich der Antwort des PO auf die Vorschau; weicht seine Wahl ab, wird die Spec vor der Freigabe angepasst.

## Scope

| Datei | Änderung | LoC (ca.) |
|-------|----------|-----------|
| `SmartCart/Views/Settings/LegalView.swift` | `enum LegalTextBlocks` (reine Zerlegung + Fließtext-Funktion), Darstellung als `VStack` aus je einem `Text`/`Divider` je Block; die drei Texte von `private let` (Instanz) zu `static let` im selben Typ, Zuordnung `markdownContent` zu `static func text(for:)`, Wortlaut und Literale unverändert | +50/−8 |
| `SmartCart/Resources/de.lproj/Localizable.strings` | Zeile 357: `\u{2192}` → Zeichen „→“ (UTF-8) | +1/−1 |
| `SmartCart/Resources/en.lproj/Localizable.strings` | Zeile 357: dasselbe | +1/−1 |
| `RestockTests/PrivacyManifestTests.swift` | bestehende Datei (liest `LegalView.swift` schon): Tests für Zerlegung, drei Dokumente, Fett, `.strings`-Prüfung | +85 |
| `RestockUITests/DynamicTypeUITests.swift` | zwei UI-Tests (Rechtstexte, Rezeptplan-Hinweis) | +60 |

Fünf Dateien, keine neue Datei und damit keine Änderung an `project.pbxproj` (Limit 4–5 Dateien eingehalten); geschätzt +200/−10, Produktcode ca. +52/−10 (±250 LoC eingehalten). Neue Artefakte (keine Produktdateien) unter `docs/artifacts/fix-214-181-legal-pfeil/`: `benutzen-befund.md` und die Aufnahmen aus den Testanhängen. Wird beim Umsetzen sichtbar, dass die Tests deutlich über die Schätzung wachsen, hält der Entwickler an und meldet die Zahl, bevor er weiterschreibt.

**Side-Effects (explizit):** Kein CloudKit-Schema, keine neuen Berechtigungen (Info.plist unverändert), keine `@AppStorage`-/UserDefaults-Schlüssel, keine Audio-Dateien, keine Launch-Argumente neu, kein Seed, keine Änderung an `ci.yml`, `project.pbxproj`, `docs/appstore/datenschutz.md`, `PrivacyInfo.xcprivacy`, Lokalisierungsschlüsseln (Schlüsselmenge und Platzhalter in de/en unverändert, `LocalizationKeyParityTests` bleibt grün). Nur Darstellung und ein Sonderzeichen in zwei Zeichenketten ändern sich.

## Verhalten

### Zerlegung (reine Funktion, keine Parser-Bibliothek)

`enum LegalTextBlocks` in `LegalView.swift` (Namespace ohne Zustand):

```
enum Block: Equatable { case paragraph(String), bullet(String), divider }
static func blocks(from markdown: String) -> [Block]
static func attributed(_ text: String) -> AttributedString
```

Regeln für `blocks(from:)`, angewendet auf den Quelltext (Zeilenumbruch `\n`):

1. Der Text wird an Leerzeilen (eine oder mehrere Zeilen, die nur Leerraum enthalten) in Stücke geteilt; leere Stücke entfallen.
2. Ein Stück, dessen einzige Zeile (nach Entfernen von Leerraum an den Rändern) `---` lautet, ist `.divider`.
3. Alle übrigen Stücke werden zeilenweise gelesen. Aufeinanderfolgende Zeilen ohne Präfix „- “ bilden einen `.paragraph` (Zeilen mit `\n` verbunden, Randleerraum entfernt); jede Zeile, die mit `- ` beginnt, ergibt für sich ein `.bullet(Text ohne „- “)`. Die Reihenfolge bleibt erhalten. Reine Absätze, reine Listen und der gemischte Fall (Einleitungszeile, direkt darunter Listenzeilen ohne Leerzeile) laufen so über denselben Weg. Der gemischte Fall kommt vor: „Du hast das Recht auf:“ + 6 Punkte (Datenschutz, Abschnitt 5), „Restock bietet … Funktionen:“ + 6 Punkte und „Die App wird … Für folgende Punkte …:“ + 3 Punkte (Nutzungsbedingungen).
4. Einfache Zeilenumbrüche innerhalb eines Absatzes bleiben erhalten (Adresse „Johannes Emmrich⏎Eichenaue 14, …⏎E-Mail: …“; Titelzeile + „Stand: Oktober 2026“). Eine Zeile, die mit „-“ ohne folgendes Leerzeichen beginnt (z. B. „-5 %“), ist Absatztext, kein Punkt.

`attributed(_:)` liefert `try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))`, bei Fehler `AttributedString(text)`. Fettdruck `**…**` bleibt, Umbrüche im Absatz bleiben.

### Darstellung

`LegalView.body`: `ScrollView { VStack(alignment: .leading, spacing: 12) { ForEach(blocks) { … } }.padding(20) }`. Je Block:

- `.paragraph`: ein `Text(attributed(…))`, `.font(.system(size: 14))`, `.foregroundStyle(.primary)`, links ausgerichtet, ohne feste Höhe, ohne `lineLimit`.
- `.bullet`: `HStack(alignment: .firstTextBaseline, spacing: 8)` aus `Text("•")` und dem Text des Punktes (gleiche Schrift wie Absatz). Der Punkt ist Teil derselben Zeile, keine Einrückung mit festen Breiten.
- `.divider`: `Divider()`.

Schrift, Farben, Hintergrund (`Color.canvas`), Titel und Navigationsleiste bleiben unverändert. Dynamic Type bleibt erhalten (die Schrift ist wie bisher `.system(size: 14)`, keine festen Umbrüche, keine festen Breiten). Der `VStack` ist eager (kein `LazyVStack`), damit alle Absätze im Bedienhilfen-Baum stehen (Voraussetzung für den UI-Test ohne Scrollen). Die Blocklisten werden je Dokument einmal berechnet (`static let` je Dokument oder `let` im `init`), nicht in jedem `body`-Durchlauf.

Die Texte `privacyPolicy`, `termsOfUse`, `imprint` bleiben als Swift-String-Literale in `LegalView.swift` (Drift-Tests `RestockTests/PrivacyManifestTests` lesen die Quelldatei, `scripts/test_asc_texts.py` vergleicht `## Deutsch` in `docs/appstore/datenschutz.md` wortgleich damit). Sie werden nur von `private let` (Instanz) zu `static let` im selben Typ `LegalView` (Zugriff `internal`), damit die Unit-Tests sie lesen können; kein Zeichen im Literal ändert sich. Die Zuordnung Dokument → Text (heute `private var markdownContent`) wird zu `static func text(for: LegalDocument) -> String` (Zugriff `internal`), die Ansicht ruft sie auf; die Tests gehen über `LegalDocument.allCases` und `LegalView.text(for:)`, bilden die Zuordnung also nicht nach.

### #181

In beiden `Localizable.strings` Zeile 357 wird `\u{2192}` durch das Zeichen „→“ (U+2192, UTF-8) ersetzt, sonst nichts. Ein Unit-Test sorgt dafür, dass die Swift-Schreibweise in `.strings` nicht wiederkehrt.

## Acceptance Criteria

- AC-1: `LegalTextBlocks.blocks(from: "A\n\nB")` liefert `[.paragraph("A"), .paragraph("B")]`; mehrere Leerzeilen oder Leerzeilen mit Leerzeichen dazwischen ergeben dasselbe Ergebnis, führende und abschließende Leerzeilen erzeugen keinen leeren Block.
- AC-2: `blocks(from: "Johannes Emmrich\nEichenaue 14\nE-Mail: x")` liefert genau einen `.paragraph("Johannes Emmrich\nEichenaue 14\nE-Mail: x")` (einfache Umbrüche im Absatz bleiben).
- AC-3: `blocks(from: "A\n\n---\n\nB")` liefert `[.paragraph("A"), .divider, .paragraph("B")]`; im Ergebnis steht kein Block, dessen Text `---` enthält.
- AC-4: `blocks(from: "- **X** a\n- Y b")` liefert `[.bullet("**X** a"), .bullet("Y b")]` (ohne Präfix „- “); `blocks(from: "Einleitung:\n- A\n- B")` liefert `[.paragraph("Einleitung:"), .bullet("A"), .bullet("B")]` (gemischter Fall); ein Absatz, der mit „-“ ohne folgendes Leerzeichen beginnt (z. B. „-5 %“), bleibt `.paragraph`.
- AC-5: Für alle drei Dokumente (`LegalView.privacyPolicy`, `.termsOfUse`, `.imprint`) gilt: (a) kein `.paragraph` und kein `.bullet` enthält `---`, (b) keine Zeile eines `.paragraph` beginnt mit „- “, (c) die Anzahl der `.divider` ist gleich der Anzahl der Quelltext-Zeilen, die nur aus `---` bestehen, und größer als 0, (d) in Datenschutz und Nutzungsbedingungen zusammen genau 18 `.bullet` (6 + 6 + 3 + 3; die Zahl ist beim Umsetzen gegen den Quelltext zu prüfen und bei Abweichung samt Grund hier zu korrigieren), (e) kein Block ist leer.
- AC-6: Verlustfreiheit: Für alle drei Dokumente ergibt das Aneinanderfügen aller Blocktexte (Absatz- und Punkttexte), ohne jeglichen Leerraum, dieselbe Zeichenfolge wie der Quelltext ohne Leerraum, ohne die Zeilen `---` und ohne die Präfixe „- “ der Listenzeilen. Der Anzeigetext verliert oder ergänzt also kein Zeichen.
- AC-7: `LegalTextBlocks.attributed("**Datenschutzerklärung**\nStand: Oktober 2026")` hat als Zeichenfolge genau „Datenschutzerklärung\nStand: Oktober 2026“ (kein `**`), und der Teil „Datenschutzerklärung“ trägt `inlinePresentationIntent` mit `.stronglyEmphasized`, „Stand: Oktober 2026“ nicht.
- AC-8: Die Literale stehen unverändert in `SmartCart/Views/Settings/LegalView.swift`: `RestockTests/PrivacyManifestTests` (bestehende Tests, unverändert) und `scripts/test_asc_texts.py` bleiben grün; der Diff der Datei enthält keine geänderte Zeile innerhalb der drei Literale außer den Schlüsselwörtern `private let` → `static let` in den drei Deklarationszeilen; zusätzlich ändert sich nur die Zuordnung `markdownContent` → `static func text(for:)`.
- AC-9: Alle `*.strings`-Dateien unter dem Repo-Stamm (ohne `.git/` und `build/`; mindestens `SmartCart/Resources/{de,en}.lproj/{Localizable,InfoPlist}.strings`, also mindestens 4 Dateien) enthalten die Zeichenfolge `\u{` nicht. Gegenprobe im selben Test: Die Prüffunktion liefert für den Text `"k" = "a \u{2192} b";` einen Treffer. Der Test findet vor dem Fix `menuplan.noSavedRecipes` in beiden Dateien (RED) und ist danach grün.
- AC-10: Die gelesenen (per `PropertyListSerialization` geparsten) Werte von `menuplan.noSavedRecipes` in `de.lproj` und `en.lproj` enthalten „→“ (U+2192) und nicht die Zeichenfolge „u{2192}“; sonst bleibt der Wortlaut unverändert. Soll de: `Noch keine Rezepte gespeichert. Gericht im Wochenplan nach rechts wischen → "Speichern".` (gerade ASCII-Anführungszeichen, in der Datei maskiert als `\"`); en: der bestehende englische Wert mit `→` anstelle von `\u{2192}`. Der Test vergleicht gegen den bisherigen Dateiwert mit ersetztem Pfeil, nicht gegen eine zweite Abschrift.
- AC-11: UI-Test Rechtstexte (`DynamicTypeUITests`, Schriftgröße AccessibilityXXXL wie in der Klasse, `-hasCompletedOnboarding YES`): Einstellungen → „Rechtliches“ → „Datenschutzerklärung“: Es gibt ein Textelement mit Label genau „1. Verantwortlicher“; kein Textelement der Ansicht enthält zugleich „Stand: Oktober 2026“ und „1. Verantwortlicher“; kein Textelement enthält „———“ oder „---“; es gibt ein Textelement, dessen Label mit „Johannes Emmrich“ beginnt und „Eichenaue 14“ enthält (Adresse bleibt ein Absatz mit Umbruch) aber nicht „2. Welche Daten“ enthält.
- AC-12: Derselbe UI-Test prüft „Nutzungsbedingungen“ (Textelement mit Label genau „1. Geltungsbereich“, keines mit „———“) und „Impressum“ (Textelement mit Label genau „Anbieter“, kein Textelement enthält zugleich „Anbieter“ und „Urheberrecht“, keines mit „———“); jede Ansicht wird erst über die Zurück-Taste verlassen, bevor die nächste geöffnet wird.
- AC-13: UI-Test Rezeptplan-Hinweis: Mit `-hasCompletedOnboarding YES -developerMode NO -premiumForScreenshots -clearMenuPlanForUITests` über den Knopf `fork.knife` der Startseite im Rezeptplan existiert nach dem Scrollen (`scrollUntilHittable` der Klasse) ein Textelement mit Label beginnend „Noch keine Rezepte gespeichert“, das „→“ enthält und „u{2192}“ nicht enthält. Ist der Hinweis auch nach dem Scrollen nicht da, schlägt der Test mit der Meldung „Hinweis fehlt (gespeicherte Rezepte im Simulator vorhanden?)“ fehl, überspringt sich aber nicht.
- AC-14: Dynamic Type bleibt: Im UI-Test aus AC-11 liegt bei AccessibilityXXXL jedes der geprüften Absatz-Textelemente waagerecht im Fenster (Rahmen innerhalb `app.windows.firstMatch.frame`, 1 pt Toleranz), also nichts nach rechts abgeschnitten.
- AC-15: Ausführung und Nachweis: Die UI-Tests laufen im Klassenlauf `-only-testing:RestockUITests/DynamicTypeUITests` auf dem Projekt-Testsimulator (Testzahl 4, 0 Fehlschläge, kein Null-Test-Lauf), die Unit-Tests im Lauf `-only-testing:RestockTests/PrivacyManifestTests` (die bestehenden Tests plus mindestens 8 neue, 0 Fehlschläge); `LocalizationKeyParityTests` und `python3 scripts/test_asc_texts.py` bleiben grün.
- AC-16: Benutzen statt nur testen (Regel 2026-09-27): Vor der Übergabe werden Datenschutzerklärung, Nutzungsbedingungen und Impressum sowie der Rezeptplan-Hinweis im Simulator geöffnet, hell und dunkel aufgenommen und die Aufnahmen angesehen; je Aufnahme steht in `docs/artifacts/fix-214-181-legal-pfeil/benutzen-befund.md` „Absätze sichtbar“, „Trennlinie statt ———“, „Aufzählungspunkte“ bzw. „Pfeil sichtbar“, mit Commit-Kennung, Zeit und Gerät im Kopf. Die Aufnahmen entstehen aus einem echten Lauf (Anhang `XCTAttachment` des UI-Tests), nie von Hand gesetzt.
- AC-17: Scope: Der Diff gegen `origin/main` enthält an Produkt- und Testdateien nur die fünf Dateien aus der Scope-Tabelle (zusätzlich Dateien unter `docs/` und Workflow-Zustand unter `.claude/`), und keine Änderung an `ci.yml`, `project.pbxproj`, `docs/appstore/`, `Info.plist`/`InfoPlist.strings`, `PrivacyInfo.xcprivacy` oder `docs/cloudkit/`.

## Tests

**Unit-Tests** (`RestockTests/PrivacyManifestTests.swift`, bestehende, im Test-Ziel registrierte Datei; sie liest `LegalView.swift` schon und prüft den Rechtstext. Entscheidung: keine neue Datei, damit das Datei-Limit hält und `project.pbxproj` unberührt bleibt; Zugriff auf `LegalTextBlocks` und die `static let`-Texte per `@testable import Restock`, falls dort noch nicht vorhanden):

- `testParagraphsSplitOnBlankLines` (AC-1), `testLineBreakInsideParagraphIsKept` (AC-2), `testDividerBecomesDividerBlock` (AC-3), `testBulletLinesBecomeBullets` (AC-4, inkl. gemischtem Fall und „-5 %“).
- `testAllThreeDocumentsHaveNoRawMarkdownLeft` (AC-5, Schleife über `LegalDocument.allCases` mit Zugriff auf die `static let`-Texte; Zählung der Quelltext-Trennzeilen im Test selbst).
- `testBlocksLoseNoCharacter` (AC-6), `testBoldSurvivesInlineParsing` (AC-7, Auswertung über `runs` und `inlinePresentationIntent`).
- `testStringsFilesContainNoSwiftEscapes` (AC-9, sucht Dateien ab dem Repo-Stamm über `#filePath`, schließt `.git`, `build` aus, Gegenprobe mit Beispieltext), `testNoSavedRecipesHintContainsArrow` (AC-10, liest beide `Localizable.strings` als Property List).

**RED/GREEN-Erwartung:** Vor der Umsetzung kompilieren die Unit-Tests nicht (`LegalTextBlocks` fehlt) bzw., nach einem leeren Gerüst, schlagen AC-9/AC-10 an den beiden Zeilen 357 fehl und AC-1 bis AC-7 an der fehlenden Zerlegung. Die UI-Tests AC-11/AC-12 sind RED, weil der gesamte Text heute ein einziges Textelement ist („1. Verantwortlicher“ nicht als eigenes Element, Label enthält „———“); AC-13 ist RED, weil das Label „u{2192}“ trägt. Nach der Umsetzung sind alle GREEN. Das ist zugleich der Nachstellweg auf Hennings Pfad (Einstellungen → Rechtliches im Simulator); der RED-Lauf belegt außerdem, ob die Community-Aussage zu `.full` auf iOS 26/27 stimmt, bevor etwas geändert wird.

**UI-Tests** (`RestockUITests/DynamicTypeUITests.swift`, bestehende Klasse, erweitert):

- `testLegalTextsRenderParagraphsAtLargestAccessibilitySize` (AC-11, AC-12, AC-14): Start über `UITestLaunch.start(app, expecting: app.buttons["gearshape"], …)` mit Gegenprobe, Argumente `DynamicTypeUITests.launchArguments + ["-hasCompletedOnboarding", "YES"]`, `openSettings(app)` (vorhandene Hilfe), `scrollUntilHittable` auf die Zeile „Rechtliches“, Tippen, je Dokument tippen, Textelemente über `app.staticTexts` mit Prädikaten auf das Label lesen (Wartehelfer `waitForExistence(timeout: UITestWait.defaultTimeout)`, Antippbarkeit der Zeilen über `waitUntilHittable()`), `XCTAttachment`-Screenshot je Dokument (`lifetime = .keepAlways`) als Beleg für AC-16, Zurück über die Navigationsleiste.
- `testRecipePlanHintShowsArrowAtLargestAccessibilitySize` (AC-13): Start mit Klassenargumenten plus `-hasCompletedOnboarding YES -developerMode NO -premiumForScreenshots -clearMenuPlanForUITests`, Tipp auf `fork.knife` (`waitUntilHittable()`), `scrollUntilHittable` auf den Hinweis, Prüfung des Labels, Screenshot-Anhang.
- Keine Seeds; die Klasse räumt wie bisher in `tearDown()` mit ihrem Aufräumlauf auf. Der Test setzt nur Argumente der Argument-Domain und benutzt kein `-developerMode YES` (Argument-Domain-Falle).

**CI-Hälfte (offene Frage der Analyse, hier entschieden):** Die Tests kommen in die bestehende Klasse `DynamicTypeUITests`, nicht in eine neue Klasse und nicht in `PaywallUITests`. Begründung: Eine neue Klasse ohne Eintrag in `ci.yml` landet automatisch in Hälfte B, die laut Issue #219 bei rund 59 von 60 Minuten liegt; `PaywallUITests` liegt selbst in B. `DynamicTypeUITests` steht in `HEAVY_CLASSES` und läuft damit in Hälfte A (die aktuelle Laufzeit von A ist hier nicht belegt und wird beim ersten CI-Lauf abgelesen); zwei Tests ohne Seed kosten dort etwa 1 bis 2 Minuten (Start, Zurück, Aufnahmen) und erfordern keine Änderung an `ci.yml`. Thematisch passt es: Die Klasse prüft „Bildschirme in größter Schrift sind vollständig lesbar“; AC-14 ist genau diese Aussage für die Rechtstexte. Alternative: neue Klasse `LegalTextUITests` in `EXTRA_CLASSES` (Hälfte D, leichter), kostet eine Zeile `ci.yml` und ist mit dem Scope-Satz „`ci.yml` unberührt“ (AC-17) nicht vereinbar; wird gewählt, falls Hälfte A beim ersten CI-Lauf über 55 Minuten liegt.

## Alternativen (gekippte Entscheidung)

- **A: `.full` beibehalten und `PresentationIntent` selbst auswerten.** Würde Absätze, Listen und Trennlinien aus den Attributen eines einzigen `AttributedString` zurückbauen. Mehr Code, fehleranfälliger bei Randfällen (verschachtelte Intents, Zeilenumbrüche), und der Text ist ohnehin ein kleines, fest bekanntes Subset. Gekippt zugunsten der Regel statt eines Markdown-Interpreters (PO-Regel „Regeln vor Modell/Parser“).
- **B: Texte als Ressource (Markdown-Datei oder `LocalizedStringKey`) auslagern.** Kippt die Gleichlaufprüfung gegen `docs/appstore/datenschutz.md` (`scripts/test_asc_texts.py`, `PrivacyManifestTests` lesen die Literale) und ist für dieses Ticket zu groß. Gekippt; wäre sinnvoll, wenn die Texte einmal englisch werden.
- **C: ein SwiftUI-`Text` je Zeile.** Verliert die Absatzbildung (Umbruch innerhalb von Absätzen wie der Adresse ist gewollt, Umbruch durch Textbreite nicht) und vervielfacht die Elemente im Bedienhilfen-Baum. Gekippt.
- Kein Modell nötig: reine Regel über Leerzeilen und Zeilenanfänge; die einfachste Lösung ist die Regel.

## Offene Grenzen

- Das Verhalten von `.inlineOnlyPreservingWhitespace` auf iOS 26/27 ist nur durch Community-Berichte ab iOS 15 gestützt; belegt wird es erst durch den RED/GREEN-Lauf dieses Tickets (Umbrüche im Absatz, Fettdruck).
- Die Aufzählung ist ein einfacher „•“ mit festem Abstand von 8 pt vor dem Text; Einrückung bei sehr großer Schrift und das Vorlesen durch VoiceOver (liest „•“ als „Aufzählungspunkt“ oder gar nicht) sind nicht gemessen.
- Listenzeilen mit Fettdruck am Anfang („**Auskunft** über …“) werden in `attributed` korrekt als Fett im Punkt gesetzt, aber nur AC-7 (Absatz) prüft Fett im Anzeigetext.
- Die Zerlegung versteht nur das in den drei Texten benutzte Subset: Absätze, `---`, „- “-Listen, Fett. Überschriften mit `#`, Tabellen, verschachtelte Listen oder Links in Markdown werden nicht besonders behandelt; wer solche Syntax ergänzt, ändert Regel und Test mit.
- Der Rechtstext ist nur deutsch (Bestand, außerhalb des Tickets); die englische Übersetzung steht nur auf der Datenschutzseite `docs/appstore/datenschutz.md`.
- AC-13 setzt voraus, dass im Simulator keine gespeicherten Rezepte liegen (Abschnitt „Gespeicherte Rezepte“ ist sonst die Liste statt des Hinweises); ohne Seed wird das nicht hergestellt, sondern bei Abweichung gemeldet. Auf einem frischen CI-Simulator ist die Liste leer.
- Der Ersatz `→` in `.strings` ist geprüft gegen die geparsten Werte (Property List) und im Rezeptplan-UI, nicht gegen jede weitere Sprachdatei: Es gibt nur de und en; andere `\u{`-Vorkommen in künftigen `.strings` fängt AC-9.
- Die Aussage „Hälfte A bleibt unter 60 Minuten“ ist nicht gemessen; der erste CI-Lauf belegt sie. Liegt A danach über 55 Minuten, wandern die Tests in eine neue Klasse in `EXTRA_CLASSES` (Änderung an `ci.yml`, eigener Durchgang).
- Nichts auf Hennings Geräten geprüft.

## Changelog

- 2026-11-05: Erstfassung (Bündel #214 + #181, Regel statt Parser, UI-Tests in `DynamicTypeUITests`, kein Eingriff in `ci.yml`).
- 2026-11-05: Nach Validierung: gemischte Fälle (Einleitung + Listenzeilen) werden zerlegt statt Rückfall (kommen dreimal im Quelltext vor), 6 statt „fünf“ Rechte, Unit-Tests in bestehende `PrivacyManifestTests` (5 statt 6 Dateien), AC-10 mit ASCII-Anführungszeichen, Laufzeitzahl für Hälfte A entfernt.
- 2026-11-05: Entwurfsvorschau erstellt (PO-Wunsch), Hinweis in Purpose statt „nicht nötig“.
- 2026-11-05: Zugriff der Tests auf die Zuordnung Dokument → Text festgelegt (`static func text(for:)`).
