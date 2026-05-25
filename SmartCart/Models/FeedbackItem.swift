import Foundation
import SwiftData

@Model
final class FeedbackItem {
    var id: UUID
    var context: String
    var text: String
    var priority: String
    var isResolved: Bool
    var createdAt: Date

    init(context: String, text: String, priority: String = "mittel") {
        self.id = UUID()
        self.context = context
        self.text = text
        self.priority = priority
        self.isResolved = false
        self.createdAt = .now
    }
}
