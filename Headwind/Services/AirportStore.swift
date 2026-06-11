import Foundation
import Observation
import HeadwindCore

/// Loads the bundled airport directory and exposes search/lookup.
///
/// v0.1 ships a curated sample dataset; the roadmap replaces this with the
/// full FAA NASR / OurAirports import pipeline.
@MainActor
@Observable
final class AirportStore {
    private(set) var database: AirportDatabase

    var airports: [Airport] { database.airports }

    init() {
        if let url = Bundle.main.url(forResource: "airports", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let airports = try? JSONDecoder().decode([Airport].self, from: data) {
            database = AirportDatabase(airports: airports)
        } else {
            assertionFailure("Bundled airports.json missing or malformed")
            database = AirportDatabase(airports: [])
        }
    }

    func airport(ident: String) -> Airport? { database.airport(ident: ident) }
    func search(_ query: String) -> [Airport] { database.search(query) }
    func nearest(to coordinate: Coordinate, limit: Int = 10) -> [Airport] {
        database.nearest(to: coordinate, limit: limit)
    }
}
