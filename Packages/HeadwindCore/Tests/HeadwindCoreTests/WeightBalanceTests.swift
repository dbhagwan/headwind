import XCTest
@testable import HeadwindCore

final class WeightBalanceTests: XCTestCase {
    /// Simple rectangular envelope: CG 35–47 in, weight 1000–2550 lb.
    private let profile = AircraftProfile(
        name: "Test Single",
        emptyWeightLb: 1600,
        emptyArmIn: 39,
        maxTakeoffWeightLb: 2550,
        fuelCapacityGal: 53,
        stations: [
            WBStation(name: "Front Seats", armIn: 37),
            WBStation(name: "Rear Seats", armIn: 73),
            WBStation(name: "Baggage", armIn: 95, maxWeightLb: 120),
            WBStation(name: "Fuel", armIn: 48),
        ],
        envelope: [
            CGEnvelopePoint(cgIn: 35, weightLb: 1000),
            CGEnvelopePoint(cgIn: 47, weightLb: 1000),
            CGEnvelopePoint(cgIn: 47, weightLb: 2550),
            CGEnvelopePoint(cgIn: 35, weightLb: 2550),
        ]
    )

    func testEmptyAircraftCGEqualsEmptyArm() {
        let result = WeightBalanceCalculator.evaluate(profile: profile, stationWeights: [:])
        XCTAssertEqual(result.totalWeightLb, 1600, accuracy: 0.001)
        XCTAssertEqual(result.cgIn, 39, accuracy: 0.001)
        XCTAssertTrue(result.isWithinEnvelope)
        XCTAssertFalse(result.isOverMaxWeight)
    }

    func testWeightedAverageCG() {
        // 1600 lb @ 39 + 400 lb @ 37 + 300 lb @ 48 → CG = (62400 + 14800 + 14400) / 2300
        let result = WeightBalanceCalculator.evaluate(
            profile: profile,
            stationWeights: ["Front Seats": 400, "Fuel": 300]
        )
        XCTAssertEqual(result.totalWeightLb, 2300, accuracy: 0.001)
        XCTAssertEqual(result.cgIn, (62400.0 + 14800.0 + 14400.0) / 2300.0, accuracy: 0.0001)
        XCTAssertTrue(result.isSafe)
    }

    func testOverGrossIsFlagged() {
        let result = WeightBalanceCalculator.evaluate(
            profile: profile,
            stationWeights: ["Front Seats": 400, "Rear Seats": 400, "Baggage": 120, "Fuel": 318]
        )
        XCTAssertTrue(result.isOverMaxWeight)
        XCTAssertFalse(result.isSafe)
    }

    func testPointInPolygon() {
        let envelope = profile.envelope
        XCTAssertTrue(WeightBalanceCalculator.contains(envelope: envelope, cgIn: 40, weightLb: 2000))
        XCTAssertFalse(WeightBalanceCalculator.contains(envelope: envelope, cgIn: 50, weightLb: 2000))
        XCTAssertFalse(WeightBalanceCalculator.contains(envelope: envelope, cgIn: 30, weightLb: 2000))
        XCTAssertFalse(WeightBalanceCalculator.contains(envelope: envelope, cgIn: 40, weightLb: 3000))
        XCTAssertFalse(WeightBalanceCalculator.contains(envelope: envelope, cgIn: 40, weightLb: 500))
    }
}
