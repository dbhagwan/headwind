import Foundation

/// A loading station (seat row, baggage area, fuel) with its arm.
public struct WBStation: Hashable, Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let armIn: Double
    public let maxWeightLb: Double?
    /// Default/placeholder weight used to seed the UI.
    public let defaultWeightLb: Double

    public init(name: String, armIn: Double, maxWeightLb: Double? = nil, defaultWeightLb: Double = 0) {
        self.name = name
        self.armIn = armIn
        self.maxWeightLb = maxWeightLb
        self.defaultWeightLb = defaultWeightLb
    }
}

/// One vertex of the certified CG envelope (weight vs. CG location).
public struct CGEnvelopePoint: Hashable, Codable, Sendable {
    public let cgIn: Double
    public let weightLb: Double

    public init(cgIn: Double, weightLb: Double) {
        self.cgIn = cgIn
        self.weightLb = weightLb
    }
}

/// Aircraft loading data for weight & balance.
public struct AircraftProfile: Hashable, Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let emptyWeightLb: Double
    public let emptyArmIn: Double
    public let maxTakeoffWeightLb: Double
    public let fuelCapacityGal: Double
    public let stations: [WBStation]
    /// CG envelope polygon, ordered around the boundary.
    public let envelope: [CGEnvelopePoint]

    public init(
        name: String,
        emptyWeightLb: Double,
        emptyArmIn: Double,
        maxTakeoffWeightLb: Double,
        fuelCapacityGal: Double,
        stations: [WBStation],
        envelope: [CGEnvelopePoint]
    ) {
        self.name = name
        self.emptyWeightLb = emptyWeightLb
        self.emptyArmIn = emptyArmIn
        self.maxTakeoffWeightLb = maxTakeoffWeightLb
        self.fuelCapacityGal = fuelCapacityGal
        self.stations = stations
        self.envelope = envelope
    }
}

public struct WBResult: Hashable, Sendable {
    public let totalWeightLb: Double
    public let cgIn: Double
    public let totalMomentLbIn: Double
    public let isWithinEnvelope: Bool
    public let isOverMaxWeight: Bool

    public var isSafe: Bool { isWithinEnvelope && !isOverMaxWeight }
}

public enum WeightBalanceCalculator {
    /// Evaluates total weight, CG, and envelope compliance.
    ///
    /// - Parameter stationWeights: weight in pounds per station name; stations
    ///   not present are treated as zero.
    public static func evaluate(profile: AircraftProfile, stationWeights: [String: Double]) -> WBResult {
        var totalWeight = profile.emptyWeightLb
        var totalMoment = profile.emptyWeightLb * profile.emptyArmIn

        for station in profile.stations {
            let weight = stationWeights[station.name] ?? 0
            totalWeight += weight
            totalMoment += weight * station.armIn
        }

        let cg = totalWeight > 0 ? totalMoment / totalWeight : 0
        let within = contains(envelope: profile.envelope, cgIn: cg, weightLb: totalWeight)
        let over = totalWeight > profile.maxTakeoffWeightLb

        return WBResult(
            totalWeightLb: totalWeight,
            cgIn: cg,
            totalMomentLbIn: totalMoment,
            isWithinEnvelope: within,
            isOverMaxWeight: over
        )
    }

    /// Ray-casting point-in-polygon test in (cg, weight) space.
    static func contains(envelope: [CGEnvelopePoint], cgIn x: Double, weightLb y: Double) -> Bool {
        guard envelope.count >= 3 else { return false }
        var inside = false
        var j = envelope.count - 1

        for i in 0..<envelope.count {
            let pi = envelope[i]
            let pj = envelope[j]
            if (pi.weightLb > y) != (pj.weightLb > y) {
                let xCross = (pj.cgIn - pi.cgIn) * (y - pi.weightLb) / (pj.weightLb - pi.weightLb) + pi.cgIn
                if x < xCross {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }
}
