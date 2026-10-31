import Foundation
import Network
import ReagentrKit

/// Newline-delimited JSON over a Unix domain socket. One request per connection.
final class SocketServer: Sendable {
    private let listener: NWListener
    static let maxRequestBytes = 1 << 20

    init(path: URL, onFailure: @escaping @Sendable (String) -> Void, handle: @escaping @Sendable (Request) async -> Response) throws {
        let dir = path.deletingLastPathComponent()
        // 0700 on the directory keeps the socket private to this user.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: path) // stale socket from a previous run

        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .unix(path: path.path)
        listener = try NWListener(using: params)
        listener.newConnectionHandler = { conn in
            conn.start(queue: .global())
            Self.receive(conn, buffer: Data(), handle: handle)
        }
        listener.stateUpdateHandler = { state in
            if case let .failed(error) = state { onFailure("Agent socket stopped: \(error.localizedDescription)") }
        }
        listener.start(queue: .global())
    }

    deinit { listener.cancel() }

    private static func receive(_ conn: NWConnection, buffer: Data, handle: @escaping @Sendable (Request) async -> Response) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            var buffer = buffer
            if let data { buffer.append(data) }
            if let nl = buffer.firstIndex(of: UInt8(ascii: "\n")) ?? (isComplete ? buffer.endIndex : nil) {
                let line = buffer[..<nl]
                Task {
                    let response: Response
                    if let req = try? Wire.decode(Request.self, from: Data(line)) {
                        response = await handle(req)
                    } else {
                        response = .failure("bad_request", "Could not parse request JSON.", now: .unknown)
                    }
                    var out = (try? Wire.encode(response)) ?? Data()
                    out.append(UInt8(ascii: "\n"))
                    conn.send(content: out, isComplete: true, completion: .contentProcessed { _ in conn.cancel() })
                }
            } else if error != nil || buffer.count > maxRequestBytes {
                conn.cancel()
            } else {
                receive(conn, buffer: buffer, handle: handle)
            }
        }
    }
}
