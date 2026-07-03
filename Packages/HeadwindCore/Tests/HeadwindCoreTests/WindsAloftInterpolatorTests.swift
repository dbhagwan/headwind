import XCTest
@testable import HeadwindCore

final class WindsAloftInterpolatorTests: XCTestCase {
    private func station(_ name: String, _ lat: Double, _ lon: Double, _ winds: [WindAloft]) -> StationWinds {
        StationWinds(station: name, coordinate: Coordinate(latitude: lat, longitude: lon), winds: winds)
    }

    private func w(_ alt: Int, _ dir: Int?, _ speed: Int?) -> WindAloft {
        WindAloft(altitudeFt: alt, directionDeg: dir, speedKts: speed, temperatureC: nil)
    }

    func testSingleStationExactLevel() throws {
        let s = station("SFO", 37.6, -122.4, [w(3000, 290, 20), w(9000, 300, 40)])
        let wind = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: Coordinate(latitude: 37.6, longitude: -122.4), altitudeFt: 3000, stations: [s]
        ))
        XCTAssertEqual(wind.directionFromDeg, 290, accuracy: 0.01)
        XCTAssertEqual(wind.speedKts, 20, accuracy: 0.01)
    }

    func testAltitudeInterpolationMidway() throws {
        // Same direction at both levels → speed interpolates linearly.
        let s = station("SFO", 37.6, -122.4, [w(3000, 360, 20), w(9000, 360, 40)])
        let wind = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: Coordinate(latitude: 37.6, longitude: -122.4), altitudeFt: 6000, stations: [s]
        ))
        XCTAssertEqual(wind.directionFromDeg, 360, accuracy: 0.01)
        XCTAssertEqual(wind.speedKts, 30, accuracy: 0.01)
    }

    func testAltitudeClampsOutsideStationRange() throws {
        let s = station("DEN", 39.8, -104.7, [w(9000, 270, 30), w(12000, 270, 50)])
        let below = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: s.coordinate, altitudeFt: 3000, stations: [s]
        ))
        XCTAssertEqual(below.speedKts, 30, accuracy: 0.01)
        let above = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: s.coordinate, altitudeFt: 30000, stations: [s]
        ))
        XCTAssertEqual(above.speedKts, 50, accuracy: 0.01)
    }

    func testVectorBlendAcrossDirectionWrap() throws {
        // 350@20 and 010@20 from equidistant stations → 360 at 20·cos(10°).
        let a = station("A", 38.0, -122.0, [w(6000, 350, 20)])
        let b = station("B", 36.0, -122.0, [w(6000, 10, 20)])
        let wind = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: Coordinate(latitude: 37.0, longitude: -122.0), altitudeFt: 6000, stations: [a, b]
        ))
        XCTAssertEqual(wind.directionFromDeg, 360, accuracy: 0.01)
        XCTAssertEqual(wind.speedKts, 20 * cos(10 * Double.pi / 180), accuracy: 0.01)
    }

    func testOpposingWindsCancelToCalm() throws {
        let a = station("A", 38.0, -122.0, [w(6000, 90, 20)])
        let b = station("B", 36.0, -122.0, [w(6000, 270, 20)])
        let wind = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: Coordinate(latitude: 37.0, longitude: -122.0), altitudeFt: 6000, stations: [a, b]
        ))
        XCTAssertEqual(wind.speedKts, 0, accuracy: 0.01)
    }

    func testInverseDistanceWeightingFavorsNearStation() throws {
        // Standing on station A: its wind should dominate a far-away B.
        let a = station("A", 37.0, -122.0, [w(6000, 360, 10)])
        let b = station("B", 37.0, -115.0, [w(6000, 180, 50)])
        let wind = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: a.coordinate, altitudeFt: 6000, stations: [a, b]
        ))
        XCTAssertEqual(wind.directionFromDeg, 360, accuracy: 1.0)
        XCTAssertGreaterThan(wind.speedKts, 9.0)
    }

    func testStationsBeyondRangeAreIgnored() {
        let far = station("FAR", 20.0, -60.0, [w(6000, 360, 50)])
        XCTAssertNil(WindsAloftInterpolator.wind(
            at: Coordinate(latitude: 37.0, longitude: -122.0), altitudeFt: 6000, stations: [far]
        ))
        XCTAssertNil(WindsAloftInterpolator.wind(
            at: Coordinate(latitude: 37.0, longitude: -122.0), altitudeFt: 6000, stations: []
        ))
    }

    func testLightAndVariableContributesCalm() throws {
        let s = station("SFO", 37.6, -122.4, [
            WindAloft(altitudeFt: 3000, directionDeg: nil, speedKts: nil, temperatureC: nil),
            w(9000, 360, 40),
        ])
        let wind = try XCTUnwrap(WindsAloftInterpolator.wind(
            at: s.coordinate, altitudeFt: 6000, stations: [s]
        ))
        // Halfway between calm and 40 kt.
        XCTAssertEqual(wind.speedKts, 20, accuracy: 0.01)
    }

    func testLegCalculatorUsesPerLegWinds() throws {
        // Eastbound leg on the equator: provider supplies a 30 kt headwind
        // (wind from 090) overriding the calm performance wind.
        let a = Waypoint(ident: "AAA", name: "A", coordinate: Coordinate(latitude: 0, longitude: 0))
        let b = Waypoint(ident: "BBB", name: "B", coordinate: Coordinate(latitude: 0, longitude: 1))
        let perf = CruisePerformance(trueAirspeedKts: 120, fuelBurnGPH: 10)

        let summary = LegCalculator.plan(waypoints: [a, b], performance: perf) { _ in
            (windFromDeg: 90, windSpeedKts: 30)
        }
        let leg = try XCTUnwrap(summary.legs.first)
        XCTAssertEqual(try XCTUnwrap(leg.groundSpeedKts), 90, accuracy: 0.1)

        // Provider returning nil falls back to the performance wind (calm).
        let fallback = LegCalculator.plan(waypoints: [a, b], performance: perf) { _ in nil }
        XCTAssertEqual(try XCTUnwrap(fallback.legs.first?.groundSpeedKts), 120, accuracy: 0.1)
    }
}
