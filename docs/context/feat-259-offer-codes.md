# Context: feat-259-offer-codes

## Request Summary
Restock Pro soll für ausgewählte Personen (Journalisten, Blogger, Tester) per Apple **Offer Code** kostenlos freischaltbar sein. Der eigene Promo-Code-Pool (CloudKit, 2026-11-01) wird abgelöst. PO 2026-11-05: „Es muss nicht perfekt sein, sondern soll funktionieren.“

## Recherche (Apple)
- `.offerCodeRedemption(isPresented:onCompletion:)`, SwiftUI, iOS 16 bis 27: https://developer.apple.com/documentation/swiftui/view/offercoderedemption(ispresented:oncompletion:)
- Leitfaden: https://developer.apple.com/documentation/storekit/supporting-offer-codes-in-your-app — Einlöse-Fenster optional, `Transaction.updates`-Listener Pflicht (Codes können außerhalb der App eingelöst werden), Zugang sofort freischalten, `finish()`.
- Forum (unbestätigt): Einlösung per Link unter iOS 26.4 evtl. defekt: https://developer.apple.com/forums/thread/841070

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/PremiumService.swift` | `PurchaseStore`-Naht; `StoreKitPurchaseStore.updates()` hört schon auf `Transaction.updates` und beendet Transaktionen; `entitlements()` liest `currentEntitlements`. Eingelöste Offer Codes laufen damit vermutlich ohne Änderung durch. `hasValidPromoCode` + `setHasValidPromoCode` (Promo-Pfad) fließt in `hasPremiumAccess` |
| `SmartCart/Services/FakePurchaseStore.swift` | DEBUG-Ersatz-Appstore, neun Szenarien; Stelle für ein Szenario „Offer Code eingelöst“ |
| `SmartCart/Services/PromoCodeService.swift` (311 Z.) | Eigener Pool, zurückzubauen |
| `SmartCart/Views/Settings/PromoCodeAdminView.swift` (183 Z.) | Dev-Verwaltung, zurückzubauen |
| `RestockTests/PromoCodeServiceTests.swift` | 13 Tests, zurückzubauen |
| `SmartCart/Views/Settings/SettingsView.swift` | Zeilen 28-30 (State), 208-232 (Eingabefeld), 243-247 (Alert), 331-336 (Dev-Link), 487-497 (`redeemPromoCode`) |
| `SmartCart/SmartCartApp.swift` ~979 | `PromoCodeService.shared.revalidateLocalRedemption()` im Start-`.task` |
| `SmartCart/Views/Premium/PaywallView.swift` | optional zweiter Einlöse-Einstieg neben „Käufe wiederherstellen“ (Zeile ~347) |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `settings.promoCode.*`, `promoCode.error.*` |
| `SmartCart/Views/Settings/LegalView.swift` 184, `docs/appstore/datenschutz.md` 38/125 | Promo-Code-Absatz; `test_asc_texts.py` verlangt Wortgleichheit LegalView ↔ Seite |
| `Restock.xcodeproj/project.pbxproj` | PromoCode-Dateien (je 3-4 Einträge) |
| `docs/cloudkit/private-schema-aktuell.ckdb` | Typ `PromoCode` bleibt im Schema (Rückbau dort nicht nötig) |

## Existing Patterns
- Kauf-Naht `PurchaseStore` + `FakePurchaseStore` für Unit-/UI-Tests; DEBUG-Launch-Argument `-purchaseScenarioForUITests`.
- Neue Swift-Dateien müssen von Hand in `project.pbxproj` (hier eher Löschen).
- Tests in `PremiumServiceTests` (Fake mit `autostart: false`), `PurchaseUITests` (P1-P11).

## Dependencies / Dependents
- Upstream: StoreKit 2 (`Transaction.updates`, `currentEntitlements`, `View.offerCodeRedemption`).
- Downstream: `hasPremiumAccess` (Ausgaben-Analyse, Rezeptplan), Paywall, Einstellungen.

## Existing Specs
- `docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md` (Kauf-Naht)
- Promo-Code-Eintrag in `BACKLOG.md` (2026-11-01)

## Risks & Considerations
- Echte Einlösung im Simulator nicht automatisiert prüfbar (#178); geprüft wird nur unsere Logik gegen den Fake und dass der Knopf das System-Fenster öffnet.
- Offer Codes brauchen Produkte und Angebote in App Store Connect (außenwirksam, nur auf Hennings Wort). Ohne sie bleibt der Knopf ohne Wirkung.
- Ein bereits eingelöster Promo-Code (Tester) verliert beim Rückbau seine Freischaltung; Promo-Codes sind noch nicht auf fremden Geräten erprobt, daher geringes Risiko.
- Datenschutz: Promo-Absatz in `LegalView` und Seite des Dritten entfällt; Manifest bleibt (Geräte-ID wird weiter von Community-Preisen genutzt).
- Umfang: Rückbau ~600 Zeilen Löschung; Durchgang-Teilung (1 Einlösen, 2 Rückbau) im Intake vorgeschlagen, PO-Zweck „pragmatisch“ spricht für möglichst wenig Zusatzfunktion.

## Analysis

### Type
Feature (Ablösung des eigenen Promo-Code-Pools durch Apple Offer Codes)

### Befund (Code gelesen, 2026-11-05)
- `StoreKitPurchaseStore.updates()` hört bereits auf `Transaction.updates`, beendet verifizierte Transaktionen und löst `refreshPurchases()` aus; `entitlements()` liest `currentEntitlements`. Ein eingelöster Offer Code erzeugt eine normale Transaktion einer bekannten Produkt-ID. **`PremiumService` braucht für das Freischalten keine Änderung** (nur Rückbau von `hasValidPromoCode`/`setHasValidPromoCode`, Zeilen 136–143 und 156).
- Neu ist nur der Einstieg: `.offerCodeRedemption(isPresented:onCompletion:)` an Einstellungen (ersetzt Textfeld Zeilen 208–231, Alert 243–247, `redeemPromoCode` 489–496) und optional Paywall (unter `restoreButton`).
- Promo-Pfad hängt nur an: `SettingsView`, `SmartCartApp` Z. 981, `PremiumService`, eigene Dateien (`PromoCodeService` 311 Z., `PromoCodeAdminView` 183 Z., `PromoCodeServiceTests` 13 Tests), Strings `settings.promoCode.*`/`promoCode.error.*`, `LegalView` Z. 184 + `docs/appstore/datenschutz.md` Z. 38/125, `project.pbxproj`.
- Ohne Modell, ohne neue Abhängigkeit; reine Regel-/Systemlösung.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | Textfeld/Alert/Dev-Link raus, Zeile „Code einlösen“ + `.offerCodeRedemption` |
| `SmartCart/Views/Premium/PaywallView.swift` | MODIFY | zweiter Einstieg unter „Käufe wiederherstellen“ (Entwurf A) |
| `SmartCart/Services/PremiumService.swift` | MODIFY | Promo-Flag raus |
| `SmartCart/SmartCartApp.swift` | MODIFY | Revalidierung im Start-`.task` raus |
| `SmartCart/Services/PromoCodeService.swift`, `Views/Settings/PromoCodeAdminView.swift`, `RestockTests/PromoCodeServiceTests.swift` | DELETE | ~600 Z. |
| `Localizable.strings` de/en | MODIFY | Promo-Schlüssel raus, 1–2 neue (Zeile „Code einlösen“); Paritätstest beachten |
| `LegalView.swift`, `docs/appstore/datenschutz.md` | MODIFY | Promo-Absatz raus, wortgleich halten (`test_asc_texts.py`) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | 3 Dateien austragen |
| Tests: `PremiumServiceTests` (Update-Strom → Entitlement bereits vorhanden, ggf. Offer-Code-Fall ergänzen), `PurchaseUITests` (Knopf vorhanden/antippbar) | MODIFY | |

### Scope Assessment
- Durchgang 1 (Einstieg + Tests): ~5 Dateien, ca. +80/−40 Zeilen.
- Durchgang 2 (Rückbau Promo-Pool, Texte, pbxproj): ~10 Dateien, ca. −650 Zeilen; über den Scoping-Limits, daher eigener Durchgang im selben Ticket.
- Risk Level: LOW–MEDIUM (Löschung eines noch auf keinem Fremdgerät erprobten Pfads; Entitlement-Kette bleibt unberührt).

### Technical Approach
Offer Codes über Apples System-Fenster; bestehende Update-Strom-Kette bleibt die einzige Freischaltquelle. Promo-Pool vollständig zurückbauen (kein Zweigleisig-Betrieb). Alternative, die ADR „eigener Pool“ nicht kippt: Pool für Tester behalten und Offer Code nur zusätzlich anbieten, kostet aber Datenschutz-Absatz, `_icloud`-Schreibrecht und Doppelpflege.

### Befunde gegen den Plan
- Forum (unbestätigt): Einlösung per Link unter iOS 26.4 evtl. defekt; Einlösen im App-Fenster bleibt der Weg.
- Ohne Angebote/Codes in App Store Connect bleibt der Knopf wirkungslos; Anlegen ist außenwirksam, nur auf Hennings Wort.
- Echte Einlösung im Simulator nicht automatisiert prüfbar (#178).
- Bereits eingelöste Promo-Codes verlieren beim Rückbau die Freischaltung (bisher nirgends fremd erprobt).

### Dependencies
StoreKit 2 (`View.offerCodeRedemption`, iOS 16+, Ziel iOS 18+ ok). Keine neuen Pakete.

### Open Questions
- [x] PO 2026-11-05: Entwurf A (Einstellungen + Paywall). Vorschau: `docs/artifacts/feat-259-offer-codes/entwurfsvorschau.html`
- [x] PO 2026-11-05: Promo-Pool ganz zurückbauen (Alt-Weg weg).
