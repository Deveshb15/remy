import RemyKit
import SwiftUI

/// A to-do row. Checking off: the disc fills with a spring, a ripple leaves the checkbox,
/// the strike draws through the title, then the row leaves. Clicking again before it leaves undoes it.
struct TodoRow: View {
    @Environment(AppController.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let todo: Todo

    @State private var checked: Bool?          // optimistic state during the leave delay
    @State private var ripple = 0
    @State private var pending: Task<Void, Never>?
    @State private var editing = false
    @State private var draft = ""
    @State private var hovering = false
    @FocusState private var focused: Bool

    private var isOn: Bool { checked ?? todo.isDone }

    var body: some View {
        let still = reduceMotion // captured for Sendable animation closures
        return HStack(spacing: 9) {
            Button(action: toggle) {
                CheckGlyph(isOn: isOn, overdue: Schedule.bucket(todo, on: app.today) == .overdue)
                    .keyframeAnimator(initialValue: 1.0, trigger: ripple) { view, scale in
                        view.scaleEffect(still ? 1 : scale)
                    } keyframes: { _ in
                        SpringKeyframe(0.8, duration: 0.07)
                        SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                    }
                    .background { Ripple(trigger: ripple) }
                    .padding(5)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: ripple)
            .accessibilityLabel(isOn ? "Mark not done" : "Mark done")

            titleView

            RowMeta(text: Schedule.chip(todo, today: app.today, calendar: .autoupdatingCurrent),
                    overdue: Schedule.bucket(todo, on: app.today) == .overdue,
                    source: todo.source)
        }
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .frame(minHeight: 30)
        .background(.primary.opacity(hovering ? 0.045 : 0), in: .rect(cornerRadius: 8, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu { menu }
    }

    @ViewBuilder private var titleView: some View {
        if editing {
            TextField("Title", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .onSubmit(commitEdit)
                .onExitCommand { editing = false }
                .onAppear { focused = true }
        } else {
            Text(todo.title)
                .font(.system(size: 13))
                .foregroundStyle(isOn ? .tertiary : .primary)
                .lineLimit(2)
                .overlay(alignment: .leading) { Strike(on: isOn, reduceMotion: reduceMotion) } // spans the text, not the row
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture(count: 2) { draft = todo.title; editing = true }
                .animation(.easeOut(duration: 0.2), value: isOn)
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
        if Theme.symbol(for: todo.source) != nil {
            Divider()
            Text("Added by \(Theme.label(for: todo.source))")
        }
        Divider()
        Button("Delete", role: .destructive) { animate { app.perform(Request(op: .delete, id: todo.id)) } }
    }

    private func toggle() {
        let next = !isOn
        withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { checked = next }
        pending?.cancel()
        if next {
            ripple += 1
            // Commit after the moment lands; clicking again inside the window cancels it (interruptible).
            pending = Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 650))
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
            Rectangle()
                .fill(.tertiary)
                .frame(width: geo.size.width, height: 1)
                .scaleEffect(x: on ? 1 : 0, anchor: .leading)
                .frame(maxHeight: .infinity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.05), value: on)
        }
        .allowsHitTesting(false)
    }
}
