import SwiftUI

/// Copy-paste setup for agents. The CLI path is the binary embedded in this app bundle.
struct SetupPanel: View {
    private var cli: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/remy").path }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Let an agent add, list, and check off your to-dos. Paste one of these into your terminal.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Snippet(title: "Claude Code", code: "claude mcp add --scope user remy -- \"\(cli)\" mcp")
                Snippet(title: "Codex", code: "codex mcp add remy -- \"\(cli)\" mcp")
                Snippet(title: "Other MCP clients",
                        code: "{ \"mcpServers\": { \"remy\": {\n  \"command\": \"\(cli)\",\n  \"args\": [\"mcp\"] } } }")
                Snippet(title: "Shell", code: "ln -sf \"\(cli)\" ~/.local/bin/remy")
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.never)
    }
}

private struct Snippet: View {
    let title: String
    let code: String
    @State private var copied = 0
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copied += 1
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(code)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: copied > 0 ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(copied > 0 ? .primary : .tertiary)
                        .contentTransition(.symbolEffect(.replace))
                        .opacity(hovering || copied > 0 ? 1 : 0.6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.primary.opacity(hovering ? 0.07 : 0.045), in: .rect(cornerRadius: 8, style: .continuous))
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .onHover { hovering = $0 }
            .sensoryFeedback(.success, trigger: copied)
            .help("Copy")
        }
    }
}
