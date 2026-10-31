import ReagentrKit
import SwiftUI
import WidgetKit

@main
struct ReagentrWidgetBundle: WidgetBundle {
    var body: some Widget { ReagentrWidget() }
}

struct ReagentrWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Paths.widgetKind, provider: Provider()) { entry in
            ReagentrWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Reagentr")
        .description("Today's to-dos from you and your agents.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
