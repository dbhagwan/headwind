import Foundation

/// Cruise performance and winds-aloft assumptions used for time/fuel planning.
public struct CruisePerformance: Hashable, Codable, Sendable {
    public var trueAirspeedKts: Double
    public var fuelBurnGPH: Double
    public var windFromDeg: Double
    public var windSpeedKts: Double

    public init(
        trueAirspeedKts: Double,
        fuelBurnGPH: Double,
        windFromDeg: Double = 0,
        windSpeedKts: Double = 0
    ) {
        self.trueAirspeedKts = trueAirspeedKts
        self.fuelBurnGPH = fuelBurnGPH
        self.windFromDeg = windFromDeg
        self.windSpeedKts = windSpeedKts
    }
}

/// One leg between consecutive waypoints with computed navigation values.
public struct Leg: Hashable, Sendable, Identifiable {
    public var id: String { "\(from.id)-\(to.id)" }
    public let from: Waypoint
    public let to: Waypoint
    public let distanceNM: Double
    public let trueCourseDeg: Double
    /// Wind-corrected values; nil when no performance data was supplied or
    /// the wind triangle has no solution.
    public let trueHeadingDeg: Double?
    public let groundSpeedKts: Double?
    public let eteMinutes: Double?
    public let fuelGal: Double?
}

/// Totals for a full route.
public struct PlanSummary: Hashable, Sendable {
    public let legs: [Leg]
    public let totalDistanceNM: Double
    public let totalEteMinutes: Double?
    public let totalFuelGal: Double?
}

public enum LegCalculator {
    /// Computes legs and totals for an ordered list of waypoints.
    public static func plan(waypoints: [Waypoint], performance: CruisePerformance? = nil) -> PlanSummary {
        var legs: [Leg] = []

        for (from, to) in zip(waypoints, waypoints.dropFirst()) {
            let distance = NavMath.distanceNM(from: from.coordinate, to: to.coordinate)
            let course = NavMath.initialBearingDeg(from: from.coordinate, to: to.coordinate)

            var heading: Double?
            var groundSpeed: Double?
            var ete: Double?
            var fuel: Double?

            if let perf = performance,
               let solution = WindTriangle.solve(
                   trueCourseDeg: course,
                   trueAirspeedKts: perf.trueAirspeedKts,
                   windFromDeg: perf.windFromDeg,
                   windSpeedKts: perf.windSpeedKts
               ) {
                heading = solution.trueHeadingDeg
                groundSpeed = solution.groundSpeedKts
                let minutes = distance / solution.groundSpeedKts * 60
                ete = minutes
                fuel = minutes / 60 * perf.fuelBurnGPH
            }

            legs.append(Leg(
                from: from,
                to: to,
                distanceNM: distance,
                trueCourseDeg: course,
                trueHeadingDeg: heading,
                groundSpeedKts: groundSpeed,
                eteMinutes: ete,
                fuelGal: fuel
            ))
        }

        let totalDistance = legs.reduce(0) { $0 + $1.distanceNM }
        let etes = legs.compactMap(\.eteMinutes)
        let fuels = legs.compactMap(\.fuelGal)

        return PlanSummary(
            legs: legs,
            totalDistanceNM: totalDistance,
            totalEteMinutes: etes.count == legs.count && !legs.isEmpty ? etes.reduce(0, +) : nil,
            totalFuelGal: fuels.count == legs.count && !legs.isEmpty ? fuels.reduce(0, +) : nil
        )
    }
}
