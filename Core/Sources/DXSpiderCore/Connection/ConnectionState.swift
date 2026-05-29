import Foundation

/// Lifecycle of the connection to the DXSpider node.
///
/// The flow is: `.disconnected` → `.connecting` → `.authenticating` → `.ready`,
/// with `.busy` while a command is in flight and `.failed` on error.
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case authenticating
    case ready
    case busy
    case failed(reason: String)

    /// Whether commands may be sent in this state.
    public var canSendCommands: Bool {
        switch self {
        case .ready, .busy: return true
        default: return false
        }
    }
}
