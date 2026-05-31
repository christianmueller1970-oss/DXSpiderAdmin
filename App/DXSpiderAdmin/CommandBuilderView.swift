import SwiftUI
import DXSpiderCore

/// Command Builder (Konzeptdokument §6, M3): Eingabemasken für Registrierung, read-only-
/// Abfragen und freie Eingabe — jeweils mit Dry-Run-Preview (§2) des exakt erzeugten Befehls
/// und Bestätigung für destruktive Aktionen. Ergebnisse erscheinen in der geteilten Konsole.
struct CommandBuilderView: View {
    @Bindable var model: ConnectionViewModel
    @State private var registerCalls = ""
    @State private var registeredFilter = ""
    @State private var badSpotterCalls = ""
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

            Section("Bad Spotter") {
                TextField("Rufzeichen (mehrere mit Leerzeichen)", text: $badSpotterCalls)
                    .textFieldStyle(.roundedBorder)
                PreviewLine(command: badSpotterList.isEmpty ? nil : .setBadSpotter(callsigns: badSpotterList))
                HStack {
                    Button("Sperren", role: .destructive) { pending = .setBadSpotter(callsigns: badSpotterList) }
                        .disabled(!model.allowWrites || !badSpotterCallsValid)
                    Button("Freigeben") { pending = .unsetBadSpotter(callsigns: badSpotterList) }
                        .disabled(!model.allowWrites || !badSpotterCallsValid)
                }
                // show/badspotter ist read-only und ignoriert Argumente (listet immer alle).
                Button("Bad Spotter anzeigen") {
                    Task { await model.send(.showBadSpotter) }
                }
            }

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

    /// Normalised, non-empty callsigns parsed from a space-separated field.
    private var registerList: [String] { Self.callList(registerCalls) }
    private var badSpotterList: [String] { Self.callList(badSpotterCalls) }
    /// At least one token and every token looks like a callsign.
    private var registerCallsValid: Bool { Self.allValidCallsigns(registerCalls) }
    private var badSpotterCallsValid: Bool { Self.allValidCallsigns(badSpotterCalls) }

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

/// Dry-run preview of the exact line a control will send (Konzeptdokument §2).
private struct PreviewLine: View {
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
