import XCTest
@testable import HeadwindCore

final class DensityAltitudeTests: XCTestCase {
    func testStandardDayAtSeaLevel() {
        XCTAssertEqual(DensityAltitude.pressureAltitudeFt(elevationFt: 0, altimeterInHg: 29.92), 0, accuracy: 0.001)
        XCTAssertEqual(DensityAltitude.isaTemperatureC(atPressureAltitudeFt: 0), 15, accuracy: 0.001)
        XCTAssertEqual(
            DensityAltitude.densityAltitudeFt(elevationFt: 0, altimeterInHg: 29.92, temperatureC: 15),
            0, accuracy: 0.001
        )
    }

    func testLowPressureRaisesPressureAltitude() {
        // 29.42 inHg is 0.5 in below standard → +500 ft.
        XCTAssertEqual(DensityAltitude.pressureAltitudeFt(elevationFt: 1000, altimeterInHg: 29.42), 1500, accuracy: 0.001)
        // 30.42 inHg → −500 ft.
        XCTAssertEqual(DensityAltitude.pressureAltitudeFt(elevationFt: 1000, altimeterInHg: 30.42), 500, accuracy: 0.001)
    }

    func testHotDayInDenver() {
        // Elev 5434, altim 30.12, OAT 30°C:
        // PA = 5434 + (29.92 − 30.12) × 1000 = 5234
        // ISA = 15 − 2 × 5.234 = 4.532
        // DA = 5234 + 120 × (30 − 4.532) = 8290.16
        let da = DensityAltitude.densityAltitudeFt(elevationFt: 5434, altimeterInHg: 30.12, temperatureC: 30)
        XCTAssertEqual(da, 8290.16, accuracy: 0.5)
    }

    func testColdDayLowersDensityAltitude() {
        let da = DensityAltitude.densityAltitudeFt(elevationFt: 0, altimeterInHg: 29.92, temperatureC: -10)
        XCTAssertEqual(da, -3000, accuracy: 0.5)
    }
}
