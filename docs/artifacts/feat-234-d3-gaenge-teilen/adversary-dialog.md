# Adversary Dialog — feat-234-d3-gaenge-teilen
Spec: docs/specs/services/shared-store-stations-sync.md
Datum: 2026-11-02 06:56

## Checkliste
- [x] AC-1: Der Typ `SharedStore` hat ein optionales Feld `stationsJSON`, es steht in `SharedStoreSchema.optionalExtensionFields` und in `docs/cloudkit/private-schema-aktuell.ckdb`. Tests: T6, T8, T5.
- [x] AC-2: `StoreCategories.mergeStationConfig` wählt den Stand mit dem späteren `date` als Ganzes, bei Gleichstand den lokalen; `nil` gilt als `distantPast`. Tests: G1, G2, G3.
- [x] AC-3: Ein fehlendes oder kaputtes Remote-Feld überschreibt nie einen gültigen lokalen Stand. Tests: G4, M5.
- [x] AC-4: Der Push mergt die lokalen Gänge gegen den Server-Record im `includeExtensionFields`-Block, schreibt nur ein nicht leeres Ergebnis und liefert den gemergten Stand zurück. Tests: M1, M2, M3.
- [x] AC-5: Der Pull liefert den Rohwert; `SyncCoordinator.apply` mergt gegen den lokalen Stand zum Anwendungszeitpunkt und schreibt nur bei Änderung; Übernahme behält das Datum des Absenders. Tests: M4, M5, M7.
- [x] AC-6: „Gänge entfernen“ schreibt einen Löschvermerk (`stations: []`, `hidden: []`, `date` jetzt); der Laden gilt als ohne Gänge, und der Vermerk gewinnt gegen ältere Remote-Stände. Tests: G5, M6, G8.
- [x] AC-7: `Store.adoptRemoteStationConfig` setzt kein neues Datum, legt die Gang-Namen als eigene Kategorien an und löst die Weg-Version nur bei tatsächlicher Änderung aus; ein übernommener Stand führt zu keinem Rückschreiben (kein Ping-Pong). Tests: G6, G7, M7.
- [x] AC-8: Ein Mitglied ohne lokale Gänge erhält beim Pull bzw. Beitritt die Gänge des Ladens. Tests: G3, G6, M4.
- [x] AC-9: Der Schema-Fallback (#121) bleibt alles-oder-nichts: ohne Erweiterungsfelder wird `stationsJSON` weder geschrieben noch verändert. Tests: T17, M3.
- [x] AC-10: Der Hinweis `station.setup.shared` lautet de und en wie in „Implementation Details (g)“; de/en-Schlüssel und Platzhalter bleiben gleich. Tests: G9, Y7, `LocalizationKeyParityTests`.
- [x] AC-11: Schema-Schritt vor dem nächsten TestFlight-Upload erledigt: `.ckdb` ergänzt, Development importiert, Production deployt, Export-Vergleich Development ↔ Production ohne Unterschied, Repo-Datei byteidentisch mit dem Development-Export. Nicht automatisch testbar, Nachweis ist ein Protokoll: Protokoll des Ablaufs `cloudkit-schema.yml` (`mode=export`) im Abschlussbericht; Test T8 prüft die Repo-Datei.
- [x] AC-12: Laden ohne `shareID` und alle bisherigen Gang-Tests (D1 bis 2b-2) verhalten sich unverändert; UI-Seed `UITEST-NOSHARE` schickt nichts an CloudKit. Tests: Bestandssuite, Y7.

## Dialog

### Runde 1
**Adversary:** Testlauf (RestockTests: StoreStationsTests, SharedStoreMergeTests, SharedStoreSchemaTests, LocalizationKeyParityTests) auf Restock-Validate-272: 109 Tests, 0 Fehler, TEST SUCCEEDED (docs/artifacts/feat-234-d3-gaenge-teilen/adversary-test-output.txt). Nicht gelaufen: ganze RestockTests-Suite, UI-Tests (Y7). Bekannt rot, unabhaengig: ConsumptionPatternTests (2, #231), auf Basisstand ebenso rot (consumption-pattern-basisstand.txt); keine Folge dieser Aenderung.

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/SharedStoreService.swift:481
  Evidence: stationsJSON steht in optionalExtensionFields, nicht in coreFields; docs/cloudkit/private-schema-aktuell.ckdb:197 enthaelt die Zeile im Typ SharedStore; T5/T6/T8 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Models/StoreCategories.swift:198
  Evidence: remote.date > local.date ? remote : local (Gleichstand lokal), nil-Seiten liefern die andere; Ganzstand, keine Mischung. G1-G3 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/StoreCategories.swift:215
  Evidence: decodeStationConfig liefert nil bei nil/leer/kaputt; mergeStationConfig gibt dann local zurueck. G4, M5 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Services/SharedStoreService.swift:165
  Evidence: mergeStations liest Record-Feld, mergt gegen store.stationConfig, schreibt nur bei write && merged != nil; Ergebnis in MergedState/push-Tupel. Aufruf in mergeIntoRecord (Z.155). M1-M3 gruen. Abweichung vom Wortlaut der Spec: der Merge steht ausserhalb des if-Blocks, wird aber mit write: includeExtensionFields gesteuert; Wirkung identisch (Fallback schreibt nichts).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Services/SyncCoordinator.swift:289
  Evidence: apply mergt zum Anwendungszeitpunkt und ruft adoptRemoteStationConfig nur bei merged != store.stationConfig (Vergleich ueber dekodierte Werte, nicht Zeichenketten); pull liefert Rohwert. Reihenfolge Mitglieder, Kategorien, Zuordnungen, Gaenge, Preise, Artikel wie in der Spec. M4, M5, M7 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Models/Store.swift:381
Code reference: SmartCart/Views/Store/StoreShareSheet.swift:408
Code reference: RestockTests/SharedStoreMergeTests.swift:472
  Evidence: removeStations schreibt StationConfig(stations: [], hidden: [], date: Date()); hasStations (activeStationConfig verlangt !stations.isEmpty) ist false. Leser StationSetupView.swift:25/230/247 und CategoryPickerView/StoreDetailView geprueft: alle gehen ueber hasStations oder nil-Koaleszenz. G5, M6, G8 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Models/Store.swift:388
  Evidence: adopt setzt stationConfig = config ohne Date(), legt ensureCustomCategory je Gang an, bumpRouteRevision nur bei geaendertem JSON. G6, G7, M7 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Services/SyncCoordinator.swift:289
  Evidence: lokal nil + remote gueltig -> merged = remote != nil -> Uebernahme beim Pull; Beitritt laeuft ueber denselben apply. G3, G6, M4 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Services/SharedStoreService.swift:165
  Evidence: write == includeExtensionFields == false schreibt nichts; syncToCloud unveraendert (ein Fallback, frischer Record). T17 (Fake-Produktion ohne stationsJSON: genau ein Fallback, alle drei Felder weg) und M3 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Models/Store.swift:376
  Evidence: Localizable.strings Z.452 de/en tragen den Wortlaut aus (g); Schluesselparitaet gruen. Store.swift hier nur als Pflichtzitat; Y7 (UI) nicht von mir ausgefuehrt.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Models/Store.swift:320
  Evidence: stationConfig-Getter/Setter delegiert an decode/encode; leeres JSON -> nil, Laden ohne Gaenge dekodiert nichts; bestehende Gang-Tests in StoreStationsTests (69) gruen. shareID == nil: push/pull kehren frueh zurueck (SharedStoreService.push guard, SyncCoordinator.pull guard).
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt)

### Runde 2
**Adversary:** Gezielter Angriff auf die gemeldete Abweichung `.sortedKeys`:
- Datums-Rundlauf: Wegwerfprobe (Scratchpad probe/main.swift) kodiert/dekodiert 200000 zufaellige Date-Werte mit Sekundenbruchteilen mit sortedKeys: 0 Abweichungen bei Gleichheit des Werts und der erneuten Kodierung. Also kein Dauer-Ungleich "merged != store.stationConfig" durch Rundung.
- Vergleich in apply und adopt: apply vergleicht dekodierte Structs (Equatable), nicht Zeichenketten. Altbestand mit unsortiertem JSON loest daher KEINEN Uebernahme-/Bump-Vorgang aus; er wird erst bei der naechsten echten Aenderung sortiert geschrieben. Der Push schreibt ggf. einmal die sortierte Zeichenkette in den Record (harmlos, gleicher Inhalt). adopt vergleicht JSON vorher/nachher, wird aber nur bei merged != lokal aufgerufen; ein reiner Schluesselreihenfolge-Unterschied kann also keinen Zaehler-Sprung erzeugen. Kein Ping-Pong.
- Gleichstand: lokal gewinnt, daher kein Ueberschreiben durch gleichaltrigen Fremdstand; zwei Geraete mit gleichem Datum und verschiedenem Inhalt bleiben dauerhaft verschieden (siehe F001, LOW).
- Loeschvermerk mit StationSetupView: addStation-Basis hat hidden [] und wird beim Schreiben ueber applyStationConfig neu gestempelt; delete zaehlt 0. Offenes Detail-Blatt (StationSetupView.swift:472/708/728) nutzt store.stationConfig mit guard bzw. stationNamed-Suche; bei Uebernahme eines Vermerks waehrend es offen ist, findet es nichts und tut nichts (nicht per UI-Lauf belegt).
- Fallback: Erstversuch merged mit write true, Fallback-Record frisch geladen, write false; serverRecordChanged-Wiederholung liest stationsJSON aus dem Gewinner-Record neu. Altclients (ohne D3) lassen das Feld im Record unberuehrt (mergeIntoRecord setzt es nur in neuer Version).

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/StoreCategories.swift:198
  Description: Gleichstand und Uhrenabweichung: Datum stammt von der Geraeteuhr (Date()). Ein Geraet mit vorgestellter Uhr gewinnt dauerhaft gegen spaetere echte Aenderungen anderer, bis diese spaeter stempeln; bei exakt gleichem Datum und verschiedenem Inhalt bleiben beide Seiten verschieden.
  Spec requirement: AC-2 — Gleichstand lokal (so umgesetzt und von der Spec so gewollt)
  Conflict: Kein Spec-Verstoss; Folge der Spec-Festlegung "Ganzstand, spaeterer gewinnt" ohne Serverzeit. Als bekannte Grenze zu vermerken.
  Remediation: Keine in D3; in Offene Grenzen der Spec/CLAUDE.md aufnehmen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Models/Store.swift:320
  Description: encodeStationConfig nutzt .sortedKeys (Abweichung von "mit dem vorhandenen JSONEncoder"). Begruendet und gefahrlos (siehe Probe), aendert aber die Bytes der gespeicherten Store.stationConfigJSON ab dem naechsten Schreiben; CloudKit-Spiegelung (CD_Store.CD_stationConfigJSON) sendet dadurch einmal einen neuen Wert pro betroffenem Laden.
  Spec requirement: AC-7 — kein Rueckschreiben/Ping-Pong
  Conflict: Kein Verstoss; im Abschlussbericht/Spec als dokumentierte Abweichung nennen.
  Remediation: Spec-Wortlaut (a) anpassen.

Offen, nicht belegt:
- AC-11: Repo-Datei korrekt (private-schema-aktuell.ckdb:197, T8 gruen). Development-Import, Production-Deploy und Export-Vergleich erfolgen nach dem Merge von main aus und sind NICHT belegt.
- Y7 (UI) und die ganze RestockTests-Suite wurden von mir nicht ausgefuehrt.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Misstrauisch gegen Runde 1/2 (AC-8 war dort faelschlich bestaetigt). Alle Einstiegswege per grep ueber SmartCart gesucht und gegen den Code gelesen:
- Teilen erstellen/Erst-Upload (StoreShareSheet.swift:174 publish -> syncToCloud -> mergeIntoRecord -> mergeStations): neuer Record, remote nil, lokale Gaenge landen in stationsJSON (SharedStoreService.swift:165). OK.
- Beitritt (StoreShareSheet.swift:389 pull, :408 apply): `stations: result.stations` jetzt uebergeben. OK (war der Fehler).
- Periodischer Pull alle 15 s, Pull beim Oeffnen der Liste, Push-Benachrichtigung (AppDelegate.swift:49 pullStore -> pull): SyncCoordinator.swift:105 uebergibt stations. OK.
- Push (pushInBackground, onDisappear der Liste, Edit/Add/Home-Pfade, Widget-Abhak-Push pushWidgetCheckoffsIfNeeded, MenuPlan, Rezeptimport): alle ueber SyncCoordinator.push -> sharedStoreService.push -> syncToCloud; apply des Ergebnisses SyncCoordinator.swift:128 mit stations. OK.
- resubscribeAll, subscribe, addSelfAsMember, fetchPreview, leaveBeforeDeleting, recordLocalDeletion: tauschen keine Ladendaten bzw. fassen stationsJSON nicht an (addSelfAsMember speichert den frisch geladenen Record mit nur membersJSON geaendert, Altfelder bleiben). OK.
- Weitere CloudKit-Nutzer (SharedItemPhotoService, CommunityPriceService, PromoCodeService) betreffen andere Record-Typen. Kein weiterer apply-Aufruf im Code (nur die drei Stellen).
Test M8 (SharedStoreMergeTests.testEveryApplyCallPassesStations): scheitert, wenn eine einzeilige apply(items:)-Zeile mit `categories:` kein `stations:` hat (genau der behobene Fehler); Mindestzahl 3 gefunden schuetzt vor Umbenennung. Blind: mehrzeilige Aufrufe (Zeile ohne `categories:` wird nicht geprueft), `stations: nil` oder `stations:` in Kommentar genuegt, nur zwei Dateien gescannt, anderer Aufrufname faellt durch. Als Beleg fuer die heutigen drei Aufrufe ausreichend, als Dauerschutz schwach (F003, LOW). Zusaetzlich bleibt die Verhaltenskette Pull->apply durch die M-/G-Tests der Mergelogik gedeckt, nicht aber Beitritt end-to-end (CloudKit nicht automatisiert).
Eigener Testlauf auf Restock-Validate-272 (SharedStoreMergeTests, SharedStoreSchemaTests, StoreStationsTests): 106 Tests, 0 Fehler, TEST SUCCEEDED, inklusive testEveryApplyCallPassesStations (docs/artifacts/feat-234-d3-gaenge-teilen/adversary-test-output.txt). Nicht gelaufen: ganze Suite, UI-Tests.

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Views/Store/StoreShareSheet.swift:408
  Evidence: join uebergibt stations: result.stations an apply; Pull-Pfade SyncCoordinator.swift:105 und Push-Rueckweg :128 tun dasselbe; Erst-Upload schreibt stationsJSON ueber mergeStations (SharedStoreService.swift:165). Alle apply-Aufrufe im Quelltext gefunden und geprueft.
  Status: CONFIRMED

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: RestockTests/SharedStoreMergeTests.swift:472
  Description: M8 prueft zeilenweise Text; mehrzeilige apply(items:)-Aufrufe, `stations: nil` und Dateien ausser StoreShareSheet.swift/SyncCoordinator.swift bleiben unbeachtet.
  Spec requirement: AC-8 — Mitglied erhaelt die Gaenge beim Pull bzw. Beitritt
  Conflict: Kein Verstoss heute; Regressionsschutz begrenzt.
  Remediation: Optional Aufrufe ueber ganze Anweisung (bis zur schliessenden Klammer) pruefen oder apply-Argument stations ohne Standardwert machen.

Offen, nicht belegt: Station-Aenderungen im Setup-Blatt werden erst beim Verlassen der Liste (onDisappear) oder beim naechsten Push anderer Aenderungen hochgeladen, nicht sofort (wie bisherige Kategorien); Beitritt und Pull gegen echtes CloudKit nicht automatisiert.
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Code reference: SmartCart/Models/Store.swift:381
Code reference: SmartCart/Models/StoreCategories.swift:198
Code reference: SmartCart/Services/SharedStoreService.swift:165
Code reference: SmartCart/Services/SyncCoordinator.swift:289

VERDICT: VERIFIED
Tests: 106 passed, 0 failed, 0 uebersprungen (Runde 3, Teilmenge SharedStoreMerge/SharedStoreSchema/StoreStations; ConsumptionPatternTests #231 bekannt rot, unabhaengig)
Edge cases: sortedKeys, Datumsrundlauf, Gleichstand, Loeschvermerk, Fallback, alle Einstiegswege (Teilen, Beitritt, Pull, Push, Widget, Benachrichtigung) geprueft, nichts gebrochen; M8 begrenzt (F003, LOW)
Regressions: keine gefunden
Checklist: 11/12 belegt (AC-8 in Runde 3 am Beitritt neu bestaetigt); AC-11 nur Repo-Datei belegt, Development/Production-Schritt offen bis nach Merge

## Geprüfte Dateien

- sha256:e63183a3a6a66bf7cdf5fae9c920ea2fcbb3477c92edf37aaeade33d926c4276  SmartCart/Models/Store.swift
- sha256:835127d4892ad92a2f0de086f0c81cd4995b5a93c0a43f1ef221974257f10508  SmartCart/Models/StoreCategories.swift
- sha256:ebe9471c0c5030638594cbd4c0f349fd09f3ea313e10e7263048df5f99d702cb  SmartCart/Services/SharedStoreService.swift
- sha256:2e4c3c82e4bdfaf7218136e6437b0e5a98ecba6df3e3773f75f06399f3bfeaa9  SmartCart/Services/SyncCoordinator.swift

## Prüfbasis

- base: 044674281fd0f72b65c82d142f891084bb18eb63
- blob:feee86615d5c3d9556eae1d233b4f549198cc488  SmartCart/Models/Store.swift
- blob:db5f0c08def4632ba301b3c7f7380671edb22ef3  SmartCart/Models/StoreCategories.swift
- blob:12416aea3ab7206e7ec7b2f793f54a19f4d0013f  SmartCart/Services/SharedStoreService.swift
- blob:da54ee220a263e2ee7de0e69a8542f4cbeefb140  SmartCart/Services/SyncCoordinator.swift

## Geprüfte Dateien

- sha256:615b285a652a6b1ef64063a6b7be951b6081cf9159c718052caa4508637195d8  RestockTests/SharedStoreMergeTests.swift
- sha256:e63183a3a6a66bf7cdf5fae9c920ea2fcbb3477c92edf37aaeade33d926c4276  SmartCart/Models/Store.swift
- sha256:835127d4892ad92a2f0de086f0c81cd4995b5a93c0a43f1ef221974257f10508  SmartCart/Models/StoreCategories.swift
- sha256:ebe9471c0c5030638594cbd4c0f349fd09f3ea313e10e7263048df5f99d702cb  SmartCart/Services/SharedStoreService.swift
- sha256:2e4c3c82e4bdfaf7218136e6437b0e5a98ecba6df3e3773f75f06399f3bfeaa9  SmartCart/Services/SyncCoordinator.swift
- sha256:478251dec18d4a322f89b4a29ec383cf97472c9a0b84ca3d82f8cd53fb0183cd  SmartCart/Views/Store/StoreShareSheet.swift

## Prüfbasis

- base: 044674281fd0f72b65c82d142f891084bb18eb63
- blob:a91e61f9c49b14a2d77aa58506ec122ede4221b3  RestockTests/SharedStoreMergeTests.swift
- blob:feee86615d5c3d9556eae1d233b4f549198cc488  SmartCart/Models/Store.swift
- blob:db5f0c08def4632ba301b3c7f7380671edb22ef3  SmartCart/Models/StoreCategories.swift
- blob:12416aea3ab7206e7ec7b2f793f54a19f4d0013f  SmartCart/Services/SharedStoreService.swift
- blob:da54ee220a263e2ee7de0e69a8542f4cbeefb140  SmartCart/Services/SyncCoordinator.swift
- blob:9035b7cd153c4268adc675497c482b1d873e3523  SmartCart/Views/Store/StoreShareSheet.swift
