import SwiftUI

struct StoreCard: View {
    let store: Store

    private var pendingCount: Int { store.pendingItems.count }
    private var freq: VisitFrequency { VisitFrequency.closest(to: store.visitsPerWeek) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored header band
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center) {
                    Text(store.emoji)
                        .font(.system(size: 34))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(store.color.gradient.opacity(0.15))

                if store.isPaused {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color(.systemGray3), in: Circle())
                        .padding(10)
                } else if pendingCount > 0 {
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
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(store.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                }

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
            .padding(.vertical, 10)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(store.isPaused ? Color(.systemGray4) : store.color.opacity(pendingCount > 0 ? 0.3 : 0.12), lineWidth: 1.5)
        )
        .shadow(color: store.color.opacity(store.isPaused ? 0 : (pendingCount > 0 ? 0.12 : 0.04)), radius: 10, x: 0, y: 4)
        .opacity(store.isPaused ? 0.45 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
