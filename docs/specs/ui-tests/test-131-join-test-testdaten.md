---
entity_id: test-131-join-test-testdaten
type: bugfix
created: 2026-10-09
updated: 2026-10-09
status: draft
workflow: fix-131-join-test-ci-rot
tags: [test, ui-test, ci, cloudkit, testdaten, join-sheet, issue-131]
---

# Beitreten-Tests mit zufälligem Code statt echtem Nutzercode (Issue #131)

## Approval

- [ ] Approved — PO (offen)

## Purpose

`testJoinWithLegacySixCharacterCodeTriggersLookup` ist auf dem CI-Runner seit 2026-10-09 rot. Der Test tippt
den echten, von einem Nutzer gemeldeten Code `CGU5ZN` und erwartet „Kein Store mit diesem Code gefunden.“,
weil es diesen Eintrag in der öffentlichen CloudKit-Datenbank früher nicht gab. **Jetzt existiert er**
(Laden „Lidl“, „Von Henning“): Die Suche liefert eine Vorschau statt eines Fehlers, der Fehlertext erscheint
nie, das 15-s-Fenster wird zu Recht ausgeschöpft. Beleg: UI-Hierarchie im Fehlmoment (xcresult Run
37888378658, Anhang „App UI hierarchy“) zeigt `TextField value: CGU5ZN`, `Lidl`, `Von Henning` und den
Button `🛒 Lidl hinzufügen`. Verbindliche Analyse: `docs/context/fix-131-join-test-ci-rot.md`, Abschnitt
„Analysis“.

Die frühere Hypothese „CloudKit-Antwort dauert länger als 15 s“ ist **widerlegt** (das Sheet war gesund, die
Suche kehrte zurück). Ebenso falsch ist die Testannahme „ohne iCloud-Konto schlägt die Suche fehl“
(Kommentare in `RestockUITests.swift`): Die öffentliche Datenbank ist ohne Konto lesbar. Wann der Eintrag
`CGU5ZN` entstand, ist nicht belegt (Annahme: Geräteläufe von Henning zu #121, Build 10/11); für den Fix
unerheblich. Der Geschwistertest mit `TESTCODE12` blieb grün, weil dieser Code nicht existiert.

**Änderung:** Beide Join-Tests nutzen einen je Lauf zufällig erzeugten Code aus Großbuchstaben: 6 Zeichen im
Legacy-Test (Kollision mit einem echten Code ≈ 1 : 10⁹), 10 Zeichen im Geschwistertest statt `TESTCODE12`.
Die Umstellung des Geschwistertests ist die Empfehlung der Analyse (gleiche Datei, gleiche Fehlerklasse,
minimaler Mehraufwand); die PO-Entscheidung dazu steht noch aus und ist hier als **gewählt** festgehalten
(siehe Risiken). Erzeugung per Regel, kein Modell. Erwartungstext, echter Codepfad und Wartefristen bleiben.

**Offene Grenze (gilt für jede Zusage dieser Spec):** Der Test hängt weiter am echten CloudKit-Netz. Lange
Antwortzeiten des Runners (Thema #111) und die theoretische Möglichkeit, dass ein zufälliger Code doch
existiert, bleiben bestehen. Es gibt keinen Fake.

## Source

- **Geändert:** `RestockUITests/RestockUITests.swift`
  - kleine Hilfsfunktion (privat im Testfile), z. B. `randomJoinCode(length:)`: `length` Zeichen aus `A–Z`
    per `String((0..<length).map { _ in letters.randomElement()! })`; Form legt Phase 5 fest, Verhalten ist
    verbindlich.
  - `testJoinSharedListSheetIsScrollableAndUsable` (ca. Zeile 64): `typeText("TESTCODE12")` → Zufallscode mit
    10 Zeichen; Kommentar „Ohne echten iCloud-Account schlägt der CloudKit-Lookup fehl“ korrigieren.
  - `testJoinWithLegacySixCharacterCodeTriggersLookup` (ca. Zeile 116): `typeText("CGU5ZN")` →
    Zufallscode mit 6 Zeichen; der Kommentar „exakt der vom Nutzer gemeldete, echte (alte) Code“ und die
    Annahme „ohne iCloud-Konto schlägt sie fehl“ werden korrigiert (Begründung: öffentliche DB ist ohne Konto
    lesbar, deshalb muss der Code garantiert unbekannt sein). Zeilennummern Stand 2026-10-09.
  - Der Test belegt weiterhin den 6-Zeichen-Auslösepfad (`JoinStoreSheet.triggerLookup`); dass `CGU5ZN` der
    historische Fehlerfall war, bleibt im Doc-Kommentar des Tests erwähnt.
- **Nicht geändert:** gesamter Produktcode (`StoreShareSheet.swift`, `SharedStoreService.swift`),
  `UITestWait.swift` (Wartefrist-Hilfen nur nutzen, wenn nötig, sonst unberührt), `project.pbxproj` (keine
  neue Datei), `ci.yml`, Scheme, alle übrigen Tests.
- **Keine** neuen Produkt-Strings, **keine** neuen Dependencies, **keine** Änderung an `Info.plist`,
  `@AppStorage`-Schlüsseln oder Audio-Dateien.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `docs/context/fix-131-join-test-ci-rot.md` | doc | verbindliche Analyse, Root Cause belegt |
| `SmartCart/Views/Store/StoreShareSheet.swift` (`triggerLookup`, `lookup`) | code | Auslöser bei 6 bzw. 10 Zeichen; Fehlertext bei jedem Fehler (nur lesen) |
| `SmartCart/Services/SharedStoreService.swift` (`fetchPreview`) | code | öffentliche CloudKit-DB, lesbar ohne Konto (nur lesen) |
| `RestockUITests/UITestWait.swift` | code | Wartefrist-Hilfen (#111), nur nutzen, wenn nötig |
| Öffentliche CloudKit-DB | ext | echter Suchpfad, bewusst kein Fake |
| Simulator `Restock-Validate` | tool | lokaler Lauf; nie parallel (Memory „Eigenes Testgerät je Projekt“) |
| GitHub-Runner `macos-26` | ci | Nachweis CI-Lauf (78 Tests) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/RestockUITests.swift` | MODIFY | Hilfsfunktion für Zufallscode; beide Join-Tests nutzen sie; falsche Kommentare korrigiert |

### Estimated Changes

- Files: 1 (Limit 4–5)
- LoC: ca. +12 / −6 (Limit ±250). Das LoC-Gate zählt Testcode als Produktivcode; vor dem Abschluss mit
  `git diff --stat` gegen den Tip-Commit prüfen.
- Seiteneffekte: keine; kein Zustand im App-Group-Container, daher kein Aufräum-Argument nötig.

## Definition of Done

- [ ] RED vor der Änderung mit festem Code `CGU5ZN` lokal belegt (AC-1)
- [ ] Beide Join-Tests mit Zufallscode lokal grün (AC-2)
- [ ] Gesamte UI-Suite im gemeinsamen Lauf grün, Testzahl > 0, kein Abbruch, kein Retry-Flag (AC-3)
- [ ] CI-Lauf auf dem PR grün, 78 Tests (AC-4)
- [ ] Zufallscode je Lauf verschieden, richtige Länge und Zeichenklasse (AC-5)
- [ ] Diff = genau 1 Datei, ca. +12/−6 LoC (AC-6)
- [ ] Durchlauf der App im Simulator als registriertes Artefakt (AC-7)
- [ ] Offene Grenze in Ticket und Bericht benannt (AC-8)

## Implementation Details

**Hilfsfunktion.** Im Testfile, privat, ohne Abhängigkeit: erzeugt `length` Zeichen aus `A–Z` mit
`randomElement()` (System-Zufall). Reiner Regelweg, kein Modell. Die Funktion hat keinen Zustand und wird in
beiden Tests aufgerufen (6 bzw. 10). Großbuchstaben, weil das Sheet den Code normalisiert und echte Codes aus
Großbuchstaben/Ziffern bestehen (`SharedStoreService.generateCode()`); Ziffern werden bewusst weggelassen,
Kollision bei 6 Buchstaben ≈ 26⁻⁶ je vergebenem Code, praktisch vernachlässigbar.

**Kommentare.** Die Aussagen „Ohne echten iCloud-Account schlägt der Lookup fehl“ werden ersetzt durch:
Die öffentliche Datenbank ist ohne Konto lesbar; „nicht gefunden“ erscheint nur für einen Code, den es nicht
gibt, deshalb je Lauf ein zufälliger. Erwartungstext, 15-s-Fristen und der Rest des Ablaufs bleiben
unverändert.

**Reproduktion (RED, Pflichtschritt, nicht dauerhaft im Repo).** Zuerst klären, warum der lokale Versuch
früher bei „Code-Eingabefeld im JoinStoreSheet nicht sichtbar“ nach 13 s scheiterte (anderer Fehler als auf
CI, daher keine Reproduktion). Kein Raten: Zustand und Sprache von `Restock-Validate`, Scheme-Sprache
(`de`/`DE`), Platzhaltertext `Z.B. ABCD-EFG-HIJ` und die UI-Hierarchie im Fehlmoment (Screenshot/Hierarchie
per Anhang oder `simctl`) prüfen und die Ursache benennen, auf demselben Weg wie Henning/CI
(`xcodebuild test` mit dem Scheme, ohne Extra-Build-Settings). Danach läuft der unveränderte Test mit festem
`CGU5ZN` lokal: erwartet Rot, in der Hierarchie die Vorschau „Lidl“ statt des Fehlertexts. Lässt sich der
lokale Aufbau nicht klären, wird das offen berichtet und der CI-Beleg (Run 37888378658) bleibt die einzige
Reproduktion; der Fix wird dann nicht als lokal am Fehlerfall bewiesen ausgegeben.

**Durchlauf (Pflicht, „Die App wird benutzt, nicht nur gebaut“).** Im Simulator die App wie ein Nutzer
starten, „Geteilter Liste beitreten“ öffnen, einen zufälligen Code tippen: Der Fehlertext „Kein Store mit
diesem Code gefunden.“ erscheint. Der Lauf wird als Artefakt registriert (echter Lauf, Commit-Kennung und
Zeitstempel passend, nie von Hand gesetzt).

**Lokal gesamt:** Gesamte UI-Suite auf `Restock-Validate` im gemeinsamen Lauf, ohne zusätzliche
Build-Settings (Memory „CODE_SIGNING_ALLOWED=NO bricht die App-Gruppe“); Testzahl > 0 und Abbrüche prüfen
(Memory „Null-Test-Lauf ist kein Grün“).

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED, Nachweisschritt, nicht dauerhaft im Repo): GIVEN der unveränderte Test mit festem Code
  `CGU5ZN`, WHEN er lokal auf `Restock-Validate` läuft, THEN ist er rot bzw. die Hierarchie zeigt die
  Vorschau „Lidl“ statt des Fehlertexts; vorher ist geklärt, warum der frühere lokale Versuch an „Code-
  Eingabefeld nicht sichtbar“ scheiterte.
- [ ] T2: GIVEN `testJoinWithLegacySixCharacterCodeTriggersLookup` mit Zufallscode (6 Zeichen), WHEN er lokal
  läuft, THEN erscheint „Kein Store mit diesem Code gefunden.“ und der Test ist grün.
- [ ] T3: GIVEN `testJoinSharedListSheetIsScrollableAndUsable` mit Zufallscode (10 Zeichen), WHEN er lokal
  läuft, THEN ist er grün (Feld und Abbrechen antippbar, Fehlertext, Rückkehr zum Home-Screen).
- [ ] T4: GIVEN die gesamte UI-Suite, WHEN sie lokal im gemeinsamen Lauf auf `Restock-Validate` läuft, THEN
  sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag.
- [ ] T5: GIVEN die Codeerzeugung, WHEN sie mehrfach aufgerufen wird (6 und 10 Zeichen), THEN sind die
  Codes je Aufruf verschieden, haben die verlangte Länge und bestehen nur aus `A–Z` (Assert im UI-Test auf
  Länge und Zeichenklasse des getippten Codes, oder kleiner Logiktest ohne App-Start).
- [ ] T6: GIVEN der PR, WHEN der CI-Lauf auf dem Runner läuft, THEN ist er grün mit 78 Tests.
- [ ] T7: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat` läuft, THEN ist es genau 1 Datei
  (`RestockUITests/RestockUITests.swift`), ca. +12/−6 LoC.

## Acceptance Criteria

- **AC-1:** GIVEN der unveränderte Test mit festem Code `CGU5ZN` (Stand vor der Änderung), WHEN er lokal auf
  `Restock-Validate` auf dem Weg des Scheme-Laufs ausgeführt wird, THEN schlägt er fehl bzw. zeigt die
  Vorschau „Lidl“ statt des Fehlertexts (RED belegt); die Ursache des früheren lokalen Fehlers „Code-
  Eingabefeld nicht sichtbar“ ist vorher benannt oder offen berichtet.
- **AC-2:** GIVEN beide Join-Tests mit je Lauf zufälligem Code, WHEN sie lokal einzeln und im Lauf laufen,
  THEN sind beide grün; der Erwartungstext „Kein Store mit diesem Code gefunden.“ und die Wartefristen sind
  unverändert.
- **AC-3:** GIVEN die gesamte UI-Suite, WHEN sie lokal im gemeinsamen Lauf auf `Restock-Validate` läuft,
  THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag.
- **AC-4:** GIVEN der PR, WHEN der CI-Lauf abgeschlossen ist, THEN ist er grün mit 78 Tests.
- **AC-5:** GIVEN die Codeerzeugung, WHEN sie wiederholt aufgerufen wird, THEN sind die Codes je Lauf
  verschieden, 6 Zeichen im Legacy-Test, 10 Zeichen im Geschwistertest, nur Großbuchstaben `A–Z`; der
  Legacy-Test löst weiter den 6-Zeichen-Pfad aus.
- **AC-6:** GIVEN der Diff dieses Fixes, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau
  `RestockUITests/RestockUITests.swift` (ca. +12/−6 LoC), ohne Produktcode, `project.pbxproj`-Änderung,
  neue Strings oder Dependencies; `UITestWait.swift` ist unberührt, sofern nicht nötig.
- **AC-7:** GIVEN die App im Simulator, WHEN sie als Nutzer durchgespielt wird (Beitreten-Sheet öffnen,
  zufälligen Code tippen), THEN erscheint der Fehlertext „Kein Store mit diesem Code gefunden.“; der
  Durchlauf ist als Artefakt registriert (echter Lauf, Commit-Kennung und Zeitstempel passend, nicht von
  Hand gesetzt).
- **AC-8:** GIVEN der Abschluss des Fixes, WHEN Ticket und Berichte formuliert werden, THEN ist die offene
  Grenze ausdrücklich genannt: Der Test hängt weiter am echten CloudKit-Netz, Antwortzeiten des Runners
  (#111-Thema) und die theoretische Existenz eines zufälligen Codes bleiben; es gibt keine Aussage
  „deterministisch“ oder „flakefrei“.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testdaten-Korrektur im Testfile. Kein Eingriff in App-Architektur; keine frühere
  Entscheidung wird gekippt (der Test läuft weiter über den echten CloudKit-Pfad).

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Je Lauf zufälliger Code (6 bzw. 10 Großbuchstaben), per Regel erzeugt | trifft die belegte Ursache (Test hing an einem Livedatum, das sich änderte); 1 Datei, kein Produktcode; Restrisiko Kollision ≈ 1 : 10⁹ |
| B | Fake/DEBUG-Startargument mit `SharedStoreDatabase`-Fake aus #121 | deterministisch, kippt aber die Entscheidung „Test läuft über den echten CloudKit-Pfad“, berührt Produktcode, mehr Dateien; verworfen |
| C | Beide Ausgänge akzeptieren (Fehlertext ODER Vorschau) | Test wäre bei jedem Datenbestand grün, damit wertlos; verworfen |
| D | Nur Wartefrist verlängern | widerlegt: die Suche kehrt zurück, es fehlt nicht Zeit |

Kein Modell beteiligt: deterministische Testlogik mit Zufallszeichen (Regeln vor Modell). Gekippte frühere
Entscheidung: keine ADR.

**Entscheidung:** Weg A.

## Risiken

- **Geschwistertest mitumstellen (PO-Entscheidung steht aus):** Die Analyse empfiehlt „mitumstellen“, die
  Spec hält das als gewählt fest. Lehnt der PO ab, entfällt nur die 10-Zeichen-Variante (ca. −3 LoC); die
  restliche Spec bleibt gültig. `TESTCODE12` ist ein erfundener Code, der heute nicht existiert, aber
  morgen jemand anlegen könnte; derselbe Fehlerklasse.
- **Zufälliger Code existiert doch:** Kollision ≈ 1 : 10⁹ je Lauf (6 Zeichen), bei 10 Zeichen vernachlässigbar.
  Tritt sie auf, sähe man die Vorschau statt des Fehlers (wie bei #131); das bleibt eine offene Grenze, kein
  Fehler der Umsetzung.
- **Echtes CloudKit-Netz:** Der Test hängt weiter an der Antwortzeit der öffentlichen DB auf dem Runner
  (Thema #111); die 15-s-Frist kann bei langsamer Antwort reißen. Kein Fake (Alternative B verworfen).
- **Lokale Reproduktion nicht gelungen:** Wenn der frühere lokale Fehler („Code-Eingabefeld nicht sichtbar“)
  nicht geklärt werden kann, ist der Fehlerfall nur am CI-Lauf belegt; das wird offen berichtet (AC-1).
- **Zeilennummern verschieben sich:** Maßgeblich sind die Testnamen, nicht die Zeilen.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün.
- **LoC-Gate zählt Testcode als Produktivcode:** ca. +12/−6 weit unter dem Limit; trotzdem prüfen.

## Changelog

- 2026-10-09: Initial spec created (Issue #131; Zufallscode statt echtem Nutzercode in beiden Join-Tests,
  Nachweise RED/GREEN lokal, gemeinsamer Lauf, CI und Durchlauf im Simulator)
