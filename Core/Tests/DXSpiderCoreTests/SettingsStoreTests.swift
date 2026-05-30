import XCTest
@testable import DXSpiderCore

final class SettingsStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dxsa-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadReturnsEmptyWhenMissing() throws {
        let store = SettingsStore(directory: tempDir)
        XCTAssertEqual(try store.load(), AppSettings())
    }

    func testSaveThenLoadRoundTrip() throws {
        let store = SettingsStore(directory: tempDir)
        let settings = AppSettings(connection: SSHConnectionConfig(
            host: "node.example.org", user: "spider", port: 22,
            consolePath: "/spider/perl/console.pl", sysopCall: "HB9HJI"
        ))
        try store.save(settings)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(try store.load(), settings)
    }

    func testStandardStoreLivesInDocumentsDXSpiderAdmin() {
        let store = SettingsStore.standard()
        XCTAssertEqual(store.directory.lastPathComponent, "DXSpiderAdmin")
        XCTAssertEqual(store.fileURL.lastPathComponent, "settings.json")
    }
}

final class FileAuditLogTests: XCTestCase {
    func testAppendsOneLinePerEntry() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dxsa-audit-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let log = FileAuditLog(fileURL: fileURL)
        await log.record(AuditEntry(timestamp: Date(timeIntervalSince1970: 0),
                                    line: "show/users", destructive: false, outcome: .sent))
        await log.record(AuditEntry(timestamp: Date(timeIntervalSince1970: 0),
                                    line: "boot W1AW", destructive: true, outcome: .blockedReadOnly))

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("SENT show/users"))
        XCTAssertTrue(lines[1].contains("BLOCKED(read-only) boot W1AW"))
    }
}

final class CompositeAuditSinkTests: XCTestCase {
    func testFansOutToAllSinks() async {
        let a = InMemoryAuditLog()
        let b = InMemoryAuditLog()
        let composite = CompositeAuditSink([a, b])
        let entry = AuditEntry(timestamp: Date(timeIntervalSince1970: 0),
                               line: "show/nodes", destructive: false, outcome: .sent)
        await composite.record(entry)

        let entriesA = await a.entries
        let entriesB = await b.entries
        XCTAssertEqual(entriesA, [entry])
        XCTAssertEqual(entriesB, [entry])
    }
}
