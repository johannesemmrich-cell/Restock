# „Schließen“-Chip zeigt „…“ — Ursache und Fix (#145 Durchgang 4, AC-14/AC-15)

Stand 2026-10-19, Simulator `Restock-Validate` (iOS 26.5, iPhone, 402 pt breit), Xcode 27.1.

## Ergebnis in zwei Sätzen

iOS 26 fragt Toolbar-Items am linken Rand (hier `.cancellationAction`) mit der vorgeschlagenen Breite 0 an
und übernimmt die Antwort als endgültige Breite; `ToolbarChipModifier` antwortet darauf wegen
`.frame(minWidth: 40)` mit genau 40 pt, und der Text (mit `lineLimit(1)`) wird in diesen 40 pt zu „…“ gekürzt.
Behoben in `ToolbarChipModifier` mit `.fixedSize(horizontal: true, vertical: false)` direkt nach dem
Rahmen: Der Chip meldet dann immer seine natürliche Breite (99 pt für „Schließen“).

## Recherche (vor der Ursachensuche)

- Apple-Dokumentation `sharedBackgroundVisibility(_:)`: blendet nur den geteilten Glas-Hintergrund aus
  und legt das Item in eine eigene Gruppe; über die Breite sagt sie nichts.
  https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:)
- Sarunw, „When toolbar items share a glass background in iOS 26“ (08.10.2026): Gruppierung linker/rechter
  Rand, Titel getrennt; kein Hinweis auf Kürzung.
  https://sarunw.com/posts/swiftui-toolbar-item-grouping-ios-26/
- Stack Overflow „Ellipsis getting added in the toolbar text when font is set on attributed string“
  (Frage 79501619) und Fatbobman „Fixing Text Truncation in SwiftUI: From fixedSize to ViewThatFits“:
  gleiches Symptom (Toolbar-Text wird zu „…“), Abhilfe `fixedSize`. Seite von Stack Overflow war aus der
  Shell nicht lesbar (Captcha), nur Titel und Suchtreffer.
  https://stackoverflow.com/questions/79501619 ·
  https://fatbobman.com/en/snippet/ensuring-full-text-display-in-swiftui-techniques-and-solutions/
- Eine Quelle, die das Vorschlagsverhalten des iOS-26-Navigationsbalkens (Breite 0 für linke Items)
  ausdrücklich beschreibt, wurde nicht gefunden; es ist unten **gemessen**, nicht aus der Literatur.

## Nachstellen (vor jedem Fix)

Sonde: Wegwerf-UI-Test in einer Kopie des Arbeitsstands (Produktcode unverändert), öffnet Paywall
(`fork.knife` gesperrt), Rezeptplan (`-premiumForScreenshots`) und Einstellungen, hell und dunkel, misst
die Rahmen der Chips im Navigationsbalken. Messwerte: `chip-sonde-messwerte.log`.

| Stelle | Platzierung | vorher | nachher |
|---|---|---|---|
| Paywall „Schließen“ | `.cancellationAction` (links) | 40 × 38 pt, „…“ | 99 × 38 pt |
| Rezeptplan „Schließen“ | `.cancellationAction` (links) | 40 × 38 pt, „…“ | 99 × 38 pt |
| Rezeptplan „Alle hinzufügen“ | `.confirmationAction` (rechts) | 139,3 × 38 pt | 139,3 × 38 pt |
| Einstellungen „Fertig“ | `.confirmationAction` (rechts) | 70,3 × 38 pt | 70,3 × 38 pt |

Hell und dunkel jeweils gleich. Screenshots: `chip-vorher-hell.png`, `chip-vorher-dunkel.png`,
`chip-vorher-rezeptplan-hell.png`, `chip-vorher-einstellungen-hell.png`; nachher `chip-nachher-hell.png`,
`chip-nachher-dunkel.png`, `chip-nachher-rezeptplan-hell.png`, `chip-nachher-einstellungen-hell.png`.

**Wichtiger Befund:** Der Fehler betrifft nicht nur die Paywall. Der Rezeptplan hat denselben Chip mit
demselben Wort an derselben Platzierung und war ebenso kaputt. Die Vergleichsstelle aus der Spec („eine
Stelle, an der ‚Schließen‘ funktioniert“) gibt es deshalb nicht; funktionierende Chips sitzen alle rechts.

## Kandidaten aus der Spec, je mit Experiment

1. **`.sharedBackgroundVisibility(.hidden)` in `ChipToolbarItem`** — Experiment: Zeile entfernt, sonst
   unverändert. Ergebnis: Paywall und Rezeptplan weiter 40 pt. **Nicht die Ursache.**
2. **`.buttonStyle(.pressable)` an der Paywall-Stelle** — keine Ursache: Der rechte Rezeptplan-Chip
   „Alle hinzufügen“ trägt denselben Stil und wird voll breit dargestellt; der linke Rezeptplan-Chip mit
   demselben Stil ist kaputt. Unterscheidend ist die Seite, nicht der Stil.
3. **Zu schmal vorgeschlagene Breite + `lineLimit(1)`/`minimumScaleFactor(0.75)`/`frame(minWidth: 40)`
   in `ToolbarChipModifier`** — Experiment: Ein Mess-Layout um den Chip protokollierte jeden
   Größenvorschlag des Systems und die Antwort (`chip-sonde-vorschlaege.log`, Chip mit Idealbreite 99 pt):
   - linker Chip: Vorschlag `w=0, h=0` → Antwort 40 pt, danach Platzierung mit `w=40` → 40 pt;
   - rechter Chip („Alle hinzufügen“): erst `w=0` → 40, danach aber Vorschlag in Idealbreite `w=139,3`.
   Das System fragt also das linke Item mit Breite 0 an und setzt die Antwort als Breite. **Ursache.**

## Fix-Versuche

- Versuch 1: `.fixedSize(horizontal: true, vertical: false)` direkt am Text (vor dem Innenabstand).
  Ergebnis: weiter 40 pt; der Text lief über den 40-pt-Rahmen hinaus (Screenshot in der Sonde). Grund:
  `.frame(minWidth: 40)` ohne `maxWidth` antwortet auf den Vorschlag 0 mit 40, unabhängig vom Inhalt.
- Versuch 2 (übernommen): `.fixedSize(horizontal: true, vertical: false)` **nach** `.frame(minWidth: 40,
  minHeight: 38)`, vor Hintergrund und Rahmenlinie. Der ganze Chip meldet seine natürliche Breite; Ergebnis
  siehe Tabelle. Gegenprobe vorher: nur die Paywall-Stelle mit `.fixedSize()` → Paywall 99 pt, Rezeptplan
  (ohne) weiter 40 pt.

`minimumScaleFactor(0.75)` bleibt stehen, wirkt im Navigationsbalken aber nicht mehr (der Text bekommt
stets seine Idealbreite). Sehr lange Beschriftungen würden nun nicht mehr verkleinert, sondern breiter.

## Seiteneffekt (Änderung in `DesignSystem.swift`)

Alle Nutzer von `toolbarChip` sind betroffen. Gemessen/gesehen: Paywall, Rezeptplan (links und rechts),
Einstellungen „Fertig“ — rechts unverändert, links jetzt voll lesbar. Weitere Nutzer (nicht einzeln per
Screenshot geprüft; nach dem Messbefund erwartet: links bisher „…“, jetzt voll; rechts unverändert):

- links (`.cancellationAction`/`.navigationBarLeading`): `StoreSetupView` (Emoji-Sheet „Abbrechen“, Laden
  hinzufügen „Abbrechen“), `ActualPriceEntryView`, `ReceiptScannerView`, `MenuPlanView` (Tag hinzufügen,
  Rezept wählen), `RecipeImportView`, `BarcodeScannerView`, `FeedbackView`, `StoreShareSheet` (Beitreten),
  `EditItemView`, `StoreDetailView` (Zeile 1391), `AddItemView`, `AllItemsView` (`.navigationBarLeading`);
- rechts (`.confirmationAction`/`.navigationBarTrailing`): `BrowseStoresView`, `SettingsView`,
  `AllItemsView`, `StoreSetupView`, `ActualPriceEntryView`, `PriceOverviewView`, `ReceiptScannerView`,
  `MenuPlanView`, `RecipeImportView`, `FeedbackView`, `StoreShareSheet`, `EditItemView`,
  `StoreDetailView` (Zeile 504), `AddItemView`.

Offen: nur iOS 26.5 gemessen (iOS 27 und iOS 18 nicht), nur ein iPhone-Format.
