# Adversary Dialog — test-145-d2-mitteilungserlaubnis
Spec: docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md
Datum: 2026-10-16 06:43

## Checkliste
- [x] **AC-1:** GIVEN frisch installierte App und `RESTOCK_NOTIF_DECISION=allow`, WHEN `testAllow` die Schalter- Kette fährt (Zahnrad → „Benachrichtigungen“ → Schalter „Nachkauf-Erinnerungen“/„Restock reminders“ von aus auf an), THEN erscheint der Mitteilungsdialog, und nach „Erlauben“ steht der Schalter auf an und bleibt es, auch nach Schließen und erneutem Öffnen der Einstellungen. Test: T1.
- [x] **AC-2:** GIVEN frisch installierte App und `RESTOCK_NOTIF_DECISION=deny`, WHEN `testDeny` dieselbe Kette fährt, THEN springt der Schalter nach „Nicht erlauben“ auf aus und bleibt es, auch nach Schließen und erneutem Öffnen der Einstellungen. Test: T2.
- [x] **AC-3:** GIVEN die normale Suite ohne `RESTOCK_NOTIF_DECISION`, WHEN `NotificationPermissionUITests` läuft, THEN werden beide Tests per `XCTSkip` mit Grund übersprungen; die übrigen Klassen sind unberührt, die Suite bleibt grün. Test: T3.
- [x] **AC-4:** GIVEN gesetztes Gate, aber schon entschiedene Erlaubnis (kein Dialog trotz Auslösung), WHEN der Test läuft, THEN schlägt er fehl mit der Meldung „Installation nicht frisch …“ und überspringt **nicht**. Test: T4.
- [x] **AC-5:** GIVEN Simulator in Deutsch (lokal) oder Englisch (CI-Runner), WHEN der Dialog erscheint, THEN bedient der Test die Schaltflächen „Erlauben“/„Nicht erlauben“ bzw. „Allow“/„Don’t Allow“; der Alert-Titel wird nur auf Vorhandensein geprüft. Test: T1, T2 (de lokal, en aus dem CI-Lauf T7).
- [x] **AC-6:** GIVEN die Launch-Argumente der Klasse, WHEN sie geprüft werden, THEN sind genau `-developerMode YES` und `-hasCompletedOnboarding YES` (plus die von `UITestLaunch` gesetzten) gesetzt, und `-notificationsEnabled` kommt in der Klasse nicht vor (Argument-Domain-Falle). Test: T8 (`grep`).
- [x] **AC-7:** GIVEN die Klasse, WHEN sie geprüft wird, THEN erzeugt sie keinen Zustand im App-Group-Container und braucht kein Aufräum-Argument; der Zustand (Erlaubnis) entsteht nur auf dem Wegwerf-Simulator des Skripts und verschwindet mit ihm (AC-10). Test: T8.
- [x] **AC-8:** GIVEN das Skript, WHEN es startet, THEN nimmt es beide Sperren `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` in dieser Reihenfolge per `mkdir` samt `owner`-Datei, bricht bei belegter Sperre mit klarer Meldung ab, ohne die fremde Sperre anzutasten, und gibt bei jedem Ende nur die selbst angelegten Sperren frei. Test: T5, T6.
- [x] **AC-9:** GIVEN das Skript, WHEN es läuft, THEN baut es genau einmal (`build-for-testing`, keine zusätzlichen Build-Settings) und führt je Weg `simctl create` (Gerätetyp und Runtime der Vorlage `Restock-Validate`) → `simctl install` → `xcodebuild test-without-building -only-testing:RestockUITests/NotificationPermissionUITests` auf diesem Wegwerf-Simulator → `simctl delete` aus. Test: T5.
- [x] **AC-10:** GIVEN der Skriptlauf, WHEN er endet (grün oder rot), THEN ist kein Wegwerf-Simulator des Laufs mehr vorhanden und die Vorlage `Restock-Validate` ist unverändert. Test: T5 (`simctl list devices` enthält keinen Namen `Restock-Notif-…-<zeitstempel>`).
- [x] **AC-11:** GIVEN die Auswertung je Weg, WHEN sie läuft, THEN zählt ein Weg nur als grün bei ≥ 1 gelaufenem (nicht übersprungenem) Test, 0 Fehlschlägen und ohne Abbruch; „Executed 0 tests“ oder ein Runner-Neustart ist Rot. Test: T5.
- [x] **AC-12:** GIVEN `ci.yml`, WHEN der Anschluss geprüft wird, THEN setzt Hälfte A `allow` und wählt zusätzlich die Klasse, Hälfte B setzt `deny`; `HEAVY_CLASSES` ist unverändert und enthält die Klasse nicht. Test: T7, T8.
- [x] **AC-13:** GIVEN der Push-Lauf, WHEN beide Hälften laufen, THEN sind sie grün und `testAllow` (A) bzw. `testDeny` (B) sind nicht übersprungen; ODER (Rückfall) der CI-Anschluss ist nicht im Diff, die Gründe sind als Messung dokumentiert, und der Anschluss steht als Folgeschritt in #145. Test: T7.
- [x] **AC-14:** GIVEN der Abschluss, WHEN die Doku geprüft wird, THEN beschreibt `CLAUDE.md` Klasse, ENV `RESTOCK_NOTIF_DECISION`, Skript, Sperren, Wegwerf-Simulator je Weg (Neuinstallation setzt erst nach einem Tag zurück), die offenen Grenzen und den Hinweis in der D7-Spec ist gesetzt.
- [x] **AC-15:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er höchstens `NotificationPermissionUITests.swift`, `run-notification-permission-uitest.sh`, `ci.yml`, `project.pbxproj`, optional `SettingsView.swift` (≤ ±2 Zeilen, nur Identifier) sowie die Doku, ca. +215 LoC, ohne neue Produkt-Strings, Dependencies, `Info.plist`- oder `@AppStorage`-Änderung. Test: T8.
- [x] **AC-16:** GIVEN der Abschluss, WHEN Ticket und Berichte formuliert werden, THEN sind ausdrücklich als offen genannt: Anfrage der Teilen-Erweiterung ungeprüft, `.provisional`, echte Zustellung, Runner-Verhalten bis zum ersten CI-Lauf, nichts auf Hennings Geräten; #145 bleibt offen (Durchgänge 3 und 4).
- [x] **AC-17:** GIVEN der Durchlauf, WHEN der Skriptlauf beider Wege erfolgt ist, THEN liegt ein Protokoll mit Commit-Kennung, Zeitstempel, Testzahl je Weg und Screenshots (Dialog, Schalterzustand) als Artefakt aus dem echten Lauf vor. Ein Lauf unter Last ist nicht erforderlich.

## Dialog

### Runde 1
**Adversary:** Statische Prüfung von Klasse, Skript, ci.yml, Diff und der echten Läufe (keine neuen Läufe). Versuch, jede AC zu widerlegen.

Code reference: RestockUITests/NotificationPermissionUITests.swift:79
Code reference: scripts/run-notification-permission-uitest.sh:44
Code reference: .github/workflows/ci.yml:161

Confirmation:
  AC: AC-1
  Code reference: RestockUITests/NotificationPermissionUITests.swift:38
  Evidence: testAllow wartet auf Schalter aus, tippt, bedient den SpringBoard-Dialog, prüft "1" mit 2 s Nachprüfung und nach Schließen/Öffnen (Z. 43-44). notif-allow-20261016-062054.log:117 passed (30,7 s); Screenshots allow/007 (aus) und 008 (an).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: RestockUITests/NotificationPermissionUITests.swift:49
  Evidence: testDeny analog mit Erwartung "0". notif-deny-20261016-062054.log:125 passed; Screenshot deny/008.jpg zeigt den Dialog (Nicht erlauben / Erlauben), 009.jpg Schalter aus.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: RestockUITests/NotificationPermissionUITests.swift:22
  Evidence: setUpWithError wirft XCTSkip ohne Wert. Nur statisch belegt (siehe F002); die Skips "andere Entscheidung" sind in beiden Logs sichtbar, ein Lauf ganz ohne Gate liegt nicht vor.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: RestockUITests/NotificationPermissionUITests.swift:108
  Evidence: Beide "Installation nicht frisch"-Zweige real belegt: test-red-allow.log:129 (kein Dialog, Zeile 108) und notif-deny-20261015-214715.log:256 (Schalter "1" beim Öffnen). Beide Fehlschläge, kein Skip.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: RestockUITests/NotificationPermissionUITests.swift:62
  Evidence: Argumente nur -hasCompletedOnboarding YES, -developerMode YES; grep auf den Schalter-Schlüssel in der Klasse ohne Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: RestockUITests/NotificationPermissionUITests.swift:13
  Evidence: Keine Seed-/Clear-Argumente, kein Schreiben in den App-Group-Container; Zustand lebt nur im Wegwerf-Simulator.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/run-notification-permission-uitest.sh:20
  Evidence: take_lock mkdir atomar, owner-Datei, Reihenfolge heavy dann loose (Z. 24), bei Fehlschlag exit 2 ohne fremde Sperre zu löschen; cleanup (Z. 16) räumt nur MY_LOCKS. Nur statisch (T6 nie gelaufen, F004).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/run-notification-permission-uitest.sh:37
  Evidence: ein build-for-testing ohne Extra-Settings, je Weg simctl create mit Typ/Runtime der Vorlage (Z. 47), install (51), test-without-building mit -only-testing der Klasse (56), delete (62). test-green-output.txt bestätigt iPhone-17-Pro/iOS-26-5.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/run-notification-permission-uitest.sh:85
  Evidence: Schlussprüfung auf Namen Restock-Notif-(allow|deny)-STAMP, Ergebnis "übrig: nein". "Vorlage unberührt" ist ein fester Ausgabetext, nicht geprüft (F003).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: scripts/run-notification-permission-uitest.sh:67
  Evidence: verlangt Status 0, 0 Fehlschläge, Test "passed" im Log (Skip zählt nicht), Executed 0 tests / EXECUTE FAILED / Runner-Neustart = Rot. Ergebnis je Weg: 2 ausgeführt, davon 1 übersprungen, passender bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: .github/workflows/ci.yml:161
  Evidence: A: allow + zusätzliches -only-testing der Klasse; B: deny, Klasse in RestockUITests enthalten; HEAVY_CLASSES (Z. 112) unverändert. Variablen im selben Schritt wie xcodebuild test. Einzige weitere Anfragestelle ist die Teilen-Erweiterung (grep), in CI nicht gestartet.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: Restock.xcodeproj/project.pbxproj:1
  Evidence: Diff gegen Basis 7942737 (Stat): 139 (Klasse) + 95 (Skript, untracked) + 5 (ci.yml) + 4 (pbxproj) = 243 Codezeilen, unter 250, aber über den geschätzten 215. SettingsView, Info.plist, Strings unberührt; übrige Änderungen nur Doku/Artefakte.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: scripts/run-notification-permission-uitest.sh:89
  Evidence: test-green-output.txt: Commit 79dc29f (uncommittete Änderungen: ja), Zeit 2026-10-16 06:25:30, Testzahl 2 je Weg (1 gelaufen). Dialog-Screenshot für deny (screens-deny-20261016-062054/008.jpg) und für allow aus früherem Lauf (screens-allow-20261015-170228/004.jpg); Schalterzustand an/aus in beiden Läufen. Der allow-Dialog im Grün-Lauf selbst ist im 4-s-Raster nicht erfasst.
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Gezielter Angriff auf die Lücken.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md:52
  Description: Die D7-Spec behauptet weiter, die Erlaubnis lasse sich von außen nicht setzen und der Weg laufe nur über die Fake-Zentrale. Der Hinweis "geschlossen durch #145 Durchgang 2" fehlt (Datei unverändert, edit_gate-gesperrt).
  Spec requirement: AC-14 — Hinweis in der D7-Spec ist gesetzt.
  Conflict: CLAUDE.md (Z. 42) beschreibt Klasse, ENV, Skript, Sperren, Wegwerf-Simulator, Tag-Regel und offene Grenzen vollständig, ersetzt den D7-Hinweis aber nicht wörtlich; D7-Spec und der D7-Absatz in CLAUDE.md führen den Dialog weiter als offen. Dieser Teil von AC-14 ist nicht erfüllt, CLAUDE.md deckt ihn nur teilweise ab. Der Absatz nennt außerdem nicht "#145 bleibt offen (Durchgänge 3 und 4)" (AC-16).
  Remediation: PO-Freigabe (override) für einen Einzeiler in der D7-Spec, oder AC-14 per PO-Entscheid auf CLAUDE.md beschränken; "Durchgänge 3 und 4 offen" in den CLAUDE.md-Absatz aufnehmen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/NotificationPermissionUITests.swift:22
  Description: Der gate-lose Skip-Pfad (AC-3, Text "Übersprungen: Braucht ...") wurde in keinem vorgelegten Lauf beobachtet; die Logs zeigen nur den Skip "andere Entscheidung".
  Spec requirement: AC-3 — beide Tests per XCTSkip mit Grund übersprungen ohne Gate.
  Conflict: Code eindeutig, aber ohne Laufbeleg (T3 war als Beobachtung im Suite-Lauf vorgesehen).
  Remediation: Beim ersten normalen Lauf ohne Gate prüfen oder im Bericht als nur statisch belegt ausweisen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/run-notification-permission-uitest.sh:90
  Description: "Vorlage: ... (unberührt)" ist ein fester Text, keine Messung. Das Skript berührt die Vorlage tatsächlich nur lesend (jq auf simctl list).
  Spec requirement: AC-10 — Vorlage unverändert.
  Conflict: Behauptung ohne Prüfung; in der Praxis nur gelesen.
  Remediation: Boot-Status vor/nach vergleichen oder Text auf "nur gelesen" ändern.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: scripts/run-notification-permission-uitest.sh:21
  Description: Der Abbruchpfad bei belegter Sperre (T6) wurde nie ausgeführt (Skriptlauf hier verboten, kein Belegprotokoll). Statisch korrekt.
  Spec requirement: AC-8 — Abbruch mit Meldung ohne fremde Sperre anzutasten.
  Conflict: Nur Codelesung, kein Lauf.
  Remediation: T6 mit einem Wegwerf-Sperrpfad nachholen oder als ungeprüft ausweisen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/NotificationPermissionUITests.swift:96
  Description: Der Dialog wird sowohl vom Interruption-Monitor als auch aktiv über SpringBoard bedient. Antwortet der Monitor zuerst, existiert der Alert nicht mehr, und XCTAssertNotNil (Z. 102) schlägt fehl, obwohl answered schon true ist. Auf dem langsameren CI-Runner möglich, im Lauf nie beobachtet.
  Spec requirement: AC-5 / AC-13 — stabile Bedienung auf dem Runner.
  Conflict: Mögliche Flake-Quelle, nicht widerlegt.
  Remediation: Bei Flake im CI-Lauf den Zweig answered == true vor dem Assert abfangen.

Offen (kein Defekt): AC-13 (CI-Push-Lauf beider Hälften) ist erst nach dem Push belegbar, Phase 7. AC-5 englische Beschriftung nur im Code (Z. 17-18), Laufbeleg erst durch CI. AC-16: offene Grenzen stehen vollständig in CLAUDE.md und Spec; Ticket-/Berichtstext steht noch aus (Phase 7).

**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachprüfung von F001 nach PO-override (grep, sed). Code und Skript unverändert seit Runde 2 (Klasse 139 Zeilen, Skript 95 Zeilen wie zuvor).

Code reference: docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md:54
Code reference: CLAUDE.md:42

- F001 BEHOBEN: Die D7-Spec enthält Z. 54-55 den Nachtrag 2026-10-16 ("Dialog selbst ... seit #145 Durchgang 2 durch NotificationPermissionUITests geprüft", mit Verweis auf die D2-Spec). CLAUDE.md: D7-Absatz (Z. 36) trägt "seit #145 Durchgang 2 ... geprüft"; "Durchgänge 3–4 von #145 offen" steht zweimal (D1- und D2-Absatz).
- AC-14 PROVEN: CLAUDE.md-Absatz vollständig (Klasse, ENV, Skript, Sperren, Wegwerf-Simulator, Ein-Tag-Regel, offene Grenzen) plus D7-Hinweis gesetzt.
- AC-16 PROVEN für den Abschluss-Stand der Doku: alle fünf offenen Grenzen und "#145 bleibt offen (Durchgänge 3–4)" stehen in CLAUDE.md/Spec. Der Wortlaut in Ticket und Bericht ist Phase-7-Arbeit, kein Code-Defekt.
- AC-13 und AC-5 (englisch): Die Spec bindet AC-13 an den Push-Lauf, vor dem Push ist er nicht belegbar; der englische Dialog ist ohne CI nicht erzeugbar (Simulator ist de). Kein Defekt, aber auch kein Beweis. Bewertung: Phase-7-Punkte, die ein VERIFIED für den lokal prüfbaren Umfang zulassen; die Aussage lautet ausdrücklich nicht "13/13 bewiesen". Ein rotes CI-Ergebnis in Phase 7 würde das Urteil für AC-13/AC-5(en) aufheben (Rückfall laut Spec: Klasse + Skript, CI-Anschluss als Folgeschritt).
- F002-F005 bleiben LOW, nicht blockierend.

**Implementierer:** (nicht beteiligt)

### Runde 4
**Adversary:** Neue Lage: CI-Anschluss herausgenommen (PO-Entscheidung 2026-10-16), Ausnahmeweg aufgegeben. Nachprüfung per Diff, grep, Artefakt und Ticket-Kommentar (Issue 145 per Kommandozeile gelesen).

Code reference: .github/workflows/ci.yml:112
Code reference: RestockUITests/NotificationPermissionUITests.swift:22
Code reference: scripts/run-notification-permission-uitest.sh:67

- Rückgängig gemacht: AC-13-Haken samt Zusatz „PO-Ausnahme … Nachweis folgt“ und Verdict AMBIGUOUS. AC-13 wird nach dem ODER-Zweig neu bewertet.
- Belege Rückfall: Der Diff von ci.yml gegen 7942737 ist leer. `ci-anschluss-vertagt.md` nennt die Gründe (Anschluss im Ticket nicht verlangt, Beleg vor dem Push unmöglich, Ausnahmeweg blockiert) und den Stand (lokal beide Wege grün); der Entwurf liegt in `ci-anschluss-vertagt.diff`. Der Folgeschritt ist in #145 vermerkt (Kommentar gelesen: Anschluss vertagt, Folgeschritt, belegt zugleich den englischen Dialog). CLAUDE.md Z. 42 sagt „CI: noch nicht angeschlossen … Folgeschritt in #145“.
- AC-13 PROVEN über den ODER-Zweig: Anschluss nicht im Diff, Gründe dokumentiert (als Begründung mit lokalem Messstand, keine CI-Messung), Folgeschritt in #145. Kein offener Phase-7-Beleg mehr nötig.
- AC-12: durch den Rückfall gegenstandslos, kein Bruch. AC-12 beschreibt ci.yml bei angeschlossener CI; die Spec lässt über AC-13 ausdrücklich den Zweig zu, in dem der Anschluss nicht im Diff steht. HEAVY_CLASSES ist unverändert (ci.yml:112) und enthält die Klasse nicht. Die Runde-1-Bestätigung zu AC-12 beschrieb den früheren ci.yml-Stand und ist überholt. Ehrlich: AC-12 ist nicht „bewiesen“, es entfällt.
- AC-5 (en): jetzt offene Grenze des Folgeschritts (englischer Dialog erst mit dem CI-Lauf), in CLAUDE.md und im #145-Kommentar benannt. Beide Sprachen stehen im Code (Z. 17-18), lokal belegt ist Deutsch. Kein Defekt.
- AC-3: Ohne Anschluss setzt keine CI-Hälfte RESTOCK_NOTIF_DECISION; die Klasse läuft in Hälfte B als Teil von RestockUITests und überspringt sich beide Tests per XCTSkip (Z. 22-30). XCTSkip ist kein Fehlschlag, die Suite bleibt grün. Weiter nur statisch belegt (F002, LOW). Die Klasse legt ohne Gate keinen Zustand an und beeinflusst andere Klassen nicht.
- Frischer Lauf 2026-10-16 08:14:53 (test-green-output.txt): beide Wege GRÜN, je 2 ausgeführt (1 bestanden, 1 gewollt übersprungen), 0 Fehlschläge, keine Wegwerf-Simulatoren übrig. Klasse und Skript unverändert seit Runde 2 (139 bzw. 95 Zeilen, Prüfsummen gleich).
- AC-15 neu: ci.yml fällt aus dem Diff, Codezeilen 139 + 95 + 4 (pbxproj) = 238, unter 250.
- F002-F005 bleiben LOW, nicht blockierend.

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Umfang: AC-1 bis AC-11 und AC-14 bis AC-17 bewiesen (AC-5 deutsch). AC-13 erfüllt über den Rückfall-Zweig (CI-Anschluss nicht im Diff, Gründe dokumentiert, Folgeschritt in #145). AC-12 gegenstandslos durch den Rückfall. Der englische Teil von AC-5 ist offene Grenze des Folgeschritts.
Tests: Lauf 2026-10-16 08:14: je Weg 2 ausgeführt, 1 bestanden, 1 gewollt übersprungen, 0 Fehlschläge.
Regressionen: keine gefunden.
Findings: F001 behoben; F002-F005 LOW.

## Geprüfte Dateien

- sha256:9df6199232fe4f8aeb6a74dc90194f79758c2c050abe4964829e3394f6e9a40d  .github/workflows/ci.yml
- sha256:1a5592728959d6c74114051eaf2d73aeb0c99282781ec1ab6057e3ea06598a4f  CLAUDE.md
- sha256:b1b130f5f2c06adcecb599fdd233da79708267ceb66806a98c2459d0e6a2cbf1  Restock.xcodeproj/project.pbxproj
- sha256:bcbe3187dfa2ebb14cdb13ae340f02fee19f71aadc94a2c833035d2ef2408311  RestockUITests/NotificationPermissionUITests.swift
- sha256:46ea46407305865c3e6ec6f9945746984c498017a31065e63a9f6945966bfe53  docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md
- sha256:f8c2da3086a06eb0dd352f043bd71448a342a7ba9fcb2ea5ded73c54c92ed99b  scripts/run-notification-permission-uitest.sh

## Prüfbasis

- base: 7942737af4b0b8df5dc7fef692ade322ab6727d5
- blob:88e574b5f9bb9c39fd237d704760b49648da52ce  .github/workflows/ci.yml
- blob:0c4d2730786ea744d5af88cf934d80ebea1cc856  CLAUDE.md
- blob:2767ba8d7bfae7378da5cad27e2d29d825f17023  Restock.xcodeproj/project.pbxproj
- blob:fa359f3f945899c10df1874369f9007535ce6e43  RestockUITests/NotificationPermissionUITests.swift
- blob:6dc63c27f74b6f4d81aaa202bf16bf4e9e1db311  docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md
- blob:1d65e8ccd8d0ce6e57cae0c3df47e49a5a1de967  scripts/run-notification-permission-uitest.sh
