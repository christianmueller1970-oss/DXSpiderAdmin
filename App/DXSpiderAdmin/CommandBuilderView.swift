import SwiftUI
import DXSpiderCore

/// Command Builder (Konzeptdokument §6, M3): Eingabemasken für Registrierung, read-only-
/// Abfragen und freie Eingabe — jeweils mit Dry-Run-Preview (§2) des exakt erzeugten Befehls
/// und Bestätigung für destruktive Aktionen. Ergebnisse erscheinen in der geteilten Konsole.
struct CommandBuilderView: View {
    @Bindable var model: ConnectionViewModel
    @State private var registerCalls = ""
    @State private var registeredFilter = ""
    @State private var routeCall = ""
    @State private var rawText = ""
    @State private var pending: DXCommand?
    @State private var area: Area = .registration
    @State private var blockKind: BlockListKind = .badSpotter

    /// Die Abschnitte des Builders, umschaltbar statt untereinander gestapelt.
    enum Area: String, CaseIterable, Identifiable {
        case registration, blockLists, queries, raw
        var id: String { rawValue }
        var title: String {
            switch self {
            case .registration: "Registrierung"
            case .blockLists: "Sperrlisten"
            case .queries: "Abfragen"
            case .raw: "Frei"
            }
        }
    }

    var body: some View {
        Group {
            if model.isConnected {
                HSplitView {
                    builder
                        .frame(minWidth: 360, idealWidth: 420, maxWidth: 500)
                    ConsolePane(model: model)
                        .frame(minWidth: 360)
                        .padding()
                }
            } else {
                NotConnectedView(purpose: "um Befehle zu senden")
            }
        }
        .navigationTitle("Command Builder")
        .confirmationDialog(
            "Befehl senden?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { command in
            Button("Senden", role: .destructive) {
                Task { await model.send(command); pending = nil }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { command in
            Text("Sendet „\(command.line)“ — destruktiver Befehl.")
        }
    }

    // MARK: Builder

    private var builder: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ModeBanner(allowWrites: model.allowWrites,
                           blocked: "Schreibbefehle gesperrt")
                Picker("Bereich", selection: $area) {
                    ForEach(Area.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding([.horizontal, .top])

            Form {
                switch area {
                case .registration: registrationSections
                case .blockLists: blockListSections
                case .queries: querySections
                case .raw: rawSections
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder private var registrationSections: some View {
        Section {
            TextField("Rufzeichen", text: $registerCalls, prompt: Text("DL1ABC HB9XYZ …"))
            PreviewLine(command: registerList.isEmpty ? nil : .setRegister(callsigns: registerList))
            HStack {
                Button("Registrieren", systemImage: "checkmark.seal") {
                    pending = .setRegister(callsigns: registerList)
                }
                .disabled(!model.allowWrites || !registerCallsValid)
                Button("Aufheben", systemImage: "xmark.seal", role: .destructive) {
                    pending = .unsetRegister(callsigns: registerList)
                }
                .disabled(!model.allowWrites || !registerCallsValid)
            }
        } header: {
            Text("Spotting-Recht vergeben")
        } footer: {
            Text("Mehrere Rufzeichen mit Leerzeichen trennen.")
        }

        // show/registered ist read-only → direkt senden, keine Bestätigung.
        // Der Node unterstützt hier keine Wildcards/Mehrfach-Calls (Leerzeichen & '*'
        // werden gestrippt); leer = alle, ein exaktes Rufzeichen = genau dieses prüfen.
        Section {
            TextField("Rufzeichen", text: $registeredFilter, prompt: Text("leer = alle"))
            Button("Registrierte anzeigen", systemImage: "list.bullet") {
                Task { await model.send(.showRegistered(call: optional(registeredFilter))) }
            }
        } header: {
            Text("Prüfen (read-only)")
        } footer: {
            Text("Nur ein exaktes Rufzeichen — der Node kennt hier keine Wildcards.")
        }
    }

    @ViewBuilder private var blockListSections: some View {
        Section {
            Picker("Liste", selection: $blockKind) {
                ForEach(BlockListKind.allCases) { Text($0.title).tag($0) }
            }
        } footer: {
            Text(blockKind.explanation)
        }

        // Listen-Pflege (jeweils mehrere Einträge mit Leerzeichen). show/* ignorieren
        // node-seitig Argumente → listen immer alles. Schreiben braucht Schreibmodus.
        MultiCommandSection(kind: blockKind, allowWrites: model.allowWrites,
                            pending: $pending, send: send)
            .id(blockKind)
    }

    @ViewBuilder private var querySections: some View {
        Section("Konfiguration") {
            Button("show/configuration", systemImage: "point.3.connected.trianglepath.dotted") {
                Task { await model.send(.showConfiguration) }
            }
        }
        Section {
            TextField("Rufzeichen", text: $routeCall, prompt: Text("HB9XYZ"))
                .onSubmit { if routeCall.isValidCallsign { send(.showRoute(callsign: routeCall)) } }
            PreviewLine(command: routeCall.isValidCallsign ? .showRoute(callsign: routeCall) : nil)
            Button("Route abfragen", systemImage: "arrow.triangle.branch") {
                send(.showRoute(callsign: routeCall))
            }
            .disabled(!routeCall.isValidCallsign)
        } header: {
            Text("Route")
        } footer: {
            Text("Über welchen Node eine Station erreichbar ist.")
        }
    }

    @ViewBuilder private var rawSections: some View {
        Section {
            TextField("Befehl", text: $rawText, prompt: Text("show/dx 10"))
                .font(.body.monospaced())
                .onSubmit(submitRaw)
            PreviewLine(command: rawTextTrimmed.isEmpty ? nil : .raw(rawTextTrimmed))
            Button("Senden", systemImage: "paperplane", action: submitRaw)
                .disabled(rawTextTrimmed.isEmpty)
        } header: {
            Text("Freie Eingabe")
        } footer: {
            Text("Unbekannte Befehle gelten als destruktiv und werden vor dem Senden bestätigt.")
        }
    }

    // MARK: Helpers

    private var rawTextTrimmed: String {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fire-and-forget send for read-only buttons (no confirmation needed).
    private func send(_ command: DXCommand) {
        Task { await model.send(command) }
    }

    /// Normalised, non-empty callsigns parsed from a space-separated field.
    private var registerList: [String] { Self.callList(registerCalls) }
    /// At least one token and every token looks like a callsign.
    private var registerCallsValid: Bool { Self.allValidCallsigns(registerCalls) }

    /// Trimmed text, or `nil` when empty — used for optional `show/…` filters.
    private func optional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func callList(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace)
            .map { Callsign.normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func allValidCallsigns(_ text: String) -> Bool {
        let list = callList(text)
        return !list.isEmpty && list.allSatisfy { Callsign.isLikely($0) }
    }

    /// Raw commands have unknown intent and are treated as destructive → confirm first.
    private func submitRaw() {
        guard !rawTextTrimmed.isEmpty else { return }
        pending = .raw(rawTextTrimmed)
    }
}

/// Section for one block list: a multi-token field with set/unset (destructive → routed
/// through the parent's confirmation) and a read-only "show all" button.
private struct MultiCommandSection: View {
    let kind: BlockListKind
    let allowWrites: Bool
    @Binding var pending: DXCommand?
    let send: (DXCommand) -> Void

    @State private var text = ""

    private var tokens: [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
    }
    private var valid: Bool {
        guard !tokens.isEmpty else { return false }
        guard kind.requiresCallsigns else { return true }
        return tokens.allSatisfy { Callsign.isLikely(Callsign.normalize($0)) }
    }

    var body: some View {
        Section {
            TextField(kind.requiresCallsigns ? "Rufzeichen" : "Wörter", text: $text,
                      prompt: Text(kind.requiresCallsigns ? "DL1ABC HB9XYZ …" : "wort1 wort2 …"))
            PreviewLine(command: tokens.isEmpty ? nil : kind.set(tokens))
            HStack {
                Button("Sperren", systemImage: "nosign", role: .destructive) {
                    pending = kind.set(tokens)
                }
                .disabled(!allowWrites || !valid)
                Button("Freigeben", systemImage: "checkmark.circle") {
                    pending = kind.unset(tokens)
                }
                .disabled(!allowWrites || !valid)
            }
        } header: {
            Text("Einträge ändern")
        } footer: {
            Text("Mehrere Einträge mit Leerzeichen trennen.")
        }

        Section("Anzeigen (read-only)") {
            // read-only → direkt senden (Node ignoriert hier Argumente, listet alles).
            Button("\(kind.title) anzeigen", systemImage: "list.bullet") { send(kind.showCommand) }
        }
    }
}

extension String {
    /// Whether the string is a plausible callsign (delegates to the Core heuristic).
    var isValidCallsign: Bool {
        Callsign.isLikely(Callsign.normalize(self))
    }
}

#Preview {
    CommandBuilderView(model: ConnectionViewModel())
        .frame(width: 820, height: 540)
}
