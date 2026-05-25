import SwiftUI

// MARK: - Filter

private enum StatusFilter: String, CaseIterable {
    case all      = "Alle"
    case open     = "Offen"
    case resolved = "Gelöst"
}

// MARK: - FeedbackListView

struct FeedbackListView: View {
    @AppStorage("devFeedbackItems") private var storedData = Data()
    @State private var statusFilter: StatusFilter = .open
    @State private var priorityFilter: DevFeedbackPriority? = nil
    @State private var selectedItem: DevFeedbackItem? = nil

    private var allItems: [DevFeedbackItem] {
        (try? JSONDecoder().decode([DevFeedbackItem].self, from: storedData))?.sorted { $0.date > $1.date } ?? []
    }

    private var filteredItems: [DevFeedbackItem] {
        allItems.filter { item in
            let statusMatch: Bool = switch statusFilter {
            case .all:      true
            case .open:     !item.isResolved
            case .resolved: item.isResolved
            }
            let priorityMatch = priorityFilter == nil || item.priority == priorityFilter
            return statusMatch && priorityMatch
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
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
        }
        .sheet(item: $selectedItem) { item in
            FeedbackDetailSheet(item: item, onResolve: { resolve(item) }, onDelete: { delete(item) })
        }
    }

    // MARK: Filter Bar

    private var filterBar: some View {
        VStack(spacing: 6) {
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    priorityChip(nil, label: "Alle")
                    ForEach(DevFeedbackPriority.allCases, id: \.self) { p in
                        priorityChip(p, label: p.label)
                    }
                }
            }
        }
    }

    private func priorityChip(_ priority: DevFeedbackPriority?, label: String) -> some View {
        let selected = priorityFilter == priority
        let color: Color = priority?.color ?? .gray
        return Button {
            priorityFilter = selected ? nil : priority
        } label: {
            HStack(spacing: 4) {
                if let p = priority {
                    Image(systemName: p.icon).font(.system(size: 10))
                }
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? color.opacity(0.2) : Color(.systemGray5), in: Capsule())
            .foregroundStyle(selected ? color : .secondary)
            .overlay(Capsule().stroke(selected ? color.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    // MARK: List

    private var list: some View {
        List {
            ForEach(filteredItems) { item in
                FeedbackRow(item: item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedItem = item }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if !item.isResolved {
                            Button { resolve(item) } label: {
                                Label("Erledigt", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        } else {
                            Button { unresolve(item) } label: {
                                Label("Wieder öffnen", systemImage: "arrow.uturn.left.circle.fill")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(item) } label: {
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
        ContentUnavailableView(
            "Kein Feedback",
            systemImage: "checkmark.seal.fill",
            description: Text("Keine Einträge für diesen Filter.")
        )
    }

    // MARK: Mutations

    private func mutate(_ body: (inout [DevFeedbackItem]) -> Void) {
        var items = (try? JSONDecoder().decode([DevFeedbackItem].self, from: storedData)) ?? []
        body(&items)
        storedData = (try? JSONEncoder().encode(items)) ?? Data()
    }

    private func resolve(_ item: DevFeedbackItem) {
        mutate { items in
            if let idx = items.firstIndex(where: { $0.id == item.id }) { items[idx].isResolved = true }
        }
        selectedItem = nil
    }

    private func unresolve(_ item: DevFeedbackItem) {
        mutate { items in
            if let idx = items.firstIndex(where: { $0.id == item.id }) { items[idx].isResolved = false }
        }
    }

    private func delete(_ item: DevFeedbackItem) {
        mutate { items in items.removeAll { $0.id == item.id } }
        selectedItem = nil
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
            Image(systemName: item.priority.icon)
                .font(.system(size: 18))
                .foregroundStyle(item.isResolved ? .secondary : item.priority.color)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(item.text)
                    .font(.body)
                    .foregroundStyle(item.isResolved ? .secondary : .primary)
                    .lineLimit(2)

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

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .opacity(item.isResolved ? 0.6 : 1.0)
    }
}

// MARK: - Detail Sheet

private struct FeedbackDetailSheet: View {
    let item: DevFeedbackItem
    let onResolve: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: item.priority.icon)
                            .font(.title3)
                            .foregroundStyle(item.priority.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.priority.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(item.priority.color)
                            Text(item.context)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.isResolved {
                            Label("Erledigt", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding()
                    .background(item.priority.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                    Text(item.text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    Text(Self.dateFormatter.string(from: item.date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if !item.isResolved {
                            Button { onResolve() } label: {
                                Label("Als erledigt markieren", systemImage: "checkmark.circle")
                            }
                        }
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
