import Foundation
import MCP
import RemyKit

/// stdio MCP server. Each tool call becomes one wire request to the running app.
enum MCPServer {
    actor ClientName { var value = "agent"; func set(_ v: String) { value = v } }

    static func run() async throws {
        let client = ClientName()
        let server = Server(name: "remy", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))

        await server.withMethodHandler(ListTools.self) { _ in .init(tools: tools) }
        await server.withMethodHandler(CallTool.self) { params in
            let source = await client.value
            guard let req = request(for: params.name, args: params.arguments ?? [:], source: source) else {
                return .init(content: [.text(text: "Unknown tool \(params.name).", annotations: nil, _meta: nil)], isError: true)
            }
            do {
                let response = try await AppClient.send(req)
                let json = try Wire.encode(response)
                return .init(content: [.text(text: CLI.render(response, for: req.op), annotations: nil, _meta: nil)],
                             structuredContent: try? JSONDecoder().decode(Value.self, from: json),
                             isError: !response.ok)
            } catch {
                return .init(content: [.text(text: "Remy is unavailable: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
            }
        }

        try await server.start(transport: StdioTransport()) { info, _ in
            await client.set(CLI.sourceName(fromClient: info.name))
        }
        await server.waitUntilCompleted()
    }

    static func request(for tool: String, args: [String: Value], source: String) -> RemyKit.Request? {
        let s = { (k: String) in args[k]?.stringValue }
        switch tool {
        case "add_todo": return RemyKit.Request(op: .add, title: s("title"), date: s("date"), time: s("time"), source: source)
        case "list_todos": return RemyKit.Request(op: .list, view: s("view").flatMap(RemyKit.Request.View.init) ?? .today)
        case "update_todo":
            return RemyKit.Request(op: .update, id: s("id"), title: s("title"), date: s("date"), time: s("time"),
                           clearDate: args["clear_date"]?.boolValue, clearTime: args["clear_time"]?.boolValue)
        case "complete_todo": return RemyKit.Request(op: .complete, id: s("id"), done: args["done"]?.boolValue ?? true)
        case "delete_todo": return RemyKit.Request(op: .delete, id: s("id"))
        case "current_time": return RemyKit.Request(op: .now)
        default: return nil
        }
    }

    static let dateHint = "Local calendar date YYYY-MM-DD. Resolve relative phrases like 'in 3 days' or 'next Friday' from the `now` returned by every call (or call current_time first)."

    static func schema(_ props: [String: Value], required: [String] = []) -> Value {
        .object(["type": "object", "properties": .object(props), "required": .array(required.map { .string($0) })])
    }
    static func str(_ d: String) -> Value { .object(["type": "string", "description": .string(d)]) }
    static func bool(_ d: String) -> Value { .object(["type": "boolean", "description": .string(d)]) }

    static let tools: [Tool] = [
        Tool(name: "add_todo", title: "Add to-do",
             description: "Add a to-do to the user's Remy desktop widget. Without a date it is due today. A future-dated to-do stays hidden until that day, then appears and notifies (at `time`, or 9:00 AM). After adding, tell the user the returned `human` date so they can catch mistakes.",
             inputSchema: schema(["title": str("What to do, short and specific."),
                                  "date": str(dateHint),
                                  "time": str("Optional 24h local time HH:mm. Requires date.")], required: ["title"])),
        Tool(name: "list_todos", title: "List to-dos",
             description: "List to-dos. view: today (overdue + due today; default), upcoming (future-dated), done, or all. Returns ids for update/complete/delete.",
             inputSchema: schema(["view": .object(["type": "string", "enum": .array(RemyKit.Request.View.allCases.map { .string($0.rawValue) })])]),
             annotations: .init(readOnlyHint: true)),
        Tool(name: "update_todo", title: "Edit or reschedule to-do",
             description: "Change a to-do's title, date, or time. Use clear_date to make it due today, clear_time to drop the time.",
             inputSchema: schema(["id": str("To-do id from list_todos."), "title": str("New title."), "date": str(dateHint),
                                  "time": str("24h local time HH:mm."), "clear_date": bool("Remove the date."), "clear_time": bool("Remove the time.")],
                                 required: ["id"])),
        Tool(name: "complete_todo", title: "Complete to-do",
             description: "Mark a to-do done (done=true, default) or reopen it (done=false).",
             inputSchema: schema(["id": str("To-do id from list_todos."), "done": bool("true to complete, false to reopen.")], required: ["id"])),
        Tool(name: "delete_todo", title: "Delete to-do",
             description: "Permanently delete a to-do. Prefer complete_todo unless the user asked to remove it.",
             inputSchema: schema(["id": str("To-do id from list_todos.")], required: ["id"]),
             annotations: .init(destructiveHint: true)),
        Tool(name: "current_time", title: "Current local time",
             description: "Get the user's current local date, weekday, time, and timezone for resolving relative dates.",
             inputSchema: schema([:]), annotations: .init(readOnlyHint: true)),
    ]
}
