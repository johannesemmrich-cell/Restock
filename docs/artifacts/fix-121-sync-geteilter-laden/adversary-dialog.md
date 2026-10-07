# Adversary Dialog — fix-121-sync-geteilter-laden
Spec: docs/specs/services/shared-store-schema-fallback.md
Datum: 2026-10-07 21:13

## Checkliste
- [x] **AC-1:** GIVEN eine Fake-Datenbank, die wie die Produktion Records mit den Feldern `categoriesJSON` oder `assignmentsJSON` mit `serverRejectedRequest` und „Cannot create or modify field 'categoriesJSON' in record 'SharedStore' in production schema“ ablehnt, WHEN ein geteilter Laden vor der Umsetzung (aktueller Code, Protokoll nur im Test eingehängt) gepusht wird, THEN schlägt der Push fehl (RED, Ist-Zustand der PO-Meldung belegt).
- [x] **AC-2:** GIVEN derselbe Test nach der Umsetzung, WHEN er läuft, THEN ist er grün (Schalter Fehler da → Fix → Fehler weg).
- [x] **AC-3:** GIVEN die Ablehnung wegen Produktions-Schema, WHEN `syncToCloud` sie erkennt, THEN speichert es genau einmal erneut ohne `categoriesJSON` und `assignmentsJSON`; insgesamt zwei Speicherversuche.
- [x] **AC-4:** GIVEN das Fallback, WHEN es greift, THEN bleiben `storeName`, `storeEmoji`, `storeColorHex`, `ownerDevice` (bei neuem Record), `itemsJSON`, `membersJSON`, `deletedJSON` und `pricesJSON` im gespeicherten Record, und Artikel, Preise und Mitglieder gleichen wieder ab (Pull durch ein zweites Gerät liefert sie).
- [x] **AC-5:** GIVEN das Fallback scheitert ebenfalls, WHEN der zweite Versuch fehlschlägt, THEN wird dessen Fehler geworfen, es gibt keinen dritten Versuch, und der bestehende Wiederholversuch bei `serverRecordChanged` bleibt auf höchstens einen Zusatzversuch begrenzt.
- [x] **AC-6:** GIVEN ein Fehler, dessen Text nicht „production schema“ enthält (Netz, `permissionFailure`, `notAuthenticated`, sonstige), WHEN Push läuft, THEN gibt es kein Fallback (genau ein Speicherversuch) und `SyncFailureKind` wird wie bisher klassifiziert (`permissionDenied`, `notAuthenticated`, `other`).
- [x] **AC-7:** GIVEN ein Push mit oder ohne Fallback, WHEN das Speichern fehlschlägt, THEN bleibt `lastSync` unverändert; nur nach erfolgreichem Speichern wird es auf die Server-`modificationDate` gesetzt.
- [x] **AC-8:** GIVEN eine Fake-Datenbank mit vollem Schema, WHEN Push läuft, THEN gibt es genau einen Speicherversuch, der Record enthält `categoriesJSON` und `assignmentsJSON`, und der Zustand `schemaIncomplete` wird nicht gesetzt.
- [x] **AC-9:** GIVEN das Fallback greift, WHEN `SyncCoordinator.push` endet, THEN ist `lastFailureKind == .schemaIncomplete`, der Aufruf liefert `true` (Kern abgeglichen), und `lastFailureDetail` benennt die Ablehnungsursache.
- [x] **AC-10 (geändert 2026-10-07 per PO-„override“):** GIVEN der Zustand `schemaIncomplete`, WHEN danach ein `pull` erfolgreich endet, THEN bleibt `schemaIncomplete` stehen (der App-weite Abruf alle 15 s darf den Hinweis nicht löschen); ein fehlschlagender `pull` überschreibt `schemaIncomplete` ebenfalls nicht (der Fehler wird protokolliert); erst ein vollständiger `push` (ohne Fallback) setzt ihn zurück. GIVEN ein früherer anderer Fehler (`other`, `permissionDenied`, `notAuthenticated`), WHEN danach ein `pull` oder vollständiger `push` erfolgreich endet, THEN ist `lastFailureKind` zurückgesetzt und bleibt nicht stehen.
- [x] **AC-11:** GIVEN `lastFailureKind == .schemaIncomplete`, WHEN der Banner in `StoreDetailView` erscheint, THEN lautet der Text „Server-Einrichtung unvollständig — Kategorien und gemerkte Zuordnungen werden noch nicht geteilt; Artikel gleichen ab“; die Texte der übrigen Fehlerarten sind wörtlich unverändert.
- [x] **AC-12:** GIVEN das Fallback hat den Kern abgeglichen (`pull`/`push` lieferte `true`), WHEN der Laden geöffnet ist, THEN zeigt der Banner den Zustand „Schema unvollständig“ trotzdem; der Banner-Aufbau (Button mit Warnsymbol, Text, Aktualisieren-Symbol, orange Hinterlegung, Tippen löst Pull aus) ist unverändert.
- [x] **AC-13:** GIVEN ein Fehler bei `pull` oder `push`, WHEN er im `catch` landet, THEN hält `SyncCoordinator.lastFailureDetail` Domain, Code und `ServerErrorDescription` bzw. `localizedDescription`.
- [x] **AC-14:** GIVEN ein Fehler bei `pull` oder `push`, WHEN er auftritt, THEN schreibt ein `os.Logger` (Subsystem Bundle-ID, Kategorie `sync`) Domain, Code und Fehlertext; Ladenname, Artikel, Anzeigename und Freigabecode stehen nicht im Klartext im Log; es gibt kein `print` und kein stilles Verschlucken in diesen Zweigen.
- [x] **AC-15:** GIVEN `developerMode == true` und ein Syncfehler oder `schemaIncomplete`, WHEN der Banner erscheint, THEN zeigt er zusätzlich die Detailzeile (`lastFailureDetail`); mit `developerMode == false` fehlt sie.
- [x] **AC-16:** GIVEN `RestockTests/SharedStoreSchemaTests.swift`, WHEN die Feldmenge eines über `mergeIntoRecord` erzeugten Records von der im Test festgeschriebenen Liste abweicht, THEN schlägt der Test fehl mit der Meldung „Felder von SharedStore geändert: CloudKit-Schema vor dem TestFlight-Upload veröffentlichen (docs/testflight-setup.md)“; bei Übereinstimmung ist er grün. Die Datei ist in `project.pbxproj` an allen vier Stellen registriert.
- [x] **AC-17:** GIVEN `docs/testflight-setup.md`, WHEN man den Abschnitt „CloudKit-Schema veröffentlichen, wenn sich die Felder von `SharedStore` ändern“ liest, THEN enthält er den Weg Dashboard → Container `iCloud.com.johannesemmrich.SmartCart` → Development → „Deploy Schema Changes…“, den Hinweis, vorher zu prüfen, dass die Felder in Development stehen, und dass TestFlight die Produktion nutzt.
- [x] **AC-18:** GIVEN der Produktivcode, WHEN `SharedStoreService` seine Datenbank anspricht, THEN läuft es über das neue Protokoll mit `CKContainer.publicCloudDatabase` als Instanz; Signaturen und Verhalten von `publish`, `push`, `pull`, `fetchPreview`, `addSelfAsMember`, `subscribe` sind für Aufrufer unverändert, und die bestehenden `SharedStoreMergeTests` bleiben unverändert grün.
- [x] **AC-19:** GIVEN die gesamte Unit-Suite, WHEN sie lokal läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch.
- [x] **AC-20:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN sind alle Tests grün, die Testzahl ist > 0, ohne Abbruch und Retry-Flag. (Bei Flakes #111 bleibt eine Ausnahme dem PO vorbehalten und wird nicht vorab angenommen.)
- [x] **AC-21:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt der Build ohne Fehler.
- [x] **AC-22:** GIVEN die App im Simulator mit dem Stand dieses Durchgangs, WHEN ein geteilter Laden (soweit mit `-skipCloudKitForScreenshots` bzw. DEBUG-Mitteln erzeugbar) als Nutzer durchgespielt wird, THEN verhält sich die Ansicht wie beschrieben (Banner-Text/-Aufbau); der Durchlauf ist als Artefakt registriert. Ist der CloudKit-Fehlerfall im Simulator nicht erzeugbar, wird das ausdrücklich als offen benannt.
- [x] **AC-23:** GIVEN die Auslieferung, WHEN der Nachweis gegen echtes CloudKit-Produktion verlangt wird, THEN ist er nur über einen neuen TestFlight-Stand auf dem Gerät des PO erbringbar und als offene Grenze benannt (nicht automatisiert); bis dahin gilt die Wirkung als durch den Fake belegt, nicht als in Produktion bewiesen.
- [x] **AC-24:** GIVEN Ticket und Berichte, WHEN sie formuliert werden, THEN nennen sie ausdrücklich: das Veröffentlichen des Schemas im Dashboard ist eine Konfiguration des Kontoinhabers und Voraussetzung für den vollen Funktionsumfang (Kategorien/Zuordnungen geteilt); der Fake ist die Ersatzprüfung; der Umbau auf CKShare (Alternative B) ist kein Teil dieses Durchgangs; es gibt keine Aussage „Sync repariert“ vor dem Nachweis aus AC-23.
- [x] **AC-25:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau `SharedStoreService.swift`, `SyncCoordinator.swift`, `StoreDetailView.swift`, `RestockTests/SharedStoreSchemaTests.swift`, `docs/testflight-setup.md` und `project.pbxproj` (ca. +180/−20 LoC), ohne neue Dependencies, `Info.plist`-Änderung oder neuen `@AppStorage`-Schlüssel.

## Dialog

### Runde 1
**Adversary:**

Methode: nur gelesen (Diff gegen 41e19c6, Artefakte, Spec, Aufrufer per grep). Kein Test, Build oder Simulator gestartet. Diff gegen 41e19c6: SharedStoreService +97/−37, SyncCoordinator +57/−6, StoreDetailView +41/−15, SharedStoreSchemaTests +17/−0, dazu docs/testflight-setup.md, Spec, Briefing. Ergebnis: keine CRITICAL- und keine HIGH-Befunde; vier MEDIUM/LOW-Befunde (F001–F004) und eine Beobachtung (F005). Der kritische Pfad (Speicherschleife, Merge, lastSync) hielt stand.

Schwerpunkt 1 (syncToCloud): Schleife auf höchstens 3 Speicherversuche begrenzt (zwei Einmal-Schalter retriedServerChange und schemaRejection); durchgespielt: Schema→Fallback ok = 2 Versuche; Schema→Fallback mit serverRecordChanged→Wiederholung = 3; serverRecordChanged→Schema→Fallback = 3; jeder weitere Fehler wird geworfen; T4b prüft beide Reihenfolgen mit Fake-Obergrenze 10. Der Fallback-Record ist frisch (currentRecord lädt neu oder legt neu an), Erweiterungsfelder weder in allKeys noch changedKeys; der Fake prüft beide Mengen. markSynced erst nach save. Kein Datenverlust durch den Fallback: Merge unverändert, nur die zwei Schreibzeilen entfallen.
Code reference: SmartCart/Services/SharedStoreService.swift:69
Code reference: SmartCart/Services/SharedStoreService.swift:79
Code reference: SmartCart/Services/SharedStoreService.swift:89
Code reference: SmartCart/Services/SharedStoreService.swift:155

Schwerpunkt 2 (Erkennung): Regel „production schema“, case-insensitive, ServerErrorDescription oder localizedDescription, bei partialFailure rekursiv; zu weite Auslösung kostet höchstens einen Zusatzversuch (begrenzt). Restrisiko: ein lokalisierter Text ohne ServerErrorDescription würde nicht erkannt (T6 prüft nur den englischen Text).

Schwerpunkt 3 (SyncCoordinator): Klasse ist @MainActor; Zustandsautomat entspricht AC-10 (Override-Fassung): Pull-Erfolg und Pull-Fehler lassen schemaIncomplete stehen, vollständiger Push löscht, andere Fehler werden bei Pull-Erfolg zurückgesetzt (T7). Zustand ist ein App-weiter Singleton (siehe F004).
Code reference: SmartCart/Services/SyncCoordinator.swift:50
Code reference: SmartCart/Services/SyncCoordinator.swift:65
Code reference: SmartCart/Services/SyncCoordinator.swift:72

Schwerpunkte 6–8: Das push-Tupel wird nur im SyncCoordinator konsumiert; übrige Aufrufer mit unveränderten Signaturen; lastFailureKind als Optional nur in StoreDetailView und Tests gelesen; mergeIntoRecord mit Default-Parameter, SharedStoreMergeTests unverändert grün. Scope: Dateimenge stimmt, keine Info.plist-/AppStorage-/Dependency-Änderung; Umfang weicht von „ca. +180/−20“ ab (PO informiert, „go“ gegeben). docs/testflight-setup.md inhaltlich stimmig (Dashboard-Beschriftungen nicht prüfbar).
Code reference: SmartCart/Views/Store/StoreDetailView.swift:275
Code reference: docs/testflight-setup.md:26

Beweislage der Läufe (selbst nachgezählt): test-green-output.txt (21:11): 462 Tests, 0 Failures, TEST SUCCEEDED; SharedStoreSchemaTests alle 12 laufen; RED: test-red-output.txt nur Übersetzungsfehler, test-red-runtime-output.txt T1 zur Laufzeit rot, -2/-3 zeigen die Override-Nachbesserung rot (T7); release-build.txt BUILD SUCCEEDED.

Findings:
- F001 (MEDIUM, edge_case) SyncCoordinator.swift:65: Ein fehlschlagender pull überschreibt schemaIncomplete bewusst nicht; bei Netzausfall zeigt der Banner den Schema-Text statt „Sync fehlgeschlagen“, im Entwicklermodus steht die veraltete Detailzeile. Entspricht AC-10 wörtlich, Zielkonflikt mit AC-13/15 im Mischfall. Entscheidung: hinnehmen und benennen.
- F002 (LOW, edge_case) SyncCoordinator.swift:64: Logger gibt den Fehlertext mit privacy .private aus (in Release als <private>); Domain und Code öffentlich. Datenschutzseitig vertretbar (ServerErrorDescription kann Freigabecode enthalten); AC-14-Lesart im Bericht präzisieren.
- F003 (MEDIUM, edge_case) SharedStoreService.swift:97: Der reale Fall der PO-Meldung (in der Produktion BEREITS vorhandener Record ohne Erweiterungsfelder) ist nicht per Test abgedeckt; der Fake gibt dieselbe Instanz zurück, nicht eine frische Kopie. Remediation: Test mit vorab hinterlegtem Server-Record oder als offene Grenze benennen.
- F004 (LOW, edge_case) SyncCoordinator.swift:50: lastFailureKind/lastFailureDetail sind ein App-weiter Zustand, nicht je Laden; kann einen Laden fälschlich belasten. Im Bericht nennen.
- F005 (LOW, anti_pattern) SharedStoreService.swift:69: Umsetzung und Artefakte uncommittet; keinen dauerhaften Stand für die Stempel. Grünen Zwischenstand sichern.

AC-Bewertung Runde 1: AC-1 bis AC-19 sowie AC-21 AKZEPTIERT (AC-4 mit Einschränkung aus F003; AC-10 mit F001 als NACHFRAGE; AC-14 NACHFRAGE F002); AC-25 AKZEPTIERT mit Offenlegung des Umfangs; AC-20, AC-22, AC-23, AC-24 in Runde 1 noch offen und nachgereicht (UI-Suite-Endzeile; Durchlauf-Artefakt; Berichtstexte).
Vorläufiges Urteil Runde 1: keine CRITICAL-/HIGH-Befunde; F001/F002 NACHFRAGE, F003 Testlücke; noch nicht VERIFIED.

**Implementierer:**

(Antworten in Runde 2)

### Runde 2
**Adversary:**

Methode: Läufe nachgezählt statt Zusagen übernommen.
- Unit-Suite test-green-output.txt (21:49): 463 Tests, 0 Failures, TEST SUCCEEDED (462 plus T16).
- UI-Suite test-full-ui-suite-output.txt (21:39): 78 Tests, 1 bekannt übersprungen, 0 Failures, TEST SUCCEEDED.
- Mutationsprobe durchlauf-t16-mutationsprobe.txt Zeile 217: 13 Tests, 11 Failures — T16 reagiert auf die Mutation.
- Banner-Durchlauf durchlauf-banner-1.txt: 1 Test, 0 Failures. Diff von SmartCartApp.swift gegen 41e19c6: 0 Zeilen, der Wegwerf-Haken ist restlos entfernt.
- Produktivdateien laut Numstat unverändert gegenüber Runde 1 (SharedStoreService +97/−37, SyncCoordinator +57/−6, StoreDetailView +41/−15); Testcode +68/−1 durch T16.
Einschränkung: Änderungszeitstempel von SharedStoreService (21:48), SyncCoordinator (21:52) und SmartCartApp (21:52) liegen nach dem UI-Lauf (21:39) wegen Mutationsprobe/Haken und Zurückspielen aus der Sicherung; der Stempel vergleicht Hashes, nicht Zeitstempel.

T16 (zu F003): AKZEPTIERT. Legt über fake.seed einen vorhandenen Server-Record ohne Erweiterungsfelder an; prüft 2 Speicherversuche, assertNoExtensionFields für allKeys() und changedKeys(), gemergte Artikel {Eier, Brot}, Mitglied „Anderes Gerät“ bleibt, ownerDevice nicht überschrieben, lastSync rückt vor. Die Mutationsprobe zeigt, dass der Test den Fehler fängt.
F001 (MEDIUM): AKZEPTIERT als bekannte Grenze; muss im Abschlussbericht stehen: Bei Pull-Fehler im Zustand schemaIncomplete zeigt der Banner weiter den Schema-Hinweis, nicht „Sync fehlgeschlagen“.
F002 (LOW): AKZEPTIERT mit Präzisierung: „Fehlertext wird protokolliert, in Release-Geräteprotokollen geschwärzt“, nicht „im Log lesbar“.
F004 (LOW): AKZEPTIERT; als Grenze im Ticket (Punkt 6).
F005 (LOW): AKZEPTIERT mit Auflage: Commit unmittelbar nach dem Verdict, alle Dateien (Spec, Briefing, Artefakte) erfassen.
AC-20: AKZEPTIERT. 78 Tests, 1 übersprungen (bekannt), 0 Failures, TEST SUCCEEDED, 21:39; kein Retry-Flag (vom Koordinator bestätigt: Aufruf ohne -retry-tests-on-failure/-test-iterations).
Code reference: docs/artifacts/fix-121-sync-geteilter-laden/test-full-ui-suite-output.txt:1
AC-22: AKZEPTIERT mit ausdrücklich offener Grenze: gezeigt sind Anzeige und Layout (durchlauf121-1.png hell ohne Entwicklermodus, -2.png hell mit Detailzeile, Aufbau unverändert); der CloudKit-Fehlerfall selbst ist im Simulator nicht erzeugbar, Zustand per Wegwerf-Haken gesetzt. Nebenbefund (nicht #121): im Entwicklermodus überdeckt die DEV-Pille die Toolbar-Knöpfe, bestand vorher.
Code reference: docs/artifacts/fix-121-sync-geteilter-laden/durchlauf121-2.png:1
AC-23: AKZEPTIERT unter Vorbehalt (Ticket-Kommentar). AC-24: AKZEPTIERT unter Vorbehalt: die fünf Aussagen stehen im Ticket #121, Kommentar „Stand der Umsetzung (2026-10-07)“ (vom Koordinator nach der Prüfung gegengelesen: `gh issue view 121 --comments`).
AC-25: AKZEPTIERT mit Offenlegung des Umfangs (PO „go“).
AC-1 bis AC-19, AC-21: wie in Runde 1; für AC-19 gilt jetzt 463 Tests, 0 Failures.
Code reference: SmartCart/Services/SharedStoreService.swift:69
Code reference: SmartCart/Services/SyncCoordinator.swift:50
Code reference: SmartCart/Views/Store/StoreDetailView.swift:275
Code reference: RestockTests/SharedStoreSchemaTests.swift:410
Code reference: docs/testflight-setup.md:26

**Implementierer:**
- F003: Test T16 ergänzt (vorhandener Server-Record eines anderen Geräts, frische Kopie, Merge, ownerDevice unverändert, keine Erweiterungsfelder in allKeys und changedKeys, 2 Speicherversuche, lastSync vorgerückt). Mutationsprobe T16 rot, danach per Sicherung wiederhergestellt (Prüfsummen). Unit-Suite 463 Tests, 0 Failures.
- F001: hinnehmen und benennen (Folge von AC-10, Mischfall selten, Pull-Fehler steht im Log).
- F002: hinnehmen, bewusst; der Text kann den Freigabecode enthalten; Domain und Code sind öffentlich, der Text ist in Release-Protokollen geschwärzt und im Entwicklermodus in der Detailzeile sichtbar.
- F004: hinnehmen und benennen, steht im Ticket #121 (Punkt 6).
- F005: Commit unmittelbar nach dem Verdict, Sicherungen und Patch im Scratchpad.
- AC-20: UI-Suite lokal, 78 Tests, 1 bekannt übersprungen, 0 Failures, 21:39. AC-22: Durchlauf mit Wegwerf-Haken, drei Screenshots und durchlauf-banner-1.txt. AC-23/24: Ticket #121. AC-25: Umfang weicht ab, PO informiert, „go“.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Einordnung: Keine Verdachtszeilen aus einer Tabelle. Schreibpfad der Zustandsgrößen trotzdem geprüft: `lastFailureKind` und `lastFailureDetail` werden nur im SyncCoordinator geschrieben (recordFailure, clearFailure, Fallback-Zweig in push; SyncCoordinator.swift:61–75 und 129–131). Bedingung davor: Fehler im catch von pull/push, vollständiger Push oder Pull-Erfolg, Schema-Ablehnung im Push-Ergebnis. Test für diesen Weg: T7 testT7_coordinatorStateSetAndReset (RestockTests/SharedStoreSchemaTests.swift:277) über die echte Kette SyncCoordinator.push/pull mit Fake-Datenbank. `lastSync` nur in markSynced nach erfolgreichem save (SharedStoreService.swift:79); Tests T2, T4, T4b, T16.

## Verdict
**VERIFIED**

Begründung (Adversary): Die Umsetzung hat dem Angriff standgehalten, keine CRITICAL- oder HIGH-Befunde, die Testlücke F003 ist durch T16 geschlossen (Mutationsprobe belegt die Wirkung). Speicherschleife höchstens 3 Versuche (T4b), Fallback-Record frisch, lastSync nur nach Erfolg, Zustandsautomat entspricht der Override-Fassung von AC-10. Unit-Suite 463/463 grün, UI-Suite 78 Tests mit 0 Failures und einem bekannt übersprungenen Test, Release-Build grün, Banner und Detailzeile im Simulator sichtbar. Verbleibende Grenzen F001, F002, F004 akzeptiert und im Bericht zu benennen. Offene Grenzen: CloudKit-Fehlerfall im Simulator nicht erzeugbar; echtes Speichern gegen die Produktion nur über einen neuen TestFlight-Stand beim PO; Ursache unbewiesen; keine Aussage „Sync repariert“; Schema-Veröffentlichung ist Konfiguration des Kontoinhabers; CKShare nicht Teil.

## Geprüfte Dateien

- sha256:5d686127b762efb4e4eafe441bb19cf45ad3436258379f482201dbab609eb681  RestockTests/SharedStoreSchemaTests.swift
- sha256:66426547691d5490079e205917d40650959585e271a1858c5e83ef06c9c41d25  SmartCart/Services/SharedStoreService.swift
- sha256:f6e11e21bfa242917dc7a03cf540138da3de6b453d086fefcf712903745ea01d  SmartCart/Services/SyncCoordinator.swift
- sha256:f1d02b4beb87701a0ca26cb8f9fdc26e641d8fa210114cd727d8ac72dd97ca71  SmartCart/Views/Store/StoreDetailView.swift
- sha256:56b994e2fc4e405b4f0f050a1e45488c7d8affffa5ff3639c539992143571a10  docs/artifacts/fix-121-sync-geteilter-laden/durchlauf121-2.png
- sha256:5880420b1839d52d08c74b4e812f8f82a14e0d646b2116a373fec6404d7dd661  docs/artifacts/fix-121-sync-geteilter-laden/test-full-ui-suite-output.txt
- sha256:c2823dcec411c84a46188bc3d4e09525265adf3572cb6fb45c083b668870d001  docs/testflight-setup.md

## Prüfbasis

- base: 9c720490b66c1a211e1d3f48886a75fe9860f01f
- blob:88f4dd4c022b380b2ea05c655297f5a604058cf6  RestockTests/SharedStoreSchemaTests.swift
- blob:3fac74b9c41757428f63fb3330c0cd780cf31327  SmartCart/Services/SharedStoreService.swift
- blob:334a5e80dfa0b0e2cb5ef4e66000c06e186fb9c2  SmartCart/Services/SyncCoordinator.swift
- blob:ea1fb234c976b6dce119b14db493c28043d9087e  SmartCart/Views/Store/StoreDetailView.swift
- blob:c6f6d318b40a80a66c7133fc80b619741b11ff90  docs/artifacts/fix-121-sync-geteilter-laden/durchlauf121-2.png
- blob:6577205c81255db7f7a6ac171ac671a6ff67835a  docs/artifacts/fix-121-sync-geteilter-laden/test-full-ui-suite-output.txt
- blob:f77905f79bf87b073cef554ac25c8733a2b864fa  docs/testflight-setup.md
