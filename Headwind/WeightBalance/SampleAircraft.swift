import Foundation
import HeadwindCore

/// Built-in aircraft profiles. The roadmap adds user-defined profiles
/// persisted with SwiftData.
///
/// Values are representative of each type; pilots must always use the weight
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

    static let archer = AircraftProfile(
        name: "Piper PA-28-181 Archer",
        emptyWeightLb: 1540,
        emptyArmIn: 86.7,
        maxTakeoffWeightLb: 2550,
        fuelCapacityGal: 48,
        stations: [
            WBStation(name: "Front Seats", armIn: 80.5, defaultWeightLb: 170),
            WBStation(name: "Rear Seats", armIn: 118.1, defaultWeightLb: 0),
            WBStation(name: "Baggage", armIn: 142.8, maxWeightLb: 200, defaultWeightLb: 0),
            WBStation(name: "Fuel (6 lb/gal)", armIn: 95.0, maxWeightLb: 288, defaultWeightLb: 216),
        ],
        envelope: [
            CGEnvelopePoint(cgIn: 82.0, weightLb: 1200),
            CGEnvelopePoint(cgIn: 82.0, weightLb: 2050),
            CGEnvelopePoint(cgIn: 88.6, weightLb: 2550),
            CGEnvelopePoint(cgIn: 93.0, weightLb: 2550),
            CGEnvelopePoint(cgIn: 93.0, weightLb: 1200),
        ]
    )

    static let cessna182T = AircraftProfile(
        name: "Cessna 182T",
        emptyWeightLb: 1995,
        emptyArmIn: 38.8,
        maxTakeoffWeightLb: 3100,
        fuelCapacityGal: 87,
        stations: [
            WBStation(name: "Front Seats", armIn: 37.0, defaultWeightLb: 170),
            WBStation(name: "Rear Seats", armIn: 74.0, defaultWeightLb: 0),
            WBStation(name: "Baggage A", armIn: 97.0, maxWeightLb: 120, defaultWeightLb: 0),
            WBStation(name: "Baggage B", armIn: 116.0, maxWeightLb: 80, defaultWeightLb: 0),
            WBStation(name: "Fuel (6 lb/gal)", armIn: 46.5, maxWeightLb: 522, defaultWeightLb: 360),
        ],
        envelope: [
            CGEnvelopePoint(cgIn: 33.0, weightLb: 1800),
            CGEnvelopePoint(cgIn: 33.0, weightLb: 2250),
            CGEnvelopePoint(cgIn: 41.0, weightLb: 3100),
            CGEnvelopePoint(cgIn: 47.4, weightLb: 3100),
            CGEnvelopePoint(cgIn: 47.4, weightLb: 1800),
        ]
    )

    static let all: [AircraftProfile] = [cessna172S, archer, cessna182T]
}
