import ActivityKit
import WidgetKit
import SwiftUI

struct ShoppingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Text(context.attributes.storeEmoji)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.storeName)
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(context.state.completedCount) von \(context.state.totalCount) erledigt")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    let progress = context.state.totalCount > 0
                        ? Double(context.state.completedCount) / Double(context.state.totalCount)
                        : 0.0
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: progress)
                    }
                    .frame(width: 38, height: 38)
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let next = context.state.nextItemName {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nächster Artikel")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(next)
                                    .font(.system(size: 17, weight: .semibold))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(intent: CheckOffItemIntent(storeName: context.attributes.storeName)) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.green)
                                    .symbolEffect(.bounce, value: next)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                    } else {
                        Label("Alle erledigt! 🎉", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.vertical, 8)
                    }
                }
            } compactLeading: {
                Text(context.attributes.storeEmoji)
                    .font(.system(size: 16))
            } compactTrailing: {
                Text("\(context.state.completedCount)/\(context.state.totalCount)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            } minimal: {
                Text(context.attributes.storeEmoji)
            }
            .keylineTint(.green)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<ShoppingActivityAttributes>

    private var progress: Double {
        guard context.state.totalCount > 0 else { return 0 }
        return Double(context.state.completedCount) / Double(context.state.totalCount)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(context.attributes.storeEmoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(context.attributes.storeName)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(context.state.completedCount) / \(context.state.totalCount)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if let next = context.state.nextItemName {
                    Text(next)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.easeInOut, value: progress)
                    }
                }
                .frame(height: 4)
            }

            if context.state.nextItemName != nil {
                Button(intent: CheckOffItemIntent(storeName: context.attributes.storeName)) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
    }
}
