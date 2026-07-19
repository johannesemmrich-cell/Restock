import SwiftUI

struct StoreCard: View {
    let store: Store
    @Environment(\.colorScheme) private var colorScheme

    private var pendingCount: Int { store.pendingItems.count }
    private var freq: VisitFrequency { VisitFrequency.closest(to: store.visitsPerWeek) }
    private var isShared: Bool { store.shareID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: RCRadius.control)
                    .fill(Color.accentContainer)
                    .frame(width: 40, height: 40)
                Image(systemName: store.iconSystemName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .frame(width: 40, height: 40)
                if store.isPaused {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.canvas)
                        .padding(3)
                        .background(Color.accent, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }
            .padding(.bottom, 16)

            HStack(spacing: 6) {
                Text(store.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if pendingCount > 0 {
                    Text("· \(pendingCount)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }
                if isShared {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }
            }

            Text(freq.label)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 3)

            Group {
                if pendingCount > 0 {
                    let preview = store.pendingItems.prefix(2).map { $0.name }.joined(separator: ", ")
                    Text(preview + (pendingCount > 2 ? "…" : ""))
                        .foregroundStyle(Color.accent)
                } else {
                    Text(String(localized: "store.empty"))
                        .foregroundStyle(Color.textSecondary.opacity(0.7))
                }
            }
            .font(.system(size: 13.5))
            .lineLimit(1)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RCRadius.card)
                .strokeBorder(Color.hairline)
        )
        .opacity(store.isPaused ? 0.55 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: RCRadius.card))
    }
}
