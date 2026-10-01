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
                    editor
                        .frame(minWidth: 360, idealWidth: 420, maxWidth: 500)
                    ConsolePane(model: model)
                        .frame(minWidth: 360)
                        .padding()
                }
            } else {
                NotConnectedView(purpose: "um Filter zu setzen")
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

    // MARK: Editor

    private var editor: some View {
        VStack(spacing: 0) {
            ModeBanner(allowWrites: model.allowWrites, blocked: "Filter können nicht verändert werden")
                .padding([.horizontal, .top])

            Form {
                Section("Regel") {
                    Picker("Aktion", selection: $action) {
                        ForEach(SpotFilter.Action.allCases) { action in
                            Label(action == .accept ? "Accept" : "Reject",
                                  systemImage: action == .accept ? "checkmark.circle" : "xmark.circle")
                                .tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $slot, in: 0...9) {
                        LabeledContent("Slot") {
                            Text("\(slot)").font(.body.monospacedDigit().weight(.semibold))
                        }
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(SpotFilter.Band.allCases) { band in
                            BandChip(title: band.displayName, isOn: Binding(
                                get: { bands.contains(band) },
                                set: { isOn in
                                    if isOn { bands.insert(band) } else { bands.remove(band) }
                                }
                            ))
                        }
                        Spacer()
                    }
                } header: {
                    Text("Bänder")
                } footer: {
                    Text("Keine Auswahl = alle Bänder.")
                }

                Section {
                    TextField("Spotter (by)", text: $spotterText, prompt: Text("DL1ABC, HB9XYZ"))
                    TextField("Origin (Node)", text: $originText, prompt: Text("HB9HJI-2"))
                } header: {
                    Text("Stationen")
                } footer: {
                    Text("Optional, mehrere Rufzeichen mit Komma trennen.")
                }

                Section("Vorschau") {
                    if let command = filter.command {
                        PreviewLine(command: command)
                    } else {
                        Text("Keine Kriterien gewählt.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(action == .accept ? "Accept anwenden" : "Reject anwenden",
                               systemImage: "line.3.horizontal.decrease.circle.fill") {
                            if let command = filter.command { pending = command }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.allowWrites || filter.command == nil)

                        Button("Slot \(slot) leeren", systemImage: "eraser", role: .destructive) {
                            pending = filter.clearCommand
                        }
                        .disabled(!model.allowWrites)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

/// Umschaltbarer Chip für ein Band (HF/VHF/UHF).
private struct BandChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Label(title, systemImage: isOn ? "checkmark" : "plus")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary),
                            in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.15), value: isOn)
    }
}

#Preview {
    FilterEditorView(model: ConnectionViewModel())
        .frame(width: 820, height: 560)
}
