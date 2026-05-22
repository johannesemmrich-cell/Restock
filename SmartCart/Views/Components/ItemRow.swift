import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    var onToggle: () -> Void

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: {
                onToggle()
                if !item.isCompleted { isAnimating = true }
            }) {
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? Color.success : Color.clear)
                        .frame(width: 26, height: 26)
                    Circle()
                        .stroke(item.isCompleted ? Color.success : Color(.systemGray3), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAnimating)
                .onChange(of: isAnimating) { _, val in
                    if val { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isAnimating = false } }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 16))
                    .foregroundStyle(item.isCompleted ? .tertiary : .primary)
                    .strikethrough(item.isCompleted, color: Color(.tertiaryLabel))

                HStack(spacing: 6) {
                    if item.quantity != "1" || !item.unit.isEmpty {
                        Text("\(item.quantity)\(item.unit.isEmpty ? "" : " \(item.unit)")")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !item.category.isEmpty {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.quaternary)
                        Text(item.category)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if let price = item.estimatedPrice, !item.isCompleted {
                Text(price, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.25), value: item.isCompleted)
    }
}
