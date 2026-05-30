import SwiftUI

/// App entry point. A single document-less window hosting the control panel.
@main
struct DXSpiderAdminApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
    }
}
