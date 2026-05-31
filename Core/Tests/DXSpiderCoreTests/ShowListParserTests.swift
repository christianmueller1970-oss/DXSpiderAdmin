import XCTest
@testable import DXSpiderCore

final class ShowListParserTests: XCTestCase {
    func testParsesLockoutCallsignsAndDropsCount() {
        // Shape from `show/lockout ALL` (columns + trailing count).
        let raw = """
        JA1XYZ-7     9A0XYZ       K5XYZ
        GB7ABC       VE7XYZ-1
        441 records
        """
        let entries = ShowListParser().parse(raw)
        XCTAssertEqual(entries, ["JA1XYZ-7", "9A0XYZ", "K5XYZ", "GB7ABC", "VE7XYZ-1"])
    }

    func testParsesBadWordsHeaderAndCount() {
        let entries = ShowListParser().parse("Words:\nSPAM   JUNK\n2 BadWords")
        XCTAssertEqual(entries, ["SPAM", "JUNK"])
    }

    func testEmptyListYieldsNothing() {
        XCTAssertTrue(ShowListParser().parse("Words:\n0 BadWords").isEmpty)
        XCTAssertTrue(ShowListParser().parse("").isEmpty)
    }

    func testUppercasesAndDeduplicates() {
        XCTAssertEqual(ShowListParser().parse("hb9a  HB9A  gb7dxc"), ["HB9A", "GB7DXC"])
    }
}
