import XCTest
@testable import DXSpiderCore

final class ShowNodesParserTests: XCTestCase {
    func testExtractsNodesAndDedupes() {
        let raw = """
        Nodes on HB9HJI-2:
        GB7DXC    connected    DXSpider v1.57
        W1NODE    disconnected
        DK0WCY    online
        GB7DXC    connected
        (noise line without a callsign)
        """
        let result = ShowNodesParser().parse(raw)
        let calls = result.nodes.map(\.callsign)

        XCTAssertEqual(calls, ["GB7DXC", "W1NODE", "DK0WCY"], "first callsign per line, de-duplicated")
        XCTAssertTrue(result.nodes.first(where: { $0.callsign == "GB7DXC" })?.isConnected == true)
        XCTAssertTrue(result.nodes.first(where: { $0.callsign == "W1NODE" })?.isConnected == false)
        XCTAssertTrue(result.nodes.first(where: { $0.callsign == "DK0WCY" })?.isConnected == true)
        XCTAssertEqual(result.rawText, raw)
    }
}

final class RateLimiterTests: XCTestCase {
    func testAllowsFirstThenBlocksWithinInterval() {
        var limiter = RateLimiter(minimumInterval: 1.0)
        let t0 = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(limiter.allows(at: t0))
        XCTAssertFalse(limiter.allows(at: t0.addingTimeInterval(0.5)))
        XCTAssertTrue(limiter.allows(at: t0.addingTimeInterval(1.0)))
    }

    func testRetryDelayCountsDown() {
        var limiter = RateLimiter(minimumInterval: 2.0)
        let t0 = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(limiter.retryDelay(at: t0), 0, accuracy: 0.0001)
        limiter.record(at: t0)
        XCTAssertEqual(limiter.retryDelay(at: t0.addingTimeInterval(0.5)), 1.5, accuracy: 0.0001)
        XCTAssertEqual(limiter.retryDelay(at: t0.addingTimeInterval(2.5)), 0, accuracy: 0.0001)
    }
}
