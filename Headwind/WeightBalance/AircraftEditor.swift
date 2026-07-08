import SwiftUI
import SwiftData

/// Create or edit a pilot-defined aircraft profile. Values must come from
/// the aircraft's own POH/weighing record — the form says so.
struct AircraftEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var aircraft: UserAircraft
    private let isNew: Bool

    init(aircraft: UserAircraft? = nil) {
        _aircraft = State(initialValue: aircraft ?? UserAircraft())
        isNew = aircraft == nil
    }

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
                    ForEach($aircraft.stations, id: \.self) { $station in
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
                        aircraft.stations.append(
                            UserAircraft.StationData(name: "Station", armIn: 40, maxWeightLb: nil, defaultWeightLb: 0)
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
            .navigationTitle(isNew ? "New Aircraft" : "Edit Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isNew {
                            context.insert(aircraft)
                        }
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
