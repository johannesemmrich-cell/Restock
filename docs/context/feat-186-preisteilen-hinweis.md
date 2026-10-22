# Context: feat-186-preisteilen-hinweis

## Request Summary
Seit #183 ist „Preise anonym mit anderen teilen“ voreingestellt an. Beim ersten Beitrag (erster
gespeicherter Bon oder erstes „Preis eintragen“ mit eingeschaltetem Schalter) soll genau einmal ein
Hinweis erscheinen: was geteilt wird, Knöpfe „Weiter teilen“ / „Nicht teilen“.
**PO-Entscheidung 2026-10-22:** Hinweis **vor** dem Hochladen. Bei „Nicht teilen“ verlässt kein Preis
das Gerät, auch nicht der des auslösenden Bons; der Schalter steht danach auf aus.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/CommunityPriceService.swift` | `sharingEnabledKey` (`communityPricesSharingEnabled`, `UserDefaults.standard`, Standard an), `isSharingEnabled(in:)`, `contribute` (prüft Schalter selbst), `contributeInBackground` (Fire-and-forget `Task`). Ort für reine Funktion „Hinweis fällig“ + Merker-Schlüssel. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:754–833` | `save()`: Schleife über Zeilen, je Zeile `ReceiptLearning.learn/apply` und sofort `contributeInBackground` (:791); am Ende `Haptics.success()`, `SyncCoordinator.pushInBackground`, `dismiss()`. Hat bereits `.confirmationDialog` (Ladenwahl, :487) und zwei `.sheet`. |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift:119–166` | `save()` → je Artikel `apply` + `static share(_:in:)` → `contributeInBackground` (:162); danach `dismiss()`. Kein Dialog vorhanden. |
| `SmartCart/Views/Settings/SettingsView.swift:20, 112` | `@AppStorage(sharingEnabledKey)` Schalter; Fußnote `settings.community.footer`. „Nicht teilen“ muss denselben Schlüssel auf `false` setzen, damit der Schalter sofort aus zeigt. |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings:419` | `settings.community.footer` — Textquelle für den Hinweis (laut Issue). Neue Schlüssel für Titel/Knöpfe nötig. |
| `SmartCart/Models/ShoppingItem.swift:534` | Liste von Lokalisierungsschlüsseln, die ein Test auf Vollständigkeit prüft (`CommunityPriceTests.swift:344`). Neue Schlüssel dort ergänzen. |
| `SmartCart/SmartCartApp.swift:30–50, 535` | Muster der DEBUG-Aufräumer: `private static func clear…ForUITestsIfNeeded()` mit `ProcessInfo.processInfo.arguments.contains("-…ForUITests")` → `UserDefaults.standard.removeObject`. Hier `-clearCommunityPricesNoticeForUITests`. |
| `SmartCart/Views/Settings/LegalView.swift:79–80` | Datenschutzabschnitt „Community-Preise“, bleibt unverändert. |
| `RestockTests/CommunityPriceTests.swift` | Bestehende Unit-Tests mit Fake-DB; Ort für „Hinweis fällig“-Tests. |
| `RestockUITests/ReceiptReviewUITests.swift` | Seed `-seedReceiptReviewForUITests`, `openedReviewSheet()`; 5 Tests tippen „Speichern“ (:695, :728, :752, :796, :844). |
| `RestockUITests/ReceiptResolutionStatsUITests.swift:101`, `DynamicTypeUITests.swift:189` | Weitere Bestands-Tests, die einen Bon speichern. |
| `SmartCart/Views/Store/StoreDetailView.swift:564` | Einstieg „Preis eintragen“. |
| `docs/specs/services/community-prices.md` | Bestehende Spec zu Weg A; Abschnitt „Offene Grenzen“ nennt fehlenden Erst-Hinweis. Wird ergänzt. |

## Existing Patterns
- UserDefaults-Merker + DEBUG-Aufräumer per Launch-Argument (`clearDeveloperModeForUITestsIfNeeded`).
- Entscheidungen als reine statische Funktionen mit `UserDefaults`-Parameter (`isSharingEnabled(in:)`), testbar mit eigener Suite.
- Dialoge als `.confirmationDialog`/`.alert` direkt am Screen (`ReceiptScannerView:487`).
- Haptik nur über `Haptics.*`; Texte über `String(localized:)`.
- Argument-Domain-Falle: Ein Launch-Argument `-<key> <wert>` überdeckt `UserDefaults` für den ganzen Lauf; Schreiben ändert den gelesenen Wert dann nicht. Deshalb nie `-communityPricesSharingEnabled` als Argument.

## Dependencies
- Upstream: `UserDefaults.standard`, `CommunityPriceService.shared`, SwiftUI-Dialoge.
- Downstream: Settings-Schalter (liest denselben Schlüssel), Bestands-UI-Tests, die speichern.

## Existing Specs
- `docs/specs/services/community-prices.md` (Weg A, #163/#183)
- `docs/specs/views/receipt-review-card.md`, `receipt-save-purchase-quantity.md` (Speichern-Pfad)

## Risks & Considerations
- **Beitrag muss bis zur Entscheidung zurückgehalten werden.** Heute geht jeder Beitrag einzeln in der Schleife raus. Beim ersten Mal: Beiträge sammeln, Dialog zeigen, erst nach „Weiter teilen“ senden, nach „Nicht teilen“ verwerfen. Lokales Lernen (Preise, Kaufdatensätze, Sync-Push) darf nicht warten oder sich ändern.
- **`dismiss()` erst nach der Entscheidung**, sonst verschwindet der Dialog mit dem Sheet. Danach schließt der Screen wie heute.
- **Abbruch-Fälle:** Wird die App während des Dialogs beendet, ist nichts geteilt und der Merker nicht gesetzt → Hinweis kommt beim nächsten Mal wieder. Passt zur PO-Entscheidung.
- **Zwei Eingänge**, dieselbe Regel: Bon-Prüf-Screen und „Preis eintragen“. Der Bon-Weg über die Teilen-Erweiterung endet ebenfalls im Bon-Prüf-Screen der App (Erweiterung selbst teilt nichts, `grep contributeInBackground`).
- **Bestands-UI-Tests brechen**, sobald nach „Speichern“ ein Dialog steht (mind. 7 Tests in 3 Dateien). Sie brauchen einen gesetzten Merker. Ein Launch-Argument `-communityPricesNoticeShown YES` unterdrückt per Argument-Domain zuverlässig, ohne Reihenfolge-Abhängigkeit; Alternative: Tests tippen den Hinweis weg.
- **Kein Beitrag ohne Inhalt:** Hat der Bon keine teilbare Zeile (Preis 0, Kette leer), soll kein Hinweis kommen. „Fällig“ also nur, wenn mindestens ein brauchbarer Beitrag vorliegt.
- Nebenbefund (nicht Teil dieses Tickets): Bestands-UI-Tests senden heute bei Standard an echte Beiträge an die CloudKit-Entwicklungsumgebung. Wird mit dem Merker nicht schlimmer; eigenes Thema.
- UI-Änderung → laut globaler Regel Vorschau-Artefakt in `/20-analyse` unter `docs/artifacts/feat-186-preisteilen-hinweis/` vor der Spec.

## Analysis

### Type
Feature

### PO-Entscheidungen (2026-10-22, nach Entwurfsvorschau)
- **Entwurf A: Systemhinweis** (SwiftUI `.alert`), Titel „Preise anonym teilen?“, ein Text, Knöpfe „Weiter teilen“ (Standard) / „Nicht teilen“. Vorschau: `docs/artifacts/feat-186-preisteilen-hinweis/entwurfsvorschau.html` (https://claude.ai/artifact/NP63V21WH9udA4nuC8PTzp), Alternative B (Karte von unten) verworfen.
- **Ein Durchgang**, beide Eingänge (Bon speichern und „Preis eintragen“); Umfang ~11 Dateien / ~290 LoC (≈145 Produktiv inkl. Texte) **freigegeben**.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/CommunityPriceService.swift` | MODIFY | `noticeShownKey = "communityPricesNoticeShown"`; `Contribution.isShareable` (Guards aus `contribute` herausgezogen, `contribute` nutzt sie); `static noticeDue(_:in:)` (Schalter an, Merker fehlt, ≥1 teilbarer Beitrag); `static recordNoticeDecision(share:in:)` (Merker true, bei Nein Schalter false); `contributeInBackground([Contribution])` |
| `SmartCart/Views/Prices/CommunityShareNotice.swift` | CREATE | ViewModifier `.communityShareNotice(pending:onFinished:)` mit dem `.alert`; pbxproj-Eintrag (App-Ziel) |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `save()` sammelt Beiträge statt je Zeile zu senden; am Ende `noticeDue` → `pendingShare` setzen, kein `dismiss()`; sonst senden + `dismiss()`; `guard pendingShare == nil` gegen Doppeltipp; Lernen/Apply/PurchaseRecord/Haptik/Sync-Push unverändert und sofort |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | MODIFY | `share(_:in:)` → `contribution(for:in:) -> Contribution?`, Sammeln in beiden Zweigen von `save()`, gleiche Verzweigung |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Aufräumer `-clearCommunityPricesNoticeForUITests` (entfernt Merker und Schalter-Schlüssel) |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | MODIFY | Titel, Text, zwei Knöpfe |
| `SmartCart/Models/ShoppingItem.swift:534` | MODIFY | neue Schlüssel in die geprüfte Liste |
| `RestockTests/CommunityPriceTests.swift` | MODIFY | Unit-Tests `noticeDue`, `recordNoticeDecision`, Senden/Verwerfen mit Fake-DB |
| `RestockUITests/CommunityShareNoticeUITests.swift` | CREATE | Speichern → Hinweis, Screen offen → „Nicht teilen“ → Screen zu, Schalter in Einstellungen aus; Gegenprobe „Weiter teilen“ und zweites Speichern ohne Hinweis |
| `RestockUITests/{ReceiptReviewUITests,ReceiptResolutionStatsUITests,DynamicTypeUITests}.swift` | MODIFY | Launch-Argument `-communityPricesNoticeShown YES` (unterdrückt den Hinweis, Argument-Domain) |
| `docs/specs/services/community-prices.md` | MODIFY | Offene Grenze „kein Hinweis“ ersetzen, Verweis auf neue Spec |

### Scope Assessment
- Files: ~11 (+ pbxproj)
- Estimated LoC: ≈ +290 / −10 (Produktiv ≈145, Tests ≈140)
- Risk Level: MEDIUM — ändert den Speichern-Ablauf des Bon-Prüf-Screens (Bestands-UI-Tests), Logik selbst klein

### Technical Approach
Reine Entscheidung im Service (testbar mit eigener `UserDefaults`-Suite), Sammeln in beiden Views, ein gemeinsamer ViewModifier mit `.alert`. `dismiss()` erst nach der Entscheidung (sonst verschwindet der Hinweis mit dem Sheet). „Nicht teilen“ verwirft die gesammelten Beiträge und setzt den Schalter aus; `contribute` prüft den Schalter weiter selbst (zweite Sicherung).

### Alternativen
- Alternative B (eigenes Sheet): verworfen vom PO.
- Hinweis im Dienst selbst (Warteschlange in `CommunityPriceService`, Dialog global in `HomeView`): entkoppelt die Views, braucht aber globalen Zustand und einen Dialog fern vom auslösenden Screen — nicht gewählt.
- Bestands-UI-Tests den Hinweis wegtippen lassen statt Launch-Argument: verlängert jeden Test, nicht gewählt.

### Risiken / Grenzfälle
- `dismiss()` vor dem Alert → gelöst durch Verzweigung.
- Doppeltipp auf Speichern → `guard`.
- App beendet während Hinweis → nichts geteilt, Merker fehlt, Hinweis kommt wieder; Beiträge dieses Bons verloren (datenschutzseitig sicher).
- Bestandsnutzer (TestFlight seit #183) sehen den Hinweis einmal, obwohl schon geteilt wurde — so in die Spec.
- Neuer UI-Test darf `-communityPricesNoticeShown` nicht setzen (Argument-Domain); nutzt Aufräumer im setUp/tearDown, der auch den Schalter zurücksetzt.
- „Preis eintragen“ hat keinen UI-Test; abgedeckt durch Unit-Tests der gemeinsamen Logik.

### Dependencies
`UserDefaults.standard`, `CommunityPriceService.shared` (nur App-Ziel; Teilen-Erweiterung teilt nichts selbst, endet im `ReceiptScannerView` der App), SwiftUI `.alert`. Settings-Schalter liest denselben Schlüssel per `@AppStorage` → zeigt nach „Nicht teilen“ sofort aus.

### Open Questions
- keine (Entwurf und Umfang vom PO entschieden)
