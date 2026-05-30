import SwiftUI
import DXSpiderCore

/// Visueller Filter-Editor (Konzeptdokument §6, M4): Accept/Reject-Baukasten mit Band-
/// Checkboxen und Origin-/Spotter-Feldern. Der erzeugte Befehl wird live als Vorschau
/// angezeigt (§2); Anwenden/Leeren sind destruktiv (Schreibmodus + Bestätigung).
struct FilterEditorView: View {
    @Bindable var model: ConnectionViewModel

    @State private var action: SpotFilter.Action = .accept
    @State private var slot = 0
    @State private var bands: Set<SpotFilter.Band> = []
    @State private var spotterText = ""
    @State private var originText = ""
    @State private var pending: DXCommand?

    private var filter: SpotFilter {
        SpotFilter(
            action: action,
            slot: slot,
            bands: SpotFilter.Band.allCases.filter { bands.contains($0) },
            spotterCalls: SpotFilter.tokens(from: spotterText),
            originCalls: SpotFilter.tokens(from: originText)
        )
    }

    var body: some View {
        Group {
            if model.isConnected {
                HSplitView {
                    form
                        .frame(minWidth: 340, idealWidth: 390, maxWidth: 470)
                    console
                        .frame(minWidth: 360)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    "Nicht verbunden",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Im Bereich „Verbindung“ verbinden, um Filter zu setzen.")
                )
            }
        }
        .navigationTitle("Filter-Editor")
        .confirmationDialog(
            "Filter anwenden?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { command in
            Button("Senden", role: .destructive) {
                Task { await model.send(command); pending = nil }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { command in
            Text("Sendet „\(command.line)“ — verändert die Spot-Filter des Nodes.")
        }
    }

    // MARK: Form

    private var form: some View {
        Form {
            if !model.allowWrites {
                Section {
                    Label("Read-only — Filter können nicht verändert werden.", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Regel") {
                Picker("Aktion", selection: $action) {
                    ForEach(SpotFilter.Action.allCases) { action in
                        Text(action == .accept ? "Accept" : "Reject").tag(action)
                    }
                }
                .pickerStyle(.segmented)
                Stepper("Slot: \(slot)", value: $slot, in: 0...9)
            }

            Section("Bänder") {
                ForEach(SpotFilter.Band.allCases) { band in
                    Toggle(band.displayName, isOn: Binding(
                        get: { bands.contains(band) },
                        set: { isOn in
                            if isOn { bands.insert(band) } else { bands.remove(band) }
                        }
                    ))
                }
            }

            Section("Stationen (optional, kommagetrennt)") {
                TextField("Spotter (by)", text: $spotterText)
                    .textFieldStyle(.roundedBorder)
                TextField("Origin (Node)", text: $originText)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Vorschau") {
                if let line = filter.command?.line {
                    Label("Sendet: \(line)", systemImage: "arrow.right.circle")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("Keine Kriterien gewählt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(action == .accept ? "Accept anwenden" : "Reject anwenden") {
                    if let command = filter.command { pending = command }
                }
                .disabled(!model.allowWrites || filter.command == nil)

                Button("Slot \(slot) leeren", role: .destructive) {
                    pending = filter.clearCommand
                }
                .disabled(!model.allowWrites)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Console

    private var console: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Konsole").font(.headline)
                Spacer()
                Button("Leeren", action: model.clearConsole)
                    .controlSize(.small)
                    .disabled(model.consoleLog.isEmpty)
            }
            ScrollView {
                Text(model.consoleLog.isEmpty ? "—" : model.consoleLog)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: .infinity)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }
}

#Preview {
    FilterEditorView(model: ConnectionViewModel())
        .frame(width: 820, height: 560)
}
