import Foundation

/// A user known to the DXSpider node, as surfaced by `show/users` and related commands.
public struct ClusterUser: Identifiable, Hashable, Sendable, Codable {
    /// The callsign uniquely identifies a user on the node.
    public var id: String { callsign }

    public var callsign: String
    public var name: String?
    public var privilege: PrivilegeLevel
    public var isRegistered: Bool

    public init(
        callsign: String,
        name: String? = nil,
        privilege: PrivilegeLevel = .user,
        isRegistered: Bool = false
    ) {
        self.callsign = callsign.uppercased()
        self.name = name
        self.privilege = privilege
        self.isRegistered = isRegistered
    }
}
