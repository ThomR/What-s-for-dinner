import LinkPresentation
import UIKit

/// Geeft het deelvenster een nette titel en icoon bij de gedeelde lijst.
final class DishListActivityItemSource: NSObject, UIActivityItemSource {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? {
        fileURL
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = String(localized: "share_list_title")
        // Geen force-unwrap: een ontbrekend icoon hoort geen crash te zijn.
        if let icon = UIImage(named: "ShareIcon") {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}
