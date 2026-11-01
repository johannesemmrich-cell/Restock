# Adversary Dialog — fix-244-open-prices-aus
Spec: docs/specs/services/open-prices-1-0-aus.md
Datum: 2026-11-01 10:57

## Checkliste

(Von Hand aus `## Acceptance Criteria` der Spec übernommen; `adversary_dialog.py parse` erkennt das Format `- [ ] AC-N:` nicht, die Spec ist freigegeben und bleibt unverändert.)

- [x] AC-1: `OpenPricesContribution.isAvailable` ist `false` und trägt einen Kommentar mit Verweis auf Issue #244
- [x] AC-2: Dienst mit `available: false` sendet nie (Schalter an, Token, Filiale, Foto): `contribute` liefert `nil`, Fake-API ohne Aufruf
- [x] AC-3: `readiness` bei `available: false` `.disabled`, bei `available: true` sonst gleich `.ready`
- [x] AC-4: `OpenPricesContributionService.shared` ist gesperrt
- [x] AC-5: Bestandstests der Klasse `OpenPricesContributionTests` mit `available: true` grün
- [x] AC-6: Einstellungen ohne Entwicklermodus ohne Zeile „Open Prices“, „Standard-Läden“ sichtbar
- [x] AC-7: Mit `-developerMode YES` ebenfalls keine Zeile „Open Prices“
- [x] AC-8: Simulator-Durchlauf: Einstellungen ohne Eintrag; Bon mit gesetztem Schalter sendet nichts, `openPricesLastResult` unverändert
- [x] AC-9: Volle Unit-Suite und Klasse `RestockUITests` grün, Build kompiliert — mit PO-Ausnahme 2026-11-01 für drei belegte Fremdfehler (ConsumptionPatternTests ×2 → #231, testAddStoreAndQuickAddItemShowsPriceWithoutCrash → #17), siehe Nachtrag

## Dialog

### Runde 1
**Adversary:** Belege einfordern. Was belegt AC-1..AC-5 (Konstante, Dienst, Singleton)? Welche Aufrufer gibt es ausser `readiness`? Kompiliert Release?
**Implementierer:** (aus Code und Testausgaben belegt)
- AC-1: `Code reference: SmartCart/Services/OpenPricesContributionService.swift:317` `static let isAvailable = false` mit Kommentar "Issue #244". PROVEN (identisch DEBUG/Release, kein `#if`).
- AC-2/AC-3: `Code reference: SmartCart/Services/OpenPricesContributionService.swift:443` `readiness` nutzt `available && isEnabled`; `contribute(lines:...)` verlangt `.ready` und kehrt sonst mit `nil` zurueck, ohne `store(...)`. Eigener Klassenlauf `adversary-test-output.txt`: `Executed 22 tests, with 0 failures`, `** TEST SUCCEEDED **` (enthaelt testUnavailableServiceNeverSends, testReadinessIsDisabledWhenUnavailable). PROVEN.
- AC-4: `Code reference: SmartCart/Services/OpenPricesContributionService.swift:416` `shared` nutzt den Standardwert `available: OpenPricesContribution.isAvailable`; Test testSharedServiceIsUnavailable gruen. PROVEN.
- AC-5: Helfer `service(...)` mit `available: true` als Default, restliche Tests der Klasse gruen. `Code reference: RestockTests/OpenPricesContributionTests.swift:31`. PROVEN.
- Release: Release-Build in `adversary-release-build.txt`: `** BUILD SUCCEEDED **`, keine Warnung "will never be executed" oder zu SettingsView/OpenPrices. PROVEN.
- Einziger produktiver Sendeaufruf: `ReceiptScannerView.swift:843` -> `shared.contributeInBackground` -> `contribute(lines:)` -> `readiness`. Teilen-Erweiterung (`RestockShareExtension`) und Widgets referenzieren den Dienst nicht (grep).

### Runde 2
**Adversary:** Randfaelle. (a) `contribute(_ plan:)` prueft nur `isEnabled` und Token, nicht `available`; (b) `OpenPricesSettingsView` ueber anderen Weg erreichbar (Deep Link, Suche, Siri); (c) Settings-UI-Test koennte falsch positiv sein; (d) AC-8 ohne Token; (e) AC-9 mit Fremdfehlern; (f) CLAUDE.md laut Spec/DoD.
**Implementierer:**
- (a) `Code reference: SmartCart/Services/OpenPricesContributionService.swift:469` `contribute(_ plan:)` ist nicht gesperrt (`guard isEnabled, let token`). Produktiv nur von `contribute(lines:)` aufgerufen, das davor `readiness` prueft; sonst nur Tests. Heute nicht erreichbar, aber keine zweite Absicherung. LOW, F002.
- (b) `OpenPricesSettingsView` wird nur in `Code reference: SmartCart/Views/Settings/SettingsView.swift:142` instanziiert (grep ueber SmartCart, Widgets, Share-Extension: keine Deep-Link-, Intent- oder Such-Verwendung). Die Schluessel in `ShoppingItem.swift:557` sind nur eine Liste fuer den Paritaetstest. PROVEN fuer AC-6/AC-7. UI-Test mit Gegenprobe "Standard-Laeden", zweimal geprueft inkl. Nachziehen, Screenshots in `durchlauf-bilder/`. `Code reference: RestockUITests/RestockUITests.swift:333`.
- (d) AC-8: `durchlauf-defaults-vorher/nachher.txt`: Schalter =1, kein `openPricesLastResult`. Der Beleg raeumt selbst ein (durchlauf.md), dass ohne Token auch ohne Sperre nichts gesendet worden waere; die Sperre bei voller Bereitschaft belegen nur Unit-Tests T2/T4. So von der Spec vorgesehen und ehrlich ausgewiesen. PROVEN mit dieser Grenze.
- (e) AC-9 wortlich "Unit-Suite und Klasse RestockUITests gruen": `test-ac9-unit-und-restockuitests.txt` zeigt 797 Unit mit 2 Fehlschlaegen (ConsumptionPatternTests) und 1 UI-Fehlschlag (`testAddStoreAndQuickAddItemShowsPriceWithoutCrash`, "'Laeden einrichten'-Button im leeren Home-State nicht gefunden"). `test-fremdfehler-auf-main-stand.txt` zeigt dieselben Fehlschlaege mit Produktcode von main. Die Tests beruehren weder Open Prices noch Einstellungen. Plausibel Vorbestand, aber AC-9 ist wortlich nicht gruen; ob "erfuellt bis auf belegte Fremdfehler" gilt, entscheidet der PO. AMBIGUOUS, F001.
- (f) `CLAUDE.md` ist im Arbeitsstand unveraendert; Spec Scope und Definition of Done verlangen den Absatz "Open Prices beitragen ... in 1.0 ausgeblendet (#244)". Fehlt. MEDIUM, F003.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockUITests/RestockUITests.swift:171
  Description: `testAddStoreAndQuickAddItemShowsPriceWithoutCrash` und zwei ConsumptionPatternTests schlagen fehl; derselbe Fehlschlag auch mit Produktcode von main (Beleg vorhanden).
  Spec requirement: AC-9 - volle Unit-Suite und Klasse RestockUITests gruen
  Conflict: Wortlaut nicht erfuellt; Vorbestand belegt, nicht durch #244 verursacht.
  Remediation: PO entscheidet ueber Ausnahme oder Folge-Issue fuer die drei Fremdfehler; CI-Lauf gegenpruefen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Services/OpenPricesContributionService.swift:469
  Description: `contribute(_ plan:)` prueft `available` nicht; Sperre nur ueber `readiness` in `contribute(lines:)`.
  Spec requirement: AC-2 - Dienst mit available false sendet nie
  Conflict: Heute kein produktiver Aufrufer ausser `contribute(lines:)`; ein kuenftiger direkter Aufruf umginge die Sperre.
  Remediation: Optional `guard available` am Anfang von `contribute(_ plan:)`.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: spec_violation
  Code reference: CLAUDE.md:1
  Description: CLAUDE.md-Absatz "Open Prices beitragen" nicht um den Stand "in 1.0 ausgeblendet (#244)" ergaenzt.
  Spec requirement: Definition of Done / Scope - CLAUDE.md MODIFY
  Conflict: Pflichtartefakt der Spec fehlt im Arbeitsstand.
  Remediation: Satz ergaenzen (Konstante, Sperre im Dienst, Altzustand bleibt gespeichert).

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/OpenPricesContributionService.swift:317
  Evidence: `static let isAvailable = false`, Kommentar #244.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Views/Settings/SettingsView.swift:142
  Evidence: NavigationLink nur unter `if OpenPricesContribution.isAvailable`; kein anderer Instanziierungsort.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: RestockTests/OpenPricesContributionTests.swift:31
  Evidence: Klassenlauf 22 Tests, 0 Fehlschlaege (adversary-test-output.txt).
  Status: CONFIRMED

## Nachtrag Orchestrator (nach Runde 2)

- F003 behoben: CLAUDE.md-Absatz „Open Prices beitragen“ um „In 1.0 ausgeblendet (Issue #244 …)“ ergänzt, inkl. offener Grenze F002. Code reference: CLAUDE.md:1 (Hash unten neu gestempelt). Keine Produktcode-Änderung.
- F002 bleibt bewusst offen (LOW, kein produktiver Weg an `readiness` vorbei), in CLAUDE.md und Spec-Grenzen benannt.
- F001: PO-Entscheidung 2026-11-01 (Auswahl „Ausnahme, weiter“): die drei Fremdfehler gelten als Ausnahme, sie bleiben in #231 und #17; Gegenprobe auf main-Stand in `test-fremdfehler-auf-main-stand.txt`. Verdict bleibt AMBIGUOUS, Weiterführung mit PO-OK.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**AMBIGUOUS**

## Geprüfte Dateien

- sha256:6ddbb14372793c0c28e1c832209fceb976e552fc42d32d5cdcbec658c7403dee  CLAUDE.md
- sha256:2c39eb4fac2c84eaf1708f6c97c94d0cd5081dfe1fd74f47094f2414427134d9  RestockTests/OpenPricesContributionTests.swift
- sha256:b9e69a3169449c999fc07450a95abeaec7ad8243efb7f9b848a7d070f7a03556  RestockUITests/RestockUITests.swift
- sha256:5a7582c8e39cfebbbf4dd16c6532729692ad278441ad11384931d88d38c3e680  SmartCart/Services/OpenPricesContributionService.swift
- sha256:59df407b3a166e1286780548e65e0df2c71ab3cdac02a1647f0a94ae1b09cfa5  SmartCart/Views/Settings/SettingsView.swift

## Prüfbasis

- base: 9ee68452809cb0f20f994508e387dca58d802efc
- blob:ea3a0a83ba9396641057b57e4da03943ece289b7  CLAUDE.md
- blob:49fa3f0b924a6586a5367e7348dba99e4ebdd821  RestockTests/OpenPricesContributionTests.swift
- blob:970cea9130109ea24481df6c49476cb3cc84d935  RestockUITests/RestockUITests.swift
- blob:308c2f69c6cb7aeb926a28a4396940a88ca27b18  SmartCart/Services/OpenPricesContributionService.swift
- blob:d237a6c23b63a8e052bd31eaa8c505038e0799c8  SmartCart/Views/Settings/SettingsView.swift

## Geprüfte Dateien

- sha256:6ddbb14372793c0c28e1c832209fceb976e552fc42d32d5cdcbec658c7403dee  CLAUDE.md
- sha256:2c39eb4fac2c84eaf1708f6c97c94d0cd5081dfe1fd74f47094f2414427134d9  RestockTests/OpenPricesContributionTests.swift
- sha256:b9e69a3169449c999fc07450a95abeaec7ad8243efb7f9b848a7d070f7a03556  RestockUITests/RestockUITests.swift
- sha256:5a7582c8e39cfebbbf4dd16c6532729692ad278441ad11384931d88d38c3e680  SmartCart/Services/OpenPricesContributionService.swift
- sha256:59df407b3a166e1286780548e65e0df2c71ab3cdac02a1647f0a94ae1b09cfa5  SmartCart/Views/Settings/SettingsView.swift

## Prüfbasis

- base: 9ee68452809cb0f20f994508e387dca58d802efc
- blob:ea3a0a83ba9396641057b57e4da03943ece289b7  CLAUDE.md
- blob:49fa3f0b924a6586a5367e7348dba99e4ebdd821  RestockTests/OpenPricesContributionTests.swift
- blob:970cea9130109ea24481df6c49476cb3cc84d935  RestockUITests/RestockUITests.swift
- blob:308c2f69c6cb7aeb926a28a4396940a88ca27b18  SmartCart/Services/OpenPricesContributionService.swift
- blob:d237a6c23b63a8e052bd31eaa8c505038e0799c8  SmartCart/Views/Settings/SettingsView.swift

## Geprüfte Dateien

- sha256:6ddbb14372793c0c28e1c832209fceb976e552fc42d32d5cdcbec658c7403dee  CLAUDE.md
- sha256:2c39eb4fac2c84eaf1708f6c97c94d0cd5081dfe1fd74f47094f2414427134d9  RestockTests/OpenPricesContributionTests.swift
- sha256:b9e69a3169449c999fc07450a95abeaec7ad8243efb7f9b848a7d070f7a03556  RestockUITests/RestockUITests.swift
- sha256:5a7582c8e39cfebbbf4dd16c6532729692ad278441ad11384931d88d38c3e680  SmartCart/Services/OpenPricesContributionService.swift
- sha256:59df407b3a166e1286780548e65e0df2c71ab3cdac02a1647f0a94ae1b09cfa5  SmartCart/Views/Settings/SettingsView.swift

## Prüfbasis

- base: 9ee68452809cb0f20f994508e387dca58d802efc
- blob:ea3a0a83ba9396641057b57e4da03943ece289b7  CLAUDE.md
- blob:49fa3f0b924a6586a5367e7348dba99e4ebdd821  RestockTests/OpenPricesContributionTests.swift
- blob:970cea9130109ea24481df6c49476cb3cc84d935  RestockUITests/RestockUITests.swift
- blob:308c2f69c6cb7aeb926a28a4396940a88ca27b18  SmartCart/Services/OpenPricesContributionService.swift
- blob:d237a6c23b63a8e052bd31eaa8c505038e0799c8  SmartCart/Views/Settings/SettingsView.swift

## Geprüfte Dateien

- sha256:6ddbb14372793c0c28e1c832209fceb976e552fc42d32d5cdcbec658c7403dee  CLAUDE.md
- sha256:2c39eb4fac2c84eaf1708f6c97c94d0cd5081dfe1fd74f47094f2414427134d9  RestockTests/OpenPricesContributionTests.swift
- sha256:b9e69a3169449c999fc07450a95abeaec7ad8243efb7f9b848a7d070f7a03556  RestockUITests/RestockUITests.swift
- sha256:5a7582c8e39cfebbbf4dd16c6532729692ad278441ad11384931d88d38c3e680  SmartCart/Services/OpenPricesContributionService.swift
- sha256:59df407b3a166e1286780548e65e0df2c71ab3cdac02a1647f0a94ae1b09cfa5  SmartCart/Views/Settings/SettingsView.swift

## Prüfbasis

- base: 9ee68452809cb0f20f994508e387dca58d802efc
- blob:ea3a0a83ba9396641057b57e4da03943ece289b7  CLAUDE.md
- blob:49fa3f0b924a6586a5367e7348dba99e4ebdd821  RestockTests/OpenPricesContributionTests.swift
- blob:970cea9130109ea24481df6c49476cb3cc84d935  RestockUITests/RestockUITests.swift
- blob:308c2f69c6cb7aeb926a28a4396940a88ca27b18  SmartCart/Services/OpenPricesContributionService.swift
- blob:d237a6c23b63a8e052bd31eaa8c505038e0799c8  SmartCart/Views/Settings/SettingsView.swift
