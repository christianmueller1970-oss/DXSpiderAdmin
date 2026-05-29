import Foundation

/// A DXSpider privilege level.
///
/// DXSpider uses privilege levels from `0` (ordinary user) up to `9` (full sysop).
/// Values outside that range are rejected at construction time.
public struct PrivilegeLevel: RawRepresentable, Comparable, Hashable, Sendable, Codable {
    public static let minRawValue = 0
    public static let maxRawValue = 9

    public let rawValue: Int

    public init?(rawValue: Int) {
        guard (PrivilegeLevel.minRawValue...PrivilegeLevel.maxRawValue).contains(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    /// Ordinary user (level 0).
    public static let user = PrivilegeLevel(rawValue: 0)!
    /// Full sysop (level 9).
    public static let sysop = PrivilegeLevel(rawValue: 9)!

    public static func < (lhs: PrivilegeLevel, rhs: PrivilegeLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
