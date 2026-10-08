# Adversary Dialog — fix-120-bon-lange-bilder
Spec: docs/specs/services/receipt-text-recognizer-tiling.md
Datum: 2026-10-08 07:28

## Checkliste
- [x] **AC-1:** GIVEN ein erzeugtes hohes Bon-Bild (ca. 1206 × 9000 px, Monospace-Text, Namens- und Preisspalte, blaue Rabattzeilen), WHEN es vor der Umsetzung (aktueller Weg: Ganzbild in einem Zug) erkannt wird, THEN fehlt Text gegenüber dem Streifenweg (RED, Ist-Zustand der PO-Meldung belegt). Lässt sich der Textverlust mit einem erzeugten Bild nicht erzeugen, wird das ausdrücklich als offene Grenze benannt, und AC-2 bis AC-8 sichern Mathematik und Zusammenführung.
- [x] **AC-2:** GIVEN derselbe Test nach der Umsetzung, WHEN die Erkennung über den Streifenweg läuft, THEN sind alle erzeugten Artikelzeilen und die Endsumme erkannt (Schalter Fehler da → Fix → Fehler weg).
- [x] **AC-3:** GIVEN eine Bildgröße, WHEN `needsTiling` läuft, THEN ist das Ergebnis `true` genau dann, wenn Höhe/Breite > 2,5 ist (1206 × 9089 ja; Seitenverhältnis 1,3 bis 2 nein; Breite oder Höhe 0 nein).
- [x] **AC-4:** GIVEN ein Bild mit `needsTiling == true`, WHEN `tiles` läuft, THEN haben alle Streifen volle Bildbreite und Höhe > 0, der erste beginnt bei 0, der letzte endet genau am Bildende, jeder Streifen beginnt höchstens am Ende des vorigen (lückenlos), und die Überlappung benachbarter Streifen beträgt ca. 0,25 × Breite.
- [x] **AC-5:** GIVEN ein Bild mit `needsTiling == true`, WHEN `tiles` läuft, THEN beträgt die Höhe aller Streifen außer dem letzten ca. 2 × Breite, und es entsteht kein Streifen, der nur aus Überlappung besteht; GIVEN `needsTiling == false`, THEN genau ein Streifen = ganzes Bild.
- [x] **AC-6:** GIVEN eine Vision-Box (normiert, Ursprung unten links, bezogen auf einen Streifen), WHEN sie in Gesamtbild-Koordinaten umgerechnet wird, THEN ist `y_global = (H − tile.maxY + box.minY × tile.height) / H` und `h_global = box.height × tile.height / H`; x und Breite bleiben; das Ergebnis ist wieder normiert mit Ursprung unten links.
- [x] **AC-7:** GIVEN dieselbe Zeile, in zwei überlappenden Streifen erkannt (gleicher Text, Mittelpunkt-Abstand im Gesamtbild < ca. 15 px bzw. < kleiner Bruchteil der Texthöhe), WHEN Duplikate entfernt werden, THEN bleibt genau ein Block.
- [x] **AC-8:** GIVEN zwei Blöcke mit gleichem Text und Mittelpunkt-Abstand von mindestens einer Zeilenhöhe oder zwei Blöcke mit nahem Mittelpunkt aber verschiedenem Text, WHEN Duplikate entfernt werden, THEN bleiben beide (zwei gleiche Artikel nacheinander gehen nicht verloren).
- [x] **AC-9:** GIVEN die Erkennung je Streifen, WHEN sie läuft, THEN verwendet jede Anfrage `.accurate`, `recognitionLanguages == ["de-DE", "fr-FR", "en-US"]`, `usesLanguageCorrection == false` und die `orientation` wie heute (Streifen-Geometrie bezogen auf das ausgerichtete Bild).
- [x] **AC-10:** GIVEN ein normales Bon-Foto (`needsTiling == false`), WHEN es erkannt wird, THEN gibt es genau einen Erkennungsdurchgang auf dem Gesamtbild mit denselben Einstellungen und demselben Ergebnis wie vor der Änderung.
- [x] **AC-11:** GIVEN kein `cgImage`, Vision wirft oder ein Streifen scheitert, WHEN `process(_:)` läuft, THEN endet der Spinner: ohne `cgImage` `parsedLines == []` und `phase == .review` wie heute; wirft Vision, ergibt das leere Zeilen und `phase == .review`; scheitert ein einzelner Streifen, werden die übrigen Streifen weiter ausgewertet.
- [x] **AC-12:** GIVEN die Änderung, WHEN man `ReceiptParserService.swift` und `ReceiptResolutionService.swift` gegen den Tip-Commit vergleicht, THEN sind beide unverändert; Rabattzeilen (negative Preise) werden weiterhin ignoriert.
- [x] **AC-13:** GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch.
- [x] **AC-14:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN sind alle Tests grün, die Testzahl ist > 0, ohne Abbruch und Retry-Flag. (Bei Flakes #111 bleibt eine Ausnahme dem PO vorbehalten und wird nicht vorab angenommen.)
- [x] **AC-15:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt der Build ohne Fehler.
- [x] **AC-16:** GIVEN das echte Bon-Bild aus #120 (liegt außerhalb des Repos, persönliche Angaben, nicht eingecheckt) und die App im Simulator mit dem Stand dieses Durchgangs, WHEN das Bild durch die echte Erkennungsstrecke der App (`process(_:)` mit `ReceiptTextRecognizer`, `reconstructLines`, `parse`, `detectedTotal`) läuft, THEN werden mindestens 17 Positionen erkannt (Messung auf dem Mac: 18) und die Endsumme 68,69 € wird erkannt; der Durchlauf ist als Artefakt registriert (Commit-Kennung und Zeitstempel passen zum Stand). Der Weg (Wegwerf-Haken/Launch-Argument, danach restlos entfernt) legt Phase 6 fest; ist er nicht machbar, wird das ausdrücklich als offen benannt.
- [x] **AC-17:** GIVEN Ticket und Berichte, WHEN sie formuliert werden, THEN nennen sie ausdrücklich die offenen Grenzen: Streifenhöhe (2 × Breite), Überlappung (0,25 × Breite) und Schwelle (2,5) sind an einem einzigen Bild gemessen bzw. festgelegt und werden an weiteren hohen Bons erst im Gebrauch bestätigt; die Nicht-Ziele (Rabatt je Artikel abziehen, Namensqualität einzelner Zeilen, PDF-/Mehrseiten-Bons); die erkannten Preise bleiben Regalpreise (Summe der 18 Positionen 70,67 € gegenüber Endsumme 68,69 €); es gibt keine Aussage „Rabatt-Bons repariert“ vor AC-16.
- [x] **AC-18:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau `SmartCart/Services/ReceiptTextRecognizer.swift`, `SmartCart/Views/Prices/ReceiptScannerView.swift`, `RestockTests/ReceiptTextRecognizerTests.swift` und `Restock.xcodeproj/project.pbxproj` (je zwei neue Dateien an allen vier Stellen registriert; ca. +150/−25 LoC), ohne neue Dependencies, `Info.plist`-Änderung, neuen `@AppStorage`-Schlüssel oder einen übrig gebliebenen Wegwerf-Haken aus AC-16.

## Dialog

### Runde 1
**Adversary:**

Methode: nur gelesen (Diff, neue Datei ReceiptTextRecognizer.swift, Tests, Belege). Kein Test, Build oder Simulator gestartet. Ergebnis: kein CRITICAL, kein HIGH, ein MEDIUM (F001), mehrere LOW.

Eigene Prüfung der Belege: test-green-output.txt 474 Tests, 0 Failures, TEST SUCCEEDED, keine übersprungenen; release-build.txt clean build BUILD SUCCEEDED; test-red-runtime-output.txt T1 zur Laufzeit rot (11 statt 18 Positionen, Preise fehlen); test-red-output.txt nur Übersetzungsfehler; ist-zustand-erzeugtes-bild.txt Einzelzug 11/18, Streifen 18, Endsumme 68,69.
Rechenproben: `tiles` für 1206×9089: Streifenhöhe 2412, Überlappung 302, Schritt 2110, Streifen bei y = 0, 2110, 4220, 6330, letzter y = 8440 mit Höhe 649, Ende 9089. Der letzte Streifen ist immer höher als die Überlappung, der Schritt immer positiv. 1000×2501: Streifen 0…2000 und 1750…2501. `globalBox`: y = (H − maxY + minY·tileH)/H, passend zur Spec und zur Vision-Konvention (Ursprung unten links).

Befunde:
- F001 (MEDIUM, edge_case): Bei Ausrichtung ungleich .up, wenn die ausgerichtete Größe keinen Streifenbedarf hat, bleibt das Rohbild mit der Original-Ausrichtung, das Schneiden lief aber auf der Rohgröße (Beispiel Rohbild 1000×3000 mit .right: ausgerichtet 3000×1000, kein Bedarf; Rohgröße Verhältnis 3 wird geschnitten, jeder Streifen geht mit .right an Vision, globalBox rechnet in der falschen Achse). Gleiches wenn uprightImage nil liefert. Remediation: Streifen nur auf aufrechtem Bild, sonst Einzelzug mit der Original-Ausrichtung.
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:90
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:95
- F002 (LOW): gedrehter Pfad (CIImage.oriented/CIContext) ungetestet; alle Aufrufe in der Testdatei nutzen .up.
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:136
- F003 (LOW): Teiltext an der Streifenkante wird nicht als Duplikat erkannt (gleicher Text vorausgesetzt); bei echten Duplikaten bleibt der erste Block (frühere Streifen, unterer unsicherer Rand).
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:60
- F004 (LOW): Der Einzelzug rief trotzdem cropping auf das Gesamtrechteck auf (pixelgleich, aber nicht dasselbe Objekt); bei cropping == nil wäre das Ergebnis leer. Remediation: Original-CGImage direkt übergeben.
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:104
- F005 (LOW): Tests: tiles[1] ohne guard (Zeile 238), T5 rechnet mit selbst gewählten Streifen, T1 Zeile 43 hängt vom Vision-Modell ab.
Code reference: RestockTests/ReceiptTextRecognizerTests.swift:238
- F006 (LOW, Scope): RecipeRecognitionService.swift:134 hat denselben Ganzbild-Aufruf (derselbe Fehler bei sehr hohen Rezept-Screenshots möglich); außerhalb des Auftrags.
Code reference: SmartCart/Services/RecipeRecognitionService.swift:134

Fehlerverhalten: recognizeBlocks synchron in Task.detached, nicht auf dem Main-Thread, keine Continuation, Hängen des Spinners ausgeschlossen; scheiternder Streifen bleibt leer. Speicher bei 1206×9089 ca. 44 MB.

AC-Bewertung Runde 1: AC-1 bis AC-8, AC-10 bis AC-13, AC-15, AC-18 AKZEPTIERT (AC-7 mit LOW F003, AC-10 mit LOW F004); AC-9 NACHFRAGE (F001/F002); AC-14, AC-16, AC-17 in Runde 1 offen, nachgereicht (UI-Suite nach der letzten Quelländerung; Durchlauf mit dem echten Bon, ≥ 17 Positionen und Endsumme 68,69; Berichtstexte im Ticket).
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:691
Code reference: Restock.xcodeproj/project.pbxproj:75
Vorläufiges Urteil Runde 1: noch nicht VERIFIED; F001 vor dem Urteil beheben oder als offene Grenze benennen.

**Implementierer:**

(Antworten in Runde 2)

### Runde 2
**Adversary:**

Methode: nur gelesen; neue Fassung von ReceiptTextRecognizer.swift neu gelesen; ReceiptScannerView.swift seit 06:33:04 unverändert; Diff gegen HEAD: project.pbxproj +4, ReceiptScannerView.swift +4/−34, ReceiptTextRecognizerTests.swift +51; ReceiptParserService.swift und SmartCartApp.swift nicht im Diff.

- F001 (MEDIUM): behoben, AKZEPTIERT. needsTiling fällt auf der ausgerichteten Größe; ohne Bedarf oder wenn uprightImage nil liefert, geht das Original-Bild mit Original-Ausrichtung in den Einzelzug; Streifen nur auf dem aufrechten Bild, recognize bekommt dort .up. RED-Beleg test-red-runtime-output-2.txt Zeile 281/282 (T9 „gedreht, ausgerichtet quer“ rot: „2 ist nicht 1“, „Original-Bild ohne Zuschnitt“); der zweite neue Test war vorher schon grün. Restrisiko: Der Fall „uprightImage liefert nil“ ist durch die Testnaht nicht abgedeckt, führt aber gutartig in den Einzelzug.
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:96
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:98
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:101
Code reference: RestockTests/ReceiptTextRecognizerTests.swift:274
Code reference: RestockTests/ReceiptTextRecognizerTests.swift:295
- F002 (LOW): als offene Grenze AKZEPTIERT; Entscheidungspfad über die Testnaht abgedeckt, CIImage.oriented mit CIContext nie mit echtem gedrehtem Bild; steht im Ticket #120 (Punkt 5).
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:140
- F003 (LOW): hinnehmen und benennen, AKZEPTIERT. Im echten Durchlauf keine Doppelpositionen (Stichprobe von einem Bon). Ticket #120 Punkt 5, Folgeticket #123.
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:60
- F004 (LOW): behoben, AKZEPTIERT. Einzelzug ruft recognize(cgImage, orientation) mit dem Original, ohne cropping; Test über Identität (===).
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:98
- F005 (LOW): behoben, AKZEPTIERT. guard tiles.count >= 3 vor tiles[1] (Testdatei Zeile 240, T8 Zeile 183), Hinweis bei T1 gesetzt; T5 stützt sich weiter auf fest vorgegebene Streifen, Mutation von tiles fangen T3/T4.
Code reference: RestockTests/ReceiptTextRecognizerTests.swift:240
- F006 (LOW): außerhalb des Scopes, als offene Grenze AKZEPTIERT; Ticket #120 Punkt 6; Folgeticket #123 angelegt.
Code reference: SmartCart/Services/RecipeRecognitionService.swift:134

AC-9 AKZEPTIERT (alle Anfragen über makeRequest(), Ausrichtung je Durchgang; gedrehter Pfad über Testnaht).
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:73
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:125
AC-13 AKZEPTIERT: Lauf 07:44:44–07:44:59 nach der letzten Änderung am Erkenner (07:44:06), 476 Tests, 0 Failures, TEST SUCCEEDED, 13 ReceiptTextRecognizerTests grün.
Code reference: RestockTests/ReceiptTextRecognizerTests.swift:27
AC-15 AKZEPTIERT: release-build.txt 07:48, nach der letzten Änderung, BUILD SUCCEEDED.
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:12
AC-16 AKZEPTIERT mit Hinweis: durchlauf-echter-bon.txt (07:46:54, nach der letzten Änderung): echte Kette (recognizeBlocks, reconstructLines, detectedTotal, parse) auf Restock-Validate mit dem echten Bild: 19 Positionen (Soll ≥ 17), Endsumme 68,69, 4,95 s, Spitze 134 MB; Gegenprobe alter Einzelzug 14 Positionen ohne Endsumme. Wegwerf-Haken restlos entfernt (SmartCartApp.swift nicht im Diff). Abweichung zur Mac-Messung (19 statt 18) erklärt (Simulator erkennt zusätzlich „Bio Ingwer Shot 1,29“); Namensqualität ist Nicht-Ziel (Ticket); das Artefakt trägt den Tip-Commit plus uncommittete Änderungen als Stand.
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:691
Code reference: SmartCart/Services/ReceiptTextRecognizer.swift:99
AC-17 AKZEPTIERT: Ticket #120, Kommentar „Stand der Umsetzung (2026-10-08)“, selbst gelesen: Streifenmaße an einem Bon, Nicht-Ziele (Rabatt je Artikel, Namensqualität, PDF/Mehrseiten), Regalpreise (71,71 € gegenüber 68,69 €), Pfand im Streifenweg nicht zugeordnet, Teiltext an der Streifenkante, gedrehter Pfad nur über die Testnaht, RecipeRecognitionService, Vision-Version-Abhängigkeit (4 Mac, 14 Simulator, 3 Gerät), keine Aussage „Rabatt-Bons repariert“ vor neuem TestFlight-Stand.
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:688
AC-18 AKZEPTIERT: App-Code ca. +152/−34 mit der neuen Datei; Testdatei im RED-Commit 323 Zeilen, +51; keine Info.plist-/AppStorage-/Dependency-Änderung, kein Wegwerf-Haken im Diff, Parser und Auflösung unverändert, PO „go“.
Code reference: Restock.xcodeproj/project.pbxproj:75
AC-14: AKZEPTIERT (nachgereicht, Bedingung erfüllt): test-full-ui-suite-output.txt, Lauf endet 2026-10-08 08:11:56 nach der letzten Quelländerung (07:44:06): „Executed 78 tests, with 1 test skipped and 0 failures“, TEST SUCCEEDED, ohne Abbruch, ohne Retry-Flag (Aufruf ohne -retry-tests-on-failure/-test-iterations, vom Koordinator bestätigt).
Code reference: docs/artifacts/fix-120-bon-lange-bilder/test-full-ui-suite-output.txt:1
AC-1 bis AC-8, AC-10 bis AC-12: wie in Runde 1 akzeptiert. Neue Befunde in Runde 2: keine.

**Implementierer:**
- F001: behoben (Streifen nur auf aufrechtem Bild, sonst Einzelzug mit Original-Bild und Original-Ausrichtung), zwei neue Tests, RED zur Laufzeit belegt, danach grün.
- F004: behoben (Einzelzug ohne Zuschnitt); F005: guard und Kommentar.
- F002, F003, F006: offene Grenzen im Ticket #120, gebündelt als Folgeticket #123.
- AC-13: Unit-Suite 476 Tests, 0 Failures. AC-15: Release-Build neu. AC-16: Durchlauf mit dem echten Bon, 19 Positionen, 68,69 €. AC-17: Ticket #120. AC-14: UI-Suite 78 Tests, 1 bekannt übersprungen, 0 Failures, 08:11. AC-18: Umfang offengelegt, PO „go“.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Einordnung: Keine Tabelle angehängt, keine Verdachtszeilen mit nur einer Produktions-Schreibstelle. Der Erkenner ist eine reine Funktion (Bild und Ausrichtung hinein, Blöcke heraus); ReceiptScannerView.process setzt debugRawLines, detectedTotal und parsedLines wie bisher. Die einzige Vorbedingung ist, dass needsTiling auf der ausgerichteten Größe gilt; Tests für genau diesen Weg: test_T9_gedreht_ausgerichtetQuer_einDurchgangMitOriginalbildUndAusrichtung (RestockTests/ReceiptTextRecognizerTests.swift:274) und test_T9_gedreht_ausgerichtetHoch_streifenAufDemAufgerichtetenBild (:295).

## Verdict
**VERIFIED**

Begründung (Adversary): Die Umsetzung hat die Prüfung bestanden. Tests: 476 Unit-Tests bestanden, 0 fehlgeschlagen; ganze UI-Suite 78 Tests, 1 bekannt übersprungen, 0 fehlgeschlagen (nachgereicht, Bedingung erfüllt). Edge cases: F001 behoben und mit RED-Beleg belegt; F002, F003, F006 sind benannte offene Grenzen im Ticket #120 und im Folgeticket #123. Regressions: keine gefunden (Parser und Auflösung unverändert, Einzelzug mit Original-Bild und Original-Ausrichtung). Checklist: 18 von 18 Punkten bewiesen. Offene Grenzen: Streifenmaße an einem Bon gemessen; Rabatt wird nicht je Artikel abgezogen (Produktfrage); Pfand im Streifenweg nicht zugeordnet; gedrehter Pfad nur über die Testnaht; Wirkung auf dem Gerät des PO erst nach einem neuen TestFlight-Stand belegt (keine Aussage „Rabatt-Bons repariert“ davor).

## Geprüfte Dateien

- sha256:ca7af6a8852b21345090c0123abda97cbf1dd254840dc47d21337717fbca4169  Restock.xcodeproj/project.pbxproj
- sha256:665247e2f63261d4f5488a1aade11b399113176ec1133bb660d9970c217a604e  RestockTests/ReceiptTextRecognizerTests.swift
- sha256:c5f0c7d4d633f21d7e9d72647c7642a5f42e3bc74bd9790dcc33a8fb678960e0  SmartCart/Services/ReceiptTextRecognizer.swift
- sha256:1132d1db4fc48c5bcb1fc78bb4801c4447e8dd226470545647db7bbe564c210c  SmartCart/Services/RecipeRecognitionService.swift
- sha256:ed70967aded10897fd365f230a45958ca5205da2e0d500ff4d4cbbe1b6230d3f  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:c3d88e4d1484a028d6279f3401d3f77e8f2352e196ac1dafafd7eec4d6204985  docs/artifacts/fix-120-bon-lange-bilder/test-full-ui-suite-output.txt

## Prüfbasis

- base: 8fd17274f814f9ee556c153081a4ad1d77dfdce2
- blob:0ce2eec202a7398a2276eef2c22729f0181abf2d  Restock.xcodeproj/project.pbxproj
- blob:77ad7cf3e4dbe8aded84df4b936282638600c3d9  RestockTests/ReceiptTextRecognizerTests.swift
- blob:b485dd6713afc88935d782d0689dcbdbe76432e9  SmartCart/Services/ReceiptTextRecognizer.swift
- blob:a494b321c3452fd2152ac9f0f7ae8e8e6d8f4a06  SmartCart/Services/RecipeRecognitionService.swift
- blob:6a740ae23d4ae06ff06976a39d4daf360011b186  SmartCart/Views/Prices/ReceiptScannerView.swift
- blob:7f70c2042990dd54f52bbc677924a8fcb7ea4d64  docs/artifacts/fix-120-bon-lange-bilder/test-full-ui-suite-output.txt
