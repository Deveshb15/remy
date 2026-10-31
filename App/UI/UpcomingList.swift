import ReagentrKit
import SwiftUI

/// Future to-dos grouped by day, with human day headers ("Tomorrow", "Tue, Nov 3").
struct UpcomingList: View {
    @Environment(AppController.self) private var app
    let todos: [Todo]

    var body: some View {
        let groups = Dictionary(grouping: todos) { $0.date! }.sorted { $0.key < $1.key }
        if !groups.isEmpty {
            SectionLabel(text: "Upcoming").padding(.top, 8)
            ForEach(groups, id: \.key) { day, items in
                Text(Schedule.human(date: day, time: nil, today: app.today, calendar: .autoupdatingCurrent))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                ForEach(items) { TodoRow(todo: $0).transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top))) }
            }
        }
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
                HStack(spacing: 4) {
                    Text("Done").font(.system(size: 13, weight: .semibold))
                    Text("\(recent.count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.top, 12)
                .padding(.bottom, 2)
            }
            .buttonStyle(PressableStyle())
            if expanded {
                ForEach(recent) { TodoRow(todo: $0).transition(.opacity) }
            }
        }
    }
}
