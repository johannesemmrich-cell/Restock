# Adversary-Dialog — Bon-Prüf-Screen als Karte mit Auswahl (#23)

Workflow: `feat-23-receipt-review-screen` · Spec: `docs/specs/views/receipt-review-card.md`
Prüfer: `implementation-validator` (liest ausschließlich die Spec und die Tests, nie den Produktcode)
Datum: 2026-09-22 bis 2026-09-23

Der Prüfer hat in jeder Runde eigene Testläufe gefahren, statt die vorgelegten Nachweise zu übernehmen.
Simulator ausschließlich `8F696920-4B9A-40A7-96F0-7697BE887CC7`, nie zwei Läufe parallel,
in keinem Lauf `-retry-tests-on-failure` oder `-test-iterations`.

---

### Runde 1 — Nachweise gegen die Checkliste

Der Prüfer hat die 18 Punkte der Checkliste (6 Expected Behavior, 12 Acceptance Criteria) gegen den
Testcode abgeglichen und den RED-Stand als Fälschungssicherheit herangezogen: `test-red-ui-output.txt`
zeigt vor der Umsetzung 11 von 12 Fehlschlägen, die Unit-Übersetzung scheiterte an nicht existierenden
Symbolen. Damit ist belegt, dass die Tests echte Regeln prüfen und nicht tautologisch grün sind.

Eigener Lauf Runde 1: 18/18 Unit-Tests, 0 Fehler — deckungsgleich mit dem vorgelegten Nachweis.

Ergebnis: AC-1, AC-2, AC-3, AC-5, AC-6, AC-8, AC-9, AC-11 und AC-12 bewiesen.
Offen gelassen und in Runde 2 vertieft: AC-4, AC-7, AC-10 sowie die Expected-Behavior-Punkte 3, 5 und 6 —
mit der Begründung, dass genau dort die typische Schwachstelle liegt, nämlich Existenz eines Elements
statt geprüftem Nutzen.

### Runde 2 — Vertiefung und gezielte Lückensuche

Eigener Lauf Runde 2: 12/12 Bildschirmtests ohne Wiederholungshilfe, 0 Fehler — ein zusätzlicher,
unabhängiger Beweis über den vorgelegten Nachweis hinaus, der mit Wiederholungsflag gelaufen war.

Fünf Funde, Verdict der Runde: AMBIGUOUS.

- F001 (MEDIUM) — AC-4: Die Vorauswahl-Sortierung war nur für den Fall belegt, dass der KI-Vorschlag
  dem aktuellen Namen entspricht. Für den häufigeren Fall „aktueller Name kommt von einem Listen-Treffer,
  keine KI beteiligt" fehlte jeder Beweis, weder als Unit- noch als Bildschirmtest.
- F002 (MEDIUM) — Expected Behavior 3: Der Test prüfte nur den Tastaturfokus. Es wurde nirgends Text
  getippt und belegt, dass jede Eingabe laufend übernommen wird. Der Unit-Test rief die Funktion mit
  fertigem String auf, was das Live-Verhalten nicht belegt.
- F003 (HIGH) — Expected Behavior 6: Der Zustand „alle Positionen abgewählt" wurde von keinem der
  30 neuen und keinem der 178 Bestandstests geprüft. Dass „Speichern" dann gesperrt bleibt, war
  unbelegt.
- F004 (LOW) — AC-10: Nur Zähler und Summe waren geprüft, das visuelle Dimmen der Karte nicht.
- F005 (LOW) — Der vorgelegte Bildschirmtest-Nachweis war mit `-retry-tests-on-failure` entstanden.
  Der eigene Lauf des Prüfers ohne dieses Flag bestand jedoch, was den Fund entkräftete.

### Runde 3 — Nachprüfung der Korrekturen

Alle fünf Funde wurden bearbeitet, dabei wurde ein weiterer, echter Defekt entdeckt. Der Prüfer hat
jede Behauptung selbst am Code und an den Artefakten verifiziert und zwei eigene Läufe gefahren.

Eigene Läufe Runde 3: 19/19 Unit-Tests und 15/15 Bildschirmtests im isolierten Lauf, beide 0 Fehler,
ohne Wiederholungshilfe.

Bewiesene Punkte:

- [x] **AC-1** — Bontext vollständig und unverändert, auch bei der 42-Zeichen-Zeile, kein Abschneiden.
      `RestockUITests/ReceiptReviewUITests.swift:185-197`, zusätzlich im Dunkelmodus.
- [x] **AC-2** — Höchstens vier Auswahlzeilen, Kappung von fünf Vorschlägen auf drei, Dedup gegen den
      KI-Vorschlag, Verhalten ohne Vorschläge. `ReceiptReviewCardTests.swift:85-155`,
      `ReceiptReviewUITests.swift:226-237`.
- [x] **AC-3** — KI-Marke einzeilig, gemessen unter 26 pt Höhe und breiter als hoch.
      `ReceiptReviewUITests.swift:208-217`. Im RED-Stand war sie 12,0 pt breit und 147 pt hoch.
- [x] **AC-4** — Vorauswahl-Sortierung jetzt auch für den Listen-Treffer-Fall belegt, unabhängig von
      Groß- und Kleinschreibung, geprüft über die `itemID` statt über einen String-Vergleich.
      `ReceiptReviewCardTests.swift:117-140`. Schließt F001.
- [x] **AC-5** — Wahl eines Listen-Treffers setzt Name, Zuordnung und KI-Merkmal wie der bisherige
      Chip-Tap; `originalName` bleibt unverändert. `ReceiptReviewCardTests.swift:163-176`,
      `ReceiptReviewUITests.swift:247-260`.
- [x] **AC-6** — Wahl des KI-Vorschlags stellt KI-Stand und KI-Namen auch nach zwischenzeitlich
      anderer Auswahl wieder her. `ReceiptReviewCardTests.swift:179-192`.
- [x] **AC-7** — Eingabe eines eigenen Namens wird bei jedem Tastenanschlag übernommen, geprüft
      mitten im Wort und ohne jede Bestätigungsaktion, mit Nachweis über die noch offene Tastatur.
      `ReceiptReviewUITests.swift:417-457`. Schließt F002.
- [x] **AC-8** — Preiszeile nach allen vier Regeln (Gewichtszeile, Stückzahl über eins, gedruckte
      Füllmenge, ein Stück) plus Literpreis. Fünf Tests, `ReceiptReviewCardTests.swift:226-258`.
- [x] **AC-9** — „Ändern" öffnet Preis- und Mengenfeld, die Preiszeile aktualisiert sich sofort,
      Einheit und Bontext bleiben unverändert. `ReceiptReviewCardTests.swift:271-314`,
      `ReceiptReviewUITests.swift:289-316`, zusätzlich im Dunkelmodus.
- [x] **AC-10** — Dimmen jetzt messend belegt, in beide Richtungen: Anteil dunkler Bildpunkte der
      Preiszeile fällt beim Abwählen unter ein Viertel des Ausgangswerts und steigt beim
      Wiederanwählen über drei Viertel zurück. Tauglichkeits-Vorbedingung verhindert ein triviales
      Grün bei leerer Zeile. `ReceiptReviewUITests.swift:253-275` und `:543-576`. Schließt F004.
- [x] **AC-11** — Section-Kopf zeigt Positionen, Auswahlzahl und Summe korrekt.
      `ReceiptReviewCardTests.swift:263-267`, `ReceiptReviewUITests.swift:321-329`.
- [x] **AC-12** — Speichern schreibt weiter über den unveränderten `save()`-Pfad, der gelernte Preis
      steht danach am Artikel. `ReceiptReviewUITests.swift:358-376`. Zusätzlich belegt, dass
      `originalName` alle drei Auswahlwege übersteht.
- [x] **Expected Behavior 2** — Tippen auf eine Auswahlzeile wechselt den Namen sofort, ohne
      Bestätigungsdialog.
- [x] **Expected Behavior 3** — siehe AC-7.
- [x] **Expected Behavior 4** — „Ändern" öffnet die Felder direkt an der Karte, siehe AC-9.
- [x] **Expected Behavior 5** — Ab- und Anwählen des Häkchens wirkt in beide Richtungen auf Dimmung,
      Auswahlzahl und Summe. Erst durch den Regressionsfund unten überhaupt erfüllt.
- [x] **Expected Behavior 6** — „Speichern" ist bei null ausgewählten Positionen gesperrt, belegt über
      `isEnabled` UND einen aktiven Tipp, der wirkungslos bleibt (der Prüf-Screen bleibt offen);
      Grenzfall „genau eine Position" und Gegenrichtung mitgeprüft.
      `ReceiptReviewUITests.swift:590-654`. Schließt F003.
- [x] **F005** — Alle fünf vorliegenden Protokolldateien wurden auf die Kommandozeile geprüft: kein
      einziger Lauf mit `-retry-tests-on-failure` oder `-test-iterations`.
- [x] **Regression „Häkchen als Einbahnstraße"** — gefunden, behoben, bewiesen. Siehe unten.

Anerkannte Grenze, keine Behauptung erhoben: Expected Behavior 1 umfasst den Kamera- und
Foto-Scan-Pfad, der laut Spec-eigener Abhängigkeitstabelle (#28) nicht automatisiert prüfbar ist,
weil die Texterkennung im Simulator nicht deterministisch arbeitet.

#### Korrektur eines eigenen Fehlbefunds (F003)

Der erste Testentwurf zu F003 meldete „Speichern lässt sich ohne ausgewählte Position noch antippen"
und wurde vom Orchestrator zunächst als Produktdefekt an den PO gemeldet. **Das war falsch und ist
richtiggestellt:** `canSave` arbeitet korrekt. Ursache der Fehlmessung ist, dass SwiftUI einen per
`.disabled(true)` gesperrten Knopf geometrisch antippbar hält — `isHittable` ist deshalb kein Signal
für eine Sperre. Der Test prüft nun `isEnabled` und zusätzlich die Wirkungslosigkeit eines echten
Tipps. Nebenbefund: Die Zusage von `testReviewSheetOpensFromShareHandoff`, Speichern sei gesperrt,
hing an genau diesem `isHittable` und war damit nie ein Beleg.

#### Regressionsfund — vom Belegen der Gegenrichtung ausgelöst

Beim Nachweis der Gegenrichtung von AC-10 zeigte sich: Das Häkchen ließ sich nur **abwählen**. Ein
Tipp in die Mitte traf beim Wiederanwählen ins Leere, weil die Füllung im abgewählten Zustand
durchsichtig ist und `.buttonStyle(.plain)` nur Gezeichnetes als Trefferfläche nimmt — übrig blieb
der 1,5 pt dünne Rahmen. Nachgewiesen: zweiter Tipp in die Mitte wirkungslos, Tipp auf den Rahmen
wirksam.

Es war eine **Regression dieses Umbaus**: Der Stand `60686dd` hatte dort einen System-Schalter, der
in beide Richtungen ging. Betroffen waren AC-10 (Gegenrichtung) und Expected Behavior 5.

Behoben durch `.contentShape(Rectangle())` am Häkchen — dasselbe Mittel, das die Auswahlzeilen
derselben Karte schon nutzen. Die übrigen antippbaren Flächen wurden einzeln geprüft, keine zweite
Fundstelle; der Prüfer hat über den Diff bestätigt, dass nur diese eine Stelle im Produktcode
angefasst wurde.

Methodisch wichtig: Die neue Hilfe `tapCenter(of:)` tippt über normalisierte Koordinaten die
geometrische Mitte, weil ein gewöhnlicher Tipp auf einen berechneten Punkt am Rand ausweichen darf —
genau das hätte den Fehler verdeckt. Damit beweist der Test den Fix und nicht die Umgehung.

#### Verbleibender sporadischer Fehlschlag — Ursache außerhalb dieser Spec

Im isolierten Bildschirmtest-Lauf scheitert gelegentlich der jeweils erste Test der Klasse
(`testAiMarkStaysOnOneLine`) an der Vorbedingung „Prüf-Screen ist erschienen", nicht an der geprüften
Sache. Empirische Lage über vier Läufe:

| Lauf | Wer | Ergebnis |
|---|---|---|
| isoliert, 08:41 (Diagnose) | Umsetzung | 14/15 — Fehlschlag an der Vorbedingung |
| isoliert, 08:51 (`test-green-ui-output.txt`, Name irreführend) | Umsetzung | 14/15 — derselbe Fehlschlag |
| gemeinsam mit `RestockUITests`, 08:54 (`regression-ui-joint.txt`) | Umsetzung | **19/19, darin 15/15** |
| isoliert, 09:07–09:13 | **Prüfer, unabhängig** | **15/15, 0 Fehler** |

Ursache wurde vom Prüfer im Produktcode selbst gelesen und bestätigt:
`HomeView.checkPendingReceiptScan()` (`SmartCart/Views/Home/HomeView.swift:1565-1582`) bricht ab,
solange die Ladenliste leer ist, und zwar bewusst ohne die Übergabe-Nutzlast zu verbrauchen — ein
Schutz nach einem früheren Datenverlust-Vorfall. Beim ersten Start nach einer Neuinstallation ist die
Abfrage unter Last noch nicht gefüllt, und danach löst nichts den Versuch erneut aus. Längere
Wartezeiten helfen deshalb nicht.

Diese Datei ist nicht Teil dieses Workflows, weder im aktuellen Stand noch im Feature-Commit; sie
gehört zur Testeinstiegs-Mechanik aus #28 und ist in der Spec unter „Dependencies" so benannt.
Ein Vorlauf-Start in `setUp` wurde bewusst **nicht** eingebaut, weil der Fehler zum
Entscheidungszeitpunkt nicht reproduzierbar war und ein Eingriff ohne reproduzierten Fehler
spekulativ wäre. Ebenso wurde der isolierte Lauf nicht ein weiteres Mal wiederholt, um kein
erkauftes Grün zu erzeugen.

Ein früherer Lauf, der mit „Executed 0 tests … passed" endete, ist verworfen und nicht als Nachweis
geführt. Ursache geklärt: Abbruchsignal von außen, weil eine parallel arbeitende fremde Sitzung die
Baudaten gelöscht und das Zielgerät heruntergefahren hatte. Kein Absturz der App, keine
Absturzberichte.

Für echte Nutzer ist das Risiko geringer als im Test: Der Screen entsteht dort nach einer Übergabe
aus der Teilen-Erweiterung, während die App typischerweise schon offen war; und selbst im seltenen
Fall geht dank des genannten Schutzes keine Nutzlast verloren, sie wird beim nächsten Öffnen
nachgeholt.

Empfehlung des Prüfers, nicht blockierend: eigenes Issue für #28, das den Versuch erneut auslöst,
sobald die Ladenliste gefüllt ist.

---

## Nachweise

| Lauf | Datei | Ergebnis |
|---|---|---|
| Unit `ReceiptReviewCardTests` | `test-green-unit-output.txt` | 19/19, TEST SUCCEEDED |
| Unit-Regression gesamte Suite, neu nach der Produktcode-Änderung | `regression-unit-all.txt` | 163/163, TEST SUCCEEDED |
| Bildschirmtests gemeinsam mit `RestockUITests` | `regression-ui-joint.txt` | 19/19, TEST SUCCEEDED, darin 15/15 |
| Bildschirmtests isoliert | `test-green-ui-output.txt` | 14/15 — sporadischer Fehlschlag an der Vorbedingung, siehe oben |
| Prüfer Runde 3, Unit | `scratchpad/adversary_r3_unit_output.txt` | 19/19, 0 Fehler |
| Prüfer Runde 3, Bildschirmtests isoliert | `scratchpad/adversary_r3_ui_output.txt` | 15/15, 0 Fehler |

Alle Läufe ohne Wiederholungshilfe, alle auf demselben Simulator, nie zwei parallel.

## Bilanz

12 von 12 Acceptance Criteria vollständig bewiesen, keine Teilbeweise offen. Alle
Expected-Behavior-Punkte bewiesen, mit Ausnahme des anerkannt nicht automatisierbaren Kamera- und
Foto-Scan-Pfads. Eine Regression gefunden, behoben und mit Gegenrichtungs-Test belegt. Keine
weiteren Regressionen. Ein eigener Fehlbefund des Dialogs wurde erkannt und richtiggestellt.

VERDICT: VERIFIED
