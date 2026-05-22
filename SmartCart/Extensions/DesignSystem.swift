import SwiftUI

// MARK: - Brand colors

extension Color {
    static let brand        = Color(hex: "#007AFF")!
    static let brandDark    = Color(hex: "#0047D8")!
    static let success      = Color(hex: "#34C759")!
    static let warning      = Color(hex: "#FF9500")!
    static let destructive  = Color(hex: "#FF3B30")!
}

// MARK: - Gradients

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [Color(hex: "#0A7CFF")!, Color(hex: "#0047D8")!],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let success = LinearGradient(
        colors: [Color(hex: "#34C759")!, Color(hex: "#248A3D")!],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
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
