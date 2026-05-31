import Foundation

/// The real ``SysopChannel`` against a DXSpider node, talking to the **console socket**
/// (`docs/NodeProtocol.md`) instead of driving the Curses-based `console.pl`.
///
/// It launches `/usr/bin/ssh <user>@<host> perl -e '<bridge>'`, where the bridge copies bytes
/// between the SSH stream and the node-local console socket (default `127.0.0.1:27754`). Over
/// that line-based protocol it attaches (`A<call>|…`), sends commands (`I<call>|…`) and reads
/// replies `<sort><call>|<line>`; only `D` (display) lines form a response — `X` broadcasts
/// (spots) are ignored here, `Z` ends the session.
///
/// Auth stays with the system SSH (key/agent). Validated against HB9HJI-2.
public actor ConsoleSocketChannel: SysopChannel {
    public static let sshExecutablePath = "/usr/bin/ssh"

    public private(set) var state: ConnectionState = .disconnected

    private let config: SSHConnectionConfig
    private let mode: ChannelMode
    private let audit: AuditSink?
    private let now: @Sendable () -> Date
    private let socketHost: String
    private let socketPort: Int
    private let connectTimeout: Duration
    private let commandTimeout: Duration
    /// Quiet window after the last display line before a response is considered complete.
    /// DXSpider commands that fork (`spawn_cmd`, e.g. `show/registered`) print the prompt
    /// *before* their output, so prompt-only framing would cut the response short and leak
    /// the output onto the next command. Debouncing on this window captures both orderings.
    private let settleDelay: Duration

    private var call = ""
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var readerTask: Task<Void, Never>?

    private let detector = PromptDetector()
    private var accumulator = ResponseAccumulator()
    private var lineBuffer = ""
    private var responseQueue: [String] = []
    private var pendingWaiter: CheckedContinuation<String, Error>?
    private var stderrBuffer = ""
    private var intentionalClose = false
    private var settleTask: Task<Void, Never>?

    public init(
        config: SSHConnectionConfig,
        mode: ChannelMode = .readOnly,
        audit: AuditSink? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        socketHost: String = "127.0.0.1",
        socketPort: Int = 27754,
        connectTimeout: Duration = .seconds(20),
        commandTimeout: Duration = .seconds(15),
        settleDelay: Duration = .milliseconds(400)
    ) {
        self.config = config
        self.mode = mode
        self.audit = audit
        self.now = now
        self.socketHost = socketHost
        self.socketPort = socketPort
        self.connectTimeout = connectTimeout
        self.commandTimeout = commandTimeout
        self.settleDelay = settleDelay
    }

    // MARK: - Lifecycle

    public func connect() async throws {
        guard let sysop = config.sysopCall.map({ Callsign.normalize($0) }), !sysop.isEmpty else {
            throw SysopChannelError.connectionFailed("Sysop-Rufzeichen fehlt (für den Console-Socket nötig)")
        }
        call = sysop

        if process != nil { teardown(intentional: true) }
        state = .connecting
        intentionalClose = false
        accumulator = ResponseAccumulator()
        lineBuffer = ""
        responseQueue.removeAll()
        stderrBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: Self.sshExecutablePath)
        proc.arguments = sshArguments

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
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
            try write(ConsoleProtocol.attach(call: call))
            _ = try await nextResponse(timeout: connectTimeout) // banner up to the first prompt
            state = .ready
        } catch {
            let reason = stderrBuffer.isEmpty ? "kein Prompt vor Timeout" : stderrBuffer
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

        state = .busy
        do {
            try write(ConsoleProtocol.input(call: call, line: command.line))
        } catch {
            state = .failed(reason: "write failed")
            await record(command, .failed("write failed: \(error.localizedDescription)"))
            throw SysopChannelError.connectionFailed(error.localizedDescription)
        }

        do {
            let response = try await nextResponse(timeout: commandTimeout)
            state = .ready
            await record(command, .sent)
            return response
        } catch {
            if state == .busy { state = .ready }
            await record(command, .failed("\(error)"))
            throw error
        }
    }

    public func disconnect() async {
        if process?.isRunning == true {
            try? write(ConsoleProtocol.input(call: call, line: "bye"))
        }
        teardown(intentional: true)
        state = .disconnected
    }

    // MARK: - SSH command

    private var sshArguments: [String] {
        [
            "-o", "BatchMode=yes",
            "-T",
            "-p", String(config.port),
            "\(config.user)@\(config.host)",
            "perl -e '\(Self.bridgeProgram(host: socketHost, port: socketPort))'",
        ]
    }

    /// A self-contained Perl bridge: copies bytes both ways between STDIN/STDOUT and the
    /// node-local console socket. Uses only double quotes so it can be wrapped in single
    /// quotes for the remote shell.
    private static func bridgeProgram(host: String, port: Int) -> String {
        "use IO::Socket::INET;use IO::Select;$|=1;"
        + "my $s=IO::Socket::INET->new(PeerAddr=>\"\(host)\",PeerPort=>\(port),Proto=>\"tcp\")"
        + "or die \"bridge connect failed: $!\\n\";$s->autoflush(1);"
        + "my $sel=IO::Select->new(\\*STDIN,$s);"
        + "while(1){for my $fh($sel->can_read){my $n=sysread($fh,my $buf,8192);"
        + "exit if !defined $n||$n==0;"
        + "if($fh==$s){syswrite(STDOUT,$buf)}else{syswrite($s,$buf)}}}"
    }

    private func write(_ message: String) throws {
        guard let stdin = stdinHandle else { throw SysopChannelError.notConnected }
        try stdin.write(contentsOf: Data((message + "\n").utf8))
    }

    // MARK: - Reading & framing

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
        lineBuffer += chunk
        while let newline = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newline])
            lineBuffer.removeSubrange(lineBuffer.startIndex...newline)
            handle(line)
        }
    }

    private func handle(_ rawLine: String) {
        guard let message = ConsoleProtocol.parse(rawLine) else { return }
        if message.isEnd {
            if !intentionalClose {
                deliver(.failure(SysopChannelError.connectionFailed("Node beendete die Sitzung")))
            }
            return
        }
        guard message.isDisplay else { return } // ignore X broadcasts (spot feed) and others
        accumulator.append(message.text + "\n")
        // Don't deliver on the bare prompt — forked commands (spawn_cmd) print the prompt
        // *before* their output. Wait until the stream falls quiet, then deliver the whole
        // response with prompt lines stripped (see `settleDelay`).
        scheduleSettle()
    }

    /// (Re)start the quiet-window timer; each new display line pushes it back.
    private func scheduleSettle() {
        settleTask?.cancel()
        let delay = settleDelay
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.flushSettled()
        }
    }

    /// Deliver everything buffered since the last command as one response, dropping the
    /// prompt line(s). Handles both orderings (output→prompt and prompt→output).
    private func flushSettled() {
        let pending = accumulator.pending
        guard !pending.isEmpty else { return }
        accumulator = ResponseAccumulator()
        deliver(.success(Self.stripPrompts(from: pending, using: detector)))
    }

    /// Remove every prompt line and surrounding blank lines, leaving only command output.
    static func stripPrompts(from text: String, using detector: PromptDetector) -> String {
        var lines = text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)
        lines.removeAll { detector.isPromptLine($0) }
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private func appendStderr(_ text: String) {
        stderrBuffer.append(text)
    }

    private func handleStreamEnded() {
        guard !intentionalClose else { return }
        deliver(.failure(SysopChannelError.connectionFailed(endReason())))
    }

    private func handleProcessExit(status: Int32) {
        guard !intentionalClose else { return }
        if case .failed = state {} else {
            state = .failed(reason: endReason(status: status))
        }
        deliver(.failure(SysopChannelError.connectionFailed(endReason(status: status))))
    }

    private func endReason(status: Int32? = nil) -> String {
        let trimmed = stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let status { return "ssh exited (status \(status))" }
        return "Verbindung geschlossen"
    }

    // MARK: - Response delivery

    private func deliver(_ result: Result<String, Error>) {
        if let waiter = pendingWaiter {
            pendingWaiter = nil
            waiter.resume(with: result)
        } else if case .success(let response) = result {
            responseQueue.append(response)
        }
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
        settleTask?.cancel()
        settleTask = nil
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
