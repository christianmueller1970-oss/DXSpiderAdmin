import Foundation

/// A linked node/partner as surfaced by `show/nodes`.
public struct ClusterNode: Identifiable, Hashable, Sendable, Codable {
    public var id: String { callsign }

    public var callsign: String
    public var isConnected: Bool
    /// Software/version string reported by the node, if known.
    public var version: String?

    public init(callsign: String, isConnected: Bool = false, version: String? = nil) {
        self.callsign = callsign.uppercased()
        self.isConnected = isConnected
        self.version = version
    }
}
