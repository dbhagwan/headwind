import Foundation
import SwiftData
import HeadwindCore

/// A pilot-defined aircraft for weight & balance, persisted with SwiftData
/// and bridged to the tested HeadwindCore calculator.
///
/// v1 models the envelope as a rectangle (forward/aft CG limits over a
/// weight range) — how simple-type POH limits usually read. Curved
/// envelopes come later.
@Model
final class UserAircraft {
    var name: String
    var emptyWeightLb: Double
    var emptyArmIn: Double
    var maxTakeoffWeightLb: Double
    var fuelCapacityGal: Double
    var forwardCGIn: Double
    var aftCGIn: Double
    var minEnvelopeWeightLb: Double
    var stations: [StationData]

    struct StationData: Codable, Hashable, Identifiable {
        var id = UUID()
        var name: String
        var armIn: Double
        var maxWeightLb: Double?
        var defaultWeightLb: Double
    }

    init(
        name: String = "",
        emptyWeightLb: Double = 1500,
        emptyArmIn: Double = 39,
        maxTakeoffWeightLb: Double = 2400,
        fuelCapacityGal: Double = 40,
        forwardCGIn: Double = 35,
        aftCGIn: Double = 47,
        minEnvelopeWeightLb: Double = 1200,
        stations: [StationData] = [
            StationData(name: "Front Seats", armIn: 37, maxWeightLb: nil, defaultWeightLb: 170),
            StationData(name: "Rear Seats", armIn: 73, maxWeightLb: nil, defaultWeightLb: 0),
            StationData(name: "Baggage", armIn: 95, maxWeightLb: 120, defaultWeightLb: 0),
            StationData(name: "Fuel (6 lb/gal)", armIn: 48, maxWeightLb: 240, defaultWeightLb: 180),
        ]
    ) {
        self.name = name
        self.emptyWeightLb = emptyWeightLb
        self.emptyArmIn = emptyArmIn
        self.maxTakeoffWeightLb = maxTakeoffWeightLb
        self.fuelCapacityGal = fuelCapacityGal
        self.forwardCGIn = forwardCGIn
        self.aftCGIn = aftCGIn
        self.minEnvelopeWeightLb = minEnvelopeWeightLb
        self.stations = stations
    }

    /// Bridge to the tested core calculator.
    ///
    /// Station names are uniquified defensively: the calculator and the
    /// loading UI key weights by station name, so two stations sharing a
    /// name would double-count weight — a wrong number on a W&B screen.
    func toProfile() -> AircraftProfile {
        var seen: Set<String> = []
        let uniqueStations = stations.map { station -> WBStation in
            var stationName = station.name.isEmpty ? "Station" : station.name
            var suffix = 2
            while seen.contains(stationName) {
                stationName = "\(station.name.isEmpty ? "Station" : station.name) \(suffix)"
                suffix += 1
            }
            seen.insert(stationName)
            return WBStation(
                name: stationName,
                armIn: station.armIn,
                maxWeightLb: station.maxWeightLb,
                defaultWeightLb: station.defaultWeightLb
            )
        }
        return AircraftProfile(
            name: name.isEmpty ? "My Aircraft" : name,
            emptyWeightLb: emptyWeightLb,
            emptyArmIn: emptyArmIn,
            maxTakeoffWeightLb: maxTakeoffWeightLb,
            fuelCapacityGal: fuelCapacityGal,
            stations: uniqueStations,
            envelope: [
                CGEnvelopePoint(cgIn: forwardCGIn, weightLb: minEnvelopeWeightLb),
                CGEnvelopePoint(cgIn: aftCGIn, weightLb: minEnvelopeWeightLb),
                CGEnvelopePoint(cgIn: aftCGIn, weightLb: maxTakeoffWeightLb),
                CGEnvelopePoint(cgIn: forwardCGIn, weightLb: maxTakeoffWeightLb),
            ]
        )
    }
}
