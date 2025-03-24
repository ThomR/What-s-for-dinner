import WidgetKit
import SwiftUI

/// ✅ Bundelt en configureert de DinnerWidget voor gebruik in het widget center.
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
