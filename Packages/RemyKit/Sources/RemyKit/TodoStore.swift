import Foundation

/// JSON-file store shared by the app and the widget extension.
/// Every access goes through NSFileCoordinator so the widget's check-off intent and the app never interleave writes.
public struct TodoStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    struct FileContents: Codable {
        var version = 1
        var todos: [Todo]
    }

    public func load() throws -> [Todo] {
        var result: Result<[Todo], Error> = .success([])
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { u in
            result = Result { try read(u) }
        }
        if let coordError { throw coordError }
        return try result.get()
    }

    /// Read-modify-write inside one coordinated block. The file is only written when `body` returns normally.
    @discardableResult
    public func mutate<T>(_ body: (inout [Todo]) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var result: Result<T, Error>?
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordError) { u in
            result = Result {
                var todos = try read(u)
                let value = try body(&todos)
                let data = try Self.encoder.encode(FileContents(todos: todos))
                try data.write(to: u, options: .atomic)
                return value
            }
        }
        if let coordError { throw coordError }
        return try result!.get()
    }

    private func read(_ u: URL) throws -> [Todo] {
        let data: Data
        do {
            data = try Data(contentsOf: u)
        } catch CocoaError.fileReadNoSuchFile {
            return [] // missing file = empty store
        } // any other read error propagates, so a write never replaces data it couldn't read
        do {
            return try Self.decoder.decode(FileContents.self, from: data).todos
        } catch {
            // Keep the unreadable file for recovery instead of silently overwriting it.
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = u.deletingLastPathComponent().appendingPathComponent("todos.corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: u, to: aside)
            return []
        }
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

public enum Paths {
    /// App Group identifier, injected via Info.plist (`RemyAppGroup`) so the team prefix lives in build settings.
    public static var appGroup: String? { Bundle.main.object(forInfoDictionaryKey: "RemyAppGroup") as? String }

    public static var storeURL: URL? {
        guard let group = appGroup,
              let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return dir.appendingPathComponent("todos.json")
    }

    /// Lives outside the group container so the CLI never touches another app's container (avoids the TCC prompt).
    public static var socketURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Remy/agent.sock")
    }

    public static let appBundleID = "dev.devesh.remy"
    public static let widgetKind = "RemyWidget"
}
