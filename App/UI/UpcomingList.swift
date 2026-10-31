import ReagentrKit
import SwiftUI

/// Future to-dos grouped by day: "Tomorrow", "Tuesday  Nov 3".
struct UpcomingList: View {
    @Environment(AppController.self) private var app
    let todos: [Todo]

    var body: some View {
        let cal = Calendar.autoupdatingCurrent
        let groups = Dictionary(grouping: todos) { $0.date! }.sorted { $0.key < $1.key }
        ForEach(groups, id: \.key) { day, items in
            SectionLabel(text: Self.dayName(day, today: app.today, cal), detail: Self.dayDetail(day, today: app.today, cal))
            ForEach(items) { TodoRow(todo: $0).transition(.opacity) }
        }
    }

    static func dayName(_ d: LocalDate, today: LocalDate, _ cal: Calendar) -> String {
        if d == today.adding(days: 1, calendar: cal) { return "Tomorrow" }
        return d.start(in: cal).formatted(.dateTime.weekday(.wide))
    }

    static func dayDetail(_ d: LocalDate, today: LocalDate, _ cal: Calendar) -> String {
        d.start(in: cal).formatted(d.year == today.year ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year())
    }
}

struct DoneList: View {
    let todos: [Todo]
    @Binding var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let recent = todos.filter { ($0.completedAt ?? .distantPast) > Date.now.addingTimeInterval(-30 * 86_400) }
        if !recent.isEmpty {
            Button {
                withAnimation(Theme.Motion.named(Theme.Motion.settle, reduceMotion: reduceMotion)) { expanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Text(expanded ? "Hide done" : "Show \(recent.count) done")
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            if expanded {
                ForEach(recent) { TodoRow(todo: $0).transition(.opacity) }
            }
        }
    }
}
