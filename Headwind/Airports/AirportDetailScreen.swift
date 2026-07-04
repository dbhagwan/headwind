import SwiftUI
import HeadwindCore

struct AirportDetailScreen: View {
    let airport: Airport

    @Environment(WeatherService.self) private var weather
    @Environment(PlanStore.self) private var plan
    @Environment(PlateStore.self) private var plates

    @State private var addedToRoute = false

    private var metar: Metar? { weather.metar(for: airport.ident) }

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Facility first (identity → runways → conditions): the diagram
            // is the page's signature visual and belongs above the fold.
            if !airport.runways.isEmpty {
                Section("Runways") {
                    if airport.runways.contains(where: { $0.leHeadingDegT != nil }) {
                        HStack {
                            Spacer()
                            RunwayDiagram(
                                runways: airport.runways,
                                windFromDeg: metar?.windDirectionDeg.map(Double.init),
                                windSpeedKts: metar?.windSpeedKts.map(Double.init)
                            )
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(airport.runways) { runway in
                        LabeledContent(runway.ident) {
                            Text("\(runway.lengthFt.formatted()) ft · \(runway.surface)")
                        }
                    }
                }
            }

            if let metar, let dir = metar.windDirectionDeg,
               let speed = metar.windSpeedKts, speed > 0 {
                let ends = RunwayWindCalculator.evaluate(
                    runways: airport.runways,
                    windFromDegT: Double(dir),
                    windSpeedKts: Double(speed)
                )
                if !ends.isEmpty {
                    Section("Runway Winds") {
                        ForEach(Array(ends.enumerated()), id: \.element.id) { index, end in
                            RunwayWindRow(end: end, isBest: index == 0)
                        }
                    }
                }
            }

            Section("Weather") {
                if let metar {
                    MetarSummaryRows(metar: metar)
                    if let temp = metar.temperatureC, let altim = metar.altimeterInHg {
                        LabeledContent("Density altitude") {
                            Text("\(Int(DensityAltitude.densityAltitudeFt(elevationFt: Double(airport.elevationFt), altimeterInHg: altim, temperatureC: temp).rounded()).formatted()) ft")
                                .monospacedDigit()
                        }
                    }
                    if let raw = metar.rawText {
                        Text(raw)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Fetching METAR…")
                            .foregroundStyle(.secondary)
                    }
                }
                if let taf = weather.taf(for: airport.ident) {
                    DisclosureGroup("TAF") {
                        Text(taf)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Airport") {
                LabeledContent("Elevation", value: "\(airport.elevationFt) ft MSL")
                LabeledContent("Mag variation", value: magVariationText)
                LabeledContent("Coordinates", value: String(
                    format: "%.4f, %.4f",
                    airport.coordinate.latitude,
                    airport.coordinate.longitude
                ))
                if let iata = airport.iata {
                    LabeledContent("IATA", value: iata)
                }
            }

            if !airport.frequencies.isEmpty {
                Section("Frequencies") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(airport.frequencies) { freq in
                            VStack(spacing: 2) {
                                Text(freq.mhz.formatted(.number.precision(.fractionLength(1...3))))
                                    .font(.system(.callout, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                Text(freq.name.uppercased())
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 10))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !plates.index.plates(for: airport.ident).isEmpty {
                Section {
                    NavigationLink {
                        PlatesListScreen(airport: airport)
                    } label: {
                        LabeledContent {
                            Text(plates.index.plates(for: airport.ident).count.formatted())
                        } label: {
                            Label("Procedures & Plates", systemImage: "doc.on.doc")
                        }
                    }
                }
            }

            Section {
                Button {
                    plan.append(airport: airport)
                    addedToRoute = true
                } label: {
                    Label(
                        addedToRoute ? "Added to Route" : "Add to Route",
                        systemImage: addedToRoute ? "checkmark.circle.fill" : "plus.circle.fill"
                    )
                }
                .disabled(addedToRoute)
            }
        }
        .navigationTitle(airport.ident)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await plates.load()
            await weather.refreshMetars(for: [airport.ident])
            await weather.refreshTAF(for: airport.ident)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(airport.ident)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .monospaced()
                    Text(airport.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Text("\(airport.city.isEmpty ? airport.state : "\(airport.city), \(airport.state)") · \(kindLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if let category = metar?.flightCategory {
                        FlightCategoryBadge(category: category)
                    }
                    if let dir = metar?.windDirectionDeg, let speed = metar?.windSpeedKts, speed > 0 {
                        WindArrow(directionFromDeg: Double(dir), speedKts: Double(speed), size: 30)
                    }
                }
            }

            HStack(spacing: 8) {
                HeroStat(value: "\(airport.elevationFt)", unit: "FT", label: "Elevation")
                if let metar, let temp = metar.temperatureC, let altim = metar.altimeterInHg {
                    HeroStat(
                        value: "\(Int(DensityAltitude.densityAltitudeFt(elevationFt: Double(airport.elevationFt), altimeterInHg: altim, temperatureC: temp).rounded()))",
                        unit: "FT",
                        label: "Density Alt"
                    )
                }
                if let longest = airport.longestRunwayFt {
                    HeroStat(value: longest.formatted(), unit: "FT", label: "Longest Rwy")
                }
            }
        }
        .hwGlassCard()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var magVariationText: String {
        let dec = WMM.declination(at: airport.coordinate, decimalYear: Date.now.decimalYear)
        return String(format: "%.1f°%@ (WMM-2025)", abs(dec), dec >= 0 ? "E" : "W")
    }

    private var kindLabel: String {
        switch airport.kind {
        case .large: "Large airport"
        case .medium: "Towered/regional"
        case .small: "GA field"
        case .seaplane: "Seaplane base"
        }
    }
}

private struct RunwayWindRow: View {
    let end: RunwayEndWind
    let isBest: Bool

    var body: some View {
        HStack {
            Text("Rwy \(end.endIdent)")
                .font(.subheadline.weight(isBest ? .bold : .regular))
                .monospaced()
            if isBest {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            Spacer()
            Text(headwindText)
                .foregroundStyle(end.headwindKts >= 0 ? .green : .red)
            Text(crosswindText)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private var headwindText: String {
        let value = Int(abs(end.headwindKts).rounded())
        return end.headwindKts >= 0 ? "↓\(value) kt" : "↑\(value) kt tail"
    }

    private var crosswindText: String {
        let value = Int(abs(end.crosswindKts).rounded())
        guard value > 0 else { return "no x-wind" }
        return "\(end.crosswindKts > 0 ? "→" : "←")\(value) kt x-wind"
    }
}

struct MetarSummaryRows: View {
    let metar: Metar

    var body: some View {
        if let speed = metar.windSpeedKts {
            LabeledContent("Wind") {
                if speed == 0 {
                    Text("Calm")
                } else if metar.windVariable {
                    Text("VRB at \(speed) kt")
                } else if let dir = metar.windDirectionDeg {
                    Text("\(String(format: "%03d", dir))° at \(speed)\(metar.windGustKts.map { "G\($0)" } ?? "") kt")
                }
            }
        }
        if let vis = metar.visibilitySM {
            LabeledContent("Visibility", value: "\(vis.formatted()) SM")
        }
        if let ceiling = metar.ceilingFt {
            LabeledContent("Ceiling", value: "\(ceiling.formatted()) ft")
        }
        if let temp = metar.temperatureC, let dew = metar.dewpointC {
            LabeledContent("Temp / Dew", value: "\(Int(temp.rounded()))° / \(Int(dew.rounded()))°C")
        }
        if let altim = metar.altimeterInHg {
            LabeledContent("Altimeter", value: String(format: "%.2f inHg", altim))
        }
        if let time = metar.observationTime {
            LabeledContent("Observed") {
                Text(time, style: .relative) + Text(" ago")
            }
        }
    }
}
