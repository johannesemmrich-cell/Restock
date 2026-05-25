import SwiftUI

// MARK: - Priority

enum DevFeedbackPriority: String, CaseIterable {
    case high    = "hoch"
    case medium  = "mittel"
    case low     = "gering"
    case testing = "testen"

    var label: String {
        switch self {
        case .high:    return "Hoch"
        case .medium:  return "Mittel"
        case .low:     return "Gering"
        case .testing: return "Testen"
        }
    }

    var color: Color {
        switch self {
        case .high:    return .red
        case .medium:  return .orange
        case .low:     return .blue
        case .testing: return .purple
        }
    }

    var icon: String {
        switch self {
        case .high:    return "exclamationmark.triangle.fill"
        case .medium:  return "minus.circle.fill"
        case .low:     return "arrow.down.circle.fill"
        case .testing: return "testtube.2"
        }
    }
}

// MARK: - Model

struct DevFeedbackItem: Codable, Identifiable {
    var id: String
    var context: String
    var text: String
    var priorityRaw: String
    var date: Date
    var isResolved: Bool = false

    var priority: DevFeedbackPriority {
        DevFeedbackPriority(rawValue: priorityRaw) ?? .medium
    }

    init(context: String, text: String, priority: DevFeedbackPriority, date: Date = Date()) {
        self.id = UUID().uuidString
        self.context = context
        self.text = text
        self.priorityRaw = priority.rawValue
        self.date = date
    }
}

// MARK: - ViewModifier

struct DevFeedbackOverlay: ViewModifier {
    let context: String

    @AppStorage("developerMode") private var developerMode = false
    @AppStorage("devFeedbackItems") private var storedData = Data()
    @State private var showSheet = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if developerMode {
                    Button {
                        showSheet = true
                    } label: {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.red.opacity(0.6), in: Circle())
                    }
                    .padding(8)
                }
            }
            .sheet(isPresented: $showSheet) {
                DevFeedbackSheet(context: context, storedData: $storedData)
                    .presentationDetents([.medium])
            }
    }
}

// MARK: - Feedback Sheet

private struct DevFeedbackSheet: View {
    let context: String
    @Binding var storedData: Data

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var selectedPriority = DevFeedbackPriority.medium

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                // Context label (read-only)
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Priority picker
                Picker("Priorität", selection: $selectedPriority) {
                    ForEach(DevFeedbackPriority.allCases, id: \.self) { p in
                        Label(p.label, systemImage: p.icon).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Feedback text editor
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Dev-Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveItem() {
        let newItem = DevFeedbackItem(
            context: context,
            text: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: selectedPriority
        )
        var items = (try? JSONDecoder().decode([DevFeedbackItem].self, from: storedData)) ?? []
        items.insert(newItem, at: 0)
        storedData = (try? JSONEncoder().encode(items)) ?? Data()
        Haptics.impact(.medium)
        dismiss()
    }
}

// MARK: - View Extension

extension View {
    func devFeedback(context: String) -> some View {
        modifier(DevFeedbackOverlay(context: context))
    }
}
