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

    var cruiseAltitudeFt: Int {
        didSet { persist() }
    }

    /// When true and stations are loaded, each leg uses winds interpolated
    /// from the NWS FB forecast at its midpoint instead of the manual wind.
    var useWindsAloft: Bool {
        didSet { persist() }
    }

    var fuelOnBoardGal: Double {
        didSet { persist() }
    }

    /// Reserve requirement in minutes (30 VFR day, 45 VFR night/IFR).
    var reserveMinutes: Double {
        didSet { persist() }
    }

    /// Resolved FB stations for the route's region (transient, refreshed by
    /// the planner).
    var aloftStations: [StationWinds] = []

    /// Fuel sufficiency for the current plan; nil until legs have fuel data.
    var fuelCheck: FuelCheck? {
        guard let trip = summary.totalFuelGal else { return nil }
        return FuelPlanner.check(
            tripFuelGal: trip,
            fuelBurnGPH: performance.fuelBurnGPH,
            onboardGal: fuelOnBoardGal,
            reserveMinutes: reserveMinutes
        )
    }

    var summary: PlanSummary {
        var provider: ((Coordinate) -> (windFromDeg: Double, windSpeedKts: Double)?)?
        if useWindsAloft && !aloftStations.isEmpty {
            let stations = aloftStations
            let altitude = cruiseAltitudeFt
            provider = { midpoint in
                WindsAloftInterpolator.wind(at: midpoint, altitudeFt: altitude, stations: stations)
                    .map { (windFromDeg: $0.directionFromDeg, windSpeedKts: $0.speedKts) }
            }
        }
        return LegCalculator.plan(waypoints: waypoints, performance: performance, windProvider: provider)
    }

    var routeString: String {
        waypoints.map(\.ident).joined(separator: " ")
    }

    private static let waypointsKey = "plan.waypoints"
    private static let performanceKey = "plan.performance"
    private static let cruiseAltitudeKey = "plan.cruiseAltitudeFt"
    private static let useWindsAloftKey = "plan.useWindsAloft"
    private static let fuelOnBoardKey = "plan.fuelOnBoardGal"
    private static let reserveMinutesKey = "plan.reserveMinutes"

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
        let savedAltitude = defaults.integer(forKey: Self.cruiseAltitudeKey)
        cruiseAltitudeFt = savedAltitude > 0 ? savedAltitude : 6500
        useWindsAloft = defaults.bool(forKey: Self.useWindsAloftKey)
        let savedFuel = defaults.double(forKey: Self.fuelOnBoardKey)
        fuelOnBoardGal = savedFuel > 0 ? savedFuel : 40
        let savedReserve = defaults.double(forKey: Self.reserveMinutesKey)
        reserveMinutes = savedReserve > 0 ? savedReserve : 45
    }

    /// Replaces the route from a space/comma-separated string of identifiers.
    /// Tokens resolve to airports or navaids (so "KPAO OSI KMRY" works).
    /// - Returns: identifiers that could not be resolved.
    @discardableResult
    func setRoute(_ route: String, database: AirportDatabase) -> [String] {
        let idents = route
            .uppercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,\n"))
            .filter { !$0.isEmpty }

        var resolved: [Waypoint] = []
        var unresolved: [String] = []

        for ident in idents {
            if let waypoint = database.waypoint(ident: ident) {
                resolved.append(waypoint)
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
        guard waypoints.last?.ident != airport.ident else { return }
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
        defaults.set(cruiseAltitudeFt, forKey: Self.cruiseAltitudeKey)
        defaults.set(useWindsAloft, forKey: Self.useWindsAloftKey)
        defaults.set(fuelOnBoardGal, forKey: Self.fuelOnBoardKey)
        defaults.set(reserveMinutes, forKey: Self.reserveMinutesKey)
    }
}
