import XCTest
@testable import HeadwindCore

final class NavMathTests: XCTestCase {
    func testOneDegreeOfLongitudeAtEquatorIsSixtyNM() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 0, longitude: 1)
        XCTAssertEqual(NavMath.distanceNM(from: a, to: b), 60, accuracy: 0.1)
    }

    func testOneDegreeOfLatitudeIsSixtyNM() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 1, longitude: 0)
        XCTAssertEqual(NavMath.distanceNM(from: a, to: b), 60, accuracy: 0.1)
    }

    func testDistanceIsSymmetric() {
        let sfo = Coordinate(latitude: 37.6188, longitude: -122.3750)
        let jfk = Coordinate(latitude: 40.6413, longitude: -73.7781)
        XCTAssertEqual(
            NavMath.distanceNM(from: sfo, to: jfk),
            NavMath.distanceNM(from: jfk, to: sfo),
            accuracy: 1e-9
        )
    }

    func testZeroDistanceToSelf() {
        let p = Coordinate(latitude: 37.0, longitude: -122.0)
        XCTAssertEqual(NavMath.distanceNM(from: p, to: p), 0, accuracy: 1e-9)
    }

    func testCardinalBearings() {
        let origin = Coordinate(latitude: 0, longitude: 0)
        XCTAssertEqual(NavMath.initialBearingDeg(from: origin, to: Coordinate(latitude: 1, longitude: 0)), 0, accuracy: 0.01)
        XCTAssertEqual(NavMath.initialBearingDeg(from: origin, to: Coordinate(latitude: 0, longitude: 1)), 90, accuracy: 0.01)
        XCTAssertEqual(NavMath.initialBearingDeg(from: origin, to: Coordinate(latitude: -1, longitude: 0)), 180, accuracy: 0.01)
        XCTAssertEqual(NavMath.initialBearingDeg(from: origin, to: Coordinate(latitude: 0, longitude: -1)), 270, accuracy: 0.01)
    }

    func testDestinationRoundTrip() {
        let origin = Coordinate(latitude: 37.6188, longitude: -122.3750)
        let bearing = 137.0
        let distance = 250.0

        let dest = NavMath.destination(from: origin, bearingDeg: bearing, distanceNM: distance)
        XCTAssertEqual(NavMath.distanceNM(from: origin, to: dest), distance, accuracy: 0.01)
        XCTAssertEqual(NavMath.initialBearingDeg(from: origin, to: dest), bearing, accuracy: 0.01)
    }

    func testMidpointOnEquator() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 0, longitude: 10)
        let mid = NavMath.midpoint(a, b)
        XCTAssertEqual(mid.latitude, 0, accuracy: 1e-9)
        XCTAssertEqual(mid.longitude, 5, accuracy: 1e-9)
    }

    func testNormalizeDeg() {
        XCTAssertEqual(NavMath.normalizeDeg(-90), 270, accuracy: 1e-9)
        XCTAssertEqual(NavMath.normalizeDeg(370), 10, accuracy: 1e-9)
        XCTAssertEqual(NavMath.normalizeDeg(0), 0, accuracy: 1e-9)
        XCTAssertEqual(NavMath.normalizeDeg(360), 0, accuracy: 1e-9)
    }
}
