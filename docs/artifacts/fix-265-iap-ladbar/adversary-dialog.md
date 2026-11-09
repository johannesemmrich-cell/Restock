# Adversary Dialog — fix-265-iap-ladbar
Spec: docs/specs/views/paywall-produkte-nachladen.md
Datum: 2026-11-09 12:42

## Checkliste
- [x] **AC-1:** Unit: Ist `products` leer und liefert der Store beim zweiten Abruf Angebote, füllt `reloadProductsIfNeeded()` die Liste; `offer(for:)` liefert danach einen Treffer.
- [x] **AC-2:** Unit: Ist `products` schon gefüllt, ruft `reloadProductsIfNeeded()` den Store nicht erneut ab (Zähler des Schein-Stores bleibt unverändert).
- [x] **AC-3:** Unit: Zwei gleichzeitige Aufrufe von `reloadProductsIfNeeded()` führen zu genau einem Store-Abruf.
- [x] **AC-4:** Unit: Wirft der Store beim Laden, bleibt `products` leer, `reloadProductsIfNeeded()` wirft nicht, ein späterer Aufruf lädt erneut.
- [x] **AC-5:** UI (Reproduktion, vor dem Fix rot): Mit `-purchaseScenarioForUITests productsLoadLate` und `-developerMode NO` öffnet die Paywall; nach Tipp auf den Kaufknopf erscheint **nicht** „Der Kauf konnte nicht geladen werden“, der Kauf läuft durch und die Paywall schließt sich. Vor der Änderung zeigt derselbe Ablauf den Fehlertext (RED belegt).
- [x] **AC-6:** UI: Das Szenario `productMissing` zeigt weiter den Fehlertext (Bestandstest bleibt grün; Nachladen ersetzt den Fehler nur, wenn Produkte da sind).
- [x] **AC-7:** Bestehende Tests `PremiumServiceTests` U1–U12 und `PurchaseUITests` P1–P11 bleiben grün; Klassenlauf mit Testzahl, Fehlschlägen und Abbruchprüfung (kein Null-Test-Lauf).
- [x] **AC-8:** Release-Nachweis: `strings` am Release-Binary enthält weder `FakePurchaseStore` noch `productsLoadLate`.
- [x] **AC-9:** `CURRENT_PROJECT_VERSION` steht in `project.yml` und `project.pbxproj` auf 41 (Widget und Teilen-Erweiterung gleiche Nummer); der Diff gegen `origin/main` berührt keine Datei aus der Liste „Nicht berührt“ oben.
- [x] **AC-10:** Benutzen statt nur testen: Die Paywall wurde im Simulator mit `productsLoadLate` geöffnet und der Kauf ausgelöst. Kriterium: Die Aufnahme nach dem Tipp (`docs/artifacts/fix-265-iap-ladbar/nach-kauf.png`) zeigt keinen Fehlertext „Der Kauf konnte nicht geladen werden“ und die Paywall ist geschlossen; Claude prüft die Aufnahme per Bildansicht und vermerkt „kein Fehlertext, Paywall geschlossen“ in `benutzen-befund.md`.
- [x] **AC-11:** Unit: Der Kaufpfad-Nachlader ist einzeln belegt: Ein Schein-Store, dessen erster Abruf leer und dessen zweiter gefüllt ist, liefert nach genau einem Aufruf von `reloadProductsIfNeeded()` ein Angebot (entspricht dem Aufruf aus `PaywallView.purchase()`, unabhängig vom `.task` beim Erscheinen). AC-5 belegt Verhalten 2 und 3 zusammen und ist damit kein Einzelbeleg für Verhalten 3.

## Dialog

### Runde 1
**Adversary:** Angriff auf Unit-Logik und Doppelstart. Gelesen: Merker vor dem await gesetzt, `defer` setzt zurück, auch bei Fehler (loadProducts wirft nie, `try?`). Zweiter gleichzeitiger Aufruf trifft auf `isLoadingProducts` und kehrt zurück (@MainActor, kein Zwischenpunkt zwischen guard und Setzen).
Code reference: SmartCart/Services/PremiumService.swift:206
Confirmation AC-1: Code reference: SmartCart/Services/PremiumService.swift:207 — leere Liste, Store zweiter Abruf gefüllt; Test testReloadFillsEmptyProductsOnSecondFetch (RestockTests/PremiumServiceTests.swift:253). Status CONFIRMED.
Confirmation AC-2: Code reference: SmartCart/Services/PremiumService.swift:207 — guard products.isEmpty; testReloadDoesNothingWhenProductsAlreadyLoaded, loadCalls == 1. CONFIRMED.
Confirmation AC-3: Code reference: SmartCart/Services/PremiumService.swift:208 — Merker vor dem await; testConcurrentReloadsFetchOnlyOnce mit 200 ms Verzögerung, loadCalls == 1. CONFIRMED.
Confirmation AC-4: Code reference: SmartCart/Services/PremiumService.swift:209 — defer-Reset; testReloadWithThrowingStoreKeepsProductsEmptyAndRetriesLater. CONFIRMED.
Confirmation AC-11: testSingleReloadYieldsOfferAfterEmptyFirstFetch, ein Aufruf, loadCalls == 2 (1 Vorlauf + 1 Nachladen). CONFIRMED.
Finding F001: Severity LOW, Category edge_case.
  Code reference: SmartCart/Services/PremiumService.swift:197
  Description: `loadProducts()` aus dem `init` setzt `isLoadingProducts` nicht und schreibt `products` bedingungslos (auch `[]`).
  Spec requirement: Verhalten 1 — nur reloadProductsIfNeeded wird gegen Doppelstart geschützt; loadProducts "bleibt".
  Conflict: Öffnet man die Paywall, solange der Start-Abruf noch läuft, entstehen zwei Abrufe; kommt ein langsamer leerer Start-Abruf nach einem gefüllten Nachladen zurück, könnte er die Liste wieder leeren. Praktisch selten, Folge nur ein weiterer Tipp (Nachladen je Tipp). Keine Spec-Verletzung.
  Remediation: loadProducts nur nicht-leer überschreiben lassen oder Merker auch dort setzen (Folgeticket).

### Runde 2
**Adversary:** Angriff auf Kaufpfad, Fehlertext, Release, Build, Scope, UI-Beleg.
Code reference: SmartCart/Views/Premium/PaywallView.swift:456
Confirmation AC-5: Code reference: SmartCart/Views/Premium/PaywallView.swift:457 — genau ein `await reloadProductsIfNeeded()` je purchase(); danach unveränderter guard und Fehlertext (Diff ohne Textänderung); .task bei Zeile 91. UI-Lauf 17 Tests, 0 Fehlschläge (test-green-ui-output.txt), Test testProductsLoadLateStillPurchasable (RestockUITests/PurchaseUITests.swift:181), RED vorher in test-red-ui-output.txt. CONFIRMED.
Confirmation AC-6: Code reference: SmartCart/Services/FakePurchaseStore.swift:41 — productMissing liefert weiter leer vor dem Zähler; Fehlertext bleibt, Bestandstest im grünen Lauf. CONFIRMED.
Confirmation AC-7: Unit 22 Tests, 0 Fehlschläge, UI 17 Tests, 0 Fehlschläge, beide TEST SUCCEEDED, kein Null-Test-Lauf. Nicht neu gefahren (Beweisdateien mit Zeitstempeln 12:32/12:37 geprüft). CONFIRMED.
Confirmation AC-8: Code reference: SmartCart/Services/FakePurchaseStore.swift:1 — gesamte Datei in #if DEBUG (Zeile 1 bis 88); Szenario nur dort definiert (productsLoadLate kommt nur in dieser Datei vor); release-strings-check.txt: 0 Treffer. CONFIRMED.
Confirmation AC-9: Code reference: project.yml:24 und :75 (41), Restock.xcodeproj/project.pbxproj: 6 Stellen 41, keine 40 übrig; Diffstat gegen origin/main berührt weder Localizable.strings, Entitlements, Schema, PrivacyInfo noch ci.yml. CONFIRMED.
Confirmation AC-10: nach-kauf.png per Bildansicht geprüft: Startseite sichtbar, kein Paywall-Sheet, kein Fehlertext; benutzen-befund.md vermerkt es. Das Bild stammt aus dem UI-Test-Anhang (RestockUITests/PurchaseUITests.swift:185), gleicher Weg wie händisch. CONFIRMED.
Code reference: SmartCart/Services/FakePurchaseStore.swift:28
Weitere Probe: Fake zählt loadCalls im actor (FakePurchaseStore.swift:28, 42): erster Abruf leer, zweiter gefüllt. Doppelte purchase()-Tipps: isPurchasing unverändert, Nachladen startet keinen Kauf.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Zusatz: `isLoadingProducts` wird nur in reloadProductsIfNeeded geschrieben (PremiumService.swift:208); Bedingung davor: products leer und kein Lauf; Test dafür: testConcurrentReloadsFetchOnlyOnce.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Alle 11 ACs belegt. Tests (aus Beweisdateien): Unit 22 bestanden, 0 fehlgeschlagen; UI 17 bestanden, 0 fehlgeschlagen, 0 übersprungen. Nicht neu gefahren.
Finding F001 (LOW): init-Abruf ohne Doppelstart-Schutz, kein Blocker.
Edge cases: geprüft, keine gebrochen. Regressions: keine gefunden.
Checklist: 11/11 points proven

## Geprüfte Dateien

- sha256:6b42aa0bfef032c8b40c3fbf41539f94ffd5bc295eea769c30d476eb47935415  SmartCart/Services/PremiumService.swift
- sha256:2e58abc868a5c9c05e6902191ecee3af0aa5b21a4cbef42cc4a7146c9d45ec7c  SmartCart/Views/Premium/PaywallView.swift

## Prüfbasis

- base: 8d58a594a4e193c84044c20e9d61c1bfb6194221
- blob:75034c55b6f1e51d0ab36af1fd484ae2da948b4f  SmartCart/Services/PremiumService.swift
- blob:ee08ec1ca38fb300c9c43e14a2ab077cc184c557  SmartCart/Views/Premium/PaywallView.swift

## Geprüfte Dateien

- sha256:28bc9a4be485f93ce580dea6a2ec8240d9908efd9802215725e485fe14f1432e  SmartCart/Services/FakePurchaseStore.swift
- sha256:6b42aa0bfef032c8b40c3fbf41539f94ffd5bc295eea769c30d476eb47935415  SmartCart/Services/PremiumService.swift
- sha256:2e58abc868a5c9c05e6902191ecee3af0aa5b21a4cbef42cc4a7146c9d45ec7c  SmartCart/Views/Premium/PaywallView.swift

## Prüfbasis

- base: 8d58a594a4e193c84044c20e9d61c1bfb6194221
- blob:fea045f18a0f9749039c19c32120712e1804d033  SmartCart/Services/FakePurchaseStore.swift
- blob:75034c55b6f1e51d0ab36af1fd484ae2da948b4f  SmartCart/Services/PremiumService.swift
- blob:ee08ec1ca38fb300c9c43e14a2ab077cc184c557  SmartCart/Views/Premium/PaywallView.swift
