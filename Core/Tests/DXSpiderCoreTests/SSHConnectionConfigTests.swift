import XCTest
@testable import DXSpiderCore

final class SSHConnectionConfigTests: XCTestCase {
    func testSSHArguments() {
        let config = SSHConnectionConfig(
            host: "node.example.org",
            user: "spider",
            port: 2222,
            consolePath: "/spider/perl/console.pl"
        )
        XCTAssertEqual(config.sshArguments, [
            "-tt",
            "-p", "2222",
            "-o", "BatchMode=yes",
            "spider@node.example.org",
            "/spider/perl/console.pl",
        ])
    }

    func testDefaultsToPort22() {
        let config = SSHConnectionConfig(host: "h", user: "u", consolePath: "/c")
        XCTAssertEqual(config.port, 22)
        XCTAssertTrue(config.sshArguments.contains("22"))
    }

    func testCodableRoundTrip() throws {
        let config = SSHConnectionConfig(
            host: "h", user: "u", port: 22, consolePath: "/c", sysopCall: "HB9HJI"
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SSHConnectionConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}

final class ProcessSysopChannelHelperTests: XCTestCase {
    func testStripEchoRemovesEchoedCommand() {
        let raw = "show/users\nDL1ABC W1AW\nHB9XYZ"
        XCTAssertEqual(
            ProcessSysopChannel.stripEcho(raw, command: .showUsers),
            "DL1ABC W1AW\nHB9XYZ"
        )
    }

    func testStripEchoLeavesUnrelatedOutput() {
        let raw = "DL1ABC W1AW"
        XCTAssertEqual(
            ProcessSysopChannel.stripEcho(raw, command: .showUsers),
            "DL1ABC W1AW"
        )
    }
}
