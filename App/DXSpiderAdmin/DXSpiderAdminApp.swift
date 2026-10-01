import SwiftUI

/// App entry point. A single document-less window hosting the control panel, plus the
/// Sparkle updater behind "Nach Updates suchen …" in the app menu.
@main
struct DXSpiderAdminApp: App {
    @State private var updates = UpdateController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Nach Updates suchen …", action: updates.checkForUpdates)
                    .disabled(!updates.canCheckForUpdates)
            }
        }
    }
}
