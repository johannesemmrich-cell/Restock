import AppIntents

struct QuickAddControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Schnell hinzufügen"
    static var description = IntentDescription("Öffnet Restock direkt zur schnellen Artikeleingabe.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart")?.set(true, forKey: "pendingQuickAdd")
        return .result()
    }
}
