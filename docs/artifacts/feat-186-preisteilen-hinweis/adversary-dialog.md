# Adversary Dialog — feat-186-preisteilen-hinweis
Spec: docs/specs/services/community-prices-erst-hinweis.md
Datum: 2026-10-22 11:30

## Checkliste
- [x] **Input:** Nutzer speichert einen Bon oder trägt über „Preis eintragen“ einen Betrag ein.
- [x] **Output:** Beim ersten Mal mit eingeschaltetem Schalter und mindestens einem teilbaren Beitrag erscheint der Hinweis,
- [x] **Side effects:** Merker `communityPricesNoticeShown` = true nach der ersten Entscheidung; bei „Nicht teilen“
- [x] **AC-1:** [Unit] GIVEN Schalter an (Schlüssel fehlt oder true), Merker fehlt und mindestens ein teilbarer Beitrag WHEN `noticeDue` THEN wahr. Test: `CommunityPriceTests::testNoticeDueWhenSwitchOnNoMarkerAndShareableContribution`
- [x] **AC-2:** [Unit/UI] GIVEN der Hinweis steht WHEN „Weiter teilen“ THEN wird der Merker gesetzt, werden alle gesammelten Beiträge gesendet (Fake-Datenbank erhält je teilbarem Beitrag einen Record), bleibt der Schalter an und schließt der Screen. Test: `CommunityPriceTests::testRecordDecisionShareKeepsSwitchAndSetsMarker`, `CommunityPriceTests::testAcceptedContributionsAreSentAfterDecision`, `CommunityShareNoticeUITests::testKeepSharingClosesScreenAndKeepsSwitchOn`
- [x] **AC-3:** [Unit/UI] GIVEN der Hinweis steht WHEN „Nicht teilen“ THEN wird der Merker gesetzt, der Schalter steht auf aus (Einstellungen zeigen aus), es wird nichts gesendet, auch nicht der Beitrag des auslösenden Bons (Fake-Datenbank bleibt leer), und der Screen schließt. Test: `CommunityPriceTests::testRecordDecisionDeclineTurnsSwitchOffAndSetsMarker`, `CommunityPriceTests::testDeclinedContributionsAreNotSentToDatabase`, `CommunityShareNoticeUITests::testFirstSaveAsksFirstAndDeclineTurnsSharingOff`
- [x] **AC-4:** [UI] GIVEN erster Bon-Speichern-Tipp mit Schalter an und teilbaren Zeilen WHEN der Hinweis erscheint THEN ist der Prüf-Screen noch offen, bis eine Entscheidung gefallen ist (Hinweis hat genau die zwei Knöpfe „Weiter teilen“ und „Nicht teilen“, Titel und Text wie in der Lösung). Test: `CommunityShareNoticeUITests::testFirstSaveAsksFirstAndDeclineTurnsSharingOff`
- [x] **AC-5:** [Unit/UI] GIVEN der Merker ist gesetzt (nach einer Entscheidung, auch nach App-Neustart) WHEN erneut gespeichert wird THEN erscheint kein zweiter Hinweis und der Screen schließt sofort wie heute. Test: `CommunityPriceTests::testNoticeNotDueWhenMarkerSet`, `CommunityShareNoticeUITests::testSecondSaveShowsNoNotice`
- [x] **AC-6:** [UI] GIVEN der Hinweis steht und der Nutzer entscheidet WHEN gespeichert wurde THEN sind lokales Lernen, Kaufdatensätze und Sync-Push gegenüber dem Stand vor der Änderung unverändert und sofort (nicht erst nach der Entscheidung): bestehende Speichern-Tests belegen den gelernten Preis und die Quelle „Bon“ nach dem Speichern. Test: `ReceiptReviewUITests::testSavingStillWritesLearnedPriceToMatchedItem`, `ReceiptReviewUITests::testSavedReceiptShowsReceiptAsPriceSource` (laufen mit Merker gesetzt; der Code-Pfad des Lernens liegt vor der Verzweigung, Reihenfolge per Durchlauf AC-15 belegt)
- [x] **AC-7:** [Unit] GIVEN `save()` ist angestoßen und der Hinweis noch offen WHEN ein zweiter Speichern-Tipp ankommt THEN wird nichts doppelt gelernt oder gesendet (`guard pendingShare == nil`); die Sendeliste für denselben Bon enthält jeden teilbaren Beitrag genau einmal. Test: `CommunityPriceTests::testAcceptedContributionsAreSentAfterDecision` (zählt Records in der Fake-Datenbank genau einmal je Beitrag); Doppeltipp am UI selbst ist nicht automatisiert prüfbar (offene Grenze)
- [x] **AC-8:** [Unit] GIVEN „Preis eintragen“ mit mindestens einem Artikel mit Preis > 0 WHEN `ActualPriceEntryView` speichert THEN liefert `contribution(for:in:)` den Beitrag, statt ihn sofort zu senden, und es gilt dieselbe `noticeDue`-Regel wie beim Bon. Test: `CommunityPriceTests::testActualPriceEntryCollectsContributionInsteadOfSending`
- [x] **AC-9:** [Unit] GIVEN Schalter aus WHEN `noticeDue` THEN falsch (kein Hinweis), und der Merker bleibt unberührt (ein späteres Einschalten kann ihn noch auslösen). Test: `CommunityPriceTests::testNoticeNotDueWhenSwitchOff`, `CommunityPriceTests::testSwitchOffLeavesMarkerUntouched`
- [x] **AC-10:** [Unit] GIVEN ein Bon ohne teilbare Zeile (Preis 0, Kette oder Artikelschlüssel oder Bezugsgröße leer) WHEN `noticeDue` THEN falsch, und `Contribution.isShareable` entscheidet wie die Guards von `contribute`. Test: `CommunityPriceTests::testNoticeNotDueWithoutShareableContribution`, `CommunityPriceTests::testIsShareableMatchesContributeGuards`
- [x] **AC-11:** [Unit] GIVEN beide Eingänge WHEN die Regel angewandt wird THEN gilt dieselbe Funktion `noticeDue`/`recordNoticeDecision` für Bon-Prüf-Screen und „Preis eintragen“ (ein gemeinsamer Modifier, keine zweite Kopie). Test: `CommunityPriceTests::testActualPriceEntryCollectsContributionInsteadOfSending` (Eingang 2); Eingang 1 durch `CommunityShareNoticeUITests`
- [x] **AC-12:** [Unit] GIVEN `contribute` WHEN der Schalter aus ist THEN wird weiterhin nichts gesendet (zweite Sicherung, Verhalten gegenüber #163 unverändert). Test: `CommunityPriceTests::testIsShareableMatchesContributeGuards` und die bestehenden `contribute`-Tests der Klasse bleiben grün
- [x] **AC-13:** [Unit] GIVEN die vier neuen Schlüssel WHEN die Lokalisierungsprüfungen laufen THEN stehen sie in `de.lproj` und `en.lproj` und in `PriceSourceDisplay.allLocalizationKeys`. Test: `CommunityPriceTests::testLocalizationKeysAreRegistered` (um die vier Schlüssel erweitert), `LocalizationKeyParityTests`
- [x] **AC-14:** [UI] GIVEN die Bestands-UI-Tests, die einen Bon speichern WHEN sie mit `-communityPricesNoticeShown YES` starten THEN erscheint der Hinweis nie und sie bleiben unverändert grün. Test: Klassen `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, `DynamicTypeUITests` im gemeinsamen Lauf; `CommunityShareNoticeUITests` setzt weder dieses Argument noch `-communityPricesSharingEnabled`, sondern nur den Aufräumer in `setUp` und `tearDown` (Prüfung per Durchsicht, Gegenprobe T3 lässt den Aufräumer beim zweiten Start weg)
- [x] **AC-15:** [Beleg] GIVEN die App läuft im Simulator `Restock-Validate` mit frischem Zustand (Aufräumer) WHEN ein gesäter Bon gespeichert, „Nicht teilen“ gewählt und die Einstellungen geöffnet werden THEN zeigt der echte Durchlauf Hinweis, offenen Screen, geschlossenen Screen und ausgeschalteten Schalter. Beleg: Bildschirmfotos und Protokollauszug aus dem echten Lauf unter `docs/artifacts/feat-186-preisteilen-hinweis/`, als Durchlauf-Artefakt registriert (Commit-Kennung und Zeitstempel passend zum Stand).
- [x] **AC-16:** [Unit/UI] GIVEN der Bestand WHEN die Regression läuft THEN bleiben die gesamte Unit-Suite (insbesondere `CommunityPriceTests`, `LocalizationKeyParityTests`) und alle UI-Klassen grün; `RestockShareExtension/` und `SmartCartWidgets/` bleiben unverändert. Test: Unit-Suite und UI-Suite im gemeinsamen Lauf
- [x] **AC-17:** [Gerät, offene Grenze, kein Gate] Auf Hennings Gerät mit TestFlight-Build erscheint der Hinweis beim ersten Speichern. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.

Belege je Punkt (Input/Output/Side effects: beide save() sammeln und verzweigen über holdForNoticeOrSend, Durchlauf-Fotos 2 und 4):
AC-1 U1; AC-2 U6, U9, T2; AC-3 U7, U8, T1 (Nein-Zweig sendet nie, Durchsicht, F001); AC-4 T1 (genau 2 Knöpfe, Prüf-Screen offen, Foto 2); AC-5 U3, T3; AC-6 Codereihenfolge Lernen/Push vor Verzweigung (F002); AC-7 guard pendingShare == nil, U9; AC-8 U11; AC-9 U2, U10; AC-10 U4, U5; AC-11 gemeinsamer Modifier; AC-12 U5; AC-13 Schlüssel de/en/allLocalizationKeys, Paritätstest grün; AC-14 UI-Klasse ohne die beiden Argumente, Bestandstests mit Argument, UI 135/0; AC-15 Fotos und durchlauf-echte-app.txt (Commit 36f19fb plus Patch); AC-16 Unit 655/0, UI 135/0, 3 Skips vorbestehend, ShareExtension und Widgets ohne Diff; AC-17 offene Grenze, am Gerät nicht belegt.

## Dialog

### Runde 1
**Adversary:** Angriff auf Senden bei Nicht teilen: grep contributeInBackground findet die Einzel-Überladung (ohne Aufrufer) und die Listen-Überladung nur im Weiter-Knopf und im Nicht-fällig-Zweig. Kein Pfad sendet bei Nicht teilen. Alert-Binding mit leerem Setter: kein Abbrechen-Knopf, modal, Sheet nicht wegwischbar, finish() räumt pending vor dismiss, Hinweis kann weder hängen bleiben noch wiederkehren. Wiedereintritt per guard gesichert. Aufräumer im DEBUG-Block. Texte de/en wörtlich wie Spec.
**Implementierer:** Code gelesen, keine Rückfrage; Verhalten wie beschrieben.

Code reference: SmartCart/Views/Prices/CommunityShareNotice.swift:26
Code reference: SmartCart/Services/CommunityPriceService.swift:180
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:759

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Views/Prices/CommunityShareNotice.swift:29
  Description: Der Nicht-teilen-Zweig ruft nur recordNoticeDecision und finish(); kein Test auf Modifier-Ebene belegt, dass nichts gesendet wird. U8 prüft nur contribute bei ausgeschaltetem Schalter (zweite Sicherung), wäre also auch ohne Zurückhaltung grün.
  Spec requirement: AC-3 — Fake-Datenbank bleibt leer
  Conflict: Nachweis teils Durchsicht; Datenabfluss wäre durch den Guard in contribute ohnehin verhindert.
  Remediation: Optional Test für holdForNoticeOrSend und Knopflogik.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:835
  Description: Lernen und pushInBackground laufen vor der Verzweigung, aber AC-6 wird nur durch Bestandstests mit gesetztem Merker belegt; kein Test liest den gelernten Preis, während der Hinweis steht.
  Spec requirement: AC-6 — unverändert und sofort
  Conflict: Beleg nur per Codereihenfolge; die Spec räumt das selbst ein.
  Remediation: Optional T1 um Preislesen vor der Entscheidung erweitern.

### Runde 2
**Adversary:** Ränder: ActualPriceEntryView verliert bei vorzeitigem Verschwinden des Sheets die Beiträge ohne Merker, laut Spec-Grenze datenschutzsicher und erlaubt. contribute(_ list:) prüft den Schalter je Beitrag. Scoping: ReceiptScannerView.save() bleibt deutlich über 50 Zeilen (vorbestehend, nur +13); Hilfsfunktion holdForNoticeOrSend ist nicht in der Spec benannt, aber sinnvoll und gemeinsam. CLAUDE.md-Streichung „kein Erst-Hinweis“ ist durch die Doku-Vorgabe gedeckt. Argument-Domain-Falle: UI-Klasse sauber, T3 lässt den Aufräumer weg. T1-T3 passed.
**Implementierer:** Keine neuen Einwände.

Code reference: SmartCart/Views/Prices/ActualPriceEntryView.swift:157
Code reference: SmartCart/Models/ShoppingItem.swift:535
Code reference: SmartCart/SmartCartApp.swift:544

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Services/CommunityPriceService.swift:165
  Description: contributeInBackground(_ contribution:) hat keinen Aufrufer mehr.
  Spec requirement: Scope minimal
  Conflict: Toter Code, kein Funktionsfehler.
  Remediation: Entfernen oder belassen.

### Runde 3
**Adversary:** Nachlauf auf zusammengeführtem Stand (origin/main 9bc25d3 = #205, RED 3a9719b). Der Vergleich gegen 9bc25d3 zeigt: die von main übernommenen Zeilen von contribute (Guard Preis > 0, Kette, Artikelschlüssel, Bezugsgröße) sind unverändert, isShareable ist weiterhin identisch zu den Guards; #205 hat contribute, Contribution und die Guards nicht angefasst, es ändert nur das Lesen kettenübergreifend. grep contributeInBackground und .contribute( findet weiterhin nur die zwei Aufrufe in CommunityShareNotice.swift (Weiter-Knopf, Nicht-fällig-Zweig) und die beiden Definitionen; kein neuer Sendeweg, keiner am Hinweis vorbei. Schlüssellisten: de und en haben je 6 Schlüssel (2 allchains von main plus 4 notice), keine Duplikate; allLocalizationKeys und testLocalizationKeysAreRegistered enthalten beide Seiten, ohne Doppel. CLAUDE.md: nur Konfliktauflösung, eigener #186-Absatz bleibt. Nachlauf rebase-test-output.txt: Unit 674/0, UI 4 Klassen 32/0, 0 Fehlschläge.
**Implementierer:** keine Einwände.

Code reference: SmartCart/Services/CommunityPriceService.swift:145
Code reference: SmartCart/Models/ShoppingItem.swift:546
Code reference: SmartCart/Views/Prices/CommunityShareNotice.swift:63
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:759
Code reference: SmartCart/Views/Prices/ActualPriceEntryView.swift:157
Code reference: SmartCart/SmartCartApp.swift:544

Keine neuen Findings; F001 bis F003 (LOW) bleiben bestehen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Kein Pfad sendet bei Nicht teilen; Hinweis hängt nicht; beide Eingänge gleiche Logik; Texte wörtlich. Nur LOW-Findings (Testtiefe, toter Code).
Tests: 655 Unit + 135 UI bestanden (Stand vor Rebase), nach Rebase 674 Unit + 32 UI (4 Klassen) bestanden, 0 fehlgeschlagen, 3 übersprungen im Gesamtlauf (vorbestehend, nicht erneut gefahren)
Edge cases: All checked, none broken
Regressions: None found
Checklist: 19/19 belegt, AC-17 als offene Grenze (am Gerät nicht belegt)

## Geprüfte Dateien

- sha256:b2ab05cdeb4db8aa5a6f1615ab41f3e057fd10d6f75bd6b2f30d603b9b4234a6  SmartCart/Models/ShoppingItem.swift
- sha256:eb415f039102b19a343acb4f0d0b776354e626fa7c1583a2be14c4cf8661142b  SmartCart/Services/CommunityPriceService.swift
- sha256:427cd2065842d5f2ff71ee76442355cc18610f755cbbe84f89fdb8e0214e2f25  SmartCart/SmartCartApp.swift
- sha256:5d51443c12c57aff3e4a0d0b9c883539972457f81b7a0d10bbe503abfab69dbb  SmartCart/Views/Prices/ActualPriceEntryView.swift
- sha256:2bd70557b151d7f6aab794d3ab41fee44933208356773b4d5bde3d0e96309d16  SmartCart/Views/Prices/CommunityShareNotice.swift
- sha256:354fb0bf8e699c30a6b53b7ba8ed20749b8738cb0de539801d0f9f9405a29e59  SmartCart/Views/Prices/ReceiptScannerView.swift

## Prüfbasis

- base: f1c5e8a9fbae73f25183c7c9fbe1db14ae94d877
- blob:e90cfed17c82770c5d88de36d46cf6ad56120994  SmartCart/Models/ShoppingItem.swift
- blob:339378dc2a485534181ff32f984e5a9ce2252b4a  SmartCart/Services/CommunityPriceService.swift
- blob:1f46866b83682b43048c76cae6c768c8269d8423  SmartCart/SmartCartApp.swift
- blob:a453011072881135687bceeba6fa48cfae466974  SmartCart/Views/Prices/ActualPriceEntryView.swift
- blob:892c7c94297e8d8dc4301ad65898eece1f78b596  SmartCart/Views/Prices/CommunityShareNotice.swift
- blob:fdb6cd5876ec0b4daf23c22eecac3aeb963fd8d3  SmartCart/Views/Prices/ReceiptScannerView.swift

## Geprüfte Dateien

- sha256:0f51a83642f754ca5d289b0911a6d0b7a65bbc90657892a6094e7b8b22ba130b  SmartCart/Models/ShoppingItem.swift
- sha256:f6833e493d0e5ba0a899af58c956b3744cc7c1de8f5f434fa0b72da0d4259a2c  SmartCart/Services/CommunityPriceService.swift
- sha256:427cd2065842d5f2ff71ee76442355cc18610f755cbbe84f89fdb8e0214e2f25  SmartCart/SmartCartApp.swift
- sha256:5d51443c12c57aff3e4a0d0b9c883539972457f81b7a0d10bbe503abfab69dbb  SmartCart/Views/Prices/ActualPriceEntryView.swift
- sha256:2bd70557b151d7f6aab794d3ab41fee44933208356773b4d5bde3d0e96309d16  SmartCart/Views/Prices/CommunityShareNotice.swift
- sha256:354fb0bf8e699c30a6b53b7ba8ed20749b8738cb0de539801d0f9f9405a29e59  SmartCart/Views/Prices/ReceiptScannerView.swift

## Prüfbasis

- base: 9bc25d3a0dfa668b7aeb2ee03b2e70bd6f19f7b0
- blob:3fbf1a77d1434ac6164f25fffe9496a08ea50acd  SmartCart/Models/ShoppingItem.swift
- blob:85d9ab43b39743639447a25e73ed7c0a76e6135d  SmartCart/Services/CommunityPriceService.swift
- blob:1f46866b83682b43048c76cae6c768c8269d8423  SmartCart/SmartCartApp.swift
- blob:a453011072881135687bceeba6fa48cfae466974  SmartCart/Views/Prices/ActualPriceEntryView.swift
- blob:892c7c94297e8d8dc4301ad65898eece1f78b596  SmartCart/Views/Prices/CommunityShareNotice.swift
- blob:fdb6cd5876ec0b4daf23c22eecac3aeb963fd8d3  SmartCart/Views/Prices/ReceiptScannerView.swift

## Geprüfte Dateien

- sha256:0f51a83642f754ca5d289b0911a6d0b7a65bbc90657892a6094e7b8b22ba130b  SmartCart/Models/ShoppingItem.swift
- sha256:f6833e493d0e5ba0a899af58c956b3744cc7c1de8f5f434fa0b72da0d4259a2c  SmartCart/Services/CommunityPriceService.swift
- sha256:427cd2065842d5f2ff71ee76442355cc18610f755cbbe84f89fdb8e0214e2f25  SmartCart/SmartCartApp.swift
- sha256:5d51443c12c57aff3e4a0d0b9c883539972457f81b7a0d10bbe503abfab69dbb  SmartCart/Views/Prices/ActualPriceEntryView.swift
- sha256:2bd70557b151d7f6aab794d3ab41fee44933208356773b4d5bde3d0e96309d16  SmartCart/Views/Prices/CommunityShareNotice.swift
- sha256:354fb0bf8e699c30a6b53b7ba8ed20749b8738cb0de539801d0f9f9405a29e59  SmartCart/Views/Prices/ReceiptScannerView.swift

## Prüfbasis

- base: 9bc25d3a0dfa668b7aeb2ee03b2e70bd6f19f7b0
- blob:3fbf1a77d1434ac6164f25fffe9496a08ea50acd  SmartCart/Models/ShoppingItem.swift
- blob:85d9ab43b39743639447a25e73ed7c0a76e6135d  SmartCart/Services/CommunityPriceService.swift
- blob:1f46866b83682b43048c76cae6c768c8269d8423  SmartCart/SmartCartApp.swift
- blob:a453011072881135687bceeba6fa48cfae466974  SmartCart/Views/Prices/ActualPriceEntryView.swift
- blob:892c7c94297e8d8dc4301ad65898eece1f78b596  SmartCart/Views/Prices/CommunityShareNotice.swift
- blob:fdb6cd5876ec0b4daf23c22eecac3aeb963fd8d3  SmartCart/Views/Prices/ReceiptScannerView.swift
