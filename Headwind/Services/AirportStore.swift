import Foundation
import Observation
import HeadwindCore

/// Loads the bundled FAA/OurAirports dataset (all open US airports plus
/// navaids) and exposes search, lookup, and map-region queries.
///
/// The ~6 MB JSON decode happens off the main actor; screens observe
/// `isLoading` and update when the directory lands.
@MainActor
@Observable
final class AirportStore {
    private(set) var database = AirportDatabase(airports: [], navaids: [])
    private(set) var isLoading = true
    private var loadTask: Task<Void, Never>?

    var airportCount: Int { database.airports.count }
    var navaidCount: Int { database.navaids.count }

    /// Idempotent: multiple screens can await this; the decode runs once.
    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
    }

    private func performLoad() async {
        let db = await Task.detached(priority: .userInitiated) { () -> AirportDatabase in
            func decode<T: Decodable>(_ resource: String, as type: [T].Type) -> [T] {
                guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let decoded = try? JSONDecoder().decode([T].self, from: data) else {
                    assertionFailure("Bundled \(resource).json missing or malformed")
                    return []
                }
                return decoded
            }
            return AirportDatabase(
                airports: decode("us-airports", as: [Airport].self),
                navaids: decode("us-navaids", as: [Navaid].self)
            )
        }.value

        database = db
        isLoading = false
    }

    func airport(ident: String) -> Airport? { database.airport(ident: ident) }
    func search(_ query: String) -> [Airport] { database.search(query) }
    func nearest(to coordinate: Coordinate, limit: Int = 10) -> [Airport] {
        database.nearest(to: coordinate, limit: limit)
    }
}
