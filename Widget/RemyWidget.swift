import RemyKit
import SwiftUI
import WidgetKit

@main
struct RemyWidgetBundle: WidgetBundle {
    var body: some Widget { RemyWidget() }
}

struct RemyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Paths.widgetKind, provider: Provider()) { entry in
            RemyWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Remy")
        .description("Today's to-dos from you and your agents.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview("Medium", as: .systemMedium) { RemyWidget() } timeline: { DayEntry.sample; DayEntry.empty }
#Preview("Large", as: .systemLarge) { RemyWidget() } timeline: { DayEntry.sample; DayEntry.empty }
#Preview("Small", as: .systemSmall) { RemyWidget() } timeline: { DayEntry.sample; DayEntry.empty }
