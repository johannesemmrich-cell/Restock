# Adversary Dialog — test-98-durchgang-5-onboarding-paywall
Spec: docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md
Datum: 2026-10-12 16:07

## Checkliste
- [x] AC-1: Das Onboarding läuft in der App vom ersten Schritt bis zur Startseite durch: „Loslegen“ → Name (mit deaktiviertem „Weiter“ bei leerem Feld) → Land → Läden → Tutorial („Los geht's!“) → Startseite (Test O1). Nutzen: Ein neuer Nutzer kommt nachweislich in die App; bisher hat das nie ein Test gesehen.
- [x] AC-2: Nach dem Onboarding stehen genau die gewählten Läden („Lidl“, „Rewe“) als Kacheln auf der Startseite; nicht gewählte Läden („Edeka“, „DM“) stehen dort nicht. „Alle auswählen“ ↔ „Auswahl aufheben“ schaltet die Beschriftung um (Test O1).
- [x] AC-3: Der im Onboarding eingegebene Name steht danach in Einstellungen → Profil im Feld „Dein Name“ (Test O1).
- [x] AC-4: Nach einem Neustart ohne jedes Launch-Argument erscheint das Onboarding nicht wieder; die Startseite mit den gewählten Läden steht (Test O1, Neustart-Teil). Der Test startet das Onboarding ohne `-hasCompletedOnboarding`-Argument (Begründung: Argument-Domain, siehe Verhalten).
- [x] AC-5: Ohne Premium öffnen fork.knife, chart.bar und die Einstellungszeile „Restock Pro freischalten“ die Paywall mit dem jeweils passenden Funktionsnamen („den Rezeptplan“, „die Ausgaben-Analyse“, „alle Pro-Features“); die Funktion selbst (Menüplan) öffnet sich nicht (Tests P1–P3). „Schließen“ schließt die Paywall; die Startseite bzw. Einstellungen sind wieder bedienbar.
- [x] AC-6: Die Paywall zeigt „Käufe wiederherstellen“ und einen Kaufknopf („Jetzt freischalten…“) — als Existenzprüfung. Weder Kaufen noch Wiederherstellen noch die Release-Fehlermeldung werden bedient (offene Grenze, siehe unten).
- [x] AC-7: Gegenprobe: Mit `-premiumForScreenshots` öffnet fork.knife den Menüplan („Tag hinzufügen“) und **keine** Paywall (Test P4). Nutzen: P1 ist rot, wenn die Sperre fehlt, und grün nur, weil sie wirkt.
- [x] AC-8: Dev-Passwort Falsch-Pfad: Fünf Tipps auf „Version“ öffnen das Sheet „Developer Mode“; ein falsches Passwort zeigt „Falsches Passwort“, leert das Feld („Entsperren“ wieder deaktiviert) und lässt das Sheet offen; „Abbrechen“ schließt es (Test P5). Der Test kennt das echte Passwort nicht.
- [x] AC-9: Echter Weg statt Nachbau: Alle Tests bedienen die sichtbaren Elemente der App (Beschriftungen, Identifier `fork.knife`/`chart.bar`/`gearshape`). Weder das Onboarding-Flag, noch Läden, noch Name, noch Premium-Status werden vom Test von Hand gesetzt; einzig erlaubt sind das Löschen des Ausgangs- zustands (`-clearOnboardingForUITests`) und die Launch-Argumente `-developerMode NO` / `-premiumForScreenshots` (Letzteres nur in der Gegenprobe).
- [x] AC-10: Aufräumen: `OnboardingUITests.tearDown()` hinterlässt keine Läden, kein gespeichertes `hasCompletedOnboarding`/`selectedCountry` und keinen Anzeigenamen. `PaywallUITests` schreibt nichts Dauerhaftes. Nachweis: Die Bestandssuiten (insbesondere `QuickAddAssignmentUITests`, `ReplenishmentUITests`, `RestockUITests`) laufen im gemeinsamen Lauf mit den neuen Klassen grün; ein Folgetest sieht frische Läden ohne Rest aus dem Onboarding. Der Lauf zählt: „Executed 0 tests“ oder ein Abbruch ist kein Grün.
- [x] AC-11: Produktcode: `-clearOnboardingForUITests` existiert ausschließlich unter `#if DEBUG` (Release-Build enthält keinen Verweis darauf; nachgewiesen durch Release-Build und Suche im Diff). `OnboardingView`, `OnboardingGate`, `PaywallView`, `PremiumService`, `SettingsView` bleiben im Diff unverändert; kein neuer `@AppStorage`-Schlüssel, keine `Info.plist`-Änderung, keine Scheme-Änderung.
- [x] AC-14: Paywall-Text (Nachtrag nach RED): Aus fork.knife und chart.bar zeigt die Paywall den passenden Funktionsnamen schon beim ersten Öffnen und bei jedem weiteren („Schalte den Rezeptplan …“, „Schalte die Ausgaben-Analyse …“), nicht „dieses Feature“. Nachweis: P1 und P2 rot vor, grün nach der Korrektur in `HomeView`; im Diff ist nur die Paywall-Darstellung dort geändert.
- [x] AC-12: Umfang: ≤ 5 Dateien (geplant 5 mit `HomeView`), ca. +275 LoC; keine Änderung an sichtbaren Texten außer dem Funktionsnamen in der Paywall (AC-14) und keine am Layout. Überschreitung von ±250 LoC wird vor dem Weiterbau gemeldet.
- [x] AC-13: Offene Grenzen sind in Spec, Testkommentar (Kopf beider Klassen) und Ticketkommentar benannt: Kauf, Wiederherstellen und Release-Fehlermeldung der Paywall (DEBUG-Zweig `dismiss()` ist nicht der Release-Weg; `Restock.storekit` nicht im Scheme), Dev-Passwort Richtig-Pfad, `StoreSetupView` folgt in Durchgang 6. Keine Zusage dieses Durchgangs lautet „Paywall/Premium geprüft“ ohne diese Einschränkung.

## Dialog

### Runde 1
**Adversary:** Annahme: die Tests sind Scheinbeweise. Geprüft: Ausgangszustand, Aufräumen, Titelprüfung, DEBUG-Grenze, Umfang, unveränderte Dateien, Mutationen, eigener Wiederholungslauf.

Eigener Lauf (nicht parallel, nur Simulator 8F696920): OnboardingUITests/testOnboardingWalkthroughCreatesChosenStoresAndName und PaywallUITests/testExpensesAnalysisLockedOpensPaywall: 2 Tests, 0 Fehler, TEST SUCCEEDED (docs/artifacts/test-98-durchgang-5-onboarding-paywall/adversary-test-output.txt).
Gesamtlauf test-green-output.txt: 90 Tests, 1 übersprungen (ReceiptShareExtensionTests, Bestandstest, braucht Skript; unabhängig von diesem Durchgang), 0 Fehler; 89 laufende Tests grün, also kein Null-Test-Lauf. test-wiederholung-3x.txt: 18 Läufe grün.
Umfang: Diff-Zahlen gegen 26227bf: pbxproj +8, OnboardingUITests +100, PaywallUITests +148, SmartCartApp +15, HomeView +12/-7 = 5 Dateien, 290 Zeilen. Das 250er-Limit ist überschritten, die Spec nennt ca. 275; die Meldung im PO-Briefing ist laut Auftrag erfolgt (von hier nicht prüfbar).
Unverändert: der Diff gegen 26227bf enthält keine Zeile in Views/Onboarding, Views/Settings, Services (PremiumService), Info.plist, xcshareddata (Scheme). PaywallView unverändert.

**Implementierer:** (keine Rückmeldung, Isolation)

- AC-1 PROVEN. Test O1 geht Loslegen, Name, Land, Läden, Tutorial, Startseite durch und prüft Weiter bei leerem Feld deaktiviert.
Code reference: RestockUITests/OnboardingUITests.swift:44
Code reference: RestockUITests/OnboardingUITests.swift:51
Code reference: RestockUITests/OnboardingUITests.swift:78
- AC-2 PROVEN. Kacheln Lidl/Rewe vorhanden, Edeka/DM nicht; Beschriftungswechsel Alle auswählen/Auswahl aufheben geprüft.
Code reference: RestockUITests/OnboardingUITests.swift:68
Code reference: RestockUITests/OnboardingUITests.swift:81
Code reference: RestockUITests/OnboardingUITests.swift:83
- AC-3 PROVEN. Feld „Dein Name“ hat Wert „Testperson“ (Wertvergleich, nicht nur Existenz).
Code reference: RestockUITests/OnboardingUITests.swift:90
- AC-4 PROVEN. Neustart mit frischer XCUIApplication ohne Argumente, Kachel Lidl steht, Loslegen fehlt. Zeile 43 setzt nur das Clear-Argument, das Flag stammt aus der App.
Code reference: RestockUITests/OnboardingUITests.swift:43
Code reference: RestockUITests/OnboardingUITests.swift:96
- AC-5 PROVEN. Alle drei Auslöser prüfen den Titel mit Funktionsname über CONTAINS „Schalte <feature>“ und „Pro-Features frei“ (kein reiner Existenztest), Menüplan öffnet sich nicht, „Schließen“ stellt die Startseite wieder her. Mutation A (Sperre aus) macht testRecipePlanLockedOpensPaywall rot (mutation-a-sperre-aus.txt), Rückname grün (mutation-nach-rueckname.txt).
Code reference: RestockUITests/PaywallUITests.swift:41
Code reference: RestockUITests/PaywallUITests.swift:72
Code reference: SmartCart/Views/Home/HomeView.swift:1399
Code reference: SmartCart/Views/Home/HomeView.swift:1410
- AC-6 PROVEN (als Existenzprüfung, wie die Spec verlangt). „Käufe wiederherstellen“ und „Jetzt freischalten…“ nur per exists, kein Tipp.
Code reference: RestockUITests/PaywallUITests.swift:47
- AC-7 PROVEN. Gegenprobe mit -premiumForScreenshots: „Tag hinzufügen“ erscheint, „Restock Pro“ nicht. Das Argument wird in PremiumService unter #if DEBUG gelesen (unverändert).
Code reference: RestockUITests/PaywallUITests.swift:104
Code reference: RestockUITests/PaywallUITests.swift:109
- AC-8 PROVEN. Falsch-Pfad: fünf Tipps, Sheet, Fehlermeldung, Feld geleert (Entsperren deaktiviert), Sheet bleibt, Abbrechen schließt. Mutation B (Passwort offen) rot (mutation-b-passwort-offen.txt). Das richtige Passwort kommt im Test nicht vor.
Code reference: RestockUITests/PaywallUITests.swift:130
Code reference: RestockUITests/PaywallUITests.swift:140
Code reference: RestockUITests/PaywallUITests.swift:142
- AC-9 PROVEN mit Vorbehalt (F002). Name, Läden, Premium-Status und Onboarding-Ergebnis entstehen über die Oberfläche bzw. den echten Pfad. Wörtlich weicht die Argumentliste ab, siehe F002.
Code reference: RestockUITests/PaywallUITests.swift:21
Code reference: RestockUITests/OnboardingUITests.swift:56
- AC-10 PROVEN. tearDown startet mit -clearOnboardingForUITests; die Funktion löscht Läden, Flag, Land und Namen; Folgesuiten im 90er-Gesamtlauf grün. PaywallUITests schreibt nichts Dauerhaftes (kein Passwort-Erfolg, kein Kauf).
Code reference: RestockUITests/OnboardingUITests.swift:23
Code reference: SmartCart/SmartCartApp.swift:471
Code reference: SmartCart/SmartCartApp.swift:475
- AC-11 PROVEN. Aufruf (SmartCartApp.swift:47) liegt im #if DEBUG-Block 28-48, die Funktion (471) im Block 164-711. Release-Binary: 0 Treffer (release-nachweis.txt, release-build-log.txt: BUILD SUCCEEDED). Keine neuen @AppStorage-Schlüssel im Diff.
Code reference: SmartCart/SmartCartApp.swift:47
Code reference: SmartCart/SmartCartApp.swift:28
- AC-14 PROVEN. PaywallRequest trägt den Namen mit (sheet(item:)), alte State-Variablen entfernt, keine Restverwendung von showPaywall/paywallFeature in HomeView. HomeView-Diff entspricht vor-probe.diff, nur Paywall-Darstellung. P1/P2 rot vor (test-paywall-titel.txt, test-red-output.txt), grün nach.
Code reference: SmartCart/Views/Home/HomeView.swift:23
Code reference: SmartCart/Views/Home/HomeView.swift:99
Code reference: SmartCart/Views/Home/HomeView.swift:204
- AC-12 PROVEN mit Vorbehalt. 5 Dateien, 290 Zeilen (Spec: ca. 275, Limit 250 überschritten, laut Auftrag gemeldet). Keine Textänderung außer Funktionsname, kein Layout.
Code reference: SmartCart/Views/Home/HomeView.swift:1399
- AC-13 PROVEN. Offene Grenzen stehen in der Spec (Zeile 47 ff., 279, 376) und in beiden Klassenkopfkommentaren. Die Suche nach „Paywall geprüft“/„Premium geprüft“ findet nur die Verneinung in der Spec (Zeile 282). Der Ticketkommentar von #98 ist von hier aus nicht prüfbar.
Code reference: RestockUITests/PaywallUITests.swift:9
Code reference: RestockUITests/OnboardingUITests.swift:11

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/PaywallUITests.swift:72
  Description: P1 und P2 öffnen die Paywall je nur einmal pro Kaltstart. Kein Test öffnet in einer Sitzung erst fork.knife, dann chart.bar.
  Spec requirement: AC-14 — Funktionsname „schon beim ersten Öffnen und bei jedem weiteren“
  Conflict: „Jedes weitere“ Öffnen ist nur strukturell durch sheet(item:) gestützt, nicht durch einen Test. Der Fehler „alter Wert beim ersten Öffnen“ ist abgedeckt.
  Remediation: Optional einen Test mit zwei Auslösern nacheinander im selben Start ergänzen.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: RestockUITests/PaywallUITests.swift:21
  Description: Die Paywall-Tests starten mit -hasCompletedOnboarding YES, die Gegenprobe zusätzlich mit -clearMenuPlanForUITests; OnboardingUITests.tearDown (Zeile 23) ebenfalls mit -hasCompletedOnboarding YES.
  Spec requirement: AC-9 — „einzig erlaubt“ sind -clearOnboardingForUITests, -developerMode NO, -premiumForScreenshots
  Conflict: Wörtlich steht die Liste enger als die Praxis. Der Sinn (der geprüfte Zustand wird nicht vorgetäuscht) bleibt gewahrt, weil das Onboarding in den Paywall-Tests nicht Prüfgegenstand ist.
  Remediation: Spec-Wortlaut von AC-9 um diese zwei Argumente ergänzen.

### Runde 2
**Adversary:** Zweiter Versuch gegen Scheinbeweise. (a) Läuft der Onboarding-Test auf einem stehengebliebenen Zustand? Nein: das Clear läuft als letzter DEBUG-Schritt in init, kein Seed legt danach Läden an; der Test erreicht die Schritte über Beschriftungen und Wartebedingungen. (b) Könnte ein Schutz offen sein, weil Mutationen nicht zurückgenommen wurden? HomeView.swift (Änderungszeit 15:59:41) entspricht nach der Rücknahme dem Stand in vor-probe.diff, mutation-nach-rueckname.txt ist danach grün, und der eigene Lauf ist grün. (c) Der iCloud-Schlüsselwertspeicher wird bewusst nicht geleert (Spec Alternative f), kein Mangel. (d) Der Dev-Passwort-Test nutzt Thread.sleep(2.5) als Pause für das Zählfenster, keinen Polling-Ersatz; bei verschlucktem Mehrfachtipp bricht er mit klarer Meldung ab. Ergebnis: kein weiterer Befund.

**Implementierer:** (keine Rückmeldung)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Relevante Schreibstelle: `hasCompletedOnboarding` wird in der App nur durch finishOnboarding() geschrieben, der Test setzt es im Onboarding-Durchlauf nicht von Hand; das Clear-Argument löscht es nur unter #if DEBUG (SmartCartApp.swift:475). Bedingung davor: Nutzer hat das Tutorial mit „Los geht's!“ beendet. Test für diesen Weg: testOnboardingWalkthroughCreatesChosenStoresAndName (Neustart-Teil).

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat die Prüfung bestanden.
Tests: 90 Gesamtlauf (89 bestanden, 0 Fehler, 1 übersprungen: Bestandstest ReceiptShareExtension, unabhängig); eigener Lauf 2/2 bestanden
Edge cases: geprüft; nur F001 und F002 (beide LOW)
Regressions: keine gefunden
Checklist: 14/14 Punkte bewiesen (AC-9 und AC-12 mit Vorbehalt)
Offene Grenzen (unverändert gültig): Kauf, Wiederherstellen, Release-Fehlermeldung der Paywall und Richtig-Pfad des Dev-Passworts sind nicht geprüft; StoreSetupView folgt in Durchgang 6. Umfang 290 Zeilen über dem 250er-Limit (gemeldet).

## Geprüfte Dateien

- sha256:921e835f6a4042fdfc64432b3092ebcaa0b9dc9c645f6d470dfc15c9a00c5bc7  RestockUITests/OnboardingUITests.swift
- sha256:3b6ef5a7f72d87684327f68a932fc1a7af3ae89ad45fd8e012f7932b93b5ad48  RestockUITests/PaywallUITests.swift
- sha256:dcdcdf2224f83763ce3e2a25ac75b91643963c445501ff9b8dfb51b743b24197  SmartCart/SmartCartApp.swift
- sha256:318af3772fa7b65764fdc4760f5fd184ea8d5ea79b9c2f490a93d06cf5c29848  SmartCart/Views/Home/HomeView.swift

## Prüfbasis

- base: 26227bff771d2c61148637245bff55539e0d6b6b
- blob:6f4df55bb0a9f170d9f2398ecfa835f758fad7ca  RestockUITests/OnboardingUITests.swift
- blob:27669c62a3b92bdb44932e0e6cb060c147019e0a  RestockUITests/PaywallUITests.swift
- blob:7ff45a5bd59d4f538b684fda865d1d68b26dfba1  SmartCart/SmartCartApp.swift
- blob:22d7d4cef5baf3d0289793bf39387638a442f6ff  SmartCart/Views/Home/HomeView.swift

## Geprüfte Dateien

- sha256:921e835f6a4042fdfc64432b3092ebcaa0b9dc9c645f6d470dfc15c9a00c5bc7  RestockUITests/OnboardingUITests.swift
- sha256:3b6ef5a7f72d87684327f68a932fc1a7af3ae89ad45fd8e012f7932b93b5ad48  RestockUITests/PaywallUITests.swift
- sha256:dcdcdf2224f83763ce3e2a25ac75b91643963c445501ff9b8dfb51b743b24197  SmartCart/SmartCartApp.swift
- sha256:318af3772fa7b65764fdc4760f5fd184ea8d5ea79b9c2f490a93d06cf5c29848  SmartCart/Views/Home/HomeView.swift

## Prüfbasis

- base: 26227bff771d2c61148637245bff55539e0d6b6b
- blob:6f4df55bb0a9f170d9f2398ecfa835f758fad7ca  RestockUITests/OnboardingUITests.swift
- blob:27669c62a3b92bdb44932e0e6cb060c147019e0a  RestockUITests/PaywallUITests.swift
- blob:7ff45a5bd59d4f538b684fda865d1d68b26dfba1  SmartCart/SmartCartApp.swift
- blob:22d7d4cef5baf3d0289793bf39387638a442f6ff  SmartCart/Views/Home/HomeView.swift
