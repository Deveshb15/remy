import AppKit
import RemyKit
import SwiftUI
import WidgetKit

// MARK: - Move

struct MoveStep: View {
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeader(title: "Move Remy to Applications",
                       subtitle: "Remy lives in your menu bar, and your agents need a permanent place to find it. This takes a second.")
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(Theme.overdue)
            }
        }
    }
}

// MARK: - Welcome

struct WelcomeStep: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            StepHeader(title: "Meet Remy",
                       subtitle: "Tell any AI agent to remind you about something. It lands on your desktop on the right day.")
            WidgetFrame(entry: .sample, scale: 1)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .offset(y: shown || reduceMotion ? 0 : 14)
                .opacity(shown ? 1 : 0)
                .onAppear { withAnimation(Theme.Motion.named(Theme.Motion.bouncy, reduceMotion: reduceMotion).delay(0.1)) { shown = true } }
        }
    }
}

/// The real medium widget, drawn in a widget-shaped card.
struct WidgetFrame: View {
    let entry: DayEntry
    var scale: CGFloat = 0.82
    var placed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WidgetBody(entry: entry, family: .systemMedium)
            .padding(16)
            .frame(width: 364, height: 170)
            .background(.background, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            .overlay(alignment: .topTrailing) {
                if placed {
                    CheckGlyph(isOn: true, size: 22)
                        .offset(x: 8, y: -8)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .scaleEffect(scale)
            .frame(width: 364 * scale, height: 170 * scale)
            .animation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion), value: placed)
            .allowsHitTesting(false)
    }
}

// MARK: - Connect

struct ConnectStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(title: "Connect your agents",
                       subtitle: "Remy found these on your Mac. Connect them so they can add to your list.")
            if model.detecting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking for your agents…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } else if model.rows.isEmpty {
                NoAgents()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.rows.enumerated()), id: \.element.id) { i, row in
                                if i > 0 { Divider().opacity(0.6).padding(.leading, 52) }
                                HarnessRow(row: row) { Task { await model.toggle(row.id) } }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(.primary.opacity(0.035), in: .rect(cornerRadius: 14, style: .continuous))
                    SelfTestLine(state: model.selfTest)
                }
            }
        }
    }
}

private struct HarnessRow: View {
    let row: OnboardingModel.Row
    let toggle: () -> Void
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            HarnessIcon(harness: row.harness)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.harness.name).font(.system(size: 13, weight: .medium))
                detail
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .animation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion), value: row.status)
        .animation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion), value: row.verified)
    }

    @ViewBuilder private var detail: some View {
        if let v = row.verified {
            Text("Verified · added \u{201C}\(v)\u{201D}").foregroundStyle(.secondary)
        } else {
            switch row.status {
            case .connected: Text("Connected").foregroundStyle(.secondary)
            case .failed(let m): Text(m).foregroundStyle(Theme.overdue)
            case .manual: Text("Couldn’t edit its settings file safely").foregroundStyle(.tertiary)
            case .working, .idle: Text(row.harness.appBundleID == nil ? "Command line" : "App").foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder private var trailing: some View {
        switch row.status {
        case .working:
            ProgressView().controlSize(.small).frame(width: 32)
        case .manual(let snippet):
            Button(copied ? "Copied" : "Copy setup") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snippet, forType: .string)
                copied = true
            }
            .buttonStyle(QuietButtonStyle())
        default:
            ConnectButton(connected: row.isConnected, name: row.harness.name, action: toggle)
        }
    }
}

/// "Connect" pill when off; a filled check when on, which offers "Disconnect" on hover. Clearer than a monochrome switch.
private struct ConnectButton: View {
    let connected: Bool
    let name: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if connected && !hovering {
                    CheckGlyph(isOn: true, size: 20)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Text(connected ? "Disconnect" : "Connect")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(connected ? .secondary : .primary)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .overlay(Capsule().strokeBorder(.primary.opacity(connected ? 0.12 : 0.22), lineWidth: 1))
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 90, alignment: .trailing)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .accessibilityLabel(connected ? "Disconnect \(name)" : "Connect \(name)")
    }
}

struct HarnessIcon: View {
    let harness: Harness
    var size: CGFloat = 28

    var body: some View {
        if let id = harness.appBundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.primary.opacity(0.06), in: .rect(cornerRadius: size * 0.26, style: .continuous))
        }
    }
}

private struct SelfTestLine: View {
    let state: OnboardingModel.SelfTest

    var body: some View {
        HStack(spacing: 6) {
            switch state {
            case .running:
                ProgressView().controlSize(.mini)
                Text("Checking Remy’s agent server…")
            case .passed:
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text("Remy’s agent server is ready.")
            case .failed:
                Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.overdue)
                Text("Remy’s agent server didn’t respond. Try reopening Remy.")
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
        .padding(.leading, 4)
    }
}

private struct NoAgents: View {
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No agents found yet. Add this to any MCP client's settings:")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            CopyWell(text: HarnessConfig.snippet(style: .mcpServers, helper: Installer.helperPath), monospaced: true)
        }
    }
}

/// Quiet well with copy-on-click.
struct CopyWell: View {
    let text: String
    var monospaced = false
    @State private var copied = 0
    @State private var hovering = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied += 1
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(text)
                    .font(monospaced ? .system(size: 11, design: .monospaced) : .system(size: 14))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: copied > 0 ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copied > 0 ? .primary : .tertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.top, monospaced ? 0 : 2)
            }
            .padding(14)
            .background(.primary.opacity(hovering ? 0.06 : 0.035), in: .rect(cornerRadius: 12, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .sensoryFeedback(.success, trigger: copied)
        .help("Copy")
    }
}

// MARK: - Try It

struct TryStep: View {
    let model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var agents: String {
        let names = model.rows.filter(\.isConnected).map(\.harness.name)
        return names.count <= 2 ? names.joined(separator: " or ") : names.prefix(2).joined(separator: ", ") + ", or another"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeader(title: "Say hi to Remy", subtitle: "Paste this into \(agents.isEmpty ? "an agent" : agents). Watch it land here.")
            CopyWell(text: OnboardingModel.tryPrompt)
            Group {
                if let todo = model.arrival {
                    HStack(spacing: 10) {
                        CheckGlyph(isOn: true, size: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(todo.title).font(.system(size: 13, weight: .medium))
                            Text("Added by \(todo.source). It's on your list for today.")
                                .font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.scale(scale: 0.9, anchor: .leading).combined(with: .opacity))
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini)
                        Text("Waiting for your agent…").font(.system(size: 12)).foregroundStyle(.tertiary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.leading, 4)
            .animation(Theme.Motion.named(Theme.Motion.bouncy, reduceMotion: reduceMotion), value: model.arrival?.id)
        }
    }
}

// MARK: - Widget

struct WidgetStep: View {
    let model: OnboardingModel
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepHeader(title: "Put Remy on your desktop",
                       subtitle: "The widget shows what’s due today. Anything set for later appears on its day.")
            HStack(alignment: .center, spacing: 28) {
                WidgetFrame(entry: DayEntry(todos: app.todos, at: Date(), calendar: .autoupdatingCurrent), scale: 0.72, placed: model.widgetPlaced)
                VStack(alignment: .leading, spacing: 14) {
                    Instruction(n: 1, text: "Right-click your desktop")
                    Instruction(n: 2, text: "Choose Edit Widgets")
                    Instruction(n: 3, text: "Search \u{201C}Remy\u{201D} and drag it out")
                    Text(model.widgetPlaced ? "Remy is on your desktop." : "Waiting for the widget…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .contentTransition(.opacity)
                        .padding(.top, 4)
                }
            }
        }
    }
}

private struct Instruction: View {
    let n: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(n)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.tertiary, lineWidth: 1))
            Text(text).font(.system(size: 13))
        }
    }
}

// MARK: - Done

struct DoneStep: View {
    private let examples = [
        "Remind me to renew the domain in 3 days.",
        "Remind me to call Mom on Sunday at 6pm.",
        "What’s on my list today?",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeader(title: "You’re set", subtitle: "Talk to your agents like you would to an assistant. Try one of these.")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(examples, id: \.self) { e in
                    Text("\u{201C}\(e)\u{201D}")
                        .font(.system(size: 13))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 10, style: .continuous))
                }
            }
            Text("Remy lives in your menu bar. Things dated for later stay out of sight until their day, then show up with a notification.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
