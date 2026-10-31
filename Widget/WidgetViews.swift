import RemyKit
import SwiftUI
import WidgetKit

struct RemyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View { WidgetBody(entry: entry, family: family) }
}

/// Family passed explicitly so the snapshot tool can render each size.
struct WidgetBody: View {
    let entry: DayEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallDay(entry: entry)
            default: ListDay(entry: entry, maxRows: family == .systemLarge ? 9 : 4, showUpcoming: family == .systemLarge)
            }
        }
        .widgetURL(URL(string: "remy://open"))
    }
}

/// "Today 3" on the left, "Sat 31" on the right.
private struct Header: View {
    let entry: DayEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("Today")
                .font(.system(size: 13, weight: .semibold))
            if !entry.items.isEmpty {
                Text(entry.items.count, format: .number)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 4)
            Text(entry.date, format: .dateTime.weekday(.abbreviated).day())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

struct TodoToggle: View {
    let todo: Todo
    var size: CGFloat = 15

    var body: some View {
        Toggle(isOn: todo.isDone, intent: ToggleTodoIntent(id: todo.id)) { EmptyView() }
            .toggleStyle(CheckToggleStyle(size: size))
            .accessibilityLabel(todo.isDone ? "Mark \(todo.title) not done" : "Mark \(todo.title) done")
    }
}

struct CheckToggleStyle: ToggleStyle {
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            CheckGlyph(isOn: configuration.isOn, size: size)
                .padding(4) // hit target larger than the glyph
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct Row: View {
    let todo: Todo
    let entry: DayEntry
    var dimmed = false

    var body: some View {
        HStack(spacing: 6) {
            TodoToggle(todo: todo)
            Text(todo.title)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(dimmed ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            RowMeta(text: dimmed ? todo.date?.start(in: entry.calendar).formatted(.dateTime.weekday(.abbreviated)) : entry.chip(todo),
                    overdue: Schedule.bucket(todo, on: entry.today) == .overdue, source: todo.source)
        }
        .padding(.leading, -4) // align the ring (not its hit padding) with the header text
        .transition(.push(from: .bottom))
    }
}

private struct ListDay: View {
    let entry: DayEntry
    let maxRows: Int
    var showUpcoming = false

    var body: some View {
        let shown = Array(entry.items.prefix(maxRows))
        let hidden = entry.items.count - shown.count
        // Large widget: spare rows preview what's coming, dimmed, under a quiet label.
        let spare = showUpcoming ? max(0, maxRows - shown.count - 1) : 0
        let soon = Array(entry.upcoming.prefix(spare))
        VStack(alignment: .leading, spacing: 0) {
            Header(entry: entry)
                .padding(.bottom, 6)
            if shown.isEmpty {
                Clear(entry: entry)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(shown) { Row(todo: $0, entry: entry) }
                    if !soon.isEmpty {
                        Text("Upcoming")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 10)
                            .padding(.bottom, 3)
                        ForEach(soon) { Row(todo: $0, entry: entry, dimmed: true) }
                    }
                }
                Spacer(minLength: 0)
                Footer(hidden: hidden, upcoming: entry.upcoming.count - soon.count)
            }
        }
    }
}

private struct Footer: View {
    let hidden: Int
    let upcoming: Int

    var body: some View {
        let parts = [hidden > 0 ? "\(hidden) more" : nil, upcoming > 0 ? "\(upcoming) upcoming" : nil].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct SmallDay: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.date, format: .dateTime.weekday(.wide))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(entry.items.count, format: .number)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(-1)
                .contentTransition(.numericText())
            Text(entry.items.count == 1 ? "to-do today" : "to-dos today")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 6)
            if let next = entry.items.first {
                HStack(alignment: .top, spacing: 5) {
                    TodoToggle(todo: next, size: 14)
                        .padding(.leading, -4)
                        .padding(.top, -3)
                    Text(next.title)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(2)
                }
            } else {
                Text(entry.nextUpcomingDay.map { "Next: \($0.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))" } ?? "All clear")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct Clear: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text("All clear")
                .font(.system(size: 13, weight: .semibold))
            Text(entry.nextUpcomingDay.map { "Next up \($0.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))." } ?? "Nothing due today.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}
