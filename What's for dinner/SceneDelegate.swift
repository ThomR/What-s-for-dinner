import UIKit
import CloudKit

/// Vangt een geaccepteerde uitnodiging voor een gedeelde lijst op.
///
/// Dit moet een scene-delegate zijn. Een SwiftUI-app is scene-gebaseerd, en dan
/// levert iOS de uitnodiging alleen hier af — in 2.0 stond deze methode op de
/// app-delegate, waar hij nooit werd aangeroepen. De app ging dan wel open, maar
/// de uitnodiging bleef op "uitgenodigd" staan.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    /// Koude start: de app draaide nog niet toen er op de uitnodiging werd
    /// getikt. Dan zit de uitnodiging in de verbindingsopties, en komt de
    /// methode hieronder níet.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            accept(metadata)
        }
    }

    /// Warme start: de app draaide al.
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        accept(metadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            await CloudSync.shared.accept(metadata)
        }
    }
}
