import AppKit
import Foundation
import ReagentrKit

struct AppClientError: LocalizedError {
    let errorDescription: String?
}

/// Talks to the running Reagentr app over its Unix socket, launching the app if needed.
enum AppClient {
    static func send(_ request: Request) async throws -> Response {
        let payload = try Wire.encode(request) + Data("\n".utf8)
        if let data = try? roundTrip(payload) { return try Wire.decode(Response.self, from: data) }
        try await launchApp()
        for _ in 0..<25 { // up to 5 s for the app to open its socket
            try await Task.sleep(for: .milliseconds(200))
            if let data = try? roundTrip(payload) { return try Wire.decode(Response.self, from: data) }
        }
        throw AppClientError(errorDescription: "Reagentr app isn't responding. Open Reagentr and try again.")
    }

    private static func launchApp() async throws {
        // Prefer the app that contains this binary (Contents/Helpers/reagentr), then any installed copy.
        let bundled = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appURL = bundled.pathExtension == "app" ? bundled
            : NSWorkspace.shared.urlForApplication(withBundleIdentifier: Paths.appBundleID)
        guard let appURL else { throw AppClientError(errorDescription: "Reagentr app not found. Install Reagentr.app first.") }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    /// Blocking connect/write/read on a Unix domain socket. Requests are tiny, so this is fine for a CLI.
    private static func roundTrip(_ payload: Data) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw AppClientError(errorDescription: "socket() failed") }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = Paths.socketURL.path
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard path.utf8.count < capacity else { throw AppClientError(errorDescription: "Socket path too long") }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            raw.copyBytes(from: path.utf8)
            raw[path.utf8.count] = 0
        }
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard ok == 0 else { throw AppClientError(errorDescription: "connect failed") }

        var timeout = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        try payload.withUnsafeBytes { buf in
            var sent = 0
            while sent < buf.count {
                let n = write(fd, buf.baseAddress! + sent, buf.count - sent)
                guard n > 0 else { throw AppClientError(errorDescription: "write failed") }
                sent += n
            }
        }
        var out = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = read(fd, &chunk, chunk.count)
            if n <= 0 { break }
            out.append(chunk, count: n)
            if out.last == UInt8(ascii: "\n") { break }
        }
        guard !out.isEmpty else { throw AppClientError(errorDescription: "empty response") }
        return out
    }
}
