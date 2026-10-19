---
entity_id: private-cloudkit-schema
type: bugfix
created: 2026-10-18
updated: 2026-10-18
status: draft
workflow: fix-155-icloud-produktionsschema
tags: [bugfix, cloudkit, swiftdata, schema, testflight]
---

# Privates CloudKit-Schema vollständig (FeedbackItem/TodoItem) + Drift-Test + Doku (Issue #155)

## Approval

- [ ] Approved

PO-Entscheidung bereits getroffen (2026-10-18, siehe `docs/context/fix-155-icloud-produktionsschema.md`,
„Open Questions“): Feedback und Todos bleiben in iCloud (Weg A). Weg B (eigene lokale Konfiguration)
entfällt. Doppelungen beim ersten Hochladen und ein Beobachter für den Abgleich sind aus diesem Ziel
ausgenommen und liegen in Issue #156.

## Purpose

Der private iCloud-Abgleich der eigenen Läden und Listen spiegelt alle fünf SwiftData-Modelle. In
CloudKit-Production fehlen aber noch die Typen `CD_FeedbackItem` und `CD_TodoItem` (am 2026-10-18
wurden nur `CD_Store`, `CD_ShoppingItem`, `CD_PurchaseRecord` deployt). Ein einziger abgelehnter Record
lässt den ganzen Export-Durchgang scheitern und schaltet den Abgleich für die Sitzung ab; der
Entwicklermodus ist auch in TestFlight freischaltbar, also kann schon ein Feedback oder Todo den Abgleich
von Läden und Artikeln blockieren. Diese Spec ergänzt beide Typen im Schema (ohne App-Code), sichert per
Test, dass Modelle und veröffentlichtes Schema nicht mehr unbemerkt auseinanderlaufen, und dokumentiert
den Schritt für die private Datenbank.

Es liegt keine Verschlechterung vor: Der eigene Abgleich hat in Production nie funktioniert (Deploy-Diff
vom 2026-10-18; bis Build 31 fehlten alle `CD_`-Typen).

## Source

- **File:** `SmartCart/Services/SchemaVersions.swift` (`enum SchemaV1`, `models`) und
  `SmartCart/Models/SharedModelContainer.swift` (`storeConfigurations(forBundleAt:)`, unverändert)
- **Identifier:** `SchemaV1.models` = Store, ShoppingItem, PurchaseRecord, FeedbackItem, TodoItem;
  gespiegelt wird jede Entität als Record-Typ `CD_<Entität>` mit Feldern `CD_<Attribut>`.
- Felder der zwei fehlenden Typen (aus den Modellen gelesen):
  - `FeedbackItem`: `id` (UUID), `context` (String), `text` (String), `priority` (String),
    `isResolved` (Bool), `createdAt` (Date)
  - `TodoItem`: `id` (UUID), `title` (String), `notes` (String?, optional), `isCompleted` (Bool),
    `createdAt` (Date)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CloudKit-Container `iCloud.com.johannesemmrich.SmartCart` (Team `XK87E2B3VR`) | external | Ziel des Schemas; Development und Production |
| `cktool` (Xcode) | tool | `export-schema`, `validate-schema`, `import-schema` nur in Development |
| Management-Token | credential | Für `cktool`; im Schlüsselbund, nach der Arbeit mit `remove-token --type management` entfernen, Wert nie anzeigen |
| CloudKit-Dashboard „Deploy Schema Changes…“ | tool | Einziger Weg nach Production; `cktool` kann das nicht |
| `SchemaV1` (`SchemaVersions.swift`) | module | Quelle der Entitäten und Attribute für den Drift-Test |
| `FeedbackItem`, `TodoItem` (`SmartCart/Models/`) | models | Feldlisten der zu ergänzenden Typen |
| `RestockTests/SharedStoreSchemaTests.swift` (`testT8_`) | test | Vorbild für Drift-Test und Fehlermeldung mit Verweis auf `docs/testflight-setup.md` |
| `docs/testflight-setup.md`, `docs/specs/fast/doc-126-cktool-schema.md` | docs | Bestehender cktool-Ablauf für `SharedStore`, wird um die private DB ergänzt |
| Hennings Geräte | external | Nur für AC-9; nur nach seinem wörtlichen „jetzt ist ein Test möglich“ |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| CloudKit-Schema des Containers (kein Repo-Code) | MODIFY | `CD_FeedbackItem`, `CD_TodoItem` in Development per `cktool import-schema`, danach Production per Dashboard |
| `docs/cloudkit/private-schema-vorher.ckdb` | CREATE | Export Development vor der Änderung (Ist-Zustand, Beleg, wird nie geändert) |
| `docs/cloudkit/private-schema-aktuell.ckdb` | CREATE | Zunächst Kopie von „vorher“ (RED), danach Export Development nach dem Import (GREEN); Grundlage von Test T2 |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | CREATE | Drift-Test T1 (Modelle gegen feste Liste) und Snapshot-Test T2 (Modelle gegen `private-schema-aktuell.ckdb`) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Testdatei in den vier Abschnitten registrieren |
| `docs/testflight-setup.md` | MODIFY | Neuer Abschnitt „Privater iCloud-Abgleich: Typen vor jedem Upload in Production“ |

Der Production-Export (nach Deploy) liegt als Beleg unter `docs/artifacts/fix-155-icloud-produktionsschema/`
(Artefakt, kein Produktcode, nicht mitgezählt).

### Estimated Changes

- Repo-Dateien (ohne .ckdb-Daten und Artefakte): 4
- LoC: +140/−0 (Test ca. +90, Doku ca. +40, pbxproj ca. +8; .ckdb-Dateien sind Daten und nicht mitgezählt)
- Im Rahmen der Scoping-Limits (4–5 Dateien, ±250 LoC). Kein Produktcode wird geändert.

## Implementation Details

**1. Schema (Werkzeugweg, Weg A).**
Ablauf wie in `docs/testflight-setup.md` für `SharedStore`: `cktool export-schema` (Development) nach
`docs/cloudkit/private-schema-vorher.ckdb` und Kopie nach `private-schema-aktuell.ckdb`. In der Arbeitsdatei
`CD_FeedbackItem` und `CD_TodoItem` ergänzen, mit allen Feldern aus „Source“ als `CD_<Attribut>`; Systemfelder,
Typen (UUID wird wie bei `CD_Store.CD_id` übernommen), Indizes und Rollen exakt nach dem Muster der
exportierten `CD_Store`-Definition. Dann `validate-schema`, `import-schema`, erneuter Export und `diff`: der
Unterschied zu „vorher“ darf nur die zwei Typen zeigen. Der neue Export ersetzt `private-schema-aktuell.ckdb`.
Danach Dashboard „Deploy Schema Changes…“ (Container-ID prüfen, im Dashboard öffnet sich zuerst ein fremder
Container): der Diff darf nur die zwei Typen enthalten. Anschließend Production und Development exportieren
und vergleichen. Management-Token entfernen.

**2. Test `MirroredSchemaSnapshotTests`.**
- T1 (feste Liste): Aus `Schema(versionedSchema: SchemaV1.self)` die Entitäten und deren Attributnamen lesen
  (`schema.entities`, je `entity.name` und `entity.attributes.map(\.name)`) und mit einer festen Liste im Test
  vergleichen (fünf Entitäten, alle Felder, die Liste wird aus den Modelldateien übernommen). Fehlermeldung
  nach dem Muster von `testT8_`: „Gespiegelte Modelle geändert: CloudKit-Schema (Development und Production)
  vor dem TestFlight-Upload ergänzen und deployen (docs/testflight-setup.md)“.
- T2 (Snapshot): Für jede Entität muss `docs/cloudkit/private-schema-aktuell.ckdb` den Record-Typ
  `CD_<Entität>` und je Attribut das Feld `CD_<Attribut>` enthalten. Die Datei wird über `#filePath`
  relativ zur Testdatei gelesen (Unit-Tests laufen auf dem Mac, das Repo ist im Simulator lesbar). Fehlt
  etwas, nennt die Meldung die fehlenden Typen/Felder und verweist auf den Deploy-Schritt.
- T2 prüft nur Development-Stand im Repo. Dass derselbe Stand in Production liegt, belegt der
  Werkzeugbeleg (AC-6), nicht der Test.

**3. Rote Testphase.**
- RED: Die Testdatei wird zuerst angelegt, `private-schema-aktuell.ckdb` ist noch die Kopie des Ist-Zustands
  (ohne `CD_FeedbackItem`/`CD_TodoItem`). T2 schlägt fehl und nennt genau diese zwei Typen mit allen Feldern.
  T1 ist von Anfang an grün (Regressionsschutz der Modellliste). RED-Gegenprobe T1: Ein Attribut aus der
  festen Liste entfernen (nur lokal, nicht committen) muss T1 fehlschlagen lassen.
- GREEN: Nach dem Import ersetzt der Development-Export `private-schema-aktuell.ckdb`; T1 und T2 bestehen.
- Beweis der Wirksamkeit: Ein neues Attribut an einem Modell ohne Schema-Ergänzung lässt T1 und/oder T2
  scheitern (einmal probehalber ausgeführt und im Protokoll festgehalten).

**4. Doku.** `docs/testflight-setup.md` erhält einen Abschnitt für die private Datenbank: Was gespiegelt
wird (Zone `com.apple.coredata.cloudkit.zone`, Typen `CD_<Entität>`), wann das Schema vor einem Upload
ergänzt werden muss (neues Modell, neues Attribut), Rezept (cktool, Deploy, Gegenprobe), Fallen: in
Production legt CloudKit nie Typen an (CKError 12), ein abgelehnter Record scheitert den ganzen Export,
Felder mit `nil` erscheinen im Just-in-time-Schema der Development nicht (daher Handschrift der .ckdb
statt Debug-Lauf), Verweis auf `MirroredSchemaSnapshotTests`.

**Risiken.**
- Unklar: ob `Schema.Entity.attributes` in der eingesetzten SDK-Version (Xcode 27.1) die Attributnamen
  liefert und wie sich Relationships (`Store` ↔ `ShoppingItem`) darstellen. Vor der Implementierung in
  einem Wegwerf-Test prüfen. Fällt `attributes` aus, nimmt T1 `storedProperties` und trennt Relationships ab.
  Die Entscheidung, ob Relationship-Felder als `CD_<name>` im Schema stehen, folgt aus dem vorhandenen
  `CD_ShoppingItem`-Export, nicht aus Annahmen.
- Handgeschriebene .ckdb könnte von dem abweichen, was NSPersistentCloudKitContainer erwartet (Typ der UUID,
  Systemfelder). Gegenmittel: Muster `CD_Store`, Gegenprobe per Export.
- Production erlaubt keine Löschungen; ein falsch deployter Typ bleibt. Deshalb Diff vor dem Deploy prüfen.

## Alternativen

- **A1, Debug-Lauf auf einem Gerät mit iCloud:** Typen entstehen just-in-time, kein Handschreiben. Verworfen:
  braucht Hennings Gerät (nur auf sein Wort) und `TodoItem.notes` müsste gefüllt sein, sonst fehlt das
  Feld. Gekippt würde nichts; es wäre nur ein anderer Weg zum selben Schema.
- **A2, `initializeCloudKitSchema` über parallelen Core-Data-Stack:** Verworfen: doppelter Mirror, mehr Code,
  verstößt gegen die Kopfwarnung in `SharedModelContainer.swift`.
- **B, Dev-Modelle aus der Spiegelung nehmen** (eigene lokale `ModelConfiguration` mit Teil-Schema):
  Verworfen durch PO-Wort 2026-10-18. Gekippt würde die Entscheidung „ein Schema, ein Store für alle
  Prozesse“ (`docs/specs/models/shared-model-container.md`); Store-Adressierung müsste in allen Prozessen
  gleichzeitig geändert und die Bestandsdaten in eine zweite Datei migriert werden (Vorfall #4).
- **Ohne Test, nur Doku:** Verworfen: ein vergessener Deploy wie jetzt bliebe bis zum nächsten Gerätefehler
  unsichtbar. Der Test ist bewusst klein.

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1: GIVEN `Schema(versionedSchema: SchemaV1.self)` WHEN Entitäten und Attributnamen gelesen werden
  THEN entsprechen sie genau der festen Liste (fünf Entitäten, alle Felder); bei Abweichung nennt die
  Meldung den Deploy-Schritt.
- [ ] T2: GIVEN `docs/cloudkit/private-schema-aktuell.ckdb` WHEN für jede Entität `CD_<Entität>` und
  `CD_<Attribut>` gesucht werden THEN sind alle vorhanden. RED zu Beginn: `CD_FeedbackItem` und
  `CD_TodoItem` fehlen. GREEN nach dem Import.
- [ ] T3: GIVEN die Modelle `FeedbackItem` und `TodoItem` WHEN T2 ausgewertet wird THEN deckt die Prüfung
  auch das optionale Feld `CD_notes` ab (Falle „nil-Felder erscheinen nicht“).

Hinweis: Alle drei Tests liegen in `MirroredSchemaSnapshotTests`; der Lauf nutzt den Unit-Testweg mit
`Restock-Validate` und die Schwere-Läufe-Sperren aus `CLAUDE.md`.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test oder ein Werkzeug-Artefakt belegt; AC-9 (Gerät) ist ausdrücklich als offene Grenze genannt
- [ ] Der Production-Export des privaten Schemas enthält alle fünf gespiegelten Typen mit denselben Feldern wie Development (AC-6)
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün)

## Acceptance Criteria

Belegart: **[Test]** automatisiert, **[Beleg]** Werkzeug-Artefakt (cktool-Export, Diff), **[Gerät]** erst nach
Hennings wörtlichem „jetzt ist ein Test möglich“, offene Grenze und kein Gate.

- **AC-1 [Test]:** `MirroredSchemaSnapshotTests` T1 ist grün und schlägt bei Entfernen eines Attributs aus der
  festen Liste nachweislich fehl (RED-Gegenprobe im Protokoll).
- **AC-2 [Test]:** T2 war vor dem Schema-Import rot (Meldung nennt `CD_FeedbackItem` und `CD_TodoItem`) und ist
  nach dem Import grün (beide Läufe im Protokoll).
- **AC-3 [Beleg]:** `docs/cloudkit/private-schema-vorher.ckdb` zeigt den Ist-Zustand ohne `CD_FeedbackItem`
  und `CD_TodoItem`.
- **AC-4 [Beleg]:** Nach `import-schema` zeigt `diff` zwischen „vorher“ und neuem Development-Export ausschließlich
  `CD_FeedbackItem` (6 Felder plus Systemfelder) und `CD_TodoItem` (5 Felder plus Systemfelder), `validate-schema`
  meldet keinen Fehler.
- **AC-5 [Beleg]:** Das Dashboard zeigt vor „Deploy Schema Changes…“ nur diese zwei Typen im Diff; der Deploy ist
  durchgeführt.
- **AC-6 [Beleg]:** Der Production-Export nach dem Deploy enthält `CD_Store`, `CD_ShoppingItem`,
  `CD_PurchaseRecord`, `CD_FeedbackItem`, `CD_TodoItem` mit denselben Feldern wie Development
  (`diff` ohne Unterschied bei den `CD_`-Typen), abgelegt unter `docs/artifacts/fix-155-icloud-produktionsschema/`.
- **AC-7 [Beleg]:** Das Management-Token ist nach der Arbeit entfernt (`remove-token --type management`,
  Ausgabe im Protokoll, kein Tokenwert in Repo oder Protokoll).
- **AC-8 [Test/Beleg]:** `docs/testflight-setup.md` enthält den neuen Abschnitt mit den Befehlen `export-schema`,
  `validate-schema`, `import-schema`, `remove-token`, dem Hinweis „Deploy Schema Changes“ und dem Verweis auf
  `MirroredSchemaSnapshotTests` (`grep` auf alle Begriffe findet je mindestens eine Stelle im neuen Abschnitt).
- **AC-9 [Gerät, offene Grenze, kein Gate]:** Mit TestFlight-Build auf Hennings Gerät exportiert ein
  Feedback oder Todo ohne Fehler und kommt auf einem zweiten Gerät oder in der CloudKit-Konsole an. Läuft nur
  nach „jetzt ist ein Test möglich“; die App ist vorher gebaut, installiert und startklar. Bis dahin bleibt der
  Punkt in Issue #155 offen und ist in jedem Bericht als „am Gerät nicht belegt“ genannt.
- **AC-10 [Test]:** Bestandsunit-Tests `SchemaCloudKitCompatibilityTests`, `ExistingDataSurvivesCloudEnableTests`
  und `SharedModelContainerExtensionDetectionTests` bleiben grün; `git diff` zeigt keine Änderung an
  `SmartCart/`, `SmartCartWidgets/` und `RestockShareExtension/`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es ändert sich weder Architektur noch Store-Adressierung; das bestehende Muster „ein Schema,
  ein Store für alle Prozesse“ bleibt. Die Entscheidung gegen Weg B (Dev-Modelle lokal halten) ist im
  Alternativen-Abschnitt und im PO-Wort vom 2026-10-18 festgehalten.

## Offene Grenzen

- Development ist nicht Production: Im Simulator legt CloudKit fehlende Typen just-in-time an, der Fehler
  „Cannot create new type … in production schema“ lässt sich lokal nicht nachstellen. Der fehlerhafte
  Ausgangszustand ist nur durch den Deploy-Diff vom 2026-10-18 und den Vorher-Export belegt.
- Dass der Export in Production wirklich läuft, ist nur am Gerät mit TestFlight und Hennings Konto belegbar
  (AC-9); der Production-Export (AC-6) belegt das Schema, nicht den Datentransport.
- Records in der privaten Datenbank zählen geht nur mit Benutzer-Token; ohne Gerät bleibt nur der
  Schema-Beleg.
- Der Production-Deploy läuft über das Dashboard (Henning über Claude Desktop oder Browser-Steuerung) und ist
  nicht automatisierbar.
- T2 prüft den Development-Stand im Repo, nicht Production; ein vergessener Deploy fällt durch T2 nicht auf.
  Er ist nur durch AC-5/AC-6 und die Doku abgesichert.
- Nicht Teil dieses Ziels, Issue #156: Doppelungen beim ersten Hochladen von mehreren Geräten
  (`OnboardingView.finishOnboarding()` und `SettingsView.seedStores` legen Standardläden je Gerät ohne
  Namensprüfung an) sowie ein Beobachter für `NSPersistentCloudKitContainer.eventChangedNotification` mit
  Diagnosezeile. Ein gescheiterter Export bleibt bis dahin in der App unsichtbar.

## Changelog

- 2026-10-18: Initial spec created
