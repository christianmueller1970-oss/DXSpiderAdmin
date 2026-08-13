import SwiftUI
import AppKit
import DXSpiderCore

/// Top-level navigation: fixed sidebar (Konzeptdokument §6) with a detail area.
/// Only the connection area exists in M1; User/Node management arrives in M2.
struct ContentView: View {
    @State private var selection: SidebarItem = .connection
    @State private var connection = ConnectionViewModel()

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) {
                Text("DXSpider Admin \(Self.appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        } detail: {
            switch selection {
            case .connection:
                ConnectionView(model: connection)
            case .info:
                NodeInfoView(model: connection)
            case .users:
                ManagementView(model: connection)
            case .commands:
                CommandBuilderView(model: connection)
            case .blocklists:
                BlockListsView(model: connection)
            case .filters:
                FilterEditorView(model: connection)
            }
        }
        .task { await runSmokeTestIfRequested() }
    }

    /// Layout-Smoke-Test: `DXSpiderAdmin -uiSmokeTest <bereich>` startet im Demo-Backend,
    /// verbindet sich und öffnet den genannten Sidebar-Bereich. Damit lässt sich eine
    /// Ansicht ohne erreichbaren Node aufnehmen und prüfen (`scripts/uisnapshot.sh`).
    /// Ohne das Argument passiert hier nichts.
    private func runSmokeTestIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiSmokeTest"), flag + 1 < arguments.count,
              let target = SidebarItem(rawValue: arguments[flag + 1])
        else { return }

        selection = target
        connection.useDemoBackend = true
        await connection.connect()

        // Ohne LaunchServices platziert macOS das Fenster teils unter der Menüleiste.
        if let window = NSApplication.shared.windows.first {
            window.setFrame(NSRect(x: 120, y: 120, width: 1280, height: 820), display: true)
        }

        // Optional eine Abfrage mitlaufen lassen, damit der Schnappschuss auch die
        // gefüllte Ausgabe zeigt: `-uiSmokeQuery show/node`.
        if let flag = arguments.firstIndex(of: "-uiSmokeQuery"), flag + 1 < arguments.count,
           let query = NodeQuery.query(id: arguments[flag + 1]) {
            await connection.runQuery(query, argument: query.defaultArgument)
        }
    }

    /// App version + build, read from the bundle (e.g. "v0.1 (1)").
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) (\(build))"
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case connection
    case info
    case users
    case commands
    case blocklists
    case filters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: "Verbindung"
        case .info: "Info & Diagnose"
        case .users: "User & Nodes"
        case .commands: "Command Builder"
        case .blocklists: "Sperrlisten"
        case .filters: "Filter-Editor"
        }
    }

    var symbol: String {
        switch self {
        case .connection: "antenna.radiowaves.left.and.right"
        case .info: "stethoscope"
        case .users: "person.2"
        case .commands: "hammer"
        case .blocklists: "nosign"
        case .filters: "line.3.horizontal.decrease.circle"
        }
    }
}

#Preview {
    ContentView()
}
