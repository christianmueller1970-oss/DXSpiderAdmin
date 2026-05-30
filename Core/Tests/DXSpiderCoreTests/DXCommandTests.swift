import XCTest
@testable import DXSpiderCore

final class DXCommandTests: XCTestCase {
    func testReadOnlyCommandLines() {
        XCTAssertEqual(DXCommand.showUsers.line, "show/users")
        XCTAssertEqual(DXCommand.showNodes.line, "show/nodes")
        XCTAssertEqual(DXCommand.showConfiguration.line, "show/configuration")
        XCTAssertEqual(DXCommand.showRoute(callsign: "hb9hji").line, "show/route HB9HJI")
    }

    func testAdminCommandLines() {
        XCTAssertEqual(
            DXCommand.setPrivilege(level: .sysop, callsign: " dl1abc ").line,
            "set/priv 9 DL1ABC"
        )
        XCTAssertEqual(DXCommand.boot(callsign: "w1aw").line, "boot W1AW")
        XCTAssertEqual(DXCommand.clearSpots(slot: 0).line, "clear/spots 0")
    }

    func testRegistrationLines() {
        XCTAssertEqual(DXCommand.setRegister(callsign: "hb9xyz").line, "set/register HB9XYZ")
        XCTAssertEqual(DXCommand.unsetRegister(callsign: " dl1abc ").line, "unset/register DL1ABC")
        XCTAssertTrue(DXCommand.setRegister(callsign: "HB9XYZ").isDestructive)
        XCTAssertTrue(DXCommand.unsetRegister(callsign: "HB9XYZ").isDestructive)
    }

    func testQueryLines() {
        XCTAssertEqual(DXCommand.showConfiguration.line, "show/configuration")
        XCTAssertEqual(DXCommand.showRoute(callsign: "w1aw").line, "show/route W1AW")
        XCTAssertTrue(DXCommand.showConfiguration.isReadOnly)
        XCTAssertTrue(DXCommand.showRoute(callsign: "W1AW").isReadOnly)
    }

    func testDestructiveFlags() {
        XCTAssertFalse(DXCommand.showUsers.isDestructive)
        XCTAssertTrue(DXCommand.showUsers.isReadOnly)
        XCTAssertTrue(DXCommand.boot(callsign: "W1AW").isDestructive)
        // Free-form commands are treated conservatively.
        XCTAssertTrue(DXCommand.raw("anything").isDestructive)
    }
}
