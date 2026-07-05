import SwiftUI
import HeadwindCore

/// Structured weather briefing in the standard order — adverse conditions
/// first, then current weather, forecasts, and winds aloft — with an
/// optional grounded AI summary on top. Every number comes from the fetched
/// data; the model only summarizes.
struct BriefingScreen: View {
    @Environment(BriefingService.self) private var briefing
    @Environment(WeatherService.self) private var weather
    @Environment(TFRService.self) private var tfrService
    @Environment(PlanStore.self) private var plan

    @AppStorage("weather.favorites") private var favoritesCSV = "KSFO,KOAK,KSJC,KPAO"
    @State private var briefingText: String?

    private var stations: [String] {
        if plan.waypoints.count >= 2 {
            return plan.waypoints.map(\.ident)
        }
        return favoritesCSV.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    private var routeMetars: [Metar] {
        stations.compactMap { weather.metar(for: $0) }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        plan.waypoints.count >= 2 ? "Route: \(plan.routeString)" : "Favorite stations",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    .font(.subheadline.weight(.semibold))

                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            if briefing.isGenerating {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(briefing.isGenerating ? "Generating…" : "Summarize with \(briefing.engine == .appleIntelligence ? "Apple Intelligence" : "Headwind")")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(briefing.isGenerating || stations.isEmpty)

                    if let briefingText {
                        Text(briefingText)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Adverse Conditions") {
                if weather.airSigmets.isEmpty && tfrService.tfrs.isEmpty {
                    Label("No active SIGMETs, AIRMETs, or TFRs loaded.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(weather.airSigmets.prefix(6)) { hazard in
                        HStack {
                            IconBadge(
                                systemName: "exclamationmark.triangle.fill",
                                tint: hazard.type == "SIGMET" ? .red : .orange
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(hazard.type) — \(hazard.hazard ?? "hazard")")
                                    .font(.subheadline.weight(.semibold))
                                if let hi = hazard.altitudeHiFt {
                                    Text("\(hazard.altitudeLowFt.map { "\($0.formatted())–" } ?? "SFC–")\(hi.formatted()) ft")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if !tfrService.tfrs.isEmpty {
                        NavigationLink {
                            AirspaceScreen()
                        } label: {
                            HStack {
                                IconBadge(systemName: "nosign", tint: .red)
                                Text("\(tfrService.tfrs.count) active TFRs")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
            }

            Section("Current Weather") {
                if routeMetars.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Fetching METARs…").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(routeMetars) { metar in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(metar.stationID)
                                    .font(.subheadline.weight(.bold))
                                    .monospaced()
                                FlightCategoryBadge(category: metar.flightCategory)
                                Spacer()
                                if metar.isStale() {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text(MetarSummarizer.plainEnglish(for: metar))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Forecasts (TAF)") {
                let tafs = stations.compactMap { id in weather.taf(for: id).map { (id, $0) } }
                if tafs.isEmpty {
                    Text("No terminal forecasts for these stations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tafs, id: \.0) { ident, taf in
                        DisclosureGroup(ident) {
                            Text(taf)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if plan.useWindsAloft && !plan.aloftStations.isEmpty && plan.waypoints.count >= 2 {
                Section("Winds Aloft · \(plan.cruiseAltitudeFt.formatted()) ft") {
                    ForEach(plan.summary.legs) { leg in
                        if let wind = plan.windUsed(for: leg) {
                            HStack {
                                Text("\(leg.from.ident) → \(leg.to.ident)")
                                    .font(.subheadline)
                                    .monospaced()
                                Spacer()
                                WindArrow(directionFromDeg: wind.directionFromDeg, size: 24)
                                Text("\(String(format: "%03d", Int(wind.directionFromDeg.rounded())))° @ \(Int(wind.speedKts.rounded())) kt")
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Text("Generated summaries are an aid, not an official weather briefing. Always obtain a regulatory briefing before flight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Briefing")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await weather.refreshMetars(for: stations)
            for station in stations.prefix(4) {
                await weather.refreshTAF(for: station)
            }
            await weather.refreshAirSigmets()
            if tfrService.tfrs.isEmpty {
                await tfrService.refresh()
            }
        }
        .refreshable {
            await weather.refreshMetars(for: stations)
            await weather.refreshAirSigmets()
        }
    }

    private func generate() async {
        await weather.refreshMetars(for: stations)
        let metars = routeMetars
        guard !metars.isEmpty else {
            briefingText = "No weather observations available for \(stations.joined(separator: ", ")). Check the identifiers and your connection."
            return
        }
        briefingText = await briefing.briefing(
            for: metars,
            routeDescription: plan.waypoints.count >= 2 ? plan.routeString : nil
        )
    }
}
