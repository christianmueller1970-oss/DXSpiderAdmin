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

    var body: some View {
        Group {
            if model.isConnected {
                HSplitView {
                    form
                        .frame(minWidth: 340, idealWidth: 390, maxWidth: 470)
                    console
                        .frame(minWidth: 360)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    "Nicht verbunden",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Im Bereich „Verbindung“ verbinden, um Befehle zu senden.")
                )
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

    // MARK: Form

    private var form: some View {
        Form {
            if !model.allowWrites {
                Section {
                    Label("Read-only — Registrierungs- und Schreibbefehle sind deaktiviert.",
                          systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Registrierung") {
                TextField("Rufzeichen (mehrere mit Leerzeichen)", text: $registerCalls)
                    .textFieldStyle(.roundedBorder)
                PreviewLine(command: registerList.isEmpty ? nil : .setRegister(callsigns: registerList))
                HStack {
                    Button("Registrieren") { pending = .setRegister(callsigns: registerList) }
                        .disabled(!model.allowWrites || !registerCallsValid)
                    Button("Aufheben", role: .destructive) { pending = .unsetRegister(callsigns: registerList) }
                        .disabled(!model.allowWrites || !registerCallsValid)
                }
                // show/registered ist read-only → direkt senden, keine Bestätigung.
                // Der Node unterstützt hier keine Wildcards/Mehrfach-Calls (Leerzeichen & '*'
                // werden gestrippt); leer = alle, ein exaktes Rufzeichen = genau dieses prüfen.
                HStack {
                    TextField("Einzelnes Rufzeichen prüfen (optional)", text: $registeredFilter)
                        .textFieldStyle(.roundedBorder)
                    Button("Registrierte anzeigen") {
                        Task { await model.send(.showRegistered(call: optional(registeredFilter))) }
                    }
                }
            }

            // Listen-Pflege (jeweils mehrere Einträge mit Leerzeichen). show/* ignorieren
            // node-seitig Argumente → listen immer alles. Schreiben braucht Schreibmodus.
            MultiCommandSection(
                title: "Bad Spotter", placeholder: "Rufzeichen (mehrere mit Leerzeichen)",
                setLabel: "Sperren", unsetLabel: "Freigeben", showLabel: "Bad Spotter anzeigen",
                allowWrites: model.allowWrites, requireCallsigns: true, pending: $pending,
                makeSet: { .setBadSpotter(callsigns: $0) }, makeUnset: { .unsetBadSpotter(callsigns: $0) },
                showCommand: .showBadSpotter, send: send
            )
            MultiCommandSection(
                title: "Lockout (User aussperren)", placeholder: "Rufzeichen (mehrere mit Leerzeichen)",
                setLabel: "Sperren", unsetLabel: "Freigeben", showLabel: "Lockouts anzeigen",
                allowWrites: model.allowWrites, requireCallsigns: true, pending: $pending,
                makeSet: { .setLockout(callsigns: $0) }, makeUnset: { .unsetLockout(callsigns: $0) },
                showCommand: .showLockout, send: send
            )
            MultiCommandSection(
                title: "Bad Node", placeholder: "Node-Rufzeichen (mehrere mit Leerzeichen)",
                setLabel: "Sperren", unsetLabel: "Freigeben", showLabel: "Bad Nodes anzeigen",
                allowWrites: model.allowWrites, requireCallsigns: true, pending: $pending,
                makeSet: { .setBadNode(callsigns: $0) }, makeUnset: { .unsetBadNode(callsigns: $0) },
                showCommand: .showBadNode, send: send
            )
            MultiCommandSection(
                title: "Bad DX (gefilterte DX-Calls)", placeholder: "Rufzeichen (mehrere mit Leerzeichen)",
                setLabel: "Sperren", unsetLabel: "Freigeben", showLabel: "Bad DX anzeigen",
                allowWrites: model.allowWrites, requireCallsigns: true, pending: $pending,
                makeSet: { .setBadDX(callsigns: $0) }, makeUnset: { .unsetBadDX(callsigns: $0) },
                showCommand: .showBadDX, send: send
            )
            MultiCommandSection(
                title: "Bad Words (Wortfilter)", placeholder: "Wörter (mehrere mit Leerzeichen)",
                setLabel: "Sperren", unsetLabel: "Freigeben", showLabel: "Bad Words anzeigen",
                allowWrites: model.allowWrites, requireCallsigns: false, pending: $pending,
                makeSet: { .setBadWord(words: $0) }, makeUnset: { .unsetBadWord(words: $0) },
                showCommand: .showBadWord, send: send
            )

            Section("Abfragen (read-only)") {
                Button("show/configuration") {
                    Task { await model.send(.showConfiguration) }
                }
                HStack {
                    TextField("Rufzeichen für Route", text: $routeCall)
                        .textFieldStyle(.roundedBorder)
                    Button("Route") {
                        Task { await model.send(.showRoute(callsign: routeCall)) }
                    }
                    .disabled(!routeCall.isValidCallsign)
                }
                PreviewLine(command: routeCall.isValidCallsign ? .showRoute(callsign: routeCall) : nil)
            }

            Section("Freie Eingabe") {
                TextField("Befehl …", text: $rawText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submitRaw)
                PreviewLine(command: rawTextTrimmed.isEmpty ? nil : .raw(rawTextTrimmed))
                Button("Senden", action: submitRaw)
                    .disabled(rawTextTrimmed.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Console

    private var console: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Konsole").font(.headline)
                Spacer()
                Button("Leeren", action: model.clearConsole)
                    .controlSize(.small)
                    .disabled(model.consoleLog.isEmpty)
            }
            ScrollView {
                Text(model.consoleLog.isEmpty ? "—" : model.consoleLog)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: .infinity)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
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

/// Reusable section for a list-style admin command: a multi-token field with set/unset
/// (destructive → routed through the parent's confirmation) and a read-only "show all"
/// button. Used for Bad Spotter, Lockout, Bad Node, Bad DX and Bad Words.
private struct MultiCommandSection: View {
    let title: String
    let placeholder: String
    let setLabel: String
    let unsetLabel: String
    let showLabel: String
    let allowWrites: Bool
    /// Free-form bad words skip the callsign check; everything else requires callsign-shaped tokens.
    let requireCallsigns: Bool
    @Binding var pending: DXCommand?
    let makeSet: ([String]) -> DXCommand
    let makeUnset: ([String]) -> DXCommand
    let showCommand: DXCommand
    let send: (DXCommand) -> Void

    @State private var text = ""

    private var tokens: [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
    }
    private var valid: Bool {
        guard !tokens.isEmpty else { return false }
        guard requireCallsigns else { return true }
        return tokens.allSatisfy { Callsign.isLikely(Callsign.normalize($0)) }
    }

    var body: some View {
        Section(title) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
            PreviewLine(command: tokens.isEmpty ? nil : makeSet(tokens))
            HStack {
                Button(setLabel, role: .destructive) { pending = makeSet(tokens) }
                    .disabled(!allowWrites || !valid)
                Button(unsetLabel) { pending = makeUnset(tokens) }
                    .disabled(!allowWrites || !valid)
            }
            // read-only → direkt senden (Node ignoriert hier Argumente, listet alles).
            Button(showLabel) { send(showCommand) }
        }
    }
}

/// Dry-run preview of the exact line a control will send (Konzeptdokument §2).
/// Shared with the info screen, so it stays internal rather than file-private.
struct PreviewLine: View {
    let command: DXCommand?

    var body: some View {
        if let command {
            Label("Sendet: \(command.line)", systemImage: "arrow.right.circle")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
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
