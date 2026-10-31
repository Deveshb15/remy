import Foundation
import AppKit
import Observation
import ReagentrKit
import SwiftUI
import WidgetKit

/// Single owner of writes from agents and the popover. Reloads the widget and reconciles notifications after changes.
@MainActor @Observable
final class AppController {
    static let shared = AppController(storeURL: Paths.storeURL)

    private(set) var todos: [Todo] = []
    private(set) var today = LocalDate(Date(), calendar: .autoupdatingCurrent)
    var lastError: String?

    @ObservationIgnored let handler: CommandHandler?
    @ObservationIgnored private var server: SocketServer?
    @ObservationIgnored private var watcher: StoreWatcher?
    @ObservationIgnored private let notifications = NotificationReconciler()

    init(storeURL: URL?) {
        handler = storeURL.map { CommandHandler(store: TodoStore(url: $0), calendar: .autoupdatingCurrent) }
        if handler == nil { lastError = "App Group container unavailable — check signing and entitlements." }
    }

    func start() {
        guard let handler else { return }
        reload()
        notifications.requestAuthorization()
        notifications.reconcile(todos)
        watcher = StoreWatcher(url: handler.store.url) { [weak self] in self?.storeChangedExternally() }
        do {
            server = try SocketServer(path: Paths.socketURL, onFailure: { message in
                Task { @MainActor in AppController.shared.lastError = message }
            }) { [weak self] request in
                await self?.perform(request) ?? .failure("unavailable", "Reagentr is shutting down.", now: .unknown)
            }
        } catch {
            lastError = "Agent socket failed to start: \(error.localizedDescription)"
        }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload(); WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    @discardableResult
    func perform(_ request: Request) -> Response {
        guard let handler else { return .failure("unavailable", lastError ?? "Store unavailable.", now: .unknown) }
        let (response, changed) = handler.handle(request)
        if changed {
            reload()
            WidgetCenter.shared.reloadTimelines(ofKind: Paths.widgetKind)
            notifications.reconcile(todos)
        }
        return response
    }

    func item(_ t: Todo) -> Item? { handler?.item(t, today) }

    var visible: [Todo] { Schedule.visible(todos, on: today) }
    var upcoming: [Todo] { Schedule.upcoming(todos, on: today) }
    var done: [Todo] { Schedule.done(todos) }

    private func storeChangedExternally() {
        let before = todos
        reload()
        if todos != before { notifications.reconcile(todos) }
    }

    func reload() {
        today = LocalDate(Date(), calendar: .autoupdatingCurrent)
        do {
            let fresh = try handler?.store.load() ?? []
            guard fresh != todos else { return }
            // Agent-driven changes animate in too, not just popover actions.
            let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            withAnimation(reduce ? Theme.Motion.reduced : Theme.Motion.bouncy) { todos = fresh }
        } catch { lastError = error.localizedDescription }
    }
}
