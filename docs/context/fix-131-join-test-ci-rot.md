# Context: fix-131-join-test-ci-rot

## Request Summary
Issue #131: `testJoinWithLegacySixCharacterCodeTriggersLookup` (RestockUITests) ist auf dem CI-Runner seit 2026-10-09 rot. Er wartet 15 s auf „Kein Store mit diesem Code gefunden.“, der Text erscheint nicht. Alle anderen 77 Tests grün.

## Befund (belegt)
- Zuletzt grün: main-Lauf 37781203061 (2026-10-08 13:01), Test dort 13,6 s gesamt. Rot: 37888378658 (main nach #129), 37890208566 (PR #130, zwei Läufe).
- Umgebung identisch in grünem und rotem Lauf: Image macos-26-arm64 20260907.0351.1, iPhone 17 Pro, iOS 26.5.
- Änderungen von grün (7873b75) bis rot (b9fbbd0) im Produkt/Test-Code: nur `Restock.xcodeproj/project.pbxproj` (+2 Zeilen) und `RestockUITests/ReceiptShareExtensionTests.swift`. `StoreShareSheet.swift` und `SharedStoreService.swift` blieben unverändert.
- Der Geschwistertest `testJoinSharedListSheetIsScrollableAndUsable` (gleicher Fehlertext, 10-stelliger Code `TESTCODE12`) war im roten Lauf grün, brauchte aber 20,0 s statt 17,7 s.
- Im Test selbst: roter Lauf ~29 s (15 s Wartefrist ausgeschöpft).

## Related Files
| File | Relevance |
|------|-----------|
| RestockUITests/RestockUITests.swift:116 | der rote Test; Wartefrist `waitForExistence(timeout: 15)` auf den Fehlertext, kein Fake, echter CloudKit-Aufruf |
| SmartCart/Views/Store/StoreShareSheet.swift:344-376 | `triggerLookup` (350 ms Entprellung, 6 oder 10 Zeichen), `lookup` setzt bei JEDEM Fehler `share.join.notfound` |
| SmartCart/Services/SharedStoreService.swift:180 | `fetchPreview` → `database.record(for:)` (öffentliche CloudKit-DB); Fehlertext erscheint erst, wenn der Aufruf zurückkehrt |
| SmartCart/Resources/de.lproj/Localizable.strings:315 | Text „Kein Store mit diesem Code gefunden.“ |
| RestockUITests/UITestWait.swift | vorhandene Warte-Hilfen (#111), Standardfrist 20 s |

## Folgerung (noch Hypothese)
Der Text fehlt nur, wenn `database.record(for:)` länger als ca. 15 s nicht zurückkehrt (Netzwerk/CloudKit-Antwortzeit des Runners ohne iCloud-Konto). Produktcode und Umgebung sind unverändert, daher spricht alles für zeitliche Streuung der CloudKit-Antwort. Nicht reproduziert, nicht belegt.

## Recherche (2026-10-09)
- Apple-Forum: öffentliche DB ist ohne Anmeldung lesbar, Speichern braucht Konto; Simulator-Fälle mit `notAuthenticated` trotz Anmeldung (developer.apple.com/forums/thread/698720, /thread/816523).
- Keine Fallberichte zu einer Verlangsamung von `record(for:)` im Simulator auf CI gefunden. Ein Beleg für die Hypothese fehlt also weiter.
- GitHub: Xcode-27-Image läuft seit 2026-09-10 auf macOS 27; unser Lauf nutzt weiter macos-26 (github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27).

## Lokaler Nachstellversuch (Restock-Validate, iOS aktuell)
`-only-testing` auf den Test: scheitert nach 13 s schon früher mit „Code-Eingabefeld im JoinStoreSheet nicht sichtbar“. Anderer Fehler als auf CI, daher KEINE Reproduktion des CI-Fehlers. Ursache des lokalen Fehlers offen (Sim-Zustand, Placeholder, Sprache?).

## Dependencies
- Upstream: CloudKit öffentliche DB, Simulator ohne iCloud-Konto.
- Downstream: nur dieser Test und `testJoinSharedListSheetIsScrollableAndUsable`.

## Risks & Considerations
- Nur Frist verlängern wäre Raten ohne Messung.
- Alternative: Fehlerpfad der Suche per DEBUG-Startargument deterministisch erzeugen (Fake statt Netzwerk); würde die Entscheidung kippen, dass der Test den echten CloudKit-Pfad durchläuft.
- Läuft gerade ein CI-Lauf auf main (37899047790): Ergebnis zeigt, ob der Fehler stabil oder zeitlich streut.
- Scoping: erwartet 1–2 Dateien.

## Analysis

### Type
Bug (CI-Test rot, Produktcode korrekt)

### Root Cause (belegt, 2026-10-09) — die Zeitüberschreitungs-Hypothese oben ist widerlegt
Der Test tippt den **echten, von einem Nutzer gemeldeten Code `CGU5ZN`** und erwartet „Kein Store mit diesem Code gefunden.“, weil es diesen Eintrag in der öffentlichen CloudKit-Datenbank nicht gab. **Jetzt existiert er:** Die UI-Hierarchie im Fehlmoment (xcresult Run 37888378658, Anhang „App UI hierarchy“, 08:06:45) zeigt im Beitreten-Sheet `TextField value: CGU5ZN`, darunter `🛒`, `Lidl`, `Von Henning` und den Button `🛒 Lidl hinzufügen`. Die Suche war erfolgreich und lieferte eine Vorschau statt eines Fehlers; der Fehlertext erscheint deshalb nie. Das 15-s-Fenster wird zu Recht ausgeschöpft (Testdauer 29,8 s = Setup + volle Wartefrist).
- Das Sheet war gesund, die Suche kehrte zurück: kein Netzwerk- und kein Zeitproblem.
- Zeitlich: zuletzt grün 2026-10-08 13:01, rot ab 2026-10-09 05:23. Dazwischen hat Henning auf dem iPhone die Sync-Fixes (#121, Build 10/11) mit seinem Laden „Lidl“ geprüft. Wann genau der Eintrag `CGU5ZN` entstand, ist NICHT belegt (Annahme: durch diese Geräteläufe); für den Fix unerheblich.
- Geschwistertest (`TESTCODE12`, 10 Zeichen) bleibt grün: dieser Code existiert nicht.
- Die Testannahme „ohne iCloud-Konto schlägt die Suche fehl“ (Kommentar RestockUITests.swift:129–132) stimmt nicht: Die öffentliche DB ist ohne Konto lesbar.

### Reproduktion
Der Fehlerzustand ist am echten CI-Lauf belegt (Hierarchie plus Dauer). Lokal im Simulator noch nicht nachgestellt: der lokale Versuch scheiterte früher (Code-Eingabefeld nicht sichtbar, anderer Fehler). In `/40-tdd-red` zuerst den lokalen Aufbau klären, dann `CGU5ZN` lokal laufen lassen (Erwartung: Vorschau „Lidl“ statt Fehlertext).

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| RestockUITests/RestockUITests.swift | MODIFY | `CGU5ZN` durch einen je Lauf zufällig erzeugten 6-stelligen Code ersetzen; Kommentar zur Annahme korrigieren |

### Scope Assessment
- Files: 1
- Estimated LoC: +8/-4
- Risk Level: LOW (nur Testcode, kein Produktcode)

### Technical Approach (Empfehlung)
Regelweg, kein Modell: Der Test erzeugt je Lauf einen zufälligen 6-stelligen Code aus Großbuchstaben (Kollision mit einem echten Code ≈ 1 : 10⁹). Alles andere bleibt: echter Codepfad, echte Suche, gleicher Erwartungstext. Der Test hängt nicht mehr an Livedaten, die sich ändern können.

### Alternativen
1. **Fake statt Netzwerk** (DEBUG-Startargument, `SharedStoreDatabase`-Fake aus #121): deterministisch, kippt aber die Entscheidung, dass dieser Test den echten CloudKit-Pfad durchläuft; berührt Produktcode, mehr Dateien.
2. **Beide Ausgänge akzeptieren** (Fehlertext ODER Vorschau): trivial, aber so schwach, dass der Test bei jedem Datenbestand grün wäre.
3. **Nur Frist verlängern**: wirkungslos, widerlegt.

### Dependencies
Echte öffentliche CloudKit-DB (Netz des Runners). Restrisiko wie bisher: lange Antwortzeiten des Runners (#111-Thema), nicht Ursache dieses Fehlers.

### Open Questions
- [ ] `testJoinSharedListSheetIsScrollableAndUsable` (`TESTCODE12`) gleich mitumstellen? Empfehlung: ja, gleiche Datei, gleiche Fehlerklasse, minimaler Mehraufwand.
