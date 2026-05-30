import Foundation

/// A fully in-memory ``SysopChannel`` for tests and SwiftUI previews.
///
/// It mimics the real connection lifecycle, enforces ``ChannelMode`` and records every
/// attempt to an ``AuditSink`` — but answers from a caller-supplied responder instead of a
/// live node, so the connection logic stays testable without a running server.
public actor InMemorySysopChannel: SysopChannel {
    public private(set) var state: ConnectionState = .disconnected

    private let mode: ChannelMode
    private let audit: AuditSink?
    private let now: @Sendable () -> Date
    private let responder: @Sendable (DXCommand) -> String

    public init(
        mode: ChannelMode = .readOnly,
        audit: AuditSink? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        responder: @escaping @Sendable (DXCommand) -> String = { $0.line }
    ) {
        self.mode = mode
        self.audit = audit
        self.now = now
        self.responder = responder
    }

    public func connect() async throws {
        state = .connecting
        state = .authenticating
        state = .ready
    }

    public func send(_ command: DXCommand) async throws -> String {
        guard state.canSendCommands else {
            await record(command, .failed("not connected"))
            throw SysopChannelError.notConnected
        }
        do {
            try mode.authorize(command)
        } catch {
            await record(command, .blockedReadOnly)
            throw error
        }

        state = .busy
        defer { state = .ready }
        let response = responder(command)
        await record(command, .sent)
        return response
    }

    public func disconnect() async {
        state = .disconnected
    }

    private func record(_ command: DXCommand, _ outcome: AuditEntry.Outcome) async {
        guard let audit else { return }
        await audit.record(AuditEntry(
            timestamp: now(),
            line: command.line,
            destructive: command.isDestructive,
            outcome: outcome
        ))
    }
}
