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
    }

    // MARK: Controls

    private var controlPanel: some View {
        Form {
            Section { header }

            Section("Backend") {
                Picker("Quelle", selection: $model.useDemoBackend) {
                    Text("Demo (ohne Server)").tag(true)
                    Text("SSH (Console-Socket)").tag(false)
                }
                .pickerStyle(.radioGroup)
                .disabled(model.isConnected)
            }

            if !model.useDemoBackend {
                Section {
                    TextField("Host", text: $model.config.host, prompt: Text("dxspider.example.net"))
                    TextField("SSH-User", text: $model.config.user, prompt: Text("root"))
                    TextField("Port", value: $model.config.port, format: .number.grouping(.never))
                    TextField("Sysop-Call", text: Binding(
                        get: { model.config.sysopCall ?? "" },
                        set: { model.config.sysopCall = $0.isEmpty ? nil : $0 }
                    ), prompt: Text("HB9XYZ-2"))
                    HStack {
                        Button("Einstellungen sichern", systemImage: "square.and.arrow.down",
                               action: model.saveSettings)
                            .disabled(!model.configValid)
                        Spacer()
                    }
                    if let message = model.settingsMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Node")
                } footer: {
                    Label("Keine Keys oder Passwörter — die Anmeldung läuft über ssh-agent und ~/.ssh.",
                          systemImage: "key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(model.isConnected)
            }

            Section {
                Toggle(isOn: $model.allowWrites) {
                    Label("Schreibende Befehle erlauben",
                          systemImage: model.allowWrites ? "pencil.circle.fill" : "lock.fill")
                }
                .tint(.orange)
                .disabled(model.isConnected)
            } header: {
                Text("Sicherheit")
            } footer: {
                Text(model.allowWrites
                     ? "Destruktive Befehle sind freigeschaltet — mit Bedacht einsetzen."
                     : "Read-only: destruktive Befehle werden blockiert. Umschalten nur im getrennten Zustand.")
                    .font(.caption)
                    .foregroundStyle(model.allowWrites ? .orange : .secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Kopf mit Node, Status und dem grossen Verbinden-/Trennen-Knopf.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: model.isConnected
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundStyle(isIdle ? Color.secondary : Color.white)
                    .frame(width: 44, height: 44)
                    .background(isIdle ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(model.state.tint.gradient),
                                in: Circle())
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.nodeDisplayName)
                        .font(.title3.weight(.semibold).monospaced())
                        .lineLimit(1)
                    Text(endpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }

            StatusBadge(state: model.state)
                .font(.callout.weight(.medium))

            Group {
                if model.isConnected {
                    Button(role: .destructive) {
                        Task { await model.disconnect() }
                    } label: {
                        Label("Trennen", systemImage: "bolt.horizontal.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task { await model.connect() }
                    } label: {
                        HStack {
                            if model.isBusy { ProgressView().controlSize(.small) }
                            Label("Verbinden", systemImage: "bolt.horizontal.circle.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isBusy || (!model.useDemoBackend && !model.configValid))
                }
            }
            .controlSize(.large)

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(.vertical, 4)
    }

    private var isIdle: Bool {
        if case .disconnected = model.state { true } else { false }
    }

    private var endpoint: String {
        if model.useDemoBackend { return "Demo-Backend · ohne Server" }
        let host = model.config.host.isEmpty ? "—" : model.config.host
        let user = model.config.user.isEmpty ? "" : "\(model.config.user)@"
        return "\(user)\(host):\(model.config.port)"
    }

    // MARK: Console

    private var consolePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ConsolePane(model: model, showsInput: true, showsError: false)

            DisclosureGroup {
                ScrollView {
                    AuditLogView(entries: model.auditEntries)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            } label: {
                Label("Audit-Log (\(model.auditEntries.count))", systemImage: "list.bullet.rectangle")
            }
        }
        .padding()
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
