import SwiftUI

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
    case users
    case commands
    case blocklists
    case filters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: "Verbindung"
        case .users: "User & Nodes"
        case .commands: "Command Builder"
        case .blocklists: "Sperrlisten"
        case .filters: "Filter-Editor"
        }
    }

    var symbol: String {
        switch self {
        case .connection: "antenna.radiowaves.left.and.right"
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
