# Adversary Dialog — fix-111-toast-dauer
Spec: docs/specs/ui-tests/test-111-durchgang-2-toast-dauer.md
Datum: 2026-10-07 12:03

## Checkliste
- [x] **AC-1:** GIVEN der Start mit `-quickAddToastDurationForUITests 60` (DEBUG), WHEN ein Artikel per Schnell-Hinzufügen angelegt wird, THEN ist der Toast nach mindestens 8 s noch sichtbar.
- [x] **AC-2:** GIVEN derselbe Test vor der Umsetzung (Stand `main`), WHEN er läuft, THEN schlägt er fehl, weil der Toast nach 6 s verschwunden ist (RED belegt, Schalter Fehler da → Fix → Fehler weg).
- [x] **AC-3:** GIVEN der Start ohne Argument, WHEN `testToastStaysVisibleLongerThanTwoSeconds` läuft, THEN ist er unverändert grün; er startet über `launchedApp()` ohne `toastDuration`.
- [x] **AC-4:** GIVEN gesetztes Argument mit Wert > 0, WHEN `showQuickAddToast` aus einer der drei Aufrufstellen läuft (nach Hinzufügen 6 s, Neustart nach Laden-Dialog 3 s, „verschoben nach“ 3 s), THEN ersetzt der Argumentwert die jeweilige `duration`; die Aufrufstellen selbst sind unverändert.
- [x] **AC-5:** GIVEN kein Argument oder ein Wert ≤ 0 bzw. nicht numerisch, WHEN `showQuickAddToast` läuft, THEN gelten unverändert 6 s bzw. 3 s.
- [x] **AC-6:** GIVEN der Release-Build, WHEN er kompiliert, THEN ist der Zweig `#if DEBUG` nicht enthalten, der Build läuft ohne Fehler, und die Fristen sind unverändert 6 s bzw. 3 s.
- [x] **AC-7:** GIVEN die Tests `testToastNamesStoreAndOffersChangeAndUndo`, `testUndoRemovesToastAndItem` und `testChangeStoreMovesItemAndRemembersCorrection`, WHEN der Durchgang umgesetzt ist, THEN starten sie mit `toastDuration: 60` und prüfen inhaltlich dasselbe wie vorher (Toast nennt Laden, bietet „Laden ändern“ und „Rückgängig“, Undo entfernt Toast und Artikel, Laden-Wechsel verschiebt den Artikel und merkt die Korrektur); geändert ist nur der Start.
- [x] **AC-8:** (PO-Ausnahme 2026-10-07, im Werkzeug erfasst: adversary_ambiguous_override; Nachweis folgt in /60-validate) GIVEN die gesamte UI- und Unit-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag.
- [x] **AC-9:** (PO-Ausnahme 2026-10-07, im Werkzeug erfasst: adversary_ambiguous_override; Nachweis folgt in /60-validate) GIVEN der Wegwerf-Zweig mit auf `QuickAddAssignmentUITests` eingeschränkter `ci.yml` und `-test-iterations 30` ohne Retry, WHEN der Vorher-Lauf (Stand `main`) läuft, THEN ist die Fehlerquote der drei Toast-Tests dokumentiert; ist sie 0, wird das offen benannt und der Nachweis entsprechend eingeschränkt.
- [x] **AC-10:** (PO-Ausnahme 2026-10-07, im Werkzeug erfasst: adversary_ambiguous_override; Nachweis folgt in /60-validate) GIVEN derselbe Wegwerf-Zweig mit dem Fix, WHEN der Nachher-Lauf läuft, THEN sind es 0 Fehler bei den drei Toast-Tests, das xcresult belegt weiterhin Einzelabfragen > 4 s (gleiche Runner-Lage), und `ci.yml` auf `main` ist unverändert.
- [x] **AC-11:** (PO-Ausnahme 2026-10-07, im Werkzeug erfasst: adversary_ambiguous_override; Nachweis folgt in /60-validate) GIVEN die App im Simulator ohne Argument, WHEN sie als Nutzer durchgespielt wird (Schnell-Hinzufügen, Toast, „Laden ändern“, Dialog schließen), THEN verschwindet der Toast nach etwa 6 s bzw. nach dem Dialog nach etwa 3 s von selbst; der Durchlauf ist als Artefakt registriert (echter Lauf, Commit-Kennung und Zeitstempel passend).
- [x] **AC-12:** (PO-Ausnahme 2026-10-07, im Werkzeug erfasst: adversary_ambiguous_override; Nachweis folgt in /60-validate) GIVEN der Abschluss des Durchgangs, WHEN Ticket und Berichte formuliert werden, THEN sind ausdrücklich als offen genannt: XCTests eigene Abfrage-Zeitgrenze („Timed out while evaluating UI query“, 31 s), der Wettlauf `frame` → `isHittable` → `tap()` und Durchgang 3; es gibt keine Aussage „alle Flakes behoben“, und #111 bleibt offen.
- [x] **AC-13:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau `SmartCart/Views/Home/HomeView.swift` und `RestockUITests/QuickAddAssignmentUITests.swift` (ca. +25/−5 LoC), ohne neue Produkt-Strings, Dependencies, `Info.plist`- oder `@AppStorage`-Änderung; `UITestWait.swift` ist unberührt.

## Dialog

### Runde 1
**Adversary:**

Grundlage: Diff der HomeView (uncommittet: +7/−1), Diff des RED-Commits 33165b6 und die drei Artefakte.

AC-1: AKZEPTIERT
- Code reference: SmartCart/Views/Home/HomeView.swift:1500-1506. Bei einem Wert > 0 ersetzt `effectiveDuration` die Frist, und diese Variable steht im `asyncAfter`.
- Code reference: RestockUITests/QuickAddAssignmentUITests.swift:187-198. Der Test wartet nach dem Erscheinen 8 s und fordert dann `toast.exists`.
- Beleg: test-green-output.txt:797 `testToastDurationLaunchArgumentKeepsToastBeyondDefault passed (21.545 seconds)`.
- Das Argument kommt als `-key value` in der Argument-Domain an; die Domain liegt nur im Prozess, ein Wert bleibt nicht über Läufe stehen.

AC-2: AKZEPTIERT mit NACHFRAGE
- Beleg: test-red-output.txt:2262 `error: ... testToastDurationLaunchArgumentKeepsToastBeyondDefault : XCTAssertTrue failed - Der Toast ist nach acht Sekunden weg, obwohl 60 s verlangt waren`; :2323 `testToastStaysVisibleLongerThanTwoSeconds passed`; :2325 „Executed 2 tests, with 1 failure (0 unexpected)". RED-Lauf (09:43:02) liegt vor der HomeView-Änderung (09:43:31).
- Nachfrage F-A: Ein einziges Fehlerbild („Toast nach 8 s weg“); kein Beleg für einen Zwischenwert zwischen 8 s und 60 s.

AC-3: AKZEPTIERT
- Code reference: RestockUITests/QuickAddAssignmentUITests.swift:33-45. `toastDuration` ist standardmäßig `nil`, ohne Wert wird kein Argument angehängt. `testToastStaysVisibleLongerThanTwoSeconds` steht nicht im Diff und ist in RED (:2323) und GREEN (:902) grün.

AC-4: AKZEPTIERT
- Code reference: SmartCart/Views/Home/HomeView.swift:1495-1506. Die gesamte Fristlogik liegt in `showQuickAddToast`. Genau drei Aufrufer: :1479 (6 s), :229 (3 s), :1567 (3 s). Kein zweiter `asyncAfter` für den Toast (:1486 gehört zu `quickAddSucceeded`). Aufrufstellen im Diff unverändert.
- Token-Logik (:1496-1497, Guard :1509): ältere Timer ersetzen neuere nie; `undoQuickAdd` (:1537) invalidiert das Token. Bei offenem `showStoreCorrection` bricht der Guard ab, beim Schließen (:227-230) läuft die Frist über den Override neu an.
- Beleg: `testChangeStoreMovesItemAndRemembersCorrection` mit 60 s grün (GREEN :503).

AC-5: AKZEPTIERT mit NACHFRAGE
- Code reference: SmartCart/Views/Home/HomeView.swift:1503-1504. `UserDefaults.double(forKey:)` liefert 0 für fehlend/nicht numerisch, `if override > 0` filtert 0 und negative Werte.
- Nachfrage F-B: kein Test für „Argument fehlt oder ungültig“; der echte 6-s-Beleg ist AC-11 (/60-validate).
- Nachfrage F-C: Randfall `inf` (inf > 0 ist true); nur DEBUG, LOW. Obergrenze oder ausdrücklich egal?

AC-6: NACHFRAGE
- Code reference: SmartCart/Views/Home/HomeView.swift:1500-1505. Zweig vollständig zwischen `#if DEBUG` und `#endif`.
- Defekt am Beleg: `release-build.txt` enthielt nur die Zeile `** BUILD SUCCEEDED **`; Kommando, Konfiguration und Zeitpunkt fehlten.
- Nachfrage F-D: Release-Build mit sichtbarem Kommando und `-configuration Release` neu aufnehmen, Warnungen zu HomeView.swift zeigen („never mutated“ möglich).

AC-7: AKZEPTIERT mit NACHFRAGE
- Code reference: RestockUITests/QuickAddAssignmentUITests.swift:146, :160, :295. Genau diese drei Aufrufe sind auf `launchedApp(toastDuration: 60)` umgestellt; im Diff keine geänderte oder entfernte Assert-Zeile. GREEN :503, :851, :1035.
- Nachfrage F-E: Wird in den drei Tests irgendwo ein ablaufender Toast erwartet?

AC-8 bis AC-12: IN DIESER PHASE NICHT BEWEISBAR, an /60-validate übergeben
- AC-8: ganze UI- und Unit-Suite im gemeinsamen Lauf, Testzahl > 0, kein Abbruch, kein Retry-Flag (GREEN-Datei deckt nur `QuickAddAssignmentUITests`).
- AC-9/AC-10: 30 Wiederholungen ohne Retry vorher/nachher, Fehlerquote dokumentiert (bei 0 offen benennen), xcresult mit Einzelabfragen > 4 s, `ci.yml` auf `main` unverändert.
- AC-11: Durchlauf im Simulator ohne Argument (Toast weg nach ca. 6 s bzw. 3 s), als Artefakt mit passender Commit-Kennung und Zeitstempel; belegt zugleich AC-5.
- AC-12: Berichtstexte nennen XCTests Abfragegrenze (31 s), den Wettlauf `frame` → `isHittable` → `tap()` und Durchgang 3 als offen; #111 bleibt offen.

AC-13: AKZEPTIERT mit Hinweis
- Beleg: Diffstat des RED-Commits zeigt im Code nur RestockUITests/QuickAddAssignmentUITests.swift (+27/−4), der uncommittete Diffstat nur SmartCart/Views/Home/HomeView.swift (+7/−1). Keine neuen Strings, kein `@AppStorage`, keine Info.plist-, `.xcscheme`- oder `.yml`-Änderung; `UITestWait.swift` und `.github` unberührt.

**Implementierer:**

(Antworten in Runde 2)

### Runde 2
**Adversary:**
- F-A (Zwischenwert): AKZEPTIERT als bekannte Grenze. Belegt ist nur, dass Argument 60 den Toast über 8 s hält. Der Code gibt den Wert unverändert weiter.
Code reference: SmartCart/Views/Home/HomeView.swift:1503
- F-B (ungültiges Argument): AKZEPTIERT mit Übergabe. Kein eigener Test; AC-5 stützt sich auf die Code-Lesart (`double(forKey:)` liefert 0, `override > 0`) und den Test ohne Argument. Den echten 6-s-/3-s-Beleg liefert AC-11 in /60-validate.
Code reference: SmartCart/Views/Home/HomeView.swift:1504
- F-C (inf): AKZEPTIERT, LOW, nicht blockierend. Der Hook liegt nur in DEBUG und wird nur mit festem Wert 60 gesetzt.
Code reference: SmartCart/Views/Home/HomeView.swift:1500
- F-D (Release-Build): AKZEPTIERT. release-build.txt hat 1280 Zeilen, Zeile 2 enthält das Kommando mit `-configuration Release ... clean build`, `** CLEAN SUCCEEDED **` (Z. 10), `** BUILD SUCCEEDED **` (Z. 1279), 0 `error:`, 56 `warning:` (keine in HomeView), Pfade `Release-iphonesimulator`, Dateizeit 12:12 nach der HomeView-Änderung. Die Warnung „never mutated“ tritt nicht auf; der `#if DEBUG`-Zweig ist im Release ausgeschlossen.
Code reference: SmartCart/Views/Home/HomeView.swift:1500-1505
- F-E (Fristen-Assert): AKZEPTIERT. Die drei umgestellten Tests erwarten keine ablaufende Frist; die `XCTAssertFalse`-Treffer (Zeilen 171, 267, 288, 319, 332, 367, 369) betreffen Karte, Sheet, Liste, Dialog und Mengentext. Das Verschwinden in `testUndoRemovesToastAndItem` kommt durch Undo (Token ungültig).
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:146
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:160
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:295

**Implementierer:**
- F-A: Kein Beleg für einen Zwischenwert, nur 60 s über 8 s. Wird als Grenze im Protokoll benannt.
- F-B: Kein eigener Test. AC-5 stützt sich auf Code-Lesart und Dauertest, der 6-s-/3-s-Beleg kommt aus AC-11 in /60-validate.
- F-C: Keine Obergrenze (Entscheidung Tech Lead): nur DEBUG und fester Wert 60. LOW.
- F-D: Release-Build neu aufgenommen mit sichtbarem Kommando und `clean build`: 0 Fehler, 56 Warnungen, keine in HomeView.swift.
- F-E: Verschwinden-Asserts nur in `testUndoRemovesToastAndItem` (Undo, kein Timer) und in einem anderen Test (Zuordnen-Sheet).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Keine verdächtigen Zeilen: Der Override-Wert wird im Produktionscode nirgends geschrieben, nur aus der Argument-Domain gelesen (HomeView.swift:1503). Der Test, der genau diesen Weg auslöst, ist `testToastDurationLaunchArgumentKeepsToastBeyondDefault` (QuickAddAssignmentUITests.swift:190).

## Verdict
**AMBIGUOUS**

Begründung (Adversary): AC-1 bis AC-7 und AC-13 sind belegt und unbeanstandet (Adversary-Urteil für diese Punkte: VERIFIED). Das Gesamturteil ist AMBIGUOUS, weil AC-8 bis AC-12 per PO-Ausnahme erst in /60-validate bewiesen werden. RED zeigt 1 Fehler bei 2 Tests, GREEN 13 von 13 ohne Fehler (nur Klasse `QuickAddAssignmentUITests`, nicht die ganze Suite). Keine Regressionen, keine Umgehung der Frist; alle drei Aufrufer laufen über `showQuickAddToast`, Token- und `showStoreCorrection`-Guard intakt. AC-8 bis AC-12 sind nicht in dieser Phase beweisbar und an /60-validate übergeben.

## Geprüfte Dateien

- sha256:343c4a8a9f670f9e52755dc7af20e8e46a61949c9078dc6f891e9fe7afcfd86b  RestockUITests/QuickAddAssignmentUITests.swift
- sha256:72724b9a59322395b71f6af631025781dd701bde0d8589641bd06a3ad7269856  SmartCart/Views/Home/HomeView.swift

## Prüfbasis

- base: 64a3d19fd01361a804dba7c860bb0e02e93cbdef
- blob:ddd685912a2574f4b83e94b6634e168594adf973  RestockUITests/QuickAddAssignmentUITests.swift
- blob:f9617212d59493a30e7112d02f96ba959133276a  SmartCart/Views/Home/HomeView.swift
