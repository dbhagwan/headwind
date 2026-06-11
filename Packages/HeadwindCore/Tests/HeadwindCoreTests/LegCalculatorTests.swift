import XCTest
@testable import HeadwindCore

final class LegCalculatorTests: XCTestCase {
    private let a = Waypoint(ident: "AAA", name: "Alpha", coordinate: Coordinate(latitude: 0, longitude: 0))
    private let b = Waypoint(ident: "BBB", name: "Bravo", coordinate: Coordinate(latitude: 0, longitude: 1))
    private let c = Waypoint(ident: "CCC", name: "Charlie", coordinate: Coordinate(latitude: 0, longitude: 2))

    func testSingleLegDistanceAndCourse() {
        let summary = LegCalculator.plan(waypoints: [a, b])
        XCTAssertEqual(summary.legs.count, 1)
        XCTAssertEqual(summary.totalDistanceNM, 60, accuracy: 0.1)
        XCTAssertEqual(summary.legs[0].trueCourseDeg, 90, accuracy: 0.01)
        XCTAssertNil(summary.totalEteMinutes)
        XCTAssertNil(summary.totalFuelGal)
    }

    func testMultiLegTotalsWithPerformance() throws {
        // 120 NM eastbound at 120 kts ground speed (calm wind) = 60 minutes.
        let perf = CruisePerformance(trueAirspeedKts: 120, fuelBurnGPH: 10)
        let summary = LegCalculator.plan(waypoints: [a, b, c], performance: perf)

        XCTAssertEqual(summary.legs.count, 2)
        XCTAssertEqual(summary.totalDistanceNM, 120, accuracy: 0.2)
        XCTAssertEqual(try XCTUnwrap(summary.totalEteMinutes), 60, accuracy: 0.2)
        XCTAssertEqual(try XCTUnwrap(summary.totalFuelGal), 10, accuracy: 0.05)
    }

    func testHeadwindIncreasesETE() throws {
        // Eastbound leg, wind from the east at 30 kts: GS = 90.
        let perf = CruisePerformance(trueAirspeedKts: 120, fuelBurnGPH: 10, windFromDeg: 90, windSpeedKts: 30)
        let summary = LegCalculator.plan(waypoints: [a, b], performance: perf)

        let leg = try XCTUnwrap(summary.legs.first)
        XCTAssertEqual(try XCTUnwrap(leg.groundSpeedKts), 90, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(leg.eteMinutes), 60.0 / 90.0 * 60, accuracy: 0.2)
    }

    func testEmptyAndSingleWaypointPlans() {
        XCTAssertTrue(LegCalculator.plan(waypoints: []).legs.isEmpty)
        XCTAssertTrue(LegCalculator.plan(waypoints: [a]).legs.isEmpty)
        XCTAssertEqual(LegCalculator.plan(waypoints: [a]).totalDistanceNM, 0)
    }
}
