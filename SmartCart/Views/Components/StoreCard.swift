import SwiftUI

struct StoreCard: View {
    let store: Store
    var onTap: () -> Void

    private var pendingCount: Int { store.pendingItems.count }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.emoji)
                        .font(.system(size: 32))
                    Spacer()
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.color, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(visitLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if pendingCount > 0 {
                    Divider()
                    let preview = store.pendingItems.prefix(2).map { $0.name }.joined(separator: ", ")
                    Text(preview + (pendingCount > 2 ? " +\(pendingCount - 2)" : ""))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(String(localized: "store.empty"))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(store.color.opacity(0.25), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var visitLabel: String {
        let v = store.visitsPerWeek
        if v <= 0 { return String(localized: "store.visits.rarely") }
        if v < 1 { return String(localized: "store.visits.biweekly") }
        let count = Int(v.rounded())
        return String(format: String(localized: "store.visits.perweek"), count)
    }
}
