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

    /// Real `show/configuration/nodes` format (anonymised): a Node/Callsigns table where each
    /// node's user list wraps onto indented continuation lines.
    func testParsesConfigurationNodesTable() {
        let raw = """
        Node         Callsigns
        DA0BCC-7     9M2PJU-2     K5XYZ
                     CQ0PCR-6     CS0RCL-6
        HB9HJI-2     HB9HJI-2
        HB9ON-8      JA1XYZ-7     9A0XYZ
        """
        let nodes = ShowNodesParser().parse(raw).nodes
        XCTAssertEqual(nodes.map(\.callsign), ["DA0BCC-7", "HB9HJI-2", "HB9ON-8"],
                       "only first column = nodes; indented continuation lines skipped")
        XCTAssertTrue(nodes.allSatisfy(\.isConnected))
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
