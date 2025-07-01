import LinkPresentation
import UIKit

class DishListActivityItemSource: NSObject, UIActivityItemSource {

    var fileURL: URL
    var title: String

    init(fileURL: URL, title: String) {
        self.fileURL = fileURL
        self.title = title
        super.init()
    }

    // De placeholder die wordt gebruikt terwijl de echte data laadt
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }

    // Het daadwerkelijke item dat gedeeld wordt (het JSON-bestand)
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return fileURL
    }

    // De metadata voor de rijke voorvertoning (titel en icoon)
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = self.title
        metadata.iconProvider = NSItemProvider(object: UIImage(named: "ShareIcon")!)
        // Je kunt hier zelfs een URL naar je app instellen als je die hebt
        // metadata.originalURL = URL(fileURLWithPath: "")
        return metadata
    }
}
