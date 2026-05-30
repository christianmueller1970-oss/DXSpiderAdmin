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
        } detail: {
            switch selection {
            case .connection:
                ConnectionView(model: connection)
            case .users:
                ManagementView(model: connection)
            }
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case connection
    case users

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: "Verbindung"
        case .users: "User & Nodes"
        }
    }

    var symbol: String {
        switch self {
        case .connection: "antenna.radiowaves.left.and.right"
        case .users: "person.2"
        }
    }
}

#Preview {
    ContentView()
}
