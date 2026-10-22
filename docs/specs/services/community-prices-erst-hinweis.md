---
entity_id: community-prices-erst-hinweis
type: feature
created: 2026-10-22
updated: 2026-10-22
status: draft
workflow: feat-186-preisteilen-hinweis
tags: [feature, community-prices, datenschutz, alert, issue-186]
---

# Einmaliger Hinweis vor dem ersten Preisbeitrag (Issue #186)

## Approval

- [ ] Approved

Entscheidungen des PO vom 2026-10-22, hier übernommen und nicht neu verhandelt: Der Hinweis erscheint **vor** dem
Hochladen. Bei „Nicht teilen“ verlässt kein Preis das Gerät, auch nicht der des auslösenden Bons, und der Schalter
steht danach auf aus. **Entwurf A** (Systemhinweis, SwiftUI `.alert`), Alternative B (Karte von unten) verworfen.
Ein Durchgang für beide Eingänge (Bon speichern, „Preis eintragen“), Umfang ca. +290/−10 Zeilen freigegeben.
Quellen: `docs/context/feat-186-preisteilen-hinweis.md`, Entwurfsvorschau
`docs/artifacts/feat-186-preisteilen-hinweis/entwurfsvorschau.html`.

## Purpose

Seit #183 ist „Preise anonym mit anderen teilen“ voreingestellt an (Opt-out). Der Nutzer erfährt davon nur aus der
Fußnote in den Einstellungen. Diese Spec fügt beim ersten Beitrag genau einen Hinweis ein, der sagt, was geteilt wird,
und der dem Nutzer vor dem ersten Hochladen die Entscheidung gibt.

Hat es bisher funktioniert? Es ist keine Verschlechterung, sondern eine Lücke aus #163/#183 (festgehalten als offene
Grenze „kein Hinweis nach dem ersten Bon-Scan“ in `community-prices.md`).

## Lösung (Entwurf A)

Ein Systemhinweis (`.alert`) in der Bildschirmmitte, ein Text, zwei Knöpfe. Texte wörtlich aus der freigegebenen Vorschau:

| Element | Deutsch | Schlüssel |
|---------|---------|-----------|
| Titel | Preise anonym teilen? | `settings.community.notice.title` |
| Text | Restock teilt beim Bon-Scan und bei „Preis eintragen“ nur Artikel, Ladenkette, Preis und Datum, ohne Namen, Foto oder Filiale. Dafür siehst du Preise anderer als „Community“. Änderbar in den Einstellungen. | `settings.community.notice.message` |
| Knopf 1 (Standard) | Weiter teilen | `settings.community.notice.share` |
| Knopf 2 | Nicht teilen | `settings.community.notice.decline` |

Englische Fassung in `en.lproj` (sinngleich, gleiche Platzhalter, hier keine): „Share prices anonymously?“ /
„Restock shares only item, store chain, price and date when you scan a receipt or enter a price, without your name,
photo or branch. In return you see other people's prices as „Community“. You can change this in Settings.“ /
„Keep sharing“ / „Don't share“. `LocalizationKeyParityTests` prüft Schlüssel- und Platzhaltergleichheit.

Ablauf beim Speichern (beide Eingänge):

1. Lokales Lernen bleibt unverändert und sofort: gelernte Preise, `ReceiptLearning.apply`, Kaufdatensätze,
   Haptik, `SyncCoordinator.pushInBackground`. Nur das Senden an den Community-Pool ändert sich.
2. Statt je Zeile sofort `contributeInBackground` aufzurufen, sammelt `save()` die `Contribution`s in einer Liste.
3. Am Ende von `save()`: Ist `CommunityPriceService.noticeDue(contributions, in: .standard)` wahr, wird die Liste in den
   Zustand `pendingShare` gelegt und der Hinweis gezeigt; `dismiss()` wird **nicht** aufgerufen. Sonst werden die
   Beiträge wie bisher gesendet und `dismiss()` aufgerufen.
4. „Weiter teilen“: Merker setzen, Beiträge senden, `dismiss()`. „Nicht teilen“: Merker setzen, Schalter aus,
   Beiträge verwerfen, `dismiss()`.

Entwurfsvorschau-Ausnahmen aus dem Entwurf übernommen: kein Hinweis, wenn der Schalter schon aus ist oder der Bon keinen
teilbaren Preis enthält; wird die App während des Hinweises beendet, ist nichts geteilt und der Hinweis kommt wieder.

## Source

- **File:** `SmartCart/Services/CommunityPriceService.swift`, `SmartCart/Views/Prices/CommunityShareNotice.swift` (neu)
- **Identifier:** `CommunityPriceService.noticeDue(_:in:)`, `CommunityPriceService.recordNoticeDecision(share:in:)`,
  `CommunityPriceService.Contribution.isShareable`, `CommunityPriceService.contributeInBackground(_: [Contribution])`,
  `View.communityShareNotice(pending:onFinished:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CommunityPriceService` (#163) | Service | Schalter-Schlüssel `sharingEnabledKey`, `contribute`, Fake-Datenbank in `CommunityPriceTests` |
| `ReceiptScannerView.save()` | View | Eingang 1: Bon-Prüf-Screen (auch Ziel des Wegs über die Teilen-Erweiterung; die Erweiterung selbst teilt nichts) |
| `ActualPriceEntryView.save()` | View | Eingang 2: „Preis eintragen“ (Einstieg `StoreDetailView.swift:564`) |
| `SettingsView` (`@AppStorage(sharingEnabledKey)`) | View | Liest denselben Schlüssel, zeigt nach „Nicht teilen“ sofort „aus“; unverändert |
| `PriceSourceDisplay.allLocalizationKeys` (`ShoppingItem.swift:534`) | Liste | Wird um die vier neuen Schlüssel ergänzt; `CommunityPriceTests.testLocalizationKeysAreRegistered` prüft |
| `SmartCartApp` DEBUG-Aufräumer | Muster | `clearDeveloperModeForUITestsIfNeeded` (`SmartCartApp.swift:535`) |

## Scope

- **Affected Files** (Zeilenangaben am Stand `f1c5e8a` geprüft):

| Datei | Änderung | Inhalt |
|-------|----------|--------|
| `SmartCart/Services/CommunityPriceService.swift` | MODIFY | `noticeShownKey = "communityPricesNoticeShown"`; `Contribution.isShareable` (Guards aus `contribute` herausgezogen, `contribute` nutzt sie, Verhalten gleich); `static noticeDue(_:in:)`; `static recordNoticeDecision(share:in:)`; `contributeInBackground(_ list: [Contribution])` |
| `SmartCart/Views/Prices/CommunityShareNotice.swift` | CREATE | ViewModifier mit dem `.alert`; Eintrag in `Restock.xcodeproj/project.pbxproj` (App-Ziel, vier Stellen) |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `save()` (Zeilen ca. 754–833): sammeln statt je Zeile senden (bisher Aufruf bei ca. 791), Verzweigung am Ende, `dismiss()` (ca. 832) nur ohne Hinweis; Zustand `pendingShare`; Doppeltipp-Schutz am Anfang von `save()` |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | MODIFY | `static share(_:in:)` (ca. 158–163) wird `contribution(for:in:) -> Contribution?`; `save()` (ca. 119–146) sammelt in beiden Zweigen, gleiche Verzweigung, Modifier |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Aufräumer `-clearCommunityPricesNoticeForUITests` (entfernt `communityPricesNoticeShown` und `communityPricesSharingEnabled` aus `UserDefaults.standard`), Aufruf im `defer`-Block bei ca. Zeile 35 |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | vier Schlüssel (nach `settings.community.footer`, Zeile 419) |
| `SmartCart/Models/ShoppingItem.swift` | MODIFY | vier Schlüssel in `allLocalizationKeys` (Zeile 534) |
| `RestockTests/CommunityPriceTests.swift` | MODIFY | Unit-Tests U1–U10 |
| `RestockUITests/CommunityShareNoticeUITests.swift` | CREATE | Klasse mit drei UI-Tests; pbxproj (UI-Test-Ziel); Klasse landet automatisch in CI-Hälfte B |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | `-communityPricesNoticeShown YES` an drei Start-Stellen (Zeilen 112, 153, 836) |
| `RestockUITests/ReceiptResolutionStatsUITests.swift` | MODIFY | dasselbe im Start-Helfer (Zeile 54–56) |
| `RestockUITests/DynamicTypeUITests.swift` | MODIFY | dasselbe in T2 (Zeile 189) |
| `docs/specs/services/community-prices.md` | MODIFY (Doku) | siehe „Doku-Änderungen“ |

- **Estimated Changes:** ca. +290/−10 Zeilen (Produktiv ca. 145 inklusive Texte, Tests ca. 140), 13 Code- und
  Testdateien (die zwei `Localizable.strings` und die drei Bestands-UI-Testdateien einzeln gezählt) plus
  `project.pbxproj` und eine Doku-Datei. Die Freigabe nannte „~11 Dateien“; die Zahl entsteht durch Zusammenfassen
  der Strings-Dateien und der Bestands-UI-Tests, Zeilenrahmen und Inhalt sind gleich.

## Implementation Details

```swift
// CommunityPriceService
static let noticeShownKey = "communityPricesNoticeShown"

extension Contribution {
    /// Dieselben Bedingungen wie bisher in `contribute` (Preis > 0, Kette, Artikelschlüssel, Bezugsgröße nicht leer).
    var isShareable: Bool { … }
}

/// Fällig, wenn der Schalter an ist (Standard an), der Merker fehlt und mindestens ein Beitrag teilbar ist.
static func noticeDue(_ contributions: [Contribution], in defaults: UserDefaults) -> Bool

/// Setzt den Merker auf true; bei share == false zusätzlich den Schalter-Schlüssel ausdrücklich auf false
/// (damit @AppStorage in den Einstellungen sofort „aus“ zeigt). Bei share == true bleibt der Schalter-Schlüssel unberührt.
static func recordNoticeDecision(share: Bool, in defaults: UserDefaults)
```

```swift
// Aufrufer (beide Eingänge)
@State private var pendingShare: [CommunityPriceService.Contribution]?   // nil = kein Hinweis offen

// Ende von save():
if CommunityPriceService.noticeDue(contributions, in: .standard) { pendingShare = contributions }
else { CommunityPriceService.shared.contributeInBackground(contributions); dismiss() }

// .communityShareNotice(pending: $pendingShare) { dismiss() }
// „Weiter teilen“: recordNoticeDecision(share: true), contributeInBackground(pending), pending = nil, onFinished()
// „Nicht teilen“:  recordNoticeDecision(share: false), pending = nil, onFinished()   // nichts gesendet
```

- Doppeltipp-Schutz: `save()` beginnt mit `guard pendingShare == nil`. Der `.alert` ist modal, der Guard sichert den
  Moment zwischen erstem Tipp und Erscheinen des Hinweises sowie das Wiedereintreten aus dem Zustand.
- `contribute` prüft den Schalter weiter selbst (zweite Sicherung): Auch ein versehentlich gesendeter Beitrag
  verlässt bei ausgeschaltetem Schalter das Gerät nicht.
- Der Hinweis hängt am Screen, der `dismiss()` aufruft (`.alert` am äußersten View des Sheets). `ReceiptScannerView` hat
  bereits `.confirmationDialog` (Zeile 487) und zwei `.sheet`; der Hinweis ist ein dritter, getrennter Präsentationszustand.
- Keine neue Abhängigkeit, keine Info.plist-Änderung, keine AppStorage-Schlüssel außer dem neuen Merker
  `communityPricesNoticeShown` (`UserDefaults.standard`, kein iCloud-Abgleich, bleibt je Gerät).
- Haptik nur über `Haptics.*` (unverändert); Texte über `String(localized:)`.

## Expected Behavior

- **Input:** Nutzer speichert einen Bon oder trägt über „Preis eintragen“ einen Betrag ein.
- **Output:** Beim ersten Mal mit eingeschaltetem Schalter und mindestens einem teilbaren Beitrag erscheint der Hinweis,
  der Screen bleibt bis zur Entscheidung offen. Danach (und in jedem anderen Fall sofort) schließt der Screen wie heute.
- **Side effects:** Merker `communityPricesNoticeShown` = true nach der ersten Entscheidung; bei „Nicht teilen“
  zusätzlich `communityPricesSharingEnabled` = false. Lokales Lernen, Kaufdatensätze und Sync-Push laufen unverändert
  und sofort.

## Nicht im Umfang

- Keine Änderung an Aggregat, Pool, Schema, `LegalView` (Datenschutzabschnitt „Community-Preise“) und Einstellungen.
- Kein Nachfragen bei späterem Wiedereinschalten des Schalters (der Merker bleibt gesetzt).
- Keine Region, kein Missbrauchsschutz (bleiben offene Punkte aus #163).

## Alternativen

- **Alternative B, eigene Karte von unten** mit Liste „teilt / teilt nicht“: übersichtlicher, aber ein Bildschirm mehr
  (Text, Layout, Großschrift, VoiceOver, Wischen-zum-Schließen als dritte Antwort). Vom PO verworfen.
- **Hinweis im Dienst selbst** (Warteschlange in `CommunityPriceService`, Dialog global in `HomeView`): entkoppelt die
  beiden Eingänge, braucht aber globalen Zustand und zeigt den Dialog fern vom auslösenden Screen. Nicht gewählt; würde
  die Entscheidung kippen, dass der Hinweis am Speichern-Screen steht.
- **Nach dem Hochladen informieren** (Hinweis ohne Rückhaltung, wie der ursprüngliche Issue-Text): einfacher, aber der
  erste Beitrag wäre schon draußen. Vom PO am 2026-10-22 zugunsten „vor dem Hochladen“ verworfen; gekippt würde nur die
  Zurückhaltung der Beiträge in `save()`.
- **Kein Hinweis, Aufklärung nur in Einstellungen und `LegalView`** (Stand heute): kein Aufwand, aber ein Opt-out
  ohne Erstkontakt; Anlass des Tickets.
- **Bestands-UI-Tests wegtippen statt Launch-Argument:** verlängert jeden Test, nicht gewählt.

## Test Plan

Unit-Tests in `RestockTests/CommunityPriceTests.swift`, mit eigener `UserDefaults`-Suite je Test (Name
`UT-NoticeTests-` plus eindeutige UUID, im `tearDown` entfernt, `UserDefaults.standard` bleibt unberührt) und dem vorhandenen
Fake `CommunityPriceDatabase`:

| Name | Prüft |
|------|-------|
| U1 `testNoticeDueWhenSwitchOnNoMarkerAndShareableContribution` | AC-1 |
| U2 `testNoticeNotDueWhenSwitchOff` | AC-9 |
| U3 `testNoticeNotDueWhenMarkerSet` | AC-5 |
| U4 `testNoticeNotDueWithoutShareableContribution` | AC-10 |
| U5 `testIsShareableMatchesContributeGuards` | AC-10, AC-12 |
| U6 `testRecordDecisionShareKeepsSwitchAndSetsMarker` | AC-2 |
| U7 `testRecordDecisionDeclineTurnsSwitchOffAndSetsMarker` | AC-3 |
| U8 `testDeclinedContributionsAreNotSentToDatabase` | AC-3 |
| U9 `testAcceptedContributionsAreSentAfterDecision` | AC-2 |
| U10 `testSwitchOffLeavesMarkerUntouched` | AC-9 |
| U11 `testActualPriceEntryCollectsContributionInsteadOfSending` | AC-8, AC-11 |
| (vorhanden, erweitert) `testLocalizationKeysAreRegistered` | AC-13 |
| (vorhanden) `LocalizationKeyParityTests` | AC-13 |

UI-Tests in `RestockUITests/CommunityShareNoticeUITests.swift`. Start immer mit
`-hasCompletedOnboarding YES -seedReceiptReviewForUITests -clearCommunityPricesNoticeForUITests` (Seed: Lidl, vier
Zeilen mit festen Preisen, teilbar). Aufräumer `-clearCommunityPricesNoticeForUITests` in `setUp` (frischer Zustand,
auch der Schalter-Schlüssel) und `tearDown` (zusammen mit `-clearReceiptReviewSeedForUITests`); die Klasse nutzt nie
`-communityPricesNoticeShown` und nie `-communityPricesSharingEnabled` (Argument-Domain-Falle: ein Launch-Argument
überlagert jedes spätere Schreiben der App). Start über `UITestLaunch.start` mit Gegenprobe auf den Seed.

| Name | Ablauf |
|------|--------|
| T1 `testFirstSaveAsksFirstAndDeclineTurnsSharingOff` | Seed starten, „Speichern“ tippen → Hinweis „Preise anonym teilen?“ mit beiden Knöpfen sichtbar, Prüf-Screen („Bon scannen — Lidl“) noch offen (AC-1, AC-4); „Nicht teilen“ → Prüf-Screen weg, Startseite sichtbar (AC-3); Zahnrad → Einstellungen: Schalter „Preise anonym mit anderen teilen“ steht auf aus (Wert „0“) (AC-3) |
| T2 `testKeepSharingClosesScreenAndKeepsSwitchOn` | wie T1, „Weiter teilen“ → Screen weg; Einstellungen: Schalter an (Wert „1“) (AC-2) |
| T3 `testSecondSaveShowsNoNotice` | Start mit Aufräumer, speichern, „Weiter teilen“, App beenden; Neustart nur mit `-hasCompletedOnboarding YES -seedReceiptReviewForUITests` (ohne Aufräumer, der Merker bleibt), „Speichern“ → Screen schließt sofort, kein Hinweis (AC-5) |

Bestands-UI-Tests unterdrücken den Hinweis mit `-communityPricesNoticeShown YES` (AC-14), vollständig:
`ReceiptReviewUITests` (Start-Helfer `launchedApp()` Zeile 112, `launchedAppWithUnresolvedLine()` Zeile 153,
`testSavedWeightLineShowsGramsInExpenses` Zeile 836; speichernde Tests `testSavingStillWritesLearnedPriceToMatchedItem`,
`testSavedReceiptShowsReceiptAsPriceSource`, `testSavedReceiptDoesNotProduceOneCentItemPrice`,
`testSavedWeightLineShowsGramsInExpenses`; `testSaveIsNotTriggerableWithoutAnySelectedPosition` tippt ein gesperrtes
„Speichern“, bekommt das Argument über den Helfer mit), `ReceiptResolutionStatsUITests` (Helfer Zeile 54–56,
`testSavedReceiptIsCountedPerStageWithChangedAndDeselected`), `DynamicTypeUITests`
(`testReceiptReviewAndStoreListStayUsableAtLargestAccessibilitySize`, Zeile 189). Per `grep` geprüft: kein weiterer
Bestands-UI-Test speichert einen Bon, und keiner bedient „Preis eintragen“ oder `ActualPriceEntryView`; die übrigen
Treffer auf „Speichern“ (`AddItemQuantitySuggestionUITests`, `LegacyLearnedPriceResetUITests`, `ShoppingRouteUITests`)
betreffen Artikel-Dialoge und sind nicht berührt. `ReceiptShareExtensionTests` und
`scripts/run-share-extension-uitest.sh` enden vor dem Speichern.

Durchlauf (kein Test, siehe AC-15): App im Simulator `Restock-Validate` mit dem Stand starten und den Ablauf als Nutzer
spielen.

## Acceptance Criteria

- **AC-1:** [Unit] GIVEN Schalter an (Schlüssel fehlt oder true), Merker fehlt und mindestens ein teilbarer Beitrag WHEN `noticeDue` THEN wahr. Test: `CommunityPriceTests::testNoticeDueWhenSwitchOnNoMarkerAndShareableContribution`
- **AC-2:** [Unit/UI] GIVEN der Hinweis steht WHEN „Weiter teilen“ THEN wird der Merker gesetzt, werden alle gesammelten Beiträge gesendet (Fake-Datenbank erhält je teilbarem Beitrag einen Record), bleibt der Schalter an und schließt der Screen. Test: `CommunityPriceTests::testRecordDecisionShareKeepsSwitchAndSetsMarker`, `CommunityPriceTests::testAcceptedContributionsAreSentAfterDecision`, `CommunityShareNoticeUITests::testKeepSharingClosesScreenAndKeepsSwitchOn`
- **AC-3:** [Unit/UI] GIVEN der Hinweis steht WHEN „Nicht teilen“ THEN wird der Merker gesetzt, der Schalter steht auf aus (Einstellungen zeigen aus), es wird nichts gesendet, auch nicht der Beitrag des auslösenden Bons (Fake-Datenbank bleibt leer), und der Screen schließt. Test: `CommunityPriceTests::testRecordDecisionDeclineTurnsSwitchOffAndSetsMarker`, `CommunityPriceTests::testDeclinedContributionsAreNotSentToDatabase`, `CommunityShareNoticeUITests::testFirstSaveAsksFirstAndDeclineTurnsSharingOff`
- **AC-4:** [UI] GIVEN erster Bon-Speichern-Tipp mit Schalter an und teilbaren Zeilen WHEN der Hinweis erscheint THEN ist der Prüf-Screen noch offen, bis eine Entscheidung gefallen ist (Hinweis hat genau die zwei Knöpfe „Weiter teilen“ und „Nicht teilen“, Titel und Text wie in der Lösung). Test: `CommunityShareNoticeUITests::testFirstSaveAsksFirstAndDeclineTurnsSharingOff`
- **AC-5:** [Unit/UI] GIVEN der Merker ist gesetzt (nach einer Entscheidung, auch nach App-Neustart) WHEN erneut gespeichert wird THEN erscheint kein zweiter Hinweis und der Screen schließt sofort wie heute. Test: `CommunityPriceTests::testNoticeNotDueWhenMarkerSet`, `CommunityShareNoticeUITests::testSecondSaveShowsNoNotice`
- **AC-6:** [UI] GIVEN der Hinweis steht und der Nutzer entscheidet WHEN gespeichert wurde THEN sind lokales Lernen, Kaufdatensätze und Sync-Push gegenüber dem Stand vor der Änderung unverändert und sofort (nicht erst nach der Entscheidung): bestehende Speichern-Tests belegen den gelernten Preis und die Quelle „Bon“ nach dem Speichern. Test: `ReceiptReviewUITests::testSavingStillWritesLearnedPriceToMatchedItem`, `ReceiptReviewUITests::testSavedReceiptShowsReceiptAsPriceSource` (laufen mit Merker gesetzt; der Code-Pfad des Lernens liegt vor der Verzweigung, Reihenfolge per Durchlauf AC-15 belegt)
- **AC-7:** [Unit] GIVEN `save()` ist angestoßen und der Hinweis noch offen WHEN ein zweiter Speichern-Tipp ankommt THEN wird nichts doppelt gelernt oder gesendet (`guard pendingShare == nil`); die Sendeliste für denselben Bon enthält jeden teilbaren Beitrag genau einmal. Test: `CommunityPriceTests::testAcceptedContributionsAreSentAfterDecision` (zählt Records in der Fake-Datenbank genau einmal je Beitrag); Doppeltipp am UI selbst ist nicht automatisiert prüfbar (offene Grenze)
- **AC-8:** [Unit] GIVEN „Preis eintragen“ mit mindestens einem Artikel mit Preis > 0 WHEN `ActualPriceEntryView` speichert THEN liefert `contribution(for:in:)` den Beitrag, statt ihn sofort zu senden, und es gilt dieselbe `noticeDue`-Regel wie beim Bon. Test: `CommunityPriceTests::testActualPriceEntryCollectsContributionInsteadOfSending`
- **AC-9:** [Unit] GIVEN Schalter aus WHEN `noticeDue` THEN falsch (kein Hinweis), und der Merker bleibt unberührt (ein späteres Einschalten kann ihn noch auslösen). Test: `CommunityPriceTests::testNoticeNotDueWhenSwitchOff`, `CommunityPriceTests::testSwitchOffLeavesMarkerUntouched`
- **AC-10:** [Unit] GIVEN ein Bon ohne teilbare Zeile (Preis 0, Kette oder Artikelschlüssel oder Bezugsgröße leer) WHEN `noticeDue` THEN falsch, und `Contribution.isShareable` entscheidet wie die Guards von `contribute`. Test: `CommunityPriceTests::testNoticeNotDueWithoutShareableContribution`, `CommunityPriceTests::testIsShareableMatchesContributeGuards`
- **AC-11:** [Unit] GIVEN beide Eingänge WHEN die Regel angewandt wird THEN gilt dieselbe Funktion `noticeDue`/`recordNoticeDecision` für Bon-Prüf-Screen und „Preis eintragen“ (ein gemeinsamer Modifier, keine zweite Kopie). Test: `CommunityPriceTests::testActualPriceEntryCollectsContributionInsteadOfSending` (Eingang 2); Eingang 1 durch `CommunityShareNoticeUITests`
- **AC-12:** [Unit] GIVEN `contribute` WHEN der Schalter aus ist THEN wird weiterhin nichts gesendet (zweite Sicherung, Verhalten gegenüber #163 unverändert). Test: `CommunityPriceTests::testIsShareableMatchesContributeGuards` und die bestehenden `contribute`-Tests der Klasse bleiben grün
- **AC-13:** [Unit] GIVEN die vier neuen Schlüssel WHEN die Lokalisierungsprüfungen laufen THEN stehen sie in `de.lproj` und `en.lproj` und in `PriceSourceDisplay.allLocalizationKeys`. Test: `CommunityPriceTests::testLocalizationKeysAreRegistered` (um die vier Schlüssel erweitert), `LocalizationKeyParityTests`
- **AC-14:** [UI] GIVEN die Bestands-UI-Tests, die einen Bon speichern WHEN sie mit `-communityPricesNoticeShown YES` starten THEN erscheint der Hinweis nie und sie bleiben unverändert grün. Test: Klassen `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, `DynamicTypeUITests` im gemeinsamen Lauf; `CommunityShareNoticeUITests` setzt weder dieses Argument noch `-communityPricesSharingEnabled`, sondern nur den Aufräumer in `setUp` und `tearDown` (Prüfung per Durchsicht, Gegenprobe T3 lässt den Aufräumer beim zweiten Start weg)
- **AC-15:** [Beleg] GIVEN die App läuft im Simulator `Restock-Validate` mit frischem Zustand (Aufräumer) WHEN ein gesäter Bon gespeichert, „Nicht teilen“ gewählt und die Einstellungen geöffnet werden THEN zeigt der echte Durchlauf Hinweis, offenen Screen, geschlossenen Screen und ausgeschalteten Schalter. Beleg: Bildschirmfotos und Protokollauszug aus dem echten Lauf unter `docs/artifacts/feat-186-preisteilen-hinweis/`, als Durchlauf-Artefakt registriert (Commit-Kennung und Zeitstempel passend zum Stand).
- **AC-16:** [Unit/UI] GIVEN der Bestand WHEN die Regression läuft THEN bleiben die gesamte Unit-Suite (insbesondere `CommunityPriceTests`, `LocalizationKeyParityTests`) und alle UI-Klassen grün; `RestockShareExtension/` und `SmartCartWidgets/` bleiben unverändert. Test: Unit-Suite und UI-Suite im gemeinsamen Lauf
- **AC-17:** [Gerät, offene Grenze, kein Gate] Auf Hennings Gerät mit TestFlight-Build erscheint der Hinweis beim ersten Speichern. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.

## Known Limitations (offene Grenzen)

- „Preis eintragen“ hat keinen UI-Test; der Eingang ist nur über die Unit-Tests der gemeinsamen Logik (AC-8, AC-11) und
  Durchsicht abgedeckt, weil das Bestandsgerüst keinen Seed für diesen Screen hat.
- App wird beendet, während der Hinweis steht: nichts geteilt, Merker fehlt, der Hinweis kommt beim nächsten Speichern
  wieder; die Beiträge dieses Bons sind verloren (datenschutzseitig sicher, PO-Entscheidung).
- Bestandsnutzer (TestFlight seit #183) sehen den Hinweis einmal, obwohl schon geteilt wurde; kein Merker-Import aus
  früheren Beiträgen.
- Doppeltipp auf „Speichern“ ist als UI-Szenario nicht automatisiert (nur der Guard und die Einmaligkeit der Sendeliste).
- Kein echter CloudKit-Test: Unit-Tests laufen gegen den Fake; der UI-Test T2/T3 sendet bei „Weiter teilen“ im Simulator
  an die Entwicklungsumgebung.
- Nebenbefund, nicht Teil dieses Tickets: Bestands-UI-Tests senden heute bei Standard-Schalter echte Beiträge an die
  CloudKit-Entwicklungsumgebung. Mit dem Merker nicht schlimmer (sie unterdrücken den Hinweis, der Schalter bleibt an);
  eigenes Thema.
- Nichts auf Hennings Geräten geprüft (AC-17).

## Doku-Änderungen

- `docs/specs/services/community-prices.md`, Abschnitt „Offene Grenzen“: Der Punkt „Kein Hinweis nach dem ersten
  Bon-Scan, keine Region, …“ wird um „Kein Hinweis nach dem ersten Bon-Scan“ gekürzt (Rest bleibt: keine Region, kein
  Missbrauchsschutz über Median und Obergrenze hinaus, Weg B als Folge-Issue). Neu dort ein Absatz: „Erst-Hinweis (Issue
  #186): Vor dem ersten Beitrag erscheint einmal ein Hinweis, Beiträge werden bis zur Entscheidung zurückgehalten,
  ‚Nicht teilen‘ schaltet den Schalter aus. Details: `docs/specs/services/community-prices-erst-hinweis.md`.“ Außerdem
  `updated:` auf das Datum der Änderung. Diese Änderung führt der Developer in Phase 6 durch, nicht der Spec-Writer.
- `CLAUDE.md` (Projekt): ein Absatz bei „Community-Preise“ mit dem Merker, dem Aufräumer
  `-clearCommunityPricesNoticeForUITests` und dem Hinweis, dass Bestands-UI-Tests `-communityPricesNoticeShown YES` setzen.

## Risiken / Grenzfälle

- `dismiss()` vor dem `.alert` würde den Hinweis mit dem Sheet entfernen: gelöst durch die Verzweigung am Ende von `save()`.
- Argument-Domain-Falle: Ein Launch-Argument `-communityPricesNoticeShown` überlagert den Wert für den ganzen Lauf, das
  Schreiben des Merkers durch die App ändert den gelesenen Wert dann nicht. Deshalb nur in Bestands-Tests, die nie den
  Hinweis erwarten; die neue Klasse nutzt ausschließlich den Aufräumer. Aufräumer sind für DEBUG-Seeds Pflicht
  (App-Group-/Standard-Defaults überleben den Testlauf), hier in `setUp` und `tearDown`.
- Mehrere Zeilen mit gleichem Artikel in einem Bon: die Sendeliste entspricht heute dem Verhalten je Zeile; der
  Upsert über den Record-Namen bleibt unverändert.
- Neue Swift-Dateien (`CommunityShareNotice.swift`, `CommunityShareNoticeUITests.swift`) müssen in
  `project.pbxproj` an den vier Stellen registriert werden (Projektregel).
- `ReceiptScannerView.save()` ist bereits lang; die Änderung hält es unter den Funktionsgrenzen, indem Sammeln und
  Verzweigen als kleine Hilfsfunktionen ausgelagert werden (Scoping-Limit ≤ 50 Zeilen je Funktion).

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion ist durch Test oder Werkzeug-Artefakt belegt; AC-17 (Gerät) ist als offene Grenze genannt
- [ ] Beim ersten Speichern mit eingeschaltetem Schalter erscheint vor dem Hochladen genau einmal der Hinweis, „Nicht teilen“ hält jeden Preis zurück und schaltet den Schalter aus
- [ ] Die App ist im Simulator gestartet und der geänderte Ablauf durchgespielt (registrierter Durchlauf, AC-15)
- [ ] Regressionslauf grün (AC-14, AC-16)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Kleine Erweiterung des bestehenden Dienstes (#163) mit einem Merker; keine neue Schicht, kein neues
  Modell. Die Entscheidung „Hinweis vor dem Hochladen, Beiträge zurückhalten“ ist PO-Entscheidung vom 2026-10-22
  und oben festgehalten.

## Changelog

- 2026-10-22: Initial spec created (Issue #186, Entwurf A freigegeben)
