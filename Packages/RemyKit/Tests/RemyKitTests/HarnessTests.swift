import Foundation
import Testing
@testable import RemyKit

@Suite struct HarnessTests {
    let helper = "/Applications/Remy.app/Contents/Helpers/remy"

    func json(_ d: Data) throws -> [String: Any] { try JSONSerialization.jsonObject(with: d) as! [String: Any] }

    @Test func mergeKeepsOtherServersAndKeys() throws {
        let existing = Data(#"{"theme":"dark","mcpServers":{"other":{"command":"/bin/other","args":["x"]}}}"#.utf8)
        let out = try json(HarnessConfig.merged(existing, style: .mcpServers, helper: helper))
        let servers = out["mcpServers"] as! [String: Any]
        #expect(out["theme"] as? String == "dark")
        #expect((servers["other"] as! [String: Any])["args"] as? [String] == ["x"])
        #expect((servers["remy"] as! [String: Any])["command"] as? String == helper)
        #expect((servers["remy"] as! [String: Any])["args"] as? [String] == ["mcp"])
    }

    @Test func styles() throws {
        let vs = try json(HarnessConfig.merged(nil, style: .vscode, helper: helper))
        #expect(((vs["servers"] as! [String: Any])["remy"] as! [String: Any])["type"] as? String == "stdio")
        let oc = try json(HarnessConfig.merged(Data("  \n".utf8), style: .opencode, helper: helper))
        let e = (oc["mcp"] as! [String: Any])["remy"] as! [String: Any]
        #expect(e["command"] as? [String] == [helper, "mcp"] && e["enabled"] as? Bool == true && e["type"] as? String == "local")
        #expect(HarnessConfig.connectedHelper(try HarnessConfig.merged(nil, style: .opencode, helper: helper), style: .opencode) == helper)
    }

    @Test func jsoncIsRefusedAndFileUntouched() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("remy-h-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("settings.json")
        let original = Data("{\n  // my comment\n  \"a\": 1\n}".utf8)
        try original.write(to: file)
        #expect(throws: HarnessConfig.Unparseable.self) { try HarnessConfig.connect(path: file, style: .mcpServers, helper: helper) }
        #expect(try Data(contentsOf: file) == original)
        #expect(!FileManager.default.fileExists(atPath: file.appendingPathExtension("remy-backup").path))
    }

    @Test func connectBacksUpOnceAndDisconnectRemoves() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("remy-h-\(UUID().uuidString)")
        let file = dir.appendingPathComponent("nested/mcp.json")
        try HarnessConfig.connect(path: file, style: .mcpServers, helper: helper) // creates dirs, no backup for a new file
        #expect(!FileManager.default.fileExists(atPath: file.appendingPathExtension("remy-backup").path))
        try HarnessConfig.connect(path: file, style: .mcpServers, helper: "/other/Remy.app/Contents/Helpers/remy")
        let backup = try Data(contentsOf: file.appendingPathExtension("remy-backup"))
        #expect(HarnessConfig.connectedHelper(backup, style: .mcpServers) == helper)
        try HarnessConfig.disconnect(path: file, style: .mcpServers)
        #expect(HarnessConfig.connectedHelper(try Data(contentsOf: file), style: .mcpServers) == nil)
    }

    @Test func repairOnlyRewritesOtherRemyCopies() throws {
        let stale = try HarnessConfig.merged(nil, style: .mcpServers, helper: "/Volumes/Remy/Remy.app/Contents/Helpers/remy")
        let fixed = try #require(try HarnessConfig.repaired(stale, style: .mcpServers, helper: helper))
        #expect(HarnessConfig.connectedHelper(fixed, style: .mcpServers) == helper)
        let custom = try HarnessConfig.merged(nil, style: .mcpServers, helper: "/usr/local/bin/remy")
        #expect(try HarnessConfig.repaired(custom, style: .mcpServers, helper: helper) == nil)
        #expect(try HarnessConfig.repaired(try HarnessConfig.merged(nil, style: .mcpServers, helper: helper), style: .mcpServers, helper: helper) == nil)
        #expect(try HarnessConfig.repaired(nil, style: .mcpServers, helper: helper) == nil)
    }

    @Test func detectUsesProbes() {
        let home = URL(fileURLWithPath: "/fakehome")
        let present: Set<String> = ["/opt/bin/claude", "/fakehome/.cursor"]
        let found = Harness.detect(home: home, searchPaths: ["/usr/bin", "/opt/bin"], fileExists: { present.contains($0) },
                                   appInstalled: { $0 == "com.microsoft.VSCode" })
        #expect(found.map(\.id) == ["claude-code", "cursor", "vscode"])
    }

    @Test func codexToml() {
        let toml = """
        model = "gpt-5"
        [mcp_servers.other]
        command = "/bin/other"
        [mcp_servers.remy]
        command = "/Applications/Remy.app/Contents/Helpers/remy"
        args = ["mcp"]
        """
        #expect(HarnessConfig.codexCommand(in: toml) == "/Applications/Remy.app/Contents/Helpers/remy")
        #expect(HarnessConfig.codexCommand(in: "[mcp_servers.other]\ncommand = \"/x\"") == nil)
    }

    @Test func temporaryLocations() {
        #expect(Install.isTemporaryLocation("/Volumes/Remy/Remy.app"))
        #expect(Install.isTemporaryLocation("/private/var/folders/x/AppTranslocation/ABC/d/Remy.app"))
        #expect(!Install.isTemporaryLocation("/Applications/Remy.app"))
        #expect(!Install.isTemporaryLocation("/Users/me/Applications/Remy.app"))
    }

    @Test func onboardingFlow() {
        #expect(OnboardingStep.connect.next(connectedCount: 0) == .widget)
        #expect(OnboardingStep.connect.next(connectedCount: 2) == .tryIt)
        #expect(OnboardingStep.move.next(connectedCount: 0) == .welcome)
        #expect(OnboardingStep.widget.next(connectedCount: 0) == .done)
    }
}
