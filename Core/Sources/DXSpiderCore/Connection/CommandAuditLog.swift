import Foundation

/// A single audited command attempt.
///
/// Every line the app would send to the node is recorded — including ones blocked by
/// read-only mode — so there is a complete local trail (Konzeptdokument §2).
public struct AuditEntry: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case sent
        case blockedReadOnly
        case failed(String)
    }

    public let timestamp: Date
    public let line: String
    public let destructive: Bool
    public let outcome: Outcome

    public init(timestamp: Date, line: String, destructive: Bool, outcome: Outcome) {
        self.timestamp = timestamp
        self.line = line
        self.destructive = destructive
        self.outcome = outcome
    }

    /// One-line, file-friendly rendering for the on-disk audit log in the user's Documents
    /// folder. Core only formats the line — it never writes the file itself.
    public func logLine(formatter: ISO8601DateFormatter = ISO8601DateFormatter()) -> String {
        let status: String
        switch outcome {
        case .sent: status = "SENT"
        case .blockedReadOnly: status = "BLOCKED(read-only)"
        case .failed(let reason): status = "FAILED(\(reason))"
        }
        let flag = destructive ? "!" : " "
        return "\(formatter.string(from: timestamp)) [\(flag)] \(status) \(line)"
    }
}

/// Receives audit entries. The app layer provides a sink that appends to a file in the
/// user's Documents folder; tests and previews use ``InMemoryAuditLog``.
public protocol AuditSink: Sendable {
    func record(_ entry: AuditEntry) async
}

/// In-memory ``AuditSink`` for tests and SwiftUI previews.
public actor InMemoryAuditLog: AuditSink {
    public private(set) var entries: [AuditEntry] = []

    public init() {}

    public func record(_ entry: AuditEntry) async {
        entries.append(entry)
    }
}
