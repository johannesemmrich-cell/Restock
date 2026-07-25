import SwiftUI

/// Antippbare Zeile bereits gekaufter Produktnamen unter einem Name-/Quick-Add-Feld, sichtbar
/// solange es fokussiert ist und der getippte Präfix zu etwas Bekanntem passt (siehe
/// `QuickAddParser.knownProductSuggestions`). Optisch an die Mengen-Chips der Quick-Add-Leiste
/// angelehnt, damit es sich wie dieselbe Interaktionssprache anfühlt.
struct ProductSuggestionChips: View {
    let suggestions: [String]
    let tint: Color
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            Haptics.impact(.light)
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: RCRadius.tag))
                                .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(tint.opacity(0.3)))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
