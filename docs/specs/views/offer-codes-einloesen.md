---
entity_id: offer-codes-einloesen
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-259-offer-codes
tags: [premium, offer-codes, storekit, paywall, einstellungen, promo-code-rueckbau]
---

# Offer Codes einlösen statt eigener Promo-Code-Pool (Issue #259)

## Approval

- [ ] Spec-Freigabe durch den PO (steht aus)

## Purpose

Restock Pro soll für ausgewählte Personen (Journalisten, Blogger, Tester) kostenlos freischaltbar sein. Heute geht das nur über den selbstgebauten Promo-Code-Pool in der öffentlichen CloudKit-Datenbank (`PromoCodeService`, 2026-11-01). Der PO hat entschieden (2026-11-05): Das läuft künftig über **Apple Offer Codes**; der eigene Pool wird vollständig zurückgebaut. Maßstab des PO: „Es muss nicht perfekt sein, sondern soll funktionieren.“

Entwurf A (PO, 2026-11-05, Vorschau `docs/artifacts/feat-259-offer-codes/entwurfsvorschau.html`): eine Zeile „Code einlösen“ in den Einstellungen und ein gleichwertiger Einstieg unter „Käufe wiederherstellen“ in der Paywall. Beide öffnen Apples System-Fenster `.offerCodeRedemption(isPresented:onCompletion:)` (SwiftUI, iOS 16 bis 27; Quelle: https://developer.apple.com/documentation/swiftui/view/offercoderedemption(ispresented:oncompletion:), Leitfaden https://developer.apple.com/documentation/storekit/supporting-offer-codes-in-your-app).

**Freischalten braucht keine neue Quelle.** `StoreKitPurchaseStore.updates()` hört bereits auf `Transaction.updates`, beendet verifizierte Transaktionen und löst `refreshPurchases()` aus; `entitlements()` liest `currentEntitlements`. Ein eingelöster Offer Code erzeugt eine normale Transaktion einer bekannten Produkt-ID und läuft damit durch die vorhandene Kette in `PremiumService`. Neu ist nur der Einstieg; der Rest ist Rückbau.

Ohne Modell, ohne neue Abhängigkeit, reine Systemlösung.

## Aufteilung in zwei Durchgänge

Die Scoping-Limits (4–5 Dateien, ±250 LoC) werden eingehalten, indem das Ticket in zwei Durchgänge geteilt wird; jeder ist für sich kompilierbar und grün. Der zweite beginnt erst nach Merge des ersten.

| Durchgang | Inhalt | Zustand danach |
|-----------|--------|----------------|
| 1 | Einlöse-Einstieg (Einstellungen, Paywall), Alt-Eingabefeld in den Einstellungen ersetzt, Tests | App löst Offer Codes ein; `PromoCodeService` & Co. liegen noch ungenutzt im Projekt |
| 2 | Rückbau des Promo-Pools (Dateien, Flag, Start-Prüfung, Strings, Datenschutztexte, pbxproj) | Kein Verweis auf Promo-Codes mehr |

## Durchgang 1: Einlöse-Einstieg

### Scope

| Datei | Änderung | LoC (ca.) |
|-------|----------|-----------|
| `SmartCart/Views/Settings/SettingsView.swift` | Promo-State (Z. 28–30), Eingabefeld samt Fehlertext (Z. 208–231), Alert (Z. 243–247), Dev-Link „Promo-Codes“ (Z. 331–336) und `redeemPromoCode` (Z. 487–497) raus; Zeile „Code einlösen“ + `.offerCodeRedemption` rein | +14 / −45 |
| `SmartCart/Views/Premium/PaywallView.swift` | Einstieg „Code einlösen“ unter `restoreButton`, `.offerCodeRedemption` | +16 |
| `SmartCart/Resources/de.lproj/Localizable.strings` und `en.lproj/…` | ein neuer Schlüssel `settings.redeemCode` je Sprache (die Paywall nutzt wie bisher deutsche Literale, siehe Paywall-Rechtslinks) | +2 / +2 |
| `RestockUITests/PurchaseUITests.swift` | UI-Tests Einstellungen und Paywall | +45 |
| `RestockTests/PremiumServiceTests.swift` | Unit-Test Offer-Code-Entitlement ohne vorherigen Kauf | +25 |

6 Dateien (SettingsView, PaywallView, `de.lproj`- und `en.lproj`-Strings einzeln gezählt, PurchaseUITests, PremiumServiceTests), geschätzt +105 / −45, zusammen rund 150 Zeilen. Das Dateilimit (4–5) wird um eins überschritten; Grund: Sprachpaar der Strings plus zwei Testdateien. Das gibt der PO mit der Spec-Freigabe ausdrücklich mit frei. Nicht berührt: `PremiumService`, `FakePurchaseStore`, `SmartCartApp`, `PrivacyInfo.xcprivacy`, `project.pbxproj`, CloudKit-Schema, `ci.yml`.

### Verhalten

1. **Einstellungen:** Im Abschnitt, in dem bisher das Promo-Code-Feld stand (Zweig „Pro noch nicht freigeschaltet“, direkt unter der Zeile „Restock Pro freischalten“), steht eine Zeile „Code einlösen“ mit Symbol `ticket` und Chevron, `accessibilityIdentifier("settings.redeemCode")`. Tipp setzt eine `@State`-Variable `showOfferCodeRedemption`, die `.offerCodeRedemption(isPresented:onCompletion:)` an der Zeile öffnet. Ist Pro bereits freigeschaltet, erscheint die Zeile nicht (wie das alte Feld).
2. **Paywall:** Unter „Käufe wiederherstellen“ steht ein zweiter, gleich gestalteter Textknopf „Code einlösen“ (14 pt, `.secondary`, `.buttonStyle(.pressable)`), `accessibilityIdentifier("paywall.redeemCode")`, öffnet dasselbe Fenster. Hinweise und Fehler von „Wiederherstellen“ (`noticeView`, Hinrollen an `noticeScrollID`, #145 D4) und der Rechtsblock (#215) bleiben in ihrer Reihenfolge; „Käufe wiederherstellen“ steht weiter vor dem neuen Knopf, der neue Knopf vor dem Rechtsblock.
3. **Abschluss:** `onCompletion` zeigt keine eigene Oberfläche. Ein Fehler des Fensters (`.failure`) wird nicht gesondert behandelt (Apple zeigt seinen Fehler im Fenster selbst); `.success` heißt nur „Fenster ohne Fehler beendet“, nicht „Code gültig“. Die Freischaltung kommt ausschließlich über `Transaction.updates` → `PremiumService` (Stufe wie ein Kauf). Die Paywall schließt sich bei Freischaltung wie bisher selbst.
4. **Kein neuer Zustand, kein neues Launch-Argument, keine neue Freischaltquelle.** Der Fake-Store braucht kein neues Szenario: Das System-Fenster lässt sich nicht fälschen, und der Offer-Code-Fall ist aus Sicht von `PremiumService` ein Update-Strom-Ereignis (siehe Tests).

### Acceptance Criteria

- AC-1: In den Einstellungen gibt es ohne Pro-Freischaltung (`-developerMode NO`) die Zeile mit `accessibilityIdentifier` `settings.redeemCode`; sie existiert, liegt vollständig im Fenster und ist antippbar (`waitUntilHittable()` liefert `matched`).
- AC-2: In der Paywall gibt es nach Hochscrollen den Knopf mit `accessibilityIdentifier` `paywall.redeemCode`; er existiert, liegt vollständig im Fenster, ist antippbar, und steht unterhalb von „Käufe wiederherstellen“ und oberhalb der Rechtslinks (Rahmenvergleich `maxY`/`minY`); dasselbe bei Schrift `AccessibilityXXXL`.
- AC-3: Ein Tipp auf beide Einstiege wird im UI-Test ausgeführt und lässt die App stabil: kein Absturz, `app.state == .runningForeground` und die Oberfläche reagiert danach weiter (Fenster schließbar bzw. Zeile/Knopf wieder antippbar). Ob das System-Fenster im Simulator tatsächlich erscheint, ist kein Teil der Bedingung; es wird nur gemessen und im Testprotokoll vermerkt (Ergebnis kommt in Offene Grenzen).
- AC-4: Ein Unit-Test (`PremiumServiceTests`, `ScriptedPurchaseStore`, `autostart: false`) weist nach: Ohne vorherigen `purchase`/`restore`-Aufruf und ohne Dev-Modus schaltet ein über den Update-Strom eintreffendes Entitlement einer bekannten Produkt-ID (Offer-Code-Einlösung) `hasPremiumAccess` frei; eine unbekannte Produkt-ID schaltet nicht frei.
- AC-5: Das Textfeld für Promo-Codes, der Alert „Code eingelöst“ und die Dev-Zeile „Promo-Codes“ sind aus `SettingsView.swift` entfernt: `grep -in promo SmartCart/Views/Settings/SettingsView.swift` liefert keine Treffer.
- AC-6: Neuer Schlüssel `settings.redeemCode` steht in `de.lproj` und `en.lproj`; `LocalizationKeyParityTests` bleibt grün (gleiche Schlüssel und Platzhalter in beiden Sprachen).
- AC-7: Bestehende Tests `PurchaseUITests` P1–P11 (Hinweis-Hinrollen, „vollständig im Fenster und antippbar“, Chip-Breite) und `PaywallUITests` (Rechtslinks) bleiben grün; die gesamte Unit-Suite ist grün (Testzahl und Fehlschläge prüfen, kein Null-Test-Lauf).
- AC-8: Der Debug-Build für den Simulator und der Release-Build (`xcodebuild build -configuration Release`, wie CI-Job `release-build`) kompilieren ohne Fehler.
- AC-9: Benutzen statt nur testen: Die App wurde im Simulator gestartet; Einstellungen und Paywall wurden geöffnet, die Zeile bzw. der Knopf angetippt; Claude prüft je eine Aufnahme (hell, Einstellungen und Paywall) per Bildansicht und vermerkt in `docs/artifacts/feat-259-offer-codes/benutzen-befund.md` je Bild „Einstieg sichtbar, vollständig, lesbar“ und was nach dem Tipp zu sehen war. Aufnahmen entstehen aus einem echten Lauf (XCTAttachment), nicht von Hand.

### Tests

**Unit** (`RestockTests/PremiumServiceTests.swift`, MARK „Offer Code“):
- `testOfferCodeEntitlementViaUpdateStreamUnlocksWithoutPurchase` (AC-4): Store ohne Kauf, `startListening()`, `entitlementList` mit `monthlyID`, `emitUpdate()`, warten (Muster `testUpdateStreamUnlocksAfterPending`, Frist 20 s), `hasPremiumAccess == true`. Gegenprobe vorher: `false`.
- `testOfferCodeEntitlementUnknownProductDoesNotUnlock` (AC-4): unbekannte ID bleibt `false`.

**UI** (`RestockUITests/PurchaseUITests.swift`, Hilfen aus `UITestWait.swift`):
- `testSettingsRedeemCodeRowExistsAndOpens` (AC-1, AC-3): Start über `UITestLaunch.start` mit `-developerMode NO`, Einstellungen öffnen, Zeile prüfen und tippen, Stabilität prüfen. Kein Aufräum-Argument nötig (kein App-Group-Zustand).
- `testPaywallRedeemCodeButtonPositionAndOpens` (AC-2, AC-3): Paywall öffnen, Knopf mit einer Scroll-Hilfe erreichen (private Kopie von `scrollUntilHittable` aus `PaywallUITests.swift:68`, keine gemeinsame Hilfe in `UITestWait.swift`), Lage gegen „Käufe wiederherstellen“ und Rechtslinks, Tipp; Variante bei `AccessibilityXXXL` über ein Launch-Argument `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` wie in `DynamicTypeUITests`.
- Nie `-developerMode YES` (Argument-Domain-Falle), kein `-purchaseScenarioForUITests`-Szenario für den Einstieg nötig.

### Ändert sich der Zustand?

Neue Berechtigungen: keine. AppStorage-Schlüssel: keine neuen. Info.plist, Audio, Schema: unberührt.

## Durchgang 2: Rückbau des Promo-Pools

### Scope

| Datei | Änderung | LoC (ca.) |
|-------|----------|-----------|
| `SmartCart/Services/PromoCodeService.swift` | gelöscht | −311 |
| `SmartCart/Views/Settings/PromoCodeAdminView.swift` | gelöscht | −183 |
| `RestockTests/PromoCodeServiceTests.swift` | gelöscht (13 Tests) | −227 |
| `SmartCart/Services/PremiumService.swift` | `hasValidPromoCode`, `setHasValidPromoCode` (Z. 136–143) und der Term in `hasPremiumAccess` (Z. 156) raus | −10 |
| `SmartCart/SmartCartApp.swift` | `PromoCodeService.shared.revalidateLocalRedemption()` samt Kommentar im Start-`.task` (~Z. 979–981) raus | −4 |
| `SmartCart/Views/Settings/LegalView.swift` | Absatz „Promo-Codes (kostenlose Freischaltung)“ (~Z. 184) raus | −3 |
| `docs/appstore/datenschutz.md` | deutscher (Z. 38/39) und englischer Absatz (Z. 125/126) raus, wortgleich zu `LegalView` | −6 |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `settings.promoCode.*` (4) und `promoCode.error.*` (3) je Sprache | −7 / −7 |
| `Restock.xcodeproj/project.pbxproj` | je 3 Dateien aus `PBXBuildFile` (3), `PBXFileReference` (3), `PBXGroup` (3), `PBXSourcesBuildPhase` (3) | −12 |

Rund 11 Dateien (3 gelöscht, 8 geändert, Strings je Sprache einzeln), praktisch nur Löschzeilen (−770 laut Tabelle, davon 721 ganze Dateien); Zeilen mit Änderung an bestehenden Dateien 49. Das Zeilenlimit zählt Löschungen mit; der PO gibt mit der Spec-Freigabe ausdrücklich frei, dass dieser Durchgang das Datei- und Zeilenlimit nur durch reine Löschung überschreitet. Nicht berührt: `PrivacyInfo.xcprivacy` (die Geräte-ID wird weiter von Community-Preisen genutzt), CloudKit-Schema (Typ `PromoCode` bleibt in `docs/cloudkit/private-schema-aktuell.ckdb` und in Production stehen).

### Verhalten

1. Alle Promo-Pfade verschwinden; `hasPremiumAccess = developerMode || hasPurchasedAccess` (+ DEBUG-Argument `-premiumForScreenshots` unverändert).
2. Der Schlüssel `promoCode.isValid` in `UserDefaults` wird nicht mehr gelesen und nicht aktiv gelöscht (pragmatisch; harmlose Restdaten).
3. **Datenschutz:** Der Absatz entfällt in `LegalView.privacyPolicy` und auf `datenschutz.md` (de und en) wortgleich; die Seite des Dritten (`emmrich-business.com/datenschutz`) pflegt ein anderer, der Hinweis an ihn folgt nach dem Release (Memory „Datenschutzseite pflegt Dritter“), nicht Teil des Codes. Der Stand „Oktober 2026“ in `LegalView` bleibt, falls `PrivacyManifestTests` ihn festhält; sonst keine Datumsänderung.
4. Es gibt keinen Übergang: Wer einen Promo-Code eingelöst hat, verliert die Freischaltung (siehe Offene Grenzen).

### Acceptance Criteria

- AC-10: `grep -rniE "promocode|promo-code|promo code" SmartCart RestockTests RestockUITests docs/appstore project.yml` liefert keine Treffer (CloudKit-Schemadatei und `docs/specs`/`BACKLOG.md`/`docs/artifacts` als Historie ausgenommen). Die Dateien `PromoCodeService.swift`, `PromoCodeAdminView.swift`, `PromoCodeServiceTests.swift` existieren nicht mehr.
- AC-11: `grep -c PromoCode Restock.xcodeproj/project.pbxproj` liefert 0; das Projekt lässt sich öffnen und bauen (Debug Simulator und Release Simulator), keine verwaiste Referenz.
- AC-12: `hasValidPromoCode` und `setHasValidPromoCode` kommen im Code nicht mehr vor; `PremiumServiceTests` (inklusive der Offer-Code-Tests aus Durchgang 1) bleiben grün; die Unit-Suite insgesamt grün mit erwarteter Testzahl (Vorher-Zahl minus 13 Promo-Tests, Testzahl und Fehlschläge geprüft).
- AC-13: Der Promo-Absatz fehlt in `LegalView` und in beiden Sprachteilen von `docs/appstore/datenschutz.md`; `python3 scripts/test_asc_texts.py` ist grün (Wortgleichheit LegalView ↔ Seite), `PrivacyManifestTests` ist grün.
- AC-14: Schlüssel `settings.promoCode.*` und `promoCode.error.*` fehlen in beiden `Localizable.strings`; `LocalizationKeyParityTests` bleibt grün; die kompilierten Tabellen (de, en) haben gleich viele Schlüssel; vor dem Rückbau wird die Anzahl N je Sprache gemessen (`grep -c '" = "'`), danach sind es in beiden N−7.
- AC-15: Die Struktur-/Python-Tests der CI (`scripts/test_*.py`, Schritt „Strukturtests (Python)“) laufen grün; ein Test, der den Promo-Pfad oder die gelöschten Dateien noch nennt, wird im selben Durchgang angepasst.
- AC-16: Nach dem Rückbau schaltet der Offer-Code-Einstieg aus Durchgang 1 weiter dieselbe Kette (UI-Tests AC-1/AC-2 grün, Einstellungen und Paywall unverändert).
- AC-17: Benutzen statt nur testen: Die App wurde nach dem Rückbau gestartet (frischer Simulator), Einstellungen und Paywall geöffnet; kein Promo-Feld mehr, Dev-Modus-Abschnitt ohne „Promo-Codes“; Befund wie AC-9 in `docs/artifacts/feat-259-offer-codes/benutzen-befund.md`.

### Tests

Keine neuen Tests; die Löschung von `PromoCodeServiceTests` ist Teil des Durchgangs. Prüfung per grep (AC-10, AC-11, AC-12), Unit-Gesamtlauf, UI-Klassen `PurchaseUITests`, `PaywallUITests`, `RestockUITests` (Einstellungen), Release-Build, `scripts/test_asc_texts.py`.

## Alternativen (gekippte Entscheidung)

- **Pool für Tester behalten, Offer Code zusätzlich:** Tester ohne Store-Produkt-Konto kämen weiter mit Promo-Code hinein, und nichts müsste in App Store Connect angelegt sein, bevor es funktioniert. Kostet dafür: weiter den Datenschutz-Absatz, das Schreibrecht `_icloud` auf `PromoCode`, eine Installationskennung in der öffentlichen Datenbank, zwei Freischaltwege mit Doppelpflege und ein App-Review-Risiko (eigene Freischalt-Codes für digitale Inhalte sind regelkritisch). Gekippt, weil der PO „pragmatisch, nicht perfekt“ will und ein Weg genügt; gekippt würde die Entscheidung vom 2026-11-01 (eigener Pool).
- **Nur Einstellungen, ohne Paywall-Einstieg:** weniger Code, aber wer über die Paywall kommt (Link aus einer Besprechung), müsste suchen. Gekippt, weil der PO Entwurf A gewählt hat.
- **Einlöse-URL/Link statt Fenster in der App:** Apple unterstützt beides; ein Forumsbericht (unbestätigt) nennt unter iOS 26.4 Probleme beim Einlösen über Links. Der Weg im App-Fenster bleibt der Pflichtweg; Links wären Zusatz in der Kommunikation, nicht Code.

## Offene Grenzen

- Echte Einlösung gegen den App Store ist im Simulator nicht automatisiert prüfbar (`SKTestSession` per Kommandozeile defekt, #178). Geprüft werden nur unsere Logik gegen den Ersatz-Store, dass die Einstiege vorhanden, antippbar und stabil sind, und (soweit der Simulator es zeigt) dass das Fenster erscheint.
- Offer Codes brauchen Angebote und Codes in App Store Connect. Das Anlegen ist außenwirksam und geschieht nur auf Hennings Wort, nicht in diesem Ticket. Ohne sie bleibt der Einstieg ohne Wirkung („ungültiger Code“ im System-Fenster).
- Bereits eingelöste Promo-Codes verlieren beim Rückbau die Freischaltung (`promoCode.isValid` wird nicht mehr gelesen). Promo-Codes sind bisher auf keinem Fremdgerät erprobt, das Risiko gilt als gering.
- Ein Forumsbericht (https://developer.apple.com/forums/thread/841070) nennt Probleme beim Einlösen per Link unter iOS 26.4; unbestätigt, nicht geprüft.
- Offer Codes gelten für die Produkt-IDs `monthlyID`, `yearlyID`, `lifetimeID`; ein Angebot für einen anderen Typ (z. B. nur Abo) wirkt entsprechend nur dort. Die Familienfreigabe regelt Apple.
- Ein Entzug eines Codes (Erstattung) kommt als widerrufene Transaktion über den Update-Strom und nimmt den Zugang weg; das ist durch `testUpdateStreamRevocationRemovesAccess` abgedeckt, aber nicht gegen echte Apple-Antworten.
- Paywall-Texte sind weiter nur deutsch (Bestand); der Einstellungs-Eintrag ist lokalisiert.
- Der CloudKit-Typ `PromoCode` bleibt im Schema (Development und Production); ein späterer Rückbau dort ist eigener Schritt.
- Die Datenschutzseite des Dritten nennt Promo-Codes ggf. weiter bis zu seiner Aktualisierung.
- Nichts auf Hennings Geräten geprüft.

## Changelog

- 2026-11-05: Erstfassung (Entwurf A, Promo-Pool ganz zurück, zwei Durchgänge).
