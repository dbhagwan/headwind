import XCTest
@testable import HeadwindCore

final class WeatherTests: XCTestCase {
    // MARK: Flight category

    func testFlightCategoryBoundaries() {
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 10, ceilingFt: nil), .vfr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 6, ceilingFt: 3500), .vfr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 5, ceilingFt: nil), .mvfr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 10, ceilingFt: 3000), .mvfr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 2.5, ceilingFt: nil), .ifr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 10, ceilingFt: 900), .ifr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 0.5, ceilingFt: nil), .lifr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: 10, ceilingFt: 400), .lifr)
        XCTAssertEqual(FlightCategory.compute(visibilitySM: nil, ceilingFt: nil), .vfr)
    }

    // MARK: METAR decoding

    func testDecodesAviationWeatherJSON() throws {
        let json = """
        [{
            "icaoId": "KSFO",
            "obsTime": 1718128560,
            "temp": 17.2,
            "dewp": 11.1,
            "wdir": 290,
            "wspd": 18,
            "wgst": 27,
            "visib": "10+",
            "altim": 1016.9,
            "clouds": [{"cover": "FEW", "base": 1500}, {"cover": "BKN", "base": 2500}],
            "rawOb": "KSFO 111636Z 29018G27KT 10SM FEW015 BKN025 17/11 A3003",
            "name": "San Francisco Intl, CA, US",
            "lat": 37.6188,
            "lon": -122.375
        }]
        """
        let metars = try JSONDecoder().decode([Metar].self, from: Data(json.utf8))
        let metar = try XCTUnwrap(metars.first)

        XCTAssertEqual(metar.stationID, "KSFO")
        XCTAssertEqual(metar.windDirectionDeg, 290)
        XCTAssertEqual(metar.windSpeedKts, 18)
        XCTAssertEqual(metar.windGustKts, 27)
        XCTAssertEqual(metar.visibilitySM, 10)
        XCTAssertEqual(metar.ceilingFt, 2500)
        XCTAssertEqual(metar.flightCategory, .mvfr)
        XCTAssertEqual(try XCTUnwrap(metar.altimeterInHg), 30.03, accuracy: 0.02)
        XCTAssertEqual(metar.observationTime, Date(timeIntervalSince1970: 1718128560))
    }

    func testDecodesVariableWindAndMissingFields() throws {
        let json = """
        [{
            "icaoId": "KPAO",
            "wdir": "VRB",
            "wspd": 4,
            "visib": 10,
            "clouds": []
        }]
        """
        let metars = try JSONDecoder().decode([Metar].self, from: Data(json.utf8))
        let metar = try XCTUnwrap(metars.first)

        XCTAssertTrue(metar.windVariable)
        XCTAssertNil(metar.windDirectionDeg)
        XCTAssertNil(metar.ceilingFt)
        XCTAssertEqual(metar.flightCategory, .vfr)
    }

    // MARK: Plain-English summary

    func testPlainEnglishSummaryMentionsKeyFacts() {
        let metar = Metar(
            stationID: "KSFO",
            windDirectionDeg: 290,
            windSpeedKts: 18,
            windGustKts: 27,
            visibilitySM: 10,
            clouds: [CloudLayer(cover: "BKN", baseFt: 2500)]
        )
        let summary = MetarSummarizer.plainEnglish(for: metar)
        XCTAssertTrue(summary.contains("MVFR"))
        XCTAssertTrue(summary.contains("290°"))
        XCTAssertTrue(summary.contains("gusting 27"))
        XCTAssertTrue(summary.contains("Ceiling 2500 feet"))
    }
}
