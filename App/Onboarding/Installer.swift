import AppKit
import RemyKit

/// Side effects for onboarding: find harnesses, (dis)connect them, self-test the MCP helper, relocate the app.
enum Installer {
    static var helperPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/remy").path }
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    // MARK: PATH

    /// Computed once; `static let` initialization is thread-safe, so concurrent callers share one shell lookup.
    private static let pathLookup = Task { await loginShellPaths() }

    static func searchPaths() async -> [String] { await pathLookup.value }

    /// GUI apps get a minimal PATH; ask the user's shell for the real one, then add common install dirs.
    private static func loginShellPaths() async -> [String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let out = await run(shell, ["-ilc", "printf '\\n__PATH__%s' \"$PATH\""], timeout: 3).output
        let fromShell = out.components(separatedBy: "__PATH__").last.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let h = home.path
        let defaults = ["\(h)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "\(h)/.bun/bin", "\(h)/.opencode/bin",
                        "\(h)/.npm-global/bin", "\(h)/.volta/bin", "/usr/bin", "/bin"]
        var seen = Set<String>()
        return (fromShell.split(separator: ":").map(String.init) + defaults).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: Detect and status

    static func detect() async -> [Harness] {
        let paths = await searchPaths()
        return Harness.detect(home: home, searchPaths: paths) { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    /// The helper path Remy is registered with in this harness, read straight from its config.
    static func registeredHelper(_ h: Harness) -> String? {
        switch h.kind {
        case .json(let path, let style):
            return HarnessConfig.connectedHelper(try? Data(contentsOf: home.appendingPathComponent(path)), style: style)
        case .cli(let binary, _, _):
            if binary == "claude" {
                return HarnessConfig.connectedHelper(try? Data(contentsOf: home.appendingPathComponent(".claude.json")), style: .mcpServers)
            }
            if binary == "codex", let toml = try? String(contentsOf: home.appendingPathComponent(".codex/config.toml"), encoding: .utf8) {
                return HarnessConfig.codexCommand(in: toml)
            }
            return nil
        }
    }

    static func isConnected(_ h: Harness) -> Bool {
        guard let path = registeredHelper(h) else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    // MARK: Connect

    enum ConnectResult: Equatable { case connected, failed(String), manual(String) }

    static func connect(_ h: Harness) async -> ConnectResult {
        switch h.kind {
        case .json(let path, let style):
            do {
                try HarnessConfig.connect(path: home.appendingPathComponent(path), style: style, helper: helperPath)
                return .connected
            } catch is HarnessConfig.Unparseable {
                return .manual(HarnessConfig.snippet(style: style, helper: helperPath))
            } catch {
                return .failed(error.localizedDescription)
            }
        case .cli(let binary, let add, let remove):
            guard let exe = Harness.locate(binary, in: await searchPaths()) else { return .failed("\(binary) not found") }
            _ = await run(exe, remove, timeout: 20) // idempotent: replace any earlier entry
            let r = await run(exe, add + [helperPath, "mcp"], timeout: 30)
            // The harness's own config is the source of truth; its exit code and chatter are not.
            if registeredHelper(h) == helperPath { return .connected }
            let reason = r.status == -1 ? "\(binary) took too long to respond" : "\(binary) couldn\u{2019}t add Remy (exit \(r.status))"
            return .failed(reason)
        }
    }

    static func disconnect(_ h: Harness) async {
        switch h.kind {
        case .json(let path, let style):
            try? HarnessConfig.disconnect(path: home.appendingPathComponent(path), style: style)
        case .cli(let binary, _, let remove):
            if let exe = Harness.locate(binary, in: await searchPaths()) { _ = await run(exe, remove, timeout: 20) }
        }
    }

    /// After the app moves (e.g. out of the DMG), point every connected harness at this copy.
    static func repairAll() async {
        let helper = helperPath
        for h in Harness.all {
            switch h.kind {
            case .json(let path, let style):
                let url = home.appendingPathComponent(path)
                if let fixed = try? HarnessConfig.repaired(try? Data(contentsOf: url), style: style, helper: helper) {
                    try? fixed.write(to: url, options: .atomic)
                }
            case .cli:
                if let current = registeredHelper(h), current != helper, current.hasSuffix("/Contents/Helpers/remy") {
                    _ = await connect(h)
                }
            }
        }
    }

    // MARK: Self-test

    /// Spawns `remy mcp`, completes initialize + tools/list, and checks all six tools come back.
    static func selfTest() async -> Bool {
        let lines = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"remy-selftest","version":"1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
        ]
        let r = await run(helperPath, ["mcp"], stdin: lines.joined(separator: "\n") + "\n", timeout: 5, until: #""id":2"#)
        guard let line = r.output.split(separator: "\n").first(where: { $0.contains(#""id":2"#) }),
              let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let tools = (obj["result"] as? [String: Any])?["tools"] as? [Any] else { return false }
        return tools.count == 6
    }

    // MARK: Move to Applications

    static var needsMove: Bool { Install.isTemporaryLocation(Bundle.main.bundlePath) }

    /// Copies the bundle to /Applications (or ~/Applications), clears quarantine, relaunches into onboarding.
    static func moveToApplications() throws {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        var lastError: Error?
        for dir in [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")] {
            let target = dir.appendingPathComponent(source.lastPathComponent)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: target.path) { try fm.trashItem(at: target, resultingItemURL: nil) }
                try fm.copyItem(at: source, to: target)
                _ = run(sync: "/usr/bin/xattr", ["-dr", "com.apple.quarantine", target.path])
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = ["--onboarding"]
                config.createsNewApplicationInstance = true
                NSWorkspace.shared.openApplication(at: target, configuration: config) { _, _ in
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
                return
            } catch { lastError = error }
        }
        throw lastError ?? CocoaError(.fileWriteUnknown)
    }

    // MARK: Process

    struct RunResult { var status: Int32; var output: String }

    /// Runs a process with the user's PATH. Stops early once stdout contains `until`, or at the timeout.
    static func run(_ exe: String, _ args: [String], stdin: String? = nil, timeout: Double, until: String? = nil) async -> RunResult {
        let env = await pathEnvironment(exe)
        return await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                p.environment = env
                let out = Pipe(), inPipe = Pipe()
                p.standardOutput = out
                p.standardError = out
                p.standardInput = inPipe
                let buffer = OutputBuffer()
                let done = DispatchSemaphore(value: 0)
                out.fileHandleForReading.readabilityHandler = { fh in
                    let chunk = fh.availableData
                    let text = buffer.append(chunk)
                    if chunk.isEmpty || (until.map { text.contains($0) } ?? false) { done.signal() }
                }
                do { try p.run() } catch { cont.resume(returning: RunResult(status: -1, output: error.localizedDescription)); return }
                if let stdin { inPipe.fileHandleForWriting.write(Data(stdin.utf8)) }
                if until == nil { try? inPipe.fileHandleForWriting.close() }
                let deadline = Date().addingTimeInterval(timeout)
                _ = done.wait(timeout: .now() + timeout)
                // Output EOF (or the `until` match) can arrive before the process has exited. Wait for the real exit
                // until the deadline; only a genuine timeout (or a stream we chose to stop early) gets terminated.
                if until == nil { while p.isRunning && Date() < deadline { usleep(20_000) } }
                let timedOut = p.isRunning
                if timedOut { p.terminate(); p.waitUntilExit() }
                out.fileHandleForReading.readabilityHandler = nil
                let text = buffer.append(Data())
                cont.resume(returning: RunResult(status: timedOut && until == nil ? -1 : p.terminationStatus, output: text))
            }
        }
    }

    @discardableResult
    static func run(sync exe: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    private static func pathEnvironment(_ exe: String) async -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        // The shell lookup itself must not wait on searchPaths() (it is what computes it).
        if !exe.hasSuffix("sh") { env["PATH"] = (await searchPaths()).joined(separator: ":") }
        return env
    }
}

/// Pipe output collected from the reader callback and read once the process ends.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    /// Appends and returns everything so far as text.
    func append(_ chunk: Data) -> String {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
        return String(decoding: data, as: UTF8.self)
    }
}
