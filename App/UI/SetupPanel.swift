import SwiftUI

/// Copy-paste setup for agents. The CLI path is the binary embedded in this app bundle.
struct SetupPanel: View {
    private var cli: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/reagentr").path }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Give any agent a Reagentr tool. It can add, list, complete, and reschedule your to-dos.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Snippet(title: "Claude Code", source: "claude",
                        code: "claude mcp add --scope user reagentr -- \"\(cli)\" mcp")
                Snippet(title: "Codex", source: "codex",
                        code: "codex mcp add reagentr -- \"\(cli)\" mcp")
                Snippet(title: "Any MCP client (JSON)", source: "other",
                        code: "{\n  \"mcpServers\": {\n    \"reagentr\": { \"command\": \"\(cli)\", \"args\": [\"mcp\"] }\n  }\n}")
                Snippet(title: "Shell (no MCP)", source: "you",
                        code: "ln -sf \"\(cli)\" ~/.local/bin/reagentr\nreagentr add \"Renew the domain\" --date 2026-11-03")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }
}

private struct Snippet: View {
    let title: String
    let source: String
    let code: String
    @State private var copied = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                SourceMark(source: source)
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied += 1
                } label: {
                    Label(copied > 0 ? "Copied" : "Copy", systemImage: copied > 0 ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(copied > 0 ? Theme.done : Theme.accent)
                .sensoryFeedback(.success, trigger: copied)
            }
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8, style: .continuous))
        }
    }
}
