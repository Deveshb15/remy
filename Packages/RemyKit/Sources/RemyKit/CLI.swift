import Foundation

/// Argument parsing and text output for the `remy` binary. Lives here so it's unit-testable.
public enum CLI {
    public enum Command: Equatable {
        case request(Request, json: Bool)
        case mcp
        case help
    }

    public struct UsageError: Error, Equatable { public let message: String }

    public static let usage = """
    remy — add dated to-dos to your Remy widget

    USAGE
      remy add "<title>" [--date YYYY-MM-DD] [--time HH:mm] [--source NAME]
      remy list [today|upcoming|done|all]
      remy done <id>        remy undo <id>
      remy edit <id> [--title T] [--date D | --no-date] [--time T | --no-time]
      remy rm <id>
      remy now
      remy mcp              run as a stdio MCP server

    Add --json to any command for raw JSON output. Source defaults to $REMY_SOURCE or "cli".
    """

    public static func parse(_ args: [String], env: [String: String] = [:]) throws(UsageError) -> Command {
        var rest = args
        let json = rest.contains("--json")
        rest.removeAll { $0 == "--json" }
        guard let cmd = rest.first else { return .help }
        rest.removeFirst()

        var flags: [String: String] = [:]
        var switches: Set<String> = []
        var positional: [String] = []
        var i = 0
        while i < rest.count {
            let a = rest[i]
            if ["--no-date", "--no-time"].contains(a) { switches.insert(a); i += 1; continue }
            if a.hasPrefix("--") {
                guard i + 1 < rest.count else { throw UsageError(message: "\(a) needs a value") }
                flags[String(a.dropFirst(2))] = rest[i + 1]; i += 2; continue
            }
            positional.append(a); i += 1
        }
        let known: Set<String> = ["date", "time", "source", "title"]
        if let bad = flags.keys.first(where: { !known.contains($0) }) { throw UsageError(message: "Unknown option --\(bad)") }
        if let d = flags["date"], LocalDate(d) == nil { throw UsageError(message: "--date must be YYYY-MM-DD, got \"\(d)\"") }
        if let t = flags["time"], LocalTime(t) == nil { throw UsageError(message: "--time must be 24h HH:mm, got \"\(t)\"") }

        func id() throws(UsageError) -> String {
            guard positional.count == 1 else { throw UsageError(message: "\(cmd) needs exactly one <id>") }
            return positional[0]
        }

        switch cmd {
        case "add":
            guard !positional.isEmpty else { throw UsageError(message: "add needs a title") }
            return .request(Request(op: .add, title: positional.joined(separator: " "), date: flags["date"], time: flags["time"],
                                    source: flags["source"] ?? env["REMY_SOURCE"] ?? "cli"), json: json)
        case "list", "ls":
            let view = try positional.first.map { v throws(UsageError) in
                guard let view = Request.View(rawValue: v) else { throw UsageError(message: "list view must be today, upcoming, done, or all") }
                return view
            }
            return .request(Request(op: .list, view: view ?? .today), json: json)
        case "done": return .request(Request(op: .complete, id: try id(), done: true), json: json)
        case "undo": return .request(Request(op: .complete, id: try id(), done: false), json: json)
        case "rm", "delete": return .request(Request(op: .delete, id: try id()), json: json)
        case "edit":
            let r = Request(op: .update, id: try id(), title: flags["title"], date: flags["date"], time: flags["time"],
                            clearDate: switches.contains("--no-date") ? true : nil, clearTime: switches.contains("--no-time") ? true : nil)
            return .request(r, json: json)
        case "now": return .request(Request(op: .now), json: json)
        case "mcp": return .mcp
        case "help", "-h", "--help": return .help
        default: throw UsageError(message: "Unknown command \"\(cmd)\"")
        }
    }

    /// Plain-text rendering of a response for humans and simple shell-based agents.
    public static func render(_ r: Response, for op: Request.Op) -> String {
        if let e = r.error { return "error (\(e.code)): \(e.message)" }
        let nowLine = "now: \(r.now.weekday) \(r.now.date) \(r.now.time) \(r.now.timezone)"
        var lines: [String] = []
        switch op {
        case .now: return nowLine
        case .list:
            let items = r.items ?? []
            lines = items.isEmpty ? ["(nothing here)"] : items.map(line)
        case .add: lines = ["added " + line(r.item!)]
        case .update: lines = ["updated " + line(r.item!)]
        case .complete: lines = [(r.item!.done ? "done " : "reopened ") + line(r.item!)]
        case .delete: lines = ["deleted " + line(r.item!)]
        }
        if let note = r.note { lines.append("note: \(note)") }
        lines.append(nowLine)
        return lines.joined(separator: "\n")
    }

    static func line(_ i: Item) -> String {
        "[\(i.id)] \(i.done ? "✓ " : "")\(i.title) — \(i.human)\(i.bucket == .overdue ? " (overdue)" : "") · via \(i.source)"
    }

    /// Badge name from an MCP client's self-reported name.
    public static func sourceName(fromClient name: String) -> String {
        let n = name.lowercased()
        // Harness order puts "claude-code" before plain "claude" (Claude desktop sends "claude-ai").
        return Harness.all.first { h in h.keywords.contains { n.contains($0) } }?.name ?? String(name.prefix(40))
    }
}
