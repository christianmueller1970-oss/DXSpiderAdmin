import XCTest
@testable import DXSpiderCore

final class NodeStatusParserTests: XCTestCase {
    // Wortgetreue Antworten von HB9HJI-2 (DXSpider v1.55 build 823, 13-Aug-2026).
    private let cluster = "Nodes: 3/400 Users [Loc/Clr]: 4/5154 Max: 8/5768 - Uptime:  8d 22h 19m"
    private let version = """
    DXSpider v1.55 (build 823 git: mojo/3e9b3621[r]) using perl v5.36.0 on Linux
    Copyright (c) 1998-2026 Dirk Koopman G1TLH
    """
    private let time = """
    Local Time: 13-Aug-2026 1658, UTC 1658Z
    HB        Switzerland-HB       Local (standard) time: 1758 (+1.0 Hours)
    """

    func testParsesClusterLine() {
        let status = NodeStatusParser().parse(cluster: cluster)
        XCTAssertEqual(status.nodesConnected, 3)
        XCTAssertEqual(status.nodesMax, 400)
        XCTAssertEqual(status.usersLocal, 4)
        XCTAssertEqual(status.usersCluster, 5154)
        XCTAssertEqual(status.peakUsersLocal, 8)
        XCTAssertEqual(status.peakUsersCluster, 5768)
        XCTAssertEqual(status.uptime, "8d 22h 19m")
    }

    func testParsesVersionAndTime() {
        let status = NodeStatusParser().parse(version: version, time: time)
        XCTAssertEqual(status.version, "1.55")
        XCTAssertEqual(status.build, "823")
        XCTAssertEqual(status.perlVersion, "5.36.0")
        XCTAssertEqual(status.localTime, "13-Aug-2026 1658")
        XCTAssertEqual(status.utcTime, "1658Z")
    }

    func testSummariesAreFormattedForTiles() {
        let status = NodeStatusParser().parse(cluster: cluster, version: version)
        XCTAssertEqual(status.versionSummary, "v1.55 (build 823)")
        XCTAssertEqual(status.usersSummary, "4 lokal / 5154 im Netz")
        XCTAssertEqual(status.nodesSummary, "3 von 400")
    }

    func testUnknownWordingLosesOnlyTheAffectedField() {
        // Eine Antwort ohne "Max:" darf die übrigen Werte nicht mitreissen.
        let status = NodeStatusParser().parse(cluster: "Nodes: 2/400 Users [Loc/Clr]: 1/900 - Uptime: 3h 5m")
        XCTAssertEqual(status.nodesConnected, 2)
        XCTAssertEqual(status.usersCluster, 900)
        XCTAssertEqual(status.uptime, "3h 5m")
        XCTAssertNil(status.peakUsersLocal)
    }

    func testEmptyInputYieldsEmptyStatus() {
        XCTAssertTrue(NodeStatusParser().parse().isEmpty)
    }
}
