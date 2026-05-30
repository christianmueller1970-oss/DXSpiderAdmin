import Foundation
import Observation
import DXSpiderCore

/// Drives the connection screen (MVVM). Wraps a `SysopChannel` and exposes UI-friendly,
/// observable state. Defaults to the in-memory demo backend so the app is fully usable
/// without a live node; switch to the SSH backend to talk to the real cluster.
@MainActor
@Observable
final class ConnectionViewModel {
    // MARK: Backend selection
    var useDemoBackend = true
    var config = SSHConnectionConfig(host: "", user: "", port: 22, consolePath: "/spider/perl/console.pl")

    // MARK: Safety (Konzeptdokument §2 — read-only default)
    var allowWrites = false
    var mode: ChannelMode { allowWrites ? .readWrite : .readOnly }

    // MARK: Live state
    private(set) var state: ConnectionState = .disconnected
    private(set) var auditEntries: [AuditEntry] = []
    private(set) var consoleLog: String = ""
    private(set) var lastError: String?
    private(set) var settingsMessage: String?
    var commandText: String = ""

    private var channel: (any SysopChannel)?
    private let audit = InMemoryAuditLog()
    private let settingsStore: SettingsStore
    private let auditSink: any AuditSink

    init(settingsStore: SettingsStore = .standard()) {
        self.settingsStore = settingsStore
        let fileAudit = FileAuditLog(fileURL: settingsStore.directory.appendingPathComponent("audit.log"))
        self.auditSink = CompositeAuditSink([audit, fileAudit])

        // Restore non-secret connection settings if present (keys stay with the system).
        if let saved = try? settingsStore.load().connection {
            self.config = saved
            self.useDemoBackend = false
        }
    }

    var isBusy: Bool {
        switch state {
        case .connecting, .authenticating, .busy: true
        default: false
        }
    }
    var isConnected: Bool { state.canSendCommands }
    var configValid: Bool {
        !config.host.isEmpty && !config.user.isEmpty && !config.consolePath.isEmpty && config.port > 0
    }

    // MARK: Actions

    func connect() async {
        guard !isConnected else { return }
        lastError = nil
        state = .connecting

        let channel: any SysopChannel = useDemoBackend
            ? InMemorySysopChannel(mode: mode, audit: auditSink, responder: { Self.demoResponder($0) })
            : ProcessSysopChannel(config: config, mode: mode, audit: auditSink)
        self.channel = channel

        do {
            try await channel.connect()
            append("✅ Verbunden via \(useDemoBackend ? "Demo" : "SSH") — Modus: \(modeLabel).")
            if !useDemoBackend { saveSettings() }
        } catch {
            lastError = describe(error)
            append("⛔️ Verbindung fehlgeschlagen: \(describe(error))")
            self.channel = nil
        }
        await syncState()
    }

    func disconnect() async {
        await channel?.disconnect()
        channel = nil
        state = .disconnected
        append("Verbindung getrennt.")
    }

    func send(_ command: DXCommand) async {
        guard let channel else { return }
        lastError = nil
        append("> \(command.line)")
        do {
            let response = try await channel.send(command)
            if !response.isEmpty { append(response) }
        } catch SysopChannelError.readOnly {
            lastError = "Im Read-only-Modus blockiert: \(command.line)"
            append("🔒 blockiert (read-only): \(command.line)")
        } catch {
            lastError = describe(error)
            append("⛔️ Fehler: \(describe(error))")
        }
        await syncState()
    }

    func sendTypedCommand() async {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        commandText = ""
        await send(.raw(text))
    }

    func clearConsole() {
        consoleLog = ""
    }

    /// Persist the current (non-secret) connection settings to the Documents folder.
    func saveSettings() {
        do {
            try settingsStore.save(AppSettings(connection: config))
            settingsMessage = "Gesichert in \(settingsStore.fileURL.path)"
        } catch {
            settingsMessage = "Sichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: Helpers

    private var modeLabel: String { allowWrites ? "Schreiben erlaubt" : "Read-only" }

    private func syncState() async {
        if let channel {
            state = await channel.state
        } else {
            state = .disconnected
        }
        auditEntries = await audit.entries
    }

    private func append(_ line: String) {
        consoleLog += (consoleLog.isEmpty ? "" : "\n") + line
    }

    private func describe(_ error: Error) -> String {
        switch error {
        case SysopChannelError.notConnected: "nicht verbunden"
        case SysopChannelError.timedOut: "Zeitüberschreitung"
        case SysopChannelError.readOnly: "read-only"
        case SysopChannelError.connectionFailed(let reason): reason
        default: "\(error)"
        }
    }

    /// Canned responses for the demo backend, so the UI is explorable without a server.
    nonisolated static func demoResponder(_ command: DXCommand) -> String {
        switch command {
        case .showUsers:
            return "DL1ABC   W1AW    HB9XYZ   G3PLX   OE1ABC"
        case .showNodes:
            return "HB9HJI-2   GB7DXC   W1NODE   DK0WCY"
        case .showConfiguration:
            return "DXSpider V1.57 build 0.x — demo node HB9HJI-2"
        default:
            return "(Demo) ausgeführt: \(command.line)"
        }
    }
}
