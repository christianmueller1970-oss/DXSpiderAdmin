import Foundation

/// The app's persisted, **non-secret** settings.
///
/// Per Konzeptdokument §2 only non-secret values live here (host, user, port, console.pl
/// path, sysop call). Keys and passwords are never stored — SSH auth stays with the system.
/// Wrapped in a struct so further non-secret preferences can be added without breaking the
/// on-disk format.
public struct AppSettings: Codable, Sendable, Equatable {
    public var connection: SSHConnectionConfig?

    public init(connection: SSHConnectionConfig? = nil) {
        self.connection = connection
    }
}

/// Reads and writes ``AppSettings`` as JSON in a directory the caller chooses.
///
/// The app uses ``standard(fileManager:)`` → `~/Documents/DXSpiderAdmin/settings.json`, which
/// is readable by the user and never part of the app bundle or the repository. The directory
/// is injectable so tests can use a temporary location.
public struct SettingsStore: Sendable {
    public let directory: URL
    public let fileName: String

    public var fileURL: URL { directory.appendingPathComponent(fileName) }

    public init(directory: URL, fileName: String = "settings.json") {
        self.directory = directory
        self.fileName = fileName
    }

    /// Store at `~/Documents/DXSpiderAdmin/`.
    public static func standard(fileManager: FileManager = .default) -> SettingsStore {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return SettingsStore(directory: documents.appendingPathComponent("DXSpiderAdmin", isDirectory: true))
    }

    /// Load settings, returning empty defaults if the file does not exist yet.
    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AppSettings()
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    /// Persist settings, creating the directory if needed. Written atomically.
    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
