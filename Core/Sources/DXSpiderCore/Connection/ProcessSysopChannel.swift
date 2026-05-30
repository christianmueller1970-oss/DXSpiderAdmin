import Foundation

/// The real ``SysopChannel``: launches `/usr/bin/ssh -tt <user>@<host> "<console.pl>"` as a
/// subprocess and talks to the node over its stdin/stdout (Konzeptdokument §3/§4).
///
/// Design notes:
/// - **Key auth stays with the OS.** We invoke the system `ssh`, which uses `ssh-agent` and
///   `~/.ssh`. This type never sees a key or password.
/// - **Continuous async reading.** A single reader task feeds every stdout chunk into a
///   ``ResponseAccumulator``; responses are delimited by the node's prompt via
///   ``PromptDetector`` — never by fixed sleeps.
/// - **Safety.** ``ChannelMode`` blocks mutations in read-only mode, every attempt is sent to
///   the ``AuditSink``, and reads are bounded by a timeout.
///
/// This type drives a live process, so it is validated against the real node (HB9HJI-2) rather
/// than by unit tests; the pure pieces it composes are covered separately. Use
/// ``InMemorySysopChannel`` for tests and previews.
public actor ProcessSysopChannel: SysopChannel {
    /// Path to the system SSH client. The app never bundles its own.
    public static let sshExecutablePath = "/usr/bin/ssh"

    public private(set) var state: ConnectionState = .disconnected

    private let config: SSHConnectionConfig
    private let mode: ChannelMode
    private let audit: AuditSink?
    private let now: @Sendable () -> Date
    private let connectTimeout: Duration
    private let commandTimeout: Duration

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var readerTask: Task<Void, Never>?

    private var accumulator = ResponseAccumulator()
    private var responseQueue: [String] = []
    private var pendingWaiter: CheckedContinuation<String, Error>?
    private var stderrBuffer = ""
    private var intentionalClose = false

    public init(
        config: SSHConnectionConfig,
        mode: ChannelMode = .readOnly,
        audit: AuditSink? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        connectTimeout: Duration = .seconds(20),
        commandTimeout: Duration = .seconds(15)
    ) {
        self.config = config
        self.mode = mode
        self.audit = audit
        self.now = now
        self.connectTimeout = connectTimeout
        self.commandTimeout = commandTimeout
    }

    // MARK: - Lifecycle

    public func connect() async throws {
        if process != nil { teardown(intentional: true) }
        state = .connecting
        intentionalClose = false
        accumulator = ResponseAccumulator()
        responseQueue.removeAll()
        stderrBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: Self.sshExecutablePath)
        proc.arguments = config.sshArguments

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.process = proc
        self.stdinHandle = stdin.fileHandleForWriting
        self.stdoutHandle = stdout.fileHandleForReading
        self.stderrHandle = stderr.fileHandleForReading

        startReading(stdout: stdout.fileHandleForReading, stderr: stderr.fileHandleForReading)

        proc.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            Task { await self?.handleProcessExit(status: status) }
        }

        do {
            try proc.run()
        } catch {
            teardown(intentional: false)
            state = .failed(reason: "launch failed: \(error.localizedDescription)")
            throw SysopChannelError.connectionFailed(error.localizedDescription)
        }

        state = .authenticating
        do {
            // The first response is the login banner up to the initial prompt.
            _ = try await nextResponse(timeout: connectTimeout)
            state = .ready
        } catch {
            let reason = stderrBuffer.isEmpty ? "no prompt before timeout" : stderrBuffer
            teardown(intentional: false)
            state = .failed(reason: reason)
            throw SysopChannelError.connectionFailed(reason.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public func send(_ command: DXCommand) async throws -> String {
        guard state.canSendCommands else {
            await record(command, .failed("not connected"))
            throw SysopChannelError.notConnected
        }
        do {
            try mode.authorize(command)
        } catch {
            await record(command, .blockedReadOnly)
            throw error
        }
        guard let stdin = stdinHandle else {
            await record(command, .failed("not connected"))
            throw SysopChannelError.notConnected
        }

        state = .busy
        do {
            try stdin.write(contentsOf: Data((command.line + "\n").utf8))
        } catch {
            state = .failed(reason: "write failed")
            await record(command, .failed("write failed: \(error.localizedDescription)"))
            throw SysopChannelError.connectionFailed(error.localizedDescription)
        }

        do {
            let raw = try await nextResponse(timeout: commandTimeout)
            state = .ready
            await record(command, .sent)
            return Self.stripEcho(raw, command: command)
        } catch {
            // A timeout doesn't necessarily kill the connection — allow a retry.
            if state == .busy { state = .ready }
            await record(command, .failed("\(error)"))
            throw error
        }
    }

    public func disconnect() async {
        teardown(intentional: true)
        state = .disconnected
    }

    // MARK: - Reading

    private func startReading(stdout: FileHandle, stderr: FileHandle) {
        var continuation: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { continuation = $0 }
        let out = continuation!

        stdout.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                out.finish()
            } else {
                out.yield(String(decoding: data, as: UTF8.self))
            }
        }

        stderr.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { await self?.appendStderr(text) }
        }

        readerTask = Task { [weak self] in
            for await chunk in stream {
                await self?.ingest(chunk)
            }
            await self?.handleStreamEnded()
        }
    }

    private func ingest(_ chunk: String) {
        accumulator.append(chunk)
        while let response = accumulator.takeCompletedResponse() {
            deliver(.success(response))
        }
    }

    private func appendStderr(_ text: String) {
        stderrBuffer.append(text)
    }

    private func handleStreamEnded() {
        guard !intentionalClose else { return }
        deliver(.failure(SysopChannelError.connectionFailed(connectionEndedReason())))
    }

    private func handleProcessExit(status: Int32) {
        guard !intentionalClose else { return }
        if case .failed = state {} else {
            state = .failed(reason: connectionEndedReason(status: status))
        }
        deliver(.failure(SysopChannelError.connectionFailed(connectionEndedReason(status: status))))
    }

    private func connectionEndedReason(status: Int32? = nil) -> String {
        let trimmed = stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let status { return "ssh exited (status \(status))" }
        return "connection closed"
    }

    // MARK: - Response delivery

    /// Hand a completed response (or failure) to a waiter, or queue successes for the next read.
    private func deliver(_ result: Result<String, Error>) {
        if let waiter = pendingWaiter {
            pendingWaiter = nil
            waiter.resume(with: result)
        } else if case .success(let response) = result {
            responseQueue.append(response)
        }
        // A failure with no waiter has nowhere to go; state already reflects it.
    }

    private func nextResponse(timeout: Duration) async throws -> String {
        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            await self?.failPendingWaiter(with: SysopChannelError.timedOut)
        }
        defer { timeoutTask.cancel() }
        return try await withCheckedThrowingContinuation { continuation in
            pendingWaiter = continuation
        }
    }

    private func failPendingWaiter(with error: Error) {
        guard let waiter = pendingWaiter else { return }
        pendingWaiter = nil
        waiter.resume(throwing: error)
    }

    // MARK: - Teardown

    private func teardown(intentional: Bool) {
        intentionalClose = intentional
        readerTask?.cancel()
        readerTask = nil
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil

        if let process, process.isRunning {
            try? stdinHandle?.close()
            process.terminate()
        }
        process?.terminationHandler = nil
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil

        if intentional {
            failPendingWaiter(with: SysopChannelError.notConnected)
        }
    }

    // MARK: - Helpers

    /// With `-tt`, the PTY echoes the command back as the first line. Drop it so callers get
    /// just the node's response.
    static func stripEcho(_ response: String, command: DXCommand) -> String {
        let lines = response.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        if let first = lines.first,
           String(first).trimmingCharacters(in: .whitespacesAndNewlines) == command.line {
            return lines.dropFirst().joined(separator: "\n")
        }
        return response
    }

    private func record(_ command: DXCommand, _ outcome: AuditEntry.Outcome) async {
        guard let audit else { return }
        await audit.record(AuditEntry(
            timestamp: now(),
            line: command.line,
            destructive: command.isDestructive,
            outcome: outcome
        ))
    }
}
