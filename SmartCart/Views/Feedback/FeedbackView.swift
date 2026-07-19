import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("feedbackHistory") private var feedbackHistoryData = Data()

    @State private var feedbackText = ""
    @State private var selectedCategory = FeedbackCategory.general
    @State private var showThankYou = false
    @State private var history: [FeedbackEntry] = []

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case general, bug, feature, design
        var id: String { rawValue }
        var label: String {
            switch self {
            case .general: return String(localized: "feedback.category.general")
            case .bug: return String(localized: "feedback.category.bug")
            case .feature: return String(localized: "feedback.category.feature")
            case .design: return String(localized: "feedback.category.design")
            }
        }
        var icon: String {
            switch self {
            case .general: return "text.bubble"
            case .bug: return "ladybug"
            case .feature: return "lightbulb"
            case .design: return "paintbrush"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "feedback.category.section")) {
                    Picker(String(localized: "feedback.category.label"), selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(String(localized: "feedback.message.section")) {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 120)
                }

                if !history.isEmpty {
                    Section(String(localized: "feedback.history.section")) {
                        ForEach(history) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: entry.category.icon)
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 12))
                                    Text(entry.category.label)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                                Text(entry.message)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.cancel")).toolbarChip(prominent: false) }
                        .buttonStyle(.plain)
}
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { submit() } label: {
                        Text(String(localized: "feedback.submit")).toolbarChip(prominent: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .overlay {
                if showThankYou {
                    thankYouOverlay
                }
            }
            .onAppear { loadHistory() }
        }
    }

    private var thankYouOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(String(localized: "feedback.thankyou.title"))
                .font(.headline)
            Text(String(localized: "feedback.thankyou.message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.sheet))
        .overlayShadow(colorScheme)
        .padding(32)
    }

    private func submit() {
        let entry = FeedbackEntry(
            id: UUID().uuidString,
            message: feedbackText.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            date: Date()
        )
        history.insert(entry, at: 0)
        saveHistory()
        feedbackText = ""
        withAnimation { showThankYou = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showThankYou = false }
            dismiss()
        }
    }

    private func loadHistory() {
        history = (try? JSONDecoder().decode([FeedbackEntry].self, from: feedbackHistoryData)) ?? []
    }

    private func saveHistory() {
        feedbackHistoryData = (try? JSONEncoder().encode(history)) ?? Data()
    }
}

struct FeedbackEntry: Codable, Identifiable {
    var id: String
    var message: String
    var categoryRaw: String
    var date: Date

    var category: FeedbackView.FeedbackCategory {
        FeedbackView.FeedbackCategory(rawValue: categoryRaw) ?? .general
    }

    init(id: String, message: String, category: FeedbackView.FeedbackCategory, date: Date) {
        self.id = id
        self.message = message
        self.categoryRaw = category.rawValue
        self.date = date
    }
}
