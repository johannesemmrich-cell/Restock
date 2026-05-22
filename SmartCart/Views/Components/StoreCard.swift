import SwiftUI

struct StoreCard: View {
    let store: Store
    var onTap: () -> Void = {}

    private var pendingCount: Int { store.pendingItems.count }
    private var freq: VisitFrequency { VisitFrequency.closest(to: store.visitsPerWeek) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored header band
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center) {
                    Text(store.emoji)
                        .font(.system(size: 36))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(store.color.gradient.opacity(0.18))

                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(store.color, in: Capsule())
                        .padding(10)
                }
            }

            // Info section
            VStack(alignment: .leading, spacing: 6) {
                Text(store.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(freq.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if pendingCount > 0 {
                    let preview = store.pendingItems.prefix(2).map { $0.name }.joined(separator: ", ")
                    Text(preview + (pendingCount > 2 ? " +\(pendingCount - 2)" : ""))
                        .font(.system(size: 12))
                        .foregroundStyle(store.color)
                        .lineLimit(1)
                } else {
                    Text(String(localized: "store.empty"))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(store.color.opacity(pendingCount > 0 ? 0.35 : 0.15), lineWidth: 1.5)
        )
        .shadow(color: store.color.opacity(pendingCount > 0 ? 0.14 : 0.05), radius: 10, x: 0, y: 4)
    }
}
