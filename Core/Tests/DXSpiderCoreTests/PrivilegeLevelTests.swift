import XCTest
@testable import DXSpiderCore

final class PrivilegeLevelTests: XCTestCase {
    func testRejectsOutOfRange() {
        XCTAssertNil(PrivilegeLevel(rawValue: -1))
        XCTAssertNil(PrivilegeLevel(rawValue: 10))
    }

    func testAcceptsBounds() {
        XCTAssertEqual(PrivilegeLevel(rawValue: 0), .user)
        XCTAssertEqual(PrivilegeLevel(rawValue: 9), .sysop)
    }

    func testComparable() {
        XCTAssertLessThan(PrivilegeLevel.user, .sysop)
        XCTAssertGreaterThan(PrivilegeLevel.sysop, .user)
    }
}
