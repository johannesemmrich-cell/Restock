import SwiftUI

// MARK: - Filter

private enum FeedbackFilter: String, CaseIterable {
    case all      = "Alle"
    case open     = "Offen"
    case resolved = "Gelöst"
}

// MARK: - FeedbackListView

struct FeedbackListView: View {
    @AppStorage("devFeedbackItems") private var storedData = Data()
    @State private var filter: FeedbackFilter = .open

    // Decoded items, newest first
    private var allItems: [DevFeedbackItem] {
        let decoded = (try? JSONDecoder().decode([DevFeedbackItem].self, from: storedData)) ?? []
        return decoded.sorted { $0.date > $1.date }
    }

    private var filteredItems: [DevFeedbackItem] {
        switch filter {
        case .all:      return allItems
        case .open:     return allItems.filter { !$0.isResolved }
        case .resolved: return allItems.filter { $0.isResolved }
        }
    }

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Dev-Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            filterPicker
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }

    // MARK: Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(FeedbackFilter.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: List

    private var list: some View {
        List {
            ForEach(filteredItems) { item in
                FeedbackRow(item: item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if !item.isResolved {
                            Button {
                                resolve(item)
                            } label: {
                                Label("Erledigt", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        } else {
                            Button {
                                unresolve(item)
                            } label: {
                                Label("Wieder öffnen", systemImage: "arrow.uturn.left.circle.fill")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label("Löschen", systemImage: "trash.fill")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: filteredItems.map(\.id))
    }

    // MARK: Empty State

    private var emptyState: some View {
        Group {
            switch filter {
            case .all:
                ContentUnavailableView(
                    "Kein Feedback",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Noch keine Einträge vorhanden.")
                )
            case .open:
                ContentUnavailableView(
                    "Alles erledigt",
                    systemImage: "checkmark.circle.fill",
                    description: Text("Keine offenen Feedback-Einträge.")
                )
            case .resolved:
                ContentUnavailableView(
                    "Nichts gelöst",
                    systemImage: "circle.dashed",
                    description: Text("Noch kein Eintrag als erledigt markiert.")
                )
            }
        }
    }

    // MARK: Mutations

    private func mutate(_ body: (inout [DevFeedbackItem]) -> Void) {
        var items = (try? JSONDecoder().decode([DevFeedbackItem].self, from: storedData)) ?? []
        body(&items)
        storedData = (try? JSONEncoder().encode(items)) ?? Data()
    }

    private func resolve(_ item: DevFeedbackItem) {
        mutate { items in
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].isResolved = true
            }
        }
    }

    private func unresolve(_ item: DevFeedbackItem) {
        mutate { items in
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].isResolved = false
            }
        }
    }

    private func delete(_ item: DevFeedbackItem) {
        mutate { items in
            items.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - FeedbackRow

private struct FeedbackRow: View {
    let item: DevFeedbackItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator
            Image(systemName: item.priority.icon)
                .font(.system(size: 18))
                .foregroundStyle(item.isResolved ? .secondary : item.priority.color)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                // Context label
                Text(item.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Feedback text
                Text(item.text)
                    .font(.body)
                    .foregroundStyle(item.isResolved ? .secondary : .primary)
                    .lineLimit(3)

                // Date + resolved badge
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: item.date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if item.isResolved {
                        Label("Erledigt", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .opacity(item.isResolved ? 0.6 : 1.0)
    }
}
