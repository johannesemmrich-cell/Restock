# Adversary-Dialog Issue #208 (feat-208-community-nacharbeiten)

Prüfer: implementation-validator. Eigener Lauf des Prüfers: Strukturtest (5/5 OK). Kein eigener xcodebuild- oder
Simulator-Lauf; nichts auf Hennings Geräten.

### Runde 1: Diff, Code, Strukturtest, Artefakte

Artefakte: `test-green-output.txt` "Executed 680 tests, with 0 failures", TEST SUCCEEDED. `ui-test-ac9-output.txt`
3 + 2 + 4 + 23 = 32 Tests, 0 Fehler. `release-strings-check.txt`: Release 0 Treffer, Debug je 1 Treffer.

Confirmation: AC-1
Code reference: SmartCart/Resources/de.lproj/Localizable.strings
Evidence: Anfangssatz "Voreingestellt an." weg, Text enthält "Community"; Bildschirmfotos zeigen denselben Wortlaut.
Status: CONFIRMED

Confirmation: AC-1 (en)
Code reference: SmartCart/Resources/en.lproj/Localizable.strings
Evidence: "On by default." weg, "Community" enthalten, Syntax korrekt, kein Platzhalter. U1 in RestockTests/CommunityPriceTests.swift:631.
Status: CONFIRMED

Confirmation: AC-2
Code reference: RestockTests/CommunityPriceTests.swift
Evidence: Genau ein Schlüssel `settings.community.footer` (U2, Zeile 640); Parität durch LocalizationKeyParityTests im grünen 680er-Lauf.
Status: CONFIRMED

Confirmation: AC-3
Code reference: SmartCart/Services/CommunityPriceService.swift
Evidence: Einzel-Überladung gelöscht, Listen-Überladung bleibt (Zeile 202); beide Aufrufer in CommunityShareNotice.swift (Zeilen 26, 63) übergeben ein Array; Grep ohne Einzelverwendung.
Status: CONFIRMED

Confirmation: AC-4
Code reference: SmartCart/Services/CommunityPriceService.swift
Evidence: `defaultDatabase(arguments:)` (Zeile 102) wählt die Ersatz-Datenbank nur in `#if DEBUG` und nur bei exakt `-discardCommunityPricesForUITests`; U3 und U4 (Zeilen 651, 657) prüfen auch ein unbekanntes Argument.
Status: CONFIRMED

Confirmation: AC-5
Code reference: SmartCart/Services/DiscardingCommunityPriceDatabase.swift
Evidence: Datei ganz in `#if DEBUG`, auch der Zähler-Schlüssel; save zählt und gibt Record zurück, Fetches liefern `[]`; U5 grün.
Status: CONFIRMED

Confirmation: AC-6
Code reference: RestockTests/CommunityPriceTests.swift
Evidence: U6 im grünen Unit-Lauf; Zähler vorher und nachher bereinigt.
Status: CONFIRMED

Confirmation: AC-7
Code reference: scripts/test_ui_tests_discard_community_prices.py
Evidence: 5 Tests grün; Prüfung generisch über RestockUITests/*.swift.
Status: CONFIRMED

Confirmation: AC-8
Code reference: docs/artifacts/feat-208-community-nacharbeiten/release-strings-check.txt
Evidence: Release 0 Treffer bei allen vier Mustern, Debug-Gegenprobe je 1 Treffer.
Status: CONFIRMED

Confirmation: AC-9
Code reference: docs/artifacts/feat-208-community-nacharbeiten/ui-test-ac9-output.txt
Evidence: 32 von 32 grün, einschließlich Weiter teilen, Nicht teilen, zweites Speichern ohne Hinweis.
Status: CONFIRMED

Confirmation: AC-10
Code reference: docs/artifacts/feat-208-community-nacharbeiten/ac10-einstellungen-schalter-an.png
Evidence: Schalter an, darunter der neue Text; Lauf `ac10-durchlauf-output.txt` endet mit Executed 1 test, TEST SUCCEEDED.
Status: CONFIRMED

Confirmation: AC-10 (aus)
Code reference: docs/artifacts/feat-208-community-nacharbeiten/ac10-einstellungen-schalter-aus.png
Evidence: Schalter aus, derselbe Text.
Status: CONFIRMED

Confirmation: AC-11
Code reference: docs/artifacts/feat-208-community-nacharbeiten/test-green-output.txt
Evidence: Unit-Suite grün (680). RestockShareExtension/ und SmartCartWidgets/ unverändert. Die neue Datei steht in project.pbxproj nur in Sources des App-Ziels (Zeile 1139), CommunityPriceService.swift ebenfalls nur dort. Gesamtlauf der UI-Suite siehe F002.
Status: CONFIRMED (Unit-Suite; UI-Gesamtlauf siehe F002)

### Runde 2: gezielte Lückensuche

1. Clear-Argument im tearDown: ReceiptReviewUITests (Zeile 103), ReceiptResolutionStatsUITests (Zeile 34), DynamicTypeUITests (Zeile 34) übergeben `-clearDiscardedCommunityPricesForUITests`; CommunityShareNoticeUITests über die Cleanup-Liste.
Code reference: RestockUITests/ReceiptReviewUITests.swift
Code reference: RestockUITests/ReceiptResolutionStatsUITests.swift
Code reference: RestockUITests/DynamicTypeUITests.swift
Code reference: RestockUITests/CommunityShareNoticeUITests.swift

2. Weitere UI-Dateien mit "Weiter teilen", `-communityPricesNoticeShown` oder Bon-Seed: nur die vier Klassen (AddItemQuantitySuggestionUITests nur in einem Kommentar). Alle sechs Bon-Starts tragen das Discard-Argument; der Dev-Modus-Start in DynamicTypeUITests.swift:143 speichert keinen Bon.

3. `#if DEBUG` im Zweig defaultDatabase geklammert, Release-Nachweis bestätigt es; der Aufräumer in SmartCartApp.swift steht im DEBUG-Block.
Code reference: SmartCart/SmartCartApp.swift

4. Fußnote ohne `%`-Platzhalter, typografische Anführungszeichen korrekt, Wortlaut gleich Spec.
Code reference: Restock.xcodeproj/project.pbxproj

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/ReceiptReviewUITests.swift:838
  Description: Kein UI-Test liest den Zähler aus; dass im UI-Lauf nichts an CloudKit geht, ist abgeleitet (Strukturtest, Unit AC-4 bis AC-6), nicht gemessen.
  Spec requirement: Spec-Abschnitt "Messbarkeit"; die Spec nennt diese Grenze selbst.
  Remediation: Optional später; kein Blocker.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-208-community-nacharbeiten/test-green-output.txt:1748
  Description: Gesamtlauf der UI-Suite liegt nicht vor; nur vier Klassen (32 Tests) lokal. Rest unverändert, belegt erst die CI des PR.
  Spec requirement: AC-11
  Remediation: CI-Ergebnis des PR vor dem Merge abwarten.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: CLAUDE.md
  Description: CLAUDE.md und community-prices-erst-hinweis.md sind (gewollt, laut Spec) mitgeändert; `.claude/gate-events.jsonl` gehört nicht in den Commit.
  Spec requirement: keine
  Remediation: gate-events.jsonl nicht committen.

AC-12 (Gerät) bleibt offene Grenze: am Gerät nicht belegt.

Code reference: SmartCart/Services/CommunityPriceService.swift
Code reference: SmartCart/Services/DiscardingCommunityPriceDatabase.swift
Code reference: docs/specs/services/community-prices-erst-hinweis.md

VERDICT: VERIFIED
Checklist: 11/11 Gate-Punkte bewiesen. Vorbehalt F002: UI-Gesamtlauf nur als CI-Beleg nach dem PR.

## Geprüfte Dateien

- sha256:2608be272b751cc3ff051efa50bd036b47e92c579cbe982f81a71c3ee5027813  CLAUDE.md
- sha256:66dd4918bc68e62d0cf8568acb3f95edb9c2d70769773805248d158ba0fdc2e7  Restock.xcodeproj/project.pbxproj
- sha256:d42d10e16feb42addfdb757cdbc5ee717dde83bbd6cdd952f1f964565244013c  RestockTests/CommunityPriceTests.swift
- sha256:29978d7d3ff70790a4696e3d0a37a4a10280b299d234d52ef3d4f71540350b69  RestockUITests/CommunityShareNoticeUITests.swift
- sha256:76c055e286ef12df0909f7613309b36c103984881a45e5efc52bd5d1b4372356  RestockUITests/DynamicTypeUITests.swift
- sha256:23d7f23b9307d9f98c0fa4154644fade61e3ba7748c65b08ef374c23babd3ac6  RestockUITests/ReceiptResolutionStatsUITests.swift
- sha256:3346ac6e8809901581525df83b6d490e0559882552b0d931860b231a19894b91  RestockUITests/ReceiptReviewUITests.swift
- sha256:5256c992e5e6f250b4ba0f2aa58fac496c73285d92cf8aa1fb35ad6f1e5f64bf  SmartCart/Resources/de.lproj/Localizable.strings
- sha256:7b5172533eda7a4d61886ab78ae9d3d951d0f286a2888ecb51f4706d2a6b0f1e  SmartCart/Resources/en.lproj/Localizable.strings
- sha256:c4fa4ea545f196d37af9cffad1d6ec365f8261e34f62af6f772a3b568e17eb19  SmartCart/Services/CommunityPriceService.swift
- sha256:69f1f690ae012b08bf6a51dac1d7ac1c20ae435685311d3d735a03d40885f586  SmartCart/Services/DiscardingCommunityPriceDatabase.swift
- sha256:0917c0610ca7e57ade12ff021c49e7c187aed9863305ad1892df124e349028e2  SmartCart/SmartCartApp.swift
- sha256:f7884aab005a03a360b93fb1326e6eeda7ccf00f1f40a88be42809357c289a41  docs/artifacts/feat-208-community-nacharbeiten/ac10-einstellungen-schalter-an.png
- sha256:920867719ab9598c98454de7e94c5553c409890aa664699b010fe367204b468a  docs/artifacts/feat-208-community-nacharbeiten/ac10-einstellungen-schalter-aus.png
- sha256:0e4eb1123c459e639be03c0a984582109f59d27c89e75422ee0475dba278e41e  docs/artifacts/feat-208-community-nacharbeiten/release-strings-check.txt
- sha256:00690e02864815035887031a99102003eb161631205046140d94384d5b458799  docs/artifacts/feat-208-community-nacharbeiten/test-green-output.txt
- sha256:cd93b8f97d37645c93bf859f92c834dfbc464da2efacda911a45d22138e8ae60  docs/artifacts/feat-208-community-nacharbeiten/ui-test-ac9-output.txt
- sha256:908b53cff282229d181e5e90e11441a3227d7b00baad56c4accc41f838336b3c  docs/specs/services/community-prices-erst-hinweis.md
- sha256:6514770a083afb7ce5460d8778cb5aefe99df407899e00abc30a58afbc4f5a73  scripts/test_ui_tests_discard_community_prices.py

## Prüfbasis

- base: 290bd107c305c1c30bc91876a912cd406d7281c7
- blob:d874af51a96aa7a3ac249223ee7dbc6ddad55eef  CLAUDE.md
- blob:ffe27a25c52e1ac371723a1b5ef50cdb713a667f  Restock.xcodeproj/project.pbxproj
- blob:647286e3064578cf70f9658a3854baf196cdda98  RestockTests/CommunityPriceTests.swift
- blob:203454e9f5ac113661f56b8bdf4adea0adde4a20  RestockUITests/CommunityShareNoticeUITests.swift
- blob:8c784246eba8d5c81f219eefe2e95cf06b9696e0  RestockUITests/DynamicTypeUITests.swift
- blob:9d24f50b6436f316d1a046fd74336fda458f31f3  RestockUITests/ReceiptResolutionStatsUITests.swift
- blob:8dff3299ab053e01f64abf0a45b4553457467396  RestockUITests/ReceiptReviewUITests.swift
- blob:4f008cc8abe2bc22d052698495da6891ef733cb0  SmartCart/Resources/de.lproj/Localizable.strings
- blob:2aa9c1cefdf2644c446087e519cff8eb61c01afb  SmartCart/Resources/en.lproj/Localizable.strings
- blob:06411de3948e90994d713c2b715896839a134f64  SmartCart/Services/CommunityPriceService.swift
- blob:3804a6f95eddd1722651a57d31d2b97463dbccdb  SmartCart/Services/DiscardingCommunityPriceDatabase.swift
- blob:2e5f4203de79cd7aa66a7b47349fd660f2b88292  SmartCart/SmartCartApp.swift
- blob:379ac136bd397d4e3969c6889e31b608ea508824  docs/artifacts/feat-208-community-nacharbeiten/ac10-einstellungen-schalter-an.png
- blob:bff2f6d8538efa39b996e74d7af571246b6536e3  docs/artifacts/feat-208-community-nacharbeiten/ac10-einstellungen-schalter-aus.png
- blob:aeb3fa7d81a5434a26e01a1da76466c655c0f71b  docs/artifacts/feat-208-community-nacharbeiten/release-strings-check.txt
- blob:df00f052d7af3b03ce058cc7f306ce544db2b7db  docs/artifacts/feat-208-community-nacharbeiten/test-green-output.txt
- blob:b5d9c439476c8e7666bd4891f3262339d63ea26b  docs/artifacts/feat-208-community-nacharbeiten/ui-test-ac9-output.txt
- blob:05f8ba56d8aecc60d559eaf421ae7260bd0e2f76  docs/specs/services/community-prices-erst-hinweis.md
- blob:a4313097b91dcfd6b45557c9029187cedfc455af  scripts/test_ui_tests_discard_community_prices.py
