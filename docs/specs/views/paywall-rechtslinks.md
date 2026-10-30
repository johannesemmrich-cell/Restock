---
entity_id: paywall-rechtslinks
type: feature
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: fix-215-paywall-rechtslinks
tags: [paywall, premium, datenschutz, eula, app-store, review-3-1-2]
---

# Paywall: Links zu Datenschutz und Nutzungsbedingungen, Abo-Text (Issue #215)

## Approval

- [ ] Spec-Freigabe durch den PO (steht aus)

## Purpose

Die Paywall (`PaywallView`) zeigt keine Links zu Datenschutzerklärung und Nutzungsbedingungen (EULA) und
nennt Name, Laufzeit und Preis der Abos nicht am Kaufpunkt. Apple verlangt laut Review-Richtlinie 3.1.2(c)
die Angaben aus Schedule 2 des Lizenzvertrags; der genaue Wortlaut ist nicht belegt (siehe Offene Grenzen). Das hat nie funktioniert (fehlende Funktion, keine Verschlechterung). Es droht
Ablehnung beim Einreichen von Release 1.0 (#175).

Heute steht nur ein Satz: „Abonnements verlängern sich automatisch. Kündigung jederzeit in den
iPhone-Einstellungen möglich.“ (`legalText`).

Der PO hat den **Entwurf A** freigegeben (Henning, 2026-10-30); die Freigabe dieser Spec steht noch aus
(Kästchen oben). Entwurf A: unter „Käufe wiederherstellen“ eine Link-Zeile
„Datenschutz · Nutzungsbedingungen (EULA)“ mit zwei getrennt antippbaren Links, dazu der Abo-Text angelehnt
an Apples Standardwortlaut (Schedule 2 ist nicht abrufbar, siehe Offene Grenzen). Entwurfsvorschau: `docs/artifacts/fix-215-paywall-rechtslinks/entwurf-paywall-rechtslinks.src.html`,
Analyse: `docs/context/fix-215-paywall-rechtslinks.md`.

## Scope

| Datei | Änderung | LoC (ca.) |
|-------|----------|-----------|
| `SmartCart/Views/Premium/PaywallView.swift` | `legalText` ersetzt durch Abo-Text + Link-Zeile; zwei URL-Konstanten | +35/−5 |
| `RestockUITests/PaywallUITests.swift` | Hilfe `scrollUntilHittable` (~25), `launchLocked(extraArguments:)` (~4), Test 1 samt Abo-Text-Prüfung und Anhang (~25), Test 2 bei größter Schrift (~12) | +65 |
| `RestockTests/PaywallLegalLinksTests.swift` | NEU, Drift-Schutz URLs gegen `docs/appstore/{de,en}.md` | +35 |
| `Restock.xcodeproj/project.pbxproj` | Registrierung der neuen Testdatei (4 Stellen) | +4 |

Artefakte (keine Produktdateien, nicht im Datei-Limit), die bei der Umsetzung neu entstehenden unter `docs/artifacts/fix-215-paywall-rechtslinks/` (daneben liegt dort schon der Entwurf `entwurf-paywall-rechtslinks[.src].html`): `store-shots/`, `screenshot-befund.md`, `paywall-unten-hell.png`, `paywall-unten-dunkel.png`, `benutzen-befund.md`.

4 Dateien, geschätzt +140/−5 inkl. Registrierung und Tests; Produktcode ca. +35/−5 (Limit 4–5 Dateien,
±250 LoC eingehalten). Nicht berührt: `Localizable.strings`, `PrivacyInfo.xcprivacy`, Berechtigungen,
CloudKit-Schema, `LegalView`, `PremiumService`, `ci.yml`.

## Verhalten

1. **Reihenfolge im Scrollbereich** (unverändert bis auf den letzten Block): Kopf, Plankarten,
   Kaufknopf, „Käufe wiederherstellen“, optionaler Hinweis (`noticeView`, `.id(noticeScrollID)`), dann
   der neue Rechtsblock an der Stelle des bisherigen `legalText`. „Wiederherstellen“ und das Hinrollen
   zum Hinweis (F001/F004 aus #145 D4) bleiben unberührt.
2. **Rechtsblock** (`legalText`, zentriert, 11 pt, `.tertiary` wie bisher; Links in `.secondary`
   mit Unterstreichung, damit sie als Links erkennbar sind):
   - Abo-Text: „Restock Pro – Jährlich: 1 Jahr, \(Preis)/Jahr. Restock Pro – Monatlich: 1 Monat, \(Preis)/Monat.
     Die Abos verlängern sich automatisch um die gleiche Laufzeit, wenn du sie nicht mindestens 24 Stunden
     vor Ablauf des laufenden Zeitraums in den Einstellungen deiner Apple-ID kündigst. Die Zahlung wird
     über deine Apple-ID abgewickelt. Der Einmalkauf ist kein Abo und verlängert sich nicht.“
   - Preise kommen aus `productPrice(for:)` (folgt dem Store, bei leerem `products` im Simulator gelten
     die vorhandenen Ersatzpreise der Paywall). Die Namen sind „Restock Pro – “ plus der Titel der Plankarte
     („Jährlich“, „Monatlich“).
   - Link-Zeile direkt unter dem Abo-Text: zwei `Link`-Elemente „Datenschutz“ und „Nutzungsbedingungen
     (EULA)“, getrennt durch „ · “. Keine festen Breiten und kein `lineLimit`: bei großer Schrift bricht
     die Zeile um (zwei Zeilen, jeder Link bleibt für sich antippbar), z. B. über `ViewThatFits` mit
     vertikalem Rückfall oder einen umbrechenden Container. Die Zeile bleibt im Scrollbereich erreichbar
     (`.padding(.bottom, 32)` bleibt).
3. **Ziele und Text** (`enum PaywallLegalLinks` in `PaywallView.swift`, Namespace ohne Zustand):
   - `static let privacyURL: URL`, `static let termsURL: URL`
   - `static func subscriptionNotice(yearlyPrice: String, monthlyPrice: String) -> String`: reine Funktion, liefert den Abo-Text aus Ziffer 2; `legalText` ruft sie mit `productPrice(for:)` auf.
   - `termsURL` = `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
   - `privacyURL` = `https://emmrich-business.com/datenschutz`
   Quelle der Wahrheit sind `docs/appstore/de.md` und `en.md` (Abschnitt `## privacy_url` und die Zeile
   „Nutzungsbedingungen (Apples Standard-Lizenzvereinbarung)“); der Drift-Schutz (AC-5) hält sie gleich.
4. **Öffnen: SwiftUI-`Link(destination:)`.** Begründung: kein Code für das Öffnen, VoiceOver sagt
   „Link“ (Trait `.link`), XCUITest findet die Elemente als `app.links` und kann sie prüfen, ohne zu
   tippen, also ohne Browseraufruf im Test. Der Bestandsweg `UIApplication.shared.open` (`SettingsView`)
   bräuchte einen `Button` ohne Link-Trait und zusätzlichen Code. Kein In-App-Browser (kein
   `SFSafariViewController`), damit keine neue Abhängigkeit entsteht.
5. **Keine neuen Texte in `Localizable.strings`**: Paywall-Texte sind deutsche Literale (Bestand); die
   englische Fassung der Paywall liegt außerhalb dieses Tickets.
6. **Kein Premium-Zustand, kein Kauf betroffen**: reine Anzeige. Bereits freigeschaltete Nutzer sehen die
   Paywall nicht.

## Acceptance Criteria

- [ ] AC-1: Auf der Paywall (ohne Premium, `-developerMode NO`) gibt es nach Hochscrollen zwei Link-Elemente mit den Beschriftungen „Datenschutz“ und „Nutzungsbedingungen (EULA)“ (`app.links`), jedes für sich existierend.
- [ ] AC-2: Beide Links liegen nach dem Scrollen vollständig im Fenster (Rahmen liegt in `app.windows.firstMatch.frame`) und sind antippbar (`waitUntilHittable()` liefert `matched`) auf dem Projekt-Testsimulator `Restock-Validate-27` (iOS 27; der ältere Eintrag `Restock-Validate` ist auf diesem Rechner nicht lauffähig).
- [ ] AC-3: Das Ziel des Datenschutz-Links ist `https://emmrich-business.com/datenschutz`, das des EULA-Links `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`; beide stehen genau einmal als Konstanten (`PaywallLegalLinks`), der Rechtsblock benutzt nur diese.
- [ ] AC-4: Der Abo-Text nennt Name und Laufzeit beider Abos (1 Jahr, 1 Monat), den Preis je Abo aus `productPrice(for:)` (nicht fest einkodiert), die automatische Verlängerung, die Kündigung mindestens 24 Stunden vor Ablauf, die Zahlung über die Apple-ID und ausdrücklich, dass der Einmalkauf kein Abo ist und sich nicht verlängert.
- [ ] AC-5: Ein Unit-Test liest `docs/appstore/de.md` und `docs/appstore/en.md` und weist nach, dass die Datenschutz-URL der Konstante im Abschnitt `## privacy_url` steht (Text zwischen dieser Überschrift und der nächsten `## `-Überschrift) und die EULA-URL der Konstante in der Zeile, die in `de.md` mit „Nutzungsbedingungen (Apples Standard-Lizenzvereinbarung)“ und in `en.md` mit „Terms of Use (Apple's standard license agreement)“ beginnt; weicht eine Konstante oder eine Store-Datei ab, schlägt er fehl.
- [ ] AC-6: Bei Schrift `AccessibilityXXXL` sind beide Links im UI-Test `testLegalLinksReachableAtLargestTextSize` vorhanden, vollständig im Fenster, antippbar und überlappen sich nicht (keine feste Breite, kein abgeschnittener Link).
- [ ] AC-7: Die Links öffnen im Test keinen Browser; der UI-Test prüft Existenz, Lage und Antippbarkeit, tippt aber nicht.
- [ ] AC-8: Der Befund, ob der neue Rechtsblock auf den Paywall-Store-Bildern (`de/05-pro.png`, `en/05-pro.png`) sichtbar ist, wird bei der Umsetzung erzeugt und steht in `docs/artifacts/fix-215-paywall-rechtslinks/screenshot-befund.md` (je Bild „sichtbar“ oder „nicht sichtbar“, mit Dateiname der Aufnahme). „Sichtbar“ heißt: mindestens ein Teil des Abo-Texts oder der Link-Zeile liegt im Bild. Bei „nicht sichtbar“ ist nichts weiter zu tun. Bei „sichtbar“ meldet Claude das dem PO mit den Bildern, und der PO entscheidet über eine Neuaufnahme der Store-Bilder; diese ist nicht Teil dieses Tickets.
- [ ] AC-9: Bestehende Paywall-Tests (`PaywallUITests`, `PurchaseUITests` P1–P11 mit Hinweis-Hinrollen und „vollständig im Fenster und antippbar“) bleiben unverändert grün; „Käufe wiederherstellen“ steht weiter vor dem Rechtsblock.
- [ ] AC-10: Die Dateinamenliste des Diffs gegen `origin/main` (geänderte und neue Dateien) enthält keine Datei aus `SmartCart/Resources/*/Localizable.strings`, `InfoPlist.strings`, `PrivacyInfo.xcprivacy`, `project.yml` und keine CloudKit-Schemadatei unter `docs/cloudkit/`; `grep -n AppStorage SmartCart/Views/Premium/PaywallView.swift` liefert vor und nach der Änderung dieselbe Trefferzahl. Außerhalb der vier Scope-Dateien sind nur Dateien unter `docs/` sowie Workflow-Zustand unter `.claude/` (Befehlsvorlagen, Herdr-Protokolle; kein Produktcode) geändert.
- [ ] AC-11: Benutzen statt nur testen: Die Paywall wurde im Simulator geöffnet und nach unten gescrollt; Claude prüft die Aufnahmen `docs/artifacts/fix-215-paywall-rechtslinks/paywall-unten-hell.png` und `paywall-unten-dunkel.png` per Bildansicht und vermerkt je Bild in `docs/artifacts/fix-215-paywall-rechtslinks/benutzen-befund.md` „Abo-Text vollständig“ und „beide Links vollständig“ (nichts abgeschnitten, Text lesbar). Eine Abweichung in einem Bild heißt AC-11 nicht erfüllt.

## Tests

**UI-Tests** (`RestockUITests/PaywallUITests.swift`, bestehende Datei, erweitert):
- Neue private Testhilfe `scrollUntilHittable(_:_:description:)` in `PaywallUITests` (Abschrift der gleichnamigen
  Hilfe aus `DynamicTypeUITests`, dort `private`): wischt bis das Element existiert, dann bis
  `waitUntilHittable()` gilt (kurze Nachzüge), sonst Fehler mit letztem Zustand. Der bestehende `scrollTo`
  reicht nicht, weil er nur bis „existiert“ wischt und Inhalt unter dem Rand schon im Baum steht.
- `testLegalLinksReachableOnPaywall` (AC-1, AC-2, AC-7): `launchLocked()`, Paywall über fork.knife öffnen
  (wie `testRecipePlanLockedOpensPaywall`), `assertPaywall`, `scrollUntilHittable` auf beide Links
  („Datenschutz“, „Nutzungsbedingungen (EULA)“), Rahmen liegt in `app.windows.firstMatch.frame`; kein `tap()`. Danach (vor dem Ende) Prüfpunkt: Der Anfang des Abo-Texts (`app.staticTexts` mit Label-Anfang „Restock Pro – Jährlich“) und die Link-Zeile liegen zugleich im Fenster; ist der Abo-Text oben abgeschnitten, wird einmal kurz zurückgewischt (`swipeDown` ein Zug), bis beide im Fenster liegen, sonst schlägt der Test fehl. Dann wird `XCTAttachment(screenshot: app.screenshot())` mit `name = "paywall-unten"` und `lifetime = .keepAlways` angehängt (Muster `StoreScreenshotCaptureUITests.save`).
  Gegenprobe: „Käufe wiederherstellen“ existiert und liegt oberhalb der Links (`frame.maxY <= link.frame.minY`).
- `testLegalLinksReachableAtLargestTextSize` (AC-6, verbindlich): gleicher Ablauf; `launchLocked()` bekommt dafür
  den optionalen Parameter `extraArguments: [String] = []` (Standard unverändert, bestehende Aufrufer
  bleiben gleich), der vor dem Start an `app.launchArguments` angehängt wird; der Start bleibt
  `UITestLaunch.start(app, expecting: app.buttons["fork.knife"], …)` mit Gegenprobe (#105/#128). Argument:
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` wie in `DynamicTypeUITests`
  (Argument-Domain, kein Aufräumer nötig); beide Links existieren, liegen im Fenster und sind antippbar,
  und liegen untereinander oder nebeneinander ohne Überlappung (Rahmen schneiden sich nicht).
- Klassenlauf, Testzahl und Fehlschläge prüfen (kein Null-Test-Lauf als Grün).

**Unit-Test** (`RestockTests/PaywallLegalLinksTests.swift`, neu, in `project.pbxproj` an den vier Stellen
registrieren: `PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase` des Test-Ziels):
- `testPrivacyURLMatchesStoreTexts` und `testEULAURLMatchesStoreTexts` (AC-3, AC-5): lesen
  `docs/appstore/de.md` und `en.md` über `#filePath` wie `PrivacyManifestTests`; die Datenschutz-URL wird nur im Abschnitt `## privacy_url`, die EULA-URL nur in der Zeile mit dem Dateimarker („Nutzungsbedingungen (Apples Standard-Lizenzvereinbarung)“ in `de.md`, „Terms of Use (Apple's standard license agreement)“ in `en.md`) gesucht (Testhilfe `section(_:in:)`); Gegenprobe: eine
  bewusst abweichende URL wird nicht akzeptiert. Geprüft wird mit der privaten Testhilfe
  `section(_ heading: String, in markdown: String) -> String` (liefert den Text zwischen der Überschrift
  `## <heading>` und der nächsten `## `-Überschrift, leer wenn es sie nicht gibt) und
  `containsURL(_ text: String, _ url: URL) -> Bool` (Teilstring-Suche). Die Datenschutz-URL wird nur im
  Ergebnis von `section("privacy_url", in:)` gesucht, die EULA-URL nur in der Zeile, die mit dem jeweiligen Dateimarker
  beginnt. Gegenproben: (a) eine fremde URL liefert `false`; (b) ein Markdown-Text, der die Datenschutz-URL nur
  unter `## description` enthält, liefert bei `containsURL(section("privacy_url", in: text), url)` `false` (die echten Dateien
  nennen die URL auch in `## description`, ein Ganzdatei-Test bliebe sonst grün).
- `testSubscriptionNoticeMentionsRequiredParts` (AC-4): `PaywallLegalLinks.subscriptionNotice(yearlyPrice:monthlyPrice:)`
  mit zwei Beispielpreisen enthält Jahr, Monat, beide Preise, „24 Stunden“, „Apple-ID“, „kein Abo“.

**Nachweislauf Store-Screenshots** (AC-8, Schritte): `StoreScreenshotCaptureUITests` (`testCaptureGerman` und
`testCaptureEnglish`; ein Lauf nur der Paywall ist nicht möglich, die Bilder 01–04 entstehen mit) auf dem
Projekt-Testsimulator `Restock-Validate-27` (iOS 27; der ältere Eintrag `Restock-Validate` ist auf diesem Rechner nicht lauffähig) mit `TEST_RUNNER_RESTOCK_STORE_SHOTS_DIR` auf
`docs/artifacts/fix-215-paywall-rechtslinks/store-shots/` (Wegwerf-Ablage, nicht die Store-Bilder) fahren,
`de/05-pro.png` und `en/05-pro.png` ansehen und den Befund eintragen. Ein größeres Gerät zeigt mehr; die
Aussage gilt daher nur für die Größe von Projekt-Testsimulator `Restock-Validate-27` (iOS 27; der ältere Eintrag `Restock-Validate` ist auf diesem Rechner nicht lauffähig) (offene Grenze).

**Benutzen statt nur testen** (Regel 2026-09-27, AC-11): Vor der Übergabe Paywall im Simulator öffnen, hinunterscrollen,
beide Links in der Ansicht sehen; Aufnahmen hell und dunkel als Artefakte (Pfade in AC-11). Erzeugung: `testLegalLinksReachableOnPaywall` hängt nach dem Hochscrollen (beide Links antippbar) einen Bildschirmfoto-Anhang (`XCTAttachment`, `lifetime = .keepAlways`, Name `paywall-unten`) an. Der Test läuft zweimal auf dem Testsimulator (`-only-testing:RestockUITests/PaywallUITests/testLegalLinksReachableOnPaywall`), einmal nach `xcrun simctl ui <udid> appearance light`, einmal nach `... appearance dark`, jeweils mit eigenem `.xcresult` (`-resultBundlePath`). Aus jedem wird mit `xcrun xcresulttool export attachments --path <xcresult> --output-path <Ordner>` exportiert; die Datei, deren Eintrag in der dort erzeugten `manifest.json` den `suggestedHumanReadableName` mit Anfang „paywall-unten“ trägt, wird als `paywall-unten-hell.png` bzw. `paywall-unten-dunkel.png` abgelegt. Commit-Kennung, Zeit und Gerät stehen im Kopf von `benutzen-befund.md`. Die Aufnahme darf nicht von Hand gesetzt oder aus einem älteren Stand übernommen werden.

## Alternativen (gekippte Entscheidung)

- **B: Links direkt unter dem Kaufknopf.** Näher am Kauf, schiebt aber „Käufe wiederherstellen“ und die
  Hinweise aus #145 D4 (Hinrollen an `noticeScrollID`) nach unten und riskiert die dortigen Tests.
  Gekippt, weil Entwurf A (PO) genügt und weniger Bestand berührt.
- **C: Rechtstexte in der App** (`LegalDocument` aus `LegalView` statt Webseite). Funktioniert ohne Netz,
  stellt aber die eigenen Nutzungsbedingungen der App neben Apples Standard-EULA aus den Store-Daten
  (`docs/appstore/{de,en}.md`); beide würden sich widersprechen. Würde die Festlegung auf die Standard-EULA
  kippen. Nur sinnvoll, wenn der PO eigene Bedingungen will.
- Kein Modell, keine Regel nötig: reine Oberfläche.

## Offene Grenzen

- Der Wortlaut von Schedule 2 des Apple Developer Program License Agreement ist nicht abrufbar und damit
  nicht belegt; ebenso ist nicht belegt, ob In-App-Texte statt öffentlicher URLs genügen. Die Lösung mit
  öffentlichen URLs plus Abo-Text deckt beide Lesarten ab, ist aber keine Zusage, dass Apple sie annimmt.
- Die Datenschutzseite `emmrich-business.com/datenschutz` gehört einem Dritten; Erreichbarkeit und Inhalt
  hängen von ihm ab, und sie beschreibt die Funktionen laut #175 noch nicht ganz richtig (formal besteht
  der Link die Prüfung, inhaltlich bleibt es ein Produktrisiko).
- Ohne Netz öffnet der Link nichts (Safari-Fehler); kein Absturzrisiko.
- Das echte Öffnen im Browser ist nicht automatisiert geprüft (der Test tippt bewusst nicht).
- Paywall-Texte sind nur deutsch (englische Paywall außerhalb des Tickets).
- Preise im Abo-Text folgen dem Store; im Simulator (leeres `products`) sieht man nur die Ersatzpreise.
- Die Aussage zu den Store-Bildern (AC-8) gilt nur für die Bildgröße von Projekt-Testsimulator `Restock-Validate-27` (iOS 27; der ältere Eintrag `Restock-Validate` ist auf diesem Rechner nicht lauffähig), nicht für die zweite Größenklasse.
- Nichts auf Hennings Geräten geprüft.

## Changelog

- 2026-10-30: Erstfassung (Entwurf A freigegeben), Link per `Link(destination:)` begründet.
- 2026-10-30: Zweite Validierung: Hilfe `scrollUntilHittable`, Namen/Signaturen `PaywallLegalLinks`, AC-8 mit festen Schritten.
- 2026-10-30: Nach Validierung: Plan-Namen „Restock Pro – Jährlich/Monatlich“, UI-Testdatei als erweitert, AC-6 verbindlicher Test, `scrollTo(…, in: app)`, Testgerät benannt, AC-8 mit festem Prüfpunkt, Freigabe-Formulierung.
