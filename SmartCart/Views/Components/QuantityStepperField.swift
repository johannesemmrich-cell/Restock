import SwiftUI

/// A reusable stepper field that combines – / + buttons with a directly editable TextField.
/// Step size is derived from the current unit:
///   "g"        → 50
///   "kg", "l"  → 0.5
///   everything else → 1
struct QuantityStepperField: View {
    @Binding var quantity: String
    @Binding var unit: String

    @FocusState private var isFocused: Bool

    // MARK: - Step size

    private var step: Double {
        switch unit.lowercased() {
        case "g":       return 50
        case "kg", "l": return 0.5
        default:        return 1
        }
    }

    // MARK: - Helpers

    /// Parses the current quantity string to a Double, accepting both comma and dot.
    private var currentValue: Double {
        Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Formats a Double back to a clean string (no trailing ".0" for whole numbers).
    private func formatted(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        // One decimal place for fractional steps (0.5, etc.)
        return String(format: "%.1f", value)
    }

    // MARK: - Actions

    private func decrement() {
        isFocused = false
        let newValue = max(0, currentValue - step)
        quantity = formatted(newValue)
    }

    private func increment() {
        isFocused = false
        let newValue = currentValue + step
        quantity = formatted(newValue)
    }

    // MARK: - View

    var body: some View {
        HStack(spacing: 8) {
            Button {
                decrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .disabled(currentValue <= 0)

            TextField("1", text: $quantity)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 44, maxWidth: 80)
                .focused($isFocused)
                // Normalize comma → dot on every edit so parsing stays robust
                .onChange(of: quantity) { _, newValue in
                    let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                    if normalized != newValue {
                        quantity = normalized
                    }
                }

            Button {
                increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var qty = "1"
    @Previewable @State var unit = ""

    VStack(spacing: 24) {
        // Default (piece) — step 1
        QuantityStepperField(quantity: $qty, unit: $unit)
            .padding(.horizontal)

        // Grams — step 50
        QuantityStepperField(
            quantity: .constant("200"),
            unit: .constant("g")
        )
        .padding(.horizontal)

        // kg / l — step 0.5
        QuantityStepperField(
            quantity: .constant("1.5"),
            unit: .constant("kg")
        )
        .padding(.horizontal)
    }
    .padding(.vertical)
}
