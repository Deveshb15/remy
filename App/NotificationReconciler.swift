import Foundation
import ReagentrKit
import UserNotifications

/// Makes pending notifications match the store: one per incomplete dated to-do, at its time or 9:00.
@MainActor
final class NotificationReconciler {
    private var center: UNUserNotificationCenter { .current() } // lazy: touching it outside an app bundle throws
    private static let prefix = "todo-"
    private var last: Task<Void, Never>?

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func reconcile(_ todos: [Todo]) {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        var desired: [String: Date] = [:]
        var byID: [String: Todo] = [:]
        for t in todos {
            guard let fire = Schedule.fireDate(t, now: now, calendar: calendar) else { continue }
            desired[Self.prefix + t.id] = fire
            byID[Self.prefix + t.id] = t
        }
        // Serialized: an older pass finishing last would re-add notifications for deleted to-dos.
        last = Task { [previous = last] in
            await previous?.value
            let pending = await center.pendingNotificationRequests()
            var current: [String: Date] = [:]
            for r in pending where r.identifier.hasPrefix(Self.prefix) {
                current[r.identifier] = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantPast
            }
            let diff = Schedule.notificationDiff(pending: current, desired: desired)
            center.removePendingNotificationRequests(withIdentifiers: diff.remove)
            for key in diff.add {
                guard let t = byID[key], let d = t.date else { continue }
                let time = t.time ?? Schedule.defaultNotifyTime
                let content = UNMutableNotificationContent()
                content.title = t.title
                content.body = t.time == nil ? "Due today · added by \(t.source)" : "Due now · added by \(t.source)"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: DateComponents(year: d.year, month: d.month, day: d.day, hour: time.hour, minute: time.minute),
                    repeats: false)
                try? await center.add(UNNotificationRequest(identifier: key, content: content, trigger: trigger))
            }
        }
    }
}
