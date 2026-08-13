import XCTest
@testable import DXSpiderCore

final class NodeQueryTests: XCTestCase {
    private func query(_ id: String) throws -> NodeQuery {
        try XCTUnwrap(NodeQuery.query(id: id), "Katalogeintrag \(id) fehlt")
    }

    func testCatalogueIDsAreUnique() {
        let ids = NodeQuery.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryGroupHasEntriesAndFavouritesResolve() {
        for group in NodeQuery.Group.allCases {
            XCTAssertFalse(NodeQuery.queries(in: group).isEmpty, "Gruppe \(group.rawValue) ist leer")
        }
        XCTAssertEqual(NodeQuery.favourites.count, NodeQuery.favouriteIDs.count)
    }

    func testArgumentlessQueryIgnoresStrayText() throws {
        let cluster = try query("show/cluster")
        XCTAssertEqual(cluster.line(argument: ""), "show/cluster")
        XCTAssertEqual(cluster.line(argument: "HB9HJI"), "show/cluster")
        XCTAssertTrue(cluster.isValid(argument: "egal"))
    }

    func testCallsignArgumentIsUppercasedAndValidated() throws {
        let stat = try query("stat/user")
        XCTAssertEqual(stat.line(argument: " hb9hji "), "stat/user HB9HJI")
        XCTAssertTrue(stat.isValid(argument: "hb9hji"))
        XCTAssertFalse(stat.isValid(argument: "!!!"))
        // Pflichtargument: leer ist ungültig, die Zeile bliebe sonst unvollständig.
        XCTAssertFalse(stat.isValid(argument: "  "))
    }

    func testCountArgumentKeepsDigitsOnlyAndIsOptional() throws {
        let log = try query("show/log")
        XCTAssertEqual(log.line(argument: "20"), "show/log 20")
        XCTAssertEqual(log.line(argument: "20 Zeilen"), "show/log 20")
        XCTAssertEqual(log.line(argument: ""), "show/log")
        XCTAssertTrue(log.isValid(argument: ""))
        XCTAssertFalse(log.isValid(argument: "0"))
        XCTAssertFalse(log.isValid(argument: "abc"))
    }

    func testLogByCallsignSharesTheBaseButNotTheID() throws {
        let byCall = try query("show/log-call")
        XCTAssertEqual(byCall.base, "show/log")
        XCTAssertEqual(byCall.line(argument: "hb9hji"), "show/log HB9HJI")
    }

    func testLocatorValidation() throws {
        let qra = try query("show/qra")
        XCTAssertTrue(qra.isValid(argument: "JN47PN"))
        XCTAssertTrue(qra.isValid(argument: "jn47"))
        XCTAssertFalse(qra.isValid(argument: "JN47P"))
        XCTAssertFalse(qra.isValid(argument: "4747PN"))
        XCTAssertEqual(qra.line(argument: "jn47pn"), "show/qra JN47PN")
    }

    func testEveryCatalogueEntryIsReadOnlyAsADXCommand() {
        for entry in NodeQuery.all {
            let command = DXCommand.query(entry, argument: entry.defaultArgument)
            XCTAssertTrue(command.isReadOnly, "\(entry.id) darf nicht als destruktiv gelten")
            XCTAssertEqual(command.line, entry.line(argument: entry.defaultArgument))
        }
    }

    func testDefaultArgumentsAreValid() {
        for entry in NodeQuery.all where !entry.defaultArgument.isEmpty {
            XCTAssertTrue(entry.isValid(argument: entry.defaultArgument),
                          "Vorgabewert von \(entry.id) ist ungültig")
        }
    }
}
