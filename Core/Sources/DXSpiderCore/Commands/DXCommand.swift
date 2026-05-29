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

    // Mutating / administrative
    case setPrivilege(level: PrivilegeLevel, callsign: String)
    case setNode(callsign: String)
    case boot(callsign: String)
    case setRegister(callsign: String)

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
            return "show/nodes"
        case .showConfiguration:
            return "show/configuration"
        case .showRoute(let callsign):
            return "show/route \(Self.normalize(callsign))"
        case .setPrivilege(let level, let callsign):
            return "set/priv \(level.rawValue) \(Self.normalize(callsign))"
        case .setNode(let callsign):
            return "set/node \(Self.normalize(callsign))"
        case .boot(let callsign):
            return "boot \(Self.normalize(callsign))"
        case .setRegister(let callsign):
            return "set/register \(Self.normalize(callsign))"
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
        case .showUsers, .showNodes, .showConfiguration, .showRoute:
            return false
        case .setPrivilege, .setNode, .boot, .setRegister,
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
}
