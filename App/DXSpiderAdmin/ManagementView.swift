import SwiftUI
import DXSpiderCore

/// User- & Node-Verwaltung (Konzeptdokument §6, MVP-Ziel M2): gefilterte Listen aus
/// `show/users`/`show/nodes`, Privilege-Änderung und „Station trennen" — destruktive
/// Aktionen nur im Schreibmodus und stets mit Bestätigung.
struct ManagementView: View {
    @Bindable var model: ConnectionViewModel
    @State private var tab: Tab = .users
    @State private var pending: PendingAction?

    enum Tab: String, CaseIterable, Identifiable {
        case users, nodes, registered
        var id: String { rawValue }
        var title: String {
            switch self {
            case .users: "User"
            case .nodes: "Nodes"
            case .registered: "Registriert"
            }
        }
    }

    var body: some View {
        Group {
            if model.isConnected {
                content
            } else {
                NotConnectedView(purpose: "um User und Nodes zu laden")
            }
        }
        .navigationTitle("User & Nodes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
                .disabled(!model.isConnected || model.isRefreshing)
            }
        }
        .task(id: model.isConnected) {
            if model.isConnected, model.users.isEmpty, model.nodes.isEmpty {
                await model.refreshAll()
            }
        }
        .confirmationDialog(
            pending?.title ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { action in
            Button(action.confirmLabel, role: .destructive) { Task { await run(action) } }
            Button("Abbrechen", role: .cancel) { }
        } message: { action in
            Text(action.message)
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Picker("Ansicht", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ModeBanner(allowWrites: model.allowWrites, blocked: "Ändern und Trennen gesperrt")
            }
            .padding()

            switch tab {
            case .users: usersTable
            case .nodes: nodesTable
            case .registered: registeredTable
            }
        }
    }

    /// Kurzer Zähler rechts neben dem Umschalter.
    private var summary: String {
        switch tab {
        case .users:
            return "\(model.users.count) User verbunden"
        case .nodes:
            let connected = model.nodes.filter(\.isConnected).count
            return "\(model.nodes.count) Nodes · \(connected) verbunden"
        case .registered:
            let rule = switch model.registrationRequired {
            case true?: " · Registrierung erforderlich"
            case false?: " · Registrierung nicht erforderlich"
            case nil: ""
            }
            return "\(model.registered.count) registriert\(rule)"
        }
    }

    private var usersTable: some View {
        Table(model.filteredUsers) {
            TableColumn("Rufzeichen") { user in
                CallsignCell(callsign: user.callsign, systemImage: "person.fill")
            }
            TableColumn("Aktionen") { user in
                HStack(spacing: 10) {
                    Menu {
                        ForEach(privilegeChoices, id: \.rawValue) { level in
                            Button("Level \(level.rawValue)\(levelHint(level))") {
                                pending = .setPriv(level, user.callsign)
                            }
                        }
                    } label: {
                        Label("Privileg", systemImage: "shield.lefthalf.filled")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Privileg-Level setzen")

                    Button("Trennen", systemImage: "bolt.horizontal.circle", role: .destructive) {
                        pending = .boot(user.callsign)
                    }
                    .buttonStyle(.borderless)
                    .help("Station vom Node trennen")
                }
                .disabled(!model.allowWrites)
            }
            .width(min: 180, ideal: 200, max: 240)
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
        .overlay {
            ListPlaceholder(isEmpty: model.filteredUsers.isEmpty, isLoading: model.isRefreshing,
                            search: model.userSearch, title: "Keine User verbunden",
                            systemImage: "person.2.slash")
        }
        .searchable(text: $model.userSearch, prompt: "User filtern")
    }

    private var nodesTable: some View {
        Table(model.filteredNodes) {
            TableColumn("Status") { node in
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(node.isConnected ? Color.green : Color.secondary.opacity(0.5))
                    Text(node.isConnected ? "verbunden" : "getrennt")
                        .foregroundStyle(node.isConnected ? .primary : .secondary)
                }
            }
            .width(min: 90, ideal: 110, max: 130)
            TableColumn("Node") { node in
                CallsignCell(callsign: node.callsign, systemImage: "server.rack")
            }
            TableColumn("Version") { node in
                Text(node.version ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
        .overlay {
            ListPlaceholder(isEmpty: model.filteredNodes.isEmpty, isLoading: model.isRefreshing,
                            search: model.nodeSearch, title: "Keine Nodes",
                            systemImage: "network.slash")
        }
        .searchable(text: $model.nodeSearch, prompt: "Nodes filtern")
    }

    private var registeredTable: some View {
        Table(model.filteredRegistered) {
            TableColumn("Rufzeichen") { user in
                CallsignCell(callsign: user.callsign, systemImage: "checkmark.seal.fill")
            }
            TableColumn("Aktion") { user in
                Button("Aufheben", systemImage: "xmark.seal", role: .destructive) {
                    pending = .unregister(user.callsign)
                }
                .buttonStyle(.borderless)
                .disabled(!model.allowWrites)
                .help("Registrierung aufheben")
            }
            .width(min: 110, ideal: 120, max: 140)
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
        .overlay {
            ListPlaceholder(isEmpty: model.filteredRegistered.isEmpty, isLoading: model.isRefreshing,
                            search: model.registeredSearch, title: "Keine registrierten Rufzeichen",
                            systemImage: "checkmark.seal")
        }
        .searchable(text: $model.registeredSearch, prompt: "Registrierte filtern")
    }

    private var privilegeChoices: [PrivilegeLevel] {
        [0, 1, 5, 9].compactMap(PrivilegeLevel.init(rawValue:))
    }

    private func levelHint(_ level: PrivilegeLevel) -> String {
        switch level.rawValue {
        case 0: " — User"
        case 9: " — Sysop"
        default: ""
        }
    }

    private func run(_ action: PendingAction) async {
        switch action {
        case .boot(let callsign):
            await model.boot(callsign)
        case .setPriv(let level, let callsign):
            await model.setPrivilege(level, for: callsign)
        case .unregister(let callsign):
            await model.unregister(callsign)
        }
        pending = nil
    }
}

/// A destructive action awaiting explicit confirmation.
enum PendingAction: Identifiable {
    case boot(String)
    case setPriv(PrivilegeLevel, String)
    case unregister(String)

    var id: String {
        switch self {
        case .boot(let call): "boot-\(call)"
        case .setPriv(let level, let call): "priv-\(level.rawValue)-\(call)"
        case .unregister(let call): "unreg-\(call)"
        }
    }
    var title: String {
        switch self {
        case .boot(let call): "Station \(call) trennen?"
        case .setPriv(let level, let call): "\(call) auf Level \(level.rawValue) setzen?"
        case .unregister(let call): "Registrierung von \(call) aufheben?"
        }
    }
    var message: String {
        switch self {
        case .boot(let call):
            "Der Befehl „boot \(call)“ trennt die Station vom Node. Destruktiver Befehl."
        case .setPriv(let level, let call):
            "Der Befehl „set/priv \(level.rawValue) \(call)“ ändert die Rechte. Destruktiver Befehl."
        case .unregister(let call):
            "Der Befehl „unset/register \(call)“ entzieht das Spotting-Recht. Destruktiver Befehl."
        }
    }
    var confirmLabel: String {
        switch self {
        case .boot: "Trennen"
        case .setPriv: "Setzen"
        case .unregister: "Aufheben"
        }
    }
}

#Preview {
    ManagementView(model: ConnectionViewModel())
        .frame(width: 700, height: 500)
}
