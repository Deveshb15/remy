import Foundation

/// A calendar day with no timezone attached ("floating"), stored as `YYYY-MM-DD`.
public struct LocalDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int, month: Int, day: Int

    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public init?(year: Int, month: Int, day: Int) {
        // Round-trip through a calendar so Feb 30 and month 13 are rejected.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard (1...12).contains(month), (1...31).contains(day),
              let date = cal.date(from: DateComponents(year: year, month: month, day: day)),
              cal.component(.day, from: date) == day else { return nil }
        self.year = year; self.month = month; self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year!; self.month = c.month!; self.day = c.day!
    }

    public func start(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int, calendar: Calendar) -> LocalDate {
        LocalDate(calendar.date(byAdding: .day, value: days, to: start(in: calendar))!, calendar: calendar)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (a: LocalDate, b: LocalDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let v = LocalDate(s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(s)"))
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

/// A wall-clock time with no timezone attached, stored as `HH:mm` (24h).
public struct LocalTime: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let hour: Int, minute: Int

    public init?(_ string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        self.init(hour: h, minute: m)
    }

    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour; self.minute = minute
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static func < (a: LocalTime, b: LocalTime) -> Bool { (a.hour, a.minute) < (b.hour, b.minute) }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let v = LocalTime(s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid time \(s)"))
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

public struct Todo: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var date: LocalDate?
    public var time: LocalTime?
    public var source: String
    public var createdAt: Date
    public var completedAt: Date?

    public init(id: String, title: String, date: LocalDate? = nil, time: LocalTime? = nil,
                source: String, createdAt: Date, completedAt: Date? = nil) {
        self.id = id; self.title = title; self.date = date; self.time = time
        self.source = source; self.createdAt = createdAt; self.completedAt = completedAt
    }

    public var isDone: Bool { completedAt != nil }

    // Unambiguous lowercase alphabet (no i, l, o, u, 0, 1) so agents can read IDs back reliably.
    static let idAlphabet = Array("abcdefghjkmnpqrstvwxyz23456789")

    public static func newID(avoiding existing: Set<String>) -> String {
        while true {
            let id = String((0..<6).map { _ in idAlphabet.randomElement()! })
            if !existing.contains(id) { return id }
        }
    }
}
