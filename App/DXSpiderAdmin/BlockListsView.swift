import SwiftUI
import DXSpiderCore

/// Structured, searchable view of the node's block lists (Bad Spotter, Lockout, Bad Node,
/// Bad DX, Bad Words). Picks a list, loads it via the matching `show/…`, filters client-side
/// and removes a single entry inline (destructive → confirmed). Mirrors the "Registriert" tab.
struct BlockListsView: View {
    @Bindable var model: ConnectionViewModel
    @State private var kind: BlockListKind = .badSpotter
    @State private var pendingRemove: String?

    var body: some View {
        Group {
            if model.isConnected {
                content
            } else {
                ContentUnavailableView(
                    "Nicht verbunden",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Im Bereich „Verbindung“ verbinden, um die Listen zu laden.")
                )
            }
        }
        .navigationTitle("Sperrlisten")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.loadBlockList(kind.showCommand) }
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
                .disabled(!model.isConnected || model.isRefreshing)
            }
        }
        .task(id: kind) {
            if model.isConnected { await model.loadBlockList(kind.showCommand) }
        }
        .confirmationDialog(
            "Eintrag entfernen?",
            isPresented: Binding(get: { pendingRemove != nil }, set: { if !$0 { pendingRemove = nil } }),
            presenting: pendingRemove
        ) { entry in
            Button("Entfernen", role: .destructive) {
                Task {
                    await model.removeBlockEntry(remove: kind.unset([entry]), reload: kind.showCommand)
                    pendingRemove = nil
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { entry in
            Text("Sendet „\(kind.unset([entry]).line)“ — destruktiver Befehl.")
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            Picker("Liste", selection: $kind) {
                ForEach(BlockListKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            if !model.allowWrites {
                Label("Read-only — Entfernen ist deaktiviert. Im Bereich „Verbindung“ freischalten.",
                      systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary.opacity(0.25))
            }

            List {
                Section {
                    if model.filteredBlockEntries.isEmpty {
                        Text(model.isRefreshing ? "Lade …" : "Keine Einträge.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.filteredBlockEntries, id: \.self) { entry in
                        HStack {
                            Text(entry).font(.body.monospaced())
                            Spacer()
                            Button("Entfernen", role: .destructive) { pendingRemove = entry }
                                .disabled(!model.allowWrites)
                        }
                    }
                } header: {
                    Text("\(model.blockEntries.count) Einträge")
                }
            }
            .searchable(text: $model.blockSearch, prompt: "\(kind.title) filtern")
        }
    }
}

/// The block lists the node exposes, with their show/unset command mapping.
enum BlockListKind: String, CaseIterable, Identifiable {
    case badSpotter, lockout, badNode, badDX, badWord
    var id: String { rawValue }

    var title: String {
        switch self {
        case .badSpotter: "Bad Spotter"
        case .lockout: "Lockout"
        case .badNode: "Bad Node"
        case .badDX: "Bad DX"
        case .badWord: "Bad Words"
        }
    }

    var showCommand: DXCommand {
        switch self {
        case .badSpotter: .showBadSpotter
        case .lockout: .showLockout
        case .badNode: .showBadNode
        case .badDX: .showBadDX
        case .badWord: .showBadWord
        }
    }

    /// Bad Words sind freie Wörter, alles andere muss wie ein Rufzeichen aussehen.
    var requiresCallsigns: Bool { self != .badWord }

    var explanation: String {
        switch self {
        case .badSpotter: "Spots dieser Stationen werden verworfen."
        case .lockout: "Diese User können sich nicht mehr am Node anmelden."
        case .badNode: "Von diesen Nodes werden keine Spots übernommen."
        case .badDX: "Spots auf diese DX-Rufzeichen werden verworfen."
        case .badWord: "Spots mit diesen Wörtern im Kommentar werden verworfen."
        }
    }

    func set(_ entries: [String]) -> DXCommand {
        switch self {
        case .badSpotter: .setBadSpotter(callsigns: entries)
        case .lockout: .setLockout(callsigns: entries)
        case .badNode: .setBadNode(callsigns: entries)
        case .badDX: .setBadDX(callsigns: entries)
        case .badWord: .setBadWord(words: entries)
        }
    }

    func unset(_ entries: [String]) -> DXCommand {
        switch self {
        case .badSpotter: .unsetBadSpotter(callsigns: entries)
        case .lockout: .unsetLockout(callsigns: entries)
        case .badNode: .unsetBadNode(callsigns: entries)
        case .badDX: .unsetBadDX(callsigns: entries)
        case .badWord: .unsetBadWord(words: entries)
        }
    }
}

#Preview {
    BlockListsView(model: ConnectionViewModel())
        .frame(width: 700, height: 500)
}
