import Foundation

/// Whether the channel may send state-changing commands.
///
/// New connections default to ``readOnly`` (Konzeptdokument §2): mutations must be
/// explicitly enabled before a destructive command can reach the node.
public enum ChannelMode: Sendable, Equatable {
    case readOnly
    case readWrite

    public var allowsMutations: Bool { self == .readWrite }

    /// Throws ``SysopChannelError/readOnly`` if `command` would change node state while
    /// the channel is read-only.
    public func authorize(_ command: DXCommand) throws {
        if command.isDestructive && !allowsMutations {
            throw SysopChannelError.readOnly
        }
    }
}
