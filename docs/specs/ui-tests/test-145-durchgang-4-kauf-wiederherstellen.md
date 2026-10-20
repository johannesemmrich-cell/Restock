---
entity_id: test-145-durchgang-4-kauf-wiederherstellen
type: test
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: test-145-d4-kauf-wiederherstellen
tags: [test, ui-test, unit-test, purchase, storekit, paywall, debug-launch-argument, issue-145, issue-98]
---

# Kauf, Wiederherstellen und Fehlerwege von Restock Pro automatisiert prüfen (Issue #145, Durchgang 4)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Letzter Durchgang von #145 und Release-1.0-Blocker (PO 2026-10-19): Umsatz und App-Store-Prüfung hängen am
Kaufweg von Restock Pro, er wurde aber nie geprüft (`PaywallUITests` aus #98 D5 prüft nur Sperre und
Existenz, nie einen Kauf). Beim Lesen des Codes fielen drei stille Stellen und ein Darstellungsfehler auf;
der PO hat am 2026-10-19 entschieden, sie in diesem Durchgang zu beheben (Entwurf A) und mit dem Test
abzusichern.

**Problem in zwei Sätzen.** Echtes StoreKit ist auf den lokal vorhandenen Simulator-Runtimes (iOS 26.5,
27.0) per Kommandozeile nicht testbar (`SKTestSession` scheitert, reproduziert am 2026-10-19, Belege
`docs/artifacts/test-145-d4-kauf-wiederherstellen/storekit-spike/`). Deshalb wird eine Naht vor StoreKit
gebaut, mit der unsere Logik (Berechtigung, Ausgänge) und die Paywall-Oberfläche in jedem Ausgang
deterministisch prüfbar sind, ohne Apples Kaufablauf zu behaupten.

**Ist-Stand (Code gelesen, Namen maßgeblich):**

- `PremiumService.purchase(_:)` gibt bei `.userCancelled` und `.pending` gleichermaßen `false` zurück; die
  Paywall zeigt in beiden Fällen nichts. Beim Abbruch ist das richtig, bei „ausstehend“ (Ask to Buy,
  starke Kundenauthentifizierung) steht der Nutzer ohne Rückmeldung da (Lücke 1).
- `PremiumService.restorePurchases()` ruft `try? AppStore.sync()`: ein Fehler wird verschluckt, und ohne
  Fund passiert sichtbar nichts (Lücke 2 und 3).
- `PaywallView.purchase()` schließt im DEBUG-Build bei fehlendem Produkt still (`dismiss()`, „wie ein
  Kauf“), nur im Release steht der Fehlertext. Im Simulator ist `products` immer leer, der Release-Fehlerweg
  ist also nie sichtbar (Lücke 4).
- `refreshPurchases()` prüft `revocationDate == nil` bereits (die Kontextdatei sagte irrtümlich „ohne“). Das
  Verhalten bleibt, wird aber erstmals durch einen Test gesichert.
- Der „Schließen“-Chip oben links in der Paywall zeigt hell und dunkel nur „…“ (Videoeinzelbilder aus
  `PaywallUITests/testRecipePlanLockedOpensPaywall`, iOS 26.5, Build 32). **Die Ursache ist nicht bekannt.**
  Sie wird vor dem Fix im Simulator nachgestellt und belegt (AC-14).

**Offene Grenzen (gelten für jede positive Zusage dieser Spec):**

1. Der **echte StoreKit-Kauf und Apples Kaufdialog sind nicht automatisiert geprüft.** Geprüft wird unsere
   Logik gegen einen Fake. `SKTestSession` per Kommandozeile ist auf iOS 26.5 und 27.0 kaputt
   (`SKInternalErrorDomain 3` bzw. `SKServiceErrorDomain 2`); Weg B (iOS-26.2-Runtime nur für einen
   Skriptlauf) und Weg C (Xcode 27.2) liegen als Folge-Issue **#178**.
2. **Ob die drei Produkte in App Store Connect angelegt sind**, ist ungeprüft (**#175**).
3. **Sandbox-/TestFlight-Kauf auf Hennings Gerät** erfolgt nur auf sein ausdrückliches Wort („jetzt ist ein
   Test möglich“), nicht in diesem Durchgang.
4. Das Produkt `sharedlists` steht in `Restock.storekit`, wird aber im Code nicht benutzt.
5. **Familienfreigabe / Ask to Buy / starke Kundenauthentifizierung** sind nur über das Fake-Ergebnis
   `.pending` geprüft, nie mit einem echten System-Ablauf.
6. `Restock.storekit` bleibt in keinem Scheme (Scheme und Datei unverändert).

**Ticket-Rahmen:** #145 Durchgang 4 von 4. Die Scoping-Limits gelten je Durchgang (Memory „#98 ein Ticket,
mehrere Durchgänge“); der PO hat am 2026-10-19 ca. +450 Zeilen in einem Durchgang freigegeben (Limit
überschritten, bewusst).

## Source

Zeilennummern Stand 2026-10-19; maßgeblich sind die Namen.

- **Geändert:** `SmartCart/Services/PremiumService.swift` (95 Z.)
  - Neues Protokoll `PurchaseStore` (`@MainActor`-frei, `Sendable`): `loadOffers(ids:) async throws ->
    [PurchaseOffer]`, `purchase(offerID:) async throws -> PurchaseOutcome`, `sync() async throws`,
    `entitlements() async -> [EntitlementRecord]`, `updates() -> AsyncStream<Void>`.
  - Neue Werttypen: `PurchaseOffer` (`id`, `displayPrice`, `price: Decimal`), `PurchaseOutcome`
    (`.purchased`, `.cancelled`, `.pending`), `EntitlementRecord` (`productID`, `isRevoked`). Der Dienst
    kennt damit kein `Product`/`Transaction` mehr; ein Fake braucht kein StoreKit-Objekt (diese sind nicht
    konstruierbar).
  - Neue Klasse `StoreKitPurchaseStore` (Standard): kapselt unverändert `Product.products(for:)`,
    `product.purchase()` (`.success` → `payloadValue`, `finish()`, `.purchased`; `.userCancelled` →
    `.cancelled`; `.pending` → `.pending`; `@unknown default` → `.cancelled`), `AppStore.sync()`,
    `Transaction.currentEntitlements` (nur `.verified`, `isRevoked = revocationDate != nil`) und
    `Transaction.updates` (verifizierte Transaktion → `finish()` → Signal). Verhalten gegenüber heute
    unverändert.
  - `PremiumService`: `init(store:)` (internal, für Tests; startet **keine** Hintergrundaufgaben, wenn
    `autostart: false`), `private init()` für `shared` wählt `Self.defaultStore()`. `defaultStore()` liefert
    unter `#if DEBUG` bei Launch-Argument `-purchaseScenarioForUITests <name>` den Fake, sonst und im Release
    `StoreKitPurchaseStore`. `products` wird zu `[PurchaseOffer]`, `product(for:)` zu `offer(for:)`.
    `purchase(offerID:) async throws -> PurchaseOutcome`, `restorePurchases() async -> RestoreOutcome`
    (`.found`, `.none`, `.failed`). `refreshPurchases()` filtert `isRevoked` (Verhalten wie heute).
    `hasPremiumAccess`, die Produkt-IDs, `-premiumForScreenshots` und `@AppStorage("developerMode")` bleiben
    unverändert.
- **Neu:** `SmartCart/Services/FakePurchaseStore.swift`, vollständig in `#if DEBUG`. **Entscheidung:
  eigene Datei** statt im selben File, damit der Release-Nachweis (AC-17) eine klare Grenze hat
  (die ganze Datei ist im Release leer) und `PremiumService.swift` lesbar bleibt. Der Fake kennt acht
  Szenarien (siehe Implementation Details), hält Zustand nur im Prozess (kein App-Group-Zustand, kein
  `UserDefaults`-Schreiben) und ist in Unit-Tests direkt mit eigenen Eingaben nutzbar.
- **Geändert:** `SmartCart/Views/Premium/PaywallView.swift` (367 Z.)
  - Zustand `notice: PaywallNotice?` (`.info(String)` / `.error(String)`), ersetzt `errorMessage`.
    `purchase()` und der Restore-Knopf setzen ihn zu Beginn auf `nil` (Hinweis verschwindet beim nächsten
    Tipp). Hinweiszeile direkt unter „Käufe wiederherstellen“ (Entwurf A): Info auf `Color.accentContainer`
    mit `Color.ink`-Text, Fehler in der Warnfarbe wie der heutige Fehlertext (`.red`, `.caption`). Die
    DEBUG-Verzweigung `#if DEBUG dismiss()` in `purchase()` entfällt; fehlendes Produkt zeigt in beiden
    Builds den bestehenden Fehlertext.
  - Texte als deutsche Literale, wie die View sie heute führt (kein neuer Lokalisierungsschlüssel;
    `Text`-Literale und die bestehende `String`-Zuweisung für den Fehlertext, siehe Lokalisierung unten).
  - `rawPrice`/`productPrice` lesen `PurchaseOffer.price`/`displayPrice`.
  - `PaywallView` behält `@StateObject premium = PremiumService.shared`.
- **Geändert (bedingt):** `SmartCart/Extensions/DesignSystem.swift` (`ToolbarChipModifier`, `toolbarChip`,
  `ChipToolbarItem`, Zeilen ca. 165–225) — **nur wenn** die belegte Ursache dort liegt. Liegt sie in
  `PaywallView` (z. B. am `.buttonStyle(.pressable)` oder an der Toolbar-Platzierung dieser einen Stelle),
  bleibt `DesignSystem.swift` unberührt. Andere Chips (alle `ChipToolbarItem`-Nutzer) werden dann in
  Phase 5 mit einem Vorher/Nachher-Screenshot je Fundstelle geprüft und als Seiteneffekt aufgelistet.
- **Neu:** `RestockTests/PremiumServiceTests.swift` — Logik gegen den Fake (siehe Test Plan).
- **Neu:** `RestockUITests/PurchaseUITests.swift` — Paywall je Ausgang (siehe Test Plan).
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — drei neue Dateien (`FakePurchaseStore.swift` nur im
  App-Ziel; `PremiumServiceTests.swift` im Unit-Test-Ziel; `PurchaseUITests.swift` im UI-Test-Ziel) an den
  vier Stellen (`PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`).
- **Geändert (Doku):** `CLAUDE.md` (ein Absatz), `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md`
  (Hinweis: „Kauf, Wiederherstellen, Release-Fehlermeldung“ teilweise geschlossen durch #145 D4, Grenzen
  weiter offen).
- **Nicht geändert:** `Restock.storekit`, Scheme, `ci.yml`, `PaywallUITests` (bleibt unverändert grün),
  `UITestWait.swift`, `HomeView`, `SettingsView`, `SmartCartApp.swift` (das Argument wird im Dienst
  gelesen, kein Aufruf in `init()` nötig), Widget- und Share-Extension-Ziele (sie kompilieren
  `PremiumService.swift` nicht; belegt am 2026-10-19: genau ein Eintrag „PremiumService.swift in Sources“ in `project.pbxproj`, nur in der Sources-Phase der App).
- **Keine** neuen Dependencies, **keine** Änderung an `Info.plist`, **keine** neuen oder geänderten
  `@AppStorage`-Schlüssel, **keine** Audio-Dateien. **Neu:** ein DEBUG-Launch-Argument
  `-purchaseScenarioForUITests <name>`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| StoreKit 2 (`Product`, `Transaction`, `AppStore.sync`) | framework | nur noch in `StoreKitPurchaseStore` |
| `DigestNotificationCenter` (`NotificationService.swift`), `CommunityPriceDatabase` | pattern | Vorbild Protokoll-Naht mit Fake |
| `RestockUITests/UITestWait.swift` | test | `UITestLaunch.start`, `waitUntilHittable`, `waitForLabel(contains:)`, `defaultTimeout` (20 s) |
| `RestockUITests/PaywallUITests.swift` | test | Vorbild `launchLocked`, `tapWhenHittable`, `assertPaywall`; bleibt unverändert |
| `docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md` | spec | Muster DEBUG-Argument, `strings`-Nachweis im Release |
| Simulator `Restock-Validate` | tool | lokaler Lauf; nie parallel; Sperren `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/PremiumService.swift` | MODIFY | Naht `PurchaseStore`, Werttypen, `StoreKitPurchaseStore`, testbarer Initialisierer, Ausgänge (ca. +95/−30) |
| `SmartCart/Services/FakePurchaseStore.swift` | CREATE | `#if DEBUG`-Fake mit acht Szenarien (ca. +70) |
| `SmartCart/Views/Premium/PaywallView.swift` | MODIFY | Hinweiszeile, Ausgänge, DEBUG-Stillschließen entfällt (ca. +45/−15) |
| `SmartCart/Extensions/DesignSystem.swift` | MODIFY (bedingt) | Chip-Fix, falls Ursache dort (ca. +5) |
| `RestockTests/PremiumServiceTests.swift` | CREATE | 12 Unit-Tests (ca. +150) |
| `RestockUITests/PurchaseUITests.swift` | CREATE | 11 UI-Tests (ca. +190) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung (ca. +12) |
| `CLAUDE.md`, D5-Spec | MODIFY | Doku |

### Estimated Changes

- Code-Dateien: 6 (+ ggf. `DesignSystem.swift` = 7; Limit 4–5 überschritten, vom PO freigegeben).
- LoC: ca. +570/−45, davon Tests ca. 340. Die Kontextdatei schätzte ~+450; die Aufteilung in Fake-Datei,
  Hinweiszeile und zwölf Unit-Tests liegt darüber. **Vor Abschluss `git diff --stat` gegen den Tip-Commit
  prüfen; das LoC-Gate zählt Testcode als Produktivcode** (Memory). Überschreitet der Stand ~+500, vor dem
  Weiterarbeiten beim PO melden, nicht stillschweigend weitermachen.
- Seiteneffekte: im Release keine; im DEBUG-Build nur, wenn `-purchaseScenarioForUITests` gesetzt ist.
  Der Standardweg (echtes StoreKit) ist im Release und ohne Argument verhaltensgleich zu heute, bis auf die
  drei beabsichtigten Hinweise und das nicht mehr stille Schließen bei fehlendem Produkt in DEBUG.

## Definition of Done

- [ ] RED-Tests vor der Umsetzung rot (Unit: kompiliert nicht bzw. fällt; UI: Hinweise fehlen), danach grün
- [ ] Ursache des „…“-Chips im Simulator nachgestellt und mit Screenshot belegt (vorher), Fix mit Screenshot (nachher)
- [ ] Release-Build kompiliert, `FakePurchaseStore` und `purchaseScenarioForUITests` per `strings` nicht enthalten
- [ ] Gesamte Unit- und UI-Suite im gemeinsamen Lauf auf `Restock-Validate` grün, Testzahl > 0, kein Abbruch, `PaywallUITests` unverändert grün
- [ ] Echter Durchlauf der Paywall im Simulator als Nutzer, als Artefakt registriert
- [ ] `CLAUDE.md`-Absatz und D5-Hinweis vorhanden
- [ ] Offene Grenzen in Ticket, Bericht und Zusagen benannt; #145 danach abschließbar, #175 und #178 bleiben offen

## Implementation Details

**Naht (Skizze, Form legt Phase 5 fest, Verhalten ist verbindlich).**

```swift
protocol PurchaseStore: Sendable {
    func loadOffers(ids: Set<String>) async throws -> [PurchaseOffer]
    func purchase(offerID: String) async throws -> PurchaseOutcome
    func sync() async throws
    func entitlements() async -> [EntitlementRecord]
    func updates() -> AsyncStream<Void>
}
enum PurchaseOutcome { case purchased, cancelled, pending }
enum RestoreOutcome { case found, none, failed }
```

Entscheidungsregeln im Dienst (reine, testbare Logik):

- `loadProducts()`: wirft `loadOffers`, bleibt `products` leer (heute: `try?` → leer, unverändert, aber
  nicht mehr still für den Kauf, weil die Paywall bei fehlendem Angebot den Fehlertext zeigt).
- `purchase(offerID:)`: `isPurchasing` während des Aufrufs; `.purchased` → `refreshPurchases()` und
  Rückgabe `.purchased`; `.cancelled`/`.pending` unverändert zurück; ein geworfener Fehler wird
  weitergeworfen (Paywall zeigt „Kauf fehlgeschlagen: …“).
- `restorePurchases()`: `sync()` wirft `PurchaseStoreError.cancelled` → `.cancelled` (`StoreKitPurchaseStore.sync`
  bildet `StoreKitError.userCancelled` darauf ab; Apple meldet so die abgebrochene Anmeldung, laut Foren
  692177/727101 teils auch fehlendes Netz); jeder andere Fehler → `.failed` (kein `refreshPurchases`-Abbruch nötig, es wird dennoch
  gelesen); sonst `refreshPurchases()` und `.found`, wenn `hasPremiumAccess` aus **Käufen** folgt
  (`purchasedProductIDs` enthält eine der drei IDs, **nicht** `developerMode`), sonst `.none`. Grund: Mit
  aktivem Dev-Modus wäre „gefunden“ sonst immer wahr.
- `refreshPurchases()`: `purchasedProductIDs` = IDs der Einträge mit `isRevoked == false`, gefiltert auf die
  drei bekannten IDs.
- Update-Strom: `for await _ in store.updates()` → `refreshPurchases()`. Task wird in `deinit` beendet
  (heute gleich). Bei `autostart: false` startet weder dieser Task noch das initiale Laden; der Test ruft
  `startListening()` und `loadProducts()` selbst.

**Fake-Szenarien (`-purchaseScenarioForUITests <name>`).** Unbekannter Name oder fehlender Wert: kein Fake
(StoreKit), kein Absturz. Die Namen sind gegenüber der Vorgabe unverändert.

| Name | `loadOffers` | `purchase` | `sync` | Berechtigungen danach |
|------|--------------|------------|--------|------------------------|
| `success` | drei Angebote (1,99 € / 8,99 € / 14,99 €) | `.purchased`, legt die gewählte ID ab | – | enthält die gekaufte ID |
| `cancel` | wie `success` | `.cancelled` | – | leer |
| `pending` | wie `success` | `.pending` | – | leer |
| `fail` | wie `success` | wirft `FakePurchaseError` mit `localizedDescription` „Testfehler Kauf“ | – | leer |
| `productMissing` | leer | (nie erreicht) | – | leer |
| `restoreNone` | wie `success` | `.cancelled` | gelingt | leer |
| `restoreFound` | wie `success` | `.cancelled` | gelingt | `lifetime` |
| `restoreFail` | wie `success` | `.cancelled` | wirft | leer |
| `restoreCancel` | wie `success` | `.cancelled` | wirft `PurchaseStoreError.cancelled` (Abbruch) | leer |

Der Fake ist ein `actor` bzw. nutzt eine Sperre (Protokoll ist `Sendable`), hält die abgelegten IDs im
Prozess und schreibt nirgends hin. Folge: Ein erneuter App-Start im selben Szenario beginnt immer leer;
ein „Neustart bleibt freigeschaltet“-Test ist mit dem Fake **nicht** möglich und wird nicht behauptet (der
Persistenzweg liegt bei StoreKit, siehe Grenze 1). Es entsteht kein Zustand im App-Group-Container,
daher kein Aufräum-Argument; `tearDown()` startet nichts (keine Persistenz zu bereinigen).

**Paywall-Verhalten (Entwurf A, PO-freigegeben).** Hinweiszeile unmittelbar unter „Käufe wiederherstellen“
(heutiger Platz des Fehlertexts). Erscheint ein Hinweis, rollt die Paywall animiert (`.smooth`) so weit, dass er
vollständig sichtbar ist (`ScrollViewReader`/`scrollTo`, Platz unverändert; F001). Die Paywall bleibt in allen Hinweis-Fällen offen. Der Hinweis verschwindet,
sobald der Nutzer „Jetzt freischalten“ oder „Käufe wiederherstellen“ antippt. Wörtliche Texte:

| Fall | Art | Text |
|------|-----|------|
| Kauf ausstehend | Info (Akzentfläche) | „Der Kauf wartet auf Zustimmung. Sobald er bestätigt ist, wird Restock Pro automatisch freigeschaltet.“ |
| Wiederherstellen ohne Fund | Info (Akzentfläche) | „Kein Kauf gefunden. Hast du Restock Pro mit einer anderen Apple-ID gekauft, melde dich mit ihr an und versuche es erneut.“ |
| Wiederherstellen fehlgeschlagen | Fehler (Warnfarbe) | „Wiederherstellen hat nicht geklappt. Prüfe die Internetverbindung und versuche es erneut.“ |
| Wiederherstellen abgebrochen (`.cancelled`) | Info (Akzentfläche) | „Wiederherstellen wurde nicht abgeschlossen. Wenn du nicht selbst abgebrochen hast, prüfe die Internetverbindung und versuche es erneut.“ |
| Produkt nicht geladen | Fehler (Warnfarbe) | „Der Kauf konnte nicht geladen werden. Bitte versuche es später erneut.“ (bestehender Text, jetzt auch in DEBUG) |

Unverändert: Kauf erfolgreich → Paywall schließt; Abbruch → keine Meldung, Paywall offen; Wiederherstellen
mit Fund → Paywall schließt; Kauffehler → „Kauf fehlgeschlagen: …“ (Warnfarbe); Texte, Preise, Pläne,
Reihenfolge der Paywall.

**Lokalisierung.** `PaywallView` benutzt heute deutsche Literale in `Text(...)` und `String`-Zuweisungen
(`errorMessage = "…"`), kein `String(localized:)`. Dem folgt die Umsetzung: die fünf neuen Texte stehen als
`Text`-Literale bzw. als `PaywallNotice`-Zeichenkette in derselben Form; kein neuer Schlüssel in
`Resources/`. Die Tests lesen die Texte über Teilstrings (Label enthält), damit Zeilenumbrüche nicht stören.

**Schließen-Chip.** Reihenfolge zwingend: (1) Ursache nachstellen — Paywall im Simulator (iOS 26.5, hell
und dunkel) öffnen, Screenshot des Chips (`docs/artifacts/test-145-d4-kauf-wiederherstellen/chip-vorher-{hell,dunkel}.png`);
Untersuchung der Kandidaten: Breite durch `.lineLimit(1)` + `.minimumScaleFactor(0.75)` in
`ToolbarChipModifier` bei zu schmal vorgeschlagener Toolbar-Breite, Wirkung von
`.sharedBackgroundVisibility(.hidden)` in `ChipToolbarItem` auf die iOS-26-Platzierung, Wirkung des
`.buttonStyle(.pressable)` auf das Label in dieser einen Stelle, Vergleich mit einer zweiten Stelle, an der
„Schließen“ als Chip funktioniert (`grep` nach `toolbarChip` mit „Schließen“/„Abbrechen“; Befund
dokumentieren). (2) Erst mit belegter Ursache gezielt beheben. (3) Nachher-Screenshots gleicher Stellen.
(4) Alle weiteren `ChipToolbarItem`-Nutzer, die vom selben Modifier abhängen, stichprobenartig in einem
Screenshot-Lauf gegenprüfen (Liste in der Phase-5-Notiz); jede Änderung außerhalb der Paywall wird als
Seiteneffekt im Bericht genannt.

**Prüfweg Schließen-Chip im UI-Test (begründet).** Das Accessibility-Label bleibt „Schließen“, auch wenn die
Darstellung „…“ zeigt (SwiftUI kürzt nur die Anzeige). Ein Test auf `buttons["Schließen"].exists` oder auf das
Label wäre deshalb auch im Fehlerzustand grün und beweist nichts. Der Test prüft stattdessen die **gerenderte
Breite**: `XCTAssertGreaterThanOrEqual(app.buttons["Schließen"].frame.width, minWidth)` mit `minWidth`, das in
Phase 5 aus der gemessenen Breite des Fehlerfalls (kleiner, Beleg im Vorher-Lauf) und der Sollbreite
(Textbreite „Schließen“ in 15 pt halbfett ≈ 62 pt + 28 pt Innenabstand = ca. 90 pt) abgeleitet und in der
Testdatei begründet wird; zusätzlich Anhängen eines Screenshots des Chips an das Testergebnis
(`XCTAttachment`, Dateien gehen in die Artefakte). Der Test muss im Fehlerzustand (vor dem Fix) rot sein
(RED-Beweis). Ist die Breite im Fehlerzustand nicht von der im Sollzustand unterscheidbar, weil die
Ursache eine reine Textkürzung bei gleicher Breite ist, wird als Prüfweg stattdessen die Abgrenzung des
Text-Elements im Chip gewählt (`buttons["Schließen"].staticTexts` mit Rahmenbreite gegen die Chipbreite);
die Wahl wird mit den Vorher-Messwerten in der Testdatei und im Bericht begründet. Eine rein visuelle
Prüfung durch Henning ist kein Prüfweg.

**Tests (Unit, `PremiumServiceTests`).** Alle ohne Netz und ohne StoreKit: `PremiumService(store: fake,
autostart: false)`. Der Fake ist hier der steuerbare Doppelgänger (Szenario oder frei setzbare
Berechtigungsliste). `developerMode` wird in `setUp` per `UserDefaults.standard.removeObject` gelöscht und in
`tearDown` geprüft (kein Rest). Singleton `shared` wird nicht benutzt.

**Tests (UI, `PurchaseUITests`).** Start über Hilfe `launch(scenario:)`: `-hasCompletedOnboarding YES
-developerMode NO -purchaseScenarioForUITests <name>`, danach Warten auf `fork.knife` per
`UITestLaunch.start`. **`-developerMode NO` ist hier erlaubt und nötig**, weil es nur liest (wie in
`PaywallUITests`); es wird nie `YES` gesetzt und nie versucht, den Dev-Modus über die Oberfläche zu
entsperren (Argument-Domain-Falle aus D5/D1 bleibt unberührt). Paywall wird über `fork.knife` geöffnet.
Warten nur mit `waitUntilHittable()`, `waitForExistence(timeout: UITestWait.defaultTimeout)` und
`waitForLabel(contains:)`, nie mit 5-s-Fristen für Hinweise oder Sheet-Zu.
„Sheet geschlossen“ heißt: `staticTexts["Restock Pro"]` existiert nicht mehr (Muster `closePaywall`).
Kein App-Group-Zustand, daher kein `tearDown`-Aufräumer; `tearDown()` beendet die App.

## Test Plan

### Automated Tests (TDD RED)

Unit, `RestockTests/PremiumServiceTests.swift`:

- [ ] U1 `testEntitlementPerProductIDGrantsAccess` — je ID (monthly, yearly, lifetime) ein Durchlauf; jede schaltet `hasPremiumAccess` frei.
- [ ] U2 `testUnknownProductIDDoesNotGrantAccess` — Berechtigung mit fremder ID: kein Zugang.
- [ ] U3 `testRevokedTransactionGivesNoAccess` — `EntitlementRecord(isRevoked: true)` für lifetime: kein Zugang; Gegenprobe nicht widerrufen: Zugang.
- [ ] U4 `testNoEntitlementsMeansNoAccessWithoutDeveloperMode` — leer, Dev-Modus aus: kein Zugang.
- [ ] U5 `testPurchaseSuccessGrantsAccessAndReturnsPurchased` — `.purchased`, Zugang, `isPurchasing` danach `false`.
- [ ] U6 `testPurchaseCancelledReturnsCancelledWithoutAccess`.
- [ ] U7 `testPurchasePendingReturnsPendingWithoutAccess`.
- [ ] U8 `testPurchaseErrorIsThrownAndResetsIsPurchasing`.
- [ ] U9 `testRestoreWithPurchaseReturnsFoundAndGrantsAccess`.
- [ ] U10 `testRestoreWithoutPurchaseReturnsNone`, plus Variante mit aktivem Dev-Modus: weiter `.none` (zählt nur Käufe).
- [ ] U11 `testRestoreSyncThrowingReturnsFailed`.
- [ ] U12 `testUpdateStreamUnlocksAfterPending` — Kauf `.pending` (kein Zugang), danach meldet der Fake über `updates()` eine Berechtigung; Dienst hört zu und schaltet frei; `await` mit Frist 20 s, kein `sleep`.
- [ ] U13 `testRestoreCancelledReturnsCancelledNotFailed` — `sync` wirft `PurchaseStoreError.cancelled`: `.cancelled`, nicht `.failed`, kein Zugang.
- [ ] U14 `testUpdateStreamRevocationRemovesAccess` — erst Zugang, dann Widerruf über `updates()`: Zugang weg (F003).

UI, `RestockUITests/PurchaseUITests.swift`:

- [ ] P1 `testPurchaseSuccessClosesPaywallAndUnlocksRecipePlan` — Szenario `success`: „Jetzt freischalten…“ → Sheet zu → `fork.knife` öffnet erneut: `Tag hinzufügen` statt Paywall.
- [ ] P2 `testPurchaseCancelledKeepsPaywallOpenWithoutMessage` — `cancel`: Paywall offen, keine der fünf Meldungen.
- [ ] P3 `testPurchasePendingShowsApprovalNoticeAndKeepsPaywallOpen` — `pending`: Text sichtbar, Sheet offen, danach `fork.knife` weiter gesperrt (nach Schließen öffnet erneut die Paywall).
- [ ] P4 `testPurchaseFailureShowsErrorAndKeepsPaywallOpen` — `fail`: „Kauf fehlgeschlagen: Testfehler Kauf“ sichtbar, Sheet offen.
- [ ] P5 `testMissingProductShowsLoadErrorInsteadOfClosing` — `productMissing`: Fehlertext sichtbar, Sheet offen (heute in DEBUG: schließt still).
- [ ] P6 `testRestoreWithoutPurchaseShowsNoPurchaseNotice` — `restoreNone`: Info sichtbar, Sheet offen.
- [ ] P7 `testRestoreFoundClosesPaywallAndUnlocks` — `restoreFound`: Sheet zu, Rezeptplan öffnet sich.
- [ ] P8 `testRestoreFailureShowsErrorNotice` — `restoreFail`: Fehler sichtbar, Sheet offen.
- [ ] P9 `testNoticeDisappearsOnNextTap` — `pending`, Hinweis da; Tipp auf „Käufe wiederherstellen“ lässt den Kauf-Hinweis verschwinden (im Szenario `pending` gelingt `sync`, ohne Fund erscheint danach der Wiederherstell-Hinweis, nie beide gleichzeitig); zweite Variante: Hinweis nach Tipp auf „Jetzt freischalten“ ersetzt.
- [ ] P10 `testNoticeIsDirectlyBelowRestoreButton` — Hinweis-Rahmen liegt unter dem Rahmen von „Käufe wiederherstellen“ und über dem Rechtstext („Abonnements verlängern sich …“).
- [ ] P12 `testRestoreCancelledShowsNeutralNotice` — `restoreCancel`: neutraler Hinweis vollständig sichtbar, keine Fehlermeldung, Sheet offen.
- [ ] P13 `testRepeatedSameNoticeScrollsIntoViewAgain` — `productMissing`: Kaufen, Hinweis vollständig sichtbar; ein kurzer, langsamer Zug zurück nach oben (Sheet bleibt offen, Hinweis nicht mehr ganz sichtbar); erneut kaufen → derselbe Hinweis wieder vollständig sichtbar (F004).
- [ ] P11 `testCloseChipShowsFullWord` — Chip-Breite gemäß „Prüfweg Schließen-Chip“, hell und dunkel (zwei Starts, `-AppleInterfaceStyle Dark` bzw. `Light`), Screenshot angehängt.

Nachweise:

- [ ] T-Rel: `xcodebuild -configuration Release -destination 'generic/platform=iOS Simulator' build` gelingt; `strings` auf die ausführbare Datei: weder `FakePurchaseStore` noch `purchaseScenarioForUITests` kommen vor; Gegenprobe Debug-Build: beide kommen vor.
- [ ] T-Suite: gesamte Unit- und UI-Suite im gemeinsamen Lauf auf `Restock-Validate`, ohne zusätzliche Build-Settings, Testzahl > 0, kein Abbruch, kein Retry-Flag; `PaywallUITests` unverändert grün.
- [ ] T-Durchlauf: App im Simulator als Nutzer (siehe AC-18).
- [ ] T-Diff: `git diff --stat` gegen den Tip-Commit.

## Acceptance Criteria

- **AC-1:** GIVEN Start (DEBUG) mit `-purchaseScenarioForUITests success` und gesperrtem Rezeptplan, WHEN der Nutzer die Paywall über `fork.knife` öffnet und „Jetzt freischalten…“ antippt, THEN schließt die Paywall, und ein erneutes Tippen auf `fork.knife` öffnet den Rezeptplan („Tag hinzufügen“) ohne Paywall. Ebenso nach Kauf aus der Ausgaben-Analyse (`chart.bar`) und der Einstellungszeile „Restock Pro freischalten“ (dort verschwindet die Zeile, „Pro aktiv“ erscheint). Tests: P1, U5.
- **AC-2:** GIVEN Szenario `cancel`, WHEN der Nutzer „Jetzt freischalten…“ antippt, THEN bleibt die Paywall offen, und keiner der vier Hinweis-/Fehlertexte erscheint; der Rezeptplan bleibt gesperrt. Tests: P2, U6.
- **AC-3:** GIVEN Szenario `pending`, WHEN der Nutzer kauft, THEN erscheint direkt unter „Käufe wiederherstellen“ der Text „Der Kauf wartet auf Zustimmung. Sobald er bestätigt ist, wird Restock Pro automatisch freigeschaltet.“ auf der Akzentfläche, die Paywall bleibt offen, `hasPremiumAccess` bleibt `false`. Tests: P3, U7.
- **AC-4:** GIVEN Szenario `fail`, WHEN der Nutzer kauft, THEN erscheint „Kauf fehlgeschlagen: Testfehler Kauf“ in der Warnfarbe, die Paywall bleibt offen, `isPurchasing` ist danach `false` (der Kaufknopf ist wieder antippbar). Tests: P4, U8.
- **AC-5:** GIVEN Szenario `productMissing`, WHEN der Nutzer kauft, THEN erscheint in **DEBUG wie in Release** „Der Kauf konnte nicht geladen werden. Bitte versuche es später erneut.“ in der Warnfarbe, und die Paywall schließt **nicht**. Die Verzweigung `#if DEBUG … dismiss()` in `PaywallView.purchase()` ist entfernt. Test: P5; Diff.
- **AC-6:** GIVEN Szenario `restoreNone`, WHEN der Nutzer „Käufe wiederherstellen“ antippt, THEN erscheint „Kein Kauf gefunden. Hast du Restock Pro mit einer anderen Apple-ID gekauft, melde dich mit ihr an und versuche es erneut.“ auf der Akzentfläche, die Paywall bleibt offen. Tests: P6, U10.
- **AC-7:** GIVEN Szenario `restoreFound`, WHEN der Nutzer „Käufe wiederherstellen“ antippt, THEN schließt die Paywall, und der Rezeptplan ist frei. Tests: P7, U9.
- **AC-8:** GIVEN Szenario `restoreFail`, WHEN der Nutzer „Käufe wiederherstellen“ antippt, THEN erscheint „Wiederherstellen hat nicht geklappt. Prüfe die Internetverbindung und versuche es erneut.“ in der Warnfarbe, die Paywall bleibt offen. Tests: P8, U11.
- **AC-9:** GIVEN ein sichtbarer Hinweis oder Fehler, WHEN der Nutzer „Jetzt freischalten…“ oder „Käufe wiederherstellen“ antippt, THEN ist der bisherige Hinweis weg, bevor das Ergebnis des neuen Vorgangs erscheint; es steht nie mehr als ein Hinweis zugleich da. Test: P9.
- **AC-10:** GIVEN ein sichtbarer Hinweis, WHEN die Paywall betrachtet wird, THEN liegt er unmittelbar unter „Käufe wiederherstellen“ und über dem Rechtstext. Test: P10.
- **AC-11:** GIVEN der Dienst mit Fake, WHEN Berechtigungen für `monthly`, `yearly` oder `lifetime` vorliegen, THEN ist `hasPremiumAccess` wahr; bei fremder ID, ohne Berechtigung (Dev-Modus aus) oder bei **widerrufener** Transaktion (`isRevoked`) ist es falsch. Tests: U1–U4.
- **AC-12:** GIVEN der Dienst mit Fake und `.pending`-Kauf, WHEN die Zustimmung später über den Update-Strom eintrifft, THEN schaltet der Dienst frei, ohne dass der Nutzer etwas tut. Test: U12.
- **AC-13:** GIVEN Start ohne `-purchaseScenarioForUITests` (oder im Release), WHEN die App läuft, THEN benutzt `PremiumService.shared` `StoreKitPurchaseStore`; ein unbekannter Szenarioname fällt auf StoreKit zurück. Beleg: Unit-Test `testUnknownScenarioFallsBackToStoreKit` (Auswahlfunktion `defaultStore(arguments:)` rein, ohne StoreKit-Aufruf, Typvergleich) und Diff; Verhalten der Naht gegenüber StoreKit ist **nicht** automatisiert belegt (Grenze 1).
- **AC-14:** GIVEN die Paywall im Simulator (iOS 26.5), WHEN die Ursache des „…“-Chips untersucht wird, THEN liegen vor dem Fix Vorher-Screenshots (hell, dunkel) und eine benannte, belegte Ursache in `docs/artifacts/test-145-d4-kauf-wiederherstellen/` vor, und der Fix ist auf diese Ursache zugeschnitten (kein Raten, Reproduktion zuerst).
- **AC-15:** GIVEN der Fix, WHEN die Paywall hell und dunkel geöffnet wird, THEN zeigt der Chip das vollständige Wort „Schließen“; der UI-Test P11 prüft die gerenderte Breite (nicht nur Label/Existenz), war vor dem Fix rot und danach grün; Nachher-Screenshots liegen im Artefaktordner. Wurde `DesignSystem.swift` geändert, sind alle anderen `ChipToolbarItem`-Nutzer geprüft und im Bericht als Seiteneffekt aufgelistet.
- **AC-16:** GIVEN die bestehenden Paywall-Pfade, WHEN `PaywallUITests` (unverändert) läuft, THEN ist die Klasse grün: Sperre an fork.knife, chart.bar und Einstellungszeile, Gegenprobe `-premiumForScreenshots`, falsches Dev-Passwort. Preise, Pläne und Reihenfolge der Paywall sind unverändert.
- **AC-17:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert und `strings` auf die ausführbare Datei läuft, THEN gelingt der Build, und weder `FakePurchaseStore` noch `purchaseScenarioForUITests` kommen vor (im Debug-Build kommen beide vor). Beleg als Textdatei im Artefaktordner.
- **AC-18:** GIVEN der fertige Stand, WHEN die App im Simulator als Nutzer durchgespielt wird, THEN sind (a) ohne Szenario-Argument die Paywall öffnet sich, der Kauf mangels Produkten (`products` leer) zeigt „Der Kauf konnte nicht geladen werden …“ statt stillem Schließen, „Käufe wiederherstellen“ verhält sich ohne Konto/Produkte nachvollziehbar (Ergebnis wörtlich festgehalten, kein Absturz), und (b) jedes der acht Szenarien einmal gestartet und der jeweilige Ausgang gesehen, mit Screenshots. Der Durchlauf ist als Artefakt registriert (echter Lauf, Commit-Kennung und Zeitstempel passend, nie von Hand gesetzt).
- **AC-19:** GIVEN die gesamte Unit- und UI-Suite, WHEN sie im gemeinsamen Lauf auf `Restock-Validate` läuft (ohne zusätzliche Build-Settings, nie parallel, beide Sperren gehalten), THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag. Die UI-Tests nutzen nie `-developerMode YES` und räumen nichts Dauerhaftes (es entsteht kein App-Group-Zustand); `developerMode` ist nach dem Lauf unverändert.
- **AC-20:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN enthält er nur die genannten Dateien (`PremiumService.swift`, `FakePurchaseStore.swift`, `PaywallView.swift`, ggf. `DesignSystem.swift`, `PremiumServiceTests.swift`, `PurchaseUITests.swift`, `project.pbxproj`, `CLAUDE.md`, D5-Spec), bleiben `Restock.storekit`, Scheme, `Info.plist`, `@AppStorage`-Schlüssel und die Produkt-IDs unverändert, liegen die Änderungen bei ca. +570/−45 (Überschreitung von +500 wird vorher dem PO gemeldet).
- **AC-21:** GIVEN der Abschluss des Durchgangs, WHEN Ticket, Berichte und `CLAUDE.md` formuliert werden, THEN stehen die offenen Grenzen 1–6 ausdrücklich darin (echter StoreKit-Kauf und Kaufdialog nicht automatisiert, #178; Produkte in App Store Connect ungeprüft, #175; Sandbox/TestFlight nur auf Hennings Wort; `sharedlists` ungenutzt; Familienfreigabe/SCA nur als Fake-`.pending`; Persistenz eines Kaufs über Neustart nicht mit dem Fake belegbar), und keine Zusage klingt nach „Kauf getestet“, ohne diese Einschränkung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue
- **Rationale:** Protokoll-Naht mit Fake nach bestehendem Muster (`DigestNotificationCenter`,
  `CommunityPriceDatabase`, `SharedStoreDatabase`); Standard bleibt die Systemschnittstelle. Eigene Werttypen
  statt `Product`/`Transaction`, weil diese Typen außerhalb von StoreKit nicht konstruierbar sind.
  Gekippte frühere Entscheidung: die offene Grenze aus #98 D5 („Kauf, Wiederherstellen und Release-Fehlermeldung
  nicht automatisiert“) wird teilweise geschlossen; die Arbeitsentscheidung „kein Produktcode für
  Paywall-Tests“ entfällt.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Naht vor StoreKit, Fake nur DEBUG, Launch-Argument | läuft in CI und lokal, prüft unsere Logik und die ganze Paywall-Oberfläche je Ausgang; prüft **nicht** Apples Kaufablauf |
| B | `SKTestSession` auf iOS-26.2-Runtime (~8 GB), nur Skriptlauf | prüft zusätzlich Apples Ablauf gegen `Restock.storekit`; Download, außerhalb CI, mit Xcode 27.1 ungewiss; später als Ergänzung (#178) |
| C | Warten auf Xcode 27.2 | könnte B auch in CI erlauben (laut MacObserver); Beta, Zeit; beobachten (#178) |
| D | Sandbox/TestFlight auf Hennings iPhone | echter Kauf gegen App Store Connect, braucht angelegte Produkte (#175); nur auf Hennings Wort, Abschluss vor Release |
| E | `Restock.storekit` ins Scheme | ändert Xcode-Läufe, die Henning startet, und ist auf den Runtimes dennoch defekt; verworfen |
| F | Fake im Release-Binary mit Laufzeitschalter | Gefahr, dass ein Argument im Store-Build Käufe vortäuscht; verworfen, `#if DEBUG` plus `strings`-Nachweis |

Kein Modell beteiligt: deterministische Testlogik, Regeln statt Sprachmodell.

**Entscheidung:** Weg A, B/C als Ergänzung in #178, D vor dem Release.

## Risiken

- **Falsches Vertrauen:** Grüne Tests belegen unsere Logik und Oberfläche, nicht den Kauf. Gegenmaßnahme: Grenzen 1–6 in jeder Zusage (AC-21), Weg D vor dem Release.
- **Singleton:** `PremiumService.shared` hält Zustand im Prozess; das Fake-Szenario wird beim Start gelesen. Gegenmaßnahme: UI-Tests starten die App je Test neu; Unit-Tests nutzen eigene Instanzen mit `autostart: false`.
- **Verdrahtungsfehler der Naht:** Ein Fehler in `StoreKitPurchaseStore` (Abbildung `Product`/`Transaction` → Werttypen) würde von keinem Test gefangen. Gegenmaßnahme: Abbildung bleibt wörtlich die heutige Logik, minimal gehalten; Diff-Prüfung in Phase 6; Durchlauf AC-18(a) zeigt zumindest den Pfad „keine Produkte“ mit echtem StoreKit.
- **`isHittable`/Warten:** CI-Abfragen dauern bis 31 s (Memory); 20-s-Hilfen, nie 5 s; Hinweistexte per Teilstring.
- **Ursache des „…“-Chips unbekannt:** Der Fix ist erst nach Reproduktion zulässig; weitet sich die Ursache auf `DesignSystem.swift` aus, betrifft die Änderung andere Bildschirme (Seiteneffekte prüfen, ggf. PO informieren).
- **Argument-Domain-Falle:** Nie `-developerMode YES`; `NO` nur als Lesewert. Ein übrig gebliebenes `developerMode = true` aus anderen Klassen würde `hasPremiumAccess` verfälschen (Zustandsleck): Prüfung im gemeinsamen Lauf (AC-19).
- **LoC-Gate zählt Testcode als Produktivcode:** Abschätzung über Freigabe; frühzeitig `git diff --stat`.
- **Simulator nie parallel**, beide Sperren, „Executed 0 tests“ ist kein Grün (Memory).
- **Nichts auf Hennings Geräten** (Regel „Hennings Geräte nur auf sein Wort“); Simulator genügt.

## Changelog

- 2026-10-19: Initial spec created (Durchgang 4 von #145; Naht vor StoreKit mit DEBUG-Fake, drei stille Stellen nach Entwurf A, „Schließen“-Chip mit Reproduktion vor dem Fix, Unit- und UI-Tests, offene Grenzen #175/#178)
- 2026-10-19: Phase 6 umgesetzt (Naht `PurchaseStore` mit `StoreKitPurchaseStore` und DEBUG-`FakePurchaseStore`, `PurchaseOffer.price` als `Decimal?`, Hinweise unter „Käufe wiederherstellen“, DEBUG-`dismiss()` entfernt; Chip-Ursache: iOS 26.5 schlägt linken Toolbar-Elementen Breite 0 vor, `.frame(minWidth: 40)` ergab 40 pt „…“, Fix `.fixedSize(horizontal: true, vertical: false)` in `ToolbarChipModifier`, siehe `chip-ursache.md`; PO-Entscheidungen: Umfang ca. +810 Zeilen freigegeben, Chip-Fix app-weit auf alle linken Chips)
- 2026-10-20: Adversary Runde 1: F001 Hinrollen, F002 neutraler Hinweis bei Abbruch (PO; Grund: Apple meldet fehlendes Netz bei AppStore.sync teils als userCancelled, Foren 692177/727101 — https://developer.apple.com/forums/thread/692177, https://developer.apple.com/forums/thread/727101; Apples Doku zu `AppStore.sync()` nennt keine Fehlerfälle). Neu: `RestoreOutcome.cancelled`, `PurchaseStoreError.cancelled`, Szenario `restoreCancel`, UI-Test `testRestoreCancelledShowsNeutralNotice`, `assertNotice` prüft vollständige Sichtbarkeit (Fenster enthält Rahmen, antippbar), Unit-Tests `testRestoreCancelledReturnsCancelledNotFailed` und `testUpdateStreamRevocationRemovesAccess` (F003). Umfang: PO ~+350 Zeilen App-Code (`loc_limit_override` 360)

- 2026-10-20: Acceptance Criteria bewusst unverändert (Spec-Freeze nach Freigabe). Die PO-Entscheidungen F001 (Hinweis vollständig sichtbar) und F002 (neutraler Hinweis bei `restoreCancel`) sind in Implementation Details und Test Plan (U13, U14, P12) festgehalten und ergänzen AC-8/AC-10; AC-2 („keiner der vier Texte“) und AC-18(b) („acht Szenarien“) bleiben erfüllt, der Durchlauf nimmt `restoreCancel` zusätzlich auf. Eine versehentliche Bash-Änderung an AC-2/AC-18 und zwei Scope-Zeilen wurde zurückgenommen.
- 2026-10-20: Adversary Runde 3/4: F004 Hinrollen an Ereignis gebunden (`noticeEvent` wechselt bei jedem gesetzten Hinweis, Hilfsfunktion `show(_:)`; vorher hing `onChange` am Wert, ein synchron gleich gesetzter Hinweis rollte nicht erneut). Test P13.
- 2026-10-20: Adversary Runde 5/6: F005 (ein Schließen-Tipp ohne Wirkung in einem von drei Gesamtläufen) per Vergleichsmessung geschlossen: origin/main 0/300, dieser Stand 0/300 Fehlschläge unter gleicher Last (`adversary-r6-vergleich.md`). Offene Grenze: Der Aussetzer trat in der Messung nicht auf; ausgeschlossen ist nur ein merklicher Unterschied zu main. Validierung: Gesamtlauf Unit 610/610, UI 130 (127 bestanden, 3 übersprungene Gates), 0 Fehlschläge. Umfang tatsächlich: App-Code +370/−92, gesamt +969/−93 (über der Freigabe von ~+350 bzw. ~+810, Mehr aus den Nachbesserungen der Prüfrunden).
