import Foundation
import SwiftData

@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var isCompleted: Bool = false
    var createdAt: Date = Date.now

    init(title: String, notes: String? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.isCompleted = false
        self.createdAt = .now
    }
}
