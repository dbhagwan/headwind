import XCTest
@testable import HeadwindCore

final class MetarCodableTests: XCTestCase {
    func testRoundTripPreservesKeyFields() throws {
        let original = Metar(
            stationID: "KSFO",
            observationTime: Date(timeIntervalSince1970: 1_718_128_560),
            temperatureC: 17.2,
            dewpointC: 11.1,
            windDirectionDeg: 290,
            windVariable: false,
            windSpeedKts: 18,
            windGustKts: 27,
            visibilitySM: 10,
            altimeterHpa: 1016.9,
            clouds: [CloudLayer(cover: "FEW", baseFt: 1500), CloudLayer(cover: "BKN", baseFt: 2500)],
            rawText: "KSFO 111636Z 29018G27KT 10SM FEW015 BKN025 17/11 A3003",
            stationName: "San Francisco Intl",
            latitude: 37.62,
            longitude: -122.37
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Metar.self, from: data)

        XCTAssertEqual(decoded.stationID, "KSFO")
        XCTAssertEqual(decoded.observationTime, original.observationTime)
        XCTAssertEqual(decoded.windDirectionDeg, 290)
        XCTAssertEqual(decoded.windSpeedKts, 18)
        XCTAssertEqual(decoded.windGustKts, 27)
        XCTAssertEqual(decoded.visibilitySM, 10)
        XCTAssertEqual(decoded.ceilingFt, 2500)
        XCTAssertEqual(decoded.flightCategory, original.flightCategory)
        XCTAssertEqual(decoded.clouds, original.clouds)
        XCTAssertEqual(decoded.rawText, original.rawText)
    }

    func testVariableWindRoundTrips() throws {
        let original = Metar(stationID: "KPAO", windVariable: true, windSpeedKts: 4)
        let decoded = try JSONDecoder().decode(Metar.self, from: try JSONEncoder().encode(original))
        XCTAssertTrue(decoded.windVariable)
        XCTAssertNil(decoded.windDirectionDeg)
        XCTAssertEqual(decoded.windSpeedKts, 4)
    }

    func testDictionaryCacheRoundTrips() throws {
        let cache = ["KSFO": Metar(stationID: "KSFO", windSpeedKts: 10)]
        let data = try JSONEncoder().encode(cache)
        let decoded = try JSONDecoder().decode([String: Metar].self, from: data)
        XCTAssertEqual(decoded["KSFO"]?.windSpeedKts, 10)
    }

    // MARK: Freshness

    func testAgeAndStaleness() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let fresh = Metar(stationID: "K", observationTime: now.addingTimeInterval(-30 * 60))
        let old = Metar(stationID: "K", observationTime: now.addingTimeInterval(-2 * 3600))
        let undated = Metar(stationID: "K")

        XCTAssertEqual(fresh.age(asOf: now), 30 * 60, accuracy: 0.5)
        XCTAssertFalse(fresh.isStale(asOf: now))
        XCTAssertTrue(old.isStale(asOf: now))
        XCTAssertNil(undated.age(asOf: now))
        XCTAssertFalse(undated.isStale(asOf: now))
    }
}
