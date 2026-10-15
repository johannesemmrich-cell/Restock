---
entity_id: test-98-durchgang-5-onboarding-paywall
type: test
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: test-98-durchgang-5-onboarding-paywall
tags: [test, ui-test, onboarding, paywall, premium, dev-password, debug-only]
---

# UI-Test-Durchlauf: Onboarding, Paywall-Sperre und Dev-Passwort (falsch) (Issue #98, Durchgang 5)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Punkt 7 aus #98, erster Teil. Drei Ketten, die heute in keinem Test den echten Weg laufen:

1. **Onboarding** (`OnboardingView`, fünf Schritte: Willkommen, Name, Land, Läden, Tutorial). Alle
   bestehenden UI-Tests starten mit `-hasCompletedOnboarding YES` und überspringen es. Kein Test hat
   es je gesehen. Unbewiesen ist, dass ein neuer Nutzer überhaupt bis zur Startseite kommt, dass die
   gewählten Läden (und nur diese) dort stehen, dass der Name ankommt und dass das Onboarding nach
   einem Neustart nicht wiederkehrt.
2. **Paywall-Sperre** (`HomeView` Zeilen ~1389–1406, `SettingsView` Zeilen ~145–150, `PaywallView`).
   Ohne Premium müssen Rezeptplan (fork.knife), Ausgaben-Analyse (chart.bar) und die Zeile „Restock
   Pro freischalten“ die Paywall mit dem passenden Funktionsnamen öffnen statt der Funktion. Heute
   läuft jeder Test, der die Funktionen berührt, mit `-developerMode YES` an der Sperre vorbei.
3. **Dev-Passwort** (`DevPasswordSheet` in `SettingsView`): fünf Tipps auf die Version öffnen das
   Sheet; ein falsches Passwort muss „Falsches Passwort“ zeigen, die Eingabe leeren und das Sheet
   offen lassen.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03), die
Scoping-Limits gelten je Durchgang. Dies ist Durchgang 5 = Onboarding + Paywall-Sperre + Dev-Passwort
(Falsch-Pfad). **`StoreSetupView` (Laden-Einrichtung) ist Durchgang 6** und nicht Teil dieser Spec.
Punkte 5 (Tagesmitteilung) und 6 (Siri/Widget) bleiben offen für einen späteren Durchgang.

Produktcode bekommt einen `#if DEBUG`-Zweig und (Nachtrag nach RED, PO-Entscheidung „jetzt mitfixen“
2026-10-12) eine kleine Korrektur in `HomeView`: Der RED-Lauf von P1 reproduzierte, dass die Paywall aus
fork.knife/chart.bar „Schalte dieses Feature …“ statt „den Rezeptplan“/„die Ausgaben-Analyse“ zeigt
(`.sheet(isPresented:)` liest `paywallFeature` beim ersten Öffnen mit dem alten Wert; bekannte
SwiftUI-Eigenheit, Abhilfe `.sheet(item:)`; Quellen: Apple-Forum 694462, swiftjectivec „Presenting
Sheets: Item, or a Boolean Binding?“). Sonst ändert sich kein Produktverhalten. Kein Modell
beteiligt, alles deterministisch (Regel vor Modell: nichts hier braucht ein Sprachmodell).

**Offene Grenzen (gelten für jede positive Zusage dieses Durchgangs):**

- Ein **Kauf**, **Wiederherstellen** und die **Release-Fehlermeldung** der Paywall („Der Kauf konnte
  nicht geladen werden…“) sind nicht automatisiert geprüft. Im Simulator ist `products` leer, weil
  `Restock.storekit` (liegt im Repo-Wurzelordner) in keinem Scheme verdrahtet ist; ein Tipp auf den
  Kaufknopf liefe in den DEBUG-Zweig (`dismiss()` ohne Kauf, `PaywallView.purchase()`), der nicht der
  Release-Weg ist. Der Test tippt ihn deshalb bewusst nicht.
- Der **Richtig-Pfad des Dev-Passworts** (richtiges Passwort schaltet `developerMode` ein) ist nicht
  geprüft; geprüft wird nur der Falsch-Pfad. Begründung siehe Abschnitt „Dev-Passwort“.
- **`StoreSetupView`** folgt in Durchgang 6.

## Source

- **Neu:** `RestockUITests/OnboardingUITests.swift` — ein Durchlauf (Test O1), tearDown mit
  `-clearOnboardingForUITests` (~110 LoC).
- **Neu:** `RestockUITests/PaywallUITests.swift` — Paywall-Sperre an den drei Auslösern, Gegenprobe,
  Dev-Passwort Falsch-Pfad (~130 LoC).
- **Geändert:** `SmartCart/SmartCartApp.swift` — nur `#if DEBUG`: neues Launch-Argument
  `-clearOnboardingForUITests` (~15 LoC, Muster der bestehenden `clear…ForUITestsIfNeeded`):
  - `deleteAllStoresAndItems(context:)` (vorhanden) + `context.save()`
  - `UserDefaults.standard.removeObject(forKey:)` für `hasCompletedOnboarding` und `selectedCountry`
  - Anzeigename: `removeObject(forKey: UserIdentity.storageKey)` in der Suite
    `group.com.johannesemmrich.SmartCart`
  - Aufruf in der DEBUG-Liste im `defer` von `init()`.
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — zwei neue Testdateien in `PBXBuildFile`,
  `PBXFileReference`, `PBXGroup` (RestockUITests), `PBXSourcesBuildPhase` des UITests-Targets (~10 LoC).
- **Nicht geändert (ausdrücklich):** `OnboardingView`, `OnboardingGate` (Auswertung von
  `hasCompletedOnboarding`; alle UI-Tests hängen daran), `PaywallView`, `PremiumService`, `HomeView`
  (außer der Paywall-Korrektur unten),
  `SettingsView` (inklusive `DevPasswordSheet` und Hash), `CloudPreferencesSync`, alle Texte und
  Layout. Keine neue `Info.plist`-Berechtigung, kein neuer `@AppStorage`-Schlüssel, keine neue
  Datei im Produktziel, keine Scheme-Änderung.

- **Geändert (Nachtrag):** `SmartCart/Views/Home/HomeView.swift` — nur die Paywall-Darstellung:
  `showPaywall` + `paywallFeature` werden durch eine Identifiable-Anfrage und `.sheet(item:)` ersetzt
  (~8 LoC); Texte und Layout der Paywall bleiben, nur der Funktionsname stimmt nun.

Geschätzter Umfang: 5 Dateien (2 Tests, `SmartCartApp.swift`, `HomeView.swift`, `project.pbxproj`),
ca. +275 LoC (Tests zählen nach tatsächlichem Diff), davon ca. 23 Produktcode. Das liegt im Dateilimit (4–5) und **an der Grenze des Zeilenlimits
(±250)**. Kandidaten zum Kürzen, falls das Scope-Gate anschlägt: Gegenprobe P4 (~25 LoC) und der
Neustart-Teil von O1 (~15 LoC). Wird es trotzdem mehr, Rückmeldung mit Schätzung vor dem Weiterbau.

## Verhalten

### Befunde aus dem Code (gegen die Analyse geprüft)

- **Argument-Domain und `hasCompletedOnboarding`:** `-hasCompletedOnboarding NO` als Launch-Argument
  landet in der Argument-Domain von `UserDefaults`. Sie wird beim Lesen vor der App-Domain
  ausgewertet und beim Schreiben nicht verändert. `finishOnboarding()` setzt zwar `true`, der
  `@AppStorage` im `OnboardingGate` läse aber weiter `NO` — das Onboarding bliebe auf dem letzten
  Schritt stehen. **Der Onboarding-Test startet deshalb ohne dieses Argument** und stellt den
  Ausgangszustand über `-clearOnboardingForUITests` her. Der Test beweist das selbst: Ohne
  funktionierendes Entfernen der Schlüssel erschiene schon der erste Schritt („Loslegen“) nicht, und
  ohne Schreiben in die App-Domain bliebe der Neustart-Teil rot.
- **Reihenfolge:** `CloudPreferencesSync.start()` (spiegelt `hasCompletedOnboarding` und
  `selectedCountry` über iCloud-Schlüsselwerte) läuft in `init()` vor dem `defer`-Block, der die
  DEBUG-Clears ausführt. Das Clear kommt also nach dem Rückfüllen leerer lokaler Felder aus iCloud
  und gewinnt. Das Clear löscht **nicht** im iCloud-Schlüsselwertspeicher: Eine Löschung dort würde
  über ein im Simulator angemeldetes Konto auf echte Geräte desselben Kontos durchschlagen
  (`iCloudChanged` entfernt den Schlüssel lokal). Der iCloud-Spiegel behält also `true`; das ist
  folgenlos, weil jedes Clear danach wieder gewinnt und alle anderen Tests das Flag per Argument
  setzen.
- **Onboarding-Schritte und Labels** (de.lproj, Szenario pinnt `de`): 0 „Loslegen“; 1 Titel „Wie
  heißt du?“, Feld-Platzhalter „Z.B. Johannes“, Knopf „Weiter“ (deaktiviert bei leerem Namen);
  2 „Wo kaufst du ein?“, Knopf „Weiter“, Land vorbelegt aus der Locale (Scheme: `DE`); 3 „Deine
  Läden“, Knopf „Alle auswählen“ / „Auswahl aufheben“ (hartkodiert), Zeilen aus `Store.presets(for:
  "DE")` (Lidl, Edeka, Rewe, Aldi, DM, …), Knopf „Einkaufen starten“; 4 „So funktioniert Restock“
  (hartkodiert), Knopf „Los geht's!“ (hartkodiert). `finishOnboarding()` legt alle Preset-Läden an,
  `isActive` = ausgewählt; die Startseite zeigt nur aktive Läden (`@Query` mit `isActive`). Ladenkachel
  heißt `<Name>, …` (Muster der Bestandstests: `label BEGINSWITH "Lidl,"`). Der gewählte Name steht
  danach in Einstellungen → Profil im Feld „Dein Name“.
- **Paywall-Auslöser:** fork.knife und chart.bar sind `Button { Image(systemName:) }` und tragen den
  SF-Symbol-Namen als Identifier (`app.buttons["fork.knife"]`, Muster in `RestockUITests`); das
  Zahnrad ist `gearshape`. Funktionsnamen: „den Rezeptplan“, „die Ausgaben-Analyse“, „alle
  Pro-Features“. Titelzeile der Paywall: „Schalte \(feature) und alle weiteren\nPro-Features frei.“
  (Zeilenumbruch im Label, deshalb nur auf Teilstrings prüfen). Weitere Elemente: Kopf „Restock Pro“,
  „Schließen“ (Navigationsleiste), „Käufe wiederherstellen“, Kaufknopf „Jetzt freischalten…“.
- **Sperre hängt an `hasPremiumAccess`:** `developerMode` ODER gekauftes Produkt ODER (DEBUG)
  `-premiumForScreenshots`. Die Paywall-Tests setzen `-developerMode NO` (Argument-Domain, überlagert
  einen persistierten Wert) und kein `-premiumForScreenshots`; ein gekauftes Produkt gibt es im
  Simulator ohne StoreKit-Konfiguration nicht.
- **Dev-Passwort:** `DevPasswordSheet` ist ein `private struct`; die Prüfung steckt in
  `private func verify()` (SHA256 des UTF-8-Eingabetextes als Kleinbuchstaben-Hex gegen
  `devPasswordHash`). Falsch: `showError = true`, `input = ""`, Sheet bleibt. Richtig: `onUnlock()`
  (setzt `developerMode`, schließt das Sheet). Sheet-Elemente: Titel „Developer Mode“, Meldung
  „Falsches Passwort“, `SecureField` „Passwort“, „Abbrechen“, „Entsperren“ (deaktiviert bei leerer
  Eingabe). Die Tipps zählen innerhalb von höchstens 2 s Abstand; der fünfte öffnet das Sheet.

### Onboarding (Klasse `OnboardingUITests`)

Start: `-clearOnboardingForUITests` (und sonst nichts, insbesondere kein `-hasCompletedOnboarding`),
über `UITestLaunch.start(app, expecting: app.buttons["Loslegen"])`. Das Clear entfernt Läden, Artikel,
`hasCompletedOnboarding`, `selectedCountry` und den Anzeigenamen.

**Test O1 `testOnboardingWalkthroughCreatesChosenStoresAndName`**

1. „Loslegen“ antippbar, antippen.
2. Schritt Name: Titel „Wie heißt du?“; „Weiter“ ist deaktiviert (`isEnabled == false`), solange das
   Feld leer ist. Feld antippen, auf Tastaturfokus warten (`hasKeyboardFocus`, Muster der Bestands-
   tests), „Testperson“ tippen, „Weiter“ wird aktiv, antippen.
3. Schritt Land: Titel „Wo kaufst du ein?“, „Weiter“ antippen (Standardland bleibt, **kein**
   Landwechsel, siehe Risiken zu `selectedCountry`).
4. Schritt Läden: Titel „Deine Läden“. „Alle auswählen“ antippen, der Knopf heißt jetzt „Auswahl
   aufheben“; erneut antippen, er heißt wieder „Alle auswählen“ (Auswahl leer). Dann die Zeilen
   „Lidl“ und „Rewe“ antippen (Edeka und DM bleiben unberührt). „Einkaufen starten“ antippen.
5. Schritt Tutorial: „So funktioniert Restock“ sichtbar, „Los geht's!“ antippen.
6. Startseite: Kacheln `Lidl,` und `Rewe,` antippbar (`waitUntilHittable`); Kacheln `Edeka,` und `DM,`
   existieren **nicht**.
7. Name angekommen: Zahnrad → Einstellungen → Feld „Dein Name“ hat den Wert „Testperson“.
8. Neustart-Teil: App beenden, ohne jedes Launch-Argument neu starten. Es erscheint kein „Loslegen“,
   die Kachel `Lidl,` ist antippbar. (Beweist, dass `hasCompletedOnboarding` wirklich in der
   App-Domain steht und das Onboarding nicht wiederkehrt. Ein Start mit `-hasCompletedOnboarding YES`
   würde das nicht beweisen, deshalb ohne Argument.)

**Aufräumen:** `tearDown()` startet die App einmal mit
`-hasCompletedOnboarding YES -clearOnboardingForUITests` und beendet sie. Danach gibt es keine Läden,
kein gespeichertes `hasCompletedOnboarding`/`selectedCountry` und keinen Anzeigenamen. Das Argument
`-hasCompletedOnboarding YES` im tearDown hält den Aufräumstart auf der Startseite statt im
Onboarding; es liegt nur in der Argument-Domain und persistiert nicht.

### Paywall-Sperre (Klasse `PaywallUITests`)

Start für P1–P3 und P5: `-hasCompletedOnboarding YES -developerMode NO`, über
`UITestLaunch.start(app, expecting: app.buttons["fork.knife"])`. Ein Start ohne Launch-Argumente (#105)
zeigte das Onboarding statt der Startseite; die Gegenprobe im Helfer fängt das (ein Neustart).
Es wird nichts gesät und nichts persistiert (kein Kauf, kein Passwort-Erfolg), daher braucht die
Klasse **kein** Aufräumen im tearDown. Warten nur über `UITestWait` (`waitUntilHittable`,
`waitForLabel(contains:)`) und `waitForExistence(timeout: UITestWait.defaultTimeout)`.

Gemeinsame Prüfung „Paywall steht“ (Hilfsfunktion): Der Kopf „Restock Pro“ existiert; die Titelzeile
enthält „Schalte \(feature)“ und „Pro-Features frei“; „Käufe wiederherstellen“ existiert; ein Knopf mit
Label `BEGINSWITH "Jetzt freischalten"` existiert. **Nur Existenz, kein Tipp** auf Kaufen oder
Wiederherstellen (offene Grenze).

- **P1 `testRecipePlanLockedOpensPaywall`:** fork.knife antippen → Paywall mit „Schalte den
  Rezeptplan“. Der Menüplan ist **nicht** geöffnet (`app.buttons["Tag hinzufügen"]` existiert nicht).
  „Schließen“ antippen → Paywall weg (Kopf „Restock Pro“ existiert nicht mehr), fork.knife wieder
  antippbar.
- **P2 `testExpensesAnalysisLockedOpensPaywall`:** chart.bar antippen → Paywall mit „Schalte die
  Ausgaben-Analyse“; „Schließen“ schließt, chart.bar wieder antippbar.
- **P3 `testSettingsProRowOpensPaywall`:** Zahnrad → Einstellungen. Die Zeile „Restock Pro
  freischalten“ (nach Wischen, Muster `statsLink` in `ReceiptResolutionStatsUITests`, max. 8 Wischer)
  antippen → Paywall mit „Schalte alle Pro-Features“. Die Zeile „Pro aktiv“ existiert nicht.
  „Schließen“ → Einstellungen wieder sichtbar.
- **P4 `testPremiumAccessOpensMenuPlanWithoutPaywall` (Gegenprobe):** Start mit
  `-hasCompletedOnboarding YES -developerMode NO -premiumForScreenshots -clearMenuPlanForUITests`
  (das Clear macht „Tag hinzufügen“ deterministisch sichtbar; es schreibt nichts außer dem Löschen).
  fork.knife antippen → „Tag hinzufügen“ existiert, der Kopf „Restock Pro“ existiert **nicht**.
  Beweist, dass P1 an der Sperre scheitert und nicht an einem kaputten Knopf, und dass der Test die
  Sperre wirklich von ihrer Aufhebung unterscheidet.
- **P5 `testWrongDevPasswordShowsErrorAndKeepsSheetOpen`:** Zahnrad → Einstellungen, zur Zeile
  „Version“ wischen. Fünf Tipps mit **einer** aufgelösten Koordinate
  (`row.coordinate(withNormalizedOffset:)`), damit keine Einzelabfrage das 2-s-Fenster sprengt. Erscheint
  das Sheet („Developer Mode“) nicht binnen `defaultTimeout`, wird nach 2,5 s Pause (Zähler verfällt)
  **einmal** wiederholt. Dann: Feld „Passwort“ antippen, Fokus abwarten, „falsch“ tippen, „Entsperren“
  antippen → „Falsches Passwort“ erscheint, das Sheet „Developer Mode“ ist **weiter offen** (ein
  fälschlich akzeptiertes Passwort würde `onUnlock()` aufrufen und das Sheet schließen), „Entsperren“ ist
  wieder deaktiviert (Eingabe geleert). „Abbrechen“ → Sheet weg, „Restock Pro freischalten“ weiter
  vorhanden. Der Test tippt **nie** das echte Passwort und kennt es nicht.

## Dev-Passwort: Entscheidung Richtig-Pfad

> Geschlossen durch #145 Durchgang 1 (2026-10-15): DEBUG-Hash-Überschreibung (`-devPasswordHashForUITests`) statt `matches(input:hash:)`; der Richtig-Pfad läuft als UI-Test. Siehe `test-145-durchgang-1-dev-passwort.md`.

Geprüft wurde, ob der Richtig-Pfad über eine reine Funktion `matches(input:hash:)` mit Unit-Test
abgedeckt werden soll. Befund im Code: Der Produktcode wäre klein (<15 Zeilen: ein internes `enum`
auf Dateiebene, `verify()` ruft es auf). **Trotzdem entschieden: nicht in diesem Durchgang, offene
Grenze.** Gründe:

1. Der Unit-Test würde nur die Hash-Formel prüfen (SHA256, Kleinbuchstaben-Hex) gegen einen Testhash. Die
   Verdrahtung, die im Ernstfall brechen würde (`onUnlock` → `developerMode = true` → Sheet schließt),
   bliebe ungeprüft. Der Nutzen ist geringer, als „Richtig-Pfad geprüft“ klingt.
2. Es wäre eine sechste Datei (`RestockTests/…`, plus pbxproj-Eintrag im Unit-Target) und eine Änderung
   an einer sicherheitsnahen Stelle ohne Produktnutzen — gegen das Dateilimit und die Regel „keine
   Seiteneffekte außerhalb des Tickets“.
3. Der Falsch-Pfad (Fehlermeldung, Eingabe leeren, Sheet bleibt) ist der, bei dem ein Fehler das
   Produkt am ehesten stillschweigend öffnet; er ist über die echte Oberfläche abgedeckt.

Die bessere Variante, falls der Richtig-Pfad später doch gewollt ist (Folgeticket): ein
`#if DEBUG`-Argument, das den Vergleichshash überschreibt (`-devPasswordHashForUITests <sha256>`).
Dann ließe sich die **ganze Kette** mit einem Test-Passwort fahren (Tipp, Sheet, Eingabe, `developerMode`,
Sheet schließt, „Pro aktiv“) — mit Aufräumen von `developerMode` und ohne das echte Passwort zu kennen.
Das kippt die Entscheidung „Produktcode des Dev-Passworts bleibt unverändert“ und braucht das
Aufräum-Argument für `developerMode`; deshalb nicht hier.

## Acceptance Criteria

- AC-1: Das Onboarding läuft in der App vom ersten Schritt bis zur Startseite durch: „Loslegen“ →
  Name (mit deaktiviertem „Weiter“ bei leerem Feld) → Land → Läden → Tutorial („Los geht's!“) →
  Startseite (Test O1). Nutzen: Ein neuer Nutzer kommt nachweislich in die App; bisher hat das nie
  ein Test gesehen.
- AC-2: Nach dem Onboarding stehen genau die gewählten Läden („Lidl“, „Rewe“) als Kacheln auf der
  Startseite; nicht gewählte Läden („Edeka“, „DM“) stehen dort nicht. „Alle auswählen“ ↔ „Auswahl
  aufheben“ schaltet die Beschriftung um (Test O1).
- AC-3: Der im Onboarding eingegebene Name steht danach in Einstellungen → Profil im Feld „Dein Name“
  (Test O1).
- AC-4: Nach einem Neustart ohne jedes Launch-Argument erscheint das Onboarding nicht wieder; die
  Startseite mit den gewählten Läden steht (Test O1, Neustart-Teil). Der Test startet das Onboarding
  ohne `-hasCompletedOnboarding`-Argument (Begründung: Argument-Domain, siehe Verhalten).
- AC-5: Ohne Premium öffnen fork.knife, chart.bar und die Einstellungszeile „Restock Pro freischalten“
  die Paywall mit dem jeweils passenden Funktionsnamen („den Rezeptplan“, „die Ausgaben-Analyse“,
  „alle Pro-Features“); die Funktion selbst (Menüplan) öffnet sich nicht (Tests P1–P3). „Schließen“
  schließt die Paywall; die Startseite bzw. Einstellungen sind wieder bedienbar.
- AC-6: Die Paywall zeigt „Käufe wiederherstellen“ und einen Kaufknopf („Jetzt freischalten…“) — als
  Existenzprüfung. Weder Kaufen noch Wiederherstellen noch die Release-Fehlermeldung werden bedient
  (offene Grenze, siehe unten).
- AC-7: Gegenprobe: Mit `-premiumForScreenshots` öffnet fork.knife den Menüplan („Tag hinzufügen“)
  und **keine** Paywall (Test P4). Nutzen: P1 ist rot, wenn die Sperre fehlt, und grün nur, weil sie
  wirkt.
- AC-8: Dev-Passwort Falsch-Pfad: Fünf Tipps auf „Version“ öffnen das Sheet „Developer Mode“; ein
  falsches Passwort zeigt „Falsches Passwort“, leert das Feld („Entsperren“ wieder deaktiviert) und
  lässt das Sheet offen; „Abbrechen“ schließt es (Test P5). Der Test kennt das echte Passwort nicht.
- AC-9: Echter Weg statt Nachbau: Alle Tests bedienen die sichtbaren Elemente der App (Beschriftungen,
  Identifier `fork.knife`/`chart.bar`/`gearshape`). Weder das Onboarding-Flag, noch Läden, noch Name,
  noch Premium-Status werden vom Test von Hand gesetzt; einzig erlaubt sind das Löschen des Ausgangs-
  zustands (`-clearOnboardingForUITests`) und die Launch-Argumente `-developerMode NO` /
  `-premiumForScreenshots` (Letzteres nur in der Gegenprobe).
- AC-10: Aufräumen: `OnboardingUITests.tearDown()` hinterlässt keine Läden, kein gespeichertes
  `hasCompletedOnboarding`/`selectedCountry` und keinen Anzeigenamen. `PaywallUITests` schreibt
  nichts Dauerhaftes. Nachweis: Die Bestandssuiten (insbesondere `QuickAddAssignmentUITests`,
  `ReplenishmentUITests`, `RestockUITests`) laufen im gemeinsamen Lauf mit den neuen Klassen grün; ein
  Folgetest sieht frische Läden ohne Rest aus dem Onboarding. Der Lauf zählt: „Executed 0 tests“ oder
  ein Abbruch ist kein Grün.
- AC-11: Produktcode: `-clearOnboardingForUITests` existiert ausschließlich unter `#if DEBUG`
  (Release-Build enthält keinen Verweis darauf; nachgewiesen durch Release-Build und Suche im Diff).
  `OnboardingView`, `OnboardingGate`, `PaywallView`, `PremiumService`, `SettingsView`
  bleiben im Diff unverändert; kein neuer `@AppStorage`-Schlüssel, keine `Info.plist`-Änderung, keine
  Scheme-Änderung.
- AC-14: Paywall-Text (Nachtrag nach RED): Aus fork.knife und chart.bar zeigt die Paywall den
  passenden Funktionsnamen schon beim ersten Öffnen und bei jedem weiteren („Schalte den Rezeptplan …“,
  „Schalte die Ausgaben-Analyse …“), nicht „dieses Feature“. Nachweis: P1 und P2 rot vor, grün nach
  der Korrektur in `HomeView`; im Diff ist nur die Paywall-Darstellung dort geändert.
- AC-12: Umfang: ≤ 5 Dateien (geplant 5 mit `HomeView`), ca. +275 LoC; keine Änderung an sichtbaren Texten außer dem Funktionsnamen in der Paywall (AC-14) und keine am
  Layout. Überschreitung von ±250 LoC wird vor dem Weiterbau gemeldet.
- AC-13: Offene Grenzen sind in Spec, Testkommentar (Kopf beider Klassen) und Ticketkommentar benannt:
  Kauf, Wiederherstellen und Release-Fehlermeldung der Paywall (DEBUG-Zweig `dismiss()` ist nicht der
  Release-Weg; `Restock.storekit` nicht im Scheme), Dev-Passwort Richtig-Pfad, `StoreSetupView` folgt
  in Durchgang 6. Keine Zusage dieses Durchgangs lautet „Paywall/Premium geprüft“ ohne diese
  Einschränkung.

## Tests

| # | Testfall | Datei | Art | Prüft |
|---|----------|-------|-----|-------|
| T1 | `testOnboardingWalkthroughCreatesChosenStoresAndName` (O1, inkl. Neustart) | `OnboardingUITests` | UI | AC-1, 2, 3, 4, 9 |
| T2 | `testRecipePlanLockedOpensPaywall` (P1) | `PaywallUITests` | UI | AC-5, 6, 9, 14 |
| T3 | `testExpensesAnalysisLockedOpensPaywall` (P2) | `PaywallUITests` | UI | AC-5, 6, 14 |
| T4 | `testSettingsProRowOpensPaywall` (P3) | `PaywallUITests` | UI | AC-5, 6 |
| T5 | `testPremiumAccessOpensMenuPlanWithoutPaywall` (P4, Gegenprobe) | `PaywallUITests` | UI | AC-7 |
| T6 | `testWrongDevPasswordShowsErrorAndKeepsSheetOpen` (P5) | `PaywallUITests` | UI | AC-8, 9 |
| T7 | Release-Build, `#if DEBUG`-Prüfung und Suche im Diff | — | Build | AC-11 |
| T8 | Bestandssuiten im gemeinsamen Lauf mit den neuen Klassen | alle | UI+Unit | AC-10 |
| T9 | Wiederholung 3x (Stabilität, besonders T1 und T6) | neue Klassen | UI | AC-10 |
| T10 | Durchlauf im Simulator, Artefakt durch Werkzeug | — | durch Werkzeug | AC-1, 5, 13 |
| T11 | Diff-Nachweis: Dateizahl, LoC, unveränderte Produktdateien (Scope-Gate, `git diff --stat` gegen `origin/main`) | — | Diff | AC-11, 12 |

Start- und Warteregeln: Start über `UITestLaunch.start(_:expecting:)` (zweiter Start mit Messzeile bei
Fehlstart, #105); Warten über `UITestWait` (`waitUntilHittable`, `waitForLabel(contains:)`,
`defaultTimeout` 20 s) statt `expectation(for: isHittable…)` mit 5 s. Der Tastaturfokus nach `tap()`
wird wie in den Bestandstests per `hasKeyboardFocus` abgewartet, bevor `typeText` läuft. Szenario pinnt
`de`/`DE`; Simulator nie parallel, eigenes Testgerät Restock-Validate.

TDD: Beide Klassen werden vor dem DEBUG-Zweig geschrieben. RED: O1 scheitert, weil das Argument
unbekannt ist (kein Clear: das Flag aus einem früheren Lauf bzw. die Läden bleiben, Schritt 1
„Loslegen“ erscheint je nach Zustand nicht oder Läden sind bereits da). P1–P3 und P5 testen bestehendes
Verhalten und dürften sofort grün sein; der Nachweis, dass sie nicht leer laufen, sind die
Gegenprobe P4 sowie Mutationsproben im Nachweis: (a) die Sperre in `HomeView` kurz aushebeln → P1 muss
rot werden; (b) in `DevPasswordSheet.verify()` kurz jeden Hash akzeptieren → P5 muss rot werden. Beide
Änderungen werden vollständig zurückgenommen und stehen nicht im Endstand des Diffs.

## Risiken

- **Argument-Domain:** `-hasCompletedOnboarding NO` ist ungeeignet (siehe Verhalten) und wird nicht
  benutzt. Falls die Annahme über die Domain-Rangfolge in der Praxis anders ausfällt, ändert das nichts
  an O1, weil der Test das Argument ohnehin nicht braucht.
- **Zustandsrest zwischen Tests:** Das Onboarding legt Läden an, setzt Flag und Namen. Ohne Clear im
  tearDown färbt O1 alle Folgetests (Memory „UI-Test-Seeds müssen aufräumen“, #28). Der
  gemeinsame Lauf (AC-10) ist der Beweis; ein Einzellauf beweist es nicht.
- **iCloud-Spiegel (`CloudPreferencesSync`):** `hasCompletedOnboarding` und `selectedCountry` werden in
  den iCloud-Schlüsselwertspeicher gespiegelt. Das Clear gewinnt zum Startzeitpunkt (läuft nach
  `start()`). Ein spät eintreffender externer iCloud-Änderungsstoß (`iCloudChanged`) könnte das Flag
  im laufenden Test wieder setzen und das Onboarding unterbrechen; im Simulator ohne Konto tritt das
  nicht auf. Der Test wählt deshalb **kein anderes Land** (sonst bliebe ein abweichendes
  `selectedCountry` im Spiegel und käme bei jedem Folgestart zurück). Bleibt O1 gelegentlich auf
  Schritt 1 stehen, ist das der erste Verdacht und Teil der Protokollzeile des Fehlstarts.
- **Fünf Tipps in 2 s (P5):** Einzelne XCUITest-Abfragen dauern auf dem Runner sporadisch 4–14 s. Die
  Koordinaten-Tipps lösen das Element nur einmal auf; die einmalige Wiederholung nach 2,5 s fängt einen
  verschluckten Tipp. Ob das auf dem CI-Runner stabil ist, zeigt erst der 3x-Lauf (T9); bei Instabilität
  ist P5 das Kürzungsziel (Ticketkommentar statt stiller Lockerung).
- **Tastatur/SecureField:** `typeText` auf dem `SecureField` setzt Fokus voraus; Fokus abwarten.
  Simulator-Hardware-Tastatur wird nicht angenommen.
- **Texte:** Die Tests lesen deutsche Beschriftungen („Loslegen“, „Alle auswählen“, „Los geht's!“,
  „Falsches Passwort“); Textänderungen brechen sie (Hinweis in `CLAUDE.md` gilt).
- **Systemdialoge:** Der Code zeigt auf der Startseite keine automatische Berechtigungsabfrage
  (`requestPermission` nur im Einstellungs-Schalter). Sollte nach dem Onboarding doch ein Dialog
  erscheinen, wäre das ein neuer Befund und kein Testfehler.
- **Stabile Testdaten:** Preset-Zeilen „Lidl“/„Rewe“ stammen aus `Store.presets(for: "DE")`; ändert
  sich diese Liste, bricht O1 sichtbar.

## Alternativen

- **(a) `Restock.storekit` ins Scheme verdrahten:** ermöglicht Kauf und Wiederherstellen im Simulator.
  Verworfen für diesen Durchgang: globale Scheme-Änderung mit Wirkung auf alle Testläufe; Forenberichte
  nennen unter XCTest `StoreKitError.Unknown`; kippt die Entscheidung „Scheme unverändert“. Eigenes
  Folgeticket (Kauf/Wiederherstellen), dort mit der Frage, ob ein Kauf unter XCUITest überhaupt trägt.
  (Quellen der Analyse: Apple `SKTestSession`-Dokumentation, Apple-Entwicklerforum Thread 736989.)
- **(b) Onboarding-Logik (`finishOnboarding`) in eine Funktion ziehen und per Unit-Test prüfen:** billiger,
  aber prüft nur die Funktion, nicht, dass der Nutzer durch die fünf Schritte kommt, dass das Flag in der
  App-Domain landet und der Gate umschaltet (Lehre vom 2026-09-27: nur der echte Durchlauf prüft, ob die
  Kette schließt). Nur als spätere Ergänzung; würde die Entscheidung „Onboarding-Produktcode bleibt
  unverändert“ kippen.
- **(c) Punkt 7 vertagen, stattdessen 5/6 vor Release:** widerspricht dem Beschluss vom 2026-10-12
  (Release 1.0: Punkt 7 vorher nötig).
- **(d) Dev-Passwort Richtig-Pfad per `matches(input:hash:)` + Unit-Test:** siehe Abschnitt
  „Dev-Passwort“; verworfen, weil er nur die Hash-Formel prüft und eine sechste Datei kostet. Kippt
  bei Bedarf die Entscheidung „SettingsView bleibt unverändert“. Bessere Variante: DEBUG-Hash-Überschreibung
  für die ganze Kette (Folgeticket).
- **(e) Onboarding mit `-hasCompletedOnboarding NO` statt Clear:** verworfen, weil die Argument-Domain
  das Schreiben von `true` durch die App überlagert und der Test auf dem letzten Schritt stehenbliebe.
- **(f) Clear auch im iCloud-Schlüsselwertspeicher:** verworfen, weil es über ein angemeldetes Konto auf
  echte Geräte durchschlagen könnte (`iCloudChanged` entfernt dort den Schlüssel lokal).
- **Ohne Modell:** nichts hier braucht ein Sprachmodell; reine Oberflächen- und Regelprüfung.
- Gekippte frühere Entscheidung: keine. (Die Alternativen a, b, d würden jeweils die genannte kippen.)

**Entscheidung:** Echter UI-Durchlauf mit DEBUG-Clear für das Onboarding, Sperre an den drei Auslösern
mit Gegenprobe, Dev-Passwort nur Falsch-Pfad, Kauf/Wiederherstellen/Release-Meldung/Richtig-Pfad als
offene Grenze, `StoreSetupView` in Durchgang 6.

## Offene Punkte

- Keine für den PO (technische Entscheidungen).
- Offene Grenze (gilt für jede Zusage dieses Durchgangs): Kauf, Wiederherstellen und Release-Fehlermeldung
  der Paywall sind nicht automatisiert prüfbar; der DEBUG-Zweig `dismiss()` ist nicht der Release-Weg und
  `Restock.storekit` steht in keinem Scheme. Dev-Passwort Richtig-Pfad ungeprüft. `StoreSetupView` folgt
  in Durchgang 6.
- Folgetickets im Ticketkommentar von #98 festhalten (gebündelt nach Ziel): (1) Kauf/Wiederherstellen im
  Simulator (storekit im Scheme, Machbarkeit unter XCUITest), (2) Dev-Passwort Richtig-Pfad per DEBUG-
  Hash-Überschreibung.
- Nach Abschluss: Verweis auf `-clearOnboardingForUITests` in `CLAUDE.md` (Abschnitt Build/UI-Tests),
  falls das Limit es erlaubt, sonst im Folgedurchgang.
