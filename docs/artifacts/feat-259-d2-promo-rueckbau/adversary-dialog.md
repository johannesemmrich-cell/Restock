# Adversary Dialog — feat-259-d2-promo-rueckbau
Spec: docs/specs/views/offer-codes-einloesen.md
Datum: 2026-11-05 18:05

## Checkliste
- [x] AC-1: In den Einstellungen gibt es ohne Pro-Freischaltung (`-developerMode NO`) die Zeile mit `accessibilityIdentifier` `settings.redeemCode`; sie existiert, liegt vollständig im Fenster und ist antippbar (`waitUntilHittable()` liefert `matched`).
- [x] AC-2: In der Paywall gibt es nach Hochscrollen den Knopf mit `accessibilityIdentifier` `paywall.redeemCode`; er existiert, liegt vollständig im Fenster, ist antippbar, und steht unterhalb von „Käufe wiederherstellen“ und oberhalb der Rechtslinks (Rahmenvergleich `maxY`/`minY`); dasselbe bei Schrift `AccessibilityXXXL`.
- [x] AC-3: Ein Tipp auf beide Einstiege wird im UI-Test ausgeführt und lässt die App stabil: kein Absturz, `app.state == .runningForeground` und die Oberfläche reagiert danach weiter (Fenster schließbar bzw. Zeile/Knopf wieder antippbar). Ob das System-Fenster im Simulator tatsächlich erscheint, ist kein Teil der Bedingung; es wird nur gemessen und im Testprotokoll vermerkt (Ergebnis kommt in Offene Grenzen).
- [x] AC-4: Ein Unit-Test (`PremiumServiceTests`, `ScriptedPurchaseStore`, `autostart: false`) weist nach: Ohne vorherigen `purchase`/`restore`-Aufruf und ohne Dev-Modus schaltet ein über den Update-Strom eintreffendes Entitlement einer bekannten Produkt-ID (Offer-Code-Einlösung) `hasPremiumAccess` frei; eine unbekannte Produkt-ID schaltet nicht frei.
- [x] AC-5: Das Textfeld für Promo-Codes, der Alert „Code eingelöst“ und die Dev-Zeile „Promo-Codes“ sind aus `SettingsView.swift` entfernt: `grep -in promo SmartCart/Views/Settings/SettingsView.swift` liefert keine Treffer.
- [x] AC-6: Neuer Schlüssel `settings.redeemCode` steht in `de.lproj` und `en.lproj`; `LocalizationKeyParityTests` bleibt grün (gleiche Schlüssel und Platzhalter in beiden Sprachen).
- [x] AC-7: Bestehende Tests `PurchaseUITests` P1–P11 (Hinweis-Hinrollen, „vollständig im Fenster und antippbar“, Chip-Breite) und `PaywallUITests` (Rechtslinks) bleiben grün; die gesamte Unit-Suite ist grün bis auf die zwei bekannten zeitabhängigen Tests `ConsumptionPatternTests.testAveragesRegularPurchaseInterval` und `ConsumptionPatternTests.testDueSoonWhenEstimatedDateIsAboutTwoDaysOut` (Zeitumstellung vom 25.10. im Fenster, bis etwa 15.11.; PO 2026-11-05; Nachweis: `HabitService.swift`, `PurchaseRecord.swift` und `ConsumptionPatternTests.swift` sind gegenüber `origin/main` unverändert); Testzahl und Fehlschläge prüfen, kein Null-Test-Lauf.
- [x] AC-8: Der Debug-Build für den Simulator und der Release-Build (`xcodebuild build -configuration Release`, wie CI-Job `release-build`) kompilieren ohne Fehler.
- [x] AC-9: Benutzen statt nur testen: Die App wurde im Simulator gestartet; Einstellungen und Paywall wurden geöffnet, die Zeile bzw. der Knopf angetippt; Claude prüft je eine Aufnahme (hell, Einstellungen und Paywall) per Bildansicht und vermerkt in `docs/artifacts/feat-259-offer-codes/benutzen-befund.md` je Bild „Einstieg sichtbar, vollständig, lesbar“ und was nach dem Tipp zu sehen war. Aufnahmen entstehen aus einem echten Lauf (XCTAttachment), nicht von Hand.
- [x] AC-10: `grep -rniE "promocode|promo-code|promo code" SmartCart RestockTests RestockUITests docs/appstore project.yml CLAUDE.md` liefert keine Treffer (CloudKit-Schemadatei und `docs/specs`/`BACKLOG.md`/`docs/artifacts` als Historie ausgenommen). Die Dateien `PromoCodeService.swift`, `PromoCodeAdminView.swift`, `PromoCodeServiceTests.swift` existieren nicht mehr.
- [x] AC-11: `grep -c PromoCode Restock.xcodeproj/project.pbxproj` liefert 0; das Projekt lässt sich öffnen und bauen (Debug Simulator und Release Simulator), keine verwaiste Referenz.
- [x] AC-12: `hasValidPromoCode` und `setHasValidPromoCode` kommen im Code nicht mehr vor; `PremiumServiceTests` (inklusive der Offer-Code-Tests aus Durchgang 1) bleiben grün; die Unit-Suite insgesamt grün mit erwarteter Testzahl: Pflicht-Messschritt vor dem Löschen, die Gesamtzahl V der Unit-Suite auf dem Stand von Durchgang 1 (origin/main 7ff7d19) wird gemessen und in `docs/artifacts/feat-259-d2-promo-rueckbau/testzahl-vorher.txt` abgelegt; nach dem Rückbau sind es genau V − 13 Tests (die 13 `func test` von `PromoCodeServiceTests`), 0 Fehlschläge (die zwei bekannten zeitabhängigen `ConsumptionPatternTests` ausgenommen, wie in Durchgang 1).
- [x] AC-13: Der Promo-Absatz fehlt in `LegalView` und in beiden Sprachteilen von `docs/appstore/datenschutz.md`; `python3 scripts/test_asc_texts.py` ist grün (Wortgleichheit LegalView ↔ Seite), `PrivacyManifestTests` ist grün.
- [x] AC-14: Schlüssel `settings.promoCode.*` und `promoCode.error.*` fehlen in beiden `Localizable.strings`; `LocalizationKeyParityTests` bleibt grün; die kompilierten Tabellen (de, en) haben gleich viele Schlüssel; vor dem Rückbau wird die Anzahl N je Sprache gemessen (`grep -c '" = "'`), danach sind es in beiden N−7.
- [x] AC-15: Die Struktur-/Python-Tests der CI (`scripts/test_*.py`, Schritt „Strukturtests (Python)“) laufen grün; ein Test, der den Promo-Pfad oder die gelöschten Dateien noch nennt, wird im selben Durchgang angepasst (Stand 2026-11-05: keine solche Stelle, der Abgleich in `scripts/`, `.github/`, `RestockTests/` und `RestockUITests/` findet nur `promotional_text` und die zu löschende Testdatei).
- [x] AC-16: Nach dem Rückbau schaltet der Offer-Code-Einstieg aus Durchgang 1 weiter dieselbe Kette (UI-Tests `testSettingsRedeemCodeRowExistsAndOpens` und `testPaywallRedeemCodeButtonPositionAndOpens` grün, Einstellungen und Paywall unverändert).
- [x] AC-17: Benutzen statt nur testen: Die App wurde nach dem Rückbau gestartet (frischer Simulator), Einstellungen und Paywall geöffnet; kein Promo-Feld mehr, Dev-Modus-Abschnitt ohne „Promo-Codes“; Befund wie AC-9 in `docs/artifacts/feat-259-offer-codes/benutzen-befund.md`.

## Dialog

### Runde 1
**Adversary:** Diff Zeile fuer Zeile gelesen (11 Dateien, 2 Einfuegungen, 770 Loeschungen). Befunde/Nachfragen:
- N1 (hasPremiumAccess): Wurde `-premiumForScreenshots` beim Entfernen von `hasValidPromoCode` angetastet? Beleg: Diff zeigt nur Entfernen der zwei Promo-Mitglieder und `|| hasValidPromoCode` im Return; der DEBUG-Zweig bleibt. Code reference: SmartCart/Services/PremiumService.swift:143 (Argument `-premiumForScreenshots` unveraendert), :147 (`developerMode || hasPurchasedAccess`).
- N2 (Start): `revalidateLocalRedemption()` in der Startaufgabe entfernt; ausser diesem Aufruf wurden keine Nachbarzeilen (AbbreviatedNameCleanup, CatalogEstimateRefresh, resubscribeAll) beruehrt. Code reference: SmartCart/SmartCartApp.swift:976-978.
- N3 (LegalView): nur der Promo-Absatz samt Leerzeile entfernt; Open-Prices-Absatz folgt direkt auf Community-Preise. Code reference: SmartCart/Views/Settings/LegalView.swift:181-184. datenschutz.md identisch in de und en (je 3 Zeilen), `scripts/test_asc_texts.py` 10 Tests OK (Wortgleichheit).
- N4 (pbxproj): 12 Zeilen entfernt = je PromoCodeService, PromoCodeAdminView, PromoCodeServiceTests: BuildFile, FileReference, Gruppeneintrag, Sources-Eintrag (3x4). Keine fremde Zeile im Diff. `grep -c PromoCode project.pbxproj` = 0. Widget- und Share-Extension-Ziele: `grep -i promo` in RestockShareExtension und SmartCartWidgets leer; project.yml leer (Quellen per Ordner, keine Einzelverweise).
- N5 (Strings): Diff entfernt je Sprache genau 7 Schluessel (settings.promoCode.{placeholder,redeem,redeemedTitle,redeemedMessage}, promoCode.error.{notFound,revoked,redeemedByAnother}); `settings.redeemCode` bleibt. `grep -c '" = "'` = 471 de und en (vorher 478 laut testzahl-vorher.txt). Verwaiste `String(localized: "…promoCode…")`: `grep -rniE promo SmartCart RestockTests RestockUITests project.yml` ohne Treffer.
- N6 (AC-10): grep nach promocode|promo-code|promo code ueber SmartCart, RestockTests, RestockUITests, docs/appstore, project.yml, CLAUDE.md, pbxproj liefert 0 Treffer; einziger Treffer im Repo ausserhalb Historie ist der Strukturtest `scripts/test_promo_removed.py` (zulaessig, ausserhalb der AC-10-Suchpfade; haelt die Dateinamen). Die drei Dateien existieren nicht.
- N7 (CLAUDE.md): einzige Aenderung im Offer-Code-Absatz; kein Rest von „PromoCodeService“. „Promo-Pool“ ist kein Treffer des Musters und sachlich korrekt. Hinweis (LOW, kein Befund): der CloudKit-Typ PromoCode bleibt bewusst im Schema (Spec), Nutzer koennen noch den Schluessel `promoCode.isValid` in UserDefaults haben; er wird nirgends mehr gelesen, ohne Wirkung.
- Nachfrage Q1: Stammen die Messwerte (849, 471) aus dem Endstand? Q2: Sind die UI-Tests AC-16 die richtigen zwei?
**Implementierer:** (nicht erreichbar; Antwort durch Adversary-Nachpruefung in Runde 2)

### Runde 2
**Adversary:** Eigene Belege:
- Q1: Zeitstempel: Quellaenderungen 17:47:48-17:50:07, `unit-vorher-output.txt` 17:49:24 (RED-Stand 37bc8ba, 862 Tests, 2 bekannte Fehlschlaege), `test-green-output.txt` 17:51:45 NACH allen Quelländerungen: „Executed 849 tests, with 2 failures“ = 862-13 (AC-12 ok); die zwei Fehlschlaege sind exakt `testAveragesRegularPurchaseInterval` und `testDueSoonWhenEstimatedDateIsAboutTwoDaysOut` (grep „Test Case … failed“), die dokumentierte Zeitumstellung. Das „TEST FAILED“ der Datei ist damit nur diese zwei; kein Null-Test-Lauf. Debug-Build 17:54 und Release-Build 17:53: je BUILD SUCCEEDED, nach dem Endstand. Code reference: SmartCart/Services/PremiumService.swift:140.
- Q2: `ui-test-output.txt` (17:55): `testPaywallRedeemCodeButtonPositionAndOpens` und `testSettingsRedeemCodeRowExistsAndOpens` passed, 2 Tests, 0 Fehler, TEST SUCCEEDED. AC-16 belegt; Einstieg selbst ist im Diff unveraendert (SettingsView/PaywallView nicht geaendert; Code reference SmartCart/Views/Settings/LegalView.swift:181 ist die einzige Views-Datei im Diff). `settings.redeemCode` weiter in SettingsView.swift:219/230.
- Kompilierbarkeit: ausser den geloeschten Dateien existiert kein Verweis auf PromoCodeService/PromoCodeAdminView/hasValidPromoCode/setHasValidPromoCode (grep 0), Builds gruen -> keine verwaiste Referenz.
- Python-Strukturtests: `python3 -m unittest discover -s scripts -p 'test_*.py'`: 179 Tests, 1 Fehlschlag `test_testflight_workflow.Repository.test_scope` (Zweig mit >5 Dateien/ >250 Zeilen gegen origin/main; in CLAUDE.md als bekannte Zweig-Regel aus #109 dokumentiert, nicht Teil der CI, nicht aus dem Rueckbau). `test_promo_removed.py` 6 OK, `test_asc_texts.py` 10 OK. AC-15 damit erfuellt bis auf diese dokumentierte Ausnahme.
- Versuch zu brechen, ohne Erfolg: (a) Nicht-Promo-Zeilen im Diff: keine; (b) Gate-/Strings-Paritaet: gleiche 471; (c) LegalView-Wortgleichheit: Test gruen; (d) Info.plist/Entitlements: kein Promo-Bezug.
- AC-17: `benutzen-befund.md` existiert bei dieser Pruefung NICHT (Ordner enthaelt nur die genannten Dateien). AC-17 ist offen; wird von einem anderen Agenten erledigt.
**Implementierer:** (nicht erreichbar)

### Bestaetigungen

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: AC-16-Test testSettingsRedeemCodeRowExistsAndOpens grün (ui-test-output.txt), Zeile im Bild einstellungen-vor-tipp.png sichtbar
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: AC-16-Test testPaywallRedeemCodeButtonPositionAndOpens grün, Paywall-Bilder im Benutzen-Befund
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: beide Tipp-Tests grün, App stabil (Benutzen-Lauf: 0 Alerts, App im Vordergrund)
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: PremiumServiceTests inkl. Offer-Code-Tests grün (39 Tests, adversary-test-output.txt)
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: SettingsView.swift in Durchgang 2 unverändert, grep promo dort 0 Treffer (Strukturtest test_promo_removed grün)
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: LocalizationKeyParityTests grün, settings.redeemCode in beiden Sprachen, 471 Schlüssel je Sprache
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: Durchgang-1-Nachweis (gemergt, PR 260); D2 ändert Paywall/Einstellungen nicht; Gesamtlauf 849 Tests, nur 2 bekannte zeitabhängige rot
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: Debug- und Release-Build BUILD SUCCEEDED (debug-/release-build-output.txt)
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: Durchgang-1-Befund docs/artifacts/feat-259-offer-codes/benutzen-befund.md, in D2 durch AC-17 wiederholt
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Views/Settings/LegalView.swift:181
  Evidence: grep 0 Treffer, drei Dateien weg
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/SmartCartApp.swift:978
  Evidence: pbxproj 0x PromoCode, Debug- und Release-Build gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: 849 = 862-13, nur 2 bekannte Fehlschlaege
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Views/Settings/LegalView.swift:183
  Evidence: Absatz in LegalView und beiden Sprachteilen weg, test_asc_texts OK
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Services/PremiumService.swift:143
  Evidence: 471 je Sprache (478-7), -premiumForScreenshots unveraendert
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/SmartCartApp.swift:976
  Evidence: 179 Python-Tests, nur das dokumentierte test_scope rot
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: SmartCart/Views/Settings/LegalView.swift:181
  Evidence: beide UI-Tests passed, Einstieg im Diff unveraendert
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Services/PremiumService.swift:147
  Evidence: benutzen-befund.md plus neun Aufnahmen aus echtem Lauf im frischen Wegwerf-Simulator; Orchestrator hat einstellungen-vor-tipp.png und entwickler-abschnitt-ende.png selbst angesehen: "Code einlösen" unter DATEN sichtbar, kein Promo-Feld, Entwickler-Abschnitt ohne "Promo-Codes"; Baumsuche nach "promo" 0 Treffer auf 14 bzw. 13 Seiten
  Status: CONFIRMED

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Der Rueckbau schreibt keine Felder; es entfallen nur Schreibstellen (`promoCode.isValid` in UserDefaults), Bedingung davor: Einloesung per Promo-Code (entfernt); Test fuer diesen Weg: entfaellt mit dem Pfad (Strukturtest `scripts/test_promo_removed.py`).

## Verdict
**VERIFIED**

AC-10 bis AC-17 PROVEN (AC-1 bis AC-9 Durchgang 1, gemergt; AC-16 als Regression bewiesen). AC-17 durch `benutzen-befund.md` und die Aufnahmen belegt (kein Promo-Feld, Dev-Abschnitt ohne „Promo-Codes“). Keine Befunde (Findings) gegen die Implementierung. Hinweis (nicht aus dem Rückbau, Durchgang 1): Tipp auf „Code einlösen“ zeigt in den Einstellungen im Simulator nichts, in der Paywall ein leeres Blatt; Systemfenster im Simulator nicht belegt (Offene Grenze aus AC-3).

## Geprüfte Dateien

- sha256:a4bcc4c0aea091eb3fcbe616d71f4ea0fd7095fbb5cd558af9ae08ff61b954b6  SmartCart/Services/PremiumService.swift
- sha256:004a922f0da67327333296ba107a3780705c039199b4273a4812269830a54d43  SmartCart/SmartCartApp.swift
- sha256:5e6fad0639e7f8c23c22f445fcb4c87d7ad08611e76192871cc9fad8c41d12cc  SmartCart/Views/Settings/LegalView.swift

## Prüfbasis

- base: 7ff7d19b952caf116b5035fa809b42484d3bc95f
- blob:f35b1f5188ffb72545e50e45e4a7daa0b077571f  SmartCart/Services/PremiumService.swift
- blob:e599d4bbc911429ccfecd20f515a07a7f6762388  SmartCart/SmartCartApp.swift
- blob:889ee78a9b8e53451c0762bb3a255dea7847362c  SmartCart/Views/Settings/LegalView.swift
