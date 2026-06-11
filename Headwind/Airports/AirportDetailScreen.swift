import SwiftUI
import HeadwindCore

struct AirportDetailScreen: View {
    let airport: Airport

    @Environment(WeatherService.self) private var weather
    @Environment(PlanStore.self) private var plan

    @State private var addedToRoute = false

    private var metar: Metar? { weather.metar(for: airport.icao) }

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Weather") {
                if let metar {
                    MetarSummaryRows(metar: metar)
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
                if let taf = weather.taf(for: airport.icao) {
                    DisclosureGroup("TAF") {
                        Text(taf)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Airport") {
                LabeledContent("Elevation", value: "\(airport.elevationFt) ft MSL")
                LabeledContent("Coordinates", value: String(
                    format: "%.4f, %.4f",
                    airport.coordinate.latitude,
                    airport.coordinate.longitude
                ))
                if let iata = airport.iata {
                    LabeledContent("IATA", value: iata)
                }
            }

            if !airport.runways.isEmpty {
                Section("Runways") {
                    ForEach(airport.runways) { runway in
                        LabeledContent(runway.ident) {
                            Text("\(runway.lengthFt.formatted()) ft · \(runway.surface)")
                        }
                    }
                }
            }

            if !airport.frequencies.isEmpty {
                Section("Frequencies") {
                    ForEach(airport.frequencies) { freq in
                        LabeledContent(freq.name) {
                            Text(freq.mhz.formatted(.number.precision(.fractionLength(1...3))))
                                .monospacedDigit()
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
        .navigationTitle(airport.icao)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await weather.refreshMetars(for: [airport.icao])
            await weather.refreshTAF(for: airport.icao)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(airport.name)
                    .font(.title2.weight(.bold))
                Spacer()
                if let category = metar?.flightCategory {
                    FlightCategoryBadge(category: category)
                }
            }
            Text("\(airport.city), \(airport.state)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
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
