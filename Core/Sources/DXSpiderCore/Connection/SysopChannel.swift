import Foundation

/// Abstraction over the transport that carries sysop commands to the node.
///
/// The planned M1 implementation launches `/usr/bin/ssh -tt <user>@<host> "<console.pl>"`
/// as a subprocess (PTY), letting the system handle SSH-key auth via `ssh-agent`.
/// The app itself never stores keys or passwords.
///
/// Defined as a protocol so the core (and its tests) can run against a mock channel
/// without a live server.
public protocol SysopChannel: Sendable {
    /// Establish the connection and reach a `ready` state.
    func connect() async throws

    /// Send a single command line and return the node's textual response.
    func send(_ command: DXCommand) async throws -> String

    /// Close the connection and tear down the underlying process.
    func disconnect() async
}

/// Errors surfaced by a ``SysopChannel``.
public enum SysopChannelError: Error, Equatable, Sendable {
    case notConnected
    case connectionFailed(String)
    case timedOut
    /// A write was blocked because the channel is in read-only mode.
    case readOnly
}
