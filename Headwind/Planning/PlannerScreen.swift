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
                if !plan.summary.legs.isEmpty {
                    Section {
                        PlanHeroCard(summary: plan.summary, fuelCheck: plan.fuelCheck, route: plan.routeString)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

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

                    if plan.waypoints.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(.tint)
                            Text("Plan your first flight")
                                .font(.headline)
                            Text("Type airport or VOR identifiers above — Headwind computes magnetic headings, winds, time, and fuel per leg.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try a Bay Tour · KPAO KSFO KOAK KSJC") {
                                routeInput = "KPAO KSFO KOAK KSJC"
                                applyRoute()
                            }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }

                    ForEach(Array(plan.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.purple.gradient, in: .circle)
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
                    LabeledContent("Fuel on board") {
                        HStack {
                            TextField("gal", value: $plan.fuelOnBoardGal, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("gal").foregroundStyle(.secondary)
                        }
                    }
                    Picker("Reserve", selection: $plan.reserveMinutes) {
                        Text("30 min").tag(30.0)
                        Text("45 min").tag(45.0)
                        Text("60 min").tag(60.0)
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
                            LegRow(leg: leg, wind: plan.windUsed(for: leg))
                        }
                    } header: {
                        Text("Legs")
                    } footer: {
                        Text("Headings are **magnetic** (WMM-2025 at each leg midpoint). Arrows show the wind each leg was solved with.")
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
        // Re-validate after suspension: the route can be cleared (and this
        // task cancelled) while the airport DB is still decoding.
        guard !Task.isCancelled,
              let first = plan.waypoints.first,
              let last = plan.waypoints.last,
              plan.waypoints.count >= 2 else { return }

        let mid = NavMath.midpoint(first.coordinate, last.coordinate)
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
    let wind: (directionFromDeg: Double, speedKts: Double)?

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
        let heading = leg.trueHeadingDeg ?? leg.trueCourseDeg
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(String(format: "%03d°", Int(WMM.magneticFromTrue(heading, declinationDeg: dec).rounded())))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(leg.trueHeadingDeg != nil ? "FLY MH" : "MC")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            .frame(width: 62, height: 52)
            .background(Color.purple.opacity(0.12), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(leg.from.ident) → \(leg.to.ident)")
                        .font(.subheadline.weight(.semibold))
                        .monospaced()
                    Spacer()
                    Text("\(Int(leg.distanceNM.rounded())) NM")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let gs = leg.groundSpeedKts {
                        MetricChip(label: "GS KT", value: "\(Int(gs.rounded()))")
                    }
                    if let ete = leg.eteMinutes {
                        MetricChip(label: "ETE", value: formatMinutes(ete))
                    }
                    if let fuel = leg.fuelGal {
                        MetricChip(label: "GAL", value: String(format: "%.1f", fuel))
                    }
                    Spacer()
                    if let wind {
                        WindArrow(directionFromDeg: wind.directionFromDeg, speedKts: wind.speedKts, size: 26)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// The plan's headline: route flow, the three numbers that matter, and a
/// fuel-margin gauge.
private struct PlanHeroCard: View {
    let summary: PlanSummary
    let fuelCheck: FuelCheck?
    let route: String

    var body: some View {
        VStack(spacing: 16) {
            Text(route.replacingOccurrences(of: " ", with: "  →  "))
                .font(.footnote.weight(.bold))
                .monospaced()
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                HeroStat(value: "\(Int(summary.totalDistanceNM.rounded()))", unit: "NM", label: "Distance")
                if let ete = summary.totalEteMinutes {
                    HeroStat(value: formatMinutes(ete), unit: "", label: "En Route")
                }
                if let fuel = summary.totalFuelGal {
                    HeroStat(
                        value: String(format: "%.1f", fuel),
                        unit: "GAL",
                        label: "Trip Fuel",
                        tint: fuelCheck.map { $0.isSufficient ? .primary : Color.red } ?? .primary
                    )
                }
            }

            if let check = fuelCheck {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let fraction = min(1, max(0, check.totalRequiredGal / max(check.onboardGal, 0.1)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(.secondary.opacity(0.15))
                            Capsule()
                                .fill((check.isSufficient ? Color.green : Color.red).gradient)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Label(
                            check.isSufficient
                                ? "Lands with +\(String(format: "%.1f", check.marginGal)) gal beyond reserve"
                                : "SHORT \(String(format: "%.1f", abs(check.marginGal))) gal — add fuel or a stop",
                            systemImage: check.isSufficient ? "fuelpump.fill" : "exclamationmark.octagon.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(check.isSufficient ? .green : .red)
                        Spacer()
                        Text("\(Int(check.onboardGal.rounded())) gal aboard")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .hwGlassCard()
    }
}

func formatMinutes(_ minutes: Double) -> String {
    let total = Int(minutes.rounded())
    return total >= 60 ? "\(total / 60)h \(total % 60)m" : "\(total)m"
}
