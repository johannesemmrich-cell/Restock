# Adversary-Dialog — fix-4-share-extension-cloudkit (Issue #4)

**Datum:** 2026-09-20
**Spec:** `docs/specs/models/shared-model-container.md`
**Runden:** 3 (Circuit Breaker: max. 3 — ausgeschöpft)
**Endverdict:** **VERIFIED** — 13/13 Punkte bewiesen, F001–F004 geschlossen

---

## Checkliste (13 Punkte, aus der Spec geparst)

- [x] **1** — `make()` parameterlos, wertet `Bundle.main.bundleURL` aus. Beleg: `SharedModelContainer.swift:92-94`, vom Prüfer gelesen und bestätigt.
- [x] **2** — Container auf App-Gruppen-Store, CloudKit im App-Prozess, `.none` in Erweiterungen, sonst `nil`. Beleg: `SharedModelContainer.swift:72-84, 92-113` + `testMainAppStillPrefersTheCloudKitMirroredConfiguration`, `testAppExtensionNeverBuildsACloudKitConfiguration`.
- [x] **3** — Side effects insgesamt (Summe aus Punkt 4, 5, 6).
- [x] **4** — App-Prozess: Backup unverändert, Flag beim ersten Mal, Kopie unter `PreCloudBackup`. Beleg: `git diff` zeigt Funktionskörper unverändert.
- [x] **5** — Erweiterung: keine Sicherung, kein Flag-Verbrauch, kein CloudKit-Kontakt. Beleg: `testPreCloudBackupRunsOnlyInTheMainApp` **und ab Runde 3 auch auf Cross-App-Ebene** (3 eigene Läufe des Prüfers: Flag bleibt leer, 0 Sicherungskopien, nur der Extension-Prozess lief). Zuvor trug diesen Punkt allein der Unit-Test.
- [x] **6** — `lastFailureKey` wird bei Fehlschlägen weiter geschrieben. Beleg: `SharedModelContainer.swift:129`, Stufenbenennung in beiden Zweigen korrekt.
- [x] **7** — Kein Einfluss auf Schema, Store-Adressierung, Signatur, 8 Aufrufstellen. Beleg: `grep` über alle `.swift`-Dateien findet exakt 8 Aufrufstellen, alle laut `git diff` unverändert.
- [x] **8 (AC-1)** — App-Prozess → Erkennung `false`. Beleg: `testDetectionIsFalseForTheMainAppProcess`, `testDetectionIsFalseForAnAppBundlePath`.
- [x] **9 (AC-2)** — `.appex`-Pfad → Erkennung `true`. Beleg: `testDetectionIsTrueForTheShareExtensionBundlePath`, `testDetectionIsTrueForTheWidgetBundlePath`, `testDetectionIgnoresTrailingSlash`.
- [x] **10 (AC-3)** — App-Prozess bevorzugt CloudKit-Konfiguration. Beleg: `testMainAppStillPrefersTheCloudKitMirroredConfiguration`; `ModelConfiguration.cloudKitContainerIdentifier` ist im iOS-27-SDK lesbar, die Rückfallregel auf AC-5 greift nicht.
- [x] **11 (AC-4)** — Erweiterung: kein CloudKit-Versuch, kein Backup. Beleg: drei Unit-Tests + Laufzeitmessung (0 CloudKit-Logzeilen, genau ein lokaler Store in instrumentierten Extension-Läufen).
- [x] **12 (AC-5)** — Cross-App Fotos → Teilen → Restock: Erfolgsansicht, Nutzlast in der App-Gruppe, kein neuer Absturzbericht. Beleg: 6/6 eigene Läufe des Prüfers über Runde 2 und 3.
- [x] **13 (AC-6)** — Regression grün. Beleg: 140/140 `RestockTests`, vom Prüfer selbst ausgeführt.

Alle 13 Punkte bewiesen. Kein offener Punkt.

Status: CONFIRMED

---

### Runde 1 — Verdict AMBIGUOUS

Der Validator las Spec und Code, führte Unit- und Regressionstests **selbst** aus (12/12 grün)
und wiederholte den Cross-App-Lauf zweimal eigenständig: **1× grün, 1× rot**.

**Findings:**

| ID | Severity | Kategorie | Befund |
|----|----------|-----------|--------|
| F001 | HIGH | edge_case | Cross-App-Nachweis (AC-5) nicht reproduzierbar: 3 grün / 2 rot über alle bekannten Läufe (60 %). Ursache in beiden roten Läufen: ein System-Alert („Restock möchte dir Mitteilungen senden") unterbricht die Fotos-App-Navigation, der XCUITest-Runner startet neu, „Teilen an Restock" wird nie erreicht. |
| F002 | MEDIUM | anti_pattern | Das Skript löscht vor dem Lauf `pendingShareExtensionReceipt`, aber **nicht** `smartcart.preCloudBackupDone.v2`. Die Meldung „Sicherungsflag gesetzt: ja" ist damit nicht diesem Lauf zuzuordnen. |
| F003 | LOW | edge_case | Randfälle der Erkennung (`.APPEX`, `.appex` als mittlere Pfadkomponente) ungetestet — Code korrekt, aber ungeprüft. |

**Recherchierter Punkt (c), kein Finding:** Ist ein CloudKit-gespiegelter Store neben lokalen
Öffnungen desselben Stores zulässig? Recherche bestätigt: etabliertes Apple-Muster
(`NSPersistentStoreRemoteChangeNotification` existiert ausdrücklich für den Fall, dass eine
App-Erweiterung in einen gemeinsamen Store schreibt). Der historische Warnkommentar in
`SharedModelContainer.swift` bezog sich auf einen anderen Fall: **zwei** eigenständige
Spiegelungen gegen denselben Store. Kein Datenverlustrisiko in der gewählten Konstellation.

### Nachbesserung 1 (Developer, Testinfrastruktur — Produktivcode unberührt)

- **F001:** Vorlauf-Aufräumen im Skript (Fotos-App und Restock beenden, SpringBoard per
  `launchctl kickstart -k system/com.apple.SpringBoard` neu starten). Neue Methode
  `dismissSystemAlerts()` klickt Systemdialoge aktiv in SpringBoard weg — vor dem Start der
  Fotos-App, vor dem Mediathek-Register, in jeder Runde der Teilen-Auswahl und alle 2 s während
  der 90-s-Wartezeit. Interruption-Monitor bleibt als zweites Netz.
  *Anmerkung:* Der zunächst vorgeschlagene deterministische Weg über
  `xcrun simctl privacy … grant notifications` ist nicht gangbar — Xcode 27 kennt den Dienst
  `notifications` nicht (vom Validator eigenständig nachgeprüft).
- **F002:** Flag wird analog zur Nutzlast vor dem Lauf gelöscht, Vorher-/Nachher-Zustand wird ausgegeben.
- **F003:** `testDetectionIsCaseInsensitive`, `testDetectionIgnoresAppexInAnIntermediatePathComponent`.

Behauptetes Ergebnis: 14 Tests grün, 3 konsekutive Cross-App-Läufe grün.

---

### Runde 2 — Verdict AMBIGUOUS

Der Validator übernahm nichts, sondern maß selbst: `xcrun simctl privacy` nachgeprüft,
`RestockTests` komplett ausgeführt (**140/140 grün**), den Cross-App-Lauf **dreimal selbst**
gefahren (3/3 grün), dabei Runde 2 und 3 mit lückenlosem
`log stream --predicate 'process CONTAINS "Restock"'` mitgeschnitten.

**F001 und F003 bestätigt erledigt.** Dafür ein neuer, schärferer Befund:

| ID | Severity | Kategorie | Befund |
|----|----------|-----------|--------|
| F004 | HIGH | spec_violation | Der Ergebnisblock druckt „Gesetzt hat es der App-Prozess (die Haupt-App lief in diesem Lauf mit)" (`scripts/run-share-extension-uitest.sh:143`). **Widerlegt:** In 3 von 3 lückenlos protokollierten Läufen lief der Haupt-App-Prozess `com.johannesemmrich.Restock` **nie** — nur `RestockShareExtension` und `RestockUITests-Runner`. Trotzdem stand das Flag danach auf „ja". Die Zuordnung wird vom Skript nicht gemessen, sondern unterstellt. Damit war Checklistenpunkt 5 auf Cross-App-Ebene **nicht** belegt. |

Die Gegenhypothese („die Erweiterung verbraucht das Flag") konnte der Validator ebenfalls nicht
bestätigen: in den Extension-Prozessen **0** CloudKit-Zeilen und genau ein „Adding persistent
store". Ursache blieb offen.

### Messauftrag statt Fix (Analysis-First)

Der Orchestrator beauftragte **keine Korrektur, sondern eine Messung** entlang dreier Spuren:
(1) Filter-Lücke — `SmartCartWidgets` war vom Log-Filter nicht erfasst; (2) der schärfste Test —
liegen nach dem Lauf frische Dateien unter `PreCloudBackup`? (3) `cfprefsd`-Verdacht prüfen,
nicht vermuten, mit vorheriger Internetrecherche.

### Messergebnis

| Messung | Befund |
|---------|--------|
| **M1 — Sicherungsdateien** | `PreCloudBackup` existierte vor **und** nach jedem Lauf **nicht** (0 Dateien), obwohl `default.store` (327 680 Bytes) vorhanden ist. **Flag gesetzt + keine Sicherungsdatei = kein Backup-Durchlauf.** |
| **M2 — Sekundengenaue Abtastung** | `21:54:04` Flag nein / `21:55:10` Flag JA — exakt beim Neuschreiben der Plist, während die Erweiterung ihre Nutzlast in dieselbe Domain legt. Ohne jede Sicherungsdatei. |
| **M3 — Prozesse, Filter-Lücke geschlossen** | Filter `process CONTAINS[c] "Restock" OR process CONTAINS[c] "SmartCart"`: **1388 Zeilen `RestockShareExtension`, 0 Zeilen `Restock`, 0 Zeilen `SmartCartWidgets`.** Das Widget ist damit als Verursacher **gemessen** ausgeschlossen. |
| **M4 — Ursache** | Die bisherige Cache-Leerung war wirkungslos: `xcrun simctl spawn <dev> killall -9 cfprefsd` scheitert (`NSPOSIXErrorDomain code=2`) — **es gibt kein `killall` im Simulator**, und `>/dev/null 2>&1` verschluckte den Fehler. cfprefsd-PID vor/nach identisch (42170). Funktionierend: `launchctl kill 9 system/com.apple.cfprefsd.xpc.daemon`. |
| **M5 — Gegenprobe** | Mit korrekt neu gestartetem cfprefsd bleibt das Flag über den ganzen Lauf leer: `nach dem Lauf: nein`, `Sicherungskopien 0/0`, Nutzlast ja, 0 Absturzberichte, GRÜN. |

**Quellen zur Mechanik:** [stackoverflow.com/q/19234665](https://stackoverflow.com/q/19234665)
(Defaults liegen seit OS X 10.8 im Speicher von cfprefsd, werden verzögert geschrieben, direktes
Editieren der Plist wird überschrieben), [stackoverflow.com/q/19303958](https://stackoverflow.com/q/19303958)
(Abhilfe: cfprefsd neu starten).

**Befund:** Messartefakt der Testumgebung, **kein Defekt im Produktivcode.** Gesetzt wurde das Flag
zuletzt bei einem echten Haupt-App-Start früher am Tag; im Lauf schrieb cfprefsd diesen
zwischengespeicherten Wert lediglich zurück.

### Nachbesserung 2 (nur `scripts/run-share-extension-uitest.sh`, +91/-2)

- cfprefsd-Neustart über `launchctl kill 9 …`; schlägt er fehl, **warnt** das Skript, statt den
  Fehler zu verschlucken. Ursache und Quellen stehen als Kommentar daneben.
- Der Ergebnisblock **misst** statt zu behaupten: Flag vorher/nachher, Sicherungskopien vorher/
  nachher mit Zeitstempel, tatsächlich gelaufene Prozesse (Filter erfasst auch `SmartCartWidgets`).
- Die unbelegte Kausalzeile 143 ist **ersatzlos entfernt**.

---

### Runde 3 — Verdict VERIFIED

Der Orchestrator legte der Prüferin ausdrücklich den schwächsten Punkt der Erklärung vor:
*Wenn das Flag nur ein zurückgeflushter Altwert war — warum blieb es dann im Leerlauf-Experiment
aus Runde 2 (60 s ohne Testlauf) leer?*

**Die Lücke ist geschlossen, widerspruchsfrei:** `ReceiptShareHandoff.store()`
(`SmartCart/Services/ReceiptShareHandoff.swift:9,14`) schreibt die Bon-Nutzlast über **dieselbe**
App-Gruppen-Suite, in der auch das Flag liegt. cfprefsd flusht seinen Domain-Cache erst bei einem
Schreibzugriff auf diese Domain; `PlistBuddy` umgeht cfprefsd und invalidiert dessen Cache nicht.

- **Leerlauf:** kein Schreibzugriff → kein Flush → Flag bleibt leer. ✓
- **Echter Lauf:** die Extension schreibt legitim die Nutzlast in dieselbe Suite → genau dieser
  Schreibzugriff flusht den kompletten stale Domain-Cache zurück, inklusive des nie
  invalidierten „true". ✓

Beide Beobachtungen ohne Zusatzannahme erklärt.

**Eigene Verifikation der Prüferin:**

- `killall`-Befund selbst reproduziert (exit code 2). Ihre eigene Anmerkung: *„Ich selbst bin in
  Runde 2 exakt auf denselben (wirkungslosen) Befehl hereingefallen, ohne es zu bemerken."*
  `launchctl kill` funktioniert: PID `30981` → respawnt als `36013`.
- **Drei eigene Läufe** mit dem korrigierten Skript (nicht nur die geforderten zwei):

| Lauf | Flag vorher | Flag nachher | Sicherungskopien vor/nach | Prozesse (gemessen) | Nutzlast | neue Absturzberichte | Status |
|------|-------------|--------------|---------------------------|---------------------|----------|----------------------|--------|
| 1 | nicht gesetzt | **nein** | 0 / 0 | `RestockShareExtension` | ja | 0 | GRÜN |
| 2 | nicht gesetzt | **nein** | 0 / 0 | `RestockShareExtension` | ja | 0 | GRÜN |
| 3 | nicht gesetzt | **nein** | 0 / 0 | `RestockShareExtension` | ja | 0 | GRÜN |

  Zusätzlich direkt am Dateisystem gegengeprüft, nicht nur über das Skript.
- **Checklistenpunkt 5 trägt jetzt auch auf Cross-App-Ebene** — zuvor trug ihn ausschließlich der
  Unit-Test `testPreCloudBackupRunsOnlyInTheMainApp`.
- **Scope bestätigt:** nur `scripts/run-share-extension-uitest.sh` mit neuem Zeitstempel (22:03);
  `SmartCart/Models/SharedModelContainer.swift` unverändert seit Runde 2 (mtime 20:17:46).

---

## Verdict

**VERIFIED**

F001 bis F004 sind geschlossen.

| Kennzahl | Ergebnis |
|----------|----------|
| Tests | 140 bestanden, 0 fehlgeschlagen (`RestockTests`) |
| Cross-App-Läufe des Prüfers | 6/6 grün über Runde 2 + 3 |
| Neue Absturzberichte | 0 in sämtlichen Läufen |
| Checkliste | 13/13 verifiziert |
| Scope | Produktivcode = 1 Datei, seit Runde 2 unverändert |

**Artefakte:**
- `docs/artifacts/fix-4-share-extension-cloudkit/test-green-output.txt` — GREEN-Lauf, Nachbesserung
  F001/F002/F003 mit 3 konsekutiven Cross-App-Läufen, Messprotokoll F004 mit Verifikationslauf
- `docs/artifacts/fix-4-share-extension-cloudkit/test-red-unit.txt`, `test-red-crossapp.txt`,
  `crash-red-RestockShareExtension-2026-09-20-192505.ips` — RED-Vergleichsbasis
- Eigene Läufe der Prüferin: `/tmp/adversary_round3_output.txt`, `_run2.txt`, `_run3.txt`

## Lehren für den Workflow

1. **Ein unterdrückter Fehler kostete zwei Prüfrunden.** `>/dev/null 2>&1` verschluckte, dass
   `killall` im Simulator nicht existiert — beide Seiten, Entwickler und Prüferin, fielen darauf
   herein. Aufräum-Befehle in Testskripten gehören nicht stummgeschaltet.
2. **Ein Nebenprodukt der Wirkung schlägt jede Zustandsabfrage.** Die Frage „wer hat das Flag
   gesetzt" war über Prozess-Logs nicht entscheidbar, über die Existenz der Sicherungsdateien
   sofort: Wirkung ohne Spur = keine Wirkung.
3. **Ein Skript darf nur drucken, was es gemessen hat.** Die Kausalzeile 143 war plausibel und
   falsch — und hätte ohne die Gegenprüfung einen vermeintlichen Beweis geliefert.
