---
entity_id: paywall-produkte-nachladen
type: bugfix
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: fix-265-iap-ladbar
tags: [paywall, premium, storekit, app-review, review-2-1-b]
---

# Paywall: Produkte erneut laden statt Dauerfehler (Issue #265)

## Approval

- [ ] Spec-Freigabe durch den PO (steht aus)

## Purpose

App Review lehnte 1.0.1 (Build 40) am 2026-11-09 ab (Guideline 2.1(b), iPad Air 11", iPadOS 27.2): Die
Paywall zeigt „Der Kauf konnte nicht geladen werden“ und die Ersatzpreise.

**Hauptursache liegt in App Store Connect, nicht im Code:** `premium.lifetime`, `premium.monthly` und
`premium.yearly` stehen auf `READY_TO_SUBMIT` und wurden nie mit einer App-Version eingereicht; Apple
verlangt das für den ersten Kauf jeder Art. Von Apple nicht bestätigt, durch Zustand und Regel gestützt
(Quellen in `docs/context/fix-265-iap-ladbar.md`). Das Anhängen der Käufe an die Version ist ein
außenwirksamer Apple-Schritt, kein Teil dieser Spec und nur auf ausdrückliches Wort des PO.

**Verschärfung im Code (Gegenstand dieser Spec):** `PremiumService.loadProducts()` läuft genau einmal im
`init` und verwirft Fehler per `try?`. Bleibt `products` leer (kein Netz beim Start, Kauf bei Apple noch
nicht abrufbar), zeigt `PaywallView.purchase()` den Fehler bis zum nächsten App-Start; es wird nie
nachgeladen. Hat es bisher funktioniert? Kein Rückschritt im Code seit Build 33; belegt funktionierend war
das Laden in Apples Prüfumgebung nie.

Regelweg, kein Modell. Alternativen: (a) im Kaufpfad `Product.products(for:)` direkt fragen, ohne Liste
(größerer Umbau der Naht `PurchaseStore` und der Preisanzeige, kein Mehrwert); (b) nur die Käufe
einreichen (genügt wahrscheinlich für die Ablehnung, lässt aber den Dauerfehler nach kurzem Netzausfall
beim Start bestehen). Keine ADR wird gekippt.

## Scope

| Datei | Änderung | LoC (ca.) |
|-------|----------|-----------|
| `SmartCart/Services/PremiumService.swift` | neue `reloadProductsIfNeeded()`, Doppelstart-Schutz | +15 |
| `SmartCart/Views/Premium/PaywallView.swift` | `.task` beim Erscheinen; Nachladen im Kaufpfad vor dem Fehlertext | +8/−1 |
| `SmartCart/Services/FakePurchaseStore.swift` | Szenario `productsLoadLate` (erster Abruf leer, danach gefüllt) | +12 |
| `RestockTests/PremiumServiceTests.swift` | Unit-Tests Nachladen | +40 |
| `RestockUITests/PurchaseUITests.swift` | UI-Test „erst leer, dann Kauf möglich“ | +30 |
| `project.yml`, `Restock.xcodeproj/project.pbxproj` | Build 40 → 41 (mechanisch, je 1–2 Stellen) | +4/−4 |

Produktcode ca. +35 LoC; 5 inhaltliche Dateien plus Build-Nummer in 2 Dateien (Limit 4–5 Dateien nur durch
die mechanische Build-Nummer überschritten, kein Split nötig). Nicht berührt: `Localizable.strings`,
Berechtigungen, CloudKit-Schema, `PrivacyInfo.xcprivacy`, `ci.yml`, Fehlertext der Paywall.

## Verhalten

1. `PremiumService.reloadProductsIfNeeded() async`: ist `products` nicht leer, tut sie nichts; läuft schon
   ein Ladevorgang (Merker `isLoadingProducts`), tut sie nichts; sonst lädt sie wie `loadProducts()`.
   `loadProducts()` selbst bleibt (Start im `init`). Ein Fehler beim Laden lässt `products` leer, wirft nie.
2. `PaywallView` ruft `reloadProductsIfNeeded()` per `.task` beim Erscheinen. Preisanzeige folgt
   `productPrice(for:)` und aktualisiert sich, sobald `products` gefüllt ist (Bestand).
3. `PaywallView.purchase()` ruft vor der Prüfung `premium.offer(for:)` einmal `await
   premium.reloadProductsIfNeeded()`. Liefert `offer(for:)` danach weiter `nil`, erscheint der bisherige
   Fehlertext unverändert. Ein Versuch je Auslöser, kein Wiederholen in Schleife, kein Dauer-Spinner.
4. Doppelkäufe: `isPurchasing` und der Kaufknopf bleiben unverändert; das Nachladen startet keinen Kauf.
5. `FakePurchaseStore` (nur DEBUG): Szenario `productsLoadLate` liefert beim ersten `loadOffers` eine leere
   Liste, ab dem zweiten die drei Angebote; Kauf verhält sich wie `success`. Zehntes Szenario, Auswahl über
   `-purchaseScenarioForUITests productsLoadLate`; im Release-Binary nicht vorhanden.
6. Build-Nummer `CURRENT_PROJECT_VERSION` 40 → 41 in `project.yml` und `project.pbxproj` (alle Ziele).

## Acceptance Criteria

- **AC-1:** Unit: Ist `products` leer und liefert der Store beim zweiten Abruf Angebote, füllt `reloadProductsIfNeeded()` die Liste; `offer(for:)` liefert danach einen Treffer.
- **AC-2:** Unit: Ist `products` schon gefüllt, ruft `reloadProductsIfNeeded()` den Store nicht erneut ab (Zähler des Schein-Stores bleibt unverändert).
- **AC-3:** Unit: Zwei gleichzeitige Aufrufe von `reloadProductsIfNeeded()` führen zu genau einem Store-Abruf.
- **AC-4:** Unit: Wirft der Store beim Laden, bleibt `products` leer, `reloadProductsIfNeeded()` wirft nicht, ein späterer Aufruf lädt erneut.
- **AC-5:** UI (Reproduktion, vor dem Fix rot): Mit `-purchaseScenarioForUITests productsLoadLate` und `-developerMode NO` öffnet die Paywall; nach Tipp auf den Kaufknopf erscheint **nicht** „Der Kauf konnte nicht geladen werden“, der Kauf läuft durch und die Paywall schließt sich. Vor der Änderung zeigt derselbe Ablauf den Fehlertext (RED belegt).
- **AC-6:** UI: Das Szenario `productMissing` zeigt weiter den Fehlertext (Bestandstest bleibt grün; Nachladen ersetzt den Fehler nur, wenn Produkte da sind).
- **AC-7:** Bestehende Tests `PremiumServiceTests` U1–U12 und `PurchaseUITests` P1–P11 bleiben grün; Klassenlauf mit Testzahl, Fehlschlägen und Abbruchprüfung (kein Null-Test-Lauf).
- **AC-8:** Release-Nachweis: `strings` am Release-Binary enthält weder `FakePurchaseStore` noch `productsLoadLate`.
- **AC-9:** `CURRENT_PROJECT_VERSION` steht in `project.yml` und `project.pbxproj` auf 41 (Widget und Teilen-Erweiterung gleiche Nummer); der Diff gegen `origin/main` berührt keine Datei aus der Liste „Nicht berührt“ oben.
- **AC-10:** Benutzen statt nur testen: Die Paywall wurde im Simulator mit `productsLoadLate` geöffnet und der Kauf ausgelöst. Kriterium: Die Aufnahme nach dem Tipp (`docs/artifacts/fix-265-iap-ladbar/nach-kauf.png`) zeigt keinen Fehlertext „Der Kauf konnte nicht geladen werden“ und die Paywall ist geschlossen; Claude prüft die Aufnahme per Bildansicht und vermerkt „kein Fehlertext, Paywall geschlossen“ in `benutzen-befund.md`.
- **AC-11:** Unit: Der Kaufpfad-Nachlader ist einzeln belegt: Ein Schein-Store, dessen erster Abruf leer und dessen zweiter gefüllt ist, liefert nach genau einem Aufruf von `reloadProductsIfNeeded()` ein Angebot (entspricht dem Aufruf aus `PaywallView.purchase()`, unabhängig vom `.task` beim Erscheinen). AC-5 belegt Verhalten 2 und 3 zusammen und ist damit kein Einzelbeleg für Verhalten 3.

## Definition of Done

- [ ] Mit zunächst leerem Produktabruf (`productsLoadLate`) lässt sich der Kauf in der Paywall ohne Fehlertext auslösen (AC-5, AC-10).
- [ ] Alle Unit- und UI-Tests der Klassen `PremiumServiceTests` und `PurchaseUITests` grün, Testzahl geprüft (AC-1 bis AC-4, AC-6, AC-7, AC-11).
- [ ] Release-Binary enthält keinen Fake und kein Szenario (AC-8); Build-Nummer 41 (AC-9).

## Test Plan

- `RestockTests/PremiumServiceTests.swift` (`autostart: false`, Schein-Store mit Abrufzähler und steuerbarer Antwortfolge): AC-1 bis AC-4.
- `RestockUITests/PurchaseUITests.swift`: `testProductsLoadLateStillPurchasable` (AC-5), Bestandstest `productMissing` (AC-6); Start über `UITestLaunch.start` mit Gegenprobe, Warten mit `waitUntilHittable()`.
- Nachweis AC-8 per `strings` wie in `docs/artifacts/test-145-d4-kauf-wiederherstellen/release-strings-check.txt`.

## Offene Grenzen

- Der Code-Fix behebt die Ablehnung nicht allein; entscheidend ist, dass die drei Käufe mit der Version eingereicht werden (Apple-Schritt, nur auf Wort des PO; ob per API möglich, ist ungeprüft, sonst Weboberfläche).
- Dass das Laden in Apples Prüfumgebung danach klappt, ist nicht nachstellbar und nicht automatisiert prüfbar; geprüft wird nur gegen den Ersatz-Appstore.
- Ohne Netz und ohne Treffer bleibt der Fehlertext; es gibt keine eigene Wiederholungs-Schaltfläche.
- Nichts auf Hennings Geräten geprüft; TestFlight-Upload von Build 41 nur auf Wort des PO mit vorher gezeigtem „Was testen?“-Text.
