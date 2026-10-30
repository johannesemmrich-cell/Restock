# Context: fix-215-paywall-rechtslinks

## Request Summary
Die Paywall (`PaywallView`) zeigt keine Links zu Datenschutzerklärung und Nutzungsbedingungen (EULA). Apple verlangt sie
in der App selbst (Review-Richtlinie 3.1.2), fehlen sie, droht Ablehnung beim Einreichen von Release 1.0 (#175).
Issue #215. Es hat nie funktioniert (fehlende Funktion, keine Verschlechterung).

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Premium/PaywallView.swift` | Einzige Produktdatei. `legalText` (Z. 343–348) trägt nur den Satz zur automatischen Verlängerung; Preise je Abo stehen schon auf den Planbuchstaben (`planCard`, Z. 162–185) |
| `SmartCart/Views/Settings/LegalView.swift` | Enthält `LegalDocument` (privacy/terms/imprint) mit vollem Text in der App; `LegalOverviewView` nur aus den Einstellungen erreichbar |
| `SmartCart/Views/Settings/SettingsView.swift:361`, `Views/Home/HomeView.swift:204` | Die zwei Stellen, die `PaywallView` als Sheet zeigen |
| `RestockUITests/PaywallUITests.swift` | Bestehende Paywall-Tests (5 Fälle, Hilfen `launchLocked`, `assertPaywall`, `scrollTo`); neuer Test gehört hierher |
| `docs/appstore/{de,en}.md` | Store-Texte: Nutzungsbedingungen = Apples Standard-EULA `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`; Datenschutz = `https://emmrich-business.com/datenschutz` |
| `docs/specs/appstore/app-store-auftritt.md`, `b3-betrieb-restschritte.md` | Haupt-Spec #175 (Haupt-Spec gesperrt, nur Changelog); Datenschutzseite des Dritten laut `asc-readback.txt` ok |

## Existing Patterns
- Externe URLs werden mit `UIApplication.shared.open(url)` geöffnet (`SettingsView.swift`), SwiftUI-`Link` wird nirgends benutzt.
- Paywall-Texte sind deutsche Literale im Code, nicht in `Localizable.strings` (en-Fassung der Paywall bleibt also deutsch, nicht Teil dieses Tickets).
- UI-Tests suchen nach angezeigtem Text (keine `accessibilityIdentifier`), Testsprache fest Deutsch.
- Paywall-Tests laufen ohne Premium und bedienen nie den Kauf; `products` ist im Simulator leer.

## Dependencies
- Upstream: `PremiumService` (Preise/Käufe), `LegalDocument`/`LegalView` (falls In-App-Weg).
- Downstream: Zwei Auslöser der Paywall (Home, Einstellungen), UI-Tests `PaywallUITests`, Store-Screenshots (`StoreScreenshotCaptureUITests` zeigt die Paywall – Layoutänderung kann Screenshots betreffen).

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (#175) – nennt Paywall-Links nicht als AC, verweist auf #215.
- `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` – Paywall-Tests, AC-13 offene Grenzen.

## Recherche (mit Quellen)
- Apple Review Guidelines 3.1.2(c): „Ensure you clearly communicate the requirements described in Schedule 2 of the Apple Developer Program License Agreement.“ ([Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- Foren-Fälle: Ablehnungen wegen fehlender Datenschutz-/EULA-Links ([809635](https://developer.apple.com/forums/thread/809635), [813493](https://developer.apple.com/forums/thread/813493), [766296](https://developer.apple.com/forums/thread/766296)). Üblich: Links in der App am Kaufpunkt und in den Store-Daten (Datenschutz-URL-Feld, EULA-Link in der Beschreibung).
- **Nicht belegt:** Wortlaut von Schedule 2 (Lizenzvertrag ~660 000 Zeichen, nicht abrufbar) und ob In-App-Texte statt öffentlicher URLs genügen. Offene Grenze für die Spec; Lösung mit öffentlichen URLs erfüllt beide Lesarten.

## Risks & Considerations
- Die App hat eigene Nutzungsbedingungen (`LegalView`), die Store-Daten nennen Apples Standard-EULA. Zwei Texte würden sich widersprechen; der Paywall-Link muss auf denselben Text zeigen wie die Store-Daten.
- Datenschutz-URL gehört einem Dritten (emmrich-business.com); Erreichbarkeit hängt von ihm ab (laut `asc_check` heute ok).
- Kein Netz: Link öffnet dann nichts (Safari-Fehler). Kein Absturzrisiko.
- Der Lifetime-Kauf ist kein Abo; die Verlängerungs-Zeile gilt nur für Monat/Jahr (Wortlaut prüfen).
- Kleine iPhones: Paywall scrollt, Links müssen am Ende erreichbar sein (Hinweisbereich `noticeView` liegt davor).
- Store-Screenshots mit Paywall müssen nicht neu aufgenommen werden, wenn die Links unterhalb des sichtbaren Bereichs liegen – in der Analyse prüfen.

## Analysis

### Type
Feature (fehlende Funktion, nie vorhanden; Auslöser ist die Ablehnungsgefahr beim Einreichen von 1.0, #175).

### In Bearbeitung (gelesen vor der Empfehlung)
Offene PRs: nur #140 (Bon-Import, Obst/Gemüse), berührt `PaywallView` nicht. Keine Issues „In progress“ gefunden. Kein Konflikt.

### Entwurf (vor der Spec, Regel vom 2026-09-22)
Vorschau mit „Heute“ (Screenshot) und Entwurf hell/dunkel plus Alternative: https://claude.ai/artifact/3jMTcQ89UR7eedCfrcp8XD, Quelle `docs/artifacts/fix-215-paywall-rechtslinks/entwurf-paywall-rechtslinks.src.html`. **Freigegeben: Entwurf A (Henning, 2026-10-30).**

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Premium/PaywallView.swift` | MODIFY | `legalText` (Z. 343–348) um Link-Zeile „Datenschutz · Nutzungsbedingungen (EULA)“ und Abo-Text mit Name, Laufzeit, Preis je Abo erweitern; Links über `Link(destination:)` bzw. bestehendes `UIApplication.shared.open` |
| `RestockUITests/PaywallUITests.swift` | MODIFY | Neuer Test: beide Links vorhanden, antippbar, im Fenster (Helfer `scrollTo`); Link-Ziel prüfbar über Konstanten, kein echter Browseraufruf |
| `RestockTests/…` (optional, neu) | CREATE | Unit-Test, dass die zwei URL-Konstanten mit `docs/appstore/{de,en}.md` übereinstimmen (Drift-Schutz) |

### Scope Assessment
- Files: 2–3
- Estimated LoC: +60/−5
- Risk Level: LOW (isolierte View, keine Daten, kein Schema, keine Berechtigung, keine neuen Schlüssel)

### Technical Approach
1. Zwei URL-Konstanten (Standard-EULA von Apple, Datenschutz-URL) an einer Stelle; Link-Zeile unter „Käufe wiederherstellen“ (Entwurf A). Die Zeile gehört zum Kaufbereich und bleibt im Scrollbereich erreichbar, auch bei großer Schrift (Zeile darf umbrechen).
2. Abo-Text nach Apples Standardwortlaut: Name, Laufzeit (1 Monat/1 Jahr), Preis (aus `productPrice`, damit er dem Store folgt), automatische Verlängerung, Kündigung ≥ 24 h vor Ablauf, Zahlung über Apple-ID. Einmalkauf ausdrücklich „kein Abo“ (steht schon am Plan).
3. Kein neuer String-Schlüssel nötig: Paywall-Texte sind deutsche Literale (Bestand), die en-Fassung der Paywall bleibt außerhalb dieses Tickets.

### Alternativen (Pflicht, mit gekippter Entscheidung)
- **B: Links direkt unter dem Kaufknopf** statt unter „Wiederherstellen“. Näher am Kauf, verschiebt aber „Wiederherstellen“ und die #145-D4-Hinweise (Hinrollen an `noticeScrollID`, F001/F004) — mehr Risiko für bestehende Tests.
- **C: Rechtstexte in der App öffnen** (vorhandene `LegalDocument`-Seiten statt Webseite). Funktioniert ohne Netz, würde aber die eigenen „Nutzungsbedingungen“ der App neben Apples Standard-EULA im Store stellen; beide widersprechen sich. Kippt die Festlegung aus `docs/appstore/{de,en}.md` (Standard-EULA). Nur sinnvoll, wenn Henning eigene Bedingungen will.
- **Kein Modell, keine Regel nötig:** reine Oberfläche, die Regel-vor-Modell-Frage stellt sich nicht.

### Befunde, die gegen den Plan sprechen
- Nicht belegt: Wortlaut Schedule 2 (nicht abrufbar). Lösung mit öffentlichen URLs erfüllt beide Lesarten (In-App-Text oder URL).
- Die Datenschutz-URL gehört einem Dritten und beschreibt die Funktionen laut #175 noch nicht ganz richtig (offene Grenze dort, nicht hier). Ein Link auf eine inhaltlich veraltete Seite besteht die Prüfung formal, bleibt aber ein Produktrisiko.
- Heute-Screenshot stammt aus #145 D4; die Paywall hat sich seitdem nur im Chip geändert.

### Store-Screenshots
`StoreScreenshotCaptureUITests` zeigt die Paywall oben (Plankarten, Kaufknopf). Die neue Zeile liegt darunter, die Screenshots müssen nicht neu aufgenommen werden; in der Spec als Gegenprobe prüfen.

### Dependencies
Upstream: `PremiumService` (Preise). Downstream: `PaywallUITests`, Store-Screenshots. Keine Abhängigkeit zu CloudKit, Manifest oder Privacy-Fragebogen (Links sind keine neue Datenerhebung).

### Open Questions
- [x] Entwurf: A freigegeben (2026-10-30)
- [ ] Datenschutz-URL: bleibt `https://emmrich-business.com/datenschutz` (Dritter), oder soll später die zweisprachige Seite aus `docs/appstore/datenschutz.md` gelten? (Spec nennt die URL aus den Store-Daten als Quelle der Wahrheit.)
