import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DXSpiderCore

/// Info & Diagnose: the node's vital signs as tiles, plus the read-only query catalogue
/// (``NodeQuery``) behind one picker. Everything here is read-only — no confirmation dialog,
/// and it works in read-only mode.
///
/// The answer stays in its own pane instead of the shared console, because several entries
/// (show/newconfiguration, show/hftable) return hundreds of lines; from there it can be
/// copied or written to a text file.
struct NodeInfoView: View {
    @Bindable var model: ConnectionViewModel
    @State private var selectedID = NodeQuery.clusterStatus.id
    @State private var argument = NodeQuery.clusterStatus.defaultArgument
    @State private var isExporting = false

    /// The picked catalogue entry; falls back to the cluster status if an ID ever goes stale.
    private var selected: NodeQuery {
        NodeQuery.query(id: selectedID) ?? .clusterStatus
    }

    private var canRun: Bool {
        model.isConnected && !model.isQuerying && selected.isValid(argument: argument)
    }

    var body: some View {
        Group {
            if model.isConnected {
                content
            } else {
                NotConnectedView(purpose: "um den Node abzufragen")
            }
        }
        .navigationTitle("Info & Diagnose")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refreshNodeStatus() }
                } label: {
                    Label("Status aktualisieren", systemImage: "arrow.clockwise")
                }
                .disabled(!model.isConnected || model.isRefreshing)
            }
        }
        .task(id: model.isConnected) {
            // Kacheln füllen, sobald die Verbindung steht — auch wenn dieser Bereich schon
            // offen war, bevor verbunden wurde. Danach nur noch auf Wunsch.
            if model.isConnected && model.nodeStatus.isEmpty { await model.refreshNodeStatus() }
        }
        .onChange(of: selectedID) {
            argument = selected.defaultArgument
        }
        .fileExporter(
            isPresented: $isExporting,
            document: PlainTextDocument(text: exportText),
            contentType: .plainText,
            defaultFilename: exportFilename
        ) { _ in }
    }

    /// Ein einziges ScrollView trägt die Ansicht; Kacheln, Abfrage-Leiste und Ausgabe-Kopf
    /// sind sein angehefteter Section-Header und bleiben beim Scrollen stehen.
    ///
    /// Der Umweg ist nötig, weil unter einer macOS-Toolbar nur *scrollender* Inhalt den
    /// korrekten Safe-Area-Abstand bekommt: ein einfacher VStack wird unter die Titelleiste
    /// gezogen (und je höher er ist, desto mehr verschwindet dort), und ein `safeAreaInset`
    /// setzt den Kopf an den Fensterrand statt unter die Toolbar.
    private var content: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    outputText
                } header: {
                    VStack(spacing: 0) {
                        statusTiles
                        Divider()
                        queryBar
                        Divider()
                        outputHeader
                        Divider()
                    }
                    .background(.bar)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: Status-Kacheln

    private var statusTiles: some View {
        HStack(alignment: .top, spacing: 12) {
            tile("Uptime", model.nodeStatus.uptime, "clock", tint: .green)
            tile("User", model.nodeStatus.usersSummary, "person.2", tint: .blue)
            tile("Nodes", model.nodeStatus.nodesSummary, "network", tint: .purple)
            tile("Version", model.nodeStatus.versionSummary, "cpu", tint: .orange,
                 detail: model.nodeStatus.gitVersion,
                 help: model.nodeStatus.versionCaveat)
            tile("Node-Zeit", model.nodeStatus.utcTime, "globe", tint: .teal)
        }
        .padding()
    }

    /// One status tile. `detail` adds a second, quieter line (used for the git origin of
    /// the version), `help` becomes the tooltip explaining a value that needs context.
    private func tile(
        _ title: String,
        _ value: String?,
        _ symbol: String,
        tint: Color,
        detail: String? = nil,
        help: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if help != nil {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(value ?? "—")
                .font(.title3.weight(.semibold))
                .redacted(reason: value == nil && model.isRefreshing ? .placeholder : [])
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 10)
        .help(help ?? "")
    }

    // MARK: Abfrage-Leiste

    private var queryBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Schnellzugriff", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(NodeQuery.favourites) { query in
                    Button(query.title) {
                        selectedID = query.id
                        argument = query.defaultArgument
                        run(query, argument: query.defaultArgument)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .disabled(!model.isConnected || model.isQuerying)
                }
            }

            HStack(spacing: 8) {
                Picker("Abfrage", selection: $selectedID) {
                    ForEach(NodeQuery.Group.allCases) { group in
                        Section(group.title) {
                            ForEach(NodeQuery.queries(in: group)) { query in
                                Text(query.title).tag(query.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: 340)

                if selected.argument != .none {
                    TextField(selected.placeholder, text: $argument)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 190)
                        .onSubmit { if canRun { run(selected, argument: argument) } }
                }

                Button("Abrufen", systemImage: "arrow.down.circle") { run(selected, argument: argument) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRun)

                if model.isQuerying { ProgressView().controlSize(.small) }
                Spacer()
            }

            Text(selected.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PreviewLine(command: .query(selected, argument: argument))
        }
        .padding([.horizontal, .bottom])
    }

    // MARK: Ausgabe

    private var outputHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.lastQueryLine.isEmpty ? "Ausgabe" : model.lastQueryLine)
                    .font(.headline.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if !model.queryOutput.isEmpty {
                    Text("\(lineCount) Zeilen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Group {
                    Button("Kopieren", systemImage: "doc.on.doc", action: copyOutput)
                        .help("Ausgabe kopieren")
                    Button("Sichern …", systemImage: "square.and.arrow.down") { isExporting = true }
                        .help("Ausgabe als Textdatei sichern")
                    Button("Leeren", systemImage: "trash", action: model.clearQueryOutput)
                        .help("Ausgabe leeren")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(model.queryOutput.isEmpty)
            }

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Nur senkrecht scrollend, wie die Konsole im Command Builder: in einem waagrecht
    /// scrollenden ScrollView darf der Inhalt kein `maxWidth: .infinity` fordern, sonst
    /// wird das Layout ungültig und der Text verschwindet — ohne die Angabe wiederum
    /// hängt er mittig statt links oben. Breite Tabellen brechen dadurch um; dafür ist
    /// die Ausgabe immer sichtbar.
    private var outputText: some View {
        Text(model.queryOutput.isEmpty ? "Noch keine Abfrage — oben eine wählen und abrufen." : model.queryOutput)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(model.queryOutput.isEmpty ? .tertiary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }

    // MARK: Helfer

    private var lineCount: Int {
        model.queryOutput.split(whereSeparator: \.isNewline).count
    }

    private func run(_ query: NodeQuery, argument: String) {
        Task { await model.runQuery(query, argument: argument) }
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.queryOutput, forType: .string)
    }

    /// Saved file gets the command line as a header, so an exported log stays self-explanatory.
    private var exportText: String {
        let stamp = Self.timestamp.string(from: Date())
        return "# \(model.lastQueryLine)\n# abgerufen \(stamp)\n\n\(model.queryOutput)\n"
    }

    private var exportFilename: String {
        let slug = model.lastQueryLine
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "dxspider_\(slug.isEmpty ? "ausgabe" : slug)_\(Self.fileStamp.string(from: Date()))"
    }

    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()
}

/// Minimal text document so query output can be written out via the standard save panel.
struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#Preview {
    NodeInfoView(model: ConnectionViewModel())
        .frame(width: 900, height: 620)
}
