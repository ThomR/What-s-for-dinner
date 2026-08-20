import WidgetKit
import SwiftUI

@main
struct DinnerWidget: Widget {
    let kind = "DinnerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DinnerWidgetProvider()) { entry in
            DinnerWidgetView(entry: entry)
        }
        .configurationDisplayName("What's For Dinner")
        .description(String(localized: "widget_description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
