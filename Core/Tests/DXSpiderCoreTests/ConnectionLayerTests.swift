import XCTest
@testable import DXSpiderCore

final class PromptDetectorTests: XCTestCase {
    let detector = PromptDetector()

    func testRecognisesPromptLine() {
        XCTAssertTrue(detector.isPromptLine("HB9HJI de HB9HJI-2 30-May-2026 2105Z >"))
        XCTAssertTrue(detector.isPromptLine("HB9HJI de HB9HJI-2 >   "))   // trailing spaces ignored
    }

    func testRejectsNonPromptLines() {
        XCTAssertFalse(detector.isPromptLine("show/users"))
        XCTAssertFalse(detector.isPromptLine("DL1ABC   GB7 connected"))   // no trailing '>'
        XCTAssertFalse(detector.isPromptLine("some > text but no signature"))
    }

    func testEndsAtPrompt() {
        let buffer = """
        show/users
        DL1ABC W1AW HB9XYZ
        HB9HJI de HB9HJI-2 30-May-2026 2105Z >
        """
        XCTAssertTrue(detector.endsAtPrompt(buffer))
        XCTAssertFalse(detector.endsAtPrompt("show/users\nstill streaming output"))
    }
}

final class ResponseAccumulatorTests: XCTestCase {
    func testHoldsUntilPromptThenReturnsStrippedResponse() {
        var acc = ResponseAccumulator()
        acc.append("show/users\n")
        acc.append("DL1ABC W1AW\n")
        XCTAssertNil(acc.takeCompletedResponse(), "no prompt yet → incomplete")

        acc.append("HB9HJI de HB9HJI-2 2105Z >\n")
        let response = acc.takeCompletedResponse()
        XCTAssertEqual(response, "show/users\nDL1ABC W1AW")
        XCTAssertEqual(acc.pending, "", "buffer cleared after a completed response")
    }

    func testStaysEmptyAfterConsumingResponse() {
        var acc = ResponseAccumulator()
        acc.append("ok\nHB9HJI de HB9HJI-2 >\n")
        XCTAssertNotNil(acc.takeCompletedResponse())
        XCTAssertNil(acc.takeCompletedResponse())
    }
}

final class ChannelModeTests: XCTestCase {
    func testReadOnlyAllowsQueriesBlocksMutations() {
        let mode = ChannelMode.readOnly
        XCTAssertNoThrow(try mode.authorize(.showUsers))
        XCTAssertThrowsError(try mode.authorize(.boot(callsign: "W1AW"))) { error in
            XCTAssertEqual(error as? SysopChannelError, .readOnly)
        }
    }

    func testReadWriteAllowsMutations() {
        XCTAssertTrue(ChannelMode.readWrite.allowsMutations)
        XCTAssertNoThrow(try ChannelMode.readWrite.authorize(.boot(callsign: "W1AW")))
    }
}

final class AuditEntryTests: XCTestCase {
    func testLogLineFormat() {
        let entry = AuditEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            line: "boot W1AW",
            destructive: true,
            outcome: .blockedReadOnly
        )
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(entry.logLine(formatter: formatter), "1970-01-01T00:00:00Z [!] BLOCKED(read-only) boot W1AW")
    }
}
