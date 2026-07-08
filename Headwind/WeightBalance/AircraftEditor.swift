import SwiftUI
import SwiftData

/// Create a pilot-defined aircraft profile. Values must come from the
/// aircraft's own POH/weighing record — the form says so.
///
/// Creation-only by design: editing a persisted @Model through live
/// bindings makes Cancel a lie under SwiftData autosave. An edit flow
/// needs draft-copy semantics; until it has them, it doesn't exist.
struct AircraftEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var aircraft = UserAircraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("Aircraft") {
                    TextField("Name (e.g. N737HW · C172S)", text: $aircraft.name)
                    numberField("Empty weight", $aircraft.emptyWeightLb, "lb")
                    numberField("Empty CG arm", $aircraft.emptyArmIn, "in")
                    numberField("Max takeoff weight", $aircraft.maxTakeoffWeightLb, "lb")
                    numberField("Usable fuel", $aircraft.fuelCapacityGal, "gal")
                }

                Section {
                    numberField("Forward CG limit", $aircraft.forwardCGIn, "in")
                    numberField("Aft CG limit", $aircraft.aftCGIn, "in")
                } header: {
                    Text("CG Envelope")
                } footer: {
                    Text("v1 models the envelope as forward/aft limits across the weight range. Use the most restrictive values from the POH.")
                }

                Section("Loading Stations") {
                    ForEach($aircraft.stations) { $station in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Station name", text: $station.name)
                                .font(.subheadline.weight(.medium))
                            HStack {
                                numberField("Arm", $station.armIn, "in")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { aircraft.stations.remove(atOffsets: $0) }

                    Button {
                        // Unique default name: duplicates would collide in the
                        // name-keyed loading UI and double-count weight.
                        let existing = Set(aircraft.stations.map(\.name))
                        var candidate = "Station \(aircraft.stations.count + 1)"
                        var n = aircraft.stations.count + 1
                        while existing.contains(candidate) {
                            n += 1
                            candidate = "Station \(n)"
                        }
                        aircraft.stations.append(
                            UserAircraft.StationData(name: candidate, armIn: 40, maxWeightLb: nil, defaultWeightLb: 0)
                        )
                    } label: {
                        Label("Add Station", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    Text("Enter values from your aircraft's POH and current weighing record. Weight & balance is only as accurate as these numbers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(aircraft)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        aircraft.emptyWeightLb > 0
            && aircraft.maxTakeoffWeightLb > aircraft.emptyWeightLb
            && aircraft.aftCGIn > aircraft.forwardCGIn
            && !aircraft.stations.isEmpty
    }

    private func numberField(_ label: String, _ value: Binding<Double>, _ unit: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}
