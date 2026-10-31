import AppIntents
import ReagentrKit
import WidgetKit

/// Check-off from the widget. Used with `Toggle(isOn:intent:)` so the system flips the UI optimistically.
struct ToggleTodoIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle To-do"
    static let isDiscoverable = false

    @Parameter(title: "To-do ID") var id: String
    @Parameter(title: "Done") var value: Bool

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        guard let url = Paths.storeURL else { return .result() }
        let done = value
        try TodoStore(url: url).mutate { todos in
            guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
            todos[i].completedAt = done ? (todos[i].completedAt ?? Date()) : nil
        }
        return .result()
    }
}
