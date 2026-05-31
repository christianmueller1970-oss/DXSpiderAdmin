import XCTest
@testable import DXSpiderCore

final class DXCommandTests: XCTestCase {
    func testReadOnlyCommandLines() {
        XCTAssertEqual(DXCommand.showUsers.line, "show/users")
        XCTAssertEqual(DXCommand.showNodes.line, "show/configuration/nodes")
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
        XCTAssertEqual(DXCommand.setRegister(callsigns: ["hb9xyz"]).line, "set/register HB9XYZ")
        XCTAssertEqual(DXCommand.unsetRegister(callsigns: [" dl1abc "]).line, "unset/register DL1ABC")
        XCTAssertTrue(DXCommand.setRegister(callsigns: ["HB9XYZ"]).isDestructive)
        XCTAssertTrue(DXCommand.unsetRegister(callsigns: ["HB9XYZ"]).isDestructive)
    }

    func testRegistrationMultipleCallsigns() {
        XCTAssertEqual(
            DXCommand.setRegister(callsigns: ["hb9a", "HB9B", " dl1abc "]).line,
            "set/register HB9A HB9B DL1ABC"
        )
        // Blank tokens are dropped.
        XCTAssertEqual(DXCommand.setRegister(callsigns: ["hb9a", "  "]).line, "set/register HB9A")
    }

    func testBadSpotterLines() {
        XCTAssertEqual(DXCommand.setBadSpotter(callsigns: ["n0call", "W1AW"]).line, "set/badspotter N0CALL W1AW")
        XCTAssertEqual(DXCommand.unsetBadSpotter(callsigns: ["w1aw"]).line, "unset/badspotter W1AW")
        XCTAssertTrue(DXCommand.setBadSpotter(callsigns: ["W1AW"]).isDestructive)
        XCTAssertTrue(DXCommand.unsetBadSpotter(callsigns: ["W1AW"]).isDestructive)
        // Node ignores any argument and always lists all → no-arg command.
        XCTAssertEqual(DXCommand.showBadSpotter.line, "show/badspotter")
        XCTAssertTrue(DXCommand.showBadSpotter.isReadOnly)
    }

    func testQueryLines() {
        XCTAssertEqual(DXCommand.showConfiguration.line, "show/configuration")
        XCTAssertEqual(DXCommand.showRoute(callsign: "w1aw").line, "show/route W1AW")
        XCTAssertTrue(DXCommand.showConfiguration.isReadOnly)
        XCTAssertTrue(DXCommand.showRoute(callsign: "W1AW").isReadOnly)
    }

    func testShowRegisteredLine() {
        // Note the trailing "ed": listing is "show/registered", while set/unset use "register".
        XCTAssertEqual(DXCommand.showRegistered(call: nil).line, "show/registered")
        XCTAssertEqual(DXCommand.showRegistered(call: "hb9tac").line, "show/registered HB9TAC")
        XCTAssertEqual(DXCommand.showRegistered(call: "  ").line, "show/registered", "blank call is ignored")
        XCTAssertTrue(DXCommand.showRegistered(call: nil).isReadOnly)
        XCTAssertFalse(DXCommand.showRegistered(call: "HB9TAC").isDestructive)
    }

    func testDestructiveFlags() {
        XCTAssertFalse(DXCommand.showUsers.isDestructive)
        XCTAssertTrue(DXCommand.showUsers.isReadOnly)
        XCTAssertTrue(DXCommand.boot(callsign: "W1AW").isDestructive)
        // Free-form commands are treated conservatively.
        XCTAssertTrue(DXCommand.raw("anything").isDestructive)
    }
}
