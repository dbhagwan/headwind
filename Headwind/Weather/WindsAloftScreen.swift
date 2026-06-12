import SwiftUI
import HeadwindCore

/// Viewer for the NWS FB winds-and-temperatures-aloft forecast.
struct WindsAloftScreen: View {
    @Environment(WeatherService.self) private var weather

    private static let regions: [(code: String, name: String)] = [
        ("sfo", "West Coast"), ("slc", "Mountain"), ("dfw", "South Central"),
        ("chi", "Midwest"), ("bos", "Northeast"), ("mia", "Southeast"),
    ]

    @State private var region = "sfo"
    @State private var forecast = "06"
    @State private var stations: [WindsAloftStation] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                Picker("Region", selection: $region) {
                    ForEach(Self.regions, id: \.code) { r in
                        Text(r.name).tag(r.code)
                    }
                }
                Picker("Forecast", selection: $forecast) {
                    Text("6 hr").tag("06")
                    Text("12 hr").tag("12")
                    Text("24 hr").tag("24")
                }
                .pickerStyle(.segmented)
            }

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Fetching winds aloft…").foregroundStyle(.secondary)
                    }
                }
            } else if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } else {
                ForEach(stations) { station in
                    Section(station.station) {
                        ForEach(station.winds, id: \.altitudeFt) { wind in
                            WindAloftRow(wind: wind)
                        }
                    }
                }
            }
        }
        .navigationTitle("Winds Aloft")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: region + forecast) {
            await fetch()
        }
        .refreshable {
            await fetch()
        }
    }

    private func fetch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await weather.windsAloft(region: region, forecastHours: forecast)
            errorText = stations.isEmpty ? "No data returned for this region." : nil
        } catch {
            errorText = "Couldn't load winds aloft: \(error.localizedDescription)"
        }
    }
}

private struct WindAloftRow: View {
    let wind: WindAloft

    var body: some View {
        HStack {
            Text("\(wind.altitudeFt.formatted()) ft")
                .foregroundStyle(.secondary)
            Spacer()
            if wind.isLightAndVariable {
                Text("Light & variable")
            } else if let dir = wind.directionDeg, let speed = wind.speedKts {
                Text("\(String(format: "%03d", dir))° @ \(speed) kt")
            }
            if let temp = wind.temperatureC {
                Text("\(temp)°C")
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 48, alignment: .trailing)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }
}
