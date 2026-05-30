import SwiftUI
import DXSpiderCore

/// Command Builder (Konzeptdokument §6, M3): Eingabemasken für Registrierung, read-only-
/// Abfragen und freie Eingabe — jeweils mit Dry-Run-Preview (§2) des exakt erzeugten Befehls
/// und Bestätigung für destruktive Aktionen. Ergebnisse erscheinen in der geteilten Konsole.
struct CommandBuilderView: View {
    @Bindable var model: ConnectionViewModel
    @State private var registerCall = ""
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
                TextField("Rufzeichen", text: $registerCall)
                    .textFieldStyle(.roundedBorder)
                PreviewLine(command: registerCall.isValidCallsign ? .setRegister(callsign: registerCall) : nil)
                HStack {
                    Button("Registrieren") { pending = .setRegister(callsign: registerCall) }
                        .disabled(!model.allowWrites || !registerCall.isValidCallsign)
                    Button("Aufheben", role: .destructive) { pending = .unsetRegister(callsign: registerCall) }
                        .disabled(!model.allowWrites || !registerCall.isValidCallsign)
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
