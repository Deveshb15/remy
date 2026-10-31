import ReagentrKit
import SwiftUI

/// A to-do row with the check-off choreography from docs/design/visual-spec.md.
struct TodoRow: View {
    @Environment(AppController.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let todo: Todo

    @State private var checked: Bool?          // optimistic local state during the celebration window
    @State private var burst = 0
    @State private var pending: Task<Void, Never>?
    @State private var editing = false
    @State private var draft = ""
    @State private var hovering = false
    @FocusState private var focused: Bool

    private var isOn: Bool { checked ?? todo.isDone }
    private var source: Theme.Source { Theme.source(todo.source) }

    var body: some View {
        let still = reduceMotion // captured for Sendable animation closures
        return HStack(spacing: 8) {
            Button(action: toggle) {
                CheckGlyph(isOn: isOn, tint: source.color)
                    .keyframeAnimator(initialValue: 1.0, trigger: burst) { view, scale in
                        view.scaleEffect(still ? 1 : scale)
                    } keyframes: { _ in
                        SpringKeyframe(0.82, duration: 0.08)
                        SpringKeyframe(1.18, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                    }
                    .overlay { Celebration(trigger: burst, tint: source.color) }
                    .padding(4)
            }
            .buttonStyle(PressableStyle())
            .sensoryFeedback(.success, trigger: burst)
            .accessibilityLabel(isOn ? "Mark not done" : "Mark done")

            titleView

            if let chip = Schedule.chip(todo, today: app.today, calendar: .autoupdatingCurrent) {
                DateChip(text: chip, overdue: Schedule.bucket(todo, on: app.today) == .overdue)
            }
            SourceMark(source: todo.source)
                .help("Added by \(source.label)")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(minHeight: 32)
        .background(Color.primary.opacity(hovering ? 0.05 : 0), in: .rect(cornerRadius: 10))
        .onHover { hovering = $0 }
        .contextMenu { menu }
    }

    @ViewBuilder private var titleView: some View {
        if editing {
            TextField("Title", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($focused)
                .onSubmit(commitEdit)
                .onExitCommand { editing = false }
                .onAppear { focused = true }
        } else {
            Text(todo.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { Strike(on: isOn, reduceMotion: reduceMotion) }
                .contentShape(.rect)
                .onTapGesture(count: 2) { draft = todo.title; editing = true }
        }
    }

    @ViewBuilder private var menu: some View {
        let cal = Calendar.autoupdatingCurrent
        Button("Edit Title") { draft = todo.title; editing = true }
        Menu("Reschedule") {
            Button("Today") { reschedule(app.today) }
            Button("Tomorrow") { reschedule(app.today.adding(days: 1, calendar: cal)) }
            Button("Next Week") { reschedule(Schedule.nextWeek(from: app.today, calendar: cal)) }
            Divider()
            Button("No Date") { animate { app.perform(Request(op: .update, id: todo.id, clearDate: true)) } }
        }
        Divider()
        Button("Delete", role: .destructive) { animate { app.perform(Request(op: .delete, id: todo.id)) } }
    }

    private func toggle() {
        let next = !isOn
        withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { checked = next }
        pending?.cancel()
        if next {
            burst += 1
            // Commit after the celebration; clicking again inside the window cancels it (interruptible).
            pending = Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 700))
                guard !Task.isCancelled else { return }
                animate { app.perform(Request(op: .complete, id: todo.id, done: true)) }
                checked = nil
            }
        } else if todo.isDone {
            animate { app.perform(Request(op: .complete, id: todo.id, done: false)) }
            checked = nil
        } else {
            checked = nil // reversed before commit
        }
    }

    private func reschedule(_ day: LocalDate) {
        animate { app.perform(Request(op: .update, id: todo.id, date: day.description)) }
    }

    private func commitEdit() {
        editing = false
        guard draft != todo.title else { return }
        animate { app.perform(Request(op: .update, id: todo.id, title: draft)) }
    }

    private func animate(_ body: () -> Void) {
        withAnimation(Theme.Motion.named(Theme.Motion.settle, reduceMotion: reduceMotion), body)
    }
}

/// Strike-through that draws from the leading edge.
private struct Strike: View {
    let on: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(.secondary)
                .frame(width: geo.size.width, height: 1.5)
                .scaleEffect(x: on ? 1 : 0, anchor: .leading)
                .frame(maxHeight: .infinity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(0.06), value: on)
        }
        .allowsHitTesting(false)
    }
}
