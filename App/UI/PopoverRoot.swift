import ReagentrKit
import SwiftUI

struct PopoverRoot: View {
    @Environment(AppController.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSetup = false
    @State private var showDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if showSetup {
                SetupPanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                QuickAdd()
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                Divider().opacity(0.5).padding(.horizontal, 16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let err = app.lastError { ErrorLine(text: err) }
                        todaySection
                        UpcomingList(todos: app.upcoming)
                        DoneList(todos: app.done, expanded: $showDone)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 440)
                .fixedSize(horizontal: false, vertical: true) // popover hugs its content up to the cap
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 340, alignment: .top)
        .animation(Theme.Motion.named(Theme.Motion.settle, reduceMotion: reduceMotion), value: showSetup)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(showSetup ? "Connect" : "Today")
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.4)
                .contentTransition(.opacity)
            if !showSetup, !app.visible.isEmpty {
                Text(app.visible.count, format: .number)
                    .font(.system(size: 20, weight: .medium))
                    .tracking(-0.4)
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button {
                showSetup.toggle()
            } label: {
                Image(systemName: showSetup ? "xmark" : "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 26, height: 26)
                    .contentShape(.circle)
            }
            .buttonStyle(PressableStyle())
            .help(showSetup ? "Back" : "Connect agents")
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var todaySection: some View {
        let items = app.visible
        if items.isEmpty {
            AllClear()
                .transition(.opacity)
        } else {
            ForEach(items) { todo in
                TodoRow(todo: todo)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .leading))))
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(text).foregroundStyle(.secondary)
            if let detail { Text(detail).foregroundStyle(.tertiary) }
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}

private struct ErrorLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.overdue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

/// Scale on press (feedback on mouse-down), springing back on release.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Theme.Motion.named(Theme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// Quiet empty state: a single light glyph that settles in once.
struct AllClear: View {
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
                .scaleEffect(arrived || reduceMotion ? 1 : 0.85)
                .opacity(arrived ? 1 : 0)
                .padding(.bottom, 4)
            Text("All clear")
                .font(.system(size: 14, weight: .semibold))
            Text("Nothing due today.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .onAppear { withAnimation(Theme.Motion.named(Theme.Motion.bouncy, reduceMotion: reduceMotion)) { arrived = true } }
    }
}
