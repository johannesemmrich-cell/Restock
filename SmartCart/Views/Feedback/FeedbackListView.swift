import SwiftUI
import SwiftData

struct FeedbackListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedbackItem.createdAt, order: .reverse)
    private var allFeedback: [FeedbackItem]

    @State private var statusFilter: StatusFilter = .offen
    @State private var priorityFilter: String = "Alle"

    private enum StatusFilter: String, CaseIterable {
        case alle   = "Alle"
        case offen  = "Offen"
        case geloest = "Gelöst"
    }

    private let priorities = ["Alle", "Hoch", "Mittel", "Gering", "Testen"]

    private var filtered: [FeedbackItem] {
        allFeedback
            .filter { item in
                switch statusFilter {
                case .alle:    return true
                case .offen:   return !item.isResolved
                case .geloest: return item.isResolved
                }
            }
            .filter { item in
                guard priorityFilter != "Alle" else { return true }
                return item.priority.lowercased() == priorityFilter.lowercased()
            }
            .sorted { a, b in
                let order = ["hoch": 0, "mittel": 1, "gering": 2, "testen": 3]
                let pa = order[a.priority] ?? 1
                let pb = order[b.priority] ?? 1
                if pa != pb { return pa < pb }
                return a.createdAt > b.createdAt
            }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Picker("Priorität", selection: $priorityFilter) {
                    ForEach(priorities, id: \.self) { p in Text(p).tag(p) }
                }
            }

            Section {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "Kein Feedback",
                        systemImage: "tray",
                        description: Text("Keine Einträge für diesen Filter.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filtered) { item in
                        FeedbackRow(item: item)
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(filtered[index]) }
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if allFeedback.contains(where: { $0.isResolved }) {
                    Button("Gelöste löschen", role: .destructive) { deleteResolved() }
                }
            }
        }
    }

    private func deleteResolved() {
        for item in allFeedback where item.isResolved { modelContext.delete(item) }
    }
}

// MARK: - Feedback Row

private struct FeedbackRow: View {
    @Bindable var item: FeedbackItem
    private let priorityOptions = ["hoch", "mittel", "gering", "testen"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text(item.text)
                .font(.subheadline)

            HStack {
                Picker("", selection: $item.priority) {
                    ForEach(priorityOptions, id: \.self) { p in
                        Text(p.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Spacer()

                Toggle("", isOn: $item.isResolved)
                    .labelsHidden()
                    .tint(.green)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.isResolved ? 0.6 : 1.0)
    }
}
