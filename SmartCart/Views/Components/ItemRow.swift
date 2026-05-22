import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isCompleted ? .green : Color(.systemGray3))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16))
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)

                HStack(spacing: 8) {
                    if !item.quantity.isEmpty && item.quantity != "1" {
                        Text("\(item.quantity)\(item.unit.isEmpty ? "" : " \(item.unit)")")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if let price = item.estimatedPrice {
                Text("~\(price, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.2), value: item.isCompleted)
    }
}
