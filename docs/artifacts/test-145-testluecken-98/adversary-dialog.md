# Adversary Dialog — test-145-testluecken-98
Spec: docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md
Datum: 2026-10-15 11:30

## Checkliste
- [x] **AC-1:** Ausgangszustand vor dem Entsperren ist geprüft (kein DEV, „Restock Pro freischalten“ da, kein „Pro aktiv“); Start mit `-clearDeveloperModeForUITests` und Hash-Argument; Kette 5× „Version“ → Passwort → „Entsperren“ → Sheet schließt.
- [x] **AC-2:** Nach dem Entsperren „Developer Mode deaktivieren“, „Pro aktiv“ und nach „Fertig“ die DEV-Pill (Test T1).
- [x] **AC-3:** Neustart ohne Clear- und Hash-Argument (`launch(clearAndOverride: false)`), danach DEV-Pill, „Pro aktiv“, „Developer Mode deaktivieren“; `-developerMode` kommt in der Klasse nur in Kommentaren vor.
- [x] **AC-4:** Hash wird zur Laufzeit per CryptoKit im Format `%02x` (klein) berechnet, identisch zu `verify()`; kein Hash-Literal im Test.
- [x] **AC-5:** Gegenprobe T2 mit gesetzter Überschreibung und falschem Passwort: Fehlermeldung, Sheet bleibt, nach „Abbrechen“ weder „Pro aktiv“ noch DEV.
- [x] **AC-6:** `testWrongDevPasswordShowsErrorAndKeepsSheetOpen` unverändert (PaywallUITests.swift weder in HEAD~1..HEAD noch im Arbeitsbaum geändert) und im GREEN-Lauf passed.
- [x] **AC-7:** Release-Build gelungen, beide Zeichenketten 0 Treffer im Release-Binär; Gegenprobe im Debug-dylib 1 Treffer je Zeichenkette.
- [x] **AC-8:** Hash-Literal byte-gleich, Überschreibung und Clear nur in `#if DEBUG`, `DevPasswordSheet`/`verify()` unberührt.
- [-] **AC-9:** Gesamte Suite im gemeinsamen Lauf — offen bis Phase 7, nicht Defekt der Implementierung (`full-suite-output.txt` ist ein unvollständiger Stand ohne Abschlusszeile).
- [-] **AC-10:** Pflicht-Durchlauf als registriertes Werkzeug-Artefakt — offen bis Phase 7, nicht Defekt der Implementierung.
- [x] **AC-11:** CLAUDE.md-Absatz beschreibt beide Argumente korrekt gegen den Code; D5-Spec trägt den Schließungshinweis.
- [x] **AC-12:** Umfang: Produktcode +21/−1 (SettingsView +11/−1, SmartCartApp +10 nur DEBUG), Test +161, pbxproj +4, plus CLAUDE.md und D5-Spec; keine neuen Strings, Info.plist, `@AppStorage`-Änderung.
- [-] **AC-13:** Ticket und Berichte nennen die offenen Grenzen — offen bis Phase 7, nicht Defekt der Implementierung (Spec, Testkopfkommentar und CLAUDE.md nennen sie bereits: Release-Pfad mit echtem Passwort, Durchgänge 2–4, #145 bleibt offen).

## Dialog

### Runde 1
**Adversary:** Alles selbst gelesen (git diff HEAD, Test, SettingsView, SmartCartApp, GREEN-/RED-/Release-Ausgaben). Kein Build, kein Simulator gestartet.

Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:19
Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:26
Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:106
Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:131
Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:144

1. Test T1 (Zeile 106): Ausgangszustand → Kette → Neustart. Vor dem Entsperren werden DEV-Pill (keine), „Restock Pro freischalten“ (da) und „Pro aktiv“ (nicht da) geprüft, sonst würde ein Altzustand den Test leer bestehen lassen. Die Kette läuft über `enterPassword` mit echtem Fünffachtipp. Nach „Fertig“ DEV-Pill, dann `app.terminate()` und `launch(clearAndOverride: false)` (Zeile 131): ohne beide Argumente, der Zustand muss also aus dem Container kommen. Danach DEV-Pill, „Pro aktiv“, „Developer Mode deaktivieren“. Beide Texte existieren im Produktcode (SettingsView.swift:139, :299).
2. Argument-Domain-Falle: `grep developerMode` in der Klasse trifft nur Kommentarzeilen 8 und 10; kein Launch-Argument `-developerMode`. Andere Klassen (`PaywallUITests` mit `-developerMode NO`, Nachkauf-Klassen mit `YES`) schreiben nur die Argument-Domain, nichts Persistentes.
3. Hash (Zeile 19): `SHA256.hash(...).map { String(format: "%02x", $0) }.joined()` ist Zeichen für Zeichen die Formel aus `verify()` (SettingsView.swift:658-660). Klein-Hex.
4. tearDown (Zeile 26): startet die App mit `-clearDeveloperModeForUITests`, wartet auf das Zahnrad, beendet sie. Läuft auch nach einem Fehlschlag. Doppelgurt mit dem Clear beim Start. Damit bleibt im gemeinsamen Lauf kein `developerMode = true` für `StoreSetupUITests`/`OnboardingUITests` zurück, soweit der Clear-Pfad greift (Sicht auf den Code; Nachweis im gemeinsamen Lauf offen, AC-9).
5. Gegenprobe T2 (Zeile 144): echt, mit gesetzter Überschreibung und falschem Passwort („falsch“); prüft Fehlermeldung, offenes Sheet, nach „Abbrechen“ kein „Pro aktiv“, kein DEV. Wäre die Überschreibung kaputt oder `verify()` immer wahr, schlüge T2 fehl.
6. GREEN-Ausgabe (test-green-output.txt, 10:44–10:54): `testCorrectDevPasswordUnlocksAndSurvivesRestart` passed (175,7 s), `testWrongPasswordWithOverrideDoesNotUnlock` passed (82,7 s), PaywallUITests 5 passed, „Executed 7 tests, with 0 failures“, `** TEST SUCCEEDED **`. Testnamen passen zu den Dateien. Zeitstempel: SmartCartApp.swift 09:01:02, SettingsView.swift 09:01:04, Testdatei 08:44:51, GREEN-Lauf ab 10:44; der Code ist seit dem Lauf unverändert (nur Doku und Artefakte später).
7. RED-Ausgabe (test-red-output.txt): T1 schlug in Zeile 117 fehl, „Asynchronous wait failed … exists == 0 for object "Developer Mode" StaticText“; das Sheet blieb offen, weil Hash-Argument und Clear damals unbekannt waren und der Vergleich mit dem festen Hash scheiterte. T2 passed in RED (erwartbar, Falsch-Pfad). Passt zum behaupteten Fehlergrund; das Sheet wurde erreicht, ein Startproblem ist ausgeschlossen.
8. AC-6: Diff von PaywallUITests.swift gegen HEAD~1 und Arbeitsbaum leer; im GREEN-Lauf passed (213 s).
9. AC-7: Release gebaut (10:33, nach der Codeänderung um 09:01), kein `.debug.dylib` im Release, beide Zeichenketten im 28-MB-Binär 0 Treffer. Die Gegenprobe ist stichhaltig: Der Debug-Starter (40 KB) liefert erwartbar 0, deshalb wurde auf das Debug-dylib (21 MB) ausgeweitet, dort je 1 Treffer. Damit ist belegt, dass `strings` die Literale findet.
10. AC-8: Das Hash-Literal fab0966f…7c86 ist im alten und neuen Zeilenpaar identisch, nur `private let devPasswordHash` wird zu `private static let releaseDevPasswordHash` plus berechnete Eigenschaft. Überschreibung liegt in `#if DEBUG`/`#endif`; ohne DEBUG bleibt nur `return Self.releaseDevPasswordHash`. In SmartCartApp.swift liegt der Aufruf (Zeile 29) im `#if DEBUG`-Block 28–51 und die Funktion im Block 167–740. `DevPasswordSheet` und `verify()` stehen nicht im Diff.
11. AC-11: CLAUDE.md-Absatz gegen den Code gelesen: Eigenschaft `devPasswordHash`, `releaseDevPasswordHash`, Clear in `SmartCartApp.init()`, DEBUG-only, Domain-Falle, offene Grenzen; stimmt. D5-Spec trägt im Abschnitt „Dev-Passwort: Entscheidung Richtig-Pfad“ den Hinweis „Geschlossen durch #145 Durchgang 1“.
12. AC-12: Codedateien: SettingsView (+11/−1), SmartCartApp (+10), Test (+161), pbxproj (+4) = 4 Dateien, Produktcode +21/−1. Rest Doku/Artefakte. Keine Info.plist, kein neues `@AppStorage`, keine neuen Texte. Die Spec-Schätzung „ca. +90“ ist zu niedrig (Test allein 161), Summe Code ca. +187/−1 bleibt unter ±250 (F001).

Ergebnis Runde 1: kein Defekt; alles hält auf Anhieb, deshalb Runde 2 mit gezielten Randfällen.

**Implementierer:** Keine Änderung nötig.

### Runde 2
**Adversary:** Gezielte Randfälle aus dem Code.

Code reference: SmartCart/Views/Settings/SettingsView.swift:38
Code reference: SmartCart/Views/Settings/SettingsView.swift:334
Code reference: SmartCart/Views/Settings/SettingsView.swift:657
Code reference: SmartCart/SmartCartApp.swift:29
Code reference: SmartCart/SmartCartApp.swift:506

- Leerer String als Argument: `!override.isEmpty` fällt auf den festen Hash zurück; kein Entsperren ohne Passwort. Leere Eingabe in `verify()`: Hash von "" ≠ Release-Hash. Kein Bypass.
- `-devPasswordHashForUITests` ohne Wert: das nächste Argument (oder nichts) wird Wert; `string(forKey:)` liefert nil oder einen Fremdwert, der nie einem SHA256 entspricht; im Release ohnehin nicht kompiliert (AC-7).
- Großbuchstaben-Hex: `verify()` erzeugt klein, Vergleich ist exakter String; ein großgeschriebener Override würde nie passen (Test rot, nicht grün). Kein Sicherheitsproblem (F002).
- Persistenz der Überschreibung: Launch-Argumente liegen in der Argument-Domain, nicht im Container; der Neustart in T1 ohne Argument beweist, dass der Hash nicht haften bleibt, während `developerMode` haftet.
- Clear läuft im `defer` von `init()` (SmartCartApp.swift:29), `@AppStorage` liest erst beim Rendern; Clear vor Anzeige. T1 belegt das mit den Altzustand-Assertions vor dem Entsperren.
- Nebenwirkung auf andere Klassen: `removeObject` nur bei vorhandenem Argument (Guard); alle anderen Starts unberührt.
- Gemeinsamer Lauf (vorab prüfbar): Ein Zustandsleck ist nur möglich, wenn tearDown nicht läuft (z. B. Abbruch des Runners mitten im Test); dann räumt der Start-Clear von T1/T2 auf, Fremdklassen davor nicht. Restrisiko benannt, mit AC-9 zu belegen.
- `full-suite-output.txt` (11:16) endet mitten im Lauf ohne Abschlusszeile; wird nicht als Beleg gewertet.

**Implementierer:** Keine Änderung nötig; F001 und F002 als Hinweise akzeptiert.

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:1
  Description: Die Spec nennt "ca. +90/−2 LoC im Code"; tatsächlich Test +161, Produktcode +21/−1, pbxproj +4 (zusammen ca. +187), weiterhin innerhalb des Limits ±250 und 4 Codedateien.
  Spec requirement: AC-12 — Diff ca. +90/−2 LoC im Code
  Conflict: Schätzung in der Spec ist zu niedrig; Limit nicht verletzt.
  Remediation: Zahl in der Spec oder im Abschlussbericht korrigieren.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Settings/SettingsView.swift:38
  Description: Ein großgeschriebener Hex-Wert im Argument wird nicht normalisiert und passt nie zu `verify()` (klein). Nur DEBUG, der Test würde rot statt grün.
  Spec requirement: AC-8 — Überschreibung nur in `#if DEBUG`, verify() unberührt
  Conflict: Kein Verstoß; mögliche Verwirrung für künftige Testautoren.
  Remediation: Keine nötig; optional im Kommentar "klein geschriebenes Hex" ergänzen.

Confirmation:
  AC: AC-1
  Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:106
  Evidence: Ausgangszustand, Kette mit Fünffachtipp und Sheet-Schließen; GREEN passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Views/Settings/SettingsView.swift:299
  Evidence: "Developer Mode deaktivieren" (Zeile 299) und "Pro aktiv" (Zeile 139) existieren im Produktcode und werden im Test geprüft.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:131
  Evidence: Neustart ohne beide Argumente; kein `-developerMode` in der Klasse.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:19
  Evidence: CryptoKit-Hash im Format `%02x`, wie `verify()`.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:144
  Evidence: Falsches Passwort mit gesetzter Überschreibung, Fehlertext, Sheet offen, kein Pro/DEV.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: RestockUITests/PaywallUITests.swift:103
  Evidence: Datei unverändert; im GREEN-Lauf passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/test-145-testluecken-98/release-strings-check.txt:1
  Evidence: Release 0 Treffer, Debug-dylib je 1 Treffer, Release-Binär nach der Codeänderung gebaut.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/SmartCartApp.swift:29
  Evidence: Aufruf im `#if DEBUG`-Block 28–51, Funktion im Block 167–740; Hash-Literal byte-gleich; verify() unberührt.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: CLAUDE.md:40
  Evidence: Absatz stimmt mit dem Code überein; D5-Spec-Hinweis vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: RestockUITests/DeveloperModeUnlockUITests.swift:1
  Evidence: 4 Codedateien, Produktcode +21/−1, Gesamt unter ±250; keine Strings/Info.plist/AppStorage.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Nebenbefund `developerMode`: Produktions-Schreiber ist `SettingsView` nach erfolgreichem `verify()` (onUnlock, Zeile 336) und „Developer Mode deaktivieren“ (Zeile 291). Bedingung davor: Nutzer gibt das richtige Passwort ein bzw. tippt „deaktivieren“. Test für diesen Weg: `testCorrectDevPasswordUnlocksAndSurvivesRestart` (Entsperren, Persistenz über Neustart); das Deaktivieren hat keinen Test (nicht Gegenstand dieses Durchgangs).

## Verdict: VERIFIED
Kein Defekt gefunden; nur zwei LOW-Hinweise. Keine Tests selbst gelaufen (harte Grenze); vorhandene GREEN-Ausgabe: 7 Tests, 0 Fehler, 0 übersprungen, Code seither unverändert. Offen bis Phase 7, nicht Defekt der Implementierung: AC-9, AC-10, AC-13.

## Geprüfte Dateien

- sha256:4f5ae63b5f0e6a8d69503e33feb71527f4292c7276b91b703f32789a66b3618b  CLAUDE.md
- sha256:c0232e0ccd3849bdbf757c336593d9de5b5e526b3e80eb8ef1e5cb0bf9f5188f  RestockUITests/DeveloperModeUnlockUITests.swift
- sha256:3b6ef5a7f72d87684327f68a932fc1a7af3ae89ad45fd8e012f7932b93b5ad48  RestockUITests/PaywallUITests.swift
- sha256:ea0834c5dc5f2491245b9fa1f2d766735ff02e0b073dad5a10219bc0f172b931  SmartCart/SmartCartApp.swift
- sha256:7129f1213bc35f51227233c6c185d48873cb9d1757fd4e195df6edb741fe4501  SmartCart/Views/Settings/SettingsView.swift
- sha256:12170dafe273173ca93e3b6a2ac42800b18131d697a30d509f6be4eec80ce059  docs/artifacts/test-145-testluecken-98/release-strings-check.txt

## Prüfbasis

- base: f8afca7913d49bcca9db09892f6d6f2b8b19cb05
- blob:0b8851eea10bc8c00ff1f4dc873a7eb9155631b0  CLAUDE.md
- blob:bcd0c3981299ae7c176d05288de32a21d88cd4b7  RestockUITests/DeveloperModeUnlockUITests.swift
- blob:27669c62a3b92bdb44932e0e6cb060c147019e0a  RestockUITests/PaywallUITests.swift
- blob:3aed95cb216424dfcee45a44ec5da87140761bf0  SmartCart/SmartCartApp.swift
- blob:fa1924209a17cf76b3f03528de7965c85bdf9b55  SmartCart/Views/Settings/SettingsView.swift
- blob:97b70c28639176267b461533666611edac5b7ac5  docs/artifacts/test-145-testluecken-98/release-strings-check.txt
