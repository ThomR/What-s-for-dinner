import WidgetKit
import SwiftUI

@main
struct DinnerWidget: Widget {
    let kind: String = "DinnerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DinnerWidgetProvider()) { entry in
            DinnerWidgetView(entry: entry)
        }
        .configurationDisplayName("What's For Dinner")
        .description("Shows the top dish in your list.")
        .supportedFamilies([.systemSmall])
    }
}
