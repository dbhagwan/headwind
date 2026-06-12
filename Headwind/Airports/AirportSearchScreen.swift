import SwiftUI
import HeadwindCore

struct AirportSearchScreen: View {
    @Environment(AirportStore.self) private var airports
    @Environment(LocationService.self) private var location

    @State private var query = ""

    private var results: [Airport] {
        if query.isEmpty, let coordinate = location.coordinate {
            return airports.nearest(to: Coordinate(coordinate), limit: 15)
        }
        return airports.search(query)
    }

    var body: some View {
        NavigationStack {
            List(results) { airport in
                NavigationLink(value: airport) {
                    AirportRow(airport: airport)
                }
            }
            .navigationTitle("Airports")
            .navigationDestination(for: Airport.self) { airport in
                AirportDetailScreen(airport: airport)
            }
            .searchable(text: $query, prompt: "Identifier, name, or city")
            .overlay {
                if airports.isLoading {
                    ProgressView("Loading airport directory…")
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }
}

struct AirportRow: View {
    let airport: Airport
    @Environment(WeatherService.self) private var weather

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(airport.ident)
                        .font(.headline)
                        .monospaced()
                    if let category = weather.metar(for: airport.ident)?.flightCategory {
                        FlightCategoryBadge(category: category)
                    }
                }
                Text(airport.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(airport.city), \(airport.state)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
