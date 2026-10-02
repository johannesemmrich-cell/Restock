# Adversary-Dialog: bon-namenserkennung-regelwerk-14 (Issue #14)

Spec: `docs/specs/services/receipt-resolution-stats.md`
Prüfer: implementation-validator, Runde 1 und 2 (Stand: gestagter Diff gegen 928c16c)

Selbst gelaufen: `RestockTests/ReceiptResolutionStatsTests` (18 Tests, 0 Fehler, TEST SUCCEEDED, Testfälle einzeln gelistet).
Nicht selbst gefahren, aus Artefakten übernommen: Unit gesamt 395 grün, `ReceiptResolutionStatsUITests` 3 Läufe je 4 Tests grün, `ReceiptReviewUITests` 22 grün. Gesamte UI-Suite im gemeinsamen Lauf: nicht gelaufen.

### Runde 1: Code gegen die Spec

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:52-55
  Evidence: `enum ReceiptResolutionStage: String, Codable, CaseIterable` mit genau den sieben Fällen. Test `testStageHasExactlyTheSevenCasesAndStringRawValues` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:117-132
  Evidence: Stufen werden in genau den vier Zweigen der bestehenden if/else-if-Kette gesetzt. Vier Einzeltests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:199
  Evidence: Jeder Index ohne Stufe wird nach dem KI-Block `.rawText`. Test `testUnresolvedLineWithoutAIKeepsRawTextAndGetsRawTextStage` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:198
  Evidence: `.ai` nur für `aiResolvedIndices`; `resolvedByAI` wird aus derselben Menge befüllt (:211). Im Simulator nur über `testTallyCountsAIStage` abgedeckt (Grenze laut Spec).
  Status: CONFIRMED (Simulator-Grenze laut Spec)

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:116-132
  Evidence: Der Diff der Datei ist rein additiv (Stufen je Zweig, erweitertes Rückgabe-Tupel, zwei Schleifen nach dem KI-Block, `stage:` im Konstruktor). Reihenfolge, Bedingungen, Namen, IDs, Fallback-Prüfung (:150-160), Vorschläge und Schwellen unberührt. Bestandstests grün. Kein eigener Vorher/Nachher-Vergleichssatz (siehe F003).
  Status: CONFIRMED (indirekt, siehe F003)

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:48
  Evidence: `var stage: ReceiptResolutionStage? = nil` ist optional, synthetisierte Decodable nutzt `decodeIfPresent`. Tests für Alt-Payload und Round-Trip grün. Datei liegt in beiden Targets, Enum steht in derselben Datei.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:49-51
  Evidence: `guard let stage = line.stage else { continue }`, danach `total += 1` genau einmal je Zeile. Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:62-64
  Evidence: `changed` nur im Zweig `isIncluded` und bei Namensabweichung nach Trimmen und `lowercased()`. Preis und Menge fließen nicht ein. Tests grün.
  Status: CONFIRMED (Randfall siehe F004)

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:52-55
  Evidence: `if !isIncluded {deselected} else if differs {changed}`, die Zweige sind disjunkt, `changed + deselected <= total` gilt konstruktiv. Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:26-37
  Evidence: `record` liest, addiert, schreibt zurück. Test `testRecordAddsUpAcrossReceiptsAndSurvivesNewInstance` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:21-23
  Evidence: `counts(for:)` liefert `Counts()` für nie gezählte Stufen, `reset` entfernt den Schlüssel. Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:9-11
  Evidence: Gespeichert wird `[String: Counts]` mit drei Int-Feldern. Kein print, os_log oder Logger in Stats oder StatsView (grep leer). Test `testStoredValueContainsNoLineNames` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-13 (genau ein Aufruf je Speichern, alle Zeilen)
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:650-652
  Evidence: `record(parsedLines)` ist die erste Anweisung von `save()`, vor dem Filter auf `isSavable`, kein `return` davor. `save()` hat nur den Speichern-Knopf als Aufrufer (:325), Abbrechen (:321) ruft nur `dismiss()`. Kein Test für "Abbruch zählt nicht", nur der Code-Pfad (siehe F002).
  Status: CONFIRMED (Code-Pfad, kein dedizierter Test)

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:164-165
  Evidence: `stage` und `resolvedName` an allen drei Konstruktionsstellen gesetzt (:164-165, :248-250, :640-642). `mergeAIReresolution` schreibt nur die übergebenen Indizes. Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/Views/Settings/SettingsView.swift:268-272
  Evidence: NavigationLink im `developerMode`-Block direkt nach "Nachkauf-Statistik". UI-Test `testLinkIsNotShownOutsideDeveloperMode` in 3 Läufen grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: SmartCart/Views/Settings/ReceiptResolutionStatsView.swift:22-25
  Evidence: `ForEach` über `allCases` (7 Zeilen), Identifier `resolutionStage.<raw>` mit `.total/.changed/.deselected`, Summenzeile "all" aus der Summe der sieben (:14-19). Bei gesamt = 0 "0 (–)" (:100), keine Division durch 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-17 (inhaltlich, mit Abweichung F001)
  Code reference: SmartCart/Views/Settings/ReceiptResolutionStatsView.swift:36-55
  Evidence: `.devFeedback(context: "Bon-Auflösung")` auf dem äußersten View (:55). Zurücksetzen destruktiv mit Identifier `resolutionStatsResetButton`, Bestätigung mit "Abbrechen" und "Zurücksetzen", danach `reset()` und Neuzeichnen. UI-Test grün.
  Status: CONFIRMED mit Abweichung

Confirmation:
  AC: AC-18
  Code reference: SmartCart/SmartCartApp.swift:406-432
  Evidence: Seed mit den Stufen KI, Abgehakt, Abgehakt, Historie. `testSavedReceiptIsCountedPerStageWithChangedAndDeselected` prüft nach echtem Speichern all.total = 4, ai.changed = 1, history.deselected = 1, completed.changed = 0. Aufräumargument `-clearReceiptResolutionStatsForUITests` ruft `reset()` (:226-232, nur DEBUG).
  Status: CONFIRMED

Confirmation:
  AC: AC-20
  Code reference: Restock.xcodeproj/project.pbxproj:72-73
  Evidence: Jede der vier neuen Dateien steht in allen vier Abschnitten, Targets stimmen. Share Extension kompiliert `ReceiptResolutionService.swift` unverändert mit (:112). Build und Testlauf von App und Test-Target erfolgreich.
  Status: CONFIRMED

Confirmation:
  AC: Scope (kein Verhaltens-Drive-by)
  Code reference: SmartCart/Services/ReceiptResolutionService.swift:116-132
  Evidence: Keine Schwellen, Stufenreihenfolge, Prompt oder Timeout geändert. Einziges Aufräumen in SmartCartApp.swift ist das neue Argument.
  Status: CONFIRMED

### Runde 2: Nachfassen an den bekannten Schwachstellen

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/Views/Settings/ReceiptResolutionStatsView.swift:36-37
  Description: Statt `confirmationDialog` wird `.alert` verwendet, der Zurücksetzen-Knopf trägt `accessibilityLabel` "Zähler zurücksetzen". Begründung im Quelltext: unter iOS 26 erscheint `confirmationDialog` als Popover ohne Abbrechen-Knopf, gleiche Labels wären nicht unterscheidbar.
  Spec requirement: AC-17 (Bestätigung, nach Bestätigung 0, nach Abbrechen bleiben die Werte). Spec-Text nennt `confirmationDialog`.
  Conflict: Verhalten von AC-17 voll erfüllt, nur das Mittel weicht vom Wortlaut ab und die Spec wurde nicht nachgezogen.
  Remediation: Spec-Text auf `.alert` und das Accessibility-Label korrigieren. Kein Code-Fix nötig.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:650-652
  Description: "Abbruch zählt nicht" und "genau einmal" nur per Code-Pfad belegt. Doppeltipp auf Speichern vor dem `dismiss()` könnte `save()` zweimal auslösen; das war schon vorher so (doppelte PurchaseRecords), jetzt zusätzlich Doppelzählung.
  Spec requirement: AC-13
  Conflict: Nicht durch Test bewiesen, theoretisch doppelt zählbar.
  Remediation: UI-Test "Abbrechen → Zähler 0" oder die Lücke in der Spec benennen. Guard-Flag in `save()` als eigenes Ticket.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: RestockTests/ReceiptResolutionStatsTests.swift:100-170
  Description: AC-5 und Test-Plan Punkt 4 verlangen einen Vergleichssatz von `resolve` (Namen, matchedItemID, suggestions). Vorhanden sind nur Einzelprüfungen von name, matchedItemID und stage. `suggestions` wird in keinem neuen Test geprüft.
  Spec requirement: AC-5
  Conflict: Beweis liegt im rein additiven Diff und den Bestandstests, nicht in einem eigenen Test.
  Remediation: Kleinen Test mit festen Erwartungen ergänzen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/ReceiptResolutionStats.swift:62-64
  Description: `normalized` trimmt nur `.whitespaces`, nicht Zeilenumbrüche (praktisch irrelevant). Eine eingeschlossene Zeile, die `isSavable` nicht erfüllt (Preis 0 oder leerer Name), wird trotzdem gezählt und kann `changed` sein, obwohl `save()` sie nicht speichert. Spec-konform ("alle Zeilen"), aber eine Verzerrung.
  Spec requirement: AC-8 und AC-13
  Conflict: Kein Verstoß, Messgrenze.
  Remediation: Optional als Messgrenze in der Spec dokumentieren.

Finding:
  ID: F005
  Severity: MEDIUM
  Category: regression
  Code reference: SmartCart/SmartCartApp.swift:226-232
  Description: `ReceiptReviewUITests` (22 Tests) nutzt denselben Seed `-seedReceiptReviewForUITests` und speichert. Seit dieser Änderung schreibt jedes dieser Speichern Zähler in den App-Gruppen-Speicher. Deren tearDown startet nur `-clearReceiptReviewSeedForUITests`, das den Zähler nicht mit aufräumt. Im gemeinsamen Lauf bleiben Zähler zurück.
  Spec requirement: AC-19 und CLAUDE.md (jede Seed-Testklasse räumt in tearDown auf).
  Conflict: AC-19 nach dem Wortlaut für die neue Suite erfüllt, im gemeinsamen Lauf widerlegt. Betrifft nur Testgerät und DEBUG.
  Remediation: `-clearReceiptReviewSeedForUITests` soll zusätzlich `ReceiptResolutionStats().reset()` aufrufen (eine Zeile).

## Nicht bewiesen

- AC-19: Gesamtsuite im gemeinsamen Lauf nicht gelaufen, Aufräumaussage durch F005 für `ReceiptReviewUITests` widerlegt.
- AC-13 "Abbruch zählt nicht" nur per Code-Pfad (F002).
- AC-5 `suggestions` nur indirekt (F003).
- AC-4 echtes Gerät mit Apple Intelligence nicht prüfbar (Spec-Grenze).

Zwischenstand nach Runde 2: AMBIGUOUS. Kein harter Verstoß, kein Datenschutz- oder Verhaltensdefekt. PO-OK zur Übernahme der Befunde und zum Beheben von F005 und F003 liegt vor (Rückfrage 2026-10-02, override-ambiguous protokolliert); Stand gesichert als Commit d4e610a.

### Runde 3: Nachprüfung der Fixes

Selbst ausgeführt: `ReceiptResolutionStatsTests` auf Restock-Validate, vorher kein xcodebuild aktiv, keine Extra-Build-Settings: 19 Tests, 0 Fehler, TEST SUCCEEDED. UI-Suiten und Gesamt-Unit-Suite nicht selbst gefahren, nur die Artefakte geprüft.

Confirmation:
  AC: F005 (AC-19, Aufräumen)
  Code reference: SmartCart/SmartCartApp.swift:209-225
  Evidence: `ReceiptResolutionStats().reset()` steht als letzte Anweisung in `clearReceiptReviewSeedForUITestsIfNeeded`, nach `try? context.save()` und `takePending()`. Der einzige guard davor ist der auf das Argument selbst, kein früheres return. Aufruf im init-defer in der `#if DEBUG`-Gruppe (:28-31), also nur unter DEBUG. `ReceiptReviewUITests.tearDown` startet die App mit genau diesem Argument (ReceiptReviewUITests.swift:107), der Zähler wird nach jedem seed-nutzenden Test dieser Klasse geleert, auch nach den speichernden.
  Status: CONFIRMED

Confirmation:
  AC: F005, Nebenwirkung "reset löscht absichtlich aufgebaute Zähler"
  Code reference: RestockUITests/ReceiptResolutionStatsUITests.swift:27-36
  Evidence: Beide Aufräumargumente stehen nur im tearDown-Cleaner. Die Test-Starts setzen nur `-clearReceiptResolutionStatsForUITests` plus optional den Seed, nie `-clearReceiptReviewSeedForUITests`. Eine Kollision, bei der ein Test seine eigenen Zähler verliert, gibt es nicht.
  Status: CONFIRMED

Confirmation:
  AC: F003 (AC-5, Vergleichssatz)
  Code reference: RestockTests/ReceiptResolutionStatsTests.swift:152-180
  Evidence: Der Test prüft name, matchedItemID, suggestion-itemIDs und suggestion-Namen je Zeile mit festen Erwartungen, plausibel gegen den Altcode (Vorschlagspool = store.items, limit 3, ReceiptResolutionService.swift:100-128). Reihenfolge deterministisch, weil `completedItemCandidates` Namen als zweiten Sortierschlüssel nutzt. Der Test legt keine Aliase an und schreibt nicht in den App-Gruppen-Speicher. 19/19 selbst grün. Die Messung der Erwartungen am Altstand 928c16c konnte der Prüfer nur auf Plausibilität prüfen; der Entwickler meldet die Messung in einer Wegwerf-Kopie (zuerst hergeleitete Vorschläge waren falsch und wurden durch gemessene ersetzt).
  Status: CONFIRMED (Messung am Altstand nur plausibilisiert)

Confirmation:
  AC: Alias-Risiko (BTR-Seed speichert nie)
  Code reference: RestockUITests/ReceiptReviewUITests.swift:157
  Evidence: Der BTR-Seed wird nur von `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` benutzt, der den Speichern-Knopf nie bedient. Die speichernden Tests nutzen den Standard-Seed (Zeile 116) oder den Gewichts-Seed (Zeile 798). Es wird nie ein Alias für "BTR" gelernt.
  Status: CONFIRMED

Confirmation:
  AC: Artefakt-Konsistenz
  Code reference: docs/artifacts/bon-namenserkennung-regelwerk-14/test-green-unit.txt
  Evidence: Kopf nennt Basis d4e610a + F003/F005, 396 Tests, 19/19 für `ReceiptResolutionStatsTests`, Ende "Executed 396 tests, with 0 failures ... TEST SUCCEEDED". UI-Artefakt: 4 + 2 = 6 Tests, 0 Fehler. Zahlen konsistent, kein Null-Test-Lauf. Die volle `ReceiptReviewUITests`-Suite (22) und ein gemeinsamer Lauf der Gesamt-UI-Suite sind in diesem Stand nicht gelaufen (offene Grenze von AC-19; 22/22 und 3x4 UI-Tests waren auf dem Stand d4e610a grün).
  Status: CONFIRMED (mit der Grenze)

Statuswertung der Altbefunde:
- F001 (.alert statt confirmationDialog): inhaltlich akzeptiert, AC-17 erfüllt. Spec-Nachzug blockiert die Spec-Sperre (PO-Override nötig), bleibt als offener Punkt für /60-validate.
- F002 (Abbruch ohne Test, Doppeltipp) und F004 (Randfälle in tally): als Messgrenzen benannt, kein Defekt in diesem Ticket.

Neue Defekte: keine. Der Diff der Fixes ist eine Zeile Produktivcode in einer DEBUG-Hilfsfunktion plus ein neuer Test.

## Verdict: VERIFIED

F005 und F003 tragen, kein neuer Defekt. Nicht eigenständig bewiesen bleiben die Messung der Test-Erwartungen am Altstand und ein Lauf der Gesamt-UI-Suite im gemeinsamen Lauf; das sind Beweisgrenzen, keine Defekte.

## Geprüfte Dateien

- sha256:bcfa6673544a2d96e633096641bc05737ce292687c6173f44c162d02cb7d48a6  Restock.xcodeproj/project.pbxproj
- sha256:8b8cbbf4f12232ddef2fc1e342aedb5ecf68ff0a120979d7ecf33e7ec44499aa  RestockTests/ReceiptResolutionStatsTests.swift
- sha256:19a6419909afa421af8274e4aedf7dd9cdc3c2cb80c706d88ade8f1c6b3fbef9  RestockUITests/ReceiptResolutionStatsUITests.swift
- sha256:d525fb088c9cc3a61bd862e6b94213a588412a267e40eeb149ea1b3106aba54a  RestockUITests/ReceiptReviewUITests.swift
- sha256:5e23f81bb949e76a288b1c8c8e0ea71006f902e7ee85f1cf55f2335aeedf1638  SmartCart/Services/ReceiptResolutionService.swift
- sha256:a11e7b9db4ef8c15aab821cb956221704549458c43ba77594fb6a550098448f4  SmartCart/Services/ReceiptResolutionStats.swift
- sha256:1d7b2aaa5fce723986fd02339f9e1c19a20a1cc942f027a941044182b13201d5  SmartCart/SmartCartApp.swift
- sha256:972e06bcec2e6ad9729ffc2272a3ab567bb3ec00adb7c9b746ada951f4d4f5e5  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:254667a6dbc6e5af41cc09ed76efaea506975c48c5d833e12d28d3fe67d28129  SmartCart/Views/Settings/ReceiptResolutionStatsView.swift
- sha256:56477701352a7129a848d8fcceff730109dadb92df28eda7db314cfac17c4f0e  SmartCart/Views/Settings/SettingsView.swift
- sha256:21a535817ade0fbd98bb8ec8e23deb4d26a4f2fedbb7147b7c14f02cc995cbf9  docs/artifacts/bon-namenserkennung-regelwerk-14/test-green-unit.txt
