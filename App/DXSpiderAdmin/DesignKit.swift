import SwiftUI
import DXSpiderCore

// Gemeinsame UI-Bausteine, damit alle Bereiche gleich aussehen: Modus-Hinweis, Konsole,
// Karten, Leer-Zustände und der Verbindungsstatus. Reine Darstellung — keine Logik.

// MARK: - Navigation

extension EnvironmentValues {
    /// Springt in den Bereich „Verbindung“; gesetzt von `ContentView`.
    @Entry var openConnectionArea: @MainActor @Sendable () -> Void = {}
}

// MARK: - Karte

private struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
            }
    }
}

extension View {
    /// Dezente, abgerundete Fläche für Kacheln und Panels.
    func card(padding: CGFloat = 12) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Modus-Hinweis

/// Einheitlicher Hinweis, ob schreibende Befehle gesperrt oder freigeschaltet sind.
/// Ersetzt die früher pro Ansicht unterschiedlich gestalteten Read-only-Leisten.
struct ModeBanner: View {
    let allowWrites: Bool
    /// Was im Read-only-Modus konkret gesperrt ist, z. B. „Filter können nicht verändert werden“.
    let blocked: String

    @Environment(\.openConnectionArea) private var openConnectionArea

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: allowWrites ? "pencil.circle.fill" : "lock.fill")
                .foregroundStyle(allowWrites ? Color.orange : Color.secondary)
            Text(allowWrites
                 ? "Schreibmodus aktiv — Befehle verändern den Node."
                 : "Read-only — \(blocked).")
                .foregroundStyle(allowWrites ? Color.primary : Color.secondary)
            Spacer(minLength: 8)
            if !allowWrites {
                Button("Freischalten …", action: openConnectionArea)
                    .buttonStyle(.link)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            allowWrites ? AnyShapeStyle(Color.orange.opacity(0.12)) : AnyShapeStyle(.fill.quinary),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

// MARK: - Nicht verbunden

/// Platzhalter für Bereiche, die eine Verbindung brauchen — mit direktem Sprung dorthin.
struct NotConnectedView: View {
    /// Wozu die Verbindung nötig ist, z. B. „um User und Nodes zu laden“.
    let purpose: String

    @Environment(\.openConnectionArea) private var openConnectionArea

    var body: some View {
        ContentUnavailableView {
            Label("Nicht verbunden", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text("Mit dem Node verbinden, \(purpose).")
        } actions: {
            Button("Zur Verbindung", action: openConnectionArea)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Listen

/// Rufzeichen-Zelle für Tabellen: Symbol plus Call in Monospace.
struct CallsignCell: View {
    let callsign: String
    let systemImage: String

    var body: some View {
        Label {
            Text(callsign)
                .font(.body.monospaced().weight(.medium))
                .textSelection(.enabled)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
    }
}

/// Overlay für leere Tabellen: lädt, keine Treffer für die Suche oder schlicht leer.
struct ListPlaceholder: View {
    let isEmpty: Bool
    let isLoading: Bool
    let search: String
    let title: String
    let systemImage: String

    var body: some View {
        if isEmpty {
            if isLoading {
                ProgressView("Lade …")
            } else if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ContentUnavailableView(title, systemImage: systemImage)
            }
        }
    }
}

// MARK: - Verbindungsstatus

extension ConnectionState {
    var tint: Color {
        switch self {
        case .ready, .busy: .green
        case .connecting, .authenticating: .orange
        case .failed: .red
        case .disconnected: .secondary
        }
    }

    var label: String {
        switch self {
        case .disconnected: "Getrennt"
        case .connecting: "Verbinde …"
        case .authenticating: "Anmeldung …"
        case .ready: "Bereit"
        case .busy: "Beschäftigt …"
        case .failed(let reason): "Fehler: \(reason)"
        }
    }
}

/// Farbiger Statuspunkt mit Text; pulsiert, solange die Verbindung aufgebaut wird.
struct StatusBadge: View {
    let state: ConnectionState

    private var isTransient: Bool {
        switch state {
        case .connecting, .authenticating, .busy: true
        default: false
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(state.tint)
                .shadow(color: state.tint.opacity(0.6), radius: 3)
                .symbolEffect(.pulse, isActive: isTransient)
            Text(state.label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

/// Kleine Pille für den Sicherheitsmodus (Read-only / Schreiben).
struct ModePill: View {
    let allowWrites: Bool

    var body: some View {
        Label(allowWrites ? "Schreiben" : "Read-only",
              systemImage: allowWrites ? "pencil" : "lock.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(allowWrites ? Color.orange : Color.secondary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                (allowWrites ? Color.orange : Color.secondary).opacity(0.15),
                in: Capsule()
            )
    }
}

// MARK: - Konsole

/// Die geteilte Konsole (Verbindung, Command Builder, Filter-Editor): Terminal-Fläche mit
/// eingefärbten Zeilen, die automatisch ans Ende scrollt. Optional mit Schnellbefehlen und
/// Eingabezeile.
struct ConsolePane: View {
    @Bindable var model: ConnectionViewModel
    var showsInput = false
    var showsError = true

    private static let quickCommands: [DXCommand] = [.showUsers, .showNodes, .showConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Konsole", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                Button("Leeren", systemImage: "trash", action: model.clearConsole)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Konsole leeren")
                    .disabled(model.consoleLog.isEmpty)
            }

            VStack(spacing: 0) {
                output
                if showsInput {
                    Divider()
                    inputLine
                }
            }
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }

            if showsInput {
                HStack(spacing: 6) {
                    ForEach(Self.quickCommands, id: \.line) { command in
                        Button(command.line) { Task { await model.send(command) } }
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .font(.caption.monospaced())
                .disabled(!model.isConnected)
            }

            if showsError, let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    private var output: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.consoleLog.isEmpty {
                        Text("Noch keine Ausgabe.")
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(Self.styled(model.consoleLog))
                            .textSelection(.enabled)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: model.consoleLog) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
            }
        }
    }

    private var inputLine: some View {
        HStack(spacing: 8) {
            Text("›")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(.tint)
            TextField("Befehl eingeben …", text: $model.commandText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .onSubmit { Task { await model.sendTypedCommand() } }
            Button("Senden", systemImage: "arrow.up.circle.fill") {
                Task { await model.sendTypedCommand() }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .font(.title3)
            .disabled(model.commandText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .disabled(!model.isConnected)
    }

    private static let bottomID = "console-bottom"

    /// Färbt die Konsolenzeilen nach ihrer Herkunft: gesendete Befehle (`> …`) in der
    /// Akzentfarbe, Fehler rot, Sperren orange, Erfolg grün, Rest neutral. Ein einziger
    /// Text, damit sich über mehrere Zeilen hinweg markieren und kopieren lässt.
    static func styled(_ log: String) -> AttributedString {
        var result = AttributedString()
        let lines = log.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            var part = AttributedString(String(line) + (index < lines.count - 1 ? "\n" : ""))
            if line.hasPrefix("> ") {
                part.foregroundColor = .accentColor
                part.inlinePresentationIntent = .stronglyEmphasized
            } else if line.hasPrefix("⛔️") {
                part.foregroundColor = .red
            } else if line.hasPrefix("🔒") {
                part.foregroundColor = .orange
            } else if line.hasPrefix("✅") {
                part.foregroundColor = .green
            } else if line == "Verbindung getrennt." {
                part.foregroundColor = .secondary
            }
            result += part
        }
        return result
    }
}

// MARK: - Befehlsvorschau

/// Dry-run-Vorschau der exakten Zeile, die ein Bedienelement senden wird (Konzeptdokument §2).
struct PreviewLine: View {
    let command: DXCommand?

    var body: some View {
        if let command {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
                Text(command.line)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.caption.monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .help("Sendet: \(command.line)")
        }
    }
}
