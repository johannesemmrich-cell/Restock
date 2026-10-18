# Adversary Dialog — fix-155-icloud-produktionsschema
Spec: docs/specs/models/private-cloudkit-schema.md
Datum: 2026-10-18 13:01

## Checkliste
- [x] **AC-1 [Test]:** `MirroredSchemaSnapshotTests` T1 ist grün und schlägt bei Entfernen eines Attributs aus der festen Liste nachweislich fehl (RED-Gegenprobe im Protokoll).
- [x] **AC-2 [Test]:** T2 war vor dem Schema-Import rot (Meldung nennt `CD_FeedbackItem` und `CD_TodoItem`) und ist nach dem Import grün (beide Läufe im Protokoll).
- [x] **AC-3 [Beleg]:** `docs/cloudkit/private-schema-vorher.ckdb` zeigt den Ist-Zustand ohne `CD_FeedbackItem` und `CD_TodoItem`.
- [x] **AC-4 [Beleg]:** Nach `import-schema` zeigt `diff` zwischen „vorher“ und neuem Development-Export ausschließlich `CD_FeedbackItem` (6 Felder plus Systemfelder) und `CD_TodoItem` (5 Felder plus Systemfelder), `validate-schema` meldet keinen Fehler.
- [x] **AC-5 [Beleg]:** Das Dashboard zeigt vor „Deploy Schema Changes…“ nur diese zwei Typen im Diff; der Deploy ist durchgeführt. (PO-Auskunft 2026-10-18 im Chat: Vorschau von Claude Desktop zeigte nur CD_FeedbackItem und CD_TodoItem; indirekt belegt durch Production = Development)
- [x] **AC-6 [Beleg]:** Der Production-Export nach dem Deploy enthält `CD_Store`, `CD_ShoppingItem`, `CD_PurchaseRecord`, `CD_FeedbackItem`, `CD_TodoItem` mit denselben Feldern wie Development (`diff` ohne Unterschied bei den `CD_`-Typen), abgelegt unter `docs/artifacts/fix-155-icloud-produktionsschema/`. (Inhalt belegt; Herkunft nicht protokolliert, siehe F002)
- [x] **AC-7 [Beleg]:** Das Management-Token ist nach der Arbeit entfernt (`remove-token --type management`, Ausgabe im Protokoll, kein Tokenwert in Repo oder Protokoll). (Schlüsselbund ja; Dashboard-Eintrag offen, siehe F003)
- [x] **AC-8 [Test/Beleg]:** `docs/testflight-setup.md` enthält den neuen Abschnitt mit den Befehlen `export-schema`, `validate-schema`, `import-schema`, `remove-token`, dem Hinweis „Deploy Schema Changes“ und dem Verweis auf `MirroredSchemaSnapshotTests`.
- [x] **AC-9 [Gerät, offene Grenze, kein Gate]:** Feedback oder Todo exportiert mit TestFlight-Build auf Hennings Gerät ohne Fehler. AM GERÄT NICHT BELEGT, offene Grenze, PO-Ausnahme 2026-10-18 (Gerätetest nur auf sein Wort, bleibt in #155 offen), Haken nur fürs Gate, nicht erfüllt; läuft nur nach „jetzt ist ein Test möglich“.
- [x] **AC-10 [Test]:** Bestandsunit-Tests `SchemaCloudKitCompatibilityTests`, `ExistingDataSurvivesCloudEnableTests` und `SharedModelContainerExtensionDetectionTests` bleiben grün; der Diff zeigt keine Änderung an `SmartCart/`, `SmartCartWidgets/` und `RestockShareExtension/`.

## Dialog

### Runde 1
**Adversary:** Eigener Testlauf (run-snapshot-tests.sh, Ausgabe adversary-test-output.txt): 17 Tests, 0 Fehlschläge, 0 übersprungen, exit=0. Angriff auf AC-1: Ist die Gegenprobe echt, ist die Datei wiederhergestellt? AC-2: Nennt die rote Meldung beide Typen? AC-3/4: Fehlen die Typen im Vorher-Export, ist der Diff sauber, passen Feldtypen zum Muster?
**Implementierer:** AC-1: t1-gegenprobe-output.txt Z. 146-157 T1 rot (3 Tests, 1 Fehler) nach Entfernen von „priority“; test-green-output.txt Z. 129 T1 grün; Testdatei im Status unverändert, also wiederhergestellt. AC-2: test-red-output.txt Z. 2654/2657 nennt CD_FeedbackItem (context, createdAt, id, isResolved, priority, text) und CD_TodoItem (createdAt, id, isCompleted, notes, title); grün in test-green-output.txt Z. 131/133. AC-3: 0 Treffer für CD_Feedback/CD_Todo in private-schema-vorher.ckdb. AC-4: development-diff.txt zeigt nur die zwei Blöcke; validate-schema „Schema is valid“; Export gleich Importdatei. Typen (String/UUID STRING, Bool INT64, Date TIMESTAMP) stimmen mit CD_Store überein. Bestätigt.

### Runde 2
**Adversary:** Edge Cases. (a) Beziehungen CD_store (ShoppingItem) und CD_item (PurchaseRecord) stehen im Export, T1/T2 prüfen sie nicht (entity.attributes ohne Relationships). (b) T2-Blockabgrenzung: recordTypeBlock sucht „RECORD TYPE CD_X (“ bis zum ersten „);“, Feldregex mit Lookaround; keine Präfixkollision, keine Treffer in fremden Blöcken. (c) #filePath auf CI: ci.yml baut und testet im selben Job mit xcodebuild test (Z. 65, 172), Quelle dort lesbar; bräche nur bei build-for-testing mit Ausführung auf anderem Rechner. (d) T2 prüft nur Feldnamen, keine Typen. (e) AC-5: keine wörtliche Dashboard-Vorschau; AC-6: kein cktool-Protokoll des Production-Exports, Datei byteidentisch mit aktuell.ckdb. (f) AC-7: remove-token.txt enthält nur die Gegenprobe-Zeile. Tokenwert-Suche (Muster 32+ Zeichen base64/hex) in Artefakten und docs/cloudkit: nur xcodebuild-Pfade, kein Tokenwert.
**Implementierer:** (a) Relationship-Felder sind im Export vorhanden; für FeedbackItem/TodoItem irrelevant, Lücke nur bei künftigen Beziehungen (F001). (c) Kein Befund. (d) Typen manuell gegen CD_Store geprüft, korrekt (F004). (e) Production-Export ist vollständig und identisch mit Development, was einen erfolgten Deploy stark stützt (Production hatte laut Spec vorher nur drei CD_-Typen); die Vorschau bleibt unbelegt, AC-5 nur teilweise. (f) Gegenprobe „No management token found“ belegt das Ergebnis; Dashboard-Eintrag muss der PO löschen. AC-8: Abschnitt docs/testflight-setup.md Z. 49-95 enthält alle Begriffe. AC-10: Diff gegen c924a12 für die drei Verzeichnisse leer; Bestandstests im Adversary-Lauf grün. AC-9: am Gerät nicht belegt, kein Gate.

## Findings und Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: RestockTests/MirroredSchemaSnapshotTests.swift:48
  Evidence: T1 vergleicht Schema(versionedSchema: SchemaV1.self) mit fester Liste (Z. 17-36); Gegenprobe rot, Normallauf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: RestockTests/MirroredSchemaSnapshotTests.swift:66
  Evidence: T2/T3 rot vor Import mit Nennung beider Typen, grün danach; T3 prüft CD_notes (Z. 73-78).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/cloudkit/private-schema-vorher.ckdb:3
  Evidence: Vorher-Export ohne CD_FeedbackItem und CD_TodoItem.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/cloudkit/private-schema-aktuell.ckdb:3
  Evidence: CD_FeedbackItem (Z. 3) und CD_TodoItem (Z. 114) nach Muster CD_Store; development-diff.txt nur diese Blöcke; validate-schema gültig.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/artifacts/fix-155-icloud-produktionsschema/private-schema-production.ckdb:3
  Evidence: Production-Datei enthält alle fünf CD_-Typen, diff gegen aktuell.ckdb leer (production-vs-development-diff.txt, 0 Byte).
  Status: CONFIRMED (Inhalt; Herkunft siehe F002)

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/fix-155-icloud-produktionsschema/remove-token.txt:1
  Evidence: „No management token found“ nach Entfernung; kein Tokenwert in Repo oder Artefakten.
  Status: CONFIRMED (Schlüsselbund)

Confirmation:
  AC: AC-8
  Code reference: docs/testflight-setup.md:49
  Evidence: Neuer Abschnitt mit export-schema, validate-schema, import-schema, remove-token, Deploy Schema Changes und MirroredSchemaSnapshotTests.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Restock.xcodeproj/project.pbxproj:133
  Evidence: Testdatei in PBXBuildFile (133), PBXFileReference (351), Gruppe (698), Sources (1088) registriert; Eigenlauf 17 Tests, 0 Fehlschläge; keine Änderung in SmartCart/, SmartCartWidgets/, RestockShareExtension/.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: RestockTests/MirroredSchemaSnapshotTests.swift:40
  Description: T1/T2 lesen nur entity.attributes; Beziehungen (CD_store, CD_item) werden nicht geprüft.
  Spec requirement: AC-1 — Drift-Schutz der gespiegelten Modelle
  Conflict: Eine neue Beziehung löst weder T1 noch T2 aus; kein Verstoß gegen ein AC.
  Remediation: Optional entity.relationships in T1/T2 aufnehmen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/artifacts/fix-155-icloud-produktionsschema/private-schema-production.ckdb:1
  Description: Zum Production-Export gibt es kein cktool-Protokoll (Befehl, exit); cktool-development.txt deckt nur Development ab. Datei byteidentisch mit private-schema-aktuell.ckdb.
  Spec requirement: AC-5/AC-6 — Production-Export nach dem Deploy als Beleg
  Conflict: Echtheit des Exports aus Production nicht unabhängig nachprüfbar.
  Remediation: Production-Export mit Befehl und exit-Wert protokollieren (cktool-production.txt).

Finding:
  ID: F003
  Severity: LOW
  Category: security
  Code reference: docs/artifacts/fix-155-icloud-produktionsschema/remove-token.txt:1
  Description: Protokoll enthält nur die Gegenprobe, nicht die remove-token-Ausgabe; der Token-Eintrag im CloudKit-Dashboard besteht weiter.
  Spec requirement: AC-7 — Token entfernt
  Conflict: Credential serverseitig weiter gültig.
  Remediation: PO löscht den Token im Dashboard; remove-token-Ausgabe nachtragen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: RestockTests/MirroredSchemaSnapshotTests.swift:61
  Description: T2 prüft nur Feldnamen, keine Feldtypen.
  Spec requirement: AC-2
  Conflict: Ein falsch typisiertes Feld bliebe unbemerkt (hier manuell gegen das Muster geprüft, korrekt).
  Remediation: Optional Typ je Swift-Typ prüfen.

Finding:
  ID: F005
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/testflight-setup.md:95
  Description: AC-5: wörtliche Dashboard-Vorschau (nur diese zwei Typen) liegt nicht vor; Deploy nur indirekt über den Production-Export belegt. AC-9 am Gerät nicht belegt.
  Spec requirement: AC-5, AC-9
  Conflict: AC-5 nur teilweise belegt; AC-9 offene Grenze.
  Remediation: PO akzeptiert AC-5 ausdrücklich; AC-9 nach „jetzt ist ein Test möglich“.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**AMBIGUOUS**

Ambiguous: F005/F002 — AC-5 nur indirekt belegt (Production-Export vollständig, Vorschau-Diff und Exportprotokoll fehlen); AC-9 am Gerät nicht belegt.
Proven points: 8/10 abgehakt (AC-5 teilweise, AC-9 offen).
Tests: 17 passed, 0 failed, 0 übersprungen (adversary-test-output.txt)
Regressions: keine

## Geprüfte Dateien

- sha256:052e2b8e04332a6684dd1f873ffa8b0de52e3655890c668e65f052951882c845  Restock.xcodeproj/project.pbxproj
- sha256:98d538685cc4566d0d1e5c9578db29994c3e91a7671bfd8134cc09aafa5980aa  RestockTests/MirroredSchemaSnapshotTests.swift
- sha256:c90e89d3601b28a31ed9dd4921ee074d42106df97252e4709ed5d0c6ce7ec07c  docs/artifacts/fix-155-icloud-produktionsschema/private-schema-production.ckdb
- sha256:b46a0892c962db6ac7ec6cfd9b13b9e701a510b93d04efd791411f664c40e726  docs/artifacts/fix-155-icloud-produktionsschema/remove-token.txt
- sha256:c90e89d3601b28a31ed9dd4921ee074d42106df97252e4709ed5d0c6ce7ec07c  docs/cloudkit/private-schema-aktuell.ckdb
- sha256:b01091bd69dc7a1871149dddc422342d44624b31602fa40cae9224f9bd0acb2f  docs/cloudkit/private-schema-vorher.ckdb
- sha256:4d387f5e1c718d91c5247d4445f55101f7e615c59201584f90b9ab9f192aa8d0  docs/testflight-setup.md

## Prüfbasis

- base: c924a1272e8ae2290631515fa2169f68cf9cfeb3
- blob:1bf91242288890044c3f927aca26b9ac6c1454c0  Restock.xcodeproj/project.pbxproj
- blob:9b657f2dde5518208d28ff2b25a46528f50159da  RestockTests/MirroredSchemaSnapshotTests.swift
- blob:f975b7000f68e8e2d3d582eadb467361baa1b00d  docs/artifacts/fix-155-icloud-produktionsschema/private-schema-production.ckdb
- blob:24c65ff8fb295154a9daa98a1207fef947fbe9cd  docs/artifacts/fix-155-icloud-produktionsschema/remove-token.txt
- blob:f975b7000f68e8e2d3d582eadb467361baa1b00d  docs/cloudkit/private-schema-aktuell.ckdb
- blob:15631191d3b65587ef74be17e90a6c07f0bffa63  docs/cloudkit/private-schema-vorher.ckdb
- blob:f69099325aa532daffde811b4fd5b51ec2fa4202  docs/testflight-setup.md

## Geprüfte Dateien

- sha256:052e2b8e04332a6684dd1f873ffa8b0de52e3655890c668e65f052951882c845  Restock.xcodeproj/project.pbxproj
- sha256:98d538685cc4566d0d1e5c9578db29994c3e91a7671bfd8134cc09aafa5980aa  RestockTests/MirroredSchemaSnapshotTests.swift
- sha256:c90e89d3601b28a31ed9dd4921ee074d42106df97252e4709ed5d0c6ce7ec07c  docs/artifacts/fix-155-icloud-produktionsschema/private-schema-production.ckdb
- sha256:b46a0892c962db6ac7ec6cfd9b13b9e701a510b93d04efd791411f664c40e726  docs/artifacts/fix-155-icloud-produktionsschema/remove-token.txt
- sha256:c90e89d3601b28a31ed9dd4921ee074d42106df97252e4709ed5d0c6ce7ec07c  docs/cloudkit/private-schema-aktuell.ckdb
- sha256:b01091bd69dc7a1871149dddc422342d44624b31602fa40cae9224f9bd0acb2f  docs/cloudkit/private-schema-vorher.ckdb
- sha256:4d387f5e1c718d91c5247d4445f55101f7e615c59201584f90b9ab9f192aa8d0  docs/testflight-setup.md

## Prüfbasis

- base: c924a1272e8ae2290631515fa2169f68cf9cfeb3
- blob:1bf91242288890044c3f927aca26b9ac6c1454c0  Restock.xcodeproj/project.pbxproj
- blob:9b657f2dde5518208d28ff2b25a46528f50159da  RestockTests/MirroredSchemaSnapshotTests.swift
- blob:f975b7000f68e8e2d3d582eadb467361baa1b00d  docs/artifacts/fix-155-icloud-produktionsschema/private-schema-production.ckdb
- blob:24c65ff8fb295154a9daa98a1207fef947fbe9cd  docs/artifacts/fix-155-icloud-produktionsschema/remove-token.txt
- blob:f975b7000f68e8e2d3d582eadb467361baa1b00d  docs/cloudkit/private-schema-aktuell.ckdb
- blob:15631191d3b65587ef74be17e90a6c07f0bffa63  docs/cloudkit/private-schema-vorher.ckdb
- blob:f69099325aa532daffde811b4fd5b51ec2fa4202  docs/testflight-setup.md
