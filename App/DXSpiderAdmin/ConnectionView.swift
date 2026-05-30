import SwiftUI
import DXSpiderCore

/// The connection control panel (Konzeptdokument §6 → "Verbindung"): backend & node
/// settings, the read-only switch, connect/disconnect, a console and the audit log.
struct ConnectionView: View {
    @Bindable var model: ConnectionViewModel

    var body: some View {
        HSplitView {
            controlPanel
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
            consolePanel
                .frame(minWidth: 380)
        }
        .navigationTitle("Verbindung")
        .toolbar {
            ToolbarItem(placement: .status) {
                StatusBadge(state: model.state)
            }
        }
    }

    // MARK: Controls

    private var controlPanel: some View {
        Form {
            Section("Backend") {
                Picker("Quelle", selection: $model.useDemoBackend) {
                    Text("Demo (ohne Server)").tag(true)
                    Text("SSH + console.pl").tag(false)
                }
                .pickerStyle(.radioGroup)
                .disabled(model.isConnected)
            }

            if !model.useDemoBackend {
                Section("Node (nicht-geheim)") {
                    TextField("Host", text: $model.config.host)
                    TextField("SSH-User", text: $model.config.user)
                    TextField("Port", value: $model.config.port, format: .number.grouping(.never))
                    TextField("console.pl-Pfad", text: $model.config.consolePath)
                }
                .disabled(model.isConnected)
                .textFieldStyle(.roundedBorder)
            }

            Section("Sicherheit") {
                Toggle("Schreibende Befehle erlauben", isOn: $model.allowWrites)
                    .disabled(model.isConnected)
                Text(model.allowWrites
                     ? "Destruktive Befehle sind freigeschaltet — mit Bedacht einsetzen."
                     : "Read-only: destruktive Befehle werden blockiert.")
                    .font(.caption)
                    .foregroundStyle(model.allowWrites ? .orange : .secondary)
            }

            Section {
                HStack {
                    if model.isConnected {
                        Button("Trennen", role: .destructive) {
                            Task { await model.disconnect() }
                        }
                    } else {
                        Button("Verbinden") {
                            Task { await model.connect() }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.isBusy || (!model.useDemoBackend && !model.configValid))
                    }
                    if model.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }
                if let error = model.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Console

    private var consolePanel: some View {
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

            HStack {
                Button("show/users") { Task { await model.send(.showUsers) } }
                Button("show/nodes") { Task { await model.send(.showNodes) } }
                Button("show/configuration") { Task { await model.send(.showConfiguration) } }
            }
            .controlSize(.small)
            .disabled(!model.isConnected)

            HStack {
                TextField("Befehl eingeben …", text: $model.commandText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.sendTypedCommand() } }
                Button("Senden") { Task { await model.sendTypedCommand() } }
                    .disabled(model.commandText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .disabled(!model.isConnected)

            DisclosureGroup("Audit-Log (\(model.auditEntries.count))") {
                AuditLogView(entries: model.auditEntries)
            }
        }
        .padding()
    }
}

/// Coloured connection-state indicator for the toolbar.
struct StatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label).font(.callout.weight(.medium))
        }
    }

    private var color: Color {
        switch state {
        case .ready, .busy: .green
        case .connecting, .authenticating: .orange
        case .failed: .red
        case .disconnected: .secondary
        }
    }

    private var label: String {
        switch state {
        case .disconnected: "Getrennt"
        case .connecting: "Verbinde …"
        case .authenticating: "Anmeldung …"
        case .ready: "Bereit"
        case .busy: "Beschäftigt …"
        case .failed(let reason): "Fehler: \(reason)"
        }
    }
}

/// Compact, monospaced rendering of the command audit trail.
struct AuditLogView: View {
    let entries: [AuditEntry]

    var body: some View {
        if entries.isEmpty {
            Text("Noch keine Befehle protokolliert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    Text(entry.logLine())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(entry.outcome == .sent ? Color.primary : Color.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    ConnectionView(model: ConnectionViewModel())
        .frame(width: 860, height: 560)
}
