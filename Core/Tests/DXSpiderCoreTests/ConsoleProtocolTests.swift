import XCTest
@testable import DXSpiderCore

final class ConsoleProtocolTests: XCTestCase {
    func testParsesDisplayLine() {
        let msg = ConsoleProtocol.parse("DHB9HJI|HB9HJI de HB9HJI-2 30-May-2026 2121Z dxspider >")
        XCTAssertEqual(msg?.sort, "D")
        XCTAssertEqual(msg?.call, "HB9HJI")
        XCTAssertEqual(msg?.text, "HB9HJI de HB9HJI-2 30-May-2026 2121Z dxspider >")
        XCTAssertEqual(msg?.isDisplay, true)
    }

    func testParsesBroadcastAndEnd() {
        XCTAssertEqual(ConsoleProtocol.parse("XHB9HJI|DX de K1TH: 14023.1")?.isBroadcast, true)
        XCTAssertEqual(ConsoleProtocol.parse("ZHB9HJI|bye")?.isEnd, true)
    }

    func testStripsTrailingCR() {
        XCTAssertEqual(ConsoleProtocol.parse("DHB9HJI|hello\r")?.text, "hello")
    }

    func testTextMayContainPipe() {
        let msg = ConsoleProtocol.parse("DHB9HJI|a|b|c")
        XCTAssertEqual(msg?.call, "HB9HJI")
        XCTAssertEqual(msg?.text, "a|b|c")
    }

    func testRejectsMalformed() {
        XCTAssertNil(ConsoleProtocol.parse("no separator here"))
        XCTAssertNil(ConsoleProtocol.parse("|leading bar"))
        XCTAssertNil(ConsoleProtocol.parse(""))
    }

    func testBuilders() {
        XCTAssertEqual(ConsoleProtocol.attach(call: "HB9HJI"), "AHB9HJI|local width=80 enhanced")
        XCTAssertEqual(ConsoleProtocol.input(call: "HB9HJI", line: "show/users"), "IHB9HJI|show/users")
    }
}
