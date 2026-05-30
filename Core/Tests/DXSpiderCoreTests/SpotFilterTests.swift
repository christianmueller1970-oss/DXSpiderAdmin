import XCTest
@testable import DXSpiderCore

final class SpotFilterTests: XCTestCase {
    func testEmptyFilterHasNoRuleOrCommand() {
        let filter = SpotFilter()
        XCTAssertNil(filter.rule)
        XCTAssertNil(filter.command)
    }

    func testSingleBand() {
        let filter = SpotFilter(action: .accept, slot: 0, bands: [.hf])
        XCTAssertEqual(filter.rule, "on hf")
        XCTAssertEqual(filter.command?.line, "accept/spots 0 on hf")
    }

    func testMultipleBandsAreOred() {
        let filter = SpotFilter(bands: [.hf, .vhf])
        XCTAssertEqual(filter.rule, "(on hf or on vhf)")
    }

    func testCombinedClausesAreAnded() {
        let filter = SpotFilter(
            action: .reject,
            slot: 2,
            bands: [.hf, .vhf],
            spotterCalls: ["W1AW", "K1ABC"],
            originCalls: ["GB7DXC"]
        )
        XCTAssertEqual(filter.rule, "(on hf or on vhf) and by W1AW,K1ABC and origin GB7DXC")
        XCTAssertEqual(filter.command?.line, "reject/spots 2 (on hf or on vhf) and by W1AW,K1ABC and origin GB7DXC")
    }

    func testClearCommandIgnoresRule() {
        let filter = SpotFilter(slot: 3, bands: [.hf])
        XCTAssertEqual(filter.clearCommand.line, "clear/spots 3")
    }

    func testTokenParsing() {
        XCTAssertEqual(SpotFilter.tokens(from: "w1aw, k1abc  dl1abc"), ["W1AW", "K1ABC", "DL1ABC"])
        XCTAssertEqual(SpotFilter.tokens(from: "   "), [])
    }
}
