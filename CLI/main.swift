import Foundation
import ReagentrKit

let args = Array(CommandLine.arguments.dropFirst())
do {
    switch try CLI.parse(args, env: ProcessInfo.processInfo.environment) {
    case .help:
        print(CLI.usage)
    case .mcp:
        try await MCPServer.run()
    case let .request(req, json):
        let response = try await AppClient.send(req)
        if json {
            print(String(decoding: try Wire.encode(response), as: UTF8.self))
        } else {
            print(CLI.render(response, for: req.op))
        }
        exit(response.ok ? 0 : 1)
    }
} catch let e as CLI.UsageError {
    FileHandle.standardError.write(Data("reagentr: \(e.message)\n\nRun `reagentr help` for usage.\n".utf8))
    exit(64)
} catch {
    FileHandle.standardError.write(Data("reagentr: \(error.localizedDescription)\n".utf8))
    exit(1)
}
