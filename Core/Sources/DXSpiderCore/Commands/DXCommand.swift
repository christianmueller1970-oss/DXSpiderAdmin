import Foundation

/// A type-safe representation of a DXSpider CLI command.
///
/// Building commands through this enum (rather than free-form strings) keeps callsigns
/// normalised, lets the UI flag destructive actions, and produces exactly one line to send.
public enum DXCommand: Equatable, Sendable {
    // Read-only queries
    case showUsers
    case showNodes
    case showConfiguration
    case showRoute(callsign: String)
    /// Optional single exact callsign — the node strips spaces/`*`, so wildcards and
    /// multiple calls do NOT work here (verified live); nil lists all registered users.
    case showRegistered(call: String?)
    case showBadSpotter
    case showLockout
    case showBadNode
    case showBadDX
    case showBadWord
    /// A read-only query from the verified ``NodeQuery`` catalogue (info & diagnostics
    /// screen). The line is assembled by the catalogue entry from a typed argument, never
    /// taken verbatim from a text field, so it stays safely read-only — unlike ``raw``.
    case query(NodeQuery, argument: String)

    // Mutating / administrative
    case setPrivilege(level: PrivilegeLevel, callsign: String)
    case setNode(callsign: String)
    case boot(callsign: String)
    case setRegister(callsigns: [String])
    case unsetRegister(callsigns: [String])
    case setBadSpotter(callsigns: [String])
    case unsetBadSpotter(callsigns: [String])
    case setLockout(callsigns: [String])
    case unsetLockout(callsigns: [String])
    case setBadNode(callsigns: [String])
    case unsetBadNode(callsigns: [String])
    case setBadDX(callsigns: [String])
    case unsetBadDX(callsigns: [String])
    /// Bad words filter banned terms (not callsigns); the node uppercases them.
    case setBadWord(words: [String])
    case unsetBadWord(words: [String])

    // Spot filters
    case acceptSpots(slot: Int, rule: String)
    case rejectSpots(slot: Int, rule: String)
    case clearSpots(slot: Int)

    /// Free-form command for advanced/manual use. Sent verbatim.
    case raw(String)

    /// The exact line to send to the node (without trailing newline).
    public var line: String {
        switch self {
        case .showUsers:
            return "show/users"
        case .showNodes:
            // Real DXSpider has no "show/nodes"; the node list comes from this command
            // (verified live against HB9HJI-2 — see docs/NodeProtocol.md).
            return "show/configuration/nodes"
        case .showConfiguration:
            return "show/configuration"
        case .showRoute(let callsign):
            return "show/route \(Self.normalize(callsign))"
        case .showRegistered(let call):
            // "show/registered" (the "ed" form, unlike set/register & unset/register).
            // With a single exact call it checks just that one; nil lists all.
            return Self.showLine("show/registered", call)
        case .showBadSpotter:
            // The node ignores any argument here and always lists the full set.
            return "show/badspotter"
        case .showLockout:
            // Unlike the other show/bad… commands, this REQUIRES an argument
            // ("usage: sh/lockout <call>|ALL", verified live) — ALL lists everything.
            return "show/lockout ALL"
        case .showBadNode:
            return "show/badnode"
        case .showBadDX:
            return "show/baddx"
        case .showBadWord:
            return "show/badword"
        case .query(let query, let argument):
            return query.line(argument: argument)
        case .setPrivilege(let level, let callsign):
            return "set/priv \(level.rawValue) \(Self.normalize(callsign))"
        case .setNode(let callsign):
            return "set/node \(Self.normalize(callsign))"
        case .boot(let callsign):
            return "boot \(Self.normalize(callsign))"
        case .setRegister(let callsigns):
            return "set/register \(Self.normalizeList(callsigns))"
        case .unsetRegister(let callsigns):
            return "unset/register \(Self.normalizeList(callsigns))"
        case .setBadSpotter(let callsigns):
            // Node strips SSIDs itself; we just pass the (normalised) calls. Priv ≥ 6.
            return "set/badspotter \(Self.normalizeList(callsigns))"
        case .unsetBadSpotter(let callsigns):
            return "unset/badspotter \(Self.normalizeList(callsigns))"
        case .setLockout(let callsigns):
            return "set/lockout \(Self.normalizeList(callsigns))"
        case .unsetLockout(let callsigns):
            return "unset/lockout \(Self.normalizeList(callsigns))"
        case .setBadNode(let callsigns):
            return "set/badnode \(Self.normalizeList(callsigns))"
        case .unsetBadNode(let callsigns):
            return "unset/badnode \(Self.normalizeList(callsigns))"
        case .setBadDX(let callsigns):
            return "set/baddx \(Self.normalizeList(callsigns))"
        case .unsetBadDX(let callsigns):
            return "unset/baddx \(Self.normalizeList(callsigns))"
        case .setBadWord(let words):
            return "set/badword \(Self.normalizeList(words))"
        case .unsetBadWord(let words):
            return "unset/badword \(Self.normalizeList(words))"
        case .acceptSpots(let slot, let rule):
            return "accept/spots \(slot) \(rule)"
        case .rejectSpots(let slot, let rule):
            return "reject/spots \(slot) \(rule)"
        case .clearSpots(let slot):
            return "clear/spots \(slot)"
        case .raw(let text):
            return text
        }
    }

    /// Whether this command changes state and should require explicit confirmation.
    public var isDestructive: Bool {
        switch self {
        case .showUsers, .showNodes, .showConfiguration, .showRoute,
             .showRegistered, .showBadSpotter, .showLockout,
             .showBadNode, .showBadDX, .showBadWord, .query:
            return false
        case .setPrivilege, .setNode, .boot, .setRegister, .unsetRegister,
             .setBadSpotter, .unsetBadSpotter,
             .setLockout, .unsetLockout, .setBadNode, .unsetBadNode,
             .setBadDX, .unsetBadDX, .setBadWord, .unsetBadWord,
             .acceptSpots, .rejectSpots, .clearSpots:
            return true
        case .raw:
            // Unknown intent — treat conservatively as destructive.
            return true
        }
    }

    /// Whether this command only reads state (safe in read-only mode).
    public var isReadOnly: Bool { !isDestructive }

    private static func normalize(_ callsign: String) -> String {
        callsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Normalise and space-join multiple callsigns (e.g. "set/register HB9A HB9B").
    private static func normalizeList(_ callsigns: [String]) -> String {
        callsigns.map(normalize).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// A `show/…` line with an optional trailing pattern (uppercased; wildcards allowed).
    private static func showLine(_ base: String, _ pattern: String?) -> String {
        guard let pattern = pattern?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !pattern.isEmpty else { return base }
        return "\(base) \(pattern)"
    }
}
