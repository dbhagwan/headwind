import Foundation
import Observation
import HeadwindCore

/// The active flight plan: route waypoints plus cruise performance, with
/// lightweight persistence across launches.
@MainActor
@Observable
final class PlanStore {
    var waypoints: [Waypoint] {
        didSet { persist() }
    }

    var performance: CruisePerformance {
        didSet { persist() }
    }

    var summary: PlanSummary {
        LegCalculator.plan(waypoints: waypoints, performance: performance)
    }

    var routeString: String {
        waypoints.map(\.ident).joined(separator: " ")
    }

    private static let waypointsKey = "plan.waypoints"
    private static let performanceKey = "plan.performance"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.waypointsKey),
           let saved = try? JSONDecoder().decode([Waypoint].self, from: data) {
            waypoints = saved
        } else {
            waypoints = []
        }
        if let data = defaults.data(forKey: Self.performanceKey),
           let saved = try? JSONDecoder().decode(CruisePerformance.self, from: data) {
            performance = saved
        } else {
            performance = CruisePerformance(trueAirspeedKts: 110, fuelBurnGPH: 9)
        }
    }

    /// Replaces the route from a space/comma-separated string of identifiers.
    /// - Returns: identifiers that could not be resolved to an airport.
    @discardableResult
    func setRoute(_ route: String, database: AirportDatabase) -> [String] {
        let idents = route
            .uppercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,\n"))
            .filter { !$0.isEmpty }

        var resolved: [Waypoint] = []
        var unresolved: [String] = []

        for ident in idents {
            if let airport = database.airport(ident: ident) {
                resolved.append(Waypoint(airport: airport))
            } else {
                unresolved.append(ident)
            }
        }

        if !resolved.isEmpty || idents.isEmpty {
            waypoints = resolved
        }
        return unresolved
    }

    func append(airport: Airport) {
        guard waypoints.last?.ident != airport.icao else { return }
        waypoints.append(Waypoint(airport: airport))
    }

    func remove(atOffsets offsets: IndexSet) {
        waypoints.remove(atOffsets: offsets)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        waypoints.move(fromOffsets: source, toOffset: destination)
    }

    func clear() {
        waypoints = []
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(waypoints) {
            defaults.set(data, forKey: Self.waypointsKey)
        }
        if let data = try? JSONEncoder().encode(performance) {
            defaults.set(data, forKey: Self.performanceKey)
        }
    }
}
