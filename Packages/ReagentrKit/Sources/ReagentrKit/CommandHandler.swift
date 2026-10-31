import Foundation

/// Applies wire requests to the store. Validation for anything an agent sends lives here.
public struct CommandHandler: Sendable {
    public let store: TodoStore
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public static let maxTitleLength = 200

    public init(store: TodoStore, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store; self.calendar = calendar; self.now = now
    }

    struct Failure: Error { let code: String, message: String }

    /// Returns the response and whether the store changed (so the host can reload the widget and notifications).
    public func handle(_ req: Request) -> (response: Response, changed: Bool) {
        let instant = now()
        let today = LocalDate(instant, calendar: calendar)
        let nowInfo = makeNow(instant)
        do {
            switch req.op {
            case .now:
                return (Response(ok: true, now: nowInfo), false)

            case .list:
                let todos = try store.load()
                let view = req.view ?? .today
                let picked: [Todo] = switch view {
                case .today: Schedule.visible(todos, on: today)
                case .upcoming: Schedule.upcoming(todos, on: today)
                case .done: Schedule.done(todos)
                case .all: Schedule.visible(todos, on: today) + Schedule.upcoming(todos, on: today) + Schedule.done(todos)
                }
                return (Response(ok: true, items: picked.map { item($0, today) }, now: nowInfo), false)

            case .add:
                let title = try validTitle(req.title)
                let date = try parseDate(req.date)
                let time = try parseTime(req.time)
                if time != nil && date == nil { throw Failure(code: "time_without_date", message: "A time needs a date. Send date as YYYY-MM-DD (today is \(today)).") }
                let source = req.source?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "cli"
                let todo = try store.mutate { todos in
                    let t = Todo(id: Todo.newID(avoiding: Set(todos.map(\.id))), title: title, date: date, time: time,
                                 source: String(source.prefix(40)), createdAt: instant)
                    todos.append(t)
                    return t
                }
                return (Response(ok: true, item: item(todo, today), note: pastNote(todo, today), now: nowInfo), true)

            case .update:
                let id = try requireID(req.id)
                let title = try req.title.map { try validTitle($0) }
                let date = try parseDate(req.date)
                let time = try parseTime(req.time)
                let todo = try store.mutate { todos in
                    guard let i = todos.firstIndex(where: { $0.id == id }) else { throw notFound(id) }
                    var t = todos[i]
                    if let title { t.title = title }
                    if req.clearDate == true { t.date = nil; t.time = nil }
                    if let date { t.date = date }
                    if req.clearTime == true { t.time = nil }
                    if let time { t.time = time }
                    if t.time != nil && t.date == nil { throw Failure(code: "time_without_date", message: "A time needs a date. Send date as YYYY-MM-DD (today is \(today)).") }
                    todos[i] = t
                    return t
                }
                return (Response(ok: true, item: item(todo, today), note: pastNote(todo, today), now: nowInfo), true)

            case .complete:
                let id = try requireID(req.id)
                let done = req.done ?? true
                let todo = try store.mutate { todos in
                    guard let i = todos.firstIndex(where: { $0.id == id }) else { throw notFound(id) }
                    todos[i].completedAt = done ? (todos[i].completedAt ?? instant) : nil
                    return todos[i]
                }
                return (Response(ok: true, item: item(todo, today), now: nowInfo), true)

            case .delete:
                let id = try requireID(req.id)
                let todo = try store.mutate { todos in
                    guard let i = todos.firstIndex(where: { $0.id == id }) else { throw notFound(id) }
                    return todos.remove(at: i)
                }
                return (Response(ok: true, item: item(todo, today), now: nowInfo), true)
            }
        } catch let f as Failure {
            return (.failure(f.code, f.message, now: nowInfo), false)
        } catch {
            return (.failure("storage", "Could not read or write the to-do store: \(error.localizedDescription)", now: nowInfo), false)
        }
    }

    public func item(_ t: Todo, _ today: LocalDate) -> Item {
        Item(id: t.id, title: t.title, date: t.date?.description, time: t.time?.description, source: t.source,
             done: t.isDone, bucket: Schedule.bucket(t, on: today),
             human: Schedule.human(date: t.date, time: t.time, today: today, calendar: calendar))
    }

    func makeNow(_ instant: Date) -> Now {
        let f = { Schedule.formatter($0, calendar).string(from: instant) }
        return Now(date: f("yyyy-MM-dd"), weekday: f("EEEE"), time: f("HH:mm"), timezone: calendar.timeZone.identifier)
    }

    func pastNote(_ t: Todo, _ today: LocalDate) -> String? {
        guard let d = t.date, d < today, !t.isDone else { return nil }
        return "That date is in the past (today is \(today)), so this to-do shows as overdue. Update it if you meant a future date."
    }

    func validTitle(_ raw: String?) throws -> String {
        let t = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw Failure(code: "invalid_title", message: "Title can't be empty.") }
        guard t.count <= Self.maxTitleLength else { throw Failure(code: "invalid_title", message: "Title is longer than \(Self.maxTitleLength) characters.") }
        return t
    }

    func parseDate(_ s: String?) throws -> LocalDate? {
        guard let s else { return nil }
        guard let d = LocalDate(s) else { throw Failure(code: "invalid_date", message: "Date must be YYYY-MM-DD, got \"\(s)\".") }
        return d
    }

    func parseTime(_ s: String?) throws -> LocalTime? {
        guard let s else { return nil }
        guard let t = LocalTime(s) else { throw Failure(code: "invalid_time", message: "Time must be 24h HH:mm, got \"\(s)\".") }
        return t
    }

    func requireID(_ id: String?) throws -> String {
        guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !id.isEmpty else {
            throw Failure(code: "missing_id", message: "An id is required. Call list to find it.")
        }
        return id
    }

    func notFound(_ id: String) -> Failure {
        Failure(code: "not_found", message: "No to-do with id \"\(id)\". Call list to see current ids.")
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
