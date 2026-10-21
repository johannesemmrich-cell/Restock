---
entity_id: inmemory-container-ohne-cloudkit
type: bugfix
created: 2026-10-21
updated: 2026-10-21
status: draft
version: "1.0"
workflow: fix-194-inmemory-container-cloudkit
tags: [testing, swiftdata, cloudkit, ios27, issue-194]
---

# In-Memory-Testspeicher ohne CloudKit-Spiegelung (Issue #194)

## Approval

- [ ] Approved

## Purpose

Auf iOS 27.0 reißt `NotificationDigestChainTests` den Test-Host achtmal ab (24 Absturzberichte am 2026-10-21 in
drei Läufen, alle an Zeile 208, dem `save()`). Ursache: fünf Testdateien legen den In-Memory-Speicher mit
`ModelConfiguration(isStoredInMemoryOnly: true)` an und lassen `cloudKitDatabase` auf `.automatic`. Der Test-Host
trägt die iCloud-Berechtigung, SwiftData hängt die Spiegelung an, der Aufbau scheitert im Simulator ohne Konto
(`NSCocoaErrorDomain 134400`), iOS 27 entfernt den Speicher („store was removed before the mirroring delegate
could recover") und `save()` wirft `NSInternalInconsistencyException: No eligible connection available`. Auf
iOS 26 blieb der Speicher trotz Fehler bestehen. Hat es bisher funktioniert? Ja, auf iOS 26 (CI) und bis zur
Umstellung auf iOS 27.0 lokal. Zwölf weitere Testdateien setzen `cloudKitDatabase: .none` bereits.

Änderung (PO-Entscheidung 2026-10-21): Alle fünf Stellen erhalten `cloudKitDatabase: .none`, und ein Strukturtest
hält künftige Verstöße rot. #99 wartet auf diesen Fix (AC „bestehende Unit-Tests grün" auf iOS 27).

**Offene Grenze (gilt für jede positive Zusage dieser Spec):**
- #195 (`ReceiptTextRecognizerTests` T1, 3 Assertions, OCR auf iOS 27) bleibt rot; das ist ein anderes Ticket.
  „Unit-Suite stabil" heißt hier: kein Host-Absturz, nicht: alle Tests grün.
- Die CI prüft iOS 26, dort trat der Fehler nie auf; die CI kann diese Änderung daher weder bestätigen noch
  widerlegen. Der Nachweis ist ein lokaler Lauf im Simulator mit iOS 27.0.
- Es wird nichts auf Hennings Geräten gestartet; alle Läufe nur im Simulator.
- Die Abschaltung der Spiegelung ändert keine Testaussage, weil keiner der fünf Tests CloudKit prüft.
- Ein Hänger von `xcodebuild` nach Testende (Diagnose-Sammlung bis 10 min, #21) ist möglich und kein Fehler
  dieses Fixes.

## Source

- **Geändert:**
  - `RestockTests/NotificationDigestChainTests.swift` (Zeile 203), `RestockTests/ReceiptAIResolutionChainTests.swift`
    (56), `RestockTests/ReceiptKnownItemNamesTests.swift` (11), `RestockTests/ReceiptParserSuggestionTests.swift`
    (14), `RestockTests/ReceiptResolutionStatsTests.swift` (33): jeweils der `ModelConfiguration`-Aufruf.
  - `CLAUDE.md` — ein Satz im Testabschnitt.
- **Neu:** `scripts/test_inmemory_containers_no_cloudkit.py` (Strukturtest).
- **Nicht geändert:** Produktcode (`SmartCart/`, `SmartCartWidgets/`, `RestockShareExtension/`; der Produktcode
  nutzt In-Memory in `SmartCartApp.swift:123` bereits mit `cloudKitDatabase: .none`), `RestockUITests/`,
  `Restock.xcodeproj/project.pbxproj`.
- Keine neuen Strings, Dependencies, `Info.plist`-Einträge oder `@AppStorage`-Schlüssel.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `docs/context/fix-194-inmemory-container-cloudkit.md` | doc | verbindliche Analyse: Absturzberichte, Root Cause, Vorbilder |
| SwiftData `ModelConfiguration(cloudKitDatabase:)` | framework | Parameter, mit dem die Spiegelung abgeschaltet wird (seit iOS 17) |
| zwölf Testdateien mit `cloudKitDatabase: .none` (z. B. `PriceSourceTests.swift:107`, `AddItemIntentTests.swift:19`) | code | Vorbild für die Form der Änderung |
| `scripts/test_ci_ui_retry.py`, `scripts/test_ci_notification_permission.py` | script | Muster für Strukturtests (unittest, liest Repo-Dateien) |
| Simulator `Restock-Validate-27` (iPhone 17, iOS 27.0, UDID 9034BD4F-2D5F-49D5-B906-838326D51C95) | tool | Lauf der Unit-Tests auf iOS 27.0 |
| Sperren für schwere Läufe (`/tmp/heavy-build.lock` u. a.) | tool | nur ein xcodebuild/Simulator-Lauf zur Zeit, über die Hauptsitzung |
| Issue #99 (`docs/specs/ci/release-build-und-iphone-only.md` im Zweig #99) | doc | Nutznießer; wird nach dem Merge rebased |
| Issue #195 | doc | bekannte rote Tests, ausdrücklich nicht Teil dieses Fixes |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockTests/NotificationDigestChainTests.swift` | MODIFY | `cloudKitDatabase: .none` am In-Memory-Aufruf (1 Zeile) |
| `RestockTests/ReceiptAIResolutionChainTests.swift` | MODIFY | dito |
| `RestockTests/ReceiptKnownItemNamesTests.swift` | MODIFY | dito |
| `RestockTests/ReceiptParserSuggestionTests.swift` | MODIFY | dito |
| `RestockTests/ReceiptResolutionStatsTests.swift` | MODIFY | dito |
| `scripts/test_inmemory_containers_no_cloudkit.py` | CREATE | Strukturtest, ca. 35 Zeilen |
| `CLAUDE.md` | MODIFY | ein Satz beim Testabschnitt |

### Estimated Changes

- Files: 7 (Limit 4–5 pro Änderung; Überschreitung offengelegt: fünf davon sind Einzeiler gleicher Form, eine
  ist Doku, effektiv ein Strukturtest plus eine Muster-Anwendung; PO hat „alle fünf plus Strukturtest"
  entschieden)
- LoC: ca. +40 / −5 (Limit ±250). Das LoC-Gate zählt Testcode als Produktivcode; vor dem Abschluss
  `git diff --stat` gegen den Tip-Commit prüfen.
- Seiteneffekte: keine am Produkt; nur Testcode und Doku.

## Definition of Done

- [ ] Strukturtest liegt vor, RED-Protokoll (5 Treffer) und GREEN-Protokoll liegen im Artefaktordner (AC-1)
- [ ] Die fünf Dateien enthalten `cloudKitDatabase: .none`, je Datei genau eine geänderte Zeile (AC-2)
- [ ] `NotificationDigestChainTests` auf iOS 27.0 8/8 grün, RED-Protokoll davor liegt vor (AC-3)
- [ ] Gesamte Unit-Suite auf iOS 27.0 ohne Host-Absturz, nur #195 rot (AC-4)
- [ ] Produktcode, `RestockUITests/` und `project.pbxproj` unverändert (AC-5)
- [ ] Durchlauf im Simulator mit Bildschirmfoto der Startseite (AC-6)
- [ ] Offene Grenze steht in Ticket, PR-Beschreibung und Bericht
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen

## Implementation Details

**Aufrufstellen.** Jede der fünf Stellen bekommt den Parameter `cloudKitDatabase: .none` in der Form der zwölf
Vorbilder (`ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)`, bzw. mit den dort sonst
üblichen Parametern). Sonst ändert sich nichts: gleiches Schema, gleiche Tests, gleiche Assertions.

**Strukturtest `scripts/test_inmemory_containers_no_cloudkit.py`.** unittest nach dem Muster der vorhandenen
`scripts/test_ci_*.py`. Er liest alle `RestockTests/*.swift`, findet jedes Vorkommen von
`isStoredInMemoryOnly: true` und prüft, dass im selben `ModelConfiguration(...)`-Aufruf `cloudKitDatabase: .none`
steht. Der Aufruf wird ab dem nächsten vorausgehenden `ModelConfiguration(` bis zur passenden schließenden
Klammer betrachtet, damit auch Aufrufe über mehrere Zeilen erkannt werden. Jeder Verstoß erscheint in der
Ausgabe als `Datei:Zeile`; bei mindestens einem Verstoß endet der Lauf mit Exit-Code ≠ 0. Lauf:
`python3 scripts/test_inmemory_containers_no_cloudkit.py`. Der Strukturtest enthält zusätzlich einen Selbsttest mit
eingebettetem Beispieltext (ein mehrzeiliger Aufruf ohne `cloudKitDatabase: .none`, einer mit), der die Erkennung
selbst prüft (Test 3), unabhängig vom Stand der echten Testdateien.

**CLAUDE.md.** Ein Satz beim Testabschnitt: In-Memory-Container in Tests immer mit `cloudKitDatabase: .none`
anlegen (sonst stürzt der Test-Host auf iOS 27 ab); der Strukturtest `scripts/test_inmemory_containers_no_cloudkit.py`
erzwingt das.

**Reihenfolge (TDD).** Strukturtest schreiben, RED (5 Treffer) protokollieren; `NotificationDigestChainTests`
auf iOS 27.0 laufen lassen, RED (Host-Absturz) protokollieren; Fix; Strukturtest GREEN; Klasse GREEN; gesamte
Unit-Suite; Durchlauf mit Bildschirmfoto. Protokolle unter `docs/artifacts/fix-194-inmemory-container-cloudkit/`.

## Expected Behavior

- **Input:** Unit-Tests unter iOS 27.0 im Simulator ohne iCloud-Konto.
- **Output:** Die fünf Testklassen legen ihren In-Memory-Speicher ohne CloudKit-Aufbau an; kein
  Host-Neustart, kein Absturzbericht. Ein künftiger Test mit `isStoredInMemoryOnly: true` ohne
  `cloudKitDatabase: .none` macht den Strukturtest rot.
- **Side effects:** keine; das Verhalten der App ändert sich nicht.

## Known Limitations

- #195 bleibt in der Suite rot (`ReceiptTextRecognizerTests` T1, 3 Assertions).
- Die CI (iOS 26) zeigt den Fehler nie; sie bestätigt nur, dass nichts verschlechtert wurde.
- Der Strukturtest prüft Text, nicht Laufzeitverhalten; ein Container, der anders als über
  `ModelConfiguration(isStoredInMemoryOnly: true)` entsteht, wird nicht erkannt.
- `xcodebuild` kann nach Testende bis zu 10 min hängen (#21).
- Das RED-Protokoll zu AC-3 stammt nicht von diesem Arbeitsstand, sondern von der Gegenprobe vom 2026-10-21
  08:21 auf einer Wegwerf-Kopie von `e9a6b79` (Testdateien identisch zu `main`); ein erneuter RED-Lauf hätte dem
  PO acht weitere Absturzmeldungen beschert, ohne neue Information (Adversary F001, LOW, offengelegt).
- „CI prüft iOS 26" ist belegt für den Lauf 39209844531 vom 2026-10-19 (`Using iPhone 17 Pro … on runtime
  iOS-26-5`, Xcode 26.6); die CI wählt die neueste Laufzeit des Runners, ein Wechsel auf iOS 27 kommt mit dem
  nächsten Runner-Image von selbst.
- Der Strukturtest meldet `cloudKitDatabase:.none` ohne Leerzeichen fälschlich und findet den Marker auch in
  Kommentaren; beides ist im Projekt nicht vorhanden und würde beim ersten Auftreten sichtbar.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN der Stand vor dem Fix, WHEN `python3 scripts/test_inmemory_containers_no_cloudkit.py` läuft,
  THEN meldet er 5 Verstöße mit `Datei:Zeile` und endet mit Exit ≠ 0 (RED).
- [ ] Test 2: GIVEN ein Stand, in dem alle In-Memory-Aufrufe `cloudKitDatabase: .none` tragen, WHEN der
  Strukturtest läuft, THEN meldet er 0 Verstöße und Exit 0 (GREEN).
- [ ] Test 3: GIVEN ein In-Memory-Aufruf, dessen Parameter über mehrere Zeilen verteilt sind und
  `cloudKitDatabase: .none` fehlt, WHEN der Strukturtest läuft, THEN wird der Aufruf als Verstoß gemeldet
  (Testfall im Strukturtest mit Beispieltext).
- [ ] Test 4: GIVEN der Stand vor dem Fix, WHEN `NotificationDigestChainTests` auf iOS 27.0 im Simulator läuft,
  THEN stürzt der Test-Host ab („Restarting after unexpected exit"), die Klasse wird nicht 8/8 grün (RED).
- [ ] Test 5: GIVEN der Stand nach dem Fix, WHEN dieselbe Klasse läuft, THEN sind 8 von 8 Tests grün ohne
  Host-Neustart (GREEN).

Weitere Prüfungen: gesamte Unit-Suite auf iOS 27.0 (`-only-testing:RestockTests`), Zählung von
`Restarting after unexpected exit` und neuen `Restock-*.ips` im Lauffenster, `git diff --stat` für den Umfang.

## Acceptance Criteria

- **AC-1:** GIVEN der Strukturtest `scripts/test_inmemory_containers_no_cloudkit.py`, WHEN er gegen den Stand
  vor dem Fix läuft, THEN liegt ein RED-Protokoll mit genau 5 Treffern vor, und WHEN er nach dem Fix läuft,
  THEN ist er grün (0 Verstöße, Exit 0).
- **AC-2:** GIVEN die fünf Dateien `NotificationDigestChainTests`, `ReceiptAIResolutionChainTests`,
  `ReceiptKnownItemNamesTests`, `ReceiptParserSuggestionTests`, `ReceiptResolutionStatsTests`, WHEN der Diff
  gelesen wird, THEN enthält der In-Memory-Aufruf jeweils `cloudKitDatabase: .none` und der Diff je Datei
  umfasst genau eine geänderte Zeile.
- **AC-3:** GIVEN `NotificationDigestChainTests` auf iOS 27.0 im Simulator, WHEN die Klasse nach dem Fix
  läuft, THEN sind 8 von 8 Tests grün ohne „Restarting after unexpected exit", und ein RED-Protokoll
  (Host-Absturz auf dem Stand davor) liegt vor.
- **AC-4:** GIVEN die gesamte Unit-Suite (`-only-testing:RestockTests`) auf iOS 27.0, WHEN sie nach dem Fix
  läuft, THEN gibt es 0 Host-Neustarts, 0 Absturzberichte während des Laufs, die Zahl der ausgeführten Tests
  ist ≥ 600, und die einzigen roten Tests sind die aus #195 (`ReceiptTextRecognizerTests` T1, 3 Assertions).
  Offene Grenze: #195 bleibt rot.
- **AC-5:** GIVEN der Gesamtdiff gegen den Tip-Commit, WHEN die Pfade geprüft werden, THEN sind `SmartCart/`,
  `SmartCartWidgets/`, `RestockShareExtension/`, `RestockUITests/` und `Restock.xcodeproj/project.pbxproj`
  unverändert; geändert sind nur die fünf Testdateien, der Strukturtest und `CLAUDE.md`.
- **AC-6:** GIVEN der Stand nach dem Fix, WHEN ein Durchlauf im Simulator (iOS 27.0) gemacht wird, THEN
  startet die Test-Host-App, die Startseite ist sichtbar, und ein Bildschirmfoto liegt unter
  `docs/artifacts/fix-194-inmemory-container-cloudkit/`.

## Out of Scope / Open Questions

- Out of Scope: #195 (OCR auf iOS 27), Umstellung der CI auf iOS 27 / Xcode 27, Tests auf Hennings Geräten,
  Vereinheitlichung aller 17 Stellen über eine Hilfsfunktion.
- Open Questions: keine.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Fünf Stellen um `cloudKitDatabase: .none` ergänzen, Strukturtest hinzufügen | kleinster Eingriff, gleiche Form wie die zwölf Vorbilder, Strukturtest schützt künftige Stellen |
| a | Gemeinsame Hilfsfunktion `makeInMemoryContainer(schema:)`, alle 17 Stellen umstellen | einheitlicher, aber 17 Dateien und Umbau funktionierender Tests; für diesen Durchgang verworfen |
| b | Nur die abstürzende Datei ändern | vom PO abgelehnt (2026-10-21); die anderen vier sind dasselbe Risiko |
| c | iOS-26-Laufzeit lokal nachladen | umgeht das Problem nur lokal, der CI-Wechsel auf Xcode 27 steht an |

Kein Modell beteiligt (Regeln vor Modell). Keine bestehende ADR wird gekippt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testinfrastruktur in der etablierten Form der zwölf Vorbilder; keine Architekturfrage,
  keine frühere Entscheidung wird gekippt.

## Risiken

- **Anderer Absturzpfad auf iOS 27:** Die Gesamtlauf-Prüfung (AC-4) deckt weitere Host-Neustarts auf; tritt
  einer auf, wird er als eigenes Ticket aufgenommen, nicht stillschweigend mitbehoben.
- **Strukturtest zu eng oder zu weit:** erkennt nur `isStoredInMemoryOnly: true` in `RestockTests/*.swift`;
  Test 3 deckt mehrzeilige Aufrufe ab.
- **Umfang 7 Dateien:** über dem Richtwert 4–5; offengelegt, fünf Einzeiler gleicher Form, vom PO entschieden.
- **Hänger nach Testende (#21):** verlängert den Nachweislauf, ändert das Ergebnis nicht.
- **Parallele Läufe:** nur ein xcodebuild/Simulator-Lauf zur Zeit; Sperren über die Hauptsitzung.

## Changelog

- 2026-10-21: Initial spec created (Issue #194; fünf In-Memory-Container ohne CloudKit-Spiegelung plus
  Strukturtest, PO-Entscheidung 2026-10-21)
- 2026-10-21: Umgesetzt und validiert. Realer Umfang 7 Code-/Konfigurationsdateien, +81/−5 (Strukturtest 74
  statt geschätzt 35 Zeilen, nach Adversary-Befund F002 um Schreibvarianten und Selbsttest erweitert).
  Adversary 2 Runden VERIFIED (F001 LOW offengelegt, F002 behoben). Validierung auf iOS 27.0: 15 Strukturtests
  grün; Unit-Suite 616 Tests, 615 grün, 0 Host-Neustarts, Absturzberichte 24 → 24, rot nur
  `ReceiptTextRecognizerTests` T1 (#195); keine Regression gegen den Lauf vor der Validierung (4 neue grüne
  Tests aus #196). Belege: `docs/artifacts/fix-194-inmemory-container-cloudkit/validation-*.txt`.
