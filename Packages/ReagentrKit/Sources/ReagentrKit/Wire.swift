import Foundation

/// One request per line over the app's Unix socket. Shared by the CLI, the MCP server, and the popover.
public struct Request: Codable, Sendable, Equatable {
    public enum Op: String, Codable, Sendable { case add, list, update, complete, delete, now }
    public enum View: String, Codable, Sendable, CaseIterable { case today, upcoming, done, all }

    public var op: Op
    public var id: String?
    public var title: String?
    public var date: String?
    public var time: String?
    public var source: String?
    public var view: View?
    public var done: Bool?
    public var clearDate: Bool?
    public var clearTime: Bool?

    public init(op: Op, id: String? = nil, title: String? = nil, date: String? = nil, time: String? = nil,
                source: String? = nil, view: View? = nil, done: Bool? = nil, clearDate: Bool? = nil, clearTime: Bool? = nil) {
        self.op = op; self.id = id; self.title = title; self.date = date; self.time = time; self.source = source
        self.view = view; self.done = done; self.clearDate = clearDate; self.clearTime = clearTime
    }
}

public struct Item: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var date: String?
    public var time: String?
    public var source: String
    public var done: Bool
    public var bucket: Bucket
    /// Human-readable due date, e.g. "Fri, Nov 7 · 5:00 PM". Agents should repeat this back to the user.
    public var human: String
}

public struct Now: Codable, Sendable, Equatable {
    public var date: String
    public var weekday: String
    public var time: String
    public var timezone: String

    public init(date: String, weekday: String, time: String, timezone: String) {
        self.date = date; self.weekday = weekday; self.time = time; self.timezone = timezone
    }

    /// For transport-level failures where no clock context was computed.
    public static let unknown = Now(date: "", weekday: "", time: "", timezone: "")
}

public struct WireError: Codable, Sendable, Equatable {
    public var code: String
    public var message: String
}

public struct Response: Codable, Sendable, Equatable {
    public var ok: Bool
    public var item: Item?
    public var items: [Item]?
    public var note: String?
    public var error: WireError?
    public var now: Now

    public static func failure(_ code: String, _ message: String, now: Now) -> Response {
        Response(ok: false, error: WireError(code: code, message: message), now: now)
    }
}

public enum Wire {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try e.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
