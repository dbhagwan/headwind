import XCTest
@testable import HeadwindCore

final class AirSigmetTests: XCTestCase {
    // Mirrors the aviationweather.gov airsigmet JSON quirks: epoch times and
    // coordinates as strings, hazard/severity fields, mixed presence.
    private let fixture = """
    [
      {"airSigmetType":"SIGMET","hazard":"CONVECTIVE","severity":"3","seriesId":"82C",
       "validTimeFrom":"1783036500","validTimeTo":"1783043700",
       "altitudeLow1":null,"altitudeHi1":45000,
       "rawAirSigmet":"KKCI SIGMET 82C VALID ...",
       "coords":[{"lat":"35.74","lon":"-106.16"},{"lat":"35.16","lon":"-105.69"},
                 {"lat":"34.70","lon":"-106.33"}]},
      {"airSigmetType":"AIRMET","hazard":"TURB","seriesId":"T4",
       "validTimeFrom":1783036500,"validTimeTo":1783058100,
       "altitudeLow1":"24000","altitudeHi1":"39000",
       "coords":[{"lat":40.0,"lon":-120.0},{"lat":41.0,"lon":-119.0},{"lat":40.5,"lon":-118.0}]},
      {"airSigmetType":"SIGMET","hazard":"ICE","coords":[]}
    ]
    """

    func testDecodesStringTypedFields() throws {
        let items = try JSONDecoder().decode([AirSigmet].self, from: Data(fixture.utf8))
        XCTAssertEqual(items.count, 3)

        let convective = items[0]
        XCTAssertEqual(convective.type, "SIGMET")
        XCTAssertEqual(convective.hazard, "CONVECTIVE")
        XCTAssertEqual(convective.severity, "3")
        XCTAssertEqual(convective.validFrom, Date(timeIntervalSince1970: 1_783_036_500))
        XCTAssertEqual(convective.altitudeHiFt, 45000)
        XCTAssertNil(convective.altitudeLowFt)
        XCTAssertEqual(convective.polygon.count, 3)
        XCTAssertEqual(convective.polygon[0].latitude, 35.74, accuracy: 1e-9)
        XCTAssertEqual(convective.polygon[0].longitude, -106.16, accuracy: 1e-9)
    }

    func testDecodesNumericVariants() throws {
        let items = try JSONDecoder().decode([AirSigmet].self, from: Data(fixture.utf8))
        let turb = items[1]
        XCTAssertEqual(turb.altitudeLowFt, 24000)
        XCTAssertEqual(turb.altitudeHiFt, 39000)
        XCTAssertEqual(turb.polygon.count, 3)
        XCTAssertEqual(turb.validTo, Date(timeIntervalSince1970: 1_783_058_100))
    }

    func testActivityWindow() throws {
        let items = try JSONDecoder().decode([AirSigmet].self, from: Data(fixture.utf8))
        let s = items[0]
        XCTAssertFalse(s.isActive(asOf: Date(timeIntervalSince1970: 1_783_036_000)))
        XCTAssertTrue(s.isActive(asOf: Date(timeIntervalSince1970: 1_783_040_000)))
        XCTAssertFalse(s.isActive(asOf: Date(timeIntervalSince1970: 1_783_050_000)))
        // No window at all → treated as active.
        XCTAssertTrue(items[2].isActive(asOf: .now))
    }

    func testEmptyPolygonSurvivesDecoding() throws {
        let items = try JSONDecoder().decode([AirSigmet].self, from: Data(fixture.utf8))
        XCTAssertTrue(items[2].polygon.isEmpty)
    }
}
