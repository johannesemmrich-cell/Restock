import SwiftData

// MARK: - V1 (current schema — all existing models)
// Add future versions here as SchemaV2, SchemaV3, etc.
// Each version needs a new MigrationStage in SmartCartMigrationPlan.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Store.self, ShoppingItem.self, PurchaseRecord.self, FeedbackItem.self, TodoItem.self]
    }
}

enum SmartCartMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
