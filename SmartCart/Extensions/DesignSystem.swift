import SwiftUI

// MARK: - Design tokens ("Vorratskammer statt Tech-Demo")
//
// Alle Farben kommen aus Assets.xcassets Color Sets (Any + Dark), keine Hex-Werte hier.
// `accent` ist die einzige Markenfarbe (Oliv, identisch zur Restock-Markenfarbe der Website);
// `amber` ist ausschließlich für Nachkauf-Dringlichkeit, `danger` für destruktive Aktionen.

extension Color {
    static let canvas          = Color("RCCanvas")
    static let surface         = Color("RCSurface")
    static let ink             = Color("RCInk")
    static let textSecondary   = Color("RCTextSecondary")
    static let hairline        = Color("RCHairline")
    static let hairlineStrong  = Color("RCHairlineStrong")
    static let accent          = Color("RCAccent")
    static let accentContainer = Color("RCAccentContainer")
    static let heroSurface     = Color("RCHeroSurface")
    static let heroText        = Color("RCHeroText")
    static let buttonPrimary   = Color("RCButtonPrimary")
    static let onButton        = Color("RCOnButton")
    static let amber           = Color("RCAmber")
    static let danger          = Color("RCDanger")

    // Beibehaltene Namen für minimale Call-Site-Änderungen an bestehenden Stellen, die
    // semantisch "Warnung"/"destruktiv" meinen (Nachkauf-Dringlichkeit / Löschen) — zeigen
    // jetzt auf die neuen Tokens statt auf die alten Blau-Verlauf-Ära-Hex-Werte.
    static let warning     = amber
    static let destructive = danger
}

// MARK: - Radien

enum RCRadius {
    static let tag: CGFloat = 6
    static let control: CGFloat = 10
    static let card: CGFloat = 14
    static let hero: CGFloat = 20
    static let sheet: CGFloat = 24
}

// MARK: - Wordmark

extension Font {
    /// Clash Display Semibold — ausschließlich für den Schriftzug "Restock" im Banner (Spec §2).
    /// Fällt automatisch auf SF Pro Semibold zurück, falls die Schriftdatei nicht im Bundle
    /// registriert ist (z. B. `xcodegen generate` noch nicht gelaufen).
    static func wordmark(_ size: CGFloat) -> Font {
        .custom("ClashDisplay-Semibold", size: size, relativeTo: .title)
    }
}

// MARK: - Läden-Ansicht (V5) / Sortierung (V6)

enum StoreViewMode: String {
    case cards, list
}

// MARK: - Visit frequency

enum VisitFrequency: Double, CaseIterable, Identifiable {
    case monthly   = 0.25
    case biMonthly = 0.5
    case weekly    = 1.0
    case twice     = 2.0
    case three     = 3.0
    case four      = 4.0
    case five      = 5.0
    case daily     = 7.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .monthly:   return String(localized: "frequency.monthly")
        case .biMonthly: return String(localized: "frequency.bimonthly")
        case .weekly:    return String(localized: "frequency.weekly")
        case .twice:     return String(localized: "frequency.twice")
        case .three:     return String(localized: "frequency.three")
        case .four:      return String(localized: "frequency.four")
        case .five:      return String(localized: "frequency.five")
        case .daily:     return String(localized: "frequency.daily")
        }
    }

    static func closest(to value: Double) -> VisitFrequency {
        allCases.min(by: { abs($0.rawValue - value) < abs($1.rawValue - value) }) ?? .weekly
    }
}

// MARK: - Card style
//
// Ebene 0 (Spec §4): Flächen im Seitenfluss bekommen eine Haarlinie, keinen Schatten. Schatten
// ist reserviert für den Restock-Banner (Ebene 1) und aufgeklappte Karten/Sheets (Ebene 2) —
// die setzen ihren Schatten direkt an ihrer eigenen View, nicht über diesen Modifier.

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RCRadius.card)
                    .strokeBorder(Color.hairline)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Primary button style
//
// Ink auf Papier (Light) / Bone auf Tinte (Dark) — bewusst NICHT die Akzentfarbe, kein Capsule.

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.onButton)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Color.buttonPrimary, in: RoundedRectangle(cornerRadius: 13))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var restockPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

// MARK: - Pressable (Anklick-Feedback für handgebaute Row-/Chip-Buttons)
//
// `.plain` unterdrückt SwiftUI's Standard-Press-Highlight komplett — in dieser App fast überall
// spürbar, da die meisten "Zeilen" (Settings-Rows, Toolbar-Chips, Karten) handgebaute
// Button{}.buttonStyle(.plain)-Konstruktionen statt echter List-Rows sind. Bewusst NUR Opacity
// (kein Hintergrund/Radius wie bei PrimaryButtonStyle), damit der Style mit jeder Art von
// Label-Inhalt (Icon, Chip, Karte) funktioniert, ohne optisch zu kollidieren.
struct PressableButtonStyle: ButtonStyle {
    // `.plain` ist ein PrimitiveButtonStyle und dimmt disabled-Buttons automatisch mit — ein
    // eigener ButtonStyle bekommt das NICHT geschenkt und muss `isEnabled` selbst auswerten,
    // sonst sehen deaktivierte Buttons (z. B. "Speichern" ohne gültige Eingabe) plötzlich genauso
    // tappable aus wie aktive.
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Toolbar chips
//
// Eckige Chips (Radius 11, Surface + Haarlinie bzw. Tinte/Bone für die Primäraktion) statt der
// runden System-Capsules. `ChipToolbarItem` blendet dafür auf iOS 26 den automatischen
// Liquid-Glass-Hintergrund des Items aus; auf iOS 18 bleibt das Systemverhalten bestehen.

struct ToolbarChipModifier: ViewModifier {
    var prominent = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(prominent ? Color.onButton : Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .frame(minWidth: 40, minHeight: 38)
            .background(
                prominent ? Color.buttonPrimary : Color.surface,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: 11).strokeBorder(Color.hairline)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11))
    }
}

extension View {
    func toolbarChip(prominent: Bool = false) -> some View {
        modifier(ToolbarChipModifier(prominent: prominent))
    }
}

/// ToolbarItem ohne System-Glass-Hintergrund, damit `toolbarChip` die Form bestimmt.
struct ChipToolbarItem<L: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let label: () -> L

    init(placement: ToolbarItemPlacement, @ViewBuilder label: @escaping () -> L) {
        self.placement = placement
        self.label = label
    }

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement) { label() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) { label() }
        }
    }
}

// MARK: - Elevation (Spec §4)
//
// Nur zwei Stellen in der App bekommen überhaupt einen Schatten: der Restock-Banner
// (eingeklappt, Ebene 1) und die aufgeklappte Detailkarte/Sheets (Ebene 2). Alles andere
// bekommt eine Haarlinie (siehe CardModifier oben).

extension View {
    /// Schatten-Ebene 1 — ausschließlich der eingeklappte Restock-Banner.
    @ViewBuilder
    func heroShadow(_ colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            shadow(color: .black.opacity(0.45), radius: 15, x: 0, y: 10)
        } else {
            shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
        }
    }

    /// Schatten-Ebene 2 — aufgeklappte Restock-Detailkarte, Sheets, Popover.
    @ViewBuilder
    func overlayShadow(_ colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 24)
        } else {
            shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 24)
        }
    }
}

// MARK: - Haptics

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
