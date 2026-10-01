import Foundation
import Observation
import Sparkle

/// Wraps Sparkle's standard updater: automatic checks per Info.plist (`SUFeedURL`,
/// `SUPublicEDKey`) and a manual check for the app menu.
///
/// In the layout smoke test (`-uiSmokeTest`) the updater stays off, so no update dialog
/// covers the window that `scripts/uisnapshot.sh` photographs.
@MainActor
@Observable
final class UpdateController {
    private(set) var canCheckForUpdates = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        let smokeTest = ProcessInfo.processInfo.arguments.contains("-uiSmokeTest")
        controller = SPUStandardUpdaterController(
            startingUpdater: !smokeTest,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.canCheckForUpdates = value }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
