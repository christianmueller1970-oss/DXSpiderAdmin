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
                NotConnectedView(purpose: "um die Sperrlisten zu laden")
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Liste", selection: $kind) {
                        ForEach(BlockListKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                    Text("\(model.blockEntries.count) Einträge")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(kind.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ModeBanner(allowWrites: model.allowWrites, blocked: "Entfernen gesperrt")
            }
            .padding()

            Table(model.filteredBlockEntries.map(BlockEntry.init)) {
                TableColumn(kind.requiresCallsigns ? "Rufzeichen" : "Wort") { entry in
                    CallsignCell(callsign: entry.id,
                                 systemImage: kind.requiresCallsigns ? "nosign" : "text.badge.xmark")
                }
                TableColumn("Aktion") { entry in
                    Button("Entfernen", systemImage: "trash", role: .destructive) {
                        pendingRemove = entry.id
                    }
                    .buttonStyle(.borderless)
                    .disabled(!model.allowWrites)
                    .help("Eintrag aus der Liste entfernen")
                }
                .width(min: 110, ideal: 120, max: 140)
            }
            .tableStyle(.inset)
            .alternatingRowBackgrounds()
            .overlay {
                ListPlaceholder(isEmpty: model.filteredBlockEntries.isEmpty, isLoading: model.isRefreshing,
                                search: model.blockSearch, title: "\(kind.title): keine Einträge",
                                systemImage: "checkmark.shield")
            }
            .searchable(text: $model.blockSearch, prompt: "\(kind.title) filtern")
        }
    }
}

/// Table row wrapper: block list entries are plain strings.
private struct BlockEntry: Identifiable {
    let id: String
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
