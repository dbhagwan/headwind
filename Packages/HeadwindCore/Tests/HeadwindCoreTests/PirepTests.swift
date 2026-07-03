import XCTest
@testable import HeadwindCore

final class PirepTests: XCTestCase {
    // Mirrors the aviationweather.gov pirep JSON: string-typed numbers,
    // empty-string fields, FL-hundreds altitude.
    private let fixture = """
    [
      {"pirepType":"AIREP","acType":"UAL1636","lat":"30.2833","lon":"-131.6333",
       "obsTime":"1783061520","fltLvl":"370","wxString":"","temp":"-51",
       "icgInt1":"","tbInt1":"",
       "rawOb":"ARP UAL1636 3017N 13138W 0652 F370 MS51 210/045KT"},
      {"pirepType":"PIREP","acType":"C172","lat":37.5,"lon":-122.2,
       "obsTime":1783061520,"fltLvl":"045","tbInt1":"MOD","icgInt1":"",
       "rawOb":"SFO UA /OV KSFO/TM 2352/FL045/TP C172/TB MOD"},
      {"pirepType":"Urgent PIREP","acType":"B737","lat":"40.0","lon":"-105.0",
       "fltLvl":"180","tbInt1":"SEV","icgInt1":"MOD",
       "rawOb":"UUA /OV DEN/FL180/TB SEV"},
      {"pirepType":"PIREP","acType":"NOLOC","fltLvl":"100"}
    ]
    """

    private func decodeAll() throws -> [Pirep] {
        // The no-coordinates report must fail individually, not sink the array,
        // so decode leniently the way the app does.
        let raw = try JSONSerialization.jsonObject(with: Data(fixture.utf8)) as! [Any]
        return raw.compactMap { item in
            guard let data = try? JSONSerialization.data(withJSONObject: item) else { return nil }
            return try? JSONDecoder().decode(Pirep.self, from: data)
        }
    }

    func testDecodesStringTypedFields() throws {
        let pireps = try decodeAll()
        XCTAssertEqual(pireps.count, 3, "report without coordinates is dropped")

        let airep = pireps[0]
        XCTAssertEqual(airep.aircraft, "UAL1636")
        XCTAssertEqual(airep.coordinate.latitude, 30.2833, accuracy: 1e-9)
        XCTAssertEqual(airep.altitudeFt, 37000)
        XCTAssertEqual(airep.temperatureC, -51)
        XCTAssertEqual(airep.observationTime, Date(timeIntervalSince1970: 1_783_061_520))
        XCTAssertNil(airep.turbulence, "empty strings become nil")
        XCTAssertFalse(airep.hasTurbulence)
    }

    func testSeverityRanking() throws {
        let pireps = try decodeAll()
        XCTAssertEqual(pireps[0].severity, .routine)
        XCTAssertEqual(pireps[1].severity, .moderate)
        XCTAssertEqual(pireps[2].severity, .severe)
        XCTAssertTrue(pireps[1].severity < pireps[2].severity)
        XCTAssertTrue(pireps[2].hasIcing)
    }

    func testLowAltitudeParsing() throws {
        let pireps = try decodeAll()
        XCTAssertEqual(pireps[1].altitudeFt, 4500)
    }
}
