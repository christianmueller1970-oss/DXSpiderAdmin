import XCTest
@testable import DXSpiderCore

final class InMemorySysopChannelTests: XCTestCase {
    func testConnectReachesReady() async throws {
        let channel = InMemorySysopChannel()
        var state = await channel.state
        XCTAssertEqual(state, .disconnected)

        try await channel.connect()
        state = await channel.state
        XCTAssertEqual(state, .ready)
    }

    func testSendBeforeConnectThrows() async {
        let channel = InMemorySysopChannel()
        do {
            _ = try await channel.send(.showUsers)
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? SysopChannelError, .notConnected)
        }
    }

    func testReadOnlyChannelBlocksMutationAndAudits() async throws {
        let audit = InMemoryAuditLog()
        let channel = InMemorySysopChannel(
            mode: .readOnly,
            audit: audit,
            now: { Date(timeIntervalSince1970: 0) }
        )
        try await channel.connect()

        // A query goes through and is audited as sent.
        let response = try await channel.send(.showUsers)
        XCTAssertEqual(response, "show/users")

        // A mutation is blocked, but still audited — and leaves the channel usable.
        do {
            _ = try await channel.send(.boot(callsign: "W1AW"))
            XCTFail("expected readOnly")
        } catch {
            XCTAssertEqual(error as? SysopChannelError, .readOnly)
        }
        let state = await channel.state
        XCTAssertEqual(state, .ready)

        let entries = await audit.entries
        XCTAssertEqual(entries.map(\.outcome), [.sent, .blockedReadOnly])
        XCTAssertEqual(entries.map(\.line), ["show/users", "boot W1AW"])
    }

    func testReadWriteChannelSendsMutation() async throws {
        let channel = InMemorySysopChannel(
            mode: .readWrite,
            responder: { "executed: \($0.line)" }
        )
        try await channel.connect()
        let response = try await channel.send(.boot(callsign: "w1aw"))
        XCTAssertEqual(response, "executed: boot W1AW")
    }
}
