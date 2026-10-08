# Adversary Dialog — fix-120-bon-teilen-weg
Spec: docs/specs/services/receipt-share-extension-recognizer.md
Datum: 2026-10-08 18:28

## Checkliste
- [x] **AC-1:** GIVEN der Stand vor der Umsetzung und das echte Bon-Bild aus #120 (außerhalb des Repos), WHEN `scripts/run-share-extension-uitest.sh` auf `Restock-Validate` läuft, THEN enthält die Nutzlast 14 Positionen und keine Endsumme (Reproduktion, Ist-Zustand; die erweiterte Auswertung aus AC-6 macht den Wert sichtbar und das Skript ROT).
- [x] **AC-2:** GIVEN der Drift-Test vor der Umsetzung, WHEN er läuft, THEN ist er rot (RED), weil `ReceiptTextRecognizer.swift` nicht in der Sources-Phase des Erweiterungsziels steht und `ShareViewController.swift` einen `VNRecognizeTextRequest` enthält.
- [x] **AC-3:** GIVEN das pbxproj nach der Umsetzung, WHEN der Drift-Test läuft, THEN steht `ReceiptTextRecognizer.swift` in der Sources-Phase des Erweiterungsziels (neuer `PBXBuildFile` `A1200D0000000000000000B3`, kollisionsfrei) und der Test ist grün; er schlägt an, wenn der Eintrag fehlt (T2).
- [x] **AC-4:** GIVEN `ShareViewController.swift` nach der Umsetzung, WHEN der Drift-Test läuft, THEN enthält die Datei weder `VNRecognizeTextRequest` noch `func recognizeText`, und `process()` erzeugt die Zeilen aus `ReceiptParserService.reconstructLines(ReceiptTextRecognizer.recognizeBlocks(in:orientation:))`; Einstellungen der Vision-Anfrage bleiben die des Erkenners (`.accurate`, `["de-DE","fr-FR","en-US"]`, `usesLanguageCorrection == false`), Parser, `ReceiptShareHandoff` und Review-Screen sind unverändert.
- [x] **AC-5:** GIVEN die Erkennung liefert keine Zeilen (kein Text, Vision wirft, alle Streifen scheitern), WHEN `process()` läuft, THEN ist `state == .noItemsFound` wie bisher, ohne Absturz und ohne hängenden Zustand; bei gescheitertem einzelnen Streifen werden die übrigen weiter ausgewertet (Verhalten des Erkenners aus #124).
- [x] **AC-6:** GIVEN das Skript nach der Umsetzung, WHEN es eine Nutzlast auswertet, THEN gibt es Positionszahl und Endsumme der Nutzlast aus und beendet sich ROT, wenn die Positionszahl unter `MIN_POSITIONS` (Vorgabe 18) liegt, die Endsumme fehlt oder von `EXPECT_TOTAL` (Vorgabe 68,69) abweicht oder die Nutzlast nicht dekodierbar ist; „Nutzlast ja“ allein führt nicht mehr zu GRÜN.
- [x] **AC-7:** GIVEN die Umsetzung und das echte Bon-Bild, WHEN `scripts/run-share-extension-uitest.sh` auf `Restock-Validate` im Simulator durchläuft, THEN meldet es mindestens 18 Positionen (Referenz App-Scanner: 19) und die Endsumme 68,69 € bei 0 neuen Absturzberichten der Erweiterung; die Ausgabe ist als Artefakt registriert (Commit-Kennung und Zeitstempel passen zum Stand). Diese Zusage gilt für den Simulator und nicht für das Gerät (AC-12).
- [x] **AC-8:** GIVEN `ReceiptShareExtensionTests`, WHEN der Test die unterste Bildkachel in der Fotos-App antippt, THEN geschieht das per Koordinate (`coordinate(withNormalizedOffset:)`), und der Ablauf erreicht den Teilen-Knopf auch bei teilweise verdeckter Kachelreihe.
- [x] **AC-9:** GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch.
- [x] **AC-10:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN sind alle Tests grün, die Testzahl ist > 0, ohne Abbruch und Retry-Flag. (Bei Flakes #111 bleibt eine Ausnahme dem PO vorbehalten und wird nicht vorab angenommen.)
- [x] **AC-11:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt er ohne Fehler, Erweiterungsziel eingeschlossen.
- [x] **AC-12:** GIVEN Ticket und Berichte, WHEN sie formuliert werden, THEN nennen sie ausdrücklich: das Speicherlimit der Erweiterung (ca. 120 MB) wird im Simulator nicht erzwungen, die Spitze des App-Scanners lag bei 134 MB, die Erweiterung ist am Gerät **nicht** bewiesen; der Gerätenachweis folgt erst nach Build 11 und Hennings ausdrücklichem Wort „jetzt ist ein Test möglich“, es wird nie ungefragt auf seinen Geräten getestet; es gibt keine Aussage „Teilen-Weg auf dem Gerät repariert“ vor diesem Nachweis; Rückfall bei Limit-Verletzung ist Alternative B als eigenes Ticket.
- [x] **AC-13:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau `RestockShareExtension/ShareViewController.swift`, `Restock.xcodeproj/project.pbxproj`, `scripts/run-share-extension-uitest.sh`, `RestockUITests/ReceiptShareExtensionTests.swift` und `RestockTests/ReceiptTextRecognizerTests.swift` (ca. +90/−25 LoC), ohne neue Dependencies, `Info.plist`-Änderung, neuen `@AppStorage`-Schlüssel, und ohne Änderung an `ReceiptParserService.swift`, `ReceiptTextRecognizer.swift` oder `ReceiptResolutionService.swift`.

## Dialog

### Runde 1
**Adversary:** Belege pro AC eingefordert und am Code gelesen.

Confirmation:
  AC: AC-3
  Code reference: Restock.xcodeproj/project.pbxproj:1016
  Evidence: A1200D0000000000000000B3 kommt genau 2x vor (Zeile 74 BuildFile, Zeile 1016 Sources-Phase des Erweiterungsziels, direkt hinter ReceiptParserService); fileRef B2 ist dieselbe PBXFileReference wie bei B1 (Zeile 73/976). Keine UUID-Kollision. Der Drift-Test findet das Ziel ueber den Namen, nicht ueber UUIDs.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: RestockShareExtension/ShareViewController.swift:141
  Evidence: Task.detached(priority: .userInitiated) ruft ReceiptParserService.reconstructLines(ReceiptTextRecognizer.recognizeBlocks(in:orientation:)); process() bleibt @MainActor, das await hoppt zurueck, state wird nur auf dem Main Actor gesetzt. recognizeText und import Vision sind entfernt. Suche ueber alle .swift: VNRecognizeTextRequest nur noch in ReceiptTextRecognizer.makeRequest (Erkenner), RecipeRecognitionService (Rezepte, #123, nicht Bon-Weg) und Tests. Kein zweiter Bon-Erkennungsweg. Einstellungen unveraendert in SmartCart/Services/ReceiptTextRecognizer.swift:73.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:98
  Evidence: Einzelzug: (try? recognize) ?? [] ; Streifen: gescheiterter Streifen -> [] (Zeile 111), uebrige laufen weiter; leere Bloecke -> reconstructLines leer -> bestehender .noItemsFound-Pfad im ShareViewController (unveraendert). Kein neuer Code im Pfad; kein automatisierter Test auf process() (Spec T5 erlaubt das als offen zu fuehren).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: RestockTests/ReceiptTextRecognizerTests.swift:441
  Evidence: test-red-output.txt Zeile 141: testExtensionUsesSharedRecognizer rot mit allen vier Verstoessen (Sources-Phase, VNRecognizeTextRequest, func recognizeText, fehlender Aufruf); Commit d2606c0 enthaelt den Test vor der Umsetzung; testWiringCheckDetectsViolations (T2) gruen. Unit-Lauf nachher: Wiring-Tests 3x passed in unit-suite-output.txt.
  Status: CONFIRMED

**Implementierer:** (Belege liegen unter docs/artifacts/fix-120-bon-teilen-weg/)

### Runde 2
**Adversary:** Edge Cases: Skript GRUEN trotz falscher Nutzlast? Alte Nutzlast? Rohzeilen vs Positionen? Geraete-/OS-Abweichung?

Confirmation:
  AC: AC-6
  Code reference: scripts/run-share-extension-uitest.sh:246
  Evidence: Alte Nutzlast wird vor dem Lauf geloescht (Zeile 63), kein Stale-GRUEN. GRUEN nur bei PAYLOAD=ja, 0 Abstuerzen, DECODED=ja, Positionen >= MIN_POSITIONS (0 schaltet nur die Mindestzahl ab, die Endsumme-Pruefung bleibt), Endsumme == EXPECT_TOTAL. Dekodierfehler -> python exit 1 -> DECODED=nein -> ROT. Gezaehlt wird payload.lines (Positionen), nicht Rohzeilen; Summe aus detectedTotal. Die ROT-Faelle (14 Positionen, keine Summe) sind nur durch Lesen der Logik belegt, nicht als Lauf-Artefakt (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/share-e2e-final-ios265.txt:1
  Evidence: [Runde 2: urspruenglich share-e2e-nachher-validate.txt, zurueckgezogen, gegen alten Stand gemessen; ersetzt durch share-e2e-final-ios265.txt, siehe Runde 3] Lauf auf 8F696920 (Restock-Validate, iOS 26.5, per simctl geprueft): Nutzlast ja, dekodierbar ja, 19 Positionen, Endsumme 68,69, 0 neue Absturzberichte, GRUEN, UI-Test passed. Prozessliste enthaelt RestockShareExtension. Artefakt ohne Commit-Kennung/OS-Zeile im Kopf (F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: RestockUITests/ReceiptShareExtensionTests.swift:223
  Evidence: lastTile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap(); der Lauf erreicht den Teilen-Knopf (Test passed).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/unit-suite-output.txt:103
  Evidence: Executed 478 tests, 0 failures, TEST SUCCEEDED; Testzahl > 0, kein Abbruch.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/release-build-output.txt:2
  Evidence: xcodebuild -configuration Release, generic/platform=iOS Simulator, BUILD SUCCEEDED.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: Restock.xcodeproj/project.pbxproj:74
  Evidence: Diff-Statistik gegen HEAD: pbxproj +2, ShareViewController +12/-32, ReceiptShareExtensionTests +3/-1, Skript +58/-4 (Testdatei im Commit d2606c0). ReceiptParserService, ReceiptTextRecognizer, ReceiptResolutionService unveraendert, keine Info.plist-/AppStorage-Aenderung. Zusaetzlich liegen nur Artefakt-Textdateien im Diff.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/run-share-extension-uitest.sh:246
  Description: AC-1 und T4 verlangen die Reproduktion (14 Positionen, keine Endsumme) und den ROT-Beleg der neuen Auswertung am Vorher-Stand. Im Repo liegt dafuer kein Lauf-Artefakt; der Kontext verweist auf eine Scratchpad-Datei ausserhalb des Repos. Die erweiterte Auswertung existierte vorher nicht, ein ROT-Lauf des neuen Skripts am alten Stand ist nirgends belegt.
  Spec requirement: AC-1 / T4 - Reproduktion belegt, Skript ROT am Vorher-Stand
  Conflict: AC-1 ist nur durch Prosa belegt, nicht durch ein nachpruefbares Artefakt.
  Remediation: Auszug des Vorher-Laufs als Artefakt ergaenzen oder im Bericht als nur beschrieben fuehren.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:96
  Description: Spec und Kontext nennen die Vorher-Messung 'Restock-Validate, iOS 27'. Restock-Validate ist iOS 26.5 (simctl). Auf iPhone 17 / iOS 27.0 lieferte die Erweiterung nach dem Fix nur 8 Positionen, auf Validate 19. Das Ergebnis haengt von der OS-/Vision-Version ab und ist nicht untersucht. AC-7 ist ausdruecklich auf Restock-Validate begrenzt, die Zusage ist damit nicht verletzt; die Aussage 'N Positionen' gilt nur fuer iOS 26.5 im Simulator.
  Spec requirement: AC-7 / AC-12 - Zusage nur Simulator Restock-Validate, nie 'Teilen-Weg repariert'
  Conflict: Keine Verletzung, aber die Messumgebung ist in der Spec falsch beschrieben, und der iOS-27-Befund (8 < 18) ist eine ungeklaerte Warnung (Geraet meldete vorher ~3).
  Remediation: Spec/Kontext korrigieren (iOS 26.5), OS-Version in die Skript-Ausgabe aufnehmen, iOS-27-Abweichung als eigenes Ticket fuehren; in Berichten nicht auf Geraet oder andere OS verallgemeinern.

Offen: AC-10 (UI-Suite laeuft erst in /60-validate; vorliegend nur der E2E-Test) und AC-12 (Speicherlimit/Geraet; Spec enthaelt die Aussage vollstaendig, Berichte muessen sie uebernehmen; Geraet nicht angefasst).

**Implementierer:** keine Gegenrede noetig.

### Runde 3
**Adversary:** Neue Belege (Messmatrix, Skript-Reparatur, Final-Laeufe, UI-Suite) selbst gelesen. Alte Runden-2-Bewertung zu AC-1/AC-7/F002 wird ueberholt.

Confirmation:
  AC: AC-1
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/messmatrix-m-alt-ios265.txt:1
  Evidence: Alter Code, selbes Bild lidl-long-1206x9089.png, iOS 26.5: 14 Positionen, Endsumme keine, ROT (14 statt 18; Summe fehlt). messmatrix-m-alt-ios27.txt: iOS 27.0 keine Nutzlast, ROT. Damit ist der Vorher-Zustand als Artefakt belegt (F001 aus Runde 2 erledigt). Beachte: auf iOS 27 ist der Vorher-Wert 0, nicht 14; die Spec nennt 14 nur fuer 26.5.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/share-e2e-final-ios265.txt:1
  Evidence: Restock-Validate (iOS 26.5, per simctl bestaetigt) und share-e2e-final-ios27.txt (Restock-UITest-Verify, iOS 27.0 laut simctl): beide GRUEN, 19 Positionen, 68,69, 0 Abstuerze, md5 der Erweiterung vor/nach identisch und 'entspricht frisch gebautem Stand: ja', Commit d2606c0 mit uncommitteten Aenderungen (Stand ist also nicht an einen Commit gebunden, nur an den md5 des Bauergebnisses). messmatrix-m-neu-* bestaetigt 19/68,69 auf beiden. F002 (iOS-27-Abweichung) ist geklaert: Messfehler durch veralteten Installationsstand.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/run-share-extension-uitest.sh:301
  Evidence: Neue ROT-Pfade (Stand nicht frisch, keine Nutzlast, Abstuerze, nicht dekodierbar, Positionen, Summe) addieren sich in FAILURES; die ROT-Laeufe messmatrix-m-alt-* belegen ROT real bei 14/keine Summe und bei fehlender Nutzlast. Unterschalen-Bug in check_installed ist behoben (globale Variablen, Aufruf ohne $(...)). set -u: alle Variablen vor Verwendung gesetzt (MATCH_BEFORE/AFTER, SIM_RUNTIME mit Rueckfall, COMMIT, DIRTY).
  Status: CONFIRMED

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/run-share-extension-uitest.sh:50
  Description: Der Bau-Nachweis ist schwach gebunden. Wegen `set -o pipefail` (Zeile 17) liefert `xcodebuild | grep` bei fehlgeschlagenem Bau einen Fehlerstatus, `Bau fehlgeschlagen` greift also (kein Fehler, nicht reproduziert, nur gelesen). Restrisiko: der md5-Vergleich prueft installiert gegen TARGET_BUILD_DIR, nicht gegen den Quellstand; ein stehengebliebenes Bauergebnis wuerde GRUEN erlauben, falls xcodebuild ohne Neubau ein altes Ergebnis liefert. Die Ausgabe nennt Commit mit 'uncommittete Aenderungen: ja', aber keinen Quell-Hash.
  Spec requirement: AC-7 - Artefakt mit Commit-Kennung und Zeitstempel passend zum Stand
  Conflict: Bindung an den Stand ist nur indirekt (md5) und bei dirty tree ohne Quell-Hash.
  Remediation: Quell-Hash (Diff-Hash) und Zeitstempel in die Ausgabe aufnehmen.

Finding:
  ID: F004
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/services/receipt-share-extension-recognizer.md:243
  Description: AC-10 verlangt die ganze UI-Suite 'auf Restock-Validate im gemeinsamen Lauf' ohne Fehler. Auf Restock-Validate scheiterten zwei Gesamtlaeufe (ui-suite-output.txt:5262, ui-suite-output-lauf2.txt:5057) an AddItemQuantitySuggestionUITests.testAssumedQuantityIsMarkedAsAssumptionInList (Kachel 'Quittenhof' nicht antippbar bzw. nicht gefunden); einzeln gruen (ui-wiederholung-addstuff.txt:460). Gruen ist nur der Lauf auf Restock-Alternativsimulator Restock-CI-Repro (iOS 26.5): 78 Tests, 1 uebersprungen (RESTOCK_SHARE_E2E, erwartet), 0 Fehler (ui-suite-output-lauf3-ci-repro.txt:5067). Ursache des Validate-Fehlers nicht bewiesen; Test und Code liegen ausserhalb des Diffs, der Fehlerbild (Kachel fehlt) passt zu Zustand auf Validate, nicht zur Erweiterung, ist aber unbelegt. Zudem ist der E2E-Test in dieser Suite uebersprungen und separat gruen.
  Spec requirement: AC-10 - UI-Suite gruen auf Restock-Validate, ohne Abbruch, Ausnahme nur durch PO
  Conflict: Wortlaut nicht erfuellt (anderer Simulator); Spec sagt 'Bei Flakes #111 bleibt eine Ausnahme dem PO vorbehalten und wird nicht vorab angenommen'. Substantiell spricht ein sauberer Lauf auf unberuehrtem Simulator gegen eine Regression durch die Aenderung, beweist es aber nur indirekt (kein Lauf der Suite auf Validate vor der Aenderung zum Vergleich).
  Remediation: PO-Entscheidung (Ausnahme/Simulatorwechsel) einholen; ggf. Validate zuruecksetzen und Suite wiederholen oder den Test auf dem Stand vor der Aenderung auf Validate ausfuehren, um Altlast zu belegen.

Finding:
  ID: F005
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/services/receipt-share-extension-recognizer.md:24
  Description: Spec weicht vom belegten Stand ab: (a) nennt Restock-Validate iOS 27 (ist 26.5); (b) beschreibt das Skript ohne Bau/Installation/md5-Nachweis und ohne iOS-/Commit-Ausgabe, die Reparatur ist eine nicht spezifizierte Erweiterung des Skripts (+~60 Zeilen mehr); (c) Vorher-Wert 14 gilt nur auf 26.5, auf 27.0 ist er 0; (d) Spec-Status draft, Approval offen. Umfang des Skript-Diffs liegt mit ca. 120 Zeilen ueber den 'ca. +25' der Spec, die Gesamtgroesse bleibt unter dem Limit (+-250).
  Spec requirement: Spec Abschnitt Purpose / Prüfskript / AC-13 (ca. +90/-25)
  Conflict: Spec und Umsetzung weichen ab; Spec-Aenderung braucht 'override' des PO und steht aus.
  Remediation: PO-override, Spec korrigieren (Runtime 26.5, Bau-/md5-Nachweis, Vorher-Werte je OS), danach Briefing neu binden.

Finding:
  ID: F006
  Severity: LOW
  Category: spec_violation
  Code reference: docs/specs/services/receipt-share-extension-recognizer.md:248
  Description: AC-12: Die Spec enthaelt die Zusage vollstaendig, aber die Berichte (inkl. dieser Pruefung) sind der Ort der Pflichtformulierung. Hier festgehalten: Speicherlimit (ca. 120 MB) wird im Simulator nicht erzwungen, App-Scanner-Spitze 134 MB, Erweiterung am Geraet NICHT bewiesen, Geraetenachweis erst nach Build 11 und Hennings Wort 'jetzt ist ein Test moeglich'; Aussage nur 'im Simulator erkennt der Teilen-Weg 19 Positionen und die Endsumme', nie 'Teilen-Weg repariert'. Rueckfall: Alternative B als eigenes Ticket. Ob Ticket und Abschlussbericht dies tragen, ist nicht prueft hier.
  Spec requirement: AC-12
  Conflict: Offene Pflicht an Ticket/Abschlussbericht, nicht am Code.
  Remediation: Formulierung in Ticket #120 und PR-Text uebernehmen.

**Implementierer:** F003 bis F006 offen; AC-10 wartet auf PO-Entscheidung.

### Runde 4
**Adversary:** Spec nach PO-override neu gelesen; Briefing gelesen.

Confirmation:
  AC: AC-10
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/ui-suite-output-lauf3-ci-repro.txt:5067
  Evidence: Neue Fassung verlangt Restock-CI-Repro (iOS 26.5, per simctl bestaetigt, UDID 41D6E735 im xcodebuild-Aufruf). Lauf: 78 Tests, 1 uebersprungen (RESTOCK_SHARE_E2E, erwartet; E2E separat gruen), 0 Fehler, TEST SUCCEEDED, kein Retry/Abbruch. Die PO-Entscheidung ist in der Spec dokumentiert, Validate-Altlast in eigenem Ticket. Meine Einschraenkung: Die Spec-Aussage 'auf main-CI gruen' habe ich nicht selbst geprueft; die Ursache auf Validate bleibt unbewiesen und ist so benannt (F004 damit erledigt, Wortlaut und Beleg stimmen ueberein).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/specs/services/receipt-share-extension-recognizer.md:264
  Evidence: Spec (Purpose, AC-12, Risiken) und Briefing (docs/briefings/fix-120-bon-teilen-weg.md:26-27) nennen ausdruecklich: Limit ca. 120 MB, Scanner 134 MB, Geraet unbewiesen, Geraetetest nur nach Build 11 und Hennings Wort, Rueckfall Alternative B als eigenes Ticket, keine Zusage 'auf dem iPhone repariert'. Damit ist die Berichtsanforderung erfuellt; der Geraetenachweis selbst bleibt ausdruecklich unbewiesen und offen.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/run-share-extension-uitest.sh:301
  Evidence: Spec nennt jetzt Skript ca. +120 und LoC ca. +190/-40; belegter Stand: Skript +~122 (aus Diff), Gesamt im Rahmen. F005 (a)-(c) behoben: iOS 26.5 fuer Validate, Bau/md5-Nachweis in Spec, Vorher-Werte je OS (14 bzw. 0), AC-6 deckt Bau-Fehler und md5. Rest-Punkt (d): Spec-Status 'draft' und Approval-Haken 'offen' im Kopf stehen weiter, obwohl PO-override vorliegt (LOW, F007).
  Status: CONFIRMED

Finding:
  ID: F007
  Severity: LOW
  Category: spec_violation
  Code reference: docs/specs/services/receipt-share-extension-recognizer.md:15
  Description: Kopf der Spec: 'Approved - PO (offen)' und status draft; AC-1 behauptet, der Alt-Stand sei 'per md5 belegt', die abgelegten messmatrix-m-alt-*-Dateien sind aber nur Ergebnisauszuege ohne md5-Zeilen (Quelle laut Koordinator: Scratchpad check-variant.sh).
  Spec requirement: AC-1 - Reproduktion mit belegtem Alt-Stand
  Conflict: Der md5-Beleg des Alt-Stands ist im Repo nicht nachpruefbar; Freigabe-Haken formal offen.
  Remediation: md5-Zeilen aus dem Scratchpad in die Artefakte uebernehmen; Haken/Status nach Freigabe setzen.

F003 (Quell-Hash) neu bewertet: LOW, kein Blocker. Spec AC-6 verlangt jetzt Bau-Erfolg und md5 vor/nach; beides erfuellt und in share-e2e-final-* sichtbar. F005 erledigt, F004 erledigt, F006 durch AC-12 oben abgedeckt.

**Implementierer:** keine Gegenrede.

### Runde 5
**Adversary:** Neue Unit-Ausgabe und md5-Beleg gelesen.

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/unit-suite-output.txt:1306
  Evidence: Frischer Lauf: Executed 478 tests, 0 failures, TEST SUCCEEDED (Zeile 1316); deckt sich mit meinem frueheren Befund (478/0). unit-suite-versuch1-haenger.txt (Zeile 85-87: 'test runner hung before establishing connection', TEST FAILED, kein Test ausgefuehrt) wird NICHT als Gruen gewertet und nicht als Beleg zitiert; nur der erfolgreiche zweite Lauf zaehlt.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: docs/artifacts/fix-120-bon-teilen-weg/messmatrix-installierter-stand-md5.txt:6
  Evidence: F007 geklaert: md5 alt 97f58a37... (Marker variant=alt, keine Symbole ReceiptTextRecognizer) und neu 49c38fbd... (90 Symbole), vor/nach je Lauf gleich. Einschraenkung: Die Tabelle betrifft Diagnose-Varianten mit zusaetzlichen Logzeilen; der Endstand 2f7e090e... steht in share-e2e-final-*. Die Aussage 'Alt-Stand per md5 belegt' ist damit gestuetzt, aber fuer den Diagnose-Alt-Stand, nicht fuer den unveraenderten Alt-Commit.
  Status: CONFIRMED

F007: md5-Teil geklaert (LOW-Restpunkt: Diagnose-Variante statt unveraenderter Alt-Build; Freigabe-Haken im Spec-Kopf formal offen). Kein Blocker.

**Implementierer:** keine Gegenrede.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine verdaechtige Zeile.

## Verdict: VERIFIED
Begruendung: AC-1..AC-13 belegt (AC-1/AC-7 durch messmatrix-m-alt-*, share-e2e-final-*; AC-10 in neuer Fassung durch Lauf auf Restock-CI-Repro; AC-12 als Berichtsformulierung in Spec und Briefing, Geraetenachweis ausdruecklich unbewiesen). Offene Findings nur LOW (F003, F007), kein Blocker. Unbewiesen bleibt: Speicherlimit der Erweiterung am Geraet, Ursache der Validate-Altlast, 'main-CI gruen'-Aussage der Spec.
Tests: 478 Unit bestanden, 0 fehlgeschlagen; UI 78 Tests, 1 uebersprungen (erwartet), 0 Fehler auf CI-Repro; E2E 19 Positionen/68,69 auf iOS 26.5 und 27.0.

## Geprüfte Dateien

- sha256:abd2d6cc2ab50af5578dabce86a5a40946292a72a706ed38af5151ac68359309  Restock.xcodeproj/project.pbxproj
- sha256:9023b61091c12cd3fe83d59f1b8ae7cd82d2b34139853d452239b6236e603bf1  RestockShareExtension/ShareViewController.swift
- sha256:22d1a6a0096f6e4ff7b144ab7ca452e55814829d29d150d17dc0055d2b34ba7f  RestockTests/ReceiptTextRecognizerTests.swift
- sha256:1379072c3ede643f2b26bb28b1ce8814cbfc9b7c7882054423500a0679138b32  RestockUITests/ReceiptShareExtensionTests.swift
- sha256:c5f0c7d4d633f21d7e9d72647c7642a5f42e3bc74bd9790dcc33a8fb678960e0  SmartCart/Services/ReceiptTextRecognizer.swift
- sha256:d601e406f4a2a9b31c9583a2e4489da9c3e1dec9331bb070f0f95ec4e59efee5  docs/artifacts/fix-120-bon-teilen-weg/messmatrix-installierter-stand-md5.txt
- sha256:d8cc4d5dc86d5f7fb1d74495ae953d000fe64f042e9447b34be5fa166dac95da  docs/artifacts/fix-120-bon-teilen-weg/messmatrix-m-alt-ios265.txt
- sha256:112dea422c2a8717df5da0eabf5ea98928f7955a32491eb2e0bc42186fc97fb7  docs/artifacts/fix-120-bon-teilen-weg/release-build-output.txt
- sha256:830b04de92c79d780b395f1c06234732688ff42d246d344b350f0bf863989f9f  docs/artifacts/fix-120-bon-teilen-weg/share-e2e-final-ios265.txt
- sha256:117ecd470f244f4dca73dac5db68403ba2593bc3bc7093c39bcaa3f533ca720f  docs/artifacts/fix-120-bon-teilen-weg/ui-suite-output-lauf3-ci-repro.txt
- sha256:a2d3ca1b41e73329b43299d054d5f6534ed17134ce614e0bc1a6a6c558eba68a  docs/artifacts/fix-120-bon-teilen-weg/unit-suite-output.txt
- sha256:f9e7f9a10ec5fbb23cc15ddca92d820b9e5d2e1a7f84883db25375ae1674308f  docs/specs/services/receipt-share-extension-recognizer.md
- sha256:4297b832f298ed5ccc825fdba1d4d1a29f2e6137f4ae62f6bd4c44764861e331  scripts/run-share-extension-uitest.sh

## Prüfbasis

- base: 7873b7511eb4f49c7d394df843ef0b6595f6516a
- blob:55c184ab7f44f79bf1ac13fce0f94e6c1d774c3d  Restock.xcodeproj/project.pbxproj
- blob:7d0f3ee0ec2f91002cfa8080049f081fc92a5ce6  RestockShareExtension/ShareViewController.swift
- blob:1b3c21d9171e5dd9e97ef9631f2f0de2195faa54  RestockTests/ReceiptTextRecognizerTests.swift
- blob:932aba8a8198dd424125ff3eeb7419fc5a48d91d  RestockUITests/ReceiptShareExtensionTests.swift
- blob:b485dd6713afc88935d782d0689dcbdbe76432e9  SmartCart/Services/ReceiptTextRecognizer.swift
- blob:e7a0fab49f59b4955dbf7348d8fa57e72404a0ba  docs/artifacts/fix-120-bon-teilen-weg/messmatrix-installierter-stand-md5.txt
- blob:158002d22d72b6ff88b5702073f973a5ea20de31  docs/artifacts/fix-120-bon-teilen-weg/messmatrix-m-alt-ios265.txt
- blob:a43c93cb71e9f65872595fc43e99f5c464ec4520  docs/artifacts/fix-120-bon-teilen-weg/release-build-output.txt
- blob:a1d354ca03ab86c231c8add4ae404be2d3ccfff9  docs/artifacts/fix-120-bon-teilen-weg/share-e2e-final-ios265.txt
- blob:4e4e86a3a4e85953eb1d87d01425caaf9fab1792  docs/artifacts/fix-120-bon-teilen-weg/ui-suite-output-lauf3-ci-repro.txt
- blob:535b458810debaba96726bcc106699c3c75fc3b7  docs/artifacts/fix-120-bon-teilen-weg/unit-suite-output.txt
- blob:ee3e28eb9ca78517204afdc8d59bd87b325682f4  docs/specs/services/receipt-share-extension-recognizer.md
- blob:d493ff15fd5c9e4a4424939d389d163ca5554a57  scripts/run-share-extension-uitest.sh
