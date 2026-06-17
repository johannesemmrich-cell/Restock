import Foundation
import SwiftData

struct ListTemplate: Codable, Identifiable {
    var id: UUID
    var name: String
    var storeEmoji: String
    var storeName: String
    var createdAt: Date
    var items: [TemplateItemData]

    init(name: String, storeEmoji: String, storeName: String, items: [TemplateItemData]) {
        self.id = UUID()
        self.name = name
        self.storeEmoji = storeEmoji
        self.storeName = storeName
        self.createdAt = Date()
        self.items = items
    }
}

struct TemplateItemData: Codable {
    var name: String
    var quantity: String
    var quantityAmount: Double
    var unit: String
    var category: String
}

final class TemplateService: ObservableObject {
    static let shared = TemplateService()
    private let key = "smartcart.listTemplates"

    @Published private(set) var templates: [ListTemplate] = []

    private init() { load() }

    func saveTemplate(name: String, from store: Store) {
        let items = store.pendingItems.map { item in
            TemplateItemData(
                name: item.name,
                quantity: item.quantity,
                quantityAmount: item.quantityAmount,
                unit: item.unit,
                category: item.category
            )
        }
        let template = ListTemplate(
            name: name,
            storeEmoji: store.emoji,
            storeName: store.name,
            items: items
        )
        templates.removeAll { $0.name == template.name }
        templates.append(template)
        persist()
    }

    func delete(id: UUID) {
        templates.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ListTemplate].self, from: data) else { return }
        templates = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
