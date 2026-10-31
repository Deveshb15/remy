import ReagentrKit
import SwiftUI

struct PopoverRoot: View {
    @Environment(AppController.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSetup = false
    @State private var showDone = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if showSetup {
                SetupPanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                QuickAdd().padding(.horizontal, 16).padding(.bottom, 10)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        todaySection
                        UpcomingList(todos: app.upcoming)
                        DoneList(todos: app.done, expanded: $showDone)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 14)
                }
                .scrollIndicators(.never)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 360)
        .frame(minHeight: 300, maxHeight: 560)
        .fontDesign(.rounded)
        .animation(Theme.Motion.named(Theme.Motion.settle, reduceMotion: reduceMotion), value: showSetup)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(showSetup ? "Connect agents" : "Today")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.3)
                    .contentTransition(.opacity)
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSetup.toggle()
            } label: {
                Image(systemName: showSetup ? "xmark" : "bolt.horizontal.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PressableStyle())
            .help(showSetup ? "Back to to-dos" : "Connect agents")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder private var todaySection: some View {
        let items = app.visible
        if let err = app.lastError {
            Label(err, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.overdue)
                .padding(.horizontal, 6).padding(.vertical, 6)
        }
        if items.isEmpty {
            AllClear(next: app.upcoming.first.flatMap { app.item($0)?.human })
                .transition(.opacity)
        } else {
            let overdue = items.filter { Schedule.bucket($0, on: app.today) == .overdue }
            if !overdue.isEmpty {
                SectionLabel(text: "Overdue", tint: Theme.overdue)
            }
            ForEach(items) { todo in
                TodoRow(todo: todo)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity).combined(with: .offset(y: -6))))
                if todo.id == overdue.last?.id { SectionLabel(text: "Today", tint: .secondary).padding(.top, 6) }
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}

/// Scale on press (feedback on mouse-down), springing back on release.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(Theme.Motion.named(Theme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// Empty state: the sun arrives with a single bounce (no looping motion).
struct AllClear: View {
    let next: String?
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Theme.marigold, Theme.accent], startPoint: .top, endPoint: .bottom))
                .scaleEffect(arrived || reduceMotion ? 1 : 0.5)
                .rotationEffect(.degrees(arrived || reduceMotion ? 0 : -40))
                .opacity(arrived ? 1 : 0)
            Text("All clear.").font(.system(size: 15, weight: .semibold))
            Text(next.map { "Next up: \($0)." } ?? "Nothing due today. Ask an agent to add something.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .onAppear { withAnimation(Theme.Motion.named(Theme.Motion.bouncy, reduceMotion: reduceMotion)) { arrived = true } }
    }
}
