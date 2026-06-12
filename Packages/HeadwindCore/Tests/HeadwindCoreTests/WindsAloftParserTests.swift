import XCTest
@testable import HeadwindCore

final class WindsAloftParserTests: XCTestCase {
    // Aligned like the real FB product; DEN has no 3000/6000 cells because
    // the station sits above those levels.
    private let fixture = """
    DATA BASED ON 121200Z
    VALID 121800Z   FOR USE 1400-2100Z. TEMPS NEG ABV 24000

    FT  3000    6000    9000   12000   18000   24000  30000  34000  39000
    SFO 2920 2925+10 3030+05 3035+01 3040-13 304026 305541 306450 307156
    DEN              2615+02 2725-04 2845-18 285530 770545 781150 760956
    """

    func testParsesStationsAndAltitudes() throws {
        let stations = WindsAloftParser.parse(fixture)
        XCTAssertEqual(stations.map(\.station), ["SFO", "DEN"])

        let sfo = try XCTUnwrap(stations.first)
        XCTAssertEqual(sfo.winds.count, 9)
        XCTAssertEqual(sfo.winds.first?.altitudeFt, 3000)
        XCTAssertEqual(sfo.winds.first?.directionDeg, 290)
        XCTAssertEqual(sfo.winds.first?.speedKts, 20)
        XCTAssertNil(sfo.winds.first?.temperatureC)
    }

    func testMissingLowLevelsAlignToColumns() throws {
        let den = try XCTUnwrap(WindsAloftParser.parse(fixture).last)
        XCTAssertEqual(den.winds.count, 7)
        XCTAssertEqual(den.winds.first?.altitudeFt, 9000)
        XCTAssertEqual(den.winds.first?.directionDeg, 260)
        XCTAssertEqual(den.winds.first?.speedKts, 15)
        XCTAssertEqual(den.winds.first?.temperatureC, 2)
    }

    func testSignedTemperatures() throws {
        let sfo = try XCTUnwrap(WindsAloftParser.parse(fixture).first)
        let at12k = try XCTUnwrap(sfo.winds.first { $0.altitudeFt == 12000 })
        XCTAssertEqual(at12k.temperatureC, 1)
        let at18k = try XCTUnwrap(sfo.winds.first { $0.altitudeFt == 18000 })
        XCTAssertEqual(at18k.temperatureC, -13)
    }

    func testImplicitNegativeTempsAbove24000() {
        let wind = WindsAloftParser.decodeCell("305541", altitudeFt: 30000)
        XCTAssertEqual(wind?.directionDeg, 300)
        XCTAssertEqual(wind?.speedKts, 55)
        XCTAssertEqual(wind?.temperatureC, -41)
    }

    func testHighSpeedEncoding() {
        // 7705 → direction (77−50)×10 = 270, speed 105.
        let wind = WindsAloftParser.decodeCell("770545", altitudeFt: 30000)
        XCTAssertEqual(wind?.directionDeg, 270)
        XCTAssertEqual(wind?.speedKts, 105)
        XCTAssertEqual(wind?.temperatureC, -45)
    }

    func testLightAndVariable() {
        let wind = WindsAloftParser.decodeCell("9900", altitudeFt: 3000)
        XCTAssertEqual(wind?.isLightAndVariable, true)
        XCTAssertNil(wind?.directionDeg)
        XCTAssertNil(wind?.speedKts)
    }

    func testLightAndVariableWithTemp() {
        let wind = WindsAloftParser.decodeCell("9900+15", altitudeFt: 6000)
        XCTAssertEqual(wind?.isLightAndVariable, true)
        XCTAssertEqual(wind?.temperatureC, 15)
    }

    func testGarbageReturnsNil() {
        XCTAssertNil(WindsAloftParser.decodeCell("XYZ", altitudeFt: 3000))
        XCTAssertNil(WindsAloftParser.decodeCell("12", altitudeFt: 3000))
        XCTAssertTrue(WindsAloftParser.parse("no header here").isEmpty)
    }
}
