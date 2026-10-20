# Adversary Dialog — test-145-d4-kauf-wiederherstellen
Spec: docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md
Datum: 2026-10-19 17:44 (Runde 1/2), 2026-10-20 07:30 (Runde 3/4), 2026-10-20 09:50 (Runde 5), 2026-10-20 11:30 (Runde 6)

## Checkliste
- [x] **AC-1:** GIVEN Start (DEBUG) mit `-purchaseScenarioForUITests success` und gesperrtem Rezeptplan, WHEN der Nutzer die Paywall über `fork.knife` öffnet und „Jetzt freischalten…“ antippt, THEN schließt die Paywall, und ein erneutes Tippen auf `fork.knife` öffnet den Rezeptplan („Tag hinzufügen“) ohne Paywall. Ebenso nach Kauf aus der Ausgaben-Analyse (`chart.bar`) und der Einstellungszeile „Restock Pro freischalten“ (dort verschwindet die Zeile, „Pro aktiv“ erscheint). Tests: P1, U5.
- [x] **AC-2:** GIVEN Szenario `cancel`, WHEN der Nutzer „Jetzt freischalten…“ antippt, THEN bleibt die Paywall offen, und keiner der vier Hinweis-/Fehlertexte erscheint; der Rezeptplan bleibt gesperrt. Tests: P2, U6.
- [x] **AC-3:** GIVEN Szenario `pending`, WHEN der Nutzer kauft, THEN erscheint direkt unter „Käufe wiederherstellen“ der Text „Der Kauf wartet auf Zustimmung. Sobald er bestätigt ist, wird Restock Pro automatisch freigeschaltet.“ auf der Akzentfläche, die Paywall bleibt offen, `hasPremiumAccess` bleibt `false`. Tests: P3, U7.
- [x] **AC-4:** GIVEN Szenario `fail`, WHEN der Nutzer kauft, THEN erscheint „Kauf fehlgeschlagen: Testfehler Kauf“ in der Warnfarbe, die Paywall bleibt offen, `isPurchasing` ist danach `false` (der Kaufknopf ist wieder antippbar). Tests: P4, U8.
- [x] **AC-5:** GIVEN Szenario `productMissing`, WHEN der Nutzer kauft, THEN erscheint in **DEBUG wie in Release** „Der Kauf konnte nicht geladen werden. Bitte versuche es später erneut.“ in der Warnfarbe, und die Paywall schließt **nicht**. Die Verzweigung `#if DEBUG … dismiss()` in `PaywallView.purchase()` ist entfernt. Test: P5; Diff.
- [x] **AC-6:** GIVEN Szenario `restoreNone`, WHEN der Nutzer „Käufe wiederherstellen“ antippt, THEN erscheint „Kein Kauf gefunden. Hast du Restock Pro mit einer anderen Apple-ID gekauft, melde dich mit ihr an und versuche es erneut.“ auf der Akzentfläche, die Paywall bleibt offen. Tests: P6, U10.
- [x] **AC-7:** GIVEN Szenario `restoreFound`, WHEN der Nutzer „Käufe wiederherstellen“ antippt, THEN schließt die Paywall, und der Rezeptplan ist frei. Tests: P7, U9.
- [x] **AC-8:** GIVEN Szenario `restoreFail`, WHEN der Nutzer „Käufe wiederherstellen“ antippt, THEN erscheint „Wiederherstellen hat nicht geklappt. Prüfe die Internetverbindung und versuche es erneut.“ in der Warnfarbe, die Paywall bleibt offen. Tests: P8, U11.
- [x] **AC-9:** GIVEN ein sichtbarer Hinweis oder Fehler, WHEN der Nutzer „Jetzt freischalten…“ oder „Käufe wiederherstellen“ antippt, THEN ist der bisherige Hinweis weg, bevor das Ergebnis des neuen Vorgangs erscheint; es steht nie mehr als ein Hinweis zugleich da. Test: P9.
- [x] **AC-10:** GIVEN ein sichtbarer Hinweis, WHEN die Paywall betrachtet wird, THEN liegt er unmittelbar unter „Käufe wiederherstellen“ und über dem Rechtstext. Test: P10.
- [x] **AC-11:** GIVEN der Dienst mit Fake, WHEN Berechtigungen für `monthly`, `yearly` oder `lifetime` vorliegen, THEN ist `hasPremiumAccess` wahr; bei fremder ID, ohne Berechtigung (Dev-Modus aus) oder bei **widerrufener** Transaktion (`isRevoked`) ist es falsch. Tests: U1–U4.
- [x] **AC-12:** GIVEN der Dienst mit Fake und `.pending`-Kauf, WHEN die Zustimmung später über den Update-Strom eintrifft, THEN schaltet der Dienst frei, ohne dass der Nutzer etwas tut. Test: U12.
- [x] **AC-13:** GIVEN Start ohne `-purchaseScenarioForUITests` (oder im Release), WHEN die App läuft, THEN benutzt `PremiumService.shared` `StoreKitPurchaseStore`; ein unbekannter Szenarioname fällt auf StoreKit zurück. Beleg: Unit-Test `testUnknownScenarioFallsBackToStoreKit` (Auswahlfunktion `defaultStore(arguments:)` rein, ohne StoreKit-Aufruf, Typvergleich) und Diff; Verhalten der Naht gegenüber StoreKit ist **nicht** automatisiert belegt (Grenze 1).
- [x] **AC-14:** GIVEN die Paywall im Simulator (iOS 26.5), WHEN die Ursache des „…“-Chips untersucht wird, THEN liegen vor dem Fix Vorher-Screenshots (hell, dunkel) und eine benannte, belegte Ursache in `docs/artifacts/test-145-d4-kauf-wiederherstellen/` vor, und der Fix ist auf diese Ursache zugeschnitten (kein Raten, Reproduktion zuerst).
- [x] **AC-15:** GIVEN der Fix, WHEN die Paywall hell und dunkel geöffnet wird, THEN zeigt der Chip das vollständige Wort „Schließen“; der UI-Test P11 prüft die gerenderte Breite (nicht nur Label/Existenz), war vor dem Fix rot und danach grün; Nachher-Screenshots liegen im Artefaktordner. Wurde `DesignSystem.swift` geändert, sind alle anderen `ChipToolbarItem`-Nutzer geprüft und im Bericht als Seiteneffekt aufgelistet.
- [x] **AC-16:** GIVEN die bestehenden Paywall-Pfade, WHEN `PaywallUITests` (unverändert) läuft, THEN ist die Klasse grün: Sperre an fork.knife, chart.bar und Einstellungszeile, Gegenprobe `-premiumForScreenshots`, falsches Dev-Passwort. Preise, Pläne und Reihenfolge der Paywall sind unverändert.
- [x] **AC-17:** GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert und `strings` auf die ausführbare Datei läuft, THEN gelingt der Build, und weder `FakePurchaseStore` noch `purchaseScenarioForUITests` kommen vor (im Debug-Build kommen beide vor). Beleg als Textdatei im Artefaktordner.
- [x] **AC-18:** GIVEN der fertige Stand, WHEN die App im Simulator als Nutzer durchgespielt wird, THEN sind (a) ohne Szenario-Argument die Paywall öffnet sich, der Kauf mangels Produkten (`products` leer) zeigt „Der Kauf konnte nicht geladen werden …“ statt stillem Schließen, „Käufe wiederherstellen“ verhält sich ohne Konto/Produkte nachvollziehbar (Ergebnis wörtlich festgehalten, kein Absturz), und (b) jedes der acht Szenarien einmal gestartet und der jeweilige Ausgang gesehen, mit Screenshots. Der Durchlauf ist als Artefakt registriert (echter Lauf, Commit-Kennung und Zeitstempel passend, nie von Hand gesetzt).
- [x] **AC-19:** GIVEN die gesamte Unit- und UI-Suite, WHEN sie im gemeinsamen Lauf auf `Restock-Validate` läuft (ohne zusätzliche Build-Settings, nie parallel, beide Sperren gehalten), THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag. Die UI-Tests nutzen nie `-developerMode YES` und räumen nichts Dauerhaftes (es entsteht kein App-Group-Zustand); `developerMode` ist nach dem Lauf unverändert.
- [x] **AC-20:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN enthält er nur die genannten Dateien (`PremiumService.swift`, `FakePurchaseStore.swift`, `PaywallView.swift`, ggf. `DesignSystem.swift`, `PremiumServiceTests.swift`, `PurchaseUITests.swift`, `project.pbxproj`, `CLAUDE.md`, D5-Spec), bleiben `Restock.storekit`, Scheme, `Info.plist`, `@AppStorage`-Schlüssel und die Produkt-IDs unverändert, liegen die Änderungen bei ca. +570/−45 (Überschreitung von +500 wird vorher dem PO gemeldet).
- [x] **AC-21:** GIVEN der Abschluss des Durchgangs, WHEN Ticket, Berichte und `CLAUDE.md` formuliert werden, THEN stehen die offenen Grenzen 1–6 ausdrücklich darin (echter StoreKit-Kauf und Kaufdialog nicht automatisiert, #178; Produkte in App Store Connect ungeprüft, #175; Sandbox/TestFlight nur auf Hennings Wort; `sharedlists` ungenutzt; Familienfreigabe/SCA nur als Fake-`.pending`; Persistenz eines Kaufs über Neustart nicht mit dem Fake belegbar), und keine Zusage klingt nach „Kauf getestet“, ohne diese Einschränkung.


Stand Runde 6: alle 21 Punkte bewiesen. F005 (nicht reproduzierbarer Fehlschlag am „Schließen“-Chip in einem Gesamtlauf) ist durch die Vergleichsmessung (origin/main 0/300, Zweig 0/300) und einen zweiten grünen Gesamtlauf als bekannter UI-Aussetzer geschlossen; Restunsicherheit im Verdict genannt., der zweite war grün. AC-10 ist nach Fix-Runde 2 bewiesen (F004 behoben).

## Dialog

### Runde 1

**Adversary:** Behauptung geprüft: Naht vor StoreKit, Fake nur in DEBUG, vier Hinweise, Chip-Fix. Eigene Läufe statt Belegen aus Phase 6:

1. Gesamte Suite im gemeinsamen Lauf auf Restock-Validate (`xcodebuild test -scheme Restock -destination id=8F696920-4B9A-40A7-96F0-7697BE887CC7 -derivedDataPath build/dd-adv`, keine weiteren Build-Settings), Ausgabe `adversary-test-output.txt`: Unit-Bündel `RestockTests.xctest` 608 Tests, 0 Fehler (die Unit-Suite ist diesmal im gemeinsamen Lauf gestartet, kein Hänger #63); UI-Bündel `RestockUITests.xctest` 128 Tests, 0 Fehler, 3 übersprungen (`NotificationPermissionUITests.testAllow`/`testDeny` ohne Gate `RESTOCK_NOTIF_DECISION`, `ReceiptShareExtensionTests` — bekannt und gewollt); `** TEST SUCCEEDED **`, EXIT 0, 0 mal „Restarting after unexpected exit“, kein `-retry-tests-on-failure` (die 551 Treffer für „retry“ sind ausschließlich XCTests Prädikat `existsNoRetry`). Darin `PremiumServiceTests` 13/13, `PurchaseUITests` 11/11, `PaywallUITests` 5/5. `developerMode` in den Einstellungen der App auf dem Simulator: vor dem Lauf nicht gesetzt, nach dem Lauf nicht gesetzt.
2. Release-Build selbst gebaut (`-configuration Release`, `build/dd-adv-rel`, BUILD SUCCEEDED), `strings`: `FakePurchaseStore` 0, `purchaseScenarioForUITests` 0, Positivkontrolle `StoreKitPurchaseStore` 4 (Typnamen werden nicht weggestrippt, die Null ist aussagekräftig); Debug-`Restock.debug.dylib`: 2 und 1. Nur Debug setzt `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` (`project.pbxproj:1349`). Beleg `adversary-release-strings.txt`. Der ältere `release-strings-check.txt` nennt die Basis `42aa196…`, die es in der Historie nicht gibt — mein Lauf ersetzt ihn als Beleg.
3. Diff `PremiumService.swift` gegen origin/main Zeile für Zeile gelesen: `StoreKitPurchaseStore` bildet die alte Logik ab — `.success` → `payloadValue` (wirft bei unverifiziert, wie vorher) → `finish()` → `.purchased`; `.userCancelled` → `.cancelled`; `.pending` → `.pending`; `@unknown default` → `.cancelled`; `currentEntitlements` nur `.verified`, `isRevoked = revocationDate != nil`, Filter danach im Dienst; `Transaction.updates` verifiziert → `finish()` → Signal → `refreshPurchases()`; `AppStore.sync()` unverändert.

Code reference: SmartCart/Services/PremiumService.swift:58
Code reference: SmartCart/Services/PremiumService.swift:79
Code reference: SmartCart/Services/PremiumService.swift:90
Code reference: SmartCart/Services/PremiumService.swift:164
Code reference: SmartCart/Services/PremiumService.swift:201
Code reference: SmartCart/Services/PremiumService.swift:212
Code reference: SmartCart/Services/FakePurchaseStore.swift:1
Code reference: SmartCart/Services/FakePurchaseStore.swift:32
Code reference: SmartCart/Views/Premium/PaywallView.swift:44
Code reference: SmartCart/Views/Premium/PaywallView.swift:365
Code reference: SmartCart/Views/Premium/PaywallView.swift:387
Code reference: SmartCart/Extensions/DesignSystem.swift:181

4. Durchlauf als Nutzer (AC-18) und AC-1-Zusatzwege mit einem Wegwerf-UI-Test in einer Scratchpad-Kopie (Produktcode byte-gleich), Ergebnis `durchlauf.md`, `durchlauf-log.txt`, 21 Screenshots `durchlauf-*.png`. Alle acht Szenarien liefern den vorgesehenen Ausgang; chart.bar nach Kauf öffnet „Ausgaben“ ohne Paywall, Einstellungen nach Kauf: Zeile „Restock Pro freischalten“ weg, „Pro aktiv“ da. Kantenfälle: unbekannter Name `gibtsnicht` → StoreKit, Ladefehler-Text, kein Absturz; Doppeltipp auf Kaufen bei `pending` → genau ein Hinweis; bei `success` → kein Absturz, freigeschaltet.

**Beim Ansehen der Screenshots fiel auf, dass die Hinweise nicht zu sehen sind.** Gemessen (Sonde `adversary-sonde-messung.swift.txt`, Ergebnis `durchlauf-hinweis-sichtbarkeit.log`): Fenster 402 × 874 pt; Kaufknopf y 775,7–829,7, „Käufe wiederherstellen“ y 845,7–862,7 — beide ohne Scrollen antippbar. Danach liegt der Hinweis bei `pending` und `restoreNone` ganz unterhalb des Bildschirms (y ab 882,7, sichtbarer Anteil 0,00, `isHittable` false), bei `fail`, `productMissing`, `restoreFail` zu 11–23 % angeschnitten. Die Paywall scrollt nicht zum Hinweis. Die UI-Tests P3/P6/P8 sind grün, weil `waitForExistence` keine Sichtbarkeit verlangt und P10 nur die Reihenfolge der Rahmen prüft.

Finding:
  ID: F001
  Severity: HIGH
  Category: spec_violation
  Code reference: SmartCart/Views/Premium/PaywallView.swift:44
  Description: Der Hinweis wird unter „Käufe wiederherstellen“ in den ScrollView eingefügt, ohne dass die Ansicht zu ihm scrollt. Auf dem iPhone mit 874 pt Höhe sitzen Kaufknopf und Wiederherstellen-Knopf ohne Scrollen am unteren Rand; der neue Hinweis entsteht unterhalb des sichtbaren Bereichs (pending, restoreNone: 0 % sichtbar; fail, productMissing, restoreFail: 11–23 %).
  Spec requirement: AC-3, AC-6, AC-8 — der Text „erscheint“ unter „Käufe wiederherstellen“; Purpose Lücke 1–3: der Nutzer soll bei „ausstehend“, „kein Fund“ und „Fehler“ nicht ohne Rückmeldung dastehen.
  Conflict: Für den Nutzer erscheint nach dem Tipp nichts; er steht wie vor der Änderung ohne sichtbare Rückmeldung da (genau die Lücke, die der Durchgang schließen soll). Die Tests prüfen nur Existenz und Rahmenreihenfolge, nicht Sichtbarkeit.
  Remediation: Beim Setzen von `notice` per `ScrollViewReader`/`scrollTo` (oder `.scrollPosition`) zum Hinweis scrollen, bzw. die Hinweiszeile so platzieren, dass sie im sichtbaren Bereich liegt; P3/P6/P8/P10 um eine Sichtbarkeitsprüfung ergänzen (Rahmen innerhalb `app.windows.firstMatch.frame`, `isHittable`). Belege: `durchlauf-hinweis-sichtbarkeit.log`, `durchlauf-messung-*.png`, `durchlauf-pending.png`.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: SmartCart/Services/PremiumService.swift:203
  Description: `restorePurchases()` meldet jeden Fehler von `AppStore.sync()` als `.failed`. Im Durchlauf (a) ohne Szenario zeigt iOS den Dialog „Bei Apple Account anmelden“; nach „Abbrechen“ steht „Wiederherstellen hat nicht geklappt. Prüfe die Internetverbindung und versuche es erneut.“ (`durchlauf-ohne-szenario-wiederherstellen-8s.png`). Apple wirft hier laut Dokumentation `StoreKitError.userCancelled`.
  Spec requirement: AC-8 und Implementation Details („`sync()` wirft → `.failed`“) gegen den Grundsatz derselben Spec „Abbruch → keine Meldung“ und AC-18(a) „verhält sich nachvollziehbar“.
  Conflict: Die Spec unterscheidet Abbruch und Fehler beim Kauf, beim Wiederherstellen nicht. Wörtlich erfüllt, aber der Nutzer bekommt nach eigenem Abbruch einen falschen Grund (Internet) genannt. Vorher (origin/main) passierte in diesem Fall sichtbar nichts.
  Remediation: PO-Entscheidung: `StoreKitError.userCancelled` aus `sync()` wie beim Kauf still behandeln (eigener Ausgang oder `.none` ohne Hinweis) und im Fake ein Szenario dafür ergänzen; oder den Text bewusst so belassen und in der Spec festhalten.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/PremiumService.swift:212
  Description: Der Widerruf ist nur über `refreshPurchases()` mit `isRevoked: true` geprüft (U3). Dass ein Widerruf, der über den Update-Strom eintrifft, die Freischaltung wieder entzieht, prüft kein Test (U12 prüft nur Freischalten). Der Code tut es (jedes Signal ruft `refreshPurchases()`, das widerrufene Einträge verwirft); der Fake kann nie ein Update senden.
  Spec requirement: AC-11/AC-12 — nicht verletzt, nur Testlücke.
  Conflict: keiner im Verhalten; Absicherung fehlt.
  Remediation: U12-Variante: Berechtigung auf `isRevoked: true` setzen, `emitUpdate()`, Zugang muss entfallen.

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/PremiumService.swift:190
  Evidence: `.purchased` → `refreshPurchases()`; P1 grün; eigener Durchlauf: fork.knife, chart.bar („Ausgaben“) und Einstellungen („Pro aktiv“, Zeile weg) nach Kauf frei (`durchlauf-ac1-*.png`).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Views/Premium/PaywallView.swift:365
  Evidence: `.cancelled` → `break`, kein Hinweis; P2, U6 grün; `durchlauf-cancel.png`.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Services/FakePurchaseStore.swift:13
  Evidence: `errorDescription` „Testfehler Kauf“, PaywallView setzt „Kauf fehlgeschlagen: …“ in `.red`; `isPurchasing` wird per `defer` zurückgesetzt; P4, U8 grün. Der Text liegt allerdings zu 77 % unter dem Bildschirmrand (F001 gilt auch hier).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Views/Premium/PaywallView.swift:365
  Evidence: Zweig `#if DEBUG dismiss()` entfernt (Diff), fehlendes Angebot → Fehlertext in beiden Builds; P5 grün; auch mit echtem StoreKit im Durchlauf (a) gesehen. Sichtbarkeit: siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Services/FakePurchaseStore.swift:61
  Evidence: `restoreFound` legt lifetime ab, `.found` → `dismiss()`; P7, U9 grün; `durchlauf-restoreFound-danach.png`.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Premium/PaywallView.swift:387
  Evidence: `notice = nil` als erste Anweisung in `purchase()` und `restore()`, ein einziger `@State` → nie zwei Hinweise; P9 grün. Gleichzeitiges Kaufen und Wiederherstellen ist möglich (Knöpfe sperren sich nur selbst), überschreibt aber nur denselben Zustand.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Views/Premium/PaywallView.swift:44
  Evidence: Hinweis zwischen `restoreButton` und `legalText` im VStack; P10 grün; Messung: Hinweis-Oberkante 882,7 unter Knopf-Unterkante 862,7. Lage richtig, Sichtbarkeit nicht (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/Services/PremiumService.swift:212
  Evidence: Filter `!isRevoked` und `knownIDs.contains`; U1–U4 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Services/PremiumService.swift:175
  Evidence: `startListening()` holt den Strom synchron, jedes Signal → `refreshPurchases()`; U12 grün (Lücke Widerruf: F003).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Services/PremiumService.swift:164
  Evidence: Auswahl nur unter `#if DEBUG`, unbekannter oder fehlender Name → `StoreKitPurchaseStore`; `testUnknownScenarioFallsBackToStoreKit` grün; Durchlauf `gibtsnicht` → echter StoreKit-Weg.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Extensions/DesignSystem.swift:181
  Evidence: `chip-ursache.md` mit Recherche, drei Kandidaten je mit Experiment, Vorschlags-Protokoll (`chip-sonde-vorschlaege.log`: linkes Item Vorschlag w=0 → 40 pt), Vorher-Screenshots hell/dunkel; der Fix setzt genau dort an.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/Extensions/DesignSystem.swift:181
  Evidence: P11 prüft Rahmenbreite ≥ 80 pt, im RED-Lauf 40 pt (`red-chip-hell-40pt.png`), jetzt grün; `chip-sonde-messwerte.log`: rechte Chips „Alle hinzufügen“ 139,3 pt und „Fertig“ 70,3 pt vorher gleich nachher, linke 40 → 99 pt. In meinen Durchlauf-Screenshots ist „Schließen“ voll lesbar. Grenze: nur iOS 26.5; weitere linke Chips (Liste in `chip-ursache.md`) nicht einzeln per Screenshot geprüft, die app-weite Wirkung hat der PO freigegeben.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: SmartCart/Views/Premium/PaywallView.swift:93
  Evidence: `PaywallUITests.swift` nicht im Diff gegen origin/main; 5/5 grün im gemeinsamen Lauf; Preise über `offer(for:)` statt `product(for:)`, Ersatzpreise unverändert (Durchlauf (a): 8,99 €/Jahr).
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Services/FakePurchaseStore.swift:1
  Evidence: ganze Datei in `#if DEBUG`; eigener Release-Build und `strings` mit Positivkontrolle (`adversary-release-strings.txt`).
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: SmartCart/Services/FakePurchaseStore.swift:25
  Evidence: Käufe nur im Prozess (`ownedIDs`), kein `UserDefaults`; Suite 608 + 128 Tests, 0 Fehler, kein Abbruch, kein Retry-Flag; `developerMode` vor und nach dem Lauf nicht gesetzt.
  Status: CONFIRMED

Confirmation:
  AC: AC-20
  Code reference: SmartCart/Services/PremiumService.swift:139
  Evidence: Diff gegen origin/main enthält nur die genannten Code- und Testdateien plus Doku und Artefakte; `Restock.storekit`, Scheme, `Info.plist` unverändert, keine neuen `@AppStorage`-Schlüssel, Produkt-IDs gleich; +814/−72 Zeilen in Code und Tests, vom PO am 2026-10-19 freigegeben. Die D5-Spec von #98 bleibt laut Orchestrator bewusst unverändert (edit_gate, freigegebener abgeschlossener Workflow); AC-20 nennt sie nur als zulässige Datei. Hinweis: Die DoD-Zeile „D5-Hinweis vorhanden“ der D4-Spec ist damit nicht wörtlich erfüllt; der Hinweis steht im D5-Absatz von CLAUDE.md.
  Status: CONFIRMED

Confirmation:
  AC: AC-21
  Code reference: SmartCart/Services/PremiumService.swift:4
  Evidence: Neuer CLAUDE.md-Absatz zu #145 D4 nennt die Grenzen 1–6 nummeriert (echter Kauf #178, App Store Connect #175, Sandbox/TestFlight nur auf Hennings Wort, `sharedlists`, Familienfreigabe/SCA nur Fake-`.pending`, Persistenz über Neustart) und „kein echter Kauf“; der D5-Absatz ist entsprechend eingeschränkt; Spec-Changelog ergänzt. Ticket und Abschlussbericht konnte ich nicht prüfen (noch nicht geschrieben). F001 und F002 müssen in die Zusagen, solange offen.
  Status: CONFIRMED

**Implementierer:** (vom Orchestrator weiterzugeben) — Stellungnahme zu F001 und F002 offen.

### Runde 2

**Adversary:** Gegenprobe, ob F001 ein Messartefakt ist: (a) Getippt wurde ohne vorheriges Wischen; die Sonde protokolliert die Knopf-Rahmen vor dem Tipp (Kaufknopf y 775,7, Wiederherstellen y 845,7) — so tippt ein Nutzer, die Paywall öffnet oben. (b) Nach dem Tipp 1 s gewartet, dann gemessen: Hinweis-Rahmen ab 882,7 bei Fensterhöhe 874; `isHittable` false. (c) Screenshot `durchlauf-pending.png`: nur ein wenige Pixel hoher Streifen der Akzentfläche am unteren Rand, kein Text. (d) Auf höheren Geräten (Pro Max, 956 pt) wäre der Hinweis vermutlich sichtbar, auf 874-pt-iPhones und kleineren nicht oder schlechter; iPhone ist laut Release-1.0-Umfang die einzige Plattform. Die Wirkung ist real und nicht an den Testläufer gebunden. F001 bleibt HIGH.

Gegenprobe F002: Der Abbruch-Fall ist kein Kunstprodukt des Simulators; `AppStore.sync()` fordert laut Apple stets eine Anmeldung bzw. Bestätigung an und wirft bei Abbruch `StoreKitError.userCancelled`. Die Spec regelt den Fall nicht ausdrücklich; deshalb MEDIUM und Entscheidung durch den PO, kein Spec-Verstoß im Wortlaut.

Weitere Proben ohne Befund: Doppeltipp während `isPurchasing` (Knopf `.disabled(premium.isPurchasing)`), Hinweis nach erfolgreichem Kauf bleibt nicht hängen (Paywall schließt, neuer `@State` beim nächsten Öffnen), `restorePurchases` mit aktivem Dev-Modus → `.none` (U10; `hasPurchasedAccess` ohne `developerMode`), `startListening()` beendet einen vorherigen Listener, `deinit` beendet den Task, `StoreKitPurchaseStore.updates` beendet seinen Task über `onTermination`. Aufrufer der geänderten API (`grep`): nur `PaywallView`; `HomeView`/`SettingsView` lesen weiter nur `hasPremiumAccess`.

Code reference: SmartCart/Views/Premium/PaywallView.swift:303
Code reference: SmartCart/Services/PremiumService.swift:139

**Implementierer:** (vom Orchestrator weiterzugeben) — offen.

### Runde 3

**Adversary:** Prüfung nach Fix-Runde 1 (Patch `phase6-fix1.patch`), Anforderungen in der verbindlichen Fassung: ACs eingefroren, PO-Entscheidungen F001 (Hinweis rollt ins Bild, vollständig sichtbar und antippbar), F002 (neutraler Hinweis bei `restoreCancel`), F003 (Widerruf über Update-Strom) in Implementation Details, Test Plan (U13, U14, P12) und Changelog 2026-10-20. Alle Läufe selbst gefahren, Belege der Fix-Runde nur gegengelesen.

1. **F001 (Sichtbarkeit).** Code: `PaywallView` liegt jetzt in einem `ScrollViewReader`, der Hinweis trägt `.id("paywallNotice")`, `.onChange(of: notice)` rollt bei einem neuen Wert animiert (`.smooth`) mit `anchor: .bottom` hin.

Code reference: SmartCart/Views/Premium/PaywallView.swift:58

   Messung mit der Sonde aus Runde 1 (erweitert um `restoreCancel` und Wiederholungs-Kanten), Protokoll `durchlauf-hinweis-sichtbarkeit-runde3.log`. Restock-Validate (402 × 874 pt), Tipp ohne vorheriges Wischen wie in Runde 1 (Kaufknopf y 775,7, Wiederherstellen y 845,7): alle sechs Hinweise **vollständig im Fenster und antippbar, nach 0,1 s** — pending y 794,3–828,0, fail 825,7–840,0, productMissing 809,7–840,0, restoreNone 776,3–828,0, restoreFail 809,7–840,0, restoreCancel 776,3–828,0 (Runde 1: 0–23 % sichtbar). Der Knopf ist danach um 88–106 pt nach oben gewandert, die Ansicht hat also gerollt. Kleinstes realistisches iPhone als Wegwerf-Simulator `Restock-Adv3-SE` (iPhone SE 3. Generation, iOS 26.5, 375 × 667 pt, danach gelöscht): alle sechs ebenfalls vollständig sichtbar (z. B. pending y 603,0–655,0, fail 652,5–667,0). Die UI-Tests prüfen das jetzt selbst: `assertNotice` verlangt `isHittable` **und** Rahmen im Fenster (`PurchaseUITests.swift:93`); im RED-Lauf der Fix-Runde fiel P5 mit genau dem Befund aus Runde 1 (y 870,7, `test-red-fix1-output.txt`), im GREEN-Lauf 17 UI-Tests grün (`test-green-output.txt`, 12 `PurchaseUITests` + 5 `PaywallUITests`; Unit-Teil 15 Tests in einem eigenen Lauf).

   **Neue Kante, F004:** Derselbe Hinweis ein zweites Mal. `productMissing` auf 874 pt: erster Tipp → voll sichtbar. Nutzer rollt hoch (z. B. um einen anderen Plan zu wählen), der Kaufknopf bleibt bei y 775,7 antippbar, der Hinweis steht bei y 870,7 (11 %). Zweiter Tipp → **kein Hinrollen**, Hinweis bleibt angeschnitten (`durchlauf-r3-wiederholung-productMissing.png`). Gegenprobe `restoreCancel` im gleichen Ablauf rollt korrekt (y 776,3). Ursache im Code: `purchase()` setzt `notice = nil` und im `guard` sofort `notice = .error(…)` ohne `await` dazwischen; SwiftUI sieht denselben Wert, `.onChange` feuert nicht. Der Weg ist nicht konstruiert: Er ist genau der Zustand, den echtes StoreKit ohne geladene Produkte liefert (Simulator, Produkte in App Store Connect nicht live #175, kein Netz beim Laden).

Code reference: SmartCart/Views/Premium/PaywallView.swift:375

2. **F002 (Abbruch neutral).** Code-Pfad: `StoreKitPurchaseStore.sync()` fängt `StoreKitError.userCancelled` und wirft `PurchaseStoreError.cancelled`; `restorePurchases()` gibt dafür `.cancelled` zurück (andere Fehler weiter `.failed`); die Paywall setzt `.info(…)` mit dem PO-Text — `.info` rendert auf `Color.accentContainer` mit `Color.ink`, nicht in `.red`. Der Fake-Fall `restoreCancel` wirft denselben Fehler.

Code reference: SmartCart/Services/PremiumService.swift:86
Code reference: SmartCart/Services/PremiumService.swift:217
Code reference: SmartCart/Views/Premium/PaywallView.swift:408
Code reference: SmartCart/Views/Premium/PaywallView.swift:362
Code reference: SmartCart/Services/FakePurchaseStore.swift:65

   Beleg Szenario: `durchlauf-restoreCancel.png` — beige-graue Akzentfläche, dunkler Text, keine rote Zeile, Paywall offen. **Echtes StoreKit ohne Szenario-Argument:** „Käufe wiederherstellen“ → Springboard-Alert „Bei Apple Account anmelden“ → „Abbrechen“ getippt → wörtlich „Wiederherstellen wurde nicht abgeschlossen. Wenn du nicht selbst abgebrochen hast, prüfe die Internetverbindung und versuche es erneut.“, vollständig sichtbar, keine Fehlermeldung, kein Absturz (`durchlauf-r3-ohne-szenario-wiederherstellen-abbruch.png`; Runde 1 zeigte hier die Fehlermeldung). Damit ist auch belegt, dass Apple im Simulator den Abbruch tatsächlich als `StoreKitError.userCancelled` meldet — die Abbildung greift. Unit U13 `testRestoreCancelledReturnsCancelledNotFailed` war im RED-Lauf rot (`failed` statt `cancelled`), ist jetzt grün. Grenze: Ob Apple fehlendes Netz auf dem Gerät ebenso meldet, ist nur über die Foren belegt, nicht nachgestellt.

3. **F003 (Widerruf über Update-Strom).** U14 `testUpdateStreamRevocationRemovesAccess`: Zugang über lifetime, dann `isRevoked: true` und `emitUpdate()`, Frist 20 s → Zugang weg, `purchasedProductIDs` leer. Der Test ist eine reine Absicherung (der Code verhielt sich schon richtig, daher im RED-Lauf nicht rot); er läuft durch denselben Strom wie U12 und prüft den Filter in `refreshPurchases()`.

Code reference: SmartCart/Services/PremiumService.swift:228

4. **Nicht geänderte Teile gegengelesen.** `DesignSystem.swift` ist seit Runde 1 unverändert (Hash b8827cc3… wie im alten Stempel), der Chip-Fix `.fixedSize(horizontal: true, vertical: false)` bleibt; in allen Runde-3-Screenshots, auch auf dem SE, steht „Schließen“ voll lesbar. `FakePurchaseStore.swift` ist weiter ganz in `#if DEBUG`, neu nur der Fall `restoreCancel`.

Code reference: SmartCart/Extensions/DesignSystem.swift:181
Code reference: SmartCart/Services/FakePurchaseStore.swift:1

5. **AC-19 Suite**, AC-17 Release, AC-18 Durchlauf: siehe Runde 4.

**Implementierer:** (vom Orchestrator weiterzugeben) — Stellungnahme zu F004 offen.

### Runde 4

**Adversary:** Pflichtläufe auf dem Stand nach Fix-Runde 1 und Gegenprobe zu F004.

1. **AC-19, gesamte Suite im gemeinsamen Lauf** auf Restock-Validate (`xcodebuild test -scheme Restock -project Restock.xcodeproj -destination id=8F696920-4B9A-40A7-96F0-7697BE887CC7 -derivedDataPath build/dd-adv`, keine weiteren Build-Settings, 06:54–07:27 CEST, nichts parallel), Ausgabe `adversary-test-output.txt`: Unit-Bündel 610 Tests, 0 Fehler (kein Hänger #63, die Unit-Suite lief im gemeinsamen Lauf); UI-Bündel 129 ausgeführt, 126 bestanden, 0 fehlgeschlagen, 3 übersprungen (`NotificationPermissionUITests.testAllow`/`testDeny` ohne Gate, `ReceiptShareExtensionTests` — bekannt und gewollt); `** TEST SUCCEEDED **`, EXIT 0; 0 × „Restarting after unexpected exit“; 0 × `retry-tests-on-failure`. Darin `PremiumServiceTests` 15/15 (inkl. U13, U14), `PurchaseUITests` 12/12 (inkl. P12), `PaywallUITests` 5/5 (Datei nicht im Diff). `developerMode` per `simctl spawn … defaults read com.johannesemmrich.Restock developerMode`: vor dem Lauf „does not exist“, nach dem Lauf „does not exist“.

2. **AC-17, Release** neu gebaut (`-configuration Release`, `build/dd-adv-rel`, BUILD SUCCEEDED, Binärdatei 07:28:35): `FakePurchaseStore` 0, `purchaseScenarioForUITests` 0, `restoreCancel` 0; Positivkontrollen `StoreKitPurchaseStore` 4 und der neue Hinweistext „Wiederherstellen wurde nicht abgeschlossen“ 2 (der Release-Weg zeigt ihn also); Debug-`Restock.debug.dylib`: 2 / 1 / 2. Beleg `adversary-release-strings.txt`.

Code reference: SmartCart/Services/FakePurchaseStore.swift:83

3. **AC-18, Durchlauf** mit `restoreCancel` ergänzt, `durchlauf.md` neu (Runde-3-Abschnitt mit Commit-Kennung 18954a4… plus uncommittete Phase-6-Änderungen, Zeitstempel, Dateihashes; der alte Abschnitt als überholt markiert). (a) echtes StoreKit: Kauf → Ladefehler voll sichtbar; Wiederherstellen → Anmeldedialog → „Abbrechen“ → neutraler Hinweis wörtlich festgehalten, kein Absturz. (b) alle neun Szenarien mit Ausgang und Screenshot, `success`/`restoreFound` schließen und schalten den Rezeptplan frei, `cancel` ohne Hinweis.

4. **Gegenprobe F004, ob Messartefakt.** (a) Der zweite Tipp traf den Kaufknopf an seiner unveränderten Stelle (y 775,7, ohne Wischen antippbar) — so tippt ein Nutzer nach dem Hochrollen. (b) Nach dem Tipp 2 s gewartet, Hinweis unverändert bei y 870,7. (c) Der asynchrone Weg (`restoreCancel`) rollt im identischen Ablauf korrekt — der Unterschied liegt also im Code, nicht im Testläufer. (d) Auf dem SE trat die Kante in diesem Ablauf nicht auf, weil dort der Kaufknopf nach dem Hochrollen selbst außer Sicht war und das Hinwischen den Hinweis mitbrachte; auf 874-pt-Geräten (und größeren, bei denen Knopf und Hinweis-Unterkante nahe am Rand liegen) tritt sie auf. Kein Test deckt „zweimal derselbe synchrone Hinweis“ ab (P5 tippt nur einmal, P9 wechselt die Hinweisart). F004 bleibt MEDIUM.

5. **Regression/Aufrufer.** `restorePurchases()` hat einen neuen Fall `.cancelled`; einziger Aufrufer ist `PaywallView.restore()`, der `switch` ist erschöpfend (Compiler). `PurchaseStoreError` wird nur in `StoreKitPurchaseStore.sync()`, im Fake und im Dienst benutzt. `HomeView`/`SettingsView` lesen weiter nur `hasPremiumAccess`. Umfang App-Code gegen origin/main: `SmartCart/` +280/−91 plus neue `FakePurchaseStore.swift` 83 Zeilen ≈ +363 (PO-Rahmen „~+350“, `loc_limit_override` 360 — knapp darüber, Zählweise des Gates nicht von mir geprüft; Hinweis, kein Befund).

Code reference: SmartCart/Services/PremiumService.swift:214
Code reference: SmartCart/Views/Premium/PaywallView.swift:396

Finding:
  ID: F004
  Severity: MEDIUM
  Category: edge_case
  Code reference: SmartCart/Views/Premium/PaywallView.swift:375
  Description: `purchase()` setzt `notice = nil` und im `guard premium.offer(for:) != nil` ohne `await` dazwischen sofort `notice = .error("Der Kauf konnte nicht geladen werden …")`. Steht derselbe Fehler schon da, sieht SwiftUI keinen Wertwechsel, `.onChange(of: notice)` (Zeile 58) feuert nicht, die Paywall rollt nicht. Gemessen auf 874 pt: nach Hochrollen und zweitem Tipp bleibt der Fehler bei y 870,7, 11 % sichtbar (`durchlauf-hinweis-sichtbarkeit-runde3.log`, `durchlauf-r3-wiederholung-productMissing.png`). Asynchrone Ausgänge (Kauf, Wiederherstellen) sind nicht betroffen (Gegenprobe `restoreCancel`).
  Spec requirement: Implementation Details „Erscheint ein Hinweis, rollt die Paywall animiert so weit, dass er vollständig sichtbar ist (F001)“ — laut Changelog 2026-10-20 Ergänzung zu AC-8/AC-10; AC-9 „der bisherige Hinweis ist weg, bevor das Ergebnis des neuen Vorgangs erscheint“.
  Conflict: Beim wiederholten Kaufversuch ohne geladene Produkte — genau der Zustand mit echtem StoreKit im Simulator, ohne Netz oder solange die Produkte in App Store Connect nicht live sind (#175) — sieht der Nutzer nach dem Tipp keine Veränderung und nur einen angeschnittenen Fehlertext; der Hinweis verschwindet auch nicht sichtbar und erscheint nicht neu.
  Remediation: Das Hinrollen an ein Ereignis statt an den Wert binden (z. B. Zähler/`UUID` je gesetztem Hinweis, `onChange` darauf) oder im `guard`-Zweig vor dem Setzen kurz abgeben (`await Task.yield()`), sodass `nil` gerendert wird; UI-Test: `productMissing`, kaufen, hochrollen bis der Hinweis außer Sicht ist, Kaufknopf erneut tippen, `assertNotice` muss wieder vollständige Sichtbarkeit melden.

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Views/Premium/PaywallView.swift:389
  Evidence: `.pending` → `.info(…)` auf `Color.accentContainer`; Hinweis nach dem Tipp vollständig sichtbar auf 874 pt (y 794,3–828,0) und 667 pt (y 603,0–655,0); P3 mit Sichtbarkeitsprüfung grün im gemeinsamen Lauf; U7 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Views/Premium/PaywallView.swift:405
  Evidence: `.none` → Info-Text wörtlich; vollständig sichtbar (874 pt y 776,3–828,0; SE y 603,0–655,0); P6, U10 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Views/Premium/PaywallView.swift:407
  Evidence: `.failed` → `.error(…)` in `.red`; vollständig sichtbar (874 pt y 809,7–840,0; SE y 636,5–667,0); P8, U11 grün. PO-Ergänzung F002: `.cancelled` getrennt, neutral, P12 und U13 grün, echter Abbruch im Simulator zeigt den neutralen Text.
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: SmartCart/Services/FakePurchaseStore.swift:10
  Evidence: Durchlauf Runde 3 (`durchlauf.md`, `durchlauf-r3-*.png`): (a) echtes StoreKit, Ladefehler statt Schließen, Wiederherstellen-Abbruch wörtlich mit neutralem Hinweis, kein Absturz; (b) alle acht Szenarien der Spec plus `restoreCancel` mit Ausgang und Screenshot; Commit-Kennung und Zeitstempel aus dem echten Lauf. F004 ist eine Kante außerhalb der in AC-18 verlangten Einzelabläufe.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Services/FakePurchaseStore.swift:1
  Evidence: eigener Release-Build heute 07:28, `strings`: Fake 0, Argument 0, `restoreCancel` 0, Positivkontrollen vorhanden (`adversary-release-strings.txt`).
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: SmartCart/Services/FakePurchaseStore.swift:25
  Evidence: 610 Unit + 129 UI (126 bestanden, 3 bekannte Übersprünge), 0 Fehler, kein Abbruch, kein Retry-Flag, `developerMode` vorher und nachher nicht gesetzt.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Services/PremiumService.swift:187
  Evidence: `startListening()` → jedes Signal `refreshPurchases()`; U12 (Freischalten) und neu U14 (Widerruf, F003 geschlossen) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/Services/PremiumService.swift:231
  Evidence: Filter `!isRevoked && knownIDs.contains`; U1–U4 grün, U14 deckt den Widerruf über den Strom ab.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/Extensions/DesignSystem.swift:181
  Evidence: unverändert seit Runde 1 (Hash b8827cc3…); P11 grün im gemeinsamen Lauf; „Schließen“ in allen Runde-3-Screenshots voll lesbar, auch auf dem SE.
  Status: CONFIRMED

Weiterhin gültig aus Runde 1 (Code dieser Stellen seit Runde 1 nicht geändert bzw. Tests im heutigen Lauf grün): AC-1 (P1 grün, Durchlauf `success` heute), AC-2 (P2 prüft jetzt alle sechs Texte, `cancel` heute ohne Hinweis), AC-4, AC-5 (P5 grün; erster Tipp voll sichtbar, Wiederholung siehe F004), AC-7, AC-9, AC-13, AC-14, AC-16 (5/5 heute), AC-20, AC-21 (CLAUDE.md-Absatz nennt `restoreCancel` und die Grenzen; Ticket/Abschlussbericht noch nicht geschrieben — F004 muss dort rein, solange offen).

**Implementierer:** (vom Orchestrator weiterzugeben) — Stellungnahme zu F004 offen.

### Runde 5

**Adversary:** Prüfung nach Fix-Runde 2 (F004). Alle Läufe selbst gefahren, nichts parallel, Sperren beim Orchestrator. Stand: 18954a4… plus uncommittete Phase-6-Änderungen; gegenüber Runde 3/4 hat sich nur `PaywallView.swift` geändert (SHA-256 fab90cc7…, vorher 86c1d734…); `PremiumService.swift` a4bcc4c0…, `FakePurchaseStore.swift` c946312e…, `DesignSystem.swift` b8827cc3… unverändert.

1. **Diff `PaywallView.swift` gegen origin/main, Zeile für Zeile** (die Änderung lief per Python über Bash): Nur Erwartetes. Neu `noticeEvent` (Zähler) und `show(_:)` (setzt `notice` und zählt hoch); `.onChange(of: noticeEvent)` rollt mit `.smooth` und `anchor: .bottom` zur Hinweis-ID; die Einrückung der Toolbar-Klammer ist korrigiert. Alle sieben Hinweis-Setzstellen laufen über `show(_:)`; `notice = nil` steht nur noch als erste Anweisung in `purchase()` und `restore()`. Kein Streurest, keine doppelte Zuweisung; `offer(for:)` statt `product(for:)` wie in Runde 1; Preise, Pläne, Rechtstext, Reihenfolge unverändert. Synchron ist nur ein Weg: der `guard premium.offer(for:) != nil` in `purchase()` (`notice = nil` und `show(.error(…))` ohne `await` dazwischen). Alle übrigen Ausgänge laufen über die Actors `FakePurchaseStore` bzw. `StoreKitPurchaseStore` und unterbrechen echt; da das Hinrollen jetzt am Zähler hängt, ist die Frage synchron/asynchron für das Rollen gegenstandslos.

Code reference: SmartCart/Views/Premium/PaywallView.swift:22
Code reference: SmartCart/Views/Premium/PaywallView.swift:60
Code reference: SmartCart/Views/Premium/PaywallView.swift:373
Code reference: SmartCart/Views/Premium/PaywallView.swift:385
Code reference: SmartCart/Services/FakePurchaseStore.swift:8
Code reference: SmartCart/Services/PremiumService.swift:187

2. **F004 nachgestellt, Sonde wie Runde 3/4** (Wegwerf-Klasse in einer Scratchpad-Kopie, `SmartCart/` byte-gleich, Protokoll `durchlauf-hinweis-sichtbarkeit-runde5.log`, Screenshots `durchlauf-r5-…png`).
   - Restock-Validate (402 × 874 pt), genau der Runde-3-Ablauf W1 (`productMissing`, kaufen, zweimal nach unten wischen, Hinweis bei y 870,7 zu 11 % sichtbar, Kaufknopf bei y 775,7 antippbar, erneut tippen): Hinweis danach **vollständig sichtbar**, y 809,7–840,0 (Runde 3: blieb bei 870,7). Ebenso mit einem langsamen Zug um 90 pt und um 200 pt (R1, R2) und **ohne Szenario-Argument mit echtem StoreKit** (R7, derselbe synchrone `guard`-Weg): jeweils vorher 11 %, nachher voll, nach 0,1–0,2 s.
   - Weitere Wiederholungen mit gleichem Text: `fail` (R3, vorher 23 %), `pending` (R4, vorher 0 %), `restoreNone` (R5 34 %, W2 0 %), `restoreFail` (R6 11 %), `restoreCancel` (W3 0 %): jedes Mal danach vollständig sichtbar.
   - Wegwerf-Simulator `Restock-Adv5-SE` (iPhone SE 3. Generation, iOS 26.5, 375 × 667 pt, danach gelöscht, Abschlussprüfung 0 übrig): Hier tritt die Kante in Reinform auf — nach dem 90-pt-Zug liegt der Hinweis ganz unter dem Rand (0 %, y 716,5), der Kaufknopf bleibt ohne Wischen antippbar (y 621,5). Zweiter Tipp: Hinweis voll sichtbar, y 636,5–667,0 (`durchlauf-r5-h667-r5-productMissing-drag90.png`, davor `…-zurueck.png`). Gleiches Bild für `fail`, `pending`, `restoreNone`, `restoreFail`, echtes StoreKit.
   - **P13 auf dem SE**: zweimal grün; die Vorbedingung „nach dem 90-pt-Zug nicht mehr ganz sichtbar, Sheet offen“ hält dort (gemessen 0 % sichtbar), der Kaufknopf bleibt antippbar. Kein Testbefund. RED-Beleg der Fix-Runde gegengelesen: P13 fiel vor dem Fix an Zeile 264 (zweites `assertNotice`), also an der richtigen Stelle.
   - Beobachtung ohne Befund: Auf dem SE beginnt der Zug von P13 (Bildschirmmitte, 0,1 s Druck) auf der Karte „Monatlich“ und wählt diesen Plan aus (`durchlauf-r5-h667-r5-productMissing-drag90-zurueck.png`). Für `productMissing` ohne Wirkung auf das Ergebnis; die Plankarten sind seit origin/main unverändert.

Code reference: SmartCart/Views/Premium/PaywallView.swift:200

3. **Regression der übrigen Hinweise** (erster Tipp, M1–M6, beide Geräte): alle sechs vollständig im Fenster und antippbar nach 0,1–0,3 s, Werte identisch zu Runde 3 (874 pt: pending 794,3–828,0, fail 825,7–840,0, productMissing 809,7–840,0, restoreNone 776,3–828,0, restoreFail 809,7–840,0, restoreCancel 776,3–828,0; 667 pt: 603,0–655,0 bzw. 636,5–667,0 bzw. 652,5–667,0). Ausgänge `success`/`restoreFound` schließen und schalten frei, `cancel` ohne Hinweis; echtes StoreKit: Ladefehler, Anmeldedialog, „Abbrechen“, neutraler Hinweis wörtlich, kein Absturz. Auf dem SE schlug im ersten Durchgang M3 einmal fehl, bevor die Paywall offen war: der Tipp auf `fork.knife` (Startseite, unverändert) öffnete sie nicht; im zweiten Durchgang grün. Kein Bezug zum Hinweis.

4. **AC-17 Release** neu gebaut (BUILD SUCCEEDED, Binärdatei 08:53:48): `FakePurchaseStore` 0, `purchaseScenarioForUITests` 0, `restoreCancel` 0; Positivkontrollen `StoreKitPurchaseStore` 4, Hinweistext 2; Debug 2/1/2; kein `debug.dylib` im Release-Bündel. Beleg `adversary-release-strings.txt`.

Code reference: SmartCart/Services/FakePurchaseStore.swift:1

5. **AC-19, gesamte Suite im gemeinsamen Lauf**, zweimal (Restock-Validate, `-derivedDataPath build/dd-adv`, keine weiteren Build-Settings):
   - **Lauf 1** (08:15–08:51, `adversary-test-output-runde5-lauf1.txt`): Unit 610/610 grün; UI 130 ausgeführt, 3 übersprungen (bekannte Gates), **1 fehlgeschlagen**: `PaywallUITests.testExpensesAnalysisLockedOpensPaywall` — der Tipp auf „Schließen“ schloss die Paywall nicht (20-s-Frist). Die Aufnahme zeigt den Chip gedrückt (Deckkraft 0,6) und wieder losgelassen, die Paywall bleibt offen (`adversary-r5-schliessen-tipp-ohne-wirkung.png`); Tippstelle x 69,5, y 100 = Mitte des 99-pt-Chips. Ergebnis TEST FAILED, EXIT 65.
   - **Lauf 2** (09:01–09:45, `adversary-test-output.txt`): Unit 610/610; UI 130 ausgeführt, 127 bestanden, 0 fehlgeschlagen, 3 übersprungen; `PremiumServiceTests` 15/15, `PurchaseUITests` 13/13 (inkl. P13), `PaywallUITests` 5/5; Ergebnis TEST SUCCEEDED, EXIT 0.
   - Beide Läufe: 0 × „Restarting after unexpected exit“, 0 × `retry-tests-on-failure`; `developerMode` vor Lauf 1, nach Lauf 1 und nach Lauf 2 „does not exist“.
   - Gegenproben zum Fehlschlag: die drei Schließen-Tests je 10× einzeln (`-test-iterations 10`): 30/30 grün (`adversary-r5-schliessen-10x.txt`). Trefferfläche des verbreiterten Chips je 5× an Mitte (x 69,5), rechtem Rand (x 111,1, weit außerhalb eines 40-pt-Platzes) und linkem Rand (x 27,9): 15/15 geschlossen (`adversary-r5-schliessen-trefferflaeche.txt`). Damit gibt es keinen strukturellen Grund (Trefferfläche), aber auch keine Erklärung für den einen Fehlschlag. Bilanz der Schließen-Tipps dieser Runde und der Runden 1/4: 1 von rund 57 ohne Wirkung; dasselbe Muster (Tipp angekommen, Aktion bleibt aus) zeigte in dieser Runde auch das unveränderte `fork.knife` einmal.

Code reference: SmartCart/Extensions/DesignSystem.swift:181
Code reference: SmartCart/Services/PremiumService.swift:214

Finding:
  ID: F005
  Severity: MEDIUM
  Category: regression
  Code reference: SmartCart/Extensions/DesignSystem.swift:181
  Description: Im ersten gemeinsamen Suite-Lauf dieser Runde schloss ein Tipp auf den „Schließen“-Chip die Paywall nicht (`PaywallUITests.testExpensesAnalysisLockedOpensPaywall`, Zeile 55 des Tests, 20-s-Frist). Der Chip wurde sichtbar gedrückt und losgelassen, `dismiss()` blieb ohne Wirkung. Der Chip ist seit dieser Änderung per `.fixedSize` 99 pt breit (vorher 40 pt mit „…“). Nicht reproduzierbar: zweiter gemeinsamer Lauf grün, 30/30 Einzelwiederholungen, 15/15 Tipps an Mitte und Rändern.
  Spec requirement: AC-19 — die gesamte Suite ist im gemeinsamen Lauf grün; AC-15 — Seiteneffekte der Änderung an `DesignSystem.swift` sind geprüft.
  Conflict: Ein Lauf der verlangten Art war rot, und zwar an dem Element, das dieser Durchgang verändert hat. Ob die Chip-Änderung beteiligt ist oder ein allgemeiner Simulator-/XCUITest-Aussetzer vorliegt (gleiches Muster einmal am unveränderten `fork.knife`), ist mit den Daten nicht zu entscheiden; ein Vergleich mit origin/main in ausreichender Zahl wurde nicht gefahren.
  Remediation: Entscheidung durch den Menschen: (a) als bekannten UI-Aussetzer (#111/#118) hinnehmen und im Abschluss offen nennen, oder (b) vor dem Merge eine Vergleichsmessung des Schließen-Tipps auf origin/main und auf diesem Stand fahren (je mindestens 200 Tipps, im gemeinsamen Lauf). Der Produktcode muss dafür nicht geändert werden.

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Views/Premium/PaywallView.swift:60
  Evidence: Hinweis zwischen „Käufe wiederherstellen“ und Rechtstext (P10 grün); mit der PO-Ergänzung F001 rollt jetzt jeder gesetzte Hinweis ins Bild, auch derselbe Text ein zweites Mal (F004 behoben): eigener Nachbau auf 874 pt (vorher 11 %, nachher voll) und 667 pt (vorher 0 %, nachher voll), auch mit echtem StoreKit; P13 grün auf Restock-Validate (beide Suite-Läufe) und zweimal auf dem SE.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Premium/PaywallView.swift:381
  Evidence: `notice = nil` bleibt erste Anweisung in `purchase()`/`restore()`, ein einziger Zustand; in allen Wiederholungsläufen genau ein Hinweis vorhanden (Protokollfeld „Hinweise“ mit einem Eintrag); P9 grün. Beim synchronen gleichen Fehler verschwindet der alte Text nicht sichtbar zwischendurch — es ist derselbe Hinweis, das Hinrollen zeigt die neue Reaktion.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Services/FakePurchaseStore.swift:1
  Evidence: eigener Release-Build heute 08:53, `strings`: Fake 0, Argument 0, `restoreCancel` 0, Positivkontrollen vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Views/Premium/PaywallView.swift:395
  Evidence: `pending` voll sichtbar beim ersten Tipp und nach Wiederholung auf beiden Geräten; P3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Views/Premium/PaywallView.swift:385
  Evidence: Ladefehler in DEBUG (Fake) und mit echtem StoreKit, Paywall bleibt offen, auch beim zweiten Versuch voll sichtbar; P5, P13 grün.
  Status: CONFIRMED

Weiterhin gültig (Code dieser Stellen unverändert seit Runde 3/4, Tests in Lauf 2 grün): AC-1, AC-2, AC-4, AC-6, AC-7, AC-8, AC-11, AC-12, AC-13, AC-14, AC-15 (Chip 99 pt, „Schließen“ voll lesbar auf beiden Geräten; siehe aber F005), AC-16 (5/5 in Lauf 2, 4/5 in Lauf 1), AC-18 (Durchlauf (a) und (b) heute erneut gesehen), AC-20 (in dieser Runde nur `PaywallView.swift` sowie Test und Doku geändert, keine neuen Dateien), AC-21 (F004 ist behoben und muss nicht mehr in die Zusagen; F005 muss hinein, solange offen). AC-19: Lauf 2 erfüllt alle Bedingungen, Lauf 1 nicht — offen bis zur Entscheidung zu F005.

**Implementierer:** (vom Orchestrator weiterzugeben) — Stellungnahme zu F005 offen.

### Runde 6

**Adversary:** Entscheidung zu F005 durch Vergleichsmessung. Code, Tests und Spec im Worktree unveraendert (SHA-256 vor und nach der Messung gleich: PaywallView fab90cc7, PremiumService a4bcc4c0, FakePurchaseStore c946312e, DesignSystem b8827cc3). Beide Sperren (heavy-build, loose-ends-testlauf) vorher in der Warteschlange genommen, danach sofort freigegeben (geprueft: beide Verzeichnisse weg).

1. **Aufbau der Messung** (Details und Sondenquelltext in `adversary-r6-vergleich.md`): Stand A = origin/main (506eb4b, identisch zum Merge-Base), Stand B = Worktree inkl. uncommittete Aenderungen, je als Wegwerf-Kopie; die Sonde (Tipp auf chart.bar, Paywall abwarten, Tipp auf "Schliessen", 5 s auf Verschwinden pruefen, ohne Assert je Tipp) nur in den Kopien. Ein frisch angelegter Wegwerf-Simulator (iPhone 17 Pro, iOS 26.5, Typ und Runtime von Restock-Validate), Bloecke abwechselnd A1 B1 A2 B2 A3 B3 A4 B4 zu je 75 Tipps, dazu 5 Lastprozesse `yes` (10 Kerne) und die fremde Last anderer Sitzungen (Lastmittel 1 min 153,75 zu Beginn, 13 bis 45 spaeter). Wegwerf-Simulator danach geloescht, Lastprozesse beendet, Pruefung ohne Reste.

2. **Messzahlen:** Stand A (origin/main) 300 Tipps, 0 Fehlschlaege, 0 Oeffnen-Fehler. Stand B (Zweig) 300 Tipps, 0 Fehlschlaege, 0 Oeffnen-Fehler. Je Block 75/0 auf beiden Staenden (Rohprotokolle `adversary-r6-vergleich-main.txt`, `adversary-r6-vergleich-branch.txt`). Vorab festgelegte Regel: B signifikant schlechter als A (mindestens 3 Fehlschlaege mehr und mindestens doppelte Rate) bestaetigt F005. Das trifft nicht zu: beide gleich (0 gegen 0). F005 ist als Regression durch den Chip-Fix nicht bestaetigt.

3. **Grenze der Aussage, offen genannt:** Der Aussetzer aus Runde 5 trat in 600 Sondentipps auf keinem Stand auf; die Messung kann ihn daher keinem Stand zuordnen, sie schliesst nur einen merklichen Unterschied zwischen B und A unter Last aus. Zusammen mit den Befunden aus Runde 5 (30/30 Einzelwiederholungen, 15/15 Tipps an Mitte, linkem und rechtem Rand des 99-pt-Chips, derselbe Fehler einmal am unveraenderten `fork.knife`) bleibt die Einordnung "bekannter UI-Aussetzer (#111/#118)", nicht "bewiesen ein Aussetzer".

4. **AC-19, weiterer gemeinsamer Gesamtlauf** (Restock-Validate, `-derivedDataPath build/dd-adv`, keine weiteren Build-Settings, Code byte-gleich zu Runde 5; vorher `adversary-test-output.txt` als `adversary-test-output-runde5-lauf2.txt` gesichert): Unit 610/610; UI 130 ausgefuehrt, 127 bestanden, 0 fehlgeschlagen, 3 uebersprungen (`NotificationPermissionUITests` testAllow/testDeny und `ReceiptShareExtensionTests`, bekannte Gates); `PremiumServiceTests` 15/15, `PurchaseUITests` 13/13, `PaywallUITests` 5/5; TEST SUCCEEDED, EXIT 0; 0 Neustarts des Testlaeufers (`Restarting after unexpected exit`), `developerMode` nicht gesetzt. Bilanz der gemeinsamen Gesamtlaeufe mit diesem Code: 2 von 3 gruen, der rote hat einen einzelnen nicht reproduzierbaren Schliessen-Tipp ohne Wirkung; ein Zweitlauf gruen ist in Runde 5 und in Runde 6 belegt.

5. **Herkunft/Regression:** Die vier geaenderten Code-Dateien wurden in dieser Runde nicht veraendert und nicht neu gelesen ausser zur Hash-Kontrolle; ihre Bewertung aus Runde 5 gilt. `adversary_dialog.py required-files` listet genau diese vier Dateien.

Code reference: SmartCart/Extensions/DesignSystem.swift:181
Code reference: SmartCart/Views/Premium/PaywallView.swift:60
Code reference: SmartCart/Services/PremiumService.swift:214
Code reference: SmartCart/Services/FakePurchaseStore.swift:8

Confirmation:
  AC: AC-19
  Code reference: SmartCart/Extensions/DesignSystem.swift:181
  Evidence: Zweiter gruener gemeinsamer Gesamtlauf mit unveraendertem Code (Unit 610/610, UI 127 bestanden, 0 fehlgeschlagen, 3 uebersprungen, EXIT 0); der rote Lauf aus Runde 5 ist durch die Vergleichsmessung (A 0/300, B 0/300 unter Last) nicht der Chip-Aenderung zuzuordnen.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/Extensions/DesignSystem.swift:181
  Evidence: Seiteneffekt des app-weit wirkenden `.fixedSize` auf die Bedienbarkeit des Schliessen-Chips unter Last gemessen: 300 von 300 Tipps schliessen die Paywall, gleich wie auf origin/main.
  Status: CONFIRMED

Finding F005 (Status: GESCHLOSSEN als bekannter UI-Aussetzer, Regression nicht bestaetigt; Restunsicherheit oben genannt).

**Implementierer:** (vom Orchestrator weiterzugeben) Die Restunsicherheit aus 3. gehoert in die Abschlusszusagen von AC-21.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat die Pruefung ueberstanden. F001 bis F004 sind behoben. F005 ist geschlossen: Vergleichsmessung des Schliessen-Tipps unter gleicher Last auf demselben Wegwerf-Simulator, abwechselnd in Bloecken: origin/main 0 Fehlschlaege in 300 Tipps, Zweig 0 Fehlschlaege in 300 Tipps. Die vorab festgelegte Regel (Zweig mindestens 3 Fehlschlaege mehr und mindestens doppelte Rate) greift nicht; der rote Lauf aus Runde 5 ist als bekannter UI-Aussetzer (#111/#118) eingeordnet.

Offene Grenze (in die Abschlusszusagen aufnehmen): Der Aussetzer trat in der Messung auf keinem Stand auf; die Messung zeigt keinen Unterschied zwischen Zweig und main, beweist aber nicht, dass er auf main ebenso auftreten wuerde. Ein Gesamtlauf von drei mit diesem Code war rot (ein Schliessen-Tipp ohne Wirkung), zwei gruen.
Tests: Letzter Gesamtlauf (Runde 6) Unit 610 bestanden, 0 fehlgeschlagen, 0 uebersprungen; UI 130 ausgefuehrt, 127 bestanden, 0 fehlgeschlagen, 3 uebersprungen (bekannte Gates), EXIT 0.
Edge cases: Alle geprueft, keine gebrochen.
Regressions: Keine gefunden.
Checklist: 21/21 Punkte bewiesen (AC-19 mit zweitem gruenen Gesamtlauf).

## Geprüfte Dateien

- sha256:b8827cc3ba9ca7a3f511e48d6e83421f1f2f68ba2df6c1ceff4dbd21aa99aaa8  SmartCart/Extensions/DesignSystem.swift
- sha256:c946312ed56f224f42c8a767b515658f471e80dbadb3cb6f6b7c015af3d03739  SmartCart/Services/FakePurchaseStore.swift
- sha256:a4bcc4c0aea091eb3fcbe616d71f4ea0fd7095fbb5cd558af9ae08ff61b954b6  SmartCart/Services/PremiumService.swift
- sha256:fab90cc71b17f8c30bf8b4867b2b8ca9bded673f304ea3f3112159195ed5c3c0  SmartCart/Views/Premium/PaywallView.swift

## Prüfbasis

- base: 506eb4b9ea01f58eac881c7fcaaa954df25c0467
- blob:574a1c0b4f85abe149df9c420004e7519fcb4825  SmartCart/Extensions/DesignSystem.swift
- blob:2c05268e73158fbb4f9e3d4d3d3a575e9a44a08b  SmartCart/Services/FakePurchaseStore.swift
- blob:f35b1f5188ffb72545e50e45e4a7daa0b077571f  SmartCart/Services/PremiumService.swift
- blob:63c17b9832d16bc1acc59cba3e86db0f156d73a6  SmartCart/Views/Premium/PaywallView.swift
