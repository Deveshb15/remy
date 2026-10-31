import RemyKit
import SwiftUI

/// Inline add row. Date options appear only while you type, then tuck away.
struct QuickAdd: View {
    @Environment(AppController.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Choice: Hashable { case today, tomorrow, nextWeek, pick }

    @State private var title: String
    @State private var choice: Choice = .today
    @State private var picked = Date.now
    @State private var showPicker = false
    @State private var useTime = false
    @State private var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var shake = 0
    @FocusState private var focused: Bool

    init(title: String = "") { _title = State(initialValue: title) }

    private var cal: Calendar { .autoupdatingCurrent }
    private var hasText: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var expanded: Bool { hasText }

    private var day: LocalDate {
        switch choice {
        case .today: app.today
        case .tomorrow: app.today.adding(days: 1, calendar: cal)
        case .nextWeek: Schedule.nextWeek(from: app.today, calendar: cal)
        case .pick: LocalDate(picked, calendar: cal)
        }
    }

    var body: some View {
        let still = reduceMotion // captured for Sendable animation closures
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(focused ? .secondary : .tertiary)
                    .frame(width: 16, height: 16)
                    .padding(5)
                TextField("New to-do", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focused)
                    .onSubmit(submit)
                if hasText {
                    Text("↩")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
            }
            .padding(.leading, 3)
            .padding(.trailing, 10)
            .frame(minHeight: 30)
            .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, x in view.offset(x: still ? 0 : x) } keyframes: { _ in
                SpringKeyframe(-5, duration: 0.06); SpringKeyframe(4, duration: 0.08); SpringKeyframe(0, duration: 0.2, spring: .bouncy)
            }

            if expanded {
                HStack(spacing: 2) {
                    option(.today, "Today")
                    option(.tomorrow, "Tomorrow")
                    option(.nextWeek, "Next week")
                    option(.pick, choice == .pick ? Schedule.human(date: day, time: nil, today: app.today, calendar: cal) : "Date…")
                        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                            DatePicker("Date", selection: $picked, in: Date.now..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding(8)
                        }
                    Spacer(minLength: 4)
                    if useTime {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .controlSize(.small)
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
                    }
                    Button {
                        withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { useTime.toggle() }
                    } label: {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(useTime ? .primary : .tertiary)
                            .frame(width: 22, height: 20)
                            .contentShape(.rect)
                    }
                    .buttonStyle(PressableStyle())
                    .help(useTime ? "Remove time" : "Add a time")
                }
                .padding(.leading, 31) // first option text lines up with the title text
                .padding(.trailing, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Theme.Motion.named(Theme.Motion.bouncy, reduceMotion: reduceMotion), value: expanded)
    }

    private func option(_ c: Choice, _ label: String) -> some View {
        let selected = choice == c
        return Button {
            withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { choice = c }
            if c == .pick { showPicker = true }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(selected ? .primary : .tertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.primary.opacity(selected ? 0.07 : 0), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { shake += 1; return }
        let timeString = useTime ? LocalTime(hour: cal.component(.hour, from: time), minute: cal.component(.minute, from: time))?.description : nil
        let response = withAnimation(Theme.Motion.named(Theme.Motion.bouncy, reduceMotion: reduceMotion)) {
            app.perform(Request(op: .add, title: trimmed, date: day.description, time: timeString, source: "you"))
        }
        if response.ok {
            title = ""
            choice = .today
            useTime = false
        } else {
            shake += 1
        }
    }
}
