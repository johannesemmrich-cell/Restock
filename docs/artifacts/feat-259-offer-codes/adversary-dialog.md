# Adversary Dialog — feat-259-offer-codes
Spec: docs/specs/views/offer-codes-einloesen.md
Datum: 2026-11-05 14:38
Geprüft: Durchgang 1 (AC-1 bis AC-9), Commit b23fe21 gegenüber RED 61a56a3, plus Nachbesserung F001 (PaywallView, ungesichert bis zum Abschluss dieses Schritts).

## Checkliste
- [x] AC-1: Zeile `settings.redeemCode` in den Einstellungen ohne Pro (`-developerMode NO`), vollständig im Fenster, antippbar
- [x] AC-2: Knopf `paywall.redeemCode` in der Paywall, unter „Käufe wiederherstellen“, über den Rechtslinks, auch bei AccessibilityXXXL (Lage und Antippbarkeit; Aussehen bei großer Schrift nicht belegt, F004)
- [x] AC-3: Tipp auf beide Einstiege, App bleibt stabil (Fenster im Simulator nicht im Baum, laut Spec kein Teil der Bedingung)
- [x] AC-4: Unit-Tests Offer-Code-Entitlement per Update-Strom (bekannte ID schaltet frei, unbekannte nicht)
- [x] AC-5: Alle Promo-Reste aus `SettingsView.swift` entfernt
- [x] AC-6: `settings.redeemCode` in de und en
- [ ] AC-7: UI-Teil grün (23/23); Unit-Suite 860/862, die zwei Fehlschläge sind zeitabhängig und nicht von #259 (F002, Entscheidung des PO)
- [x] AC-8: Debug- und Release-Build kompilieren (Logs `build-debug.txt`, `build-release.txt`, je `BUILD SUCCEEDED`)
- [x] AC-9: Benutzen-Befund vorhanden, Bilder geprüft; Zustand nach dem Tipp nicht belegt (ehrlich vermerkt)
- [ ] AC-10: Rückbau Promo-Dateien — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-11: pbxproj ohne PromoCode — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-12: `hasValidPromoCode` entfernt — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-13: Promo-Absatz in LegalView und Datenschutzseite — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-14: `settings.promoCode.*`-Schlüssel entfernt — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-15: Struktur-/Python-Tests — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-16: Einstieg nach Rückbau unverändert — Durchgang 2, nicht Teil dieses Durchgangs
- [ ] AC-17: Benutzen nach Rückbau — Durchgang 2, nicht Teil dieses Durchgangs

## Dialog

### Runde 1
**Adversary:**
Ich gehe davon aus, dass die Implementierung falsch ist. Fragen: (1) AC-5 vollständig? Platzierung von `.offerCodeRedemption`? (2) Beweist der AC-4-Test etwas, obwohl `PremiumService` unverändert ist? (3) Schließt sich die Paywall nach einer Einlösung (Spec Verhalten 3)? (4) Unit-Suite wirklich grün? (5) Wo ist der Beleg für BUILD SUCCEEDED? (6) Nach-Tipp- und XXXL-Bilder identisch zu den Vorher-Bildern. (7) DEBUG-only-Code, `import StoreKit`? (8) Scoping.

**Implementierer:**
Vom Prüfer selbst durch Gegenprüfung beantwortet, siehe Runde 2.

### Runde 2
**Adversary (Gegenprüfungen und Edge Cases):**
- AC-5/AC-1: `grep -in promo SmartCart/Views/Settings/SettingsView.swift` leer. Die Zeile steht im `else`-Zweig von `if premium.hasPremiumAccess`, `import StoreKit` vorhanden, Abschluss `{ _ in }` ohne Seiteneffekt. Der Rechtslink-Vergleich im UI-Test ist bedingt (`if privacy.exists, redeemExists`), schwach, aber `PaywallUITests` prüft die Links separat.
- AC-4: Gegenprobe `false` vor dem Update, kein `purchase`-Aufruf (`purchasedOfferIDs.isEmpty`), unbekannte ID bleibt gesperrt (`knownIDs`). Charakterisierungstest eines unveränderten Produktcodes, wie in der Spec vorgesehen.
- Paywall-Schließen: `dismiss()` kam nur in `purchase()` und `restore()` vor; nach einer Einlösung blieb die Paywall offen — Verstoß gegen Spec Verhalten 3 (F001).
- AC-7: Unit 862 Tests, 2 Fehlschläge in `ConsumptionPatternTests` (zeitabhängig, Code unverändert gegenüber `origin/main`); UI 23 Tests, 0 Fehlschläge (F002).
- AC-8: Zunächst kein Build-Log abgelegt, nur das Release-Binary mit `paywall.redeemCode` (F003).
- AC-9: Bilder zeigen Einstieg sichtbar, vollständig, lesbar; Zustand nach dem Tipp nicht belegt, XXXL-Bild identisch zum normalen (feste Schriftgrößen im Bestand, F004).
- Scoping: `PremiumService`, `SmartCartApp`, `project.pbxproj` unberührt.

**Implementierer:**
F001 und F003 wurden behoben (Runde 3). F002 und F004 bleiben als dokumentierte Vorbelastung bzw. offene Grenze.

### Runde 3
**Adversary (Prüfung der Nachbesserung):**
- F001: `PaywallView.swift:87` schließt die Paywall bei Wechsel von `premium.hasPremiumAccess` von false auf true. Kommentar am Knopf (Zeile 369) stimmt jetzt. Fall „Paywall öffnet mit schon aktivem Pro“: `onChange` feuert nur bei Änderung. Doppeltes `dismiss()` bei success/restoreFound: `testPurchaseSuccessClosesPaywallAndUnlocksRecipePlan` und `testRestoreFoundClosesPaywallAndUnlocks` sind grün. Nicht automatisiert geprüft: dass ein echter Offer Code die Paywall schließt (kein Szenario im Ersatz-Appstore, Systemfenster im Simulator nicht auslösbar) und der Weg Einstellungen → Paywall → Kauf mit doppeltem `dismiss()`.
- F003: Debug- und Release-Log je ein `BUILD SUCCEEDED`; UI-Lauf nach dem Fix: 23 Tests, 0 Fehlschläge.

**Implementierer:**
Offen bleibt: kein Test für das Schließen nach echter Einlösung (offene Grenze), Unit-Suite nicht nach dem Fix erneut gefahren (nur Ansichtscode, `PremiumService` unberührt).

## Befunde und Bestätigungen

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/Views/Premium/PaywallView.swift:87
  Description: Nach Einlösen eines Codes schloss sich die Paywall nicht, obwohl Pro aktiv war.
  Status: FIXED (`.onChange(of: premium.hasPremiumAccess)` → `dismiss()`, UI-Lauf 23/23 grün)

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/Views/Settings/SettingsView.swift:211
  Description: AC-7 „gesamte Unit-Suite grün“ wörtlich nicht erfüllt: 2 zeitabhängige Fehlschläge in `ConsumptionPatternTests` (Zeitumstellung 25.10.), Code gegenüber `origin/main` unverändert.
  Status: OPEN, Vorbelastung, Entscheidung beim PO

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Views/Premium/PaywallView.swift:376
  Description: Kein Build-Log für AC-8 abgelegt.
  Status: FIXED (`build-debug.txt`, `build-release.txt`)

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Premium/PaywallView.swift:371
  Description: Festes `.system(size: 14)` wie der Bestand; XXXL-Bild identisch zum Normalbild.
  Status: OPEN, offene Grenze (Bestand, nicht #259)

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Views/Settings/SettingsView.swift:230
  Evidence: `accessibilityIdentifier("settings.redeemCode")` im Zweig „Pro nicht freigeschaltet“; `testSettingsRedeemCodeRowExistsAndOpens` bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Views/Premium/PaywallView.swift:375
  Evidence: `accessibilityIdentifier("paywall.redeemCode")`, Reihenfolge Wiederherstellen, Hinweis, Code-Knopf, Rechtsblock; beide Paywall-Tests bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Views/Premium/PaywallView.swift:376
  Evidence: `.offerCodeRedemption(isPresented:)` mit leerem Abschluss, ebenso `SettingsView.swift:231`; App bleibt im Vordergrund.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Views/Settings/SettingsView.swift:209
  Evidence: `PremiumServiceTests` Offer-Code-Tests bestanden (21 Tests, 0 Fehlschläge), `PremiumService` unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Views/Settings/SettingsView.swift:28
  Evidence: `grep -in promo` auf `SettingsView.swift` leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Views/Settings/SettingsView.swift:219
  Evidence: Schlüssel in `de.lproj` und `en.lproj` Zeile 116; `LocalizationKeyParityTests` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Views/Premium/PaywallView.swift:87
  Evidence: `build-debug.txt` und `build-release.txt` je `BUILD SUCCEEDED`, kein `#if DEBUG` im neuen Code.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Settings/SettingsView.swift:209
  Evidence: `benutzen-befund.md` mit je Bild „sichtbar, vollständig, lesbar“; Zustand nach Tipp ehrlich als nicht belegt vermerkt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS
Begründung: AC-1 bis AC-6, AC-8 und AC-9 sind belegt, F001 und F003 sind behoben. AC-7 ist wörtlich nicht erfüllt, weil 2 zeitabhängige Unit-Tests in `ConsumptionPatternTests` rot sind (nicht von #259, F002). Das Schließen der Paywall nach echter Einlösung ist nicht automatisiert prüfbar (offene Grenze). AC-10 bis AC-17 gehören zu Durchgang 2.
