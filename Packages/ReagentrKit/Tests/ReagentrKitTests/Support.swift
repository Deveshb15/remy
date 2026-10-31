import Foundation
@testable import ReagentrKit

func tempStore() -> TodoStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("reagentr-tests-\(UUID().uuidString)")
    return TodoStore(url: dir.appendingPathComponent("todos.json"))
}

func cal(_ tz: String = "America/Los_Angeles") -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: tz)!
    return c
}

func d(_ s: String) -> LocalDate { LocalDate(s)! }

/// Instant for a local wall time in the given calendar.
func at(_ date: String, _ time: String = "12:00", _ c: Calendar = cal()) -> Date {
    let ld = d(date), lt = LocalTime(time)!
    return c.date(from: DateComponents(year: ld.year, month: ld.month, day: ld.day, hour: lt.hour, minute: lt.minute))!
}

func todo(_ id: String, date: String? = nil, time: String? = nil, created: Date = Date(timeIntervalSince1970: 0), done: Date? = nil) -> Todo {
    Todo(id: id, title: id, date: date.map(d), time: time.map { LocalTime($0)! }, source: "test", createdAt: created, completedAt: done)
}
