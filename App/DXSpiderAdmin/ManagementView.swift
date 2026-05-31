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
                ContentUnavailableView(
                    "Nicht verbunden",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Im Bereich „Verbindung“ verbinden, um User und Nodes zu laden.")
                )
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
            Picker("Ansicht", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            if !model.allowWrites {
                readOnlyBanner
            }

            switch tab {
            case .users: usersList
            case .nodes: nodesList
            case .registered: registeredList
            }
        }
    }

    private var readOnlyBanner: some View {
        Label("Read-only — destruktive Aktionen sind deaktiviert. Im Bereich „Verbindung“ freischalten.",
              systemImage: "lock.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.25))
    }

    private var usersList: some View {
        List {
            if model.filteredUsers.isEmpty {
                Text(model.isRefreshing ? "Lade …" : "Keine User.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.filteredUsers) { user in
                HStack {
                    Text(user.callsign).font(.body.monospaced())
                    Spacer()
                    Menu("Priv setzen") {
                        ForEach(privilegeChoices, id: \.rawValue) { level in
                            Button("Level \(level.rawValue)\(levelHint(level))") {
                                pending = .setPriv(level, user.callsign)
                            }
                        }
                    }
                    .fixedSize()
                    .disabled(!model.allowWrites)
                    Button("Trennen", role: .destructive) {
                        pending = .boot(user.callsign)
                    }
                    .disabled(!model.allowWrites)
                }
            }
        }
        .searchable(text: $model.userSearch, prompt: "User filtern")
    }

    private var nodesList: some View {
        List {
            if model.filteredNodes.isEmpty {
                Text(model.isRefreshing ? "Lade …" : "Keine Nodes.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.filteredNodes) { node in
                HStack(spacing: 8) {
                    Image(systemName: node.isConnected ? "circle.fill" : "circle")
                        .foregroundStyle(node.isConnected ? .green : .secondary)
                        .font(.caption2)
                    Text(node.callsign).font(.body.monospaced())
                    if let version = node.version {
                        Text(version).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(node.isConnected ? "verbunden" : "getrennt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $model.nodeSearch, prompt: "Nodes filtern")
    }

    private var registeredList: some View {
        List {
            Section {
                if model.filteredRegistered.isEmpty {
                    Text(model.isRefreshing ? "Lade …" : "Keine registrierten Rufzeichen.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.filteredRegistered) { user in
                    HStack {
                        Text(user.callsign).font(.body.monospaced())
                        Spacer()
                        Button("Aufheben", role: .destructive) {
                            pending = .unregister(user.callsign)
                        }
                        .disabled(!model.allowWrites)
                    }
                }
            } header: {
                if let required = model.registrationRequired {
                    Text("Registrierung: \(required ? "erforderlich" : "nicht erforderlich") · \(model.registered.count) Calls")
                }
            }
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
