# Adversary Dialog — test-98-durchgang-6-laden-einrichtung
Spec: docs/specs/ui-tests/test-98-durchgang-6-laden-einrichtung.md
Datum: 2026-10-13 06:14

## Checkliste
- [x] AC-1: Deaktivieren per Wischgeste: Der Laden verschwindet aus „Aktiv“, steht unter „Inaktiv“, und seine Kachel ist nach dem Schließen des Sheets von der Startseite verschwunden, die des anderen Ladens bleibt (Test S1). Nutzen: Der Nutzer kann einen Laden ausblenden und die Startseite folgt sofort; bisher hat das nie ein Test gesehen.
- [x] AC-2: Aktivieren per Wischgeste macht AC-1 rückgängig: Der Laden steht wieder in „Aktiv“, „Inaktiv“ verschwindet, die Kachel ist zurück (Test S2).
- [x] AC-3: Löschen nur für inaktive Läden und mit Rückfrage: Wischen → „Löschen“ zeigt „Markt löschen?“ mit dem Ladennamen; „Abbrechen“ lässt den Laden stehen; Bestätigen mit „Löschen“ entfernt ihn aus der Liste und seine Kachel von der Startseite, der andere Laden bleibt (Test S3). Nur gesäte Läden im Test-Simulator (Restock-Validate). Offene Grenze: „Teilen beenden“ bei geteilten Läden ungeprüft.
- [x] AC-4: Eigenen Laden hinzufügen: „Hinzufügen“ ist bei leerem Namen gesperrt; mit Namen entsteht die Zeile in „Aktiv“ und nach dem Schließen die Kachel auf der Startseite (Test S4). Emoji und Farbe sind nicht bedient.
- [x] AC-5: Besuchshäufigkeit ändern: Die neue Stufe steht im Untertitel der Zeile und im Label der Kachel auf der Startseite (Test S5).
- [x] AC-6: Reihenfolge ziehen: Im Modus „Bearbeiten“ vertauscht das Ziehen auf dem Verschiebegriff die Läden; nach „Fertig“ gilt die Umkehrung der vorher gelesenen Reihenfolge in der Liste (Test S6).
- [x] AC-7: Die gezogene Reihenfolge kommt auf der Startseite als Kachelreihenfolge an und überlebt einen App-Neustart ohne Seed-Argument (Test S6). Nutzen: `sortIndex` wird wirklich gespeichert und gelesen; die Messung vom 2026-10-12 hat nur das Ziehen selbst belegt.
- [x] AC-8: Der Reihenfolge-Test liest die Startreihenfolge vorher und prüft die Umkehrung; er nimmt keine feste Reihenfolge an (beide Seed-Läden `sortIndex` 0). Die Reihenfolge wird über `app.cells.staticTexts` gelesen, nicht über `app.staticTexts`.
- [x] AC-9: Emoji-Sheet: „Emoji ändern“ öffnet und schließt mit „Abbrechen“ ohne Änderung (Test S7). Die Emoji-Eingabe und der Farbwähler sind ungeprüft und als offene Grenze benannt.
- [x] AC-10: Zeilenschalter: Der Schalter `Toggle("")` einer Zeile wird zum Deaktivieren/Aktivieren bedient, **wenn** er in TDD-RED je Zeile eindeutig findbar ist (`cell.switches.firstMatch`); sonst wird nur der Wischweg getestet und der Schalter im Ticketkommentar als offene Grenze genannt. Die Entscheidung steht in der RED-Protokollzeile des Tests.
- [x] AC-11: Echter Weg statt Nachbau: Alle Tests bedienen sichtbare Elemente (Beschriftungen, Wischgesten, Ziehgeste). Läden, Reihenfolge und Frequenzen werden vom Test nicht von Hand gesetzt; erlaubt sind nur der bestehende Seed `-seedQuickAddAssignmentForUITests` als Ausgangszustand und sein Aufräum-Argument.
- [x] AC-12: Aufräumen: `tearDown()` startet die App mit `-clearQuickAddAssignmentSeedForUITests`; danach gibt es keine Läden und Artikel aus dem Test (auch „Testmarkt“ aus S4 ist weg). Nachweis: Die Bestandssuiten (insbesondere `QuickAddAssignmentUITests`, `RestockUITests`, `OnboardingUITests`) laufen im gemeinsamen Lauf mit der neuen Klasse grün. Der Lauf zählt: „Executed 0 tests“ oder ein Abbruch ist kein Grün; die Testzahl wird geprüft.
- [x] AC-13: Stabilität: Warten nur zustandsbasiert (`waitUntilHittable`, `waitForLabel(contains:)`, `UITestWait.defaultTimeout`), keine 5-s-Fristen. Nachweis: mindestens drei Läufe der neuen Klasse hintereinander grün, davon mindestens einer unter Rechenlast (Memory „Leerer UI-Test-Start nur unter Last“; Messung des Ziehens: 4/4 vollständig, 5/5 im Ziehschritt, auch unter Last).
- [x] AC-14: Der Bestandstest `RestockUITests.swift` Zeilen 160–200 bleibt unverändert und grün.
- [x] AC-15: Umfang und Produktcode: Kein Produktcode im Diff (`SmartCart/` unverändert); ≤ 5 Dateien (geplant 3: Test, `project.pbxproj`, Spec), ca. +160–190 LoC. Überschreitung von ±250 LoC wird vor dem Weiterbau gemeldet. Wird ein Produktfehler gefunden, wird er nur mit Wort des PO mitgefixt.
- [x] AC-16: Offene Grenzen sind in Spec, Testkommentar (Kopf der Klasse) und Ticketkommentar benannt: „Teilen beenden“ beim Löschen geteilter Läden (CloudKit), Emoji-Eingabe, Farbwähler, ggf. Zeilenschalter (AC-10), Punkte 5 und 6 aus #98. Keine Zusage dieses Durchgangs lautet „Laden-Einrichtung geprüft“ ohne diese Einschränkungen.

## Dialog

### Runde 1
**Adversary:**
Vorläufiges Urteil AMBIGUOUS (Risiko hoch, nur gelesen, keine Simulatorläufe). Belegbasis: Diff Test 298 Zeilen, Produkt +4 Zeilen.
Code reference: SmartCart/Views/Settings/StoreSetupView.swift:116 (`onChange(of: allStores.map(\.isActive))`)
Code reference: RestockUITests/StoreSetupUITests.swift:126 (S1)
- AC-1: AKZEPTIERT (S1 prüft Inaktiv-Zeile, nicht mehr in Aktiv, Kachel weg; RED→GREEN mit test-red-output.txt und s1-doppelte-zeile.png). NACHFRAGE: Mutationsprobe fehlt.
- AC-2: AKZEPTIERT; NACHFRAGE: „Lidl wieder in Aktiv“ nicht ausdrücklich geprüft.
- AC-3: NACHFRAGE (Spec verlangt Knopf „Abbrechen“, iPhone zeigt Einblendmenü; Spec nicht nachgetragen; Mutationsprobe fehlt).
- AC-4: AKZEPTIERT. AC-5: AKZEPTIERT. AC-6: AKZEPTIERT mit Vorbehalt (ein Ziehweg).
- AC-7: NACHFRAGE (Neustart nur mit Home-Taste; `onMove` ohne `save()`, direkter Abbruch verlor die Reihenfolge 2/2).
- AC-8: AKZEPTIERT. AC-9: AKZEPTIERT.
- AC-10: NACHFRAGE (Zeilenschalter von keinem Test bedient, keine Entscheidungszeile).
- AC-11: AKZEPTIERT. AC-12: AKZEPTIERT mit Vorbehalt (Aufräumen von „Testmarkt“ nicht direkt bewiesen).
- AC-13: AKZEPTIERT mit Vorbehalt (Last in Lauf 4 nicht belegt; zweiter Tipp mit 10-s-Frist, in den Läufen nie gebraucht).
- AC-14: AKZEPTIERT (Diff `RestockUITests.swift` leer, Bestandssuite im gemeinsamen Lauf grün).
- AC-15: DISPROVEN gegenüber dem Wortlaut (Produktcode geändert; PO-Wort nicht als Datei belegt; LoC über 250).
- AC-16: NACHFRAGE (Klassenkommentar nennt Zeilenschalter und Persistenzgrenze nicht).
Findings: F001 HIGH edge_case (`onMove` ohne `context.save()`, Test umgeht mit Home-Taste; Code reference: SmartCart/Views/Settings/StoreSetupView.swift:32); F002 MEDIUM spec_violation (Spec widerspricht Stand: AC-15, „Nicht geändert“, AC-3 „Abbrechen“); F003 MEDIUM anti_pattern (Mutationsproben (a)–(c) der Spec nicht gelaufen); F004 MEDIUM spec_violation (AC-10 Schalter nicht bedient, keine Entscheidungszeile); F005 LOW (Aufräumen „Testmarkt“ nicht direkt belegt); F006 LOW (Last von Lauf 4 nicht belegt); F007 LOW (zweiter Tipp und 10-s-Frist können Fehler verdecken).
Forderungen für Runde 2: (1) Zeitstempel der Läufe jünger als die letzte Änderung; (2) F001 `save()` oder AC-7 einschränken und überall nennen; (3) Mutationsproben (b) und (c) mit RED-Protokoll; (4) Zeilenschalter bedienen oder Nicht-Findbarkeit belegen; (5) PO-Wort zitieren, Spec-Nachtrag oder offene Grenze, LoC-Überschreitung melden; (6) Aufräumbeweis „Testmarkt“, Last von Lauf 4 belegen; (7) S2: „Lidl in Aktiv“ ausdrücklich prüfen; (8) Klassenkommentar um Zeilenschalter und Persistenzgrenze ergänzen.
**Implementierer:**
Entscheidungen des PO (über das Auswahlwerkzeug, sinngemäß): 2026-10-12 „Jetzt mitfixen (Empfohlen)“ für den Produktfehler „deaktivierter Laden steht doppelt“; 2026-10-13 „Mitfixen (Empfohlen)“ für F001 (`onMove` speichert sofort). Umsetzung der Forderungen in Runde 2: save() in `onMove`, Home-Umweg im Test entfernt (S6 beendet die App direkt); S2 prüft „Lidl in Aktiv“; neuer Test S8 bedient den Zeilenschalter; Klassenkommentar ergänzt; Mutationsproben (b), (c), (d) mit RED-Protokoll; Lauf unter Last mit Lastnachweis, Aufräumbeweis „Testmarkt“ und frische Läufe nach der letzten Änderung folgen. Spec-Nachtrag (AC-3, AC-15, Dateiliste, Umfang) und LoC-Meldung: siehe Runde 2 und Freigabe-Hinweis an den PO.

### Runde 2
**Adversary:**
Nur gelesen, keine Simulatorläufe; Zahlen selbst per grep nachgezählt. Forderungen (1)–(8) aus Runde 1: (1) Zeitstempel ERFÜLLT (Läufe 10:06–13:45, letzte Änderung Test 09:47:04, Produkt 08:20:10); (2) F001 ERFÜLLT (`save()` in `onMove`, Test beendet die App direkt, Mutation (d) rot); (3) Mutationen (b), (c), (d) ERFÜLLT (alle rot, zurückgenommen, `git diff --stat -- SmartCart` nur +7 Zeilen; bei (c) nur Timeout ohne Assertion-Meldung, schwächer, aber Beleg); (4) Zeilenschalter ERFÜLLT (S8, Wert „1“/„0“, Inaktiv-/Aktiv-Zeile, Kachel, Rückweg); (5) TEIL-ERFÜLLT (PO-Worte im Dialog zitiert, Spec-Nachtrag und LoC-Meldung stehen aus, nur der PO kann das lösen); (6) ERFÜLLT (0 Läden/0 Artikel nach S4, Lastprotokoll mit sechs `yes`-Prozessen bei 100 %); (7) ERFÜLLT (S2 prüft „Lidl in Aktiv“); (8) ERFÜLLT (Klassenkommentar Zeilen 10–13).
Code reference: SmartCart/Views/Settings/StoreSetupView.swift:39 (`try? context.save()` in `onMove`)
Code reference: SmartCart/Views/Settings/StoreSetupView.swift:119 (`onChange(of: allStores.map(\.isActive))`)
Code reference: RestockUITests/StoreSetupUITests.swift:111 (`swipeAndTap`, Warten auf Stillstand, höchstens eine zweite Geste mit Messzeile)
Code reference: RestockUITests/StoreSetupUITests.swift:185 (S8, Zeilenschalter)
AC-1 bis AC-14 und AC-16: CONFIRMED. AC-15: DISPROVEN gegenüber dem Wortlaut (Produktcode, Dateiliste, Umfang) — Spec-Nachtrag und LoC-Meldung mit PO-„override“ stehen aus.
Zweite Wischgeste: Messzeile vorhanden; in den 5 grünen Läufen 0 zweite Wischgesten; ein zweiter Tipp auf „Verwalten“ (stabilitaet-3.txt:109, 10,8 s, Last 72), protokolliert, kein stilles Verdecken.
Findings: F-R2-1 LOW edge_case (zweite Geste auf bereits geöffnete Zeile könnte Voll-Wisch auslösen; Abhilfe `button.exists` vor der zweiten Geste; theoretisch, nicht beobachtet); F-R2-2 LOW anti_pattern (feste 10-s-Frist in `openSetup`, mit Messzeile und Kommentar begründet); F-R2-3 LOW spec_violation (Produktcode laut AC-15; PO-Wort 2026-10-12 und 2026-10-13, nur der Spec-Nachtrag fehlt).
Proven points: 15/16. Urteil: AMBIGUOUS (nur wegen AC-15/PO-Punkten, Code und Tests stimmen).
**Implementierer:**
Läufe nach der letzten Änderung: `runde3/stabilitaet-1.txt`, `-2.txt`, `runde3b/stabilitaet-3.txt`, `-4-unter-last.txt` je 8/8 grün, `runde3b/gemeinsamer-lauf.txt` 27 Tests ohne Fehler, `runde3/aufraeumen-speicher.txt` 0 Läden/0 Artikel. Vorgeschichte: `vor-runde3/runde2-rot` (S2, erste Wischgeste ging verloren, darauf Korrektur in `swipeAndTap`); zwei Läufe in `runde3` fielen durch Simulator-Boot-Timeout bei fremder Rechnerlast (~300) aus und wurden in `runde3b` wiederholt. F-R2-1 bleibt bewusst offen (nicht beobachtet; eine Änderung würde alle Nachweisläufe entwerten); F-R2-2 durch Messzeile abgedeckt. Der Spec-Nachtrag (AC-3 Einblendmenü, AC-10, AC-15, S6, S8) und die Meldung der Umfangs-Überschreitung (Test ca. 300 Zeilen, Produkt +7, pbxproj; Spec ≤ +190 / ±250) liegen beim PO: getipptes „override“ nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS — Code und Tests belegt (15/16 Punkte); einziger Grund war AC-15 (Spec-Wortlaut „kein Produktcode“, Dateiliste, Umfang). Auflösung durch den PO: getipptes „override“ am 2026-10-13; der Spec-Nachtrag (Abschnitt „Nachtrag 2026-10-13“, Punkte 1–6, alle Stellen angepasst) und ein neues, an die Spec gebundenes PO-Briefing liegen vor. Schlusslauf nach dem Nachtrag: `runde4b/schlusslauf.txt`, 27 Tests, 0 Fehler, TEST SUCCEEDED (erster Versuch `runde4/schlusslauf.txt`: 26/27, ein Bestandstest `QuickAddAssignmentUITests.testQuantityAndUnitShownInList` rot an fester 10-s-Frist beim Tastaturschließen bei ruhiger Last; die neue Klasse war 8/8 grün; im Ticketkommentar zu nennen, Folgearbeit #118).

## Geprüfte Dateien

- sha256:acf707ca0a28dea60dad2c0e31373f236f2074ea251551eb66045bbe646d4a9c  RestockUITests/StoreSetupUITests.swift
- sha256:f7a22182d5bacadb308efa63439c97d697b3499b82916fa827d00f009750f0ad  SmartCart/Views/Settings/StoreSetupView.swift

## Prüfbasis

- base: f606902bf86facb7b1078c466e6a45898e70cba0
- blob:c19bf21b5b251752d321ca2a8b4e2e14a7348e11  RestockUITests/StoreSetupUITests.swift
- blob:3ebf6b8d42278884a9e01ca3c3099f4364611b46  SmartCart/Views/Settings/StoreSetupView.swift

## Geprüfte Dateien

- sha256:acf707ca0a28dea60dad2c0e31373f236f2074ea251551eb66045bbe646d4a9c  RestockUITests/StoreSetupUITests.swift
- sha256:f7a22182d5bacadb308efa63439c97d697b3499b82916fa827d00f009750f0ad  SmartCart/Views/Settings/StoreSetupView.swift

## Prüfbasis

- base: f606902bf86facb7b1078c466e6a45898e70cba0
- blob:c19bf21b5b251752d321ca2a8b4e2e14a7348e11  RestockUITests/StoreSetupUITests.swift
- blob:3ebf6b8d42278884a9e01ca3c3099f4364611b46  SmartCart/Views/Settings/StoreSetupView.swift

## Geprüfte Dateien

- sha256:acf707ca0a28dea60dad2c0e31373f236f2074ea251551eb66045bbe646d4a9c  RestockUITests/StoreSetupUITests.swift
- sha256:f7a22182d5bacadb308efa63439c97d697b3499b82916fa827d00f009750f0ad  SmartCart/Views/Settings/StoreSetupView.swift

## Prüfbasis

- base: f606902bf86facb7b1078c466e6a45898e70cba0
- blob:c19bf21b5b251752d321ca2a8b4e2e14a7348e11  RestockUITests/StoreSetupUITests.swift
- blob:3ebf6b8d42278884a9e01ca3c3099f4364611b46  SmartCart/Views/Settings/StoreSetupView.swift
