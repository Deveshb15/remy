import Testing
@testable import RemyKit

@Suite struct CLITests {
    @Test func parsesAdd() throws {
        let c = try CLI.parse(["add", "Renew", "domain", "--date", "2026-11-03", "--time", "17:00"], env: ["REMY_SOURCE": "Codex"])
        #expect(c == .request(Request(op: .add, title: "Renew domain", date: "2026-11-03", time: "17:00", source: "Codex"), json: false))
        #expect(try CLI.parse(["add", "x", "--json"]) == .request(Request(op: .add, title: "x", source: "cli"), json: true))
    }

    @Test func parsesOtherCommands() throws {
        #expect(try CLI.parse(["list", "upcoming"]) == .request(Request(op: .list, view: .upcoming), json: false))
        #expect(try CLI.parse(["list"]) == .request(Request(op: .list, view: .today), json: false))
        #expect(try CLI.parse(["done", "abc234"]) == .request(Request(op: .complete, id: "abc234", done: true), json: false))
        #expect(try CLI.parse(["undo", "abc234"]) == .request(Request(op: .complete, id: "abc234", done: false), json: false))
        #expect(try CLI.parse(["edit", "abc234", "--no-date"]) == .request(Request(op: .update, id: "abc234", clearDate: true), json: false))
        #expect(try CLI.parse(["mcp"]) == .mcp)
        #expect(try CLI.parse([]) == .help)
    }

    @Test(arguments: [
        ["add", "x", "--date", "tomorrow"], ["add", "x", "--time", "5pm"], ["add"], ["done"],
        ["list", "soon"], ["frobnicate"], ["add", "x", "--date"], ["add", "x", "--colour", "red"],
    ])
    func rejectsBadInput(args: [String]) {
        #expect(throws: CLI.UsageError.self) { try CLI.parse(args) }
    }

    @Test func sourceNames() {
        #expect(CLI.sourceName(fromClient: "claude-code") == "Claude Code")
        #expect(CLI.sourceName(fromClient: "claude-ai") == "Claude")
        #expect(CLI.sourceName(fromClient: "codex-mcp-client") == "Codex")
        #expect(CLI.sourceName(fromClient: "cursor-vscode") == "Cursor")
        #expect(CLI.sourceName(fromClient: "Visual Studio Code") == "VS Code")
        #expect(CLI.sourceName(fromClient: "gemini-cli-mcp-client") == "Gemini CLI")
        #expect(CLI.sourceName(fromClient: "zed") == "zed")
        #expect(Harness.matching(source: "Claude Code")?.id == "claude-code")
        #expect(Harness.matching(source: "you") == nil)
    }
}
