import SwiftUI
import SwiftData

// MARK: - ViewModifier

struct DevFeedbackOverlay: ViewModifier {
    let context: String
    @AppStorage("developerMode") private var developerMode = false
    @State private var showSheet = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if developerMode {
                    Button { showSheet = true } label: {
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
                DevFeedbackSheet(context: context)
                    .presentationDetents([.height(340)])
            }
    }
}

// MARK: - Feedback Sheet

struct DevFeedbackSheet: View {
    let context: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var selectedPriority = "mittel"
    private let priorityOptions = ["hoch", "mittel", "gering", "testen"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Picker("Priorität", selection: $selectedPriority) {
                    ForEach(priorityOptions, id: \.self) { p in
                        Text(p.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                TextEditor(text: $feedbackText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") { saveFeedback() }
                        .fontWeight(.semibold)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveFeedback() {
        let item = FeedbackItem(
            context: context,
            text: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: selectedPriority
        )
        modelContext.insert(item)
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
