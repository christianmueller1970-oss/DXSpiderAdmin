import Foundation

/// Appends audit entries to a log file (one ``AuditEntry/logLine(formatter:)`` per line).
///
/// The app points this at `~/Documents/DXSpiderAdmin/audit.log`. The file URL is injectable
/// so tests can use a temporary location.
public actor FileAuditLog: AuditSink {
    private let fileURL: URL
    private let formatter: ISO8601DateFormatter

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        self.formatter = formatter
    }

    public func record(_ entry: AuditEntry) async {
        let line = entry.logLine(formatter: formatter) + "\n"
        guard let data = line.data(using: .utf8) else { return }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: fileURL, options: .atomic)
            return
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}

/// Fans a single audit entry out to several sinks (e.g. an in-memory log for the UI plus a
/// file on disk).
public struct CompositeAuditSink: AuditSink {
    private let sinks: [any AuditSink]

    public init(_ sinks: [any AuditSink]) {
        self.sinks = sinks
    }

    public func record(_ entry: AuditEntry) async {
        for sink in sinks {
            await sink.record(entry)
        }
    }
}
