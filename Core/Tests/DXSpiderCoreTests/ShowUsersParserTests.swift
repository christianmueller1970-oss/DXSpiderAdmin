import XCTest
@testable import DXSpiderCore

final class ShowUsersParserTests: XCTestCase {
    func testExtractsAndDedupesCallsigns() {
        let raw = """
        Users on HB9HJI-2:
        HB9HJI   W1AW   DL1ABC
        HB9HJI   G4XYZ-2
        (heading and noise lines are ignored)
        """
        let result = ShowUsersParser().parse(raw)
        let calls = Set(result.users.map(\.callsign))

        XCTAssertTrue(calls.contains("HB9HJI"))
        XCTAssertTrue(calls.contains("W1AW"))
        XCTAssertTrue(calls.contains("DL1ABC"))
        XCTAssertTrue(calls.contains("G4XYZ-2"))
        // De-duplicated despite appearing twice.
        XCTAssertEqual(result.users.filter { $0.callsign == "HB9HJI" }.count, 1)
        // Raw text is preserved for fallback.
        XCTAssertEqual(result.rawText, raw)
    }

    func testSkipsConsoleHeader() {
        // Real console `show/users`: header line + one callsign per line.
        let raw = """
        Callsigns connected to HB9HJI-2
        HB9HJI
        DL1ABC
        """
        let calls = ShowUsersParser().parse(raw).users.map(\.callsign)
        XCTAssertEqual(calls, ["HB9HJI", "DL1ABC"])
        XCTAssertFalse(calls.contains("HB9HJI-2"), "the node call in the header must not be a user")
    }

    func testCallsignHeuristic() {
        XCTAssertTrue(ShowUsersParser.isLikelyCallsign("HB9HJI"))
        XCTAssertTrue(ShowUsersParser.isLikelyCallsign("W1AW"))
        XCTAssertTrue(ShowUsersParser.isLikelyCallsign("HB9HJI-2"))
        XCTAssertFalse(ShowUsersParser.isLikelyCallsign("USERS"))   // no digit
        XCTAssertFalse(ShowUsersParser.isLikelyCallsign("12345"))   // no letter
        XCTAssertFalse(ShowUsersParser.isLikelyCallsign("ON"))      // too short
    }
}
