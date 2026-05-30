import Foundation

/// Non-secret connection settings for reaching the DXSpider node over SSH.
///
/// Per Konzeptdokument §2 these values are explicitly **not** secrets: no keys or passwords
/// live here. SSH-key auth is handled entirely by the system (`ssh-agent`, `~/.ssh`). The app
/// loads this from a readable file in the user's Documents folder — never from the bundle or
/// repository.
public struct SSHConnectionConfig: Sendable, Equatable, Codable {
    public var host: String
    public var user: String
    public var port: Int
    /// Absolute path to `console.pl` on the node, e.g. `/spider/perl/console.pl`.
    public var consolePath: String
    /// Informational sysop callsign (e.g. for an audit-log header). Never used for auth.
    public var sysopCall: String?

    public init(
        host: String,
        user: String,
        port: Int = 22,
        consolePath: String,
        sysopCall: String? = nil
    ) {
        self.host = host
        self.user = user
        self.port = port
        self.consolePath = consolePath
        self.sysopCall = sysopCall
    }

    /// Arguments passed to `/usr/bin/ssh`.
    ///
    /// `-tt` forces the remote pseudo-terminal that `console.pl` expects; `BatchMode=yes`
    /// enforces key-only auth — it disables interactive password prompts that would otherwise
    /// hang the subprocess, and makes a missing key fail fast instead of blocking.
    public var sshArguments: [String] {
        [
            "-tt",
            "-p", String(port),
            "-o", "BatchMode=yes",
            "\(user)@\(host)",
            consolePath,
        ]
    }
}
