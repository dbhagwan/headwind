import SwiftUI
import HeadwindCore

/// Favorite stations with live METAR cards.
struct WeatherScreen: View {
    @Environment(WeatherService.self) private var weather
    @Environment(AirportStore.self) private var airports

    @AppStorage("weather.favorites") private var favoritesCSV = "KSFO,KOAK,KSJC,KPAO"
    @State private var newStation = ""

    private var favorites: [String] {
        favoritesCSV.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    addStationField

                    if !suggestions.isEmpty {
                        suggestionList
                    }

                    if weather.isOffline {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                            if let updated = weather.lastUpdated {
                                Text("Offline — last saved ") + Text(updated, style: .relative) + Text(" ago")
                            } else {
                                Text("Offline — showing last saved weather.")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let error = weather.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    ForEach(favorites, id: \.self) { ident in
                        MetarCard(ident: ident) {
                            remove(ident)
                        }
                    }

                    if favorites.isEmpty {
                        ContentUnavailableView(
                            "No Stations",
                            systemImage: "cloud.sun",
                            description: Text("Add an airport identifier to track its weather.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Weather")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let updated = weather.lastUpdated {
                        Text(updated, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable {
                await weather.refreshMetars(for: favorites)
            }
            .task {
                await airports.load()
                await weather.refreshMetars(for: favorites)
            }
        }
    }

    /// Airports matching the partially-typed identifier, minus ones
    /// already tracked.
    private var suggestions: [Airport] {
        let query = newStation.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return [] }
        return airports.search(query)
            .filter { !favorites.contains($0.ident) }
            .prefix(5)
            .map { $0 }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { airport in
                Button {
                    add(airport.ident)
                } label: {
                    HStack {
                        Text(airport.ident)
                            .font(.subheadline.weight(.semibold))
                            .monospaced()
                        Text(airport.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if airport.id != suggestions.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var addStationField: some View {
        HStack {
            TextField("Add station (e.g. KDEN)", text: $newStation)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onSubmit(addStation)
            Button(action: addStation) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .disabled(newStation.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
    }

    private func addStation() {
        add(newStation.trimmingCharacters(in: .whitespaces).uppercased())
    }

    private func add(_ ident: String) {
        guard !ident.isEmpty, !favorites.contains(ident) else { return }
        favoritesCSV = (favorites + [ident]).joined(separator: ",")
        newStation = ""
        Task { await weather.refreshMetars(for: [ident]) }
    }

    private func remove(_ ident: String) {
        favoritesCSV = favorites.filter { $0 != ident }.joined(separator: ",")
    }
}

/// One station's current conditions on a glass card.
struct MetarCard: View {
    let ident: String
    let onRemove: () -> Void

    @Environment(WeatherService.self) private var weather

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ident)
                    .font(.title3.weight(.bold))
                    .monospaced()
                if let metar {
                    FlightCategoryBadge(category: metar.flightCategory)
                    if metar.isStale() {
                        Label {
                            if let observed = metar.observationTime {
                                Text(observed, style: .relative)
                            } else {
                                Text("old")
                            }
                        } icon: {
                            Image(systemName: "clock.badge.exclamationmark")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                    }
                }
                Spacer()
            }

            if let metar {
                if let name = metar.stationName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        if let dir = metar.windDirectionDeg, (metar.windSpeedKts ?? 0) > 0 {
                            WindArrow(directionFromDeg: Double(dir), size: 22)
                        }
                        conditionItem(icon: "wind", text: windText(metar))
                    }
                    if let vis = metar.visibilitySM {
                        conditionItem(icon: "eye", text: "\(vis.formatted()) SM")
                    }
                    if let ceiling = metar.ceilingFt {
                        conditionItem(icon: "cloud", text: "\(ceiling.formatted()) ft")
                    } else {
                        conditionItem(icon: "sun.max", text: "Clear")
                    }
                    if let temp = metar.temperatureC {
                        conditionItem(icon: "thermometer.medium", text: "\(Int(temp.rounded()))°C")
                    }
                }
                .font(.footnote)

                if let raw = metar.rawText {
                    Text(raw)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                }
            } else {
                Text("No data yet — pull to refresh.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .hwGlassCard()
        .overlay(alignment: .leading) {
            if let metar {
                Capsule()
                    .fill(metar.flightCategory.color.gradient)
                    .frame(width: 4)
                    .padding(.vertical, 16)
                    .padding(.leading, 7)
            }
        }
        // Long-press lifts the card and reveals actions — no chrome on
        // the card itself. VoiceOver gets the same action directly.
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove Station", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Remove Station", onRemove)
    }

    private var metar: Metar? { weather.metar(for: ident) }

    private func windText(_ metar: Metar) -> String {
        guard let speed = metar.windSpeedKts, speed > 0 else { return "Calm" }
        if metar.windVariable { return "VRB \(speed) kt" }
        guard let dir = metar.windDirectionDeg else { return "\(speed) kt" }
        let gust = metar.windGustKts.map { "G\($0)" } ?? ""
        return "\(String(format: "%03d", dir))° \(speed)\(gust) kt"
    }

    private func conditionItem(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
    }
}
