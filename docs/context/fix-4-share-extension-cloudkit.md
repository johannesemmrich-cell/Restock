# Context: fix-4-share-extension-cloudkit (Issue #4)

Phase 1 (Context Generation), Stand 2026-09-20. Track: **Full Process** (Intake-Summe 3,
Blast Radius High). Workflow-Typ im State ist `feature`, NICHT `bug` — der Typ `bug` ist im
Werkzeug ein Schnellverfahren, das direkt zu `phase6_implement` springt und Spec + TDD-RED
als erledigt markiert. Genau das hat Henning im Issue-Kommentar ausgeschlossen.

## Request Summary

Der Bon-Import per „Teilen" schlägt fehl, weil die Share Extension ~4,5 s nach Start abstürzt:
`SharedModelContainer.make()` öffnet den Store zuerst mit CloudKit-Spiegelung, die Extension hat
aber kein iCloud-Entitlement, und CloudKit bricht den Prozess per Assertion (SIGTRAP) ab.
Freigegebener Fix: `make()` erkennt App-Erweiterungen und überspringt dort den CloudKit-Versuch.

Vollständige Ursachenanalyse, Crash-Report, Quellen und verworfene Alternativen stehen in
**GitHub-Issue #4** (Beschreibung + Kommentar „Freigegebener Plan") — hier nicht dupliziert.

## Related Files

| Datei | Relevanz |
|-------|----------|
| `SmartCart/Models/SharedModelContainer.swift` | **Die einzige zu ändernde Produktivdatei.** `make()` Z. 41-73: Cloud-Versuch → Fallback lokal. Der Doku-Kommentar Z. 29-36 verbietet ausdrücklich „per-process branching" und muss mit zurückgenommen werden. |
| `RestockShareExtension/ShareViewController.swift` | Ruft `make()` in `process()` (Z. 154) nach OCR + Parsing auf. Ab dort läuft der Wettlauf gegen den Absturz: `ReceiptShareHandoff.store(payload)` (Z. 197) und die Erfolgsansicht (Z. 200) liegen dahinter. |
| `RestockShareExtension/RestockShareExtension.entitlements` | Enthält **nur** die App-Gruppe, kein `com.apple.developer.icloud-services`. Ursache des Absturzes. Bleibt bewusst so. |
| `SmartCartWidgets/SmartCartWidgets.entitlements` | Ebenfalls nur App-Gruppe → gleiche Absturzlage, bisher nicht nachgestellt. |
| `SmartCart/SmartCart.entitlements` | Haupt-App hat `icloud-services` + Container `iCloud.com.johannesemmrich.SmartCart`. Nur hier darf der Cloud-Pfad laufen. |
| `SmartCart/SmartCartApp.swift` (Z. 41-72) | Erster Aufrufer; hat hinter `make()` noch zwei Notfallstufen (Store-Dateien löschen, In-Memory). Hier darf sich nichts ändern. |
| `SmartCartWidgets/ShoppingListWidget.swift` | Zweiter Extension-Aufrufer (`StoreEntityQuery`, Timeline-Reload). |
| `SmartCart/Intents/AddItemIntent.swift` | Dritter Aufrufer. **Kein eigenes AppIntents-Extension-Target im Projekt** → läuft im App-Prozess, behält also das iCloud-Entitlement. Die Erkennung darf ihn nicht miterfassen. |
| `SmartCart/Services/ReceiptShareHandoff.swift` | Nutzlast-Übergabe an die App über App-Gruppen-`UserDefaults`. Der Nachweis „Nutzlast liegt in der App-Gruppe" hängt hier (`pendingShareExtensionReceipt`). |
| `RestockTests/SchemaCloudKitCompatibilityTests.swift` | Bestehendes Muster: prüft, dass `.private(...)` fürs aktuelle Schema **nicht** scheitert. Läuft im App-Prozess und muss grün bleiben. |
| `RestockTests/ExistingDataSurvivesCloudEnableTests.swift` | Bestehendes Muster für den Übergang lokal → Cloud gegen dieselbe Datei. |
| `RestockUITests/RestockUITests.swift` | Einziger UI-Test-Bestand (4 Tests, alle nur Haupt-App). **Kein Cross-App-Test vorhanden** — der Fotos→Teilen-Ablauf muss in Phase 4 neu gebaut werden. |

## Existing Patterns

- **Ein gemeinsamer Store-Öffner für alle Prozesse.** `SharedModelContainer` ist bewusst die
  einzige Stelle; abweichende Schema-Deklarationen haben historisch echten Datenverlust
  verursacht (Kommentar-Header Z. 6-21). Jede Änderung muss diesen Einzelpunkt erhalten.
- **Gestufte Fallbacks statt Fehlerwurf.** `make()` gibt `nil` zurück, Aufrufer entscheiden über
  die Degradierung. Die Haupt-App hängt zwei weitere Stufen an, Extensions melden nur
  „nicht verfügbar".
- **Diagnose über `UserDefaults`.** `lastFailureKey` mit Präfix `[cloud]`/`[local]`; bewusst
  `.standard`, nicht die App-Gruppe.
- **Prozessübergreifende Übergabe über App-Gruppen-Defaults** (`ReceiptShareHandoff`,
  `widgetDidCheckOffItem` in `SyncCoordinator`) — kein eigenes Dateiformat.
- **Kommentare tragen die Begründung.** Nahezu jede nicht offensichtliche Zeile hat einen
  Kommentar mit Datum und Nutzerbericht. Eine zurückgenommene Festlegung wird im Kommentar
  ausdrücklich zurückgenommen, nicht stillschweigend gelöscht.
- **Es gibt im ganzen Code bisher KEINE Prozess-/Umgebungs-Erkennung.** `Bundle.main` wird nur für
  Version und Sprache gelesen. Der Fix führt das erste derartige Muster ein.

## Dependencies

**Upstream** (was `make()` benutzt): `SchemaV1` aus `SchemaVersions.swift`, App-Gruppe
`group.com.johannesemmrich.SmartCart`, CloudKit-Container `iCloud.com.johannesemmrich.SmartCart`,
`UserDefaults` (`.standard` für Diagnose, App-Gruppe für das Backup-Flag), `FileManager` für die
Store-Sicherung.

**Downstream** (was von `make()` abhängt): Haupt-App-Start, Siri-/Shortcut-Intent, Widget-Timeline
und Widget-Intents, Share Extension. Zwei Unit-Test-Dateien nutzen die Konstanten
(`cloudKitContainerID`, `appGroupID`) mit.

**Zielabgrenzung:** `SharedModelContainer.swift` ist in beide Extension-Targets einkompiliert und
ist dort die **einzige** CloudKit-Berührung. `SyncCoordinator`, `SharedStoreService` und
`SharedItemPhotoService` (die direkt `CKContainer` benutzen) sind **nicht** in den
Extension-Targets — geprüft über die Sources-Build-Phasen: Share Extension 17 Quelldateien,
Widgets 16. Ein zweiter Absturzpfad in den Erweiterungen existiert also nicht.

## Existing Specs

Keine. `docs/` existierte vor dieser Phase nicht; `docs/specs/` ist leer. Dieses Dokument ist das
erste Artefakt unter `docs/`.

## Risks & Considerations

1. **Stille Abschaltung der iCloud-Spiegelung in der Haupt-App.** Erkennt die Prüfung den
   App-Prozess fälschlich als Erweiterung, öffnet die App dauerhaft nur lokal — ohne Fehler, ohne
   sichtbares Symptom, bis der Nutzer den Geräteabgleich vermisst. Das ist das größte Risiko der
   Änderung und braucht einen eigenen Test im App-Prozess, nicht nur den Extension-Nachweis.
2. **Das einmalige Sicherungs-Flag wird von Erweiterungen verbraucht.**
   `backupLocalStoreBeforeFirstCloudAttempt()` (Z. 105-129) läuft in `make()` **vor** dem
   Cloud-Versuch und setzt ein app-gruppenweites Flag, das genau einmal pro Gerät greift. Läuft
   eine Erweiterung zuerst, ist das Flag verbraucht, bevor die Haupt-App ihren ersten echten
   Cloud-Versuch macht — die Sicherung schützt dann nichts. Überspringt die Erweiterung CloudKit,
   sollte sie folgerichtig auch das Flag nicht verbrauchen. Gehört in die Analyse.
3. **Datenverlust-Vorgeschichte.** Genau diese Datei trägt zwei dokumentierte Vorfälle
   (Store-Wipe durch Schema-Mismatch; Verlust beim Übergang lokal → Cloud). Schema-Deklaration und
   Fallback-Reihenfolge dürfen sich nicht mit ändern.
4. **Widget ist mitbetroffen, aber nicht nachgestellt.** Der Fix greift dort automatisch. Ob der
   Absturz im Widget je auftrat, ist offen — zu klären, ob der Nachweis auch dort verlangt wird
   oder ob das ein Folge-Issue ist.
5. **Der Nachweis läuft über zwei Prozesse.** Ein gewöhnlicher Unit-Test kann den Absturz nicht
   zeigen: er tritt asynchron auf `com.apple.coredata.cloudkit.queue` in einem anderen Prozess auf.
   Der Beleg ist dreiteilig: Erfolgsansicht sichtbar, Nutzlast in der App-Gruppe, **kein** neuer
   Crash-Report `RestockShareExtension-*.ips`.
6. **Diagnose-Schlüssel zwischen den Prozessen.** Ob `UserDefaults.standard` in der Erweiterung
   dieselbe Ablage trifft wie in der App, ist nicht verifiziert. Falls doch, könnte ein
   `[cloud]`-Eintrag aus einer Erweiterung die Notfall-Erkennung der Haupt-App verwirren. In der
   Analyse nachlesen, nicht vermuten.
7. **Das Speicherlimit bleibt.** 120 MB für Erweiterungen sind der zweite, bisher nicht ausgelöste
   Risikofaktor (Quelle in Issue #4). Nicht Teil dieses Auftrags.

## Reproduktion (RED/GREEN-Grundlage)

XCUITest, Simulator iPhone 17 / iOS 27.0: Fotos-App öffnen, Begrüßung „Fortfahren" und
Mitteilungsfrage „Erlauben" wegklicken, letztes Bild im Raster öffnen, „Teilen" → „Restock".

- **Vor dem Fix:** Erweiterung zeigt ~3 s „Bon wird erkannt …", verschwindet dann; Crash-Report
  `RestockShareExtension-2026-09-20-160807.ips` (SIGTRAP, CloudKit-Queue) liegt unter
  `~/Library/Logs/DiagnosticReports/` vor und belegt den Ausgangszustand.
- **Nach dem Fix:** Erfolgsansicht „N Positionen … erkannt", Nutzlast unter
  `pendingShareExtensionReceipt` in der App-Gruppe, kein neuer Crash-Report.
- **Testbild** (Lidl-Screenshot, muss vor dem Lauf in die Fotos-Bibliothek des Simulators):
  `~/.claude/uploads/825e909c-a32a-4c05-a27e-7fd41a005c37/99bb697a-image.png` — am 2026-09-20
  als vorhanden geprüft.

## Offene Fragen für /20-analyse

- Welche Erkennungsmethode? Kandidaten: Bundle-Pfad endet auf `.appex`, oder
  `NSExtension`-Schlüssel in der Info.plist. Beide müssen gegen den App-Prozess, den
  Intent-im-App-Prozess und die Unit-Test-Umgebung geprüft werden — belegt, nicht vermutet.
- Soll das Sicherungs-Flag (Risiko 2) mit umgestellt werden, oder ist das ein Folge-Issue?
- Reicht der Extension-Nachweis, oder wird das Widget mitbelegt?

---

# Analysis

Phase 2 (Analyse), Stand 2026-09-20. Grundlage: Code-Fakten aus diesem Repo (jede Aussage unten ist
im Code oder am gebauten Bundle geprüft, nicht abgeleitet), der Absturzbericht, und Recherche zu
CloudKit in App-Erweiterungen.

## Type

**Bugfix.** (Workflow-Typ im State bleibt `feature`, weil `bug` dort ein Schnellverfahren ist —
siehe Kopf dieses Dokuments.)

## Korrekturen an Phase 1

Zwei Annahmen aus Phase 1 haben der Prüfung nicht standgehalten:

1. **Risiko 6 entfällt.** Der Diagnose-Schlüssel `lastFailureKey` (`smartcart.lastContainerError`)
   wird im gesamten Repo **nirgends gelesen** — auch nicht in `SmartCartApp.init()`. Der
   Doku-Kommentar in `SharedModelContainer.swift:37-39` und `:53-55` behauptet ausdrücklich eine
   Auswertung des `[cloud]`-Präfix durch `SmartCartApp.init()`; diese Logik existiert nicht.
   `SmartCartApp.init()` prüft ausschließlich `if let c = SharedModelContainer.make()` und setzt bei
   Totalausfall einen **anderen** Schlüssel (`smartcart.dataResetOccurred`, Z. 61), der in
   `HomeView.swift:270-271` gelesen wird. Es gibt also keine „Notfall-Erkennung der Haupt-App", die
   ein Eintrag aus einer Erweiterung verwirren könnte. Der falsche Kommentar wird im Zuge des Fixes
   mit korrigiert (siehe Scope); der ungelesene Schlüssel selbst ist ein eigenes Thema (Folge-Issue).

2. **Das Widget ist an fünf Stellen betroffen, nicht an einer.** `ShoppingListWidget.swift` ruft
   `make()` in Z. 126, 134, 141, 185 und 299 auf (EntityQuery, Vorschläge, Standardauswahl, Abhaken
   per Widget-Intent, Timeline-Aufbau). Gleichzeitig gilt: **Es existiert kein einziger
   Absturzbericht für `SmartCartWidgets`** — unter `~/Library/Logs/DiagnosticReports/` liegt nur
   `RestockShareExtension-2026-09-20-160807.ips`. Siehe Frage C unten.

## Antworten auf die offenen Fragen aus Phase 1

### A — Erkennungsmethode: Bundle-Endung `.appex`

**Entscheidung:** `Bundle.main.bundleURL.pathExtension == "appex"`.

Beide Kandidaten wurden gegen alle fünf Umgebungen geprüft:

| Umgebung | Bundle bei Laufzeit | `.appex`? | `NSExtension` in Info.plist? |
|---|---|---|---|
| Haupt-App `Restock` | `Restock.app` | nein ✓ | nein ✓ (generierte Info.plist, `GENERATE_INFOPLIST_FILE = YES`) |
| Share Extension | `RestockShareExtension.appex` | ja ✓ | ja ✓ (`NSExtensionPointIdentifier = com.apple.share-services`) |
| Widget | `SmartCartWidgets.appex` | ja ✓ | ja ✓ (`com.apple.widgetkit-extension`) |
| Siri-Intent (`AddItemIntent`) | `Restock.app` | nein ✓ | nein ✓ (kein eigenes Extension-Target im Projekt) |
| Unit-Tests (`RestockTests`) | `Restock.app` | nein ✓ | nein ✓ |

Die Unit-Test-Zeile ist der wichtigste Beleg und **empirisch am gebauten Produkt geprüft**:
`RestockTests.xctest` liegt in `Restock.app/PlugIns/` neben den beiden `.appex`, und das Target hat
`BUNDLE_LOADER = "$(TEST_HOST)"` mit `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Restock.app/Restock"`
(pbxproj Z. 1244/1259/1266/1281). Der Testprozess **ist** der App-Prozess; `Bundle.main` ist dort
`Restock.app`. Damit ist die Erkennung im Unit-Test direkt und aussagekräftig prüfbar.

Beide Kandidaten liegen in allen fünf Fällen richtig. Der Ausschlag für `.appex`:

- Die Bundle-Endung ist die **physische Prozess-Hülle**, nicht eine Deklaration. Genau diese Hülle
  entscheidet über die Signatur und damit über das Entitlement — es ist die kausal richtige Ebene
  für die Frage „habe ich das iCloud-Entitlement?".
- `NSExtension` ist ein Konfigurationsschlüssel des jeweiligen Extension-Points, kein Vertrag für
  Prozesserkennung. Ein `.appex` ohne diesen Schlüssel (künftiger Extension-Typ, verändertes
  Info.plist-Generat) würde fälschlich als App erkannt — und das ist die **gefährliche** Richtung.
- Die umgekehrte Fehlrichtung (App fälschlich als Erweiterung, Risiko 1) ist bei `.appex` praktisch
  ausgeschlossen: `Restock.app` kann nicht `.appex` heißen, ohne dass der gesamte Build gebrochen ist.

**Verworfen und belegt:** Das Entitlement zur Laufzeit direkt prüfen (`SecTaskCreateFromSelf` /
`SecTaskCopyValueForEntitlement`). Diese Security-APIs sind auf iOS **nicht im öffentlichen SDK**.
Ein anderes Projekt hat genau diesen Weg gebaut und wieder zurückgenommen (github.com/gbyo/programme
PR #45 → PR #47, Begründung dort: „Those Security task APIs are not exposed to ordinary iOS app
Swift code in the public SDK"). Scheidet aus.

### B — Sicherungs-Flag: ja, mit umstellen, in diesem Fix

**Entscheidung:** `backupLocalStoreBeforeFirstCloudAttempt()` wird in Erweiterungen ebenfalls
übersprungen — hinter derselben Bedingung wie der Cloud-Versuch.

Belegte Lage: Das Flag `smartcart.preCloudBackupDone.v2` wird ausschließlich in dieser Funktion
gesetzt und gelesen (`SharedModelContainer.swift:111-113`); die Funktion ist `private` und hat genau
einen Aufrufer, `make()` (Z. 44). Der Ordner `PreCloudBackup` hat **keinen Lesepfad im Code** —
reine Ablage für eine manuelle Wiederherstellung.

Begründung: Das Flag sichert exakt das eine riskante Fenster „erster Kontakt mit dem Cloud-Pfad". Es
ist app-gruppenweit, greift genau einmal pro Gerät, und `make()` ruft es **vor** der Verzweigung auf.
Öffnet eine Erweiterung künftig nur noch lokal, fasst sie den Cloud-Pfad nie an — verbraucht aber
weiterhin das Cloud-bezogene Fenster. Nutzt jemand „Teilen", bevor er die App je gestartet hat, ist
die Sicherung beim echten ersten App-Start bereits aufgebraucht und schützt nichts. Das ist kein
Nebenschauplatz, sondern eine direkte Folge dieser Änderung — sie gehört in denselben Fix, in
dieselbe Funktion, in denselben Codeblock.

### C — Widget: Fix greift automatisch, eigener Nachweis wird NICHT verlangt

**Entscheidung:** Der Nachweis läuft über die Share Extension. Das Widget wird vom selben Fix
mitgeheilt, bekommt aber keinen eigenen RED/GREEN-Nachweis in diesem Auftrag.

Begründung: Der Absturz im Widget ist **nicht belegt** — kein einziger Absturzbericht für
`SmartCartWidgets` existiert, während der für die Share Extension vorliegt. Eine plausible Erklärung
(ausdrücklich Hypothese, nicht geprüft): Der Absturz tritt ~4,5 s nach Prozessstart auf; die Share
Extension lebt wegen OCR lange genug, ein Widget-Timeline-Aufbau ist typischerweise weit kürzer und
endet, bevor die CloudKit-Queue anläuft. Ohne reproduzierten Fehler gibt es nach dem
Analysis-First-Prinzip auch nichts zu beweisen. Ein Nachweis auf Verdacht würde den Auftrag
aufblähen, ohne etwas zu belegen. Aufgenommen als Folge-Issue.

## Affected Files

| Datei | Change Type | Beschreibung |
|---|---|---|
| `SmartCart/Models/SharedModelContainer.swift` | MODIFY | Erkennungsfunktion ergänzen; `make()` verzweigt vor dem Cloud-Versuch; Sicherungsaufruf hinter dieselbe Bedingung; Doku-Kommentar Z. 29-36 (Verbot der Prozess-Verzweigung) ausdrücklich zurücknehmen; Falschaussage in Z. 37-39/53-55 über die angebliche Auswertung in `SmartCartApp.init()` korrigieren. |
| `RestockTests/SharedModelContainerExtensionDetectionTests.swift` | CREATE | Unit-Tests: Erkennung liefert im App-Prozess `false` (sichert Risiko 1); Erkennung liefert für einen `.appex`-Pfad `true`; die im App-Prozess gewählte Store-Konfiguration ist die CloudKit-Variante. |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Neue Testdatei in den vier nötigen Abschnitten registrieren (Xcode erkennt Dateien nicht selbst — siehe CLAUDE.md). |
| `RestockUITests/ReceiptShareExtensionTests.swift` | CREATE | Cross-App-Nachweis (Fotos → Teilen → Restock). Wird in Phase 4 (TDD RED) gebaut, nicht hier. |

Keine Änderung an: den Entitlements (bleiben bewusst wie sie sind), `SmartCartApp.swift`,
`ShoppingListWidget.swift`, `AddItemIntent.swift`, `ShareViewController.swift` — alle acht
Aufrufstellen rufen weiterhin `make()` ohne Argument auf.

## Scope Assessment

- Dateien: **3 in Phase 5** (+1 Testdatei in Phase 4) — Limit 4-5 ✓
- Geschätzte LoC: **+70 / -15** Produktivcode und Tests, plus pbxproj-Registrierung — Limit ±250 ✓
- Funktionen: `make()` bleibt unter 50 LoC, wenn die Erkennung eine eigene kleine Funktion wird ✓
- Risk Level: **MEDIUM**

## Technical Approach

Empfehlung, in dieser Reihenfolge:

1. Erkennung als **eigene, reine Funktion** implementieren, die auf einer `URL` arbeitet, nicht
   direkt auf `Bundle.main` — nur so sind beide Richtungen prüfbar (App-Pfad → `false`,
   `.appex`-Pfad → `true`), ohne einen echten Extension-Prozess starten zu müssen. Der
   Produktivaufruf reicht `Bundle.main.bundleURL` hinein.
2. Test schreiben, der im App-Test-Host beweist, dass die Erkennung dort `false` ergibt — **vor**
   der Änderung an `make()`. Das ist die Absicherung gegen Risiko 1.
3. `make()` verzweigen: bei erkannter Erweiterung Sicherungsaufruf **und** Cloud-Versuch
   überspringen, direkt den lokalen App-Gruppen-Store öffnen. Schema-Deklaration und
   Store-Adressierung bleiben unverändert — nur die CloudKit-Konfiguration entfällt.
4. Kommentare korrigieren (zurückgenommene Festlegung ausdrücklich als zurückgenommen markieren,
   nicht löschen — Repo-Konvention).
5. Bestandstests müssen unverändert grün bleiben.

**Warum nicht der naheliegende Gegenentwurf** (`make(cloudKit:)` bzw. zwei benannte Einstiegspunkte,
sodass jeder Aufrufer deterministisch entscheidet): Er wurde ernsthaft geprüft und verworfen. Es gibt
**acht** Aufrufstellen in vier Dateien. Ein Parameter verlagert die Fehlerquelle von „eine zentrale
Weiche, einmal richtig" zu „acht Aufrufer, die je den richtigen Wert übergeben". Genau diese
Aufrufer-Divergenz ist der dokumentierte Grund, warum `SharedModelContainer` überhaupt als einziger
Einstiegspunkt existiert — ein abweichender Aufruf hat in diesem Projekt schon einmal echten
Datenverlust verursacht (Kommentar Z. 6-21). Bei der Laufzeit-Erkennung ändert sich an den acht
Aufrufstellen nichts.

**Härtere Prüfung, als die Bewertung vorschlug:** Ein Test nur auf die Erkennung würde einen
vertauschten Vergleich in `make()` nicht bemerken. In Phase 4 ist deshalb zu prüfen, ob die
Reihenfolge der Store-Konfigurationen selbst beobachtbar gemacht werden kann (`ModelConfiguration`
hat vermutlich eine lesbare `cloudKitContainerIdentifier`-Eigenschaft — **zu verifizieren, nicht
voraussetzen**). Falls ja: Test „im App-Prozess ist die erste Konfiguration die mit CloudKit".
Falls nein: der Cross-App-Nachweis in Phase 4 deckt die Richtung ab.

## Dependencies

Unverändert gegenüber Phase 1. Die Änderung berührt keine Schnittstelle nach außen: Die Signatur von
`make()` bleibt gleich, alle acht Aufrufer bleiben unangetastet.

## Risks & Considerations (aktualisiert)

1. **Stille Abschaltung der iCloud-Spiegelung in der Haupt-App** — unverändert das größte Risiko.
   Abgesichert durch den Unit-Test im App-Prozess (Schritt 2 oben). Bleibt MEDIUM, weil der
   Fehlerfall symptomlos wäre.
2. **Sicherungs-Flag** — durch Entscheidung B adressiert, kein offenes Risiko mehr.
3. **Datenverlust-Vorgeschichte** — nicht berührt: Schema-Deklaration, Store-Adressierung und die
   Fallback-Kette in `SmartCartApp` bleiben unverändert. Zusätzlich belegt: Die Share Extension
   **schreibt nicht** in den SwiftData-Store (kein `insert`, `delete` oder `save` im gesamten
   Extension-Code); die Übergabe an die App läuft über App-Gruppen-`UserDefaults`
   (`ReceiptShareHandoff`). Der lokale Öffnungspfad in der Erweiterung ist rein lesend.
4. **Widget** — durch Entscheidung C adressiert, Folge-Issue.
5. **Zweiprozess-Nachweis** — unverändert: Erfolgsansicht sichtbar, Nutzlast in der App-Gruppe, kein
   neuer Absturzbericht. Die Reproduktionsgrundlage ist geprüft vorhanden (Absturzbericht
   `RestockShareExtension-2026-09-20-160807.ips` und das Testbild liegen beide vor, am 2026-09-20
   erneut bestätigt).
6. ~~Diagnose-Schlüssel zwischen den Prozessen~~ — **entfällt**, siehe Korrektur 1.
7. **Speicherlimit 120 MB** — unverändert nicht Teil dieses Auftrags.

## Folge-Issues (in Phase 2 angelegt)

- **#5** — Diagnose-Schlüssel `smartcart.lastContainerError` wird geschrieben, aber nie gelesen;
  der Kommentar beschreibt nicht existierende Logik. Die Kommentar-Korrektur passiert in #4 mit,
  die Frage „sichtbar machen oder entfernen?" bleibt dort offen.
- **#6** — Widget hat dieselbe Absturzlage, nie reproduziert. Nach #4 prüfen, ob sie sich auf dem
  alten Stand überhaupt auslösen lässt.

## Open Questions

Keine offenen Fragen an den Product Owner. Alle drei Fragen aus Phase 1 sind mit Belegen entschieden
(A, B, C oben).
