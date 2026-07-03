import SwiftUI
import HeadwindCore

/// Route editor with live leg calculations: distance, wind-corrected heading,
/// ground speed, time, and fuel.
struct PlannerScreen: View {
    @Environment(PlanStore.self) private var plan
    @Environment(AirportStore.self) private var airports
    @Environment(WeatherService.self) private var weather

    @State private var routeInput = ""
    @State private var unresolved: [String] = []
    @State private var showUnresolvedAlert = false

    /// FB low-level forecast regions and rough centers, for picking the
    /// product that covers the route.
    private static let fbRegions: [(code: String, center: Coordinate)] = [
        ("sfo", Coordinate(latitude: 37.6, longitude: -122.4)),
        ("slc", Coordinate(latitude: 40.8, longitude: -111.9)),
        ("dfw", Coordinate(latitude: 32.9, longitude: -97.0)),
        ("chi", Coordinate(latitude: 41.9, longitude: -87.9)),
        ("bos", Coordinate(latitude: 42.4, longitude: -71.0)),
        ("mia", Coordinate(latitude: 25.8, longitude: -80.3)),
    ]

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

                Section {
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
                    LabeledContent("Cruise altitude") {
                        HStack {
                            TextField("ft", value: $plan.cruiseAltitudeFt, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("ft").foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Winds aloft (auto)", isOn: $plan.useWindsAloft)
                    if !plan.useWindsAloft {
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
                } header: {
                    Text("Performance")
                } footer: {
                    if plan.useWindsAloft {
                        Text(plan.aloftStations.isEmpty
                             ? "Fetching NWS winds-aloft forecast…"
                             : "Each leg uses the NWS FB forecast interpolated at its midpoint and \(plan.cruiseAltitudeFt.formatted()) ft.")
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
                        Text("Courses (MC) and headings (MH) are **magnetic**, using WMM-2025 variation at each leg's midpoint.")
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
            .task(id: "\(plan.useWindsAloft)-\(plan.routeString)") {
                await refreshWindsAloft()
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

    /// Fetches the FB forecast for the region covering the route and
    /// resolves station coordinates through the airport/navaid directory.
    private func refreshWindsAloft() async {
        guard plan.useWindsAloft, plan.waypoints.count >= 2 else { return }
        await airports.load()

        let mid = NavMath.midpoint(
            plan.waypoints.first!.coordinate,
            plan.waypoints.last!.coordinate
        )
        let region = Self.fbRegions.min {
            NavMath.distanceNM(from: mid, to: $0.center) < NavMath.distanceNM(from: mid, to: $1.center)
        }!.code

        guard let parsed = try? await weather.windsAloft(region: region, forecastHours: "06") else { return }

        plan.aloftStations = parsed.compactMap { station in
            let code = station.station.uppercased()
            let coordinate = airports.database.navaid(ident: code)?.coordinate
                ?? airports.database.airport(ident: "K\(code)")?.coordinate
                ?? airports.database.airport(ident: code)?.coordinate
            return coordinate.map {
                StationWinds(station: code, coordinate: $0, winds: station.winds)
            }
        }
    }
}

private struct LegRow: View {
    let leg: Leg

    /// WMM declination at the leg midpoint, so long legs across changing
    /// variation stay honest.
    private var declination: Double {
        WMM.declination(
            at: NavMath.midpoint(leg.from.coordinate, leg.to.coordinate),
            decimalYear: Date.now.decimalYear
        )
    }

    var body: some View {
        let dec = declination
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
                metric("MC", String(format: "%03d°", Int(WMM.magneticFromTrue(leg.trueCourseDeg, declinationDeg: dec).rounded())))
                if let heading = leg.trueHeadingDeg {
                    metric("MH", String(format: "%03d°", Int(WMM.magneticFromTrue(heading, declinationDeg: dec).rounded())))
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
