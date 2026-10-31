import ReagentrKit
import SwiftUI
import WidgetKit

struct ReagentrWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    private var maxRows: Int { family == .systemLarge ? 9 : 4 }

    var body: some View {
        Group {
            if entry.items.isEmpty {
                EmptyDay(entry: entry, compact: family == .systemSmall)
            } else if family == .systemSmall {
                SmallDay(entry: entry)
            } else {
                ListDay(entry: entry, maxRows: maxRows, showFooter: family == .systemLarge)
            }
        }
        .fontDesign(.rounded)
        .widgetURL(URL(string: "reagentr://open"))
    }
}

/// Header: "Today" + open count + upcoming hint.
private struct Header: View {
    let entry: DayEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Today").font(.system(size: 13, weight: .semibold))
            Text(entry.items.count, format: .number)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Theme.accent, in: .capsule)
                .contentTransition(.numericText())
                .widgetAccentable()
            Spacer(minLength: 4)
            if !entry.upcoming.isEmpty {
                Text("\(entry.upcoming.count) upcoming")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }
}

struct TodoToggle: View {
    let todo: Todo
    var size: CGFloat = 18

    var body: some View {
        Toggle(isOn: todo.isDone, intent: ToggleTodoIntent(id: todo.id)) { EmptyView() }
            .toggleStyle(CheckToggleStyle(tint: Theme.source(todo.source).color, size: size))
            .accessibilityLabel(todo.isDone ? "Mark \(todo.title) not done" : "Mark \(todo.title) done")
    }
}

struct CheckToggleStyle: ToggleStyle {
    let tint: Color
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            CheckGlyph(isOn: configuration.isOn, tint: tint, size: size)
                .padding(3) // larger hit target than the glyph
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct Row: View {
    let todo: Todo
    let entry: DayEntry
    let lineLimit: Int

    var body: some View {
        let overdue = Schedule.bucket(todo, on: entry.today) == .overdue
        HStack(spacing: 6) {
            TodoToggle(todo: todo)
            Text(todo.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let chip = entry.chip(todo) { DateChip(text: chip, overdue: overdue) }
            SourceMark(source: todo.source)
        }
        .transition(.push(from: .bottom))
    }
}

private struct ListDay: View {
    let entry: DayEntry
    let maxRows: Int
    let showFooter: Bool

    var body: some View {
        let shown = Array(entry.items.prefix(maxRows))
        let hidden = entry.items.count - shown.count
        VStack(alignment: .leading, spacing: 6) {
            Header(entry: entry)
                .padding(.bottom, 2)
            ForEach(shown) { todo in
                Row(todo: todo, entry: entry, lineLimit: showFooter ? 2 : 1)
            }
            Spacer(minLength: 0)
            if hidden > 0 || (showFooter && !entry.upcoming.isEmpty) {
                HStack {
                    if hidden > 0 { Text("+\(hidden) more") }
                    Spacer()
                    if showFooter, let next = entry.nextUpcomingHuman { Text("Next: \(next)") }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SmallDay: View {
    let entry: DayEntry

    var body: some View {
        let next = entry.items[0]
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.date, format: .dateTime.weekday(.wide))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(entry.items.count, format: .number)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(next.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
            HStack(spacing: 4) {
                if let chip = entry.chip(next) {
                    DateChip(text: chip, overdue: Schedule.bucket(next, on: entry.today) == .overdue)
                }
                SourceMark(source: next.source)
                Spacer(minLength: 0)
                TodoToggle(todo: next, size: 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyDay: View {
    let entry: DayEntry
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: compact ? 30 : 36, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Theme.marigold, Theme.accent], startPoint: .top, endPoint: .bottom))
                .symbolRenderingMode(.hierarchical)
                .widgetAccentable()
            Text("All clear.")
                .font(.system(size: 13, weight: .semibold))
            if let next = entry.nextUpcomingHuman {
                Text("Next: \(next).")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if !compact {
                Text("Nothing due today.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Medium", as: .systemMedium) { ReagentrWidget() } timeline: { DayEntry.sample; DayEntry.empty }
#Preview("Large", as: .systemLarge) { ReagentrWidget() } timeline: { DayEntry.sample; DayEntry.empty }
#Preview("Small", as: .systemSmall) { ReagentrWidget() } timeline: { DayEntry.sample; DayEntry.empty }
