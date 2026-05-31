import XCTest
@testable import DXSpiderCore

final class ShowRegisteredParserTests: XCTestCase {
    // Real shape captured from HB9HJI-2 (anonymised count).
    let sample = """
    Registration is Required
    HB9AF(1)       HB9TAA(1)      HB9TAB(1)      HB9TAC(1)      HB9TAD(1)
    HB9TAE(1)      HB9TAF(1)
    7 records
    """

    func testExtractsRegisteredCallsigns() {
        let result = ShowRegisteredParser().parse(sample)
        XCTAssertEqual(
            result.users.map(\.callsign),
            ["HB9AF", "HB9TAA", "HB9TAB", "HB9TAC", "HB9TAD", "HB9TAE", "HB9TAF"]
        )
        XCTAssertTrue(result.users.allSatisfy(\.isRegistered))
        XCTAssertEqual(result.registrationRequired, true)
    }

    func testReadsNotRequiredAndEmptyList() {
        let result = ShowRegisteredParser().parse("Registration is NOT Required\n0 records")
        XCTAssertTrue(result.users.isEmpty)
        XCTAssertEqual(result.registrationRequired, false)
    }

    func testDeduplicatesAndKeepsRawText() {
        let result = ShowRegisteredParser().parse("HB9AF(1)  HB9AF(1)\n1 records")
        XCTAssertEqual(result.users.map(\.callsign), ["HB9AF"])
        XCTAssertEqual(result.rawText, "HB9AF(1)  HB9AF(1)\n1 records")
    }
}
