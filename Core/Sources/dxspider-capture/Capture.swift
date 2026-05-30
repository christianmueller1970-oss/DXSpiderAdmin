import Foundation
import DXSpiderCore

/// Diagnostic CLI for the live test against the real node (Konzeptdokument §10).
///
/// Connects read-only via `ProcessSysopChannel`, runs a handful of `show/*` queries and saves
/// each raw response as a fixture file. The captured output drives verification/refinement of
/// `ShowUsersParser`, `ShowNodesParser` and the `SpotFilter` syntax.
///
/// Connection settings come from `~/Documents/DXSpiderAdmin/settings.json` (written by the app)
/// or from command-line flags. No keys/passwords are handled — SSH auth stays with the system.
///
/// PRIVACY: fixtures contain real callsigns and are written **outside** the repository
/// (`~/Documents/DXSpiderAdmin/fixtures/`). Anonymise before committing any test fixture.
@main
struct Capture {
    static func main() async {
        let arguments = Arguments(CommandLine.arguments)
        if arguments.help {
            printUsage()
            return
        }

        guard let config = resolveConfig(arguments) else {
            FileHandle.standardError.write(Data("Fehlende Verbindungsdaten.\n\n".utf8))
            printUsage()
            exit(2)
        }

        let outDir = arguments.outDir
            ?? SettingsStore.standard().directory.appendingPathComponent("fixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        print("Verbinde mit \(config.user)@\(config.host):\(config.port) (read-only) …")
        let channel = ProcessSysopChannel(config: config, mode: .readOnly)

        do {
            try await channel.connect()
            print("Verbunden.\n")
        } catch {
            print("Verbindung fehlgeschlagen: \(error)")
            print("Hinweis: SSH-Key in den Agent laden — `ssh-add ~/.ssh/id_ed25519`.")
            print("(Der Kanal nutzt BatchMode=yes und unterbindet daher interaktive Passphrase-Abfragen.)")
            exit(1)
        }

        await capture(.showConfiguration, label: "show_configuration", from: channel, outDir: outDir)
        await capture(.showUsers, label: "show_users", from: channel, outDir: outDir)
        await capture(.showNodes, label: "show_nodes", from: channel, outDir: outDir)
        if let route = arguments.route {
            await capture(.showRoute(callsign: route), label: "show_route", from: channel, outDir: outDir)
        }

        await channel.disconnect()
        print("Fertig. Fixtures in: \(outDir.path)")
        print("DATENSCHUTZ: enthält echte Rufzeichen — vor jeglichem Commit anonymisieren.")
    }

    // MARK: Steps

    private static func capture(
        _ command: DXCommand,
        label: String,
        from channel: ProcessSysopChannel,
        outDir: URL
    ) async {
        do {
            let response = try await channel.send(command)
            print("----- \(command.line) -----")
            print(response.isEmpty ? "(leere Antwort)" : response)
            let url = outDir.appendingPathComponent("\(label).txt")
            try? response.write(to: url, atomically: true, encoding: .utf8)
            print(">> gesichert: \(url.lastPathComponent)\n")
        } catch {
            print("!! Fehler bei „\(command.line)“: \(error)\n")
        }
    }

    // MARK: Config resolution

    /// Merge command-line flags over saved settings; CLI flags win.
    private static func resolveConfig(_ args: Arguments) -> SSHConnectionConfig? {
        let saved = try? SettingsStore.standard().load().connection

        guard let host = args.host ?? saved?.host, !host.isEmpty,
              let user = args.user ?? saved?.user, !user.isEmpty else {
            return nil
        }
        let console = args.console ?? saved?.consolePath ?? "/spider/perl/console.pl"
        let port = args.port ?? saved?.port ?? 22
        return SSHConnectionConfig(host: host, user: user, port: port, consolePath: console)
    }

    private static func printUsage() {
        print("""
        dxspider-capture — erfasst echte Node-Ausgaben als Parser-Fixtures (read-only).

        Verwendung:
          dxspider-capture [--host H] [--user U] [--port P] [--console PFAD] [--route CALL] [--out DIR]

        Ohne Flags werden die Werte aus ~/Documents/DXSpiderAdmin/settings.json gelesen
        (die die App schreibt). Flags überschreiben gespeicherte Werte.

        Voraussetzung: passender SSH-Key im ssh-agent (ssh-add ~/.ssh/id_ed25519).
        Es werden ausschließlich read-only-Abfragen gesendet.
        """)
    }
}

/// Minimal command-line flag parser.
private struct Arguments {
    var host: String?
    var user: String?
    var console: String?
    var route: String?
    var port: Int?
    var outDir: URL?
    var help = false

    init(_ argv: [String]) {
        var iterator = argv.dropFirst().makeIterator()
        while let flag = iterator.next() {
            switch flag {
            case "--help", "-h": help = true
            case "--host": host = iterator.next()
            case "--user": user = iterator.next()
            case "--console": console = iterator.next()
            case "--route": route = iterator.next()
            case "--port": port = iterator.next().flatMap(Int.init)
            case "--out": outDir = iterator.next().map { URL(fileURLWithPath: $0, isDirectory: true) }
            default: break
            }
        }
    }
}
