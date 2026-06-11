import XCTest
@testable import HeadwindCore

final class WindTriangleTests: XCTestCase {
    func testDirectHeadwind() throws {
        let s = try XCTUnwrap(WindTriangle.solve(trueCourseDeg: 360, trueAirspeedKts: 100, windFromDeg: 360, windSpeedKts: 20))
        XCTAssertEqual(s.groundSpeedKts, 80, accuracy: 0.01)
        XCTAssertEqual(s.trueHeadingDeg, 360.0.truncatingRemainder(dividingBy: 360), accuracy: 0.01)
        XCTAssertEqual(s.windCorrectionAngleDeg, 0, accuracy: 0.01)
    }

    func testDirectTailwind() throws {
        let s = try XCTUnwrap(WindTriangle.solve(trueCourseDeg: 360, trueAirspeedKts: 100, windFromDeg: 180, windSpeedKts: 20))
        XCTAssertEqual(s.groundSpeedKts, 120, accuracy: 0.01)
        XCTAssertEqual(s.windCorrectionAngleDeg, 0, accuracy: 0.01)
    }

    func testDirectCrosswindFromRight() throws {
        let s = try XCTUnwrap(WindTriangle.solve(trueCourseDeg: 360, trueAirspeedKts: 100, windFromDeg: 90, windSpeedKts: 20))
        // WCA = asin(20/100) ≈ 11.537°, corrected to the right (into the wind).
        XCTAssertEqual(s.windCorrectionAngleDeg, 11.537, accuracy: 0.01)
        XCTAssertEqual(s.trueHeadingDeg, 11.537, accuracy: 0.01)
        // GS = TAS * cos(WCA) with no headwind component.
        XCTAssertEqual(s.groundSpeedKts, 100 * cos(11.537 * .pi / 180), accuracy: 0.05)
    }

    func testDirectCrosswindFromLeft() throws {
        let s = try XCTUnwrap(WindTriangle.solve(trueCourseDeg: 360, trueAirspeedKts: 100, windFromDeg: 270, windSpeedKts: 20))
        XCTAssertEqual(s.windCorrectionAngleDeg, -11.537, accuracy: 0.01)
        XCTAssertEqual(s.trueHeadingDeg, 348.463, accuracy: 0.01)
    }

    func testCalmWind() throws {
        let s = try XCTUnwrap(WindTriangle.solve(trueCourseDeg: 123, trueAirspeedKts: 110, windFromDeg: 0, windSpeedKts: 0))
        XCTAssertEqual(s.groundSpeedKts, 110, accuracy: 0.001)
        XCTAssertEqual(s.trueHeadingDeg, 123, accuracy: 0.001)
    }

    func testImpossibleWindReturnsNil() {
        XCTAssertNil(WindTriangle.solve(trueCourseDeg: 360, trueAirspeedKts: 50, windFromDeg: 90, windSpeedKts: 80))
    }

    func testZeroAirspeedReturnsNil() {
        XCTAssertNil(WindTriangle.solve(trueCourseDeg: 0, trueAirspeedKts: 0, windFromDeg: 0, windSpeedKts: 10))
    }

    func testComponents() {
        XCTAssertEqual(WindTriangle.headwindComponent(courseDeg: 360, windFromDeg: 360, windSpeedKts: 15), 15, accuracy: 0.001)
        XCTAssertEqual(WindTriangle.headwindComponent(courseDeg: 360, windFromDeg: 180, windSpeedKts: 15), -15, accuracy: 0.001)
        XCTAssertEqual(WindTriangle.crosswindComponent(courseDeg: 360, windFromDeg: 90, windSpeedKts: 15), 15, accuracy: 0.001)
        XCTAssertEqual(WindTriangle.crosswindComponent(courseDeg: 360, windFromDeg: 270, windSpeedKts: 15), -15, accuracy: 0.001)
    }
}
