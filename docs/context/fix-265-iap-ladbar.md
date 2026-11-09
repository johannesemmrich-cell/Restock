# Context: fix-265-iap-ladbar

## Request Summary
App Review lehnte 1.0.1 (Build 40) am 2026-11-09 ab (Guideline 2.1(b), iPad Air 11", iPadOS 27.2): Die Paywall zeigt „Der Kauf konnte nicht geladen werden“. Gewählt (PO): Käufe an 1.0.1 anhängen und die App härten (neuer Build 41), Antwort an Apple vorher zeigen.

## Befund
- App Store Connect (Lesezugriff, 2026-11-09): `premium.lifetime` (Einmalkauf), `premium.monthly`, `premium.yearly` (Abos) stehen alle auf `READY_TO_SUBMIT`, auch bei 1.0 (`READY_FOR_SALE`). Nie mit einer Version eingereicht. Apple verlangt das für den ersten Kauf jeder Art (Apple-Hilfe „Submit an in-app purchase“). Von Apple nicht bestätigt.
- Screenshot: Paywall zeigt Ersatzpreise (`fallbackPrice`), also ist `PremiumService.products` leer.
- `PremiumService.loadProducts()` (`SmartCart/Services/PremiumService.swift:197`) läuft genau einmal im `init` (Zeile 168) und verwirft Fehler per `try?`.
- `PaywallView.purchase()` (`SmartCart/Views/Premium/PaywallView.swift:454`) zeigt den Fehler, sobald `premium.offer(for:)` nil liefert; kein erneuter Ladeversuch. Kein `.task`/`onAppear` in der Paywall.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/PremiumService.swift` | `loadProducts`, `init`, Naht `PurchaseStore`, `StoreKitPurchaseStore.loadOffers` (Zeile 59) |
| `SmartCart/Views/Premium/PaywallView.swift` | Fehlertext (457), Preisanzeige (128, 143), Kaufauslösung |
| `SmartCart/Services/FakePurchaseStore.swift` | Szenario `productMissing` (leere Liste); Erweiterung um „erst leer, dann gefüllt“ nötig |
| `RestockTests/PremiumServiceTests.swift` | U1–U12, `autostart: false`, Muster für neuen Test |
| `RestockUITests/PurchaseUITests.swift` | P1–P11, `testProductMissing…` (Zeile 180) |
| `project.yml`, `Restock.xcodeproj/project.pbxproj` | Build 40 → 41 (Zeilen 24/75 bzw. 1498/1526) |

## Existing Patterns
- Naht `PurchaseStore` mit `FakePurchaseStore` (nur DEBUG, Launch-Argument `-purchaseScenarioForUITests`, neun Szenarien); Release-Nachweis per `strings`.
- Docs: `docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md`.
- TestFlight-Upload nur auf Wort des PO, „Was testen?“-Text vorher zeigen; Apple-Schritte einzeln auf Wort des PO.

## Dependencies
- Upstream: StoreKit `Product.products(for:)`.
- Downstream: Paywall, Einstellungen (Zeile „Restock Pro freischalten“), `hasPremiumAccess`-Prüfungen.

## Risks & Considerations
- Hauptursache liegt in App Store Connect, nicht im Code; der Code-Fix allein genügt nicht.
- Anhängen der Käufe an die Version: Ob per API möglich, ist ungeprüft (`asc_lib.ALLOWED` kennt keine Einreichungs-Endpunkte); sonst Weboberfläche durch Henning, sein Aufwand muss vermieden oder minimal gehalten werden (Regel: nichts an ihn weiterreichen).
- Erneutes Laden darf keinen Dauer-Spinner und keine Doppelkäufe erzeugen (`isPurchasing`).
- Alternative zum Nachladen: Preise beim Kauf direkt abfragen (`Product.products` im Kaufpfad) statt gecachter Liste.
- Reproduktion: Fake-Szenario „erst leer, dann gefüllt“ zeigt Fehler → Fix → Kauf geht; echter Apple-Sandbox-Ablauf nicht nachstellbar.

## Analysis

### Type
Bug (Ablehnung App Review 2.1(b)). Hat es bisher funktioniert? Version 1.0 steht im Verkauf; Käufe waren nie mit einer Version eingereicht, also konnte das Laden in Apples Prüfumgebung nie belegt funktionieren. Kein Rückschritt im Code seit Build 33 (`loadProducts` unverändert einmalig im `init`).

### Recherche (vor der Analyse, Quellen)
- Apple-Hilfe „Submit an in-app purchase“: Der erste Kauf je Art (Einmalkauf, Abo) muss mit einer neuen App-Version eingereicht werden; Abos nur zusammen mit ihrer Gruppe. https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase
- Forum, gleiches Muster (Käufe „Ready to Submit“, fehlen auf der Versionsseite, Ablehnung 2.1(b)): https://developer.apple.com/forums/thread/841767, https://developer.apple.com/forums/thread/841193, https://developer.apple.com/forums/thread/850187, https://developer.apple.com/forums/thread/840483, https://developer.apple.com/forums/thread/841661. Gemeldeter Weg: Kauf über „Zur Prüfung hinzufügen“ in den bestehenden Entwurf der abgelehnten Einreichung legen. Anekdotisch.
- API: Ob `reviewSubmissionItems` Käufe annimmt, ist widersprüchlich (409 `IAP_NOT_SUBMITTABLE`; `FIRST_SUBSCRIPTION_MUST_BE_SUBMITTED_ON_VERSION`). Nicht belegt, dass es per API geht.

### Root Cause
1. Hauptursache (außerhalb des Codes): Die drei Käufe sind nie eingereicht worden. StoreKit liefert dem Prüfer deshalb keine Produkte. Von Apple nicht bestätigt, aber durch Zustand (`READY_TO_SUBMIT`) und Regel gestützt.
2. Verschärfung im Code: `loadProducts()` läuft einmal im `init` und schluckt Fehler; bei leerer Liste bleibt die Paywall bis zum Neustart kaputt, `purchase()` lädt nie nach.

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| SmartCart/Services/PremiumService.swift | MODIFY | `loadProducts()` nur bei leerer Liste erneut; neue `reloadProductsIfNeeded()`; Doppelstart abfangen |
| SmartCart/Views/Premium/PaywallView.swift | MODIFY | `.task` beim Öffnen; in `purchase()` vor dem Fehler einmal nachladen |
| SmartCart/Services/FakePurchaseStore.swift | MODIFY | Szenario „erst leer, dann gefüllt“ |
| RestockTests/PremiumServiceTests.swift | MODIFY | Test Nachladen |
| RestockUITests/PurchaseUITests.swift | MODIFY | UI-Test: erster Versuch leer, Kauf klappt danach |
| project.yml, project.pbxproj | MODIFY | Build 40 → 41 (mechanisch) |

### Scope
- 7 Dateien (5 inhaltlich + Build-Nummer in 2 Dateien), ca. +90/-5 LoC. Grenze „4–5 Dateien“ nur durch die Build-Nummer überschritten; kein Split nötig.
- Risiko: Niedrig (Code), Hoch für den Termin (Ablehnung hängt an App Store Connect).

### Technical Approach (Empfehlung)
Regelweg, kein Modell. Nachladen statt Cache: `reloadProductsIfNeeded()` ruft den Store nur bei leerer Liste und nur einmal gleichzeitig; Paywall ruft sie beim Erscheinen und vor dem Fehlertext im Kaufpfad. `isPurchasing` bleibt Schutz gegen Doppelkäufe. Kein Dauer-Spinner: ein Versuch je Auslöser.
Alternative: im Kaufpfad direkt `Product.products(for:)` fragen, ohne Liste (würde `PurchaseStore`-Naht und Ersatzpreis-Anzeige umbauen; größer, kein Mehrwert). Gekippt würde keine ADR.
Alternative ohne Code: nur die Käufe einreichen. Reicht für die Ablehnung wahrscheinlich, lässt aber den Dauerfehler nach kurzem Netzausfall beim Start bestehen.

### Reihenfolge / Apple-Schritte (je auf Wort des PO)
1. Käufe an 1.0.1 anhängen: zuerst Weg über Weboberfläche/Entwurf prüfen (nicht per API belegt). Mein Aufwand soll es sein, nicht Hennings: Prüfung per Chrome-Automation in dessen angemeldeter Sitzung nur nach seinem Wort.
2. Build 41 mit Härtung; „Was testen?“-Text vorher zeigen.
3. Antwort im Resolution Center entwerfen und vorlegen.

### Reproduktion
Fake-Szenario „erst leer, dann gefüllt“ in der Paywall: heute Fehlertext bis Neustart (RED), nach Fix Kauf möglich. Echter Apple-Ablauf nicht nachstellbar (Grenze).

### Open Questions
- [ ] Soll Build 41 mit der Härtung eingereicht werden, oder reichen die angehängten Käufe an Build 40? (Empfehlung: Build 41, da ohnehin neu eingereicht wird.)
