# Adversary Dialog — feat-233-abhaken-per-tipp
Spec: docs/specs/views/item-row-tap-to-check.md
Datum: 2026-10-30 13:19

## Checkliste
- [x] **AC-1:** Ein Tipp auf den Namen einer offenen Zeile in der Ladenliste hakt den Artikel ab (er erscheint unter „Erledigt“) und öffnet den Bearbeiten-Dialog nicht.
- [x] **AC-2:** Ein Tipp auf den Namen einer erledigten Zeile hebt das Abhaken auf (der Artikel ist wieder offen) und öffnet den Bearbeiten-Dialog nicht.
- [x] **AC-3:** Ein Tipp auf das Kästchen löst genau einmal aus (kein doppeltes Umschalten durch Kästchen und Zeilentipp): Nach dem ersten Tipp zeigt die Zeile das Häkchen (Bild `checkmark`), nach dem zweiten nicht mehr; der Dialog öffnet nie. Das Kästchen hat kein eigenes Label; Tests greifen es über `app.cells.containing(.staticText, identifier: <Name>).buttons.firstMatch` an (wie `ShoppingRouteLearningUITests.checkbox(of:in:)`).
- [x] **AC-4:** Wischen nach links zeigt bei offenen Zeilen neben „Löschen“ und „Dringend“, bei erledigten Zeilen neben „Löschen“ einen Knopf „Bearbeiten“; Tipp darauf öffnet den Bearbeiten-Dialog für genau diesen Artikel. Ein voller Wisch löscht weiterhin (Löschen bleibt die äußere Aktion). Der Test deckt die offene Zeile ab, die erledigte Zeile wird im Durchlauf (AC-9) gezeigt.
- [x] **AC-5:** Lang drücken auf eine Zeile zeigt „Bearbeiten“ als ersten Eintrag des Kontextmenüs (offene und erledigte Zeilen, Kennung `item.action.edit`); Tipp darauf öffnet den Dialog. In geteilten Läden folgen darunter wie bisher die Zuweisungs-Einträge. (PO-Ausnahme 2026-10-30, override: Menü-Reihenfolge im geteilten Laden nur per Code belegt, keine Testdaten; Einzel-Laden getestet; Nachprüfung #236)
- [x] **AC-6:** Zeigt die Zeile „Preis?“ (Kategorie-Pauschale; im Test über den Zusatzartikel des Launch-Arguments `-shoppingRouteUnpricedItemForUITests`, weil alle übrigen Testartikel Katalogpreise haben), öffnet ein Tipp genau darauf den Bearbeiten-Dialog mit Preisfeld und hakt nicht ab.
- [x] **AC-7:** Das Kästchen bleibt für Bedienhilfen als Knopf erreichbar (in der Zugänglichkeits-Hierarchie als `button` innerhalb der Zeile, ohne Label, auffindbar wie in AC-3, automatisch geprüft). Zusätzlich trägt die Zeile die benannte VoiceOver-Aktion „Bearbeiten“; XCUITest kann benutzerdefinierte Aktionen nicht auslösen, deshalb wird diese Aktion im Durchlauf (AC-9) über den Accessibility Inspector des Simulators belegt (Beleg als Bild), nicht per Test. (PO-Ausnahme 2026-10-30, override: Kästchen als Knopf getestet; VoiceOver-Aktion „Bearbeiten“ nur im Code, nicht per XCUITest auslösbar; Nachprüfung #236)
- [x] **AC-8:** Das Abhaken per Zeilentipp läuft im Code über denselben Pfad wie das Kästchen (eine gemeinsame Funktion `performToggle`, Routen-Lernen, Live Activity, Haptik/Animation hängen an `toggle(item:)`). Automatisch belegt ist die Gleichheit des Pfads nur indirekt: Die Bestandstests `ShoppingRouteUITests`, `AddItemQuantitySuggestionUITests`, `LegacyLearnedPriceResetUITests` (Dialog über `UITestItemEditor.open`) und `ShoppingRouteLearningUITests` (Routen-Lernen über das Kästchen) bleiben grün. Routen-Lernen und Live Activity per Zeilentipp werden im Durchlauf (AC-9) belegt.
- [x] **AC-9:** Beweis im echten Durchlauf: Im Simulator mit dem Stand dieser Änderung werden Zeile antippen, Kästchen antippen, Wischen und Lang drücken einmal als Nutzer durchgespielt und belegt (Bildschirmfotos unter `docs/artifacts/feat-233-abhaken-per-tipp/`), einschließlich Beginn der Live Activity beim ersten Haken über den Zeilentipp und der VoiceOver-Aktion aus AC-7. (PO-Ausnahme 2026-10-30, override: 11 Fotos, Live Activity und Routen-Lernen belegt; VoiceOver-Beleg über den Accessibility Inspector fehlt; Nachprüfung #236)

## Dialog

### Runde 1
**Adversary:**
Frischer Lauf (adversary-test-output.txt): ItemRowTapUITests 7 Tests, 0 Fehler, alle passed.

AC-1 bewiesen: Zeilentipp laeuft ueber onTapGesture(perform: performToggle), Test tippt den Namen (staticText), erwartet Haken und kein "Speichern".
Code reference: SmartCart/Views/Components/ItemRow.swift:173

AC-2 bewiesen: erledigte Zeile nutzt dieselbe ItemRow, toggle(item:) verzweigt auf markPending; Test prueft Haken weg, kein Dialog.
Code reference: SmartCart/Views/Store/StoreDetailView.swift:1203

AC-3 bewiesen: Kaestchen bleibt eigener Button (Button(action: performToggle)); Test wartet nach dem Tipp 1 s und prueft in beide Richtungen, dass der Haken stabil bleibt (faengt Doppelausloesung). Abweichung zur Spec ("Bild checkmark" vs. Test "buttons[checkmark]"): akzeptabel, weil das Kaestchen ein Button mit Kennung checkmark ist; die Spec sollte beim Nachfuehren angepasst werden.
Code reference: SmartCart/Views/Components/ItemRow.swift:48

AC-4 bewiesen fuer die offene Zeile (Wischen, Bearbeiten, Loeschen vorhanden, Dialog zeigt Gouda). Code: trailing allowsFullSwipe, Loeschen steht VOR editButton, also bleibt Loeschen die aeussere Aktion; die erledigte Zeile hat editButton im selben Block. Der volle Wisch und die erledigte Zeile sind NICHT per Test belegt (Test zieht nur teilweise), nur per Code; der Durchlauf AC-9 muss beides zeigen.
Code reference: SmartCart/Views/Store/StoreDetailView.swift:461

AC-5 per Code bewiesen: editButton(for:) steht als erster Eintrag im contextMenu, offen (Zeile 903) und erledigt (Zeile 479), Kennung item.action.edit. Der Test beweist die REIHENFOLGE nicht (sucht irgendeinen Knopf mit Kennung oder Label "Bearbeiten"). Reihenfolge und erledigte Zeile gehen in den Durchlauf.
Code reference: SmartCart/Views/Store/StoreDetailView.swift:904

AC-6 OFFEN: Der Test beweist, dass ein Tipp auf den Knopf "Preis unbekannt..." den Dialog (Speichern) oeffnet und nichts abgehakt wird. Er beweist NICHT, dass das Preisfeld im Dialog steht (Spec: "Dialog mit Preisfeld"); expectEditor prueft nur "Speichern". Es fehlt auch der Nachweis, dass es der Dialog von Wunderkraut ist; die Haken-Pruefung laeuft bei offenem Sheet (Elemente dahinter eventuell nicht abfragbar, exists==false dann schwach).
Code reference: SmartCart/Views/Components/ItemRow.swift:204

AC-7 OFFEN: Kaestchen als Button (elementType == .button) bewiesen. Die VoiceOver-Aktion "Bearbeiten" (accessibilityAction) steht im Code, ist aber nicht belegt; Beleg kommt erst im Durchlauf. XCUITest findet das Kaestchen, das ist keine VoiceOver-Navigation.
Code reference: SmartCart/SmartCartApp.swift:373

AC-8 OFFEN: Gleicher Pfad im Code bewiesen (beide Wege rufen performToggle, dann toggle(item:) mit Routen-Lernen, Live Activity, Haptik). Bestandstests habe ich in diesem Lauf nicht ausgefuehrt (nur ItemRowTapUITests); der Beleg ist test-green-output.txt (24 Tests, 0 Fehler) des Implementierers. Routen-Lernen und Live Activity per ZEILENTIPP sind nicht belegt (nur Durchlauf).

AC-9 OFFEN: Durchlauf nicht erbracht; keine Bildschirmfotos, keine Live-Activity-Beobachtung, kein Accessibility-Inspector-Beleg.

Nachfragen an den Implementierer fuer Runde 2:
1. AC-6: Beleg, dass im geoeffneten Dialog das Preisfeld sichtbar ist (Test erweitern oder Durchlauf-Bild), und dass es Wunderkraut ist.
2. AC-5: Beleg fuer "Bearbeiten" als ERSTEN Eintrag (Durchlauf-Bild offene und erledigte Zeile).
3. AC-4: voller Wisch loescht weiter; erledigte Zeile mit Bearbeiten (Durchlauf-Bild).
4. AC-3: Spec-Wortlaut "Bild checkmark" an den Test (Knopf mit Kennung checkmark) angleichen oder begruenden.
5. AC-7/AC-8/AC-9: Durchlauf mit Zeilentipp, Live Activity beim ersten Haken, Routen-Lernen per Zeilentipp, VoiceOver-Aktion im Accessibility Inspector.
6. AC-8: Bestandsklassen auf diesem Stand frisch laufen lassen.
**Implementierer:**
Antworten zu den Nachfragen 1 bis 7 stehen in Runde 2 (siehe dort).
Zu 4 (AC-3): Spec sagt "Bild checkmark", tatsaechlich traegt der Kaestchen-Knopf selbst die Kennung checkmark (Label "Ausgewaehlt"); die Bedienhilfen verschmelzen das Bild mit dem Knopf. Gleichwertig; die Spec wird wegen der Freigabe-Bindung nicht mehr geaendert, die Abweichung ist hier festgehalten.

### Runde 2
**Adversary:**
Lauf: Gesamtlauf test-green-output.txt, 28 Tests, 0 Fehler, TEST SUCCEEDED (Zeile 2733 bis 2747); mein Lauf ItemRowTapUITests aus Runde 1 war 7/7 gruen. Produktcode seit Runde 1 unveraendert, nur ItemRowTapUITests.swift erweitert (11 Tests). Ich habe die Fotos 03, 04, 08, 09, 11 gelesen.

AC-6 jetzt bewiesen: der Test prueft Namensfeld Wunderkraut und Preisfeld "Preis (optional)", schliesst den Dialog ueber Abbrechen und prueft erst dann bei allen vier Zeilen "kein Haken" (behebt meine Sheet-Kritik). Foto 11 zeigt Wunderkraut mit leerem Preisfeld.
Code reference: SmartCart/SmartCartApp.swift:373

AC-4 jetzt bewiesen: testSwipeLeftOnCompletedRowShowsEditAndDelete (erledigte Zeile Brot, Dialog zeigt Brot) und testFullSwipeLeftStillDeletes (Gouda weg, kein Dialog, Apfel und Brot bleiben). Foto 08 zeigt Bearbeiten und Loeschen auf der erledigten Zeile. Die Loeschen-Aktion steht im Code als erste trailing-Aktion.
Code reference: SmartCart/Views/Store/StoreDetailView.swift:461

AC-1 bis AC-3 bleiben bewiesen (Code und Tests unveraendert). Die Zeilentipp-Aktion haengt am HStack, das Kaestchen bleibt eigener Button.
Code reference: SmartCart/Views/Components/ItemRow.swift:173

AC-5 TEILWEISE, bewusst offen: Der Helfer expectEditFirstInContextMenu ist in diesem Testladen schwach: das Menue enthaelt nur den einen Eintrag Bearbeiten (Foto 09 bestaetigt: ein Eintrag), das Minimum von minY ueber ein Element ist tautologisch wahr. Bewiesen ist damit nur, dass Bearbeiten im Menue steht (offen und erledigt), Kennung und Label stimmen und der Dialog sich oeffnet. "Erster Eintrag" vor den Zuweisungs-Eintraegen in geteilten Laeden ist nur per Code belegt (editButton steht vor dem if store.shareID-Block).
Code reference: SmartCart/Views/Store/StoreDetailView.swift:904

AC-7 TEILWEISE, offen: Kaestchen als Button per Test bewiesen. Die VoiceOver-Aktion "Bearbeiten" ist weiterhin nur im Code (accessibilityAction) vorhanden, per XCUITest nicht belegbar, Accessibility-Inspector-Beleg fehlt. Ehrliche offene Grenze.

AC-8 TEILWEISE, offen: Gleicher Code-Pfad belegt (performToggle fuer Kaestchen und Zeilentipp; toggle(item:) mit recordCheckOff, Live Activity, Haptik); Bestandsklassen im Gesamtlauf gruen. Routen-Lernen per Zeilentipp ist weder per Test noch per Foto belegt. Live Activity per Zeilentipp ist belegt: Foto 03 zeigt die Dynamic Island mit Fortschritt 1/3 und Foto 04 die Live Activity Wegeladen, Gouda, 1/3 nach dem ersten Haken ueber den Zeilentipp (Foto 02). Einschraenkung: Die Systemfrage "Live-Aktivitaeten erlauben?" ist offen geblieben; die Aktivitaet war trotzdem sichtbar. Der Walkthrough-Test prueft die Live Activity nicht per Assertion, sie ist nur fotografiert.
Code reference: SmartCart/Views/Store/StoreDetailView.swift:1203

AC-9 TEILWEISE, offen: Durchlauf mit 11 Fotos ist erbracht (Zeilentipp, Kaestchen, Wischen offen und erledigt, Lang druecken, Preis-Dialog, Live Activity). Es fehlen laut Spec die VoiceOver-Aktion im Accessibility Inspector und der Nachweis Routen-Lernen per Zeilentipp. Hinweis: der Durchlauf ist ein Test, der Fotos erzeugt, kein Lauf mit Beobachtung durch einen Menschen; die Fotos selbst sind echt (Simulator, Statusleiste 14:09 bis 14:10).

Weitere Befunde, keine Defekte: (1) Spec-Wortlaut AC-3 "Bild checkmark" weicht ab; vom Implementierer begruendet, akzeptiert. (2) Die neuen Tests haben ausser dem Menue-Helfer keine tautologischen Stellen gefunden; closeSwipeActions tippt die erste Zelle der Liste und verlaesst sich auf deren Reihenfolge (nur Walkthrough, Fotos).
Ein echter Defekt im Produktcode wurde nicht gefunden.

Urteil: AMBIGUOUS. Fehlt: (a) Reihenfolge von Bearbeiten gegenueber Zuweisungs-Eintraegen im geteilten Laden (AC-5), (b) VoiceOver-Aktion Bearbeiten im Accessibility Inspector (AC-7, AC-9), (c) Routen-Lernen per Zeilentipp (AC-8, AC-9). Alles drei ist im Code angelegt, aber nicht belegt; die Spec verlangt (b) und (c) im Durchlauf.
**Implementierer:**
1. AC-6: testPricePromptOpensEditorWithoutChecking prueft Namensfeld Wunderkraut und Preisfeld "Preis (optional)" (EditItemView.swift:104), schliesst ueber Abbrechen und prueft danach fuer alle vier Zeilen "kein Haken". Fotos durchlauf-11-preis-dialog.png und durchlauf-10-wunderkraut-preis-fehlt.png.
2. AC-5: Helfer expectEditFirstInContextMenu misst, dass Bearbeiten die kleinste frame.minY hat, fuer offene Zeile (Gouda) und erledigte Zeile (testLongPressOnCompletedRowShowsEditFirst). Grenze: Testladen nicht geteilt, Menue hat nur einen Eintrag; Reihenfolge gegenueber Zuweisungs-Eintraegen nur per Code. Foto durchlauf-09-gouda-kontextmenue.png.
3. AC-4: testSwipeLeftOnCompletedRowShowsEditAndDelete und testFullSwipeLeftStillDeletes. Fotos durchlauf-07 und durchlauf-08.
4. AC-3: siehe Runde 1, Spec bewusst nicht mehr geaendert.
5. AC-9: testWalkthroughWithScreenshots mit 11 Fotos; Live Activity startet beim ersten Haken per Zeilentipp (Fotos 03 und 04); Systemfrage "Live-Aktivitaeten erlauben?" im Test nicht beantwortet.
6. AC-7 VoiceOver-Aktion: per XCUITest nicht belegbar (accessibilityCustomActions leer), nur im Code; offene Grenze.
7. AC-8: Routen-Lernen per Zeilentipp nicht per Test oder Foto belegt, nur im Code; Bestandsklassen im Gesamtlauf gruen.

### Runde 3
**Adversary:**
Beweislage: neuer Test testRouteIsLearnedFromRowTaps (ItemRowTapUITests.swift 277 bis 297), lernen-rot.txt, lernen-gruen.txt, test-green-lernen-output.txt (14 Tests, 0 Fehler, TEST SUCCEEDED, ItemRowTapUITests 12 plus ShoppingRouteLearningUITests 2). Kein eigener Lauf, wie angewiesen.

Vergleich mit ShoppingRouteLearningUITests.testRouteIsLearnedFromSlowCheckOffs: gleiches Szenario. Gleiche Argumente (-hasCompletedOnboarding, -seedShoppingRouteForUITests, -shoppingRouteNoLearnedModelForUITests, -routeCheckOffStepSecondsForUITests 5), gleiche Ausgangslage-Pruefung (Apfel, Brot, Gouda), Haken in der Reihenfolge Gouda, Brot, Apfel, Neustart ohne Seed mit -routeClockOffsetMinutesForUITests 31, Haken zuruecknehmen, Erwartung Gouda, Brot, Apfel. Einziger Unterschied: Abhaken per Tipp auf den Namen (tapName) statt aufs Kaestchen; Zuruecknehmen ebenfalls per Zeilentipp. Das prueft genau die Luecke: Zeilentipp lernt die Route.

Nicht tautologisch: Die Ausgangslage zeigt die feste Reihenfolge, das Ergebnis die gelernte; die Gegenprobe lernen-rot.txt scheitert mit tatsaechlich [Gouda, Brot, Apfel] gegen absichtlich falsch erwartetes [Apfel, Brot, Gouda] (Zeile 312 der Testdatei), die richtige Erwartung ist gruen. Damit unterscheidet die Assertion gelernt von nicht gelernt. Der Test haengt an Gouda/Brot/Apfel als Namen; die Zeilentipps laufen ueber denselben performToggle wie das Kaestchen, das ist die zu beweisende Eigenschaft.

Helfer unveraendert fuer Bestandsaufrufe: openedStore hat Standardwerte (seeded true, extraArguments leer) und liefert dann dieselben Argumente wie vorher; waitForOrder ist neu und wird nur vom neuen Test benutzt. Der Diff trifft nur ItemRowTapUITests.swift, ShoppingRouteLearningUITests ist unberuehrt und im Lauf gruen.
Code reference: SmartCart/Views/Store/StoreDetailView.swift:1203
Code reference: SmartCart/Views/Components/ItemRow.swift:173
Code reference: SmartCart/SmartCartApp.swift:373

AC-8 jetzt bewiesen und abgehakt: gleicher Code-Pfad im Code, Routen-Lernen per Zeilentipp durch den neuen Test, Live Activity per Foto 03 und 04, Bestandsklassen gruen.

Offen bleiben genau zwei benannte Grenzen (vom PO am 2026-10-30 so bewertet, Folgeticket #236):
Grenze A (AC-7, AC-9): VoiceOver-Aktion "Bearbeiten" ist per XCUITest nicht ausloesbar und nur im Code belegt (ItemRow.swift, accessibilityAction); der Accessibility-Inspector-Beleg aus der Spec fehlt.
Grenze B (AC-5): Reihenfolge von "Bearbeiten" vor den Zuweisungs-Eintraegen im geteilten Laden ist nur per Code belegt (editButton steht vor dem if store.shareID-Block); es gibt keine Testdaten fuer einen geteilten Laden, der Menue-Reihenfolge-Test ist im Einzel-Laden trivial.
Fuer AC-9 ist der Durchlauf sonst erbracht; er bleibt wegen Grenze A offen. Ein Defekt im Produktcode liegt nicht vor.
Urteil: AMBIGUOUS mit genau diesen zwei Grenzen; ich halte sie nicht fuer gedeckt und vergebe daher kein VERIFIED.
**Implementierer:**
Lernen per Zeilentipp (Luecke 1) per Test geschlossen: testRouteIsLearnedFromRowTaps (gleiches Szenario wie testRouteIsLearnedFromSlowCheckOffs, Abhaken per Tipp auf den Namen). Gegenprobe lernen-rot.txt (falsche Erwartung scheitert, tatsaechlich Gouda, Brot, Apfel), lernen-gruen.txt (richtige Erwartung gruen), test-green-lernen-output.txt (14 von 14 gruen). Die Helfer waitForOrder sowie die Vorgabeparameter seeded und extraArguments von openedStore aendern bestehende Aufrufe nicht. PO-Bewertung 2026-10-30: Luecke 2 (VoiceOver-Aktion) und Luecke 3 (Menue-Reihenfolge im geteilten Laden) bleiben als ausdrueckliche Grenzen, Folgeticket #236.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict: AMBIGUOUS

## Geprüfte Dateien

- sha256:677455b3f55097dbf226707c9475e924f1f17061eca3b7e48a05a848e2492600  SmartCart/SmartCartApp.swift
- sha256:e282216ba0d4936996d9caefeb8ed4628402df02ff2bcdf0bbc7d9b765dc757a  SmartCart/Views/Components/ItemRow.swift
- sha256:0eb43e9aac8284b59a3feaa9806d5950013a533124f2031f9d8a8fe51bf5fef3  SmartCart/Views/Store/StoreDetailView.swift

## Prüfbasis

- base: a7097ce68021748cc95044ad7101830771e1c541
- blob:5aa11f83fd407278f2cbbff0c7704fb90e247924  SmartCart/SmartCartApp.swift
- blob:afc4513f313488614303cfb266bd29449ea8e95f  SmartCart/Views/Components/ItemRow.swift
- blob:47e1253dd876b090d1d9bed48b30c9b77bdecc4d  SmartCart/Views/Store/StoreDetailView.swift

## Geprüfte Dateien

- sha256:677455b3f55097dbf226707c9475e924f1f17061eca3b7e48a05a848e2492600  SmartCart/SmartCartApp.swift
- sha256:e282216ba0d4936996d9caefeb8ed4628402df02ff2bcdf0bbc7d9b765dc757a  SmartCart/Views/Components/ItemRow.swift
- sha256:0eb43e9aac8284b59a3feaa9806d5950013a533124f2031f9d8a8fe51bf5fef3  SmartCart/Views/Store/StoreDetailView.swift

## Prüfbasis

- base: a7097ce68021748cc95044ad7101830771e1c541
- blob:5aa11f83fd407278f2cbbff0c7704fb90e247924  SmartCart/SmartCartApp.swift
- blob:afc4513f313488614303cfb266bd29449ea8e95f  SmartCart/Views/Components/ItemRow.swift
- blob:47e1253dd876b090d1d9bed48b30c9b77bdecc4d  SmartCart/Views/Store/StoreDetailView.swift
