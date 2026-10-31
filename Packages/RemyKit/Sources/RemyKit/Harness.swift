import Foundation

/// An agent harness Remy can connect to: how to find it and how to register Remy's MCP server with it.
public struct Harness: Identifiable, Sendable, Equatable {
    public enum Probe: Sendable, Equatable {
        case binary(String)   // found on the user's PATH
        case path(String)     // exists, relative to home
        case app(String)      // bundle identifier is installed
    }

    public enum Style: Sendable, Equatable {
        case mcpServers  // { "mcpServers": { name: { command, args } } }
        case vscode      // { "servers": { name: { type: "stdio", command, args } } }
        case opencode    // { "mcp": { name: { type: "local", command: [..], enabled } } }
    }

    public enum Kind: Sendable, Equatable {
        /// Harness owns its config format; Remy calls its `mcp add` / `mcp remove`.
        case cli(binary: String, add: [String], remove: [String])
        /// Plain JSON config Remy merges into (path relative to home).
        case json(path: String, style: Style)
    }

    public let id: String
    public let name: String
    public let kind: Kind
    public let probes: [Probe]
    public let appBundleID: String?
    /// Lowercased fragments of the MCP `clientInfo.name` this harness sends, most specific first.
    public let keywords: [String]

    public var isCLI: Bool { if case .cli = kind { true } else { false } }

    public static let serverName = "remy"
    static let helperSuffix = "/Contents/Helpers/remy"

    public static let all: [Harness] = [
        Harness(id: "claude-code", name: "Claude Code",
                kind: .cli(binary: "claude", add: ["mcp", "add", "--scope", "user", serverName, "--"], remove: ["mcp", "remove", "--scope", "user", serverName]),
                probes: [.binary("claude")], appBundleID: nil, keywords: ["claude-code", "claude code"]),
        Harness(id: "codex", name: "Codex",
                kind: .cli(binary: "codex", add: ["mcp", "add", serverName, "--"], remove: ["mcp", "remove", serverName]),
                probes: [.binary("codex")], appBundleID: nil, keywords: ["codex"]),
        Harness(id: "gemini", name: "Gemini CLI", kind: .json(path: ".gemini/settings.json", style: .mcpServers),
                probes: [.binary("gemini"), .path(".gemini")], appBundleID: nil, keywords: ["gemini"]),
        Harness(id: "opencode", name: "opencode", kind: .json(path: ".config/opencode/opencode.json", style: .opencode),
                probes: [.binary("opencode"), .path(".config/opencode")], appBundleID: nil, keywords: ["opencode"]),
        Harness(id: "claude-desktop", name: "Claude", kind: .json(path: "Library/Application Support/Claude/claude_desktop_config.json", style: .mcpServers),
                probes: [.app("com.anthropic.claudefordesktop"), .path("Library/Application Support/Claude")],
                appBundleID: "com.anthropic.claudefordesktop", keywords: ["claude-ai", "claude"]),
        Harness(id: "cursor", name: "Cursor", kind: .json(path: ".cursor/mcp.json", style: .mcpServers),
                probes: [.app("com.todesktop.230313mzl4w4u92"), .binary("cursor-agent"), .path(".cursor")],
                appBundleID: "com.todesktop.230313mzl4w4u92", keywords: ["cursor"]),
        Harness(id: "windsurf", name: "Windsurf", kind: .json(path: ".codeium/windsurf/mcp_config.json", style: .mcpServers),
                probes: [.app("com.exafunction.windsurf"), .path(".codeium/windsurf")],
                appBundleID: "com.exafunction.windsurf", keywords: ["windsurf"]),
        Harness(id: "vscode", name: "VS Code", kind: .json(path: "Library/Application Support/Code/User/mcp.json", style: .vscode),
                probes: [.app("com.microsoft.VSCode")], appBundleID: "com.microsoft.VSCode", keywords: ["visual studio code", "vscode"]),
        Harness(id: "lmstudio", name: "LM Studio", kind: .json(path: ".lmstudio/mcp.json", style: .mcpServers),
                probes: [.app("ai.elementlabs.lmstudio"), .path(".lmstudio")], appBundleID: "ai.elementlabs.lmstudio", keywords: ["lm studio", "lmstudio"]),
    ]

    /// Harnesses present on this machine. Dependencies are injected so tests run against a fake home.
    public static func detect(home: URL, searchPaths: [String], fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:),
                              appInstalled: (String) -> Bool) -> [Harness] {
        all.filter { h in
            h.probes.contains { probe in
                switch probe {
                case .binary(let b): locate(b, in: searchPaths, fileExists: fileExists) != nil
                case .path(let p): fileExists(home.appendingPathComponent(p).path)
                case .app(let id): appInstalled(id)
                }
            }
        }
    }

    public static func locate(_ binary: String, in searchPaths: [String], fileExists: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> String? {
        searchPaths.lazy.map { ($0 as NSString).appendingPathComponent(binary) }.first(where: fileExists)
    }

    /// The harness whose agent produced a to-do with this source name, if any.
    public static func matching(source: String) -> Harness? {
        all.first { $0.name == source }
    }
}

// MARK: - JSON config editing

public enum HarnessConfig {
    public struct Unparseable: Error, Equatable { public let path: String }

    static func key(_ style: Harness.Style) -> String {
        switch style { case .mcpServers: "mcpServers"; case .vscode: "servers"; case .opencode: "mcp" }
    }

    static func entry(_ style: Harness.Style, helper: String) -> [String: Any] {
        switch style {
        case .mcpServers: ["command": helper, "args": ["mcp"]]
        case .vscode: ["type": "stdio", "command": helper, "args": ["mcp"]]
        case .opencode: ["type": "local", "command": [helper, "mcp"], "enabled": true]
        }
    }

    static func parse(_ data: Data?, path: String) throws -> [String: Any] {
        guard let data, !data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) else { return [:] }
        // JSONC (comments, trailing commas) fails here on purpose: Remy never rewrites a file it can't round-trip.
        guard let obj = try? JSONSerialization.jsonObject(with: data), let dict = obj as? [String: Any] else { throw Unparseable(path: path) }
        return dict
    }

    static func serialize(_ dict: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) + Data("\n".utf8)
    }

    /// The new file contents with Remy's server added or replaced; other servers and keys are kept.
    public static func merged(_ data: Data?, style: Harness.Style, helper: String, path: String = "") throws -> Data {
        var root = try parse(data, path: path)
        var servers = root[key(style)] as? [String: Any] ?? [:]
        servers[Harness.serverName] = entry(style, helper: helper)
        root[key(style)] = servers
        return try serialize(root)
    }

    /// The command path of Remy's entry, if one exists.
    public static func connectedHelper(_ data: Data?, style: Harness.Style) -> String? {
        guard let root = try? parse(data, path: ""), let servers = root[key(style)] as? [String: Any],
              let e = servers[Harness.serverName] as? [String: Any] else { return nil }
        if let c = e["command"] as? String { return c }
        return (e["command"] as? [String])?.first
    }

    /// Rewrites Remy's entry when it points at another copy of Remy.app (e.g. the DMG volume). Nil when nothing to do.
    public static func repaired(_ data: Data?, style: Harness.Style, helper: String) throws -> Data? {
        guard let current = connectedHelper(data, style: style), current != helper,
              current.hasSuffix(Harness.helperSuffix) else { return nil }
        return try merged(data, style: style, helper: helper)
    }

    /// Connect a JSON harness on disk: one-time backup, then atomic write.
    public static func connect(path: URL, style: Harness.Style, helper: String) throws {
        let fm = FileManager.default
        let existing = try? Data(contentsOf: path)
        let updated = try merged(existing, style: style, helper: helper, path: path.path)
        try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = path.appendingPathExtension("remy-backup")
        if let existing, !fm.fileExists(atPath: backup.path) { try existing.write(to: backup) }
        try updated.write(to: path, options: .atomic)
    }

    public static func disconnect(path: URL, style: Harness.Style) throws {
        guard let existing = try? Data(contentsOf: path) else { return }
        var root = try parse(existing, path: path.path)
        var servers = root[key(style)] as? [String: Any] ?? [:]
        guard servers.removeValue(forKey: Harness.serverName) != nil else { return }
        root[key(style)] = servers
        try serialize(root).write(to: path, options: .atomic)
    }

    /// `command = "..."` inside `[mcp_servers.remy]` of Codex's config.toml.
    /// ponytail: line-based read, enough for the file `codex mcp add` writes; use a TOML parser if Codex changes format.
    public static func codexCommand(in toml: String) -> String? {
        var inSection = false
        for line in toml.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line.hasPrefix("[") { inSection = line == "[mcp_servers.\(Harness.serverName)]"; continue }
            if inSection, line.hasPrefix("command"), let q = line.firstIndex(of: "\""), let e = line.lastIndex(of: "\""), q < e {
                return String(line[line.index(after: q)..<e])
            }
        }
        return nil
    }

    /// Paste-able fallback for a harness Remy couldn't edit.
    public static func snippet(style: Harness.Style, helper: String) -> String {
        let dict = [key(style): [Harness.serverName: entry(style, helper: helper)]]
        return String(decoding: (try? serialize(dict)) ?? Data(), as: UTF8.self)
    }
}

// MARK: - Install location and onboarding flow

public enum Install {
    /// Running from a mounted DMG or Gatekeeper's App Translocation: paths written now would soon disappear.
    public static func isTemporaryLocation(_ bundlePath: String) -> Bool {
        bundlePath.hasPrefix("/Volumes/") || bundlePath.contains("/AppTranslocation/")
    }
}

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case move, welcome, connect, tryIt, widget, done

    /// Try It needs at least one connected agent; otherwise go straight to the widget.
    public func next(connectedCount: Int) -> OnboardingStep {
        switch self {
        case .move: .welcome
        case .welcome: .connect
        case .connect: connectedCount > 0 ? .tryIt : .widget
        case .tryIt: .widget
        case .widget, .done: .done
        }
    }
}
