import ReagentrKit
import SwiftUI

/// Title field + date chips (Today, Tomorrow, Next week, Pick a date) + optional time.
struct QuickAdd: View {
    @Environment(AppController.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var chipNS

    enum Choice: Hashable { case today, tomorrow, nextWeek, pick }

    @State private var title = ""
    @State private var choice: Choice = .today
    @State private var picked = Date.now
    @State private var showPicker = false
    @State private var useTime = false
    @State private var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var shake = 0
    @FocusState private var focused: Bool

    private var cal: Calendar { .autoupdatingCurrent }

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
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(focused ? Theme.accent : .secondary)
                TextField("Add a to-do", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .focused($focused)
                    .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.4) : Theme.accent)
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut(.return, modifiers: [])
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focused ? Theme.accent.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, x in view.offset(x: still ? 0 : x) } keyframes: { _ in
                SpringKeyframe(-6, duration: 0.06); SpringKeyframe(5, duration: 0.08); SpringKeyframe(0, duration: 0.2, spring: .bouncy)
            }

            HStack(spacing: 4) {
                chip(.today, "Today")
                chip(.tomorrow, "Tomorrow")
                chip(.nextWeek, "Next week")
                chip(.pick, choice == .pick ? Schedule.human(date: day, time: nil, today: app.today, calendar: cal) : "Pick a date", icon: "calendar")
                    .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                        DatePicker("Date", selection: $picked, in: Date.now..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .padding(10)
                    }
                Spacer(minLength: 0)
                Button {
                    withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { useTime.toggle() }
                } label: {
                    Image(systemName: useTime ? "clock.fill" : "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(useTime ? Theme.accent : .secondary)
                        .frame(width: 24, height: 22)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressableStyle())
                .help(useTime ? "Remove time" : "Add a time")
            }
            if useTime {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
                    .font(.system(size: 12, weight: .medium))
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    private func chip(_ c: Choice, _ label: String, icon: String? = nil) -> some View {
        let selected = choice == c
        return Button {
            withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { choice = c }
            if c == .pick { showPicker = true }
        } label: {
            HStack(spacing: 3) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
                Text(label).lineLimit(1)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(selected ? .white : .secondary)
            .padding(.leading, icon == nil ? 8 : 4) // icon side padding = vertical padding (badge rule)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background {
                if selected {
                    Capsule().fill(Theme.accent).matchedGeometryEffect(id: "chip", in: chipNS)
                } else {
                    Capsule().fill(Color.primary.opacity(0.06))
                }
            }
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
            withAnimation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion)) { choice = .today; useTime = false }
        } else {
            shake += 1
        }
    }
}
