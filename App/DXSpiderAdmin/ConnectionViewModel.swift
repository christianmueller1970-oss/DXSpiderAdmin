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

    // MARK: User & Node management (M2)
    private(set) var users: [ClusterUser] = []
    private(set) var nodes: [ClusterNode] = []
    private(set) var registered: [ClusterUser] = []
    private(set) var registrationRequired: Bool?
    private(set) var blockEntries: [String] = []
    private(set) var isRefreshing = false
    var userSearch = ""
    var nodeSearch = ""
    var registeredSearch = ""
    var blockSearch = ""

    private var channel: (any SysopChannel)?
    private let audit = InMemoryAuditLog()
    private let settingsStore: SettingsStore
    private let auditSink: any AuditSink
    private var rateLimiter = RateLimiter(minimumInterval: 0.75)

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
        !config.host.isEmpty && !config.user.isEmpty && config.port > 0
            && !(config.sysopCall ?? "").isEmpty
    }

    var filteredUsers: [ClusterUser] {
        let query = userSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return users }
        return users.filter { $0.callsign.localizedCaseInsensitiveContains(query) }
    }
    var filteredNodes: [ClusterNode] {
        let query = nodeSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return nodes }
        return nodes.filter { $0.callsign.localizedCaseInsensitiveContains(query) }
    }
    /// Client-side filter over the registered users (the node has no wildcard filter).
    var filteredRegistered: [ClusterUser] {
        let query = registeredSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return registered }
        return registered.filter { $0.callsign.localizedCaseInsensitiveContains(query) }
    }
    /// Client-side filter over the currently loaded block list (bad spotter/node/dx/word, lockout).
    var filteredBlockEntries: [String] {
        let query = blockSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return blockEntries }
        return blockEntries.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    // MARK: Actions

    func connect() async {
        guard !isConnected else { return }
        lastError = nil
        state = .connecting

        let channel: any SysopChannel = useDemoBackend
            ? InMemorySysopChannel(mode: mode, audit: auditSink, responder: { Self.demoResponder($0) })
            : ConsoleSocketChannel(config: config, mode: mode, audit: auditSink)
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
        users = []
        nodes = []
        registered = []
        registrationRequired = nil
        blockEntries = []
        append("Verbindung getrennt.")
    }

    func send(_ command: DXCommand) async {
        guard channel != nil else { return }
        lastError = nil
        append("> \(command.line)")
        do {
            let response = try await dispatch(command)
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

    // MARK: User & Node management

    func refreshAll() async {
        await refreshUsers()
        await refreshNodes()
        await refreshRegistered()
    }

    func refreshRegistered() async {
        guard isConnected else { return }
        isRefreshing = true
        do {
            let raw = try await dispatch(.showRegistered(call: nil))
            let result = ShowRegisteredParser().parse(raw)
            registered = result.users
            registrationRequired = result.registrationRequired
        } catch {
            lastError = describe(error)
        }
        isRefreshing = false
        await syncState()
    }

    /// Destructive: remove a single registration, then refresh the list.
    func unregister(_ callsign: String) async {
        await send(.unsetRegister(callsigns: [callsign]))
        await refreshRegistered()
    }

    /// Load one of the block lists (bad spotter/node/dx/word, lockout) into `blockEntries`.
    func loadBlockList(_ show: DXCommand) async {
        guard isConnected else { return }
        blockEntries = []          // avoid showing the previous list's entries while loading
        isRefreshing = true
        do {
            let raw = try await dispatch(show)
            blockEntries = ShowListParser().parse(raw)
        } catch {
            lastError = describe(error)
        }
        isRefreshing = false
        await syncState()
    }

    /// Destructive: remove one entry from a block list, then reload that list.
    func removeBlockEntry(remove: DXCommand, reload: DXCommand) async {
        await send(remove)
        await loadBlockList(reload)
    }

    func refreshUsers() async {
        guard isConnected else { return }
        isRefreshing = true
        do {
            let raw = try await dispatch(.showUsers)
            users = ShowUsersParser().parse(raw).users
        } catch {
            lastError = describe(error)
        }
        isRefreshing = false
        await syncState()
    }

    func refreshNodes() async {
        guard isConnected else { return }
        isRefreshing = true
        do {
            let raw = try await dispatch(.showNodes)
            nodes = ShowNodesParser().parse(raw).nodes
        } catch {
            lastError = describe(error)
        }
        isRefreshing = false
        await syncState()
    }

    /// Destructive: change a user's privilege level (requires write mode + confirmation in the UI).
    func setPrivilege(_ level: PrivilegeLevel, for callsign: String) async {
        await send(.setPrivilege(level: level, callsign: callsign))
        await refreshUsers()
    }

    /// Destructive: disconnect ("boot") a station.
    func boot(_ callsign: String) async {
        await send(.boot(callsign: callsign))
        await refreshUsers()
    }

    /// Destructive: mark a callsign as a node partner.
    func markAsNode(_ callsign: String) async {
        await send(.setNode(callsign: callsign))
        await refreshNodes()
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

    /// Single send path: paces commands via the rate limiter (Konzeptdokument §2), then
    /// forwards to the channel. Returns the node's response.
    private func dispatch(_ command: DXCommand) async throws -> String {
        guard let channel else { throw SysopChannelError.notConnected }
        let delay = rateLimiter.retryDelay(at: Date())
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
        rateLimiter.record(at: Date())
        return try await channel.send(command)
    }

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
            return "DL1ABC   W1AW    HB9XYZ   G3PLX   OE1ABC   DK7ZB   F5XYZ"
        case .showNodes:
            return """
            GB7DXC    connected     DXSpider v1.57
            W1NODE    connected
            DK0WCY    disconnected
            HB9HJI-2  connected
            """
        case .showConfiguration:
            return "DXSpider V1.57 build 0.x — demo node HB9HJI-2"
        case .showRegistered:
            return """
            Registration is Required
            DL1ABC(1)      HB9XYZ(1)      OE1ABC(1)
            3 records
            """
        default:
            return "(Demo) ausgeführt: \(command.line)"
        }
    }
}
