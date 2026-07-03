import XCTest
@testable import HeadwindCore

final class FuelPlannerTests: XCTestCase {
    func testSufficientFuel() {
        // 10 gal trip + 45 min at 8 gph (6 gal) = 16 required; 30 on board.
        let check = FuelPlanner.check(tripFuelGal: 10, fuelBurnGPH: 8, onboardGal: 30, reserveMinutes: 45)
        XCTAssertEqual(check.reserveGal, 6, accuracy: 1e-9)
        XCTAssertEqual(check.totalRequiredGal, 16, accuracy: 1e-9)
        XCTAssertEqual(check.marginGal, 14, accuracy: 1e-9)
        XCTAssertTrue(check.isSufficient)
        XCTAssertEqual(check.enduranceMinutes, 225, accuracy: 1e-9)
    }

    func testInsufficientFuelFlagged() {
        // 20 trip + 4 reserve (30 min @ 8 gph) = 24 required; 20 on board.
        let check = FuelPlanner.check(tripFuelGal: 20, fuelBurnGPH: 8, onboardGal: 20, reserveMinutes: 30)
        XCTAssertEqual(check.marginGal, -4, accuracy: 1e-9)
        XCTAssertFalse(check.isSufficient)
    }

    func testExactlyAtReserveIsSufficient() {
        let check = FuelPlanner.check(tripFuelGal: 10, fuelBurnGPH: 10, onboardGal: 17.5, reserveMinutes: 45)
        XCTAssertEqual(check.marginGal, 0, accuracy: 1e-9)
        XCTAssertTrue(check.isSufficient)
    }

    func testZeroBurnDoesNotDivideByZero() {
        let check = FuelPlanner.check(tripFuelGal: 0, fuelBurnGPH: 0, onboardGal: 20, reserveMinutes: 45)
        XCTAssertEqual(check.enduranceMinutes, 0)
        XCTAssertEqual(check.reserveGal, 0)
        XCTAssertTrue(check.isSufficient)
    }
}
