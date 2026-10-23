---
entity_id: community-prices-nacharbeiten
type: feature
created: 2026-10-22
updated: 2026-10-22
status: draft
workflow: feat-208-community-nacharbeiten
tags: [feature, community-prices, ui-tests, debug-only, issue-208]
---

# Community-Preise: Nacharbeiten aus #186 (Issue #208)

## Approval

- [ ] Approved

Entscheidungen des PO vom 2026-10-22, hier übernommen und nicht neu verhandelt: **Teil 1 Entwurf A** (der Anfangssatz
„Voreingestellt an.“ entfällt, ein Text für beide Schalterstände, `SettingsView` bleibt unberührt). Teil 2 als
Ersatz-Datenbank per DEBUG-Argument, Teil 3 als reine Löschung. Der Intake-Kontext hat den Umfang akzeptiert: gemeinsames
Ziel „Community-Preis-Teil stimmig, keine Fremddaten“, Bündel unter 250 Zeilen, dafür über dem Dateilimit (siehe Scope).
Quellen: `docs/context/feat-208-community-nacharbeiten.md`, Entwurfsvorschau
`docs/artifacts/feat-208-community-nacharbeiten/entwurfsvorschau.html`.

## Purpose

Drei Reste aus #186, die dasselbe Ziel haben:

1. Die Fußnote unter dem Schalter „Preise anonym mit anderen teilen“ beginnt mit „Voreingestellt an.“ und widerspricht
   damit dem Schalter, sobald er auf aus steht.
2. Vier UI-Klassen (`ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, `DynamicTypeUITests`,
   `CommunityShareNoticeUITests`) erreichen eine der beiden Sendestellen (`holdForNoticeOrSend`, „Weiter teilen“) und
   könnten bei Standard-Schalter echte `CommunityPrice`-Records an die CloudKit-Entwicklungsumgebung schicken. Das sind
   Fremddaten im Pool, die keine Nutzer erzeugt haben.
3. Die Einzel-Überladung `contributeInBackground(_ contribution:)` hat seit #186 keinen Aufrufer mehr.

Hat es bisher funktioniert? Es ist keine Verschlechterung des Produkts: Teil 1 besteht seit #183, Teil 2 seit #163
(Tests senden, seit sie Bons speichern), Teil 3 seit #186. Ob der Versand aus dem Simulator tatsächlich ankommt, ist
nicht belegt (CI-Simulator ohne iCloud-Konto scheitert vermutlich mit `notAuthenticated`; lokal mit Konto nicht
gemessen). Die Spec behebt deshalb den Weg, nicht eine gemessene Schadensmenge.

## Lösung

### Teil 1: eine Fußnote für beide Schalterstände (Entwurf A)

`settings.community.footer` verliert den Anfangssatz. Ein Text, unabhängig vom Schalter.

| Sprache | Neuer Wert |
|---------|------------|
| de | Teilt beim Bon-Scan und bei „Preis eintragen“ nur Artikel, Ladenkette, Preis und Datum – ohne Namen, Foto oder Filiale. Preise anderer Nutzer erscheinen als „Community“. |
| en | When scanning a receipt or entering a price, shares only item, store chain, price and date – no name, photo or branch. Other users' prices appear as “Community”. |

Keine Platzhalter, `SettingsView.swift` bleibt unverändert (liest weiter denselben Schlüssel).

### Teil 2: Ersatz-Datenbank für UI-Tests

- Neue Datei `SmartCart/Services/DiscardingCommunityPriceDatabase.swift`, ganz in `#if DEBUG`. Der Typ
  `DiscardingCommunityPriceDatabase: CommunityPriceDatabase` verwirft `save(_:)`, erhöht dabei den Zähler
  `UserDefaults.standard["communityPricesDiscardedSaveCount"]` um 1 und gibt den übergebenen Record zurück. Beide
  Fetch-Methoden liefern `[]`. Der Schlüssel steht als `static let countKey` am Typ und existiert nur in DEBUG.
- `CommunityPriceService.shared` wählt die Datenbank über `static func defaultDatabase(arguments: [String]) ->
  CommunityPriceDatabase`, Muster `PremiumService.defaultStore(arguments:)`: Unter `#if DEBUG` und mit dem Argument
  `-discardCommunityPricesForUITests` liefert sie `DiscardingCommunityPriceDatabase()`, sonst
  `CKContainer(identifier: containerID).publicCloudDatabase`. Im Release-Build ist der DEBUG-Zweig nicht kompiliert.
- `SmartCartApp.init()` bekommt den DEBUG-Aufräumer `-clearDiscardedCommunityPricesForUITests`, der den Zähler aus
  `UserDefaults.standard` entfernt (Aufruf neben `clearCommunityPricesNoticeForUITestsIfNeeded`, Zeile ca. 36).
- Die vier Klassen übergeben `-discardCommunityPricesForUITests`: in `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`
  und `DynamicTypeUITests` überall dort, wo `-communityPricesNoticeShown YES` steht (Zeilen ca. 113, 155, 839 / 55 / 190),
  in `CommunityShareNoticeUITests` in `openedReview(freshNotice:)` und im Aufräum-Start. Jede dieser Klassen hängt im
  `tearDown()` `-clearDiscardedCommunityPricesForUITests` an einen Aufräum-Start (die Klasse
  `CommunityShareNoticeUITests` hat ihn schon in `Self.cleanup`, dort ergänzt).
- Der Schalter bleibt unberührt: `CommunityShareNoticeUITests` fährt den echten Hinweisablauf („Weiter teilen“ sendet an
  die Ersatz-Datenbank statt ins Netz). Sie setzt weiter nie `-communityPricesNoticeShown` und nie
  `-communityPricesSharingEnabled` (Argument-Domain-Falle aus #186).
- Strukturtest `scripts/test_ui_tests_discard_community_prices.py` (Python, ohne Abhängigkeiten, Muster
  `scripts/test_ci_notification_permission.py`): (a) jede Datei in `RestockUITests/`, die `-communityPricesNoticeShown`
  setzt oder die Zeichenkette „Weiter teilen“ enthält, enthält auch `-discardCommunityPricesForUITests`; (b) jede Datei,
  die `-discardCommunityPricesForUITests` enthält, enthält auch `-clearDiscardedCommunityPricesForUITests`; (c)
  `SmartCartApp.swift` kennt das Aufräum-Argument und `CommunityPriceService.swift` kennt das Argument
  `-discardCommunityPricesForUITests`. Der Test erfasst damit künftige Klassen, die das Muster nutzen; eine Klasse, die
  weder den Merker noch „Weiter teilen“ erwähnt, aber anders an die Sendestellen gelangt, erfasst er nicht.

**Messbarkeit (ehrliche Variante).** Der UI-Test-Prozess hat ein anderes `UserDefaults.standard` als die App, er kann den
Zähler nicht lesen, und ein Sichtbarmachen in der Oberfläche würde Produktcode für den Test einführen. Gewählt: Der
Beleg „die Ersatz-Datenbank verwirft und zählt, und die Auswahl greift“ kommt aus Unit-Tests (AC-4 bis AC-6). Dass die
vier UI-Klassen das Argument tatsächlich übergeben, sichert der Strukturtest (AC-7). Dass in einem echten UI-Lauf kein
Record an CloudKit geht, ist damit **nicht gemessen**, nur durch Konstruktion (Auswahl am einzigen Erzeugungsort von
`shared`) begründet; siehe offene Grenzen.

### Teil 3: toter Code

`nonisolated func contributeInBackground(_ contribution: Contribution)` (Zeile ca. 179) wird gelöscht. Die
Listen-Überladung `contributeInBackground(_ list: [Contribution])` bleibt.

## Source

- **File:** `SmartCart/Services/CommunityPriceService.swift`, `SmartCart/Services/DiscardingCommunityPriceDatabase.swift` (neu),
  `SmartCart/SmartCartApp.swift`, `SmartCart/Resources/{de,en}.lproj/Localizable.strings`
- **Identifier:** `CommunityPriceService.defaultDatabase(arguments:)`, `DiscardingCommunityPriceDatabase`,
  `DiscardingCommunityPriceDatabase.countKey`, `SmartCartApp.clearDiscardedCommunityPricesForUITestsIfNeeded()`,
  Schlüssel `settings.community.footer`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CommunityPriceDatabase` (Protokoll) | Naht | Wird von `DiscardingCommunityPriceDatabase` erfüllt, `CKDatabase` bleibt die Produktion |
| `PremiumService.defaultStore(arguments:)` | Muster | Auswahl per DEBUG-Argument, unbekannt → Produktion |
| `CommunityShareNotice.swift` (Zeilen 26, 63) | Aufrufer | beide Sendestellen laufen über `shared.contributeInBackground(list)`, unverändert |
| `LocalizationKeyParityTests` | Test | Schlüssel- und Platzhaltergleichheit de/en |
| `SmartCartApp` DEBUG-Aufräumer | Muster | `clearCommunityPricesNoticeForUITestsIfNeeded` |

## Scope

- **Affected Files:**

| Datei | Änderung |
|-------|----------|
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY: Fußnote (Zeile 421), zusammen eine Datei-Gruppe |
| `SmartCart/Services/CommunityPriceService.swift` | MODIFY: `defaultDatabase(arguments:)`, `shared` nutzt sie, Einzel-Überladung löschen |
| `SmartCart/Services/DiscardingCommunityPriceDatabase.swift` | CREATE (DEBUG) + `Restock.xcodeproj/project.pbxproj` an vier Stellen, nur App-Ziel |
| `SmartCart/SmartCartApp.swift` | MODIFY: Aufräumer |
| `RestockUITests/ReceiptReviewUITests.swift`, `ReceiptResolutionStatsUITests.swift`, `DynamicTypeUITests.swift`, `CommunityShareNoticeUITests.swift` | MODIFY: Argument und Aufräumer |
| `RestockTests/CommunityPriceTests.swift` | MODIFY: Unit-Tests |
| `scripts/test_ui_tests_discard_community_prices.py` | CREATE: Strukturtest |

- **Estimated Changes:** ca. +150/−15 Zeilen. Gezählt sind etwa 9 Dateien mit den zwei Strings-Dateien als eine Gruppe
  (insgesamt 13 Dateien einzeln, darunter `project.pbxproj`), also über dem Limit von 4–5 Dateien; die Zeilenzahl liegt
  unter ±250. Der PO hat den Umfang im Intake-Kontext akzeptiert (ein gemeinsames Ziel, Regel „Folgearbeit bündeln“).

## Expected Behavior

- **Input:** Nutzer öffnet Einstellungen; UI-Tests starten die App mit `-discardCommunityPricesForUITests`.
- **Output:** Die Fußnote beginnt mit „Teilt beim Bon-Scan …“ bei Schalter an wie aus. Mit dem Argument (nur DEBUG) geht
  kein Beitrag ins Netz, stattdessen steigt der Zähler. Ohne das Argument und in jedem Release-Build ist das Verhalten
  gegenüber #186 unverändert.
- **Side effects:** In DEBUG und nur mit dem Argument entsteht der Schlüssel `communityPricesDiscardedSaveCount` in
  `UserDefaults.standard`, Aufräumer `-clearDiscardedCommunityPricesForUITests`. Keine neuen `@AppStorage`-Schlüssel,
  keine Info.plist-Änderung, keine neuen Berechtigungen, keine Audio-Dateien.

## Nicht im Umfang

- Keine Fußnote nach Schalterstand, keine Änderung an `SettingsView`.
- Kein Zähler in der Oberfläche, keine Änderung an Hinweisablauf, Aggregat, Pool oder Schema.
- Keine Bereinigung bereits in CloudKit-Development liegender Test-Records (eigener Eingriff im Dashboard, falls der PO
  ihn will).
- Kein globales Argument für alle UI-Klassen.

## Alternativen

- **Standard „aus“ in DEBUG-Bauten:** schlösse jeden Versand der Tests aus, ändert aber das geprüfte Produktverhalten, und
  der Hinweisablauf wäre in `CommunityShareNoticeUITests` nicht mehr fahrbar. Verworfen; gekippt würde die Entscheidung
  „Standard an“ (#183) nur für DEBUG.
- **Das Argument in allen UI-Klassen:** deckt auch künftige Klassen ab, berührt aber alle Dateien ohne Sendeweg und
  bringt Vergessensgefahr bei jeder neuen Klasse. Verworfen; der Strukturtest fängt neue Klassen mit dem Muster.
- **Fußnote nach Schalterstand (Alternative B):** zwei Texte, genauer, aber `SettingsView` und ein Schlüssel mehr. Vom PO
  verworfen.
- **Ersatz-Datenbank bei jedem `…ForUITests`-Argument:** erfasst fast alle Klassen ohne Änderung, koppelt aber die
  Datenbankwahl an eine Namenskonvention, die nichts mit dem Versand zu tun hat. Nicht gewählt.
- **Zähler in der App-Gruppe und Auslesen per App-Start mit eigenem Argument:** machte den Versand im UI-Lauf messbar,
  kostet aber ein weiteres Lese-Argument und App-Gruppen-Zustand. Nicht gewählt; offene Grenze unten.

## Test Plan

Unit-Tests in `RestockTests/CommunityPriceTests.swift` (Zähler-Tests mit `UserDefaults.standard` räumen den Schlüssel in
`setUp`/`tearDown` und prüfen, dass er danach fehlt):

| Name | Prüft |
|------|-------|
| U1 `testFooterDoesNotStartWithDefaultOnSentence` | AC-1 |
| U2 `testFooterIsSameTextRegardlessOfSwitch` | AC-2 |
| U3 `testDefaultDatabaseWithDiscardArgumentIsDiscarding` | AC-4 |
| U4 `testDefaultDatabaseWithoutOrUnknownArgumentIsCloudKit` | AC-4 |
| U5 `testDiscardingDatabaseCountsAndDiscards` | AC-5 |
| U6 `testContributionThroughDiscardingServiceNeverReachesFakeAndCounts` | AC-6 |

U1 und U2 lesen die kompilierten Strings über `Bundle(for: CommunityPriceService.self)` (kein Einstellungs-UI-Test
existiert, an den sich ein UI-Beleg ohne neue Klasse andocken ließe; der Text steht in `Text(String(localized:))` ohne
Zustandsabhängigkeit). `LocalizationKeyParityTests` bleibt unverändert und deckt Schlüssel- und Platzhaltergleichheit.

Strukturtest: `python3 scripts/test_ui_tests_discard_community_prices.py` (AC-7). Release-Nachweis (AC-8):
`strings` auf das Release-Binary, Muster `docs/artifacts/test-145-d4-kauf-wiederherstellen/release-strings-check.txt`,
abgelegt unter `docs/artifacts/feat-208-community-nacharbeiten/release-strings-check.txt`, mit Gegenprobe im
Debug-Binary (`Restock.debug.dylib`).

## Acceptance Criteria

- **AC-1:** [Unit] GIVEN die kompilierte Tabelle `de` und `en` WHEN `settings.community.footer` gelesen wird THEN beginnt der Text weder mit „Voreingestellt an.“ noch mit „On by default.“ und enthält das Wort „Community“. Test: `CommunityPriceTests::testFooterDoesNotStartWithDefaultOnSentence`
- **AC-2:** [Unit] GIVEN Schalter an oder aus WHEN die Fußnote gelesen wird THEN ist es derselbe, einzige Schlüssel und Text (kein zweiter Fußnoten-Schlüssel in der Tabelle, Schlüssel- und Platzhalterparität de/en bleibt). Test: `CommunityPriceTests::testFooterIsSameTextRegardlessOfSwitch`, `LocalizationKeyParityTests`
- **AC-3:** [Unit] GIVEN die Einzel-Überladung wurde gelöscht WHEN die Unit-Suite läuft THEN kompiliert alles, `contributeInBackground(_: [Contribution])` bleibt, und die bestehenden `CommunityPriceTests` bleiben grün. Test: gesamte Unit-Suite im gemeinsamen Lauf
- **AC-4:** [Unit] GIVEN `defaultDatabase(arguments:)` WHEN `-discardCommunityPricesForUITests` übergeben wird THEN ist das Ergebnis eine `DiscardingCommunityPriceDatabase`; ohne das Argument oder mit einem unbekannten Argument ist es kein solcher Typ (Produktionsdatenbank). Test: `CommunityPriceTests::testDefaultDatabaseWithDiscardArgumentIsDiscarding`, `CommunityPriceTests::testDefaultDatabaseWithoutOrUnknownArgumentIsCloudKit`
- **AC-5:** [Unit] GIVEN eine `DiscardingCommunityPriceDatabase` WHEN `save` zweimal aufgerufen wird THEN steht der Zähler `communityPricesDiscardedSaveCount` auf 2, jeder Aufruf gibt den übergebenen Record zurück, die Fetch-Methoden liefern leere Listen. Test: `CommunityPriceTests::testDiscardingDatabaseCountsAndDiscards`
- **AC-6:** [Unit] GIVEN ein `CommunityPriceService` mit der Ersatz-Datenbank und Schalter an WHEN ein teilbarer Beitrag gesendet wird THEN steigt der Zähler um 1 und keine Fake-Produktionsdatenbank erhält einen Record. Test: `CommunityPriceTests::testContributionThroughDiscardingServiceNeverReachesFakeAndCounts`
- **AC-7:** [Struktur] GIVEN `RestockUITests/` WHEN der Strukturtest läuft THEN enthält jede Datei mit `-communityPricesNoticeShown` oder „Weiter teilen“ auch `-discardCommunityPricesForUITests`, jede Datei mit diesem Argument auch `-clearDiscardedCommunityPricesForUITests`, und `SmartCartApp.swift` kennt das Aufräum-Argument. Test: `scripts/test_ui_tests_discard_community_prices.py` (erwartet vorher rot, danach grün)
- **AC-8:** [Beleg] GIVEN der Release-Build WHEN `strings` auf das Release-Binary läuft THEN kommen weder `-discardCommunityPricesForUITests`, `-clearDiscardedCommunityPricesForUITests`, `communityPricesDiscardedSaveCount` noch `DiscardingCommunityPriceDatabase` vor; die Gegenprobe im Debug-Binary findet sie. Beleg: `docs/artifacts/feat-208-community-nacharbeiten/release-strings-check.txt`
- **AC-9:** [UI] GIVEN die vier Klassen WHEN sie mit dem Argument laufen THEN bleiben sie unverändert grün, auch der Hinweisablauf (Hinweis, „Weiter teilen“, „Nicht teilen“, Schalterstand). Test: `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, `DynamicTypeUITests`, `CommunityShareNoticeUITests` im gemeinsamen Lauf
- **AC-10:** [Beleg] GIVEN die App läuft im Simulator `Restock-Validate` mit dem Stand WHEN die Einstellungen geöffnet werden THEN zeigt die Fußnote den neuen Text bei Schalter an und bei Schalter aus. Beleg: Bildschirmfotos aus dem echten Lauf unter `docs/artifacts/feat-208-community-nacharbeiten/`
- **AC-11:** [Unit/UI] GIVEN der Bestand WHEN die Regression läuft THEN bleiben Unit-Suite und alle UI-Klassen grün; `RestockShareExtension/` und `SmartCartWidgets/` bleiben unverändert. Test: Unit- und UI-Suite im gemeinsamen Lauf
- **AC-12:** [Gerät, offene Grenze, kein Gate] Auf Hennings Gerät ist nichts geprüft. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.

## Known Limitations (offene Grenzen)

- In einem echten UI-Lauf ist nicht gemessen, dass kein Record an CloudKit geht: Der UI-Prozess kann den Zähler der App
  nicht lesen. Belegt sind nur die Auswahl und das Zählen/Verwerfen (Unit), die Übergabe des Arguments in den vier
  Klassen (Struktur) und das Fehlen im Release (strings).
- Es ist nicht belegt, dass der Versand aus UI-Läufen bisher je ankam (CI ohne iCloud-Konto vermutlich
  `notAuthenticated`, lokal nicht gemessen). Bereits vorhandene Test-Records in CloudKit-Development bleiben.
- Der Strukturtest erfasst nur Klassen, die `-communityPricesNoticeShown` oder „Weiter teilen“ verwenden. Eine künftige
  Klasse, die die Sendestellen auf anderem Weg erreicht, wird nicht erfasst.
- Kein Einstellungs-UI-Test für die Fußnote; der Text ist per Unit-Test auf die kompilierten Strings und im
  Simulator-Durchlauf (AC-10) belegt.
- Nichts auf Hennings Geräten geprüft (AC-12).

## Doku-Änderungen

- `CLAUDE.md` (Projekt), Absatz „Erst-Hinweis vor dem ersten Preisbeitrag“: Ergänzung zu `-discardCommunityPricesForUITests`
  und `-clearDiscardedCommunityPricesForUITests` (Ersatz-Datenbank, Zähler `communityPricesDiscardedSaveCount`, nur
  DEBUG, Aufräumer Pflicht) und dass die Bestands-Klassen mit Merker das Argument mit übergeben.
- `docs/specs/services/community-prices-erst-hinweis.md`, Abschnitt „Known Limitations“: Der Nebenbefund „Bestands-UI-Tests
  senden heute … echte Beiträge“ verweist auf diese Spec. Diese Änderungen führt der Developer in Phase 6 durch.

## Risiken / Grenzfälle

- Argument-Domain-Falle: Die neuen Argumente sind reine Schalter ohne Wert und erzeugen keinen Zustand außer dem Zähler;
  sie überlagern keinen Schlüssel, den die App schreibt.
- `shared` ist ein `static let`: Die Wahl fällt einmal beim ersten Zugriff. Der Prozess liest seine Argumente beim Start,
  also gilt sie für den ganzen Lauf.
- Der Zähler überlebt einen Lauf in `UserDefaults.standard` der App; ohne Aufräumer sähen spätere Läufe einen Altwert.
  Deshalb ist der Aufräumer im `tearDown()` Pflicht und Teil des Strukturtests.
- Neue Swift-Datei `DiscardingCommunityPriceDatabase.swift` in `project.pbxproj` an den vier Stellen (Projektregel),
  nur im App-Ziel; Widget- und Erweiterungsziele kompilieren sie nicht, `CommunityPriceService.swift` darf sie dort nicht
  verwenden (alles unter `#if DEBUG`, und die Datei, die den Typ nennt, liegt nur im App-Ziel; falls
  `CommunityPriceService.swift` in einem weiteren Ziel kompiliert wird, bleibt der Verweis hinter `#if DEBUG` und der Build
  jedes Ziels wird geprüft).

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion ist durch Test oder Werkzeug-Artefakt belegt; AC-12 (Gerät) ist als offene Grenze genannt
- [ ] Die Fußnote hat keinen Widerspruch mehr zum Schalter, kein UI-Lauf kann über die vier Klassen per Konstruktion echte Beiträge senden
- [ ] Die App ist im Simulator gestartet und die Einstellungen sind angesehen (AC-10)
- [ ] Regressionslauf grün (AC-9, AC-11), Release-Nachweis liegt vor (AC-8)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Dieselbe Naht (`CommunityPriceDatabase`) und dasselbe Auswahlmuster wie bei `PremiumService.defaultStore`;
  keine neue Schicht, nur DEBUG.

## Changelog

- 2026-10-22: Initial spec created (Issue #208, Entwurf A freigegeben)
