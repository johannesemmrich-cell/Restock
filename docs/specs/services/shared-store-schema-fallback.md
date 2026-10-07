---
entity_id: shared-store-schema-fallback
type: bugfix
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: fix-121-sync-geteilter-laden
tags: [sync, cloudkit, shared-store, schema, production, testflight, diagnose, issue-121]
---

# Geteilte Läden: Fallback bei unvollständigem Produktions-Schema und sichtbare Diagnose (Issue #121)

## Approval

- [ ] Approved — PO (offen)

## Purpose

PO-Meldung 2026-10-07: Die Synchronisierung geteilter Läden „kommt gar nicht an“, beide Geräte laufen über
TestFlight, im Laden steht „Sync fehlgeschlagen — Änderungen werden möglicherweise nicht mit anderen
geteilt“ (= `SyncFailureKind.other`), und „bisher hat es perfekt funktioniert“ (Analyse in
`docs/context/fix-121-sync-geteilter-laden.md`, Abschnitte „Befund 1–4“, „Hypothesen“, „Analysis“).

**Hauptverdacht (Root Cause, belegt durch Zeitverlauf und Code, Produktions-Schema selbst noch nicht
eingesehen):** `SharedStoreService.mergeIntoRecord` schreibt bei **jedem** Speichern die zwei Felder
`categoriesJSON` und `assignmentsJSON` (`SharedStoreService.swift:127-128`). Beide kamen am 2026-10-02 neu
hinzu (Commits 3bc0abf, 6c4a032) und sind erstmals in Build 9 (2026-10-05) auf Geräten. TestFlight nutzt die
CloudKit-**Produktionsumgebung**; dort legt CloudKit unbekannte Felder nicht an und lehnt das Speichern ab
(„Cannot create or modify field 'categoriesJSON' in record 'SharedStore' in production schema“, Quellen in
der Analyse). `syncToCloud` meldet das als `.other`. Ein Pull funktioniert weiter (fehlende Felder gelten als
Vorgabewert, `:92, 97, 183-184`). Der Push scheitert auf beiden Geräten, also kommt nichts an.

Der eigentliche Fix des Zustands ist eine **Konfiguration des Kontoinhabers** (Schema im CloudKit-Dashboard
veröffentlichen, nicht Teil des Codes). Dieser Durchgang härtet den Code, damit das Problem (1) den Kern der
Synchronisierung nicht mehr lahmlegt, (2) sichtbar und diagnostizierbar wird und (3) beim nächsten neuen Feld
vor dem TestFlight-Upload auffällt:

1. Ein kleines Protokoll vor der Datenbank, damit ein Fake die Produktion nachstellt.
2. Fallback in `syncToCloud`: bei Ablehnung wegen Produktions-Schema genau einmal ohne die optionalen
   Erweiterungsfelder erneut speichern. Artikel, Preise und Mitglieder gleichen wieder ab.
3. Sichtbarer Zustand „Schema unvollständig“ und Fehlerdetails (Zustand, `os.Logger`, Entwicklermodus).
4. Drift-Test der Feldliste und Schritt in `docs/testflight-setup.md`.

**Offene Grenze (gilt für jede Zusage dieser Spec):** Echtes Speichern gegen die CloudKit-Produktion ist nicht
automatisiert prüfbar; der Fake ist die Ersatzprüfung. Ob das Produktions-Schema wirklich die Ursache ist,
bestätigt erst der Blick ins Dashboard bzw. der Fehlertext im Entwicklermodus auf einem neuen TestFlight-Stand
auf dem Gerät des PO. Bis das Schema veröffentlicht ist, werden **Kategorien und gemerkte Zuordnungen nicht
geteilt**; das Fallback stellt nur den Kern (Artikel, Preise, Mitglieder) wieder her.

## Source

Zeilennummern Stand 2026-10-07; maßgeblich sind die Funktionen.

- **Geändert:** `SmartCart/Services/SharedStoreService.swift`
  - Datenbankzugriff (`db`, Zeile 9; Aufrufe `db.record(for:)` Zeile 55, 152, 167, 199 und `db.save(…)`
    Zeile 66, 208, 231) läuft über ein kleines Protokoll (z. B. `SharedStoreDatabase` mit `record(for:)` und
    `save(_ record:)`); `CKDatabase` erfüllt es per Erweiterung, `publicCloudDatabase` bleibt die
    Produktivinstanz. Für Tests ist die Datenbank injizierbar (Form legt Phase 5 fest). Keine
    Verhaltensänderung für Aufrufer: Signaturen von `publish`, `push`, `pull`, `fetchPreview`,
    `addSelfAsMember`, `subscribe` bleiben.
  - `syncToCloud` (Zeile 48-79): erkennt eine Ablehnung wegen Produktions-Schema und speichert genau einmal
    erneut ohne `categoriesJSON` und `assignmentsJSON`. Die Feldlisten (Kernfelder, Erweiterungsfelder)
    stehen als Konstanten an einer Stelle.
  - `mergeIntoRecord` (Zeile 83-130) bleibt das Merge-Verhalten; das Weglassen der Erweiterungsfelder
    geschieht beim Speichern, nicht im Merge.
- **Geändert:** `SmartCart/Services/SyncCoordinator.swift`
  - `SyncFailureKind` (Zeile 35) um `schemaIncomplete`; `lastFailureKind` (Zeile 45) wird bei Erfolg von
    `pull`/`push` zurückgesetzt; neues `lastFailureDetail` (Domain, Code, `ServerErrorDescription` bzw.
    `localizedDescription`); `os.Logger` (Subsystem Bundle-ID, Kategorie `sync`) in den `catch`-Zweigen von
    `pull` (Zeile 73) und `push` (Zeile 93). `classify` (Zeile 47) erkennt „production schema“ regelbasiert.
- **Geändert:** `SmartCart/Views/Store/StoreDetailView.swift` — `syncFailureText` (Zeile 1074-1083) um den
  Fall `schemaIncomplete`; Banner (Zeile 275-298) zeigt ihn auch dann, wenn das Speichern über das Fallback
  gelang (`pull`/`push` also `true` lieferte); im Entwicklermodus (`@AppStorage("developerMode")`, Zeile 36)
  zusätzlich eine Detailzeile. Aufbau des Banners (Button, Symbol, Text, Aktualisieren-Symbol, orange)
  unverändert.
- **Neu:** `RestockTests/SharedStoreSchemaTests.swift` — Fake-Produktion, RED-Test, Fallback-Tests,
  Drift-Test. Registrierung in `Restock.xcodeproj/project.pbxproj` an allen vier Stellen (PBXBuildFile,
  PBXFileReference, PBXGroup, PBXSourcesBuildPhase).
- **Geändert:** `docs/testflight-setup.md` — neuer Abschnitt „CloudKit-Schema veröffentlichen, wenn sich die
  Felder von `SharedStore` ändern“.
- **Nicht geändert:** Merge-Logik (`merge`, `StoreCategories`, `LearnedPriceSync`), `StoreShareSheet.swift`,
  `AppDelegate.swift`, `SmartCartApp.swift`, `Info.plist`, Entitlements, UI-Tests.
- **Keine** neuen Dependencies, **kein** `Info.plist`-Eintrag, **kein** neuer `@AppStorage`-Schlüssel (der
  vorhandene `developerMode` wird nur gelesen), keine Audio-Dateien.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CloudKit` (`CKDatabase`, `CKError`, `CKRecord`) | framework | Produktivpfad und Fehlerklassifizierung |
| `os.Logger` | framework | Fehler von `pull`/`push` ohne Personendaten protokollieren |
| `SharedStoreService.mergeIntoRecord` | code | erzeugt den Record, dessen `allKeys()` der Drift-Test prüft |
| `RestockTests/SharedStoreMergeTests.swift` | test | Muster: CloudKit-freie Tests, eindeutige `shareID`, Aufräumen der `lastSync_UT-*`-Schlüssel |
| `docs/context/fix-121-sync-geteilter-laden.md` | doc | verbindliche Analyse |
| `docs/testflight-setup.md` | doc | Upload-Anleitung, bekommt den Schema-Schritt |
| `docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md` | spec | Vorgänger, offene Grenze „echtes Teilen / Server“ |
| Simulator `Restock-Validate` | tool | lokale Läufe; nie parallel (Memory „Eigenes Testgerät je Projekt“) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/SharedStoreService.swift` | MODIFY | Datenbank hinter kleinem Protokoll; Fallback ohne `categoriesJSON`/`assignmentsJSON` bei Ablehnung wegen Produktions-Schema; Feldlisten als Konstanten |
| `SmartCart/Services/SyncCoordinator.swift` | MODIFY | `schemaIncomplete`, `lastFailureDetail`, `Logger`, Zurücksetzen bei Erfolg |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | Hinweistext „Server-Einrichtung unvollständig …“, Detailzeile im Entwicklermodus |
| `RestockTests/SharedStoreSchemaTests.swift` | CREATE | Fake-Produktion, RED-Test, Fallback-Tests, Drift-Test |
| `docs/testflight-setup.md` | MODIFY | Schritt „CloudKit-Schema veröffentlichen“ |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Testdatei an vier Stellen registrieren |

### Estimated Changes

- Files: 5 plus `project.pbxproj` (Limit 4–5, ausgereizt)
- LoC: ca. +180 / −20 (Limit ±250). Das LoC-Gate zählt Testcode als Produktivcode (Memory „LoC-Gate zählt
  Testcode als Produktivcode“); Umfang vor dem Abschluss mit `git diff --stat` gegen den Tip-Commit prüfen,
  bei Überschreitung zuerst Rückmeldung mit Schätzung. Funktionen ≤ 50 LoC (`syncToCloud` wächst; ggf. die
  Schema-Erkennung und das Entfernen der Felder in kleine Hilfsfunktionen auslagern).
- Risiko: HOCH (kritischer Pfad, geteilte Daten) → Adversary 2 Runden.
- Seiteneffekte: Beim Fallback gehen Kategorien/Zuordnungen **nicht** verloren (lokal bleiben sie, im
  Server-Record bleiben ältere Werte), sie werden nur nicht hochgeladen und im Banner genannt.

## Definition of Done

- [ ] RED-Test T1 (Fake-Produktion lehnt neue Felder ab, Push schlägt mit aktuellem Code fehl) belegt und
  danach grün (AC-1, AC-2)
- [ ] Fallback speichert einmal ohne Erweiterungsfelder, Kernfelder bleiben (AC-3, AC-4, AC-5)
- [ ] Andere Fehler lösen kein Fallback aus (AC-6)
- [ ] Wasserstand `lastSync` nur nach erfolgreichem Speichern (AC-7)
- [ ] Vollständiges Produktions-Schema: unveränderter Pfad, Erweiterungsfelder werden geschrieben (AC-8)
- [ ] Zustand `schemaIncomplete` gesetzt und zurückgesetzt, `lastFailureKind` bleibt nach Erfolg nicht
  stehen (AC-9, AC-10)
- [ ] Banner-Text und Banner bei gelungenem Fallback (AC-11, AC-12)
- [ ] Diagnose: `lastFailureDetail`, `os.Logger`, Detailzeile im Entwicklermodus, keine Personendaten
  (AC-13, AC-14, AC-15)
- [ ] Drift-Test mit Hinweistext (AC-16)
- [ ] `docs/testflight-setup.md` ergänzt (AC-17)
- [ ] Protokoll vor der Datenbank ohne Verhaltensänderung für Aufrufer, Produktivcode nutzt
  `publicCloudDatabase` (AC-18)
- [ ] Unit-Suite grün, Testzahl > 0 (AC-19)
- [ ] Ganze UI-Suite lokal grün (AC-20)
- [ ] Release-Build kompiliert (AC-21)
- [ ] Durchlauf der App im Simulator, Fehlerfall ggf. offen benannt (AC-22)
- [ ] Nachweis nach Auslieferung nur über neuen TestFlight-Stand beim PO, offen benannt (AC-23)
- [ ] Offene Grenzen und Konfigurationsvoraussetzung in Ticket und Bericht (AC-24)
- [ ] Diff gegen Tip-Commit: genau die genannten Dateien, keine neuen Dependencies, `Info.plist`- oder
  `@AppStorage`-Änderung (AC-25)

## Implementation Details

**Protokoll vor der Datenbank (`SharedStoreService`).** Skizze (Form legt Phase 5 fest, Verhalten ist
verbindlich):

```swift
protocol SharedStoreDatabase {
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
    func save(_ record: CKRecord) async throws -> CKRecord
}
extension CKDatabase: SharedStoreDatabase {}
```

`CKDatabase` hat beide Methoden bereits; die Erweiterung ist leer bzw. nur ein Adapter. `subscribe`/
`unsubscribe` (Subscriptions) dürfen auf `CKDatabase` bleiben, solange der Fake nur `record(for:)`/`save`
braucht. Produktivinstanz bleibt `container.publicCloudDatabase`.

**Fake „Produktion“ (Test).** Hält eine feste Menge erlaubter Feldnamen (das Produktions-Schema ohne
`categoriesJSON`/`assignmentsJSON`). `save` wirft bei einem Record mit anderem Feld einen `CKError` mit Code
`serverRejectedRequest` und `ServerErrorDescription` „Cannot create or modify field 'categoriesJSON' in
record 'SharedStore' in production schema“; sonst speichert er (eigene `modificationDate`) und gibt den
Record zurück. Zählt Speicherversuche, damit „genau einmal erneut“ prüfbar ist. Zweite Variante mit vollem
Schema für AC-8; weitere Varianten werfen Netz-, Berechtigungs- und Anmeldefehler.

**Erkennung (regelbasiert, kein Modell).** Eine Ablehnung gilt als „Produktions-Schema“, wenn der Fehlertext
(`ServerErrorDescription` aus `userInfo`, sonst `localizedDescription`) „production schema“ enthält,
Groß-/Kleinschreibung ignoriert. Bei `partialFailure` zählen die Teilfehler. Kein Abgleich nach Feldnamen,
keine Modelle.

**Fallback in `syncToCloud`.** Wird das erste `save` wegen Produktions-Schema abgelehnt, entfernt der Dienst
`categoriesJSON` und `assignmentsJSON` aus dem Record (`record[field] = nil`) und speichert **genau einmal**
erneut. Kernfelder `storeName`, `storeEmoji`, `storeColorHex`, `ownerDevice`, `itemsJSON`, `membersJSON`,
`deletedJSON`, `pricesJSON` bleiben. Gelingt das, gilt wie bisher: `markSynced` mit der Server-
`modificationDate`, `pruneDeletions`, Rückgabe des Merge-Ergebnisses (Kategorien/Zuordnungen lokal bleiben
unverändert erhalten und werden vom Aufrufer wie bisher angewandt). Scheitert auch der zweite Versuch,
wird dessen Fehler geworfen (kein weiterer Versuch, keine Endlosschleife). Der bestehende Wiederholversuch bei
`serverRecordChanged` (`attempt == 0`) bleibt eigenständig; Fallback und `serverRecordChanged` dürfen sich
nicht gegenseitig endlos auslösen (jeweils höchstens ein Zusatzversuch). `syncToCloud` meldet dem Aufrufer,
dass das Fallback gegriffen hat (z. B. Rückgabewert oder Flag; Form legt Phase 5 fest).

**Zustand und Diagnose (`SyncCoordinator`).** Greift das Fallback, setzt `push` `lastFailureKind =
.schemaIncomplete` und liefert dennoch `true` (der Kern wurde abgeglichen). Nach einem vollständigen Speichern
(ohne Fallback) wird der Zustand zurückgesetzt, ebenso `lastFailureKind` bei jedem erfolgreichen `pull`/
`push` (heute bleibt der alte Wert stehen). `lastFailureDetail` hält eine Zeile mit Domain, Code und
`ServerErrorDescription`/`localizedDescription`; beim Fallback enthält sie die Ablehnungsursache. Der
`os.Logger` (Subsystem = Bundle-ID, Kategorie `sync`) protokolliert Fehler von `pull`/`push` mit Domain, Code
und Fehlertext. **Keine Personendaten:** kein Ladenname, keine Artikel, kein Anzeigename, kein Code der
Freigabe (`shareID`) im Klartext (Datenschutzstufe `.private` bzw. weglassen). Fehlertext des Servers wird
nur als `.public` protokolliert, wenn er keine Nutzdaten enthalten kann; im Zweifel `.private`.

**Banner (`StoreDetailView`).** Bei `schemaIncomplete` lautet der Text (als `String(localized:)` bzw. im
Stil der vorhandenen Texte): „Server-Einrichtung unvollständig — Kategorien und gemerkte Zuordnungen werden
noch nicht geteilt; Artikel gleichen ab“. Da das Fallback als Erfolg zählt (`syncFailed == false`), zeigt der
Banner diesen Zustand zusätzlich zu `syncFailed`. Im Entwicklermodus folgt eine zweite Zeile mit
`lastFailureDetail`. Bei den bisherigen Fehlerarten bleiben die Texte wörtlich unverändert.

**Drift-Test (`SharedStoreSchemaTests`).** Erzeugt über `mergeIntoRecord` einen Record eines Test-Ladens und
vergleicht `Set(record.allKeys())` mit der im Test festgeschriebenen Liste (`storeName`, `storeEmoji`,
`storeColorHex`, `ownerDevice`, `itemsJSON`, `membersJSON`, `deletedJSON`, `pricesJSON`, `categoriesJSON`,
`assignmentsJSON`; `ownerDevice` nur bei `isNewRecord: true`, daher mit neuem Record erzeugen). Weicht die
Menge ab, schlägt der Test fehl mit der Meldung: „Felder von SharedStore geändert: CloudKit-Schema vor dem
TestFlight-Upload veröffentlichen (docs/testflight-setup.md)“.

**Dokumentation (`docs/testflight-setup.md`).** Neuer Abschnitt „CloudKit-Schema veröffentlichen, wenn sich
die Felder von `SharedStore` ändern“: CloudKit-Dashboard → Container `iCloud.com.johannesemmrich.SmartCart`
→ Development → Record-Typ `SharedStore` prüfen, ob alle Felder (insbesondere neue) dort stehen → „Deploy
Schema Changes…“ nach Production. TestFlight und App Store nutzen die Produktion, Xcode-Läufe die
Entwicklung. Verweis auf den Drift-Test.

**Reihenfolge (TDD).** (1) Test-Datei mit Fake und RED-Test T1 anlegen und registrieren, mit aktuellem Code
rot belegen; (2) Protokoll einführen, Fallback und Zustand umsetzen; (3) Drift-Test, Dokumentation, Banner;
(4) Suiten und Durchlauf. Nach dem GREEN-Zwischenstand sofort committen (Memory „Committen vor weiteren
Agenten“).

**Durchlauf (Pflicht, „Die App wird benutzt, nicht nur gebaut“).** Die App wird im Simulator
`Restock-Validate` ohne Zusatz-Build-Settings (Memory „CODE_SIGNING_ALLOWED=NO bricht die App-Gruppe“)
gestartet und der geänderte Ablauf als Nutzer durchgespielt: geteilter Laden öffnen, Banner-Zustand
beobachten, soweit mit `-skipCloudKitForScreenshots` oder einem anderen DEBUG-Weg erzeugbar. Der
Fehlerfall gegen echtes CloudKit ist im Simulator nicht erzeugbar und wird als offen benannt, falls kein
Weg gefunden wird (Fehlerfall dann nur über den Fake, T1–T7). Der Durchlauf wird als Artefakt registriert
(echter Lauf, Commit-Kennung und Zeitstempel passend, nie von Hand gesetzt).

**Testbare reine Funktionen (T13, T14).** Die Banner-Entscheidung (sichtbar ja/nein, Haupttext, Detailzeile je
nach `syncFailed`, `lastFailureKind`, `developerMode`, `lastFailureDetail`) und die Log-Meldung (Domain, Code,
Fehlertext, ohne Personendaten) werden als kleine reine Funktionen geführt, die `StoreDetailView` bzw.
`SyncCoordinator` nur aufrufen. Dadurch sind AC-11, AC-12, AC-14 und AC-15 ohne UI-Test und ohne CloudKit
prüfbar; ein künstliches Erzeugen des Fehlerzustands per Launch-Argument entfällt.

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED): GIVEN Fake-Produktion ohne `categoriesJSON`/`assignmentsJSON` und der Code vor dem Fallback,
  WHEN `syncToCloud` (Push) für einen geteilten Laden läuft, THEN schlägt er mit „production schema“ fehl.
  Nach der Umsetzung grün.
- [ ] T2: GIVEN derselbe Fake, WHEN Push mit dem Fallback läuft, THEN gelingt er, der gespeicherte Record
  enthält alle Kernfelder und weder `categoriesJSON` noch `assignmentsJSON`, und es gab genau zwei
  Speicherversuche.
- [ ] T3: GIVEN Fake mit Netz-, Berechtigungs- (`permissionFailure`) bzw. Anmeldefehler (`notAuthenticated`),
  WHEN Push läuft, THEN genau ein Speicherversuch und der Fehler wird geworfen (kein Fallback).
- [ ] T4: GIVEN Fake, bei dem auch der zweite Versuch scheitert, WHEN Push läuft, THEN genau zwei Versuche,
  Fehler wird geworfen, `lastSync` unverändert.
- [ ] T5: GIVEN Fake mit vollem Schema, WHEN Push läuft, THEN ein Versuch, Record enthält beide
  Erweiterungsfelder.
- [ ] T6: GIVEN Fehlertexte mit „Production Schema“ in anderer Schreibweise, mit „production schema“ im
  `localizedDescription` statt `ServerErrorDescription` und ein anderer Text (z. B. „Network unavailable“),
  WHEN die Erkennung läuft, THEN erkennt sie die ersten beiden und nicht den dritten.
- [ ] T7: GIVEN `SyncCoordinator` mit Fallback-Push, WHEN er abgeschlossen ist, THEN
  `lastFailureKind == .schemaIncomplete` und `lastFailureDetail` nicht leer; nach vollständigem Push ist der
  Zustand zurückgesetzt; nach einem erfolgreichen Pull steht kein alter Fehler mehr.
- [ ] T8: GIVEN der Drift-Test, WHEN die Feldliste von `mergeIntoRecord` mit der festgeschriebenen
  übereinstimmt, THEN grün; bei Abweichung (Gegenprobe im Entwurf, nicht eingecheckt) Meldung wörtlich wie
  in AC-16.
- [ ] T9: GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN grün, Testzahl > 0 (Memory „Null-Test-Lauf
  ist kein Grün“), bestehende `SharedStoreMergeTests` unverändert grün.
- [ ] T10: GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN
  grün ohne Abbruch und Retry-Flag.
- [ ] T11: GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt er.
- [ ] T12: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat` läuft, THEN 5 Dateien plus
  `project.pbxproj`, ca. +180/−20 LoC.
- [ ] T13 (AC-11, AC-12, AC-15): GIVEN die Banner-Entscheidung als reine Funktion
  (Eingaben `syncFailed`, `lastFailureKind`, `developerMode`, `lastFailureDetail`; Ausgabe: sichtbar ja/nein,
  Haupttext, optionale Detailzeile), WHEN sie für die Fälle (a) `schemaIncomplete` mit `syncFailed == false`,
  (b) `.other` mit `syncFailed == true`, (c) kein Fehler und (d) `schemaIncomplete` mit `developerMode == true`
  aufgerufen wird, THEN ist der Banner in (a), (b), (d) sichtbar und in (c) nicht, (a) trägt den Text
  „Server-Einrichtung unvollständig …“ ohne Detailzeile, (d) trägt zusätzlich die Detailzeile, (b) den bisherigen
  Text.
- [ ] T14 (AC-14): GIVEN die Log-Meldung als reine Funktion (Eingabe Fehler, Ausgabe Text), WHEN sie für
  einen `CKError` mit Domain, Code und `ServerErrorDescription` gebildet wird, THEN enthält sie Domain, Code
  und Fehlertext, und weder Ladenname, Artikelname, Anzeigename noch Freigabecode aus dem Eingabekontext.
- [ ] T15 (AC-18): GIVEN die Standard-Datenbank von `SharedStoreService`, WHEN ihr Scope gelesen wird, THEN ist
  sie die öffentliche Datenbank (`databaseScope == .public`), und `CKDatabase` erfüllt das Datenbank-Protokoll
  (Übersetzbarkeit). Die bestehenden `SharedStoreMergeTests` bleiben unverändert grün (T9).
- Zuordnung der übrigen ACs, die in den Tests oben nicht namentlich stehen: AC-3 und AC-4 in T2, AC-5 und
  AC-7 in T4, AC-6 in T3, AC-13 in T7.

Nicht durch Unit-Tests abgedeckt: AC-17 (Doku-Eintrag, Prüfung durch Sichtkontrolle des Diffs in T12), AC-22
(Pflicht-Durchlauf der App im Simulator, als Artefakt registriert, kein Unit-Test) und AC-24 (Berichtstexte,
Prüfung im Abschlussbericht).

Nicht automatisierbar (offene Grenze): echtes Speichern gegen die CloudKit-Produktion und die Anzeige auf
dem Gerät des PO (AC-23).

## Acceptance Criteria

- **AC-1:** GIVEN eine Fake-Datenbank, die wie die Produktion Records mit den Feldern `categoriesJSON` oder
  `assignmentsJSON` mit `serverRejectedRequest` und „Cannot create or modify field 'categoriesJSON' in
  record 'SharedStore' in production schema“ ablehnt, WHEN ein geteilter Laden vor der Umsetzung (aktueller
  Code, Protokoll nur im Test eingehängt) gepusht wird, THEN schlägt der Push fehl (RED, Ist-Zustand der
  PO-Meldung belegt).
- **AC-2:** GIVEN derselbe Test nach der Umsetzung, WHEN er läuft, THEN ist er grün (Schalter Fehler da →
  Fix → Fehler weg).
- **AC-3:** GIVEN die Ablehnung wegen Produktions-Schema, WHEN `syncToCloud` sie erkennt, THEN speichert es
  genau einmal erneut ohne `categoriesJSON` und `assignmentsJSON`; insgesamt zwei Speicherversuche.
- **AC-4:** GIVEN das Fallback, WHEN es greift, THEN bleiben `storeName`, `storeEmoji`, `storeColorHex`,
  `ownerDevice` (bei neuem Record), `itemsJSON`, `membersJSON`, `deletedJSON` und `pricesJSON` im
  gespeicherten Record, und Artikel, Preise und Mitglieder gleichen wieder ab (Pull durch ein zweites Gerät
  liefert sie).
- **AC-5:** GIVEN das Fallback scheitert ebenfalls, WHEN der zweite Versuch fehlschlägt, THEN wird dessen
  Fehler geworfen, es gibt keinen dritten Versuch, und der bestehende Wiederholversuch bei
  `serverRecordChanged` bleibt auf höchstens einen Zusatzversuch begrenzt.
- **AC-6:** GIVEN ein Fehler, dessen Text nicht „production schema“ enthält (Netz, `permissionFailure`,
  `notAuthenticated`, sonstige), WHEN Push läuft, THEN gibt es kein Fallback (genau ein Speicherversuch) und
  `SyncFailureKind` wird wie bisher klassifiziert (`permissionDenied`, `notAuthenticated`, `other`).
- **AC-7:** GIVEN ein Push mit oder ohne Fallback, WHEN das Speichern fehlschlägt, THEN bleibt `lastSync`
  unverändert; nur nach erfolgreichem Speichern wird es auf die Server-`modificationDate` gesetzt.
- **AC-8:** GIVEN eine Fake-Datenbank mit vollem Schema, WHEN Push läuft, THEN gibt es genau einen
  Speicherversuch, der Record enthält `categoriesJSON` und `assignmentsJSON`, und der Zustand
  `schemaIncomplete` wird nicht gesetzt.
- **AC-9:** GIVEN das Fallback greift, WHEN `SyncCoordinator.push` endet, THEN ist `lastFailureKind ==
  .schemaIncomplete`, der Aufruf liefert `true` (Kern abgeglichen), und `lastFailureDetail` benennt die
  Ablehnungsursache.
- **AC-10:** GIVEN der Zustand `schemaIncomplete` oder ein früherer Fehler, WHEN danach ein `pull` oder
  vollständiger `push` erfolgreich endet, THEN ist der Zustand bzw. `lastFailureKind` zurückgesetzt und
  bleibt nicht stehen.
- **AC-11:** GIVEN `lastFailureKind == .schemaIncomplete`, WHEN der Banner in `StoreDetailView` erscheint,
  THEN lautet der Text „Server-Einrichtung unvollständig — Kategorien und gemerkte Zuordnungen werden noch
  nicht geteilt; Artikel gleichen ab“; die Texte der übrigen Fehlerarten sind wörtlich unverändert.
- **AC-12:** GIVEN das Fallback hat den Kern abgeglichen (`pull`/`push` lieferte `true`), WHEN der Laden
  geöffnet ist, THEN zeigt der Banner den Zustand „Schema unvollständig“ trotzdem; der Banner-Aufbau (Button
  mit Warnsymbol, Text, Aktualisieren-Symbol, orange Hinterlegung, Tippen löst Pull aus) ist unverändert.
- **AC-13:** GIVEN ein Fehler bei `pull` oder `push`, WHEN er im `catch` landet, THEN hält
  `SyncCoordinator.lastFailureDetail` Domain, Code und `ServerErrorDescription` bzw. `localizedDescription`.
- **AC-14:** GIVEN ein Fehler bei `pull` oder `push`, WHEN er auftritt, THEN schreibt ein `os.Logger`
  (Subsystem Bundle-ID, Kategorie `sync`) Domain, Code und Fehlertext; Ladenname, Artikel, Anzeigename und
  Freigabecode stehen nicht im Klartext im Log; es gibt kein `print` und kein stilles Verschlucken in diesen
  Zweigen.
- **AC-15:** GIVEN `developerMode == true` und ein Syncfehler oder `schemaIncomplete`, WHEN der Banner
  erscheint, THEN zeigt er zusätzlich die Detailzeile (`lastFailureDetail`); mit `developerMode == false`
  fehlt sie.
- **AC-16:** GIVEN `RestockTests/SharedStoreSchemaTests.swift`, WHEN die Feldmenge eines über
  `mergeIntoRecord` erzeugten Records von der im Test festgeschriebenen Liste abweicht, THEN schlägt der Test
  fehl mit der Meldung „Felder von SharedStore geändert: CloudKit-Schema vor dem TestFlight-Upload
  veröffentlichen (docs/testflight-setup.md)“; bei Übereinstimmung ist er grün. Die Datei ist in
  `project.pbxproj` an allen vier Stellen registriert.
- **AC-17:** GIVEN `docs/testflight-setup.md`, WHEN man den Abschnitt „CloudKit-Schema veröffentlichen, wenn
  sich die Felder von `SharedStore` ändern“ liest, THEN enthält er den Weg Dashboard → Container
  `iCloud.com.johannesemmrich.SmartCart` → Development → „Deploy Schema Changes…“, den Hinweis, vorher zu
  prüfen, dass die Felder in Development stehen, und dass TestFlight die Produktion nutzt.
- **AC-18:** GIVEN der Produktivcode, WHEN `SharedStoreService` seine Datenbank anspricht, THEN läuft es über
  das neue Protokoll mit `CKContainer.publicCloudDatabase` als Instanz; Signaturen und Verhalten von
  `publish`, `push`, `pull`, `fetchPreview`, `addSelfAsMember`, `subscribe` sind für Aufrufer unverändert,
  und die bestehenden `SharedStoreMergeTests` bleiben unverändert grün.
- **AC-19:** GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN sind alle Tests grün, die Testzahl ist
  > 0, es gab keinen Abbruch.
- **AC-20:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft,
  THEN sind alle Tests grün, die Testzahl ist > 0, ohne Abbruch und Retry-Flag. (Bei Flakes #111 bleibt eine
  Ausnahme dem PO vorbehalten und wird nicht vorab angenommen.)
- **AC-21:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt
  der Build ohne Fehler.
- **AC-22:** GIVEN die App im Simulator mit dem Stand dieses Durchgangs, WHEN ein geteilter Laden (soweit mit
  `-skipCloudKitForScreenshots` bzw. DEBUG-Mitteln erzeugbar) als Nutzer durchgespielt wird, THEN verhält
  sich die Ansicht wie beschrieben (Banner-Text/-Aufbau); der Durchlauf ist als Artefakt registriert. Ist der
  CloudKit-Fehlerfall im Simulator nicht erzeugbar, wird das ausdrücklich als offen benannt.
- **AC-23:** GIVEN die Auslieferung, WHEN der Nachweis gegen echtes CloudKit-Produktion verlangt wird, THEN
  ist er nur über einen neuen TestFlight-Stand auf dem Gerät des PO erbringbar und als offene Grenze benannt
  (nicht automatisiert); bis dahin gilt die Wirkung als durch den Fake belegt, nicht als in Produktion
  bewiesen.
- **AC-24:** GIVEN Ticket und Berichte, WHEN sie formuliert werden, THEN nennen sie ausdrücklich: das
  Veröffentlichen des Schemas im Dashboard ist eine Konfiguration des Kontoinhabers und Voraussetzung für den
  vollen Funktionsumfang (Kategorien/Zuordnungen geteilt); der Fake ist die Ersatzprüfung; der Umbau auf
  CKShare (Alternative B) ist kein Teil dieses Durchgangs; es gibt keine Aussage „Sync repariert“ vor dem
  Nachweis aus AC-23.
- **AC-25:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau
  `SharedStoreService.swift`, `SyncCoordinator.swift`, `StoreDetailView.swift`,
  `RestockTests/SharedStoreSchemaTests.swift`, `docs/testflight-setup.md` und `project.pbxproj`
  (ca. +180/−20 LoC), ohne neue Dependencies, `Info.plist`-Änderung oder neuen `@AppStorage`-Schlüssel.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Härtung innerhalb der bestehenden Eigenbau-Architektur (öffentliche CloudKit-Datenbank,
  ein Record je Laden). Das Protokoll vor der Datenbank dient der Testbarkeit, nicht einem Architekturwechsel.
  Kein früherer Beschluss wird gekippt; die Entscheidung „Eigenbau statt CKShare“ bleibt Arbeitsstand
  (Alternative B).

## Folge-Durchgänge/Abgrenzung

- **Nicht in diesem Durchgang:** Umbau auf CKShare / private+shared Datenbank (Alternative B), eigenes
  Ticket nur bei belegter Sackgasse; eigene Sync-Diagnoseansicht in den Einstellungen; Account-Status-Prüfung
  (`CKAccountStatus`); Behandlung von Fetch-Fehlern, die heute als „neuer Record“ gelten
  (`SharedStoreService.swift:55-60`), und der Fehler in `StoreShareSheet` (`subscribe` nur `print`,
  Beitritts-Lookup) — Befunde 2 der Analyse; Hypothesen 2–4 (Laden nur in Entwicklung geteilt, Wasserstand,
  stille Nachrichten).
- **Konfiguration, kein Code (Kontoinhaber):** Schema in Produktion veröffentlichen; vorher prüfen, ob
  `categoriesJSON`/`assignmentsJSON` in Development stehen (entstehen dort nur, wenn ein Xcode-Lauf nach dem
  2026-10-02 einen geteilten Laden gespeichert hat). Blockiert den Code nicht.
- Folgearbeit aus Befund 2 wird, falls nötig, nach gemeinsamem Ziel gebündelt als ein GitHub-Issue angelegt
  (nicht als Mini-Tickets).

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **C** | Nur Konfiguration: Schema veröffentlichen, kein Code | einfachster Weg, heilt sofort, wird dem Kontoinhaber zuerst empfohlen; schützt aber nicht vor dem nächsten neuen Feld und macht Fehler weiter unsichtbar; allein nicht ausreichend |
| **A (gewählt)** | Härtung: Fallback ohne Erweiterungsfelder, Zustand und Diagnose sichtbar, Drift-Test, Dokumentation | ergänzt C; Kern der Synchronisierung läuft auch bei unvollständigem Schema; Fehler werden benannt; nächster Feldzugang fällt vor dem Upload auf |
| B | Umbau auf Apples CKShare / private+shared Datenbank | Rechte, Zonen, Annahme übernimmt das System; kippt den Eigenbau, Migration geteilter Läden nötig; zu groß, eigenes Ticket nur bei belegter Sackgasse |
| D | Erweiterungsfelder gar nicht mehr als eigene Felder, sondern in ein vorhandenes JSON-Feld packen | kein Schema-Problem mehr, aber Format-Änderung bestehender Records, alte Geräte lesen es falsch; verworfen |

Kein Modell beteiligt: Die Erkennung ist eine Textregel, die Behebung deterministische Logik. Gekippte
frühere Entscheidung: keine. Ausdrücklich nicht gekippt: öffentliche Datenbank und Eigenbau-Sync.

**Entscheidung:** Weg A, zusammen mit der Konfiguration aus Weg C.

## Risiken

- **Ursache nicht im Produktions-Schema:** Der Blick ins Dashboard fehlt. Trifft die Hypothese nicht zu,
  greift das Fallback nicht; die Diagnose (`lastFailureDetail`, Logger) liefert dann den echten Fehlertext.
  Zusage daher nur „Kern gleicht bei dieser Ablehnung ab“, nicht „Sync repariert“ (AC-23, AC-24).
- **Fehlertext-Regel zu eng/weit:** „production schema“ ist ein Textabgleich auf Apples Meldung; ändert Apple
  den Wortlaut, greift das Fallback nicht (Sync bleibt dann wie heute `.other`, aber mit sichtbarem Detail).
  Eine zu weite Regel wird durch T3/T6 begrenzt.
- **Stilles Auseinanderlaufen von Kategorien/Zuordnungen:** Beim Fallback laden Geräte diese nicht hoch;
  geteilte Kategorien divergieren, bis das Schema veröffentlicht ist. Deshalb der Banner (AC-11/12), keine
  stille Verschlucken.
- **Fallback gilt als Erfolg:** `push` liefert `true`, daher würde der Banner ohne die Erweiterung in AC-12
  nicht erscheinen; AC-12 und T7 sichern das.
- **Datenverlust-Risiko im kritischen Pfad:** Merge und Wasserstand werden nicht geändert; Tests T2–T5 und
  die bestehenden `SharedStoreMergeTests` sichern; Adversary 2 Runden.
- **Datenschutz im Log:** `os.Logger` darf keine Nutzdaten enthalten (AC-14).
- **Fake ist nicht die Produktion:** Er bildet nur die Ablehnung unbekannter Felder nach, keine
  Security Roles, Indizes, Zustellung (AC-23).
- **LoC-Gate zählt Testcode als Produktivcode:** ca. +180/−20 unter dem Limit; vor Abschluss prüfen.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün.
- **Zeilennummern verschieben sich:** maßgeblich sind die Funktionen.

## Changelog

- 2026-10-07: Initial spec created (Issue #121; Protokoll vor der Datenbank, Fake-Produktion als RED-Test,
  Fallback ohne `categoriesJSON`/`assignmentsJSON` bei Ablehnung wegen Produktions-Schema, Zustand „Schema
  unvollständig“, Diagnose, Drift-Test, TestFlight-Schritt)
