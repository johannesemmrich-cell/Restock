# Adversary Dialog — test-98-durchgang-7-tagesmitteilung
Spec: docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md
Datum: 2026-10-13 22:05

## Checkliste
- [x] AC-1 Naht (PROVEN)
- [x] AC-2 Kette D1 (PROVEN)
- [x] AC-3 Abgemeldet D2 (PROVEN)
- [x] AC-4 Ersetzen D3 (PROVEN)
- [x] AC-5 Ledger nach Zustellzeit D4 (PROVEN)
- [x] AC-6 Produktfix D5 (PROVEN; .ephemeral/.unknown ungetestet, siehe F002)
- [x] AC-7 cancelAll D6 (PROVEN)
- [x] AC-8 Aufräumen (tearDown PROVEN; gemeinsamer Unit-Lauf aller RestockTests nachgeholt: 486 Tests, 0 Fehler, TEST SUCCEEDED, unit-gesamtlauf-output.txt; UI-Suiten laufen in der CI)
- [x] AC-9 Echter Weg (PROVEN)
- [x] AC-10 Stabilität (PROVEN, 3 Läufe)
- [x] AC-11 Umfang (310 statt 250 LoC; vom PO per AskUserQuestion am 2026-10-13 akzeptiert, F001 geschlossen)
- [-] AC-12 vertagt an /60-validate (Pflicht-Durchlauf)
- [~] AC-13 Testklassen-Kopfkommentar und Spec PROVEN; CLAUDE.md und Ticketkommentar vertagt an /60-validate
- [x] AC-14 Geräte (PROVEN)

## Dialog

### Runde 1
**Adversary:** Tests selbst gefahren: `xcodebuild test -only-testing:RestockTests/NotificationDigestChainTests`, Ziel Restock-Validate (8F696920-...). Lauf 1 (Ausgabe in adversary-test-run1.txt): "Executed 8 tests, with 0 failures", "** TEST SUCCEEDED **", alle 8 Methoden einzeln passed. Lauf 2 danach: erneut "Executed 8 tests, with 0 failures" (das Ende "TEST SUCCEEDED" kam im Filter nicht, xcodebuild hing offenbar im Diagnose-Einsammeln, Issue #21, kein Testfehler). Dazu die vorhandenen Artefakte: test-green-wiederholung.txt (3 Läufe + Kontrolllauf je 8/0), test-red-output.txt (5 Fehler, nur D5, Zeilen 134/135/141/141/149) und mutationsprobe-output.txt (Guard entfernt: 8 Tests, 5 Fehler, nur D5) belegen Rot-vor-Fix und dass D5 nicht leer läuft. Kein Simulator parallel (einziger xcodebuild nebenher war ein macOS-Build eines anderen Projekts). Keine Gerätezugriffe.

Befunde im Code:
- AC-1: Protokoll `DigestNotificationCenter` mit Erweiterung auf `UNUserNotificationCenter`; `scheduleReplenishmentDigests(candidates:now:center:)`, `cancelAll(center:)`, `run(container:now:center:)` mit Standardwert `UNUserNotificationCenter.current()`. Aufrufer unverändert: `git diff origin/main --stat` zeigt keine Änderung an SmartCartApp.swift, SettingsView, HomeView, HabitService; Aufrufstellen SmartCartApp.swift:764/820, SettingsView.swift:286/424, HabitService.swift:283 nutzen den Standardwert. Build grün (Testlauf baut die App).
- Reihenfolge: Der Guard `status == .authorized || .provisional` steht in performDigestScheduling VOR `commitDelivered`, `remove(identifiers:)`, `add` und `log.replace`. Ohne Erlaubnis läuft `remove` also nicht, das Protokoll bleibt unberührt, das Ledger bekommt nichts. `.notDetermined`, `.denied`, `.ephemeral` und unbekannte Werte fallen alle durch (Allow-Liste, nicht Deny-Liste).
- AC-9: Die Tests setzen weder Ledger noch Protokoll noch Muster; Muster entstehen aus echten PurchaseRecords im In-Memory-SwiftData-Container (SchemaV1), `run` ruft echten Planer. Einzige Handvorgabe: `center.preload` (erlaubt, D3). `OverdueNotificationLedger().shouldNotify(pattern)` liest den echten Zustand.
- AC-10: Feste Daten (Sept. 2026, `Calendar.current`, keine Zeitumstellung), `now` wird immer übergeben, keine Wartezeiten.
- AC-8: touchedKeys enthält alle 11 Schlüssel der Spec; setUp und tearDown löschen und prüfen per XCTAssertNil.

Code reference: SmartCart/Services/NotificationService.swift
Code reference: SmartCart/Services/ReplenishmentDigest.swift
Code reference: RestockTests/NotificationDigestChainTests.swift
Code reference: Restock.xcodeproj/project.pbxproj

**Implementierer:** (nicht beteiligt; Kontextisolation)

### Runde 2
**Adversary:** Gebohrt nach Lücken.

Finding F001:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockTests/NotificationDigestChainTests.swift
  Description: `git diff origin/main --numstat` für Code: pbxproj +4, Testdatei +238, NotificationService +49/-10, ReplenishmentDigest +7/-2 = 310 Zeilen (Hinzufügungen plus Löschungen) ohne CLAUDE.md, das noch hinzukommt. Spec-Schätzung Test ca. 190, tatsächlich 238.
  Spec requirement: AC-11 — Summe ≤ ±250 LoC; bei Überschreitung "STOP und mit Schätzung nachfragen".
  Conflict: 310 > 250, keine Nachfrage dokumentiert (Dateizahl 5 mit CLAUDE.md eingehalten, Produktcode nur Naht, Erlaubnisprüfung, Kommentar: sauber).
  Remediation: PO-Akzeptanz des Mehrumfangs einholen (Präzedenz Durchgänge 3 und 4) oder Test kürzen.

Finding F002:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: RestockTests/NotificationDigestChainTests.swift
  Description: D5 prüft `.notDetermined` und `.denied` (Schleife, Zeile 131) sowie `.provisional` (eigener Test), aber weder `.ephemeral` noch einen unbekannten Rohwert. Der Guard in NotificationService.swift (Allow-Liste) behandelt beides korrekt, nur nicht durch Test belegt. Ebenso nicht getestet: ein vorhandener Protokolleintrag bleibt ohne Erlaubnis unberührt (kein `commitDelivered`).
  Spec requirement: AC-6 nennt nur notDetermined und denied, daher keine Verletzung.
  Remediation: Optional `.ephemeral` in die Schleife aufnehmen.

Finding F003:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/NotificationService.swift
  Description: Wird die Erlaubnis später entzogen, bleiben bereits angemeldete `replenish-`-Anfragen unberührt (Guard vor remove); iOS stellt ohnehin nicht zu. Konsistent mit Spec ("nichts entfernen"), nur zur Kenntnis.

Bestätigungen (Rigor, jeweils mit Beleg):

Confirmation: AC-1 CONFIRMED — Protokoll und Standardwerte, Aufrufer unverändert (siehe Runde 1).
Code reference: SmartCart/Services/NotificationService.swift
Confirmation: AC-1/AC-2 CONFIRMED — `run` reicht `center` durch (Zeile 206); D1 prüft Kennung `replenish-digest-2026-9-22`, Stunde 9, Tag 22, Text "Milch", Protokoll `deliveryDate` 22.9. 9:00.
Code reference: SmartCart/Services/ReplenishmentDigest.swift
Confirmation: AC-2 bis AC-7, AC-9, AC-10 CONFIRMED — 8/8 Tests grün in meinem Lauf; D2 beide Schalter, D3 fremde Kennung `other-1` bleibt, `replenish-old` weg, keine Dopplung (Butter+Milch in einer Kennung), D4 vor 9:00 meldbar, danach nicht und keine neue Anfrage, D5 Rot-vor-Fix und Mutationsprobe belegt, D6 leert Zentrale und Protokoll.
Code reference: RestockTests/NotificationDigestChainTests.swift
Confirmation: AC-8 (Teil tearDown) CONFIRMED — Schlüssel-Leerprüfung in setUp und tearDown. Der gemeinsame Lauf mit allen Bestandssuiten wurde hier NICHT gefahren (nur die neue Klasse); die Aussage stützt sich auf die Artefakte des Implementierers, nicht auf eigene Ausführung.
Code reference: Restock.xcodeproj/project.pbxproj
Confirmation: AC-14 CONFIRMED — Alle Läufe nur auf Simulator-UDID 8F696920 (Restock-Validate), kein devicectl; Artefakte nennen dieselbe UDID.
Code reference: docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md

Vertagt an /60-validate: AC-12 (Pflicht-Durchlauf im Simulator), AC-13 Teile CLAUDE.md und Ticketkommentar von #98 (CLAUDE.md-Absatz "Durchgang 7" ist im Diff noch nicht vorhanden; Spec und Testklassen-Kopfkommentar nennen die offenen Grenzen vollständig).

Hinweis Stand: Der Produktfix in NotificationService.swift ist gestaged, aber noch nicht committet (HEAD 02d2b95 enthält D5 rot).

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`); keine Tabelle angehängt. Verdächtige Felder, manuell geprüft:
- `scheduledReplenishmentDigests` (Protokoll): Produktions-Schreibstelle `log.replace(with:)` nur nach erfolgreichem `add` und nur nach Erlaubnis-Guard. Bedingung davor: `authorizationStatus` ist `.authorized` oder `.provisional`. Test für diesen Weg: testNothingIsPlannedOrLoggedWithoutPermissionAndItemStaysNotifiable (Gegenweg) und testPurchaseHistoryBecomesOneDigestAtNine (Weg mit Erlaubnis).
- `notifiedOverdueReplenishments` (Ledger): geschrieben in `commitDelivered`, erst nach Erlaubnis-Guard und nach Zustellzeit. Test für diesen Weg: testItemEntersLedgerOnlyAfterDeliveryTime.

## Verdict
VERDICT: AMBIGUOUS
Begründung: Funktional sind AC-1 bis AC-7, AC-9, AC-10, AC-14 bewiesen (eigener Lauf 8/8, 0 Fehler, Testzahl geprüft, Rot-vor-Fix und Mutationsprobe vorhanden, Guard steht vor commitDelivered/remove/add/replace, Aufrufer unverändert). Offen für den Menschen: F001 (AC-11, 310 statt ≤250 LoC ohne dokumentierte PO-Nachfrage) und AC-8 gemeinsamer Lauf nicht von mir ausgeführt. AC-12 und AC-13 (CLAUDE.md, Ticketkommentar) sind an /60-validate vertagt. Tests: 8 bestanden, 0 fehlgeschlagen, 0 übersprungen.

## Geprüfte Dateien

- sha256:0f0741d069671f12fd7a6cc69b159e37e06b141a6c969876e28e53f5eb7ebe3f  Restock.xcodeproj/project.pbxproj
- sha256:b667b206af51ea65e0dc44fda9486c671c086964dd79c2a3e28b58d939e8d282  RestockTests/NotificationDigestChainTests.swift
- sha256:bf058331890bc898107f9da5ae2e0afc05f5621017cbf28912cc980a97c13542  SmartCart/Services/NotificationService.swift
- sha256:dea98753fc29d6f168fa93bd6c4eaa782f13a0c9c1f1b520be737da0c0cbfbb4  SmartCart/Services/ReplenishmentDigest.swift
- sha256:3d0b030765c6ec068334eb4fb3bb16eb4a2ef6ce165f6529cc2e91157af0b011  docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md

## Prüfbasis

- base: 5c9202085c03158bb9c2397fc861c0a414a1a531
- blob:40262fc468fc708ef05a34604ab51dc6efc8cdbd  Restock.xcodeproj/project.pbxproj
- blob:e3e8f45f333d506f8e1994cbe06a55c368ff1834  RestockTests/NotificationDigestChainTests.swift
- blob:678056e706fa6e67b5658651d82a1425bc1f4a34  SmartCart/Services/NotificationService.swift
- blob:3fcb79a6a800af2946966b18a2e5f499612528c0  SmartCart/Services/ReplenishmentDigest.swift
- blob:cb393ec036a1a6031e02e494c7d16ad8485f58b5  docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md

## Geprüfte Dateien

- sha256:0f0741d069671f12fd7a6cc69b159e37e06b141a6c969876e28e53f5eb7ebe3f  Restock.xcodeproj/project.pbxproj
- sha256:b667b206af51ea65e0dc44fda9486c671c086964dd79c2a3e28b58d939e8d282  RestockTests/NotificationDigestChainTests.swift
- sha256:bf058331890bc898107f9da5ae2e0afc05f5621017cbf28912cc980a97c13542  SmartCart/Services/NotificationService.swift
- sha256:dea98753fc29d6f168fa93bd6c4eaa782f13a0c9c1f1b520be737da0c0cbfbb4  SmartCart/Services/ReplenishmentDigest.swift
- sha256:3d0b030765c6ec068334eb4fb3bb16eb4a2ef6ce165f6529cc2e91157af0b011  docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md

## Prüfbasis

- base: 5c9202085c03158bb9c2397fc861c0a414a1a531
- blob:40262fc468fc708ef05a34604ab51dc6efc8cdbd  Restock.xcodeproj/project.pbxproj
- blob:e3e8f45f333d506f8e1994cbe06a55c368ff1834  RestockTests/NotificationDigestChainTests.swift
- blob:678056e706fa6e67b5658651d82a1425bc1f4a34  SmartCart/Services/NotificationService.swift
- blob:3fcb79a6a800af2946966b18a2e5f499612528c0  SmartCart/Services/ReplenishmentDigest.swift
- blob:cb393ec036a1a6031e02e494c7d16ad8485f58b5  docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md
