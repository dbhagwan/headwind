import Foundation
import HeadwindCore

/// Built-in aircraft profiles for v0.1. The roadmap adds user-defined
/// profiles persisted with SwiftData.
///
/// Values are representative of the type; pilots must always use the weight
/// and balance data from their specific aircraft's POH.
enum SampleAircraft {
    static let cessna172S = AircraftProfile(
        name: "Cessna 172S",
        emptyWeightLb: 1680,
        emptyArmIn: 39.3,
        maxTakeoffWeightLb: 2550,
        fuelCapacityGal: 53,
        stations: [
            WBStation(name: "Front Seats", armIn: 37.0, defaultWeightLb: 170),
            WBStation(name: "Rear Seats", armIn: 73.0, defaultWeightLb: 0),
            WBStation(name: "Baggage A", armIn: 95.0, maxWeightLb: 120, defaultWeightLb: 0),
            WBStation(name: "Baggage B", armIn: 123.0, maxWeightLb: 50, defaultWeightLb: 0),
            WBStation(name: "Fuel (6 lb/gal)", armIn: 48.0, maxWeightLb: 318, defaultWeightLb: 240),
        ],
        envelope: [
            CGEnvelopePoint(cgIn: 35.0, weightLb: 1500),
            CGEnvelopePoint(cgIn: 35.0, weightLb: 1950),
            CGEnvelopePoint(cgIn: 41.0, weightLb: 2550),
            CGEnvelopePoint(cgIn: 47.3, weightLb: 2550),
            CGEnvelopePoint(cgIn: 47.3, weightLb: 1500),
        ]
    )

    static let all: [AircraftProfile] = [cessna172S]
}
