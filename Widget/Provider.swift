import Foundation
import RemyKit
import WidgetKit

struct DayEntry: TimelineEntry {
    let date: Date
    let today: LocalDate
    let items: [Todo]       // overdue first, then today
    let upcoming: [Todo]
    let calendar: Calendar

    func chip(_ t: Todo) -> String? { Schedule.chip(t, today: today, calendar: calendar) }
    var nextUpcomingDay: Date? { upcoming.first?.date?.start(in: calendar) }
}

struct Provider: TimelineProvider {
    var storeURL: URL? = Paths.storeURL

    func placeholder(in context: Context) -> DayEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(context.isPreview ? .sample : entries(now: Date()).first!)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let list = entries(now: Date())
        completion(Timeline(entries: list, policy: .after(list.last!.date)))
    }

    /// One entry per day boundary, so future to-dos appear at midnight without the app running.
    func entries(now: Date) -> [DayEntry] {
        let calendar = Calendar.autoupdatingCurrent
        let todos = storeURL.flatMap { try? TodoStore(url: $0).load() } ?? []
        return Schedule.timelineDates(todos, now: now, calendar: calendar).map { DayEntry(todos: todos, at: $0, calendar: calendar) }
    }
}

extension DayEntry {
    init(todos: [Todo], at date: Date, calendar: Calendar) {
        let day = LocalDate(date, calendar: calendar)
        self.init(date: date, today: day, items: Schedule.visible(todos, on: day),
                  upcoming: Schedule.upcoming(todos, on: day), calendar: calendar)
    }

    static var sample: DayEntry {
        let cal = Calendar.autoupdatingCurrent
        let today = LocalDate(Date(), calendar: cal)
        let mk = { (id: String, title: String, offset: Int?, time: String?, source: String) in
            Todo(id: id, title: title, date: offset.map { today.adding(days: $0, calendar: cal) },
                 time: time.flatMap(LocalTime.init), source: source, createdAt: .distantPast)
        }
        let todos = [
            mk("a", "Call the bank about the card", -1, nil, "Claude"),
            mk("b", "Review PR for the widget", 0, "11:30", "Codex"),
            mk("c", "Renew the domain", 0, "17:00", "Claude"),
            mk("d", "Buy oat milk", nil, nil, "you"),
            mk("e", "Ship the onboarding copy", 3, nil, "Claude"),
        ]
        return DayEntry(date: Date(), today: today, items: Schedule.visible(todos, on: today),
                        upcoming: Schedule.upcoming(todos, on: today), calendar: cal)
    }

    static var empty: DayEntry {
        let cal = Calendar.autoupdatingCurrent
        return DayEntry(date: Date(), today: LocalDate(Date(), calendar: cal), items: [], upcoming: [], calendar: cal)
    }
}
