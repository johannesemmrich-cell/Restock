# Adversary-Dialog: test-98-durchgang-2-banner-schnelleingabe (Spec docs/specs/ui-tests/replenishment-uitest.md)

### Runde 1

Release-Build (`-configuration Release`, generic iOS Simulator): BUILD SUCCEEDED. Seed/Clear vollstaendig unter `#if DEBUG`.

Finding:
  ID: F001
  Severity: HIGH
  Category: spec_violation
  Code reference: RestockUITests/ReplenishmentUITests.swift:96
  Description: `listRow` trifft auch die Vorschlags-Zelle "Vielleicht auch fällig" im Bannerladen; B5/B2 koennten bei kaputtem Produkt gruen sein.
  Spec requirement: AC-6 / AC-12 - Artikel stehen offen in der Liste; Tests pruefen echte Wirkung.
  Conflict: Mutation "addAll legt nur ersten Artikel an" waere gruen geblieben.
  Remediation: Abwesenheit von replenish.also.add.<Name> pruefen; Mutationsbeleg.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: SmartCart/SmartCartApp.swift:379
  Description: +326 Zeilen gegenueber a721bf0 (Test 258, Produktcode ~66).
  Spec requirement: AC-20 - +-250 LoC.
  Conflict: Limit ueberschritten.
  Remediation: PO-Freigabe dokumentieren oder straffen.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: SmartCart/Services/HabitService.swift:633
  Description: doneKey/dismissedKey/acceptedKey liegen in ReplenishmentKeyMigration, Spec nannte ReplenishmentFeedback.
  Spec requirement: AC-14
  Conflict: Spec-Fehler.
  Remediation: Spec an allen Stellen korrigieren.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Home/HomeView.swift:88
  Description: replenishmentCollapsed / storeReplenishmentCollapsed (StoreDetailView.swift:37) werden von Clear/Seed nicht zurueckgesetzt; eingeklappter Abschnitt macht Tests rot.
  Spec requirement: AC-14
  Conflict: Zustand ueberlebt den Test.
  Remediation: Schluessel in Seed/Clear entfernen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/ReplenishmentUITests.swift:255
  Description: Test N hatte keine Positiv-Gegenprobe, Abwesenheit allein.
  Spec requirement: AC-11
  Conflict: "nichts zu sehen" auch bei nicht geoeffneter Ansicht.
  Remediation: Vorher auf Navigationsleiste warten.

Runde-1-Verdict: AMBIGUOUS (Tendenz BROKEN). AC-17/18/19 offen (Phase /60-validate).

### Runde 2 (Beweise gelesen)

- F001: BEHOBEN. RestockUITests/ReplenishmentUITests.swift:137 (B2) und :178 (B5) warten auf `gone(app.buttons["replenish.also.add.<Name>"])`. Mutationsbeleg docs/artifacts/test-98-durchgang-2-banner-schnelleingabe/mutation-proofs.md: (a) addAll nur erster Artikel -> ROT; (b) addSingleDueItem ohne Artikel -> ROT an der neuen Pruefung; (c) Blocklist nicht gespeichert -> beide Neustart-Tests ROT; (d) Snooze nicht gespeichert -> beide ROT. b0 (nur context.insert entfernt) blieb gruen: plausibel, da ShoppingItem.init den Artikel ueber die Store-Relation implizit in den Kontext einfuegt; unwirksame Mutation, kein Testmangel, durch b ersetzt. Bewertung: AKZEPTIERT. Rest-Hinweis: Mutationen wurden per Kopie/SHA-1 zurueckgenommen; ich habe HabitService.swift ohne Diff und HomeView.swift mit nur 3 Identifier-Zeilen bestaetigt (git diff --stat).
- F002: AKZEPTIERT. PO-Freigabe 2026-10-03 laut Koordinator, in Spec vermerkt (Spec-Diff vorhanden). Ich kann die Freigabe selbst nicht verifizieren, nur den Spec-Vermerk.
- F003: AKZEPTIERT. grep auf `ReplenishmentFeedback` in der Spec: keine Treffer. Code nutzt ReplenishmentKeyMigration (SmartCartApp.swift:429).
- F004: AKZEPTIERT. SmartCartApp.swift:433 entfernt beide Collapsed-Schluessel in removeReplenishmentSeed (laeuft bei Seed und Clear).
- F005: AKZEPTIERT. RestockUITests/ReplenishmentUITests.swift:262 wartet auf navigationBars["Listenladen"].
- Endlauf test-green-output.txt (17:40, nach den Quelldatei-Aenderungen 17:11): 10 Tests, 0 Failures, TEST SUCCEEDED.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: SmartCart/SmartCartApp.swift:387
  Evidence: Seed legt nur 2 Laeden und 12 PurchaseRecords relativ zu Date() (12:00) an; keine Vorschlaege/Snoozes/Sperren; idempotent (removeReplenishmentSeed zuerst, Z. 420). 3 Kaeufe -> kein Wochentagsmodus (PurchaseRecord fixedWeekdays verlangt >=4).
  Status: CONFIRMED

Confirmation:
  AC: AC-2, AC-7, AC-12
  Code reference: RestockUITests/ReplenishmentUITests.swift:196
  Evidence: Banner/Abschnitt werden ueber echte Identifier replenish.* geprueft; gruener Lauf 10/10.
  Status: CONFIRMED

Confirmation:
  AC: AC-3, AC-6
  Code reference: RestockUITests/ReplenishmentUITests.swift:137
  Evidence: Zusatzpruefung der Vorschlagszeile; Mutationen a und b rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, AC-5, AC-9, AC-10
  Code reference: RestockUITests/ReplenishmentUITests.swift:248
  Evidence: Neustart ohne Seed, Gegenproben vorhanden; Mutationen c und d rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: RestockUITests/ReplenishmentUITests.swift:214
  Evidence: gone(button) plus Listennudeln bleibt; gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: RestockUITests/ReplenishmentUITests.swift:262
  Evidence: Gegenprobe Navigationsleiste vor Abwesenheitspruefung.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Views/Home/HomeView.swift:887
  Evidence: Diff HomeView (+3: Z. 887, 905, 939) nur accessibilityIdentifier.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Views/Store/StoreDetailView.swift:732
  Evidence: Diff StoreDetailView (+2: Z. 732, 765) nur accessibilityIdentifier.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/SmartCartApp.swift:433
  Evidence: Clear loescht Laeden, Seed-Kaeufe, alle 8 Defaults-Schluessel (Konstanten) plus Collapsed-Schluessel. Beleg im gemeinsamen Lauf gehoert in Phase /60-validate.
  Status: CONFIRMED (Code); Laufbeleg offen

Confirmation:
  AC: AC-15
  Code reference: RestockUITests/ReplenishmentUITests.swift:40
  Evidence: launch() mit Neustart-Retry, Wartezeiten 15 s, Expectations statt Einmal-Lesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: SmartCart/SmartCartApp.swift:151
  Evidence: Funktionen innerhalb #if DEBUG (151-649), Aufrufe in DEBUG-Block (28-46); Release-Build BUILD SUCCEEDED.
  Status: CONFIRMED

Confirmation:
  AC: AC-20
  Code reference: SmartCart/SmartCartApp.swift:379
  Evidence: 5 Dateien; HabitService/PurchaseRecord ohne Diff; Schnelleingabe unberuehrt; LoC-Ueberschreitung durch PO akzeptiert (Spec-Vermerk).
  Status: CONFIRMED

AC-17, AC-18, AC-19: nicht Teil dieser Implementierungspruefung; Beweise (Gesamtlauf, drei Laeufe, registrierter Durchlauf) werden in Phase /60-validate erwartet. Kein Defekt, aber vor Abschluss zwingend.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 10 passed, 0 failed (Klasse ReplenishmentUITests); Gesamtsuite/3x-Laeufe noch ausstehend (AC-17/18).
Edge cases: gepruefte Faelle (Mitternacht, Wochentagsmodus, Collapsed, Doppelseed) nicht gebrochen.
Regressions: keine (Release-Build gruen, keine Regel-Aenderung).
Checklist: AC-1..16 und 20 proven; AC-17/18/19 an Phase /60-validate delegiert.

## Geprüfte Dateien

- sha256:be7b704eba5f5ee272c226250ee5c569b0344f22fffa51eb01e34051ebccb6c7  RestockUITests/ReplenishmentUITests.swift
- sha256:8a45fb061f2f4d5799305732a0b8711ef2532e866278779898f67155db60e766  SmartCart/Services/HabitService.swift
- sha256:1c43effbb25dbdc691c31a8969ed34b9543396d521438e03cf3f54809e93d452  SmartCart/SmartCartApp.swift
- sha256:a8564bbfb2788540cecea7bcb2f939d7b8431e01ec53c1dc1fca93891f0a8911  SmartCart/Views/Home/HomeView.swift
- sha256:c76ec05df1a38675e5b61cabd3c22dc403007f2e8e0cdbf343efc9d5b498cc70  SmartCart/Views/Store/StoreDetailView.swift
