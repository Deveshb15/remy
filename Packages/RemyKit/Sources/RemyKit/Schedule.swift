import Foundation

public enum Bucket: String, Codable, Sendable { case overdue, today, upcoming, done }

/// Pure date logic. Every function takes `calendar` and `now`/`day` so nothing reads the wall clock.
public enum Schedule {
    public static let defaultNotifyTime = LocalTime(hour: 9, minute: 0)!

    public static func bucket(_ t: Todo, on day: LocalDate) -> Bucket {
        if t.isDone { return .done }
        guard let d = t.date, d != day else { return .today } // undated = due today
        return d < day ? .overdue : .upcoming
    }

    /// What the widget shows on `day`: overdue (oldest first), then today (timed by time, then untimed).
    public static func visible(_ todos: [Todo], on day: LocalDate) -> [Todo] {
        let overdue = todos.filter { bucket($0, on: day) == .overdue }.sorted(by: chronological)
        let today = todos.filter { bucket($0, on: day) == .today }.sorted(by: chronological)
        return overdue + today
    }

    public static func upcoming(_ todos: [Todo], on day: LocalDate) -> [Todo] {
        todos.filter { bucket($0, on: day) == .upcoming }.sorted(by: chronological)
    }

    public static func done(_ todos: [Todo]) -> [Todo] {
        todos.filter(\.isDone).sorted { $0.completedAt! > $1.completedAt! }
    }

    /// Date, then timed-before-untimed by time, then creation order.
    static func chronological(_ a: Todo, _ b: Todo) -> Bool {
        if a.date != b.date {
            switch (a.date, b.date) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            default: return false
            }
        }
        if a.time != b.time {
            switch (a.time, b.time) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            default: return false
            }
        }
        return a.createdAt < b.createdAt
    }

    /// Widget timeline entry dates: now, the next midnight (so overdue/labels flip), and each future midnight
    /// on which an incomplete to-do becomes visible. Capped at 14.
    public static func timelineDates(_ todos: [Todo], now: Date, calendar: Calendar) -> [Date] {
        let today = LocalDate(now, calendar: calendar)
        var days: Set<LocalDate> = [today.adding(days: 1, calendar: calendar)]
        for t in todos where !t.isDone { if let d = t.date, d > today { days.insert(d) } }
        let midnights = days.sorted().prefix(13).map { $0.start(in: calendar) }
        return [now] + midnights
    }

    /// When a to-do's notification should fire, or nil if it shouldn't (done, undated, or already past).
    public static func fireDate(_ t: Todo, now: Date, calendar: Calendar) -> Date? {
        guard !t.isDone, let d = t.date else { return nil }
        let time = t.time ?? defaultNotifyTime
        let fire = calendar.date(from: DateComponents(year: d.year, month: d.month, day: d.day,
                                                      hour: time.hour, minute: time.minute))!
        return fire > now ? fire : nil
    }

    /// Diff of notification requests: what to add (new or changed fire date) and what to remove.
    public static func notificationDiff(pending: [String: Date], desired: [String: Date]) -> (add: [String], remove: [String]) {
        let add = desired.filter { pending[$0.key] != $0.value }.map(\.key).sorted()
        let remove = pending.keys.filter { desired[$0] == nil || desired[$0] != pending[$0] }.sorted()
        return (add, remove)
    }

    /// "Next week" quick-add chip: the next Monday strictly after `day`.
    public static func nextWeek(from day: LocalDate, calendar: Calendar) -> LocalDate {
        var d = day.adding(days: 1, calendar: calendar)
        while calendar.component(.weekday, from: d.start(in: calendar)) != 2 { d = d.adding(days: 1, calendar: calendar) }
        return d
    }

    /// Human-readable date for agents and UI: "Today · 5:00 PM", "Tomorrow", "Fri, Nov 7", "Mon, Jan 4, 2027".
    public static func human(date: LocalDate?, time: LocalTime?, today: LocalDate, calendar: Calendar) -> String {
        let d = date ?? today
        let dayPart: String
        switch d {
        case today: dayPart = "Today"
        case today.adding(days: 1, calendar: calendar): dayPart = "Tomorrow"
        case today.adding(days: -1, calendar: calendar): dayPart = "Yesterday"
        default:
            let f = formatter(d.year == today.year ? "EEE, MMM d" : "EEE, MMM d, yyyy", calendar)
            dayPart = f.string(from: d.start(in: calendar))
        }
        guard let time else { return dayPart }
        let at = calendar.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: time.hour, minute: time.minute))!
        return "\(dayPart) · \(formatter("h:mm a", calendar).string(from: at))"
    }

    /// Short chip text for a row: overdue shows its day; otherwise only a time, since rows sit under a day header.
    public static func chip(_ t: Todo, today: LocalDate, calendar: Calendar) -> String? {
        switch bucket(t, on: today) {
        case .overdue: return human(date: t.date, time: nil, today: today, calendar: calendar)
        case .today, .done, .upcoming:
            guard let time = t.time, let d = t.date else { return nil }
            let at = calendar.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: time.hour, minute: time.minute))!
            return formatter("h:mm a", calendar).string(from: at)
        }
    }

    static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX") // agent-facing text stays stable regardless of system locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }
}
