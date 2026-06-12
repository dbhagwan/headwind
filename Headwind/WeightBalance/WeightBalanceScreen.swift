import SwiftUI
import Charts
import HeadwindCore

/// Interactive weight & balance with a live CG envelope chart.
struct WeightBalanceScreen: View {
    @State private var profile = SampleAircraft.cessna172S
    @State private var stationWeights: [String: Double]

    init() {
        let profile = SampleAircraft.cessna172S
        _stationWeights = State(initialValue: Dictionary(
            uniqueKeysWithValues: profile.stations.map { ($0.name, $0.defaultWeightLb) }
        ))
    }

    private var result: WBResult {
        WeightBalanceCalculator.evaluate(profile: profile, stationWeights: stationWeights)
    }

    var body: some View {
        List {
            Section {
                envelopeChart
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                resultCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Aircraft") {
                Picker("Profile", selection: $profile) {
                    ForEach(SampleAircraft.all) { aircraft in
                        Text(aircraft.name).tag(aircraft)
                    }
                }
                LabeledContent("Max takeoff", value: "\(Int(profile.maxTakeoffWeightLb)) lb")
            }

            Section("Loading") {
                ForEach(profile.stations) { station in
                    StationSlider(
                        station: station,
                        weight: binding(for: station)
                    )
                }
            }

            Section {
                Text("Sample profiles for demonstration. Always compute weight and balance from your aircraft's POH data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Weight & Balance")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profile) {
            stationWeights = Dictionary(
                uniqueKeysWithValues: profile.stations.map { ($0.name, $0.defaultWeightLb) }
            )
        }
    }

    private func binding(for station: WBStation) -> Binding<Double> {
        Binding(
            get: { stationWeights[station.name] ?? 0 },
            set: { stationWeights[station.name] = $0 }
        )
    }

    private var envelopeChart: some View {
        // Close the polygon for drawing.
        let boundary = profile.envelope + [profile.envelope[0]]

        return Chart {
            ForEach(Array(boundary.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("CG (in)", point.cgIn),
                    y: .value("Weight (lb)", point.weightLb)
                )
                .foregroundStyle(.blue.opacity(0.7))
            }

            PointMark(
                x: .value("CG (in)", result.cgIn),
                y: .value("Weight (lb)", result.totalWeightLb)
            )
            .foregroundStyle(result.isSafe ? .green : .red)
            .symbolSize(180)
        }
        .chartXAxisLabel("Center of Gravity (in aft of datum)")
        .chartYAxisLabel("Weight (lb)")
        .frame(height: 260)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var resultCard: some View {
        HStack(spacing: 24) {
            resultItem("Weight", "\(Int(result.totalWeightLb.rounded())) lb")
            resultItem("CG", String(format: "%.1f in", result.cgIn))
            VStack(spacing: 4) {
                Text("Status")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Label(
                    result.isSafe ? "Within limits" : (result.isOverMaxWeight ? "Over gross" : "Out of CG"),
                    systemImage: result.isSafe ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(result.isSafe ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
        .hwGlassCard()
    }

    private func resultItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }
}

private struct StationSlider: View {
    let station: WBStation
    @Binding var weight: Double

    private var maxWeight: Double { station.maxWeightLb ?? 500 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(station.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(weight.rounded())) lb")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $weight, in: 0...maxWeight, step: 5)
            Text("Arm \(station.armIn.formatted()) in" + (station.maxWeightLb.map { " · max \(Int($0)) lb" } ?? ""))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
