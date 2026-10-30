# Adversary-Dialog fix-215-paywall-rechtslinks (#215)

Prüfer: implementation-validator, 2026-10-30. Nur lesend, keine Simulator-Läufe; Belege aus Code, Roh-Logs und Bildansicht.

### Runde 1

Je AC geprüft, was zu sehen sein muss, und Belege gesammelt.
- AC-1/2/6/7: Testcode `PaywallUITests.swift` (`assertLegalLinks`) prüft `app.links`, Fenster-Rahmen, `waitUntilHittable`; kein `tap()` auf die Links. Der AXXXL-Test prüft zusätzlich `intersects`. Roh-Log: beide Tests passed.
- AC-3: URLs im Produktcode nur in `PaywallView.swift:9-10`; die Links benutzen nur diese Konstanten.
- AC-4: Abo-Text mit Jahr, Monat, 24 Stunden, Apple-ID, automatischer Verlängerung, „kein Abo“; Preise aus `productPrice(for:)`.
- AC-5: `PaywallLegalLinksTests` mit Abschnittssuche und Gegenproben; beide Store-Dateien stimmen.
- Nachfragen: Null-Test-Lauf? Bestandstest-Änderung vereinbar mit der Prüfabsicht? Aufnahmen vom aktuellen Stand? AC-10 sauber?

### Runde 2

Antworten durch eigene Recherche im Repo:
- Roh-Log `test-green-ui-purchase.txt`: 7 Tests/0 Fehlschläge, 13/0, gesamt 20/0, TEST SUCCEEDED, Unit 3 passed; kein Null-Test-Lauf, keine Läufer-Neustarts.
- `PurchaseUITests.swift:274`: Präfix „Abonnements verlängern sich“ → „Restock Pro – Jährlich“; die Lageprüfung (Hinweis unter „Wiederherstellen“, über dem Rechtstext) bleibt, Prüfabsicht erhalten.
- Aktualität: `PaywallView.swift` zuletzt 15:28, `PurchaseUITests.swift` 16:09, maßgeblicher Lauf bis 16:14; Aufnahmen 17:32, Store-Shots 17:22–17:24, also neuer als jede Codeänderung.
- Bilder per Bildansicht: Abo-Text (7 Zeilen) und Link-Zeile in hell und dunkel vollständig; `de/05-pro.png` endet am angeschnittenen „Käufe wiederherstellen“.
- AC-10: `git diff --name-only origin/main...HEAD` ohne verbotene Datei (ein Zwei-Punkt-Diff zeigt wegen vorgerücktem `origin/main` Fremddateien aus feat-233, kein Defekt dieses Workflows); AppStorage-Treffer vorher 0, nachher 0.

Befunde:
1. LOW: Abo-Text in `.tertiary` mit 11 pt, kontrastarm in hell und dunkel, Kontrast nicht gemessen; laut Spec so gewollt, kein AC.
2. INFO: Stand ist noch nicht committet.
3. INFO: Öffnen der Links im Browser nicht automatisiert geprüft (AC-7 verlangt das bewusst nicht).
4. INFO: AC-8 „nicht sichtbar“ gilt nur für die Bildgröße 1206×2622.

Defekte mit Schwere MEDIUM oder höher: keine.

Code reference: SmartCart/Views/Premium/PaywallView.swift:9
Code reference: RestockUITests/PaywallUITests.swift:1
Code reference: RestockUITests/PurchaseUITests.swift:274
Code reference: RestockTests/PaywallLegalLinksTests.swift:1

- [x] AC-1: `assertLegalLinks` (`app.links["Datenschutz"]`, `app.links["Nutzungsbedingungen (EULA)"]`); Log `test-green-ui-purchase.txt:416` passed
- [x] AC-2: `window.contains(link.frame)` plus `scrollUntilHittable`/`waitUntilHittable`; Log `:303` und `:416` passed auf Restock-Validate-27
- [x] AC-3: `PaywallView.swift:9-10` einzige Treffer im Produktcode; Links benutzen `PaywallLegalLinks.privacyURL`/`termsURL`
- [x] AC-4: `PaywallView.swift:12-17`, Preise aus `productPrice(for:)`; `testSubscriptionNoticeMentionsRequiredParts` passed (Log `:133`)
- [x] AC-5: `PaywallLegalLinksTests.swift` (Abschnittssuche, Markerzeile, Gegenproben); `de.md:47`, `de.md:53-55`; Log `:129`, `:131` passed
- [x] AC-6: `testLegalLinksReachableAtLargestTextSize` (AXXXL, `intersects`); Log `:303` passed; `ViewThatFits` mit vertikalem Rückfall
- [x] AC-7: kein `tap()` auf die Links in `PaywallUITests.swift`
- [x] AC-8: `screenshot-befund.md` (de und en „nicht sichtbar“); `store-shots/de/05-pro.png` per Bildansicht bestätigt
- [x] AC-9: `PaywallUITests` 7/0, `PurchaseUITests` 13/0; Reihenfolge `restoreButton` (`:60`), `noticeView` (`:64`), `legalText` (`:69`)
- [x] AC-10: `git diff --name-only origin/main...HEAD` ohne verbotene Datei; AppStorage vorher und nachher 0
- [x] AC-11: `paywall-unten-hell.png`, `paywall-unten-dunkel.png` per Bildansicht geprüft; `benutzen-befund.md` stimmt überein

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:31b0aa2498bb3eca11602699023bb61173b27c2585ec8759accc63f9428450c5  RestockTests/PaywallLegalLinksTests.swift
- sha256:23bfbd8378fa3e9893ec7b1f5d5e73a234ff8920960a4ddca8087b8196720fdc  RestockUITests/PaywallUITests.swift
- sha256:4577a66e1f9c33ac2bda837026be076f8f184f93727bf4acc23912b03f601c8c  RestockUITests/PurchaseUITests.swift
- sha256:b3179ec0e6616ea31fa207d4db510ad4dab76a0babe2e19a387e0bc78bf176f0  SmartCart/Views/Premium/PaywallView.swift

## Prüfbasis

- base: a7097ce68021748cc95044ad7101830771e1c541
- blob:1e3857d227c5103aaa690fa47c807e7a17bbfee3  RestockTests/PaywallLegalLinksTests.swift
- blob:cb36656b3ddce8acb70262acd3c2e9cf3c3ec6f4  RestockUITests/PaywallUITests.swift
- blob:58704045d851b3610fbf536b2bd43880b63dd1b7  RestockUITests/PurchaseUITests.swift
- blob:51269f657727a76eaa7eb77c57da82d7a689ca4e  SmartCart/Views/Premium/PaywallView.swift
