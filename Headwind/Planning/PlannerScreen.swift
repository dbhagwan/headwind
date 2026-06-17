import SwiftUI
import HeadwindCore

/// Route editor with live leg calculations: distance, wind-corrected heading,
/// ground speed, time, and fuel.
struct PlannerScreen: View {
    @Environment(PlanStore.self) private var plan
    @Environment(AirportStore.self) private var airports

    @State private var routeInput = ""
    @State private var unresolved: [String] = []
    @State private var showUnresolvedAlert = false

    var body: some View {
        @Bindable var plan = plan

        NavigationStack {
            List {
                Section("Route") {
                    HStack {
                        TextField("e.g. KPAO OSI KMRY (airports & VORs)", text: $routeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                            .onSubmit(applyRoute)
                        Button("Set", action: applyRoute)
                            .buttonStyle(.borderedProminent)
                            .disabled(routeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(plan.waypoints) { waypoint in
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.purple)
                            Text(waypoint.ident)
                                .font(.body.weight(.semibold))
                                .monospaced()
                            Text(waypoint.name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .onDelete { plan.remove(atOffsets: $0) }
                    .onMove { plan.move(fromOffsets: $0, toOffset: $1) }
                }

                Section("Performance") {
                    LabeledContent("True airspeed") {
                        HStack {
                            TextField("kt", value: $plan.performance.trueAirspeedKts, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("kt").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Fuel burn") {
                        HStack {
                            TextField("gph", value: $plan.performance.fuelBurnGPH, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("gph").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Wind from") {
                        HStack {
                            TextField("deg", value: $plan.performance.windFromDeg, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("°T").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Wind speed") {
                        HStack {
                            TextField("kt", value: $plan.performance.windSpeedKts, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("kt").foregroundStyle(.secondary)
                        }
                    }
                }

                if !plan.summary.legs.isEmpty {
                    Section {
                        ForEach(plan.summary.legs) { leg in
                            LegRow(leg: leg)
                        }
                    } header: {
                        Text("Legs")
                    } footer: {
                        Text("Courses (TC) and headings (TH) are **true** (°T). Magnetic variation is coming in a later update.")
                    }

                    Section {
                        TotalsCard(summary: plan.summary)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        plan.clear()
                        routeInput = ""
                    }
                    .disabled(plan.waypoints.isEmpty)
                }
            }
            .alert("Unknown identifiers", isPresented: $showUnresolvedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Not in the airport directory: \(unresolved.joined(separator: ", "))")
            }
            .onAppear {
                if routeInput.isEmpty {
                    routeInput = plan.routeString
                }
            }
        }
    }

    private func applyRoute() {
        unresolved = plan.setRoute(routeInput, database: airports.database)
        showUnresolvedAlert = !unresolved.isEmpty
    }
}

private struct LegRow: View {
    let leg: Leg

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(leg.from.ident) → \(leg.to.ident)")
                    .font(.subheadline.weight(.semibold))
                    .monospaced()
                Spacer()
                Text("\(Int(leg.distanceNM.rounded())) NM")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            HStack(spacing: 14) {
                metric("TC", String(format: "%03d°", Int(leg.trueCourseDeg.rounded())))
                if let heading = leg.trueHeadingDeg {
                    metric("TH", String(format: "%03d°", Int(heading.rounded())))
                }
                if let gs = leg.groundSpeedKts {
                    metric("GS", "\(Int(gs.rounded())) kt")
                }
                if let ete = leg.eteMinutes {
                    metric("ETE", formatMinutes(ete))
                }
                if let fuel = leg.fuelGal {
                    metric("Fuel", String(format: "%.1f gal", fuel))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).fontWeight(.semibold)
            Text(value).monospacedDigit()
        }
    }
}

private struct TotalsCard: View {
    let summary: PlanSummary

    var body: some View {
        HStack(spacing: 24) {
            total("Distance", "\(Int(summary.totalDistanceNM.rounded())) NM")
            if let ete = summary.totalEteMinutes {
                total("Time", formatMinutes(ete))
            }
            if let fuel = summary.totalFuelGal {
                total("Fuel", String(format: "%.1f gal", fuel))
            }
        }
        .frame(maxWidth: .infinity)
        .hwGlassCard()
    }

    private func total(_ label: String, _ value: String) -> some View {
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

func formatMinutes(_ minutes: Double) -> String {
    let total = Int(minutes.rounded())
    return total >= 60 ? "\(total / 60)h \(total % 60)m" : "\(total)m"
}
