import SwiftUI
import SwiftData

struct TodoListView: View {
    @Query(sort: \TodoItem.createdAt) private var allItems: [TodoItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddAlert = false
    @State private var newTitle = ""
    @State private var editingItem: TodoItem?
    @State private var editNotes = ""

    private var openItems: [TodoItem]      { allItems.filter { !$0.isCompleted } }
    private var completedItems: [TodoItem] { allItems.filter { $0.isCompleted } }

    var body: some View {
        List {
            Section("Offen (\(openItems.count))") {
                if openItems.isEmpty {
                    Text("Keine offenen Todos")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(openItems) { item in
                        todoRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation { item.isCompleted = true }
                                } label: {
                                    Label("Erledigt", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .leading) {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if !completedItems.isEmpty {
                Section("Erledigt (\(completedItems.count))") {
                    ForEach(completedItems) { item in
                        todoRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation { item.isCompleted = false }
                                } label: {
                                    Label("Öffnen", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
        }
        .navigationTitle("Todos & Ideen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newTitle = ""
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Neues Todo", isPresented: $showAddAlert) {
            TextField("Titel", text: $newTitle)
            Button("Abbrechen", role: .cancel) { newTitle = "" }
            Button("Hinzufügen") {
                let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                modelContext.insert(TodoItem(title: trimmed))
                newTitle = ""
            }
        }
        .alert("Notizen", isPresented: Binding(
            get: { editingItem != nil },
            set: { if !$0 { editingItem = nil } }
        )) {
            TextField("Notizen…", text: $editNotes)
            Button("Abbrechen", role: .cancel) { editingItem = nil }
            Button("Speichern") {
                editingItem?.notes = editNotes.isEmpty ? nil : editNotes
                editingItem = nil
            }
        }
    }

    private func todoRow(item: TodoItem) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { item.isCompleted.toggle() }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editNotes = item.notes ?? ""
            editingItem = item
        }
    }
}
