import Foundation
import SwiftData

@Model
final class FeedbackItem {
    // Siehe Store.swift für die Begründung: jede gespeicherte Eigenschaft braucht für SwiftDatas
    // automatische CloudKit-Spiegelung entweder optional zu sein oder einen Standardwert zu
    // haben. Echte Werte kommen weiterhin ausschließlich aus init() unten.
    var id: UUID = UUID()
    var context: String = ""
    var text: String = ""
    var priority: String = "mittel"
    var isResolved: Bool = false
    var createdAt: Date = Date.now

    init(context: String, text: String, priority: String = "mittel") {
        self.id = UUID()
        self.context = context
        self.text = text
        self.priority = priority
        self.isResolved = false
        self.createdAt = .now
    }
}
