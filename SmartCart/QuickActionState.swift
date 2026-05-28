import Observation

@Observable
final class QuickActionState {
    static let shared = QuickActionState()
    private init() {}
    var triggerQuickAdd = false
}
