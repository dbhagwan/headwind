import XCTest
@testable import HeadwindCore

final class PlateIndexTests: XCTestCase {
    private let json = """
    {"cycle":"2606","airports":{
      "KSFO":[
        {"n":"AIRPORT DIAGRAM","c":"APD","p":"00375AD.PDF"},
        {"n":"ILS OR LOC RWY 28L","c":"IAP","p":"00375IL28L.PDF"},
        {"n":"ILS OR LOC RWY 28R","c":"IAP","p":"00375IL28R.PDF"},
        {"n":"TRUKN TWO (RNAV)","c":"DP","p":"00375TRUKN.PDF"},
        {"n":"TAKEOFF MINIMUMS","c":"MIN","p":"SW2TO.PDF"}
      ]
    }}
    """

    func testDecodeAndLookup() throws {
        let index = try JSONDecoder().decode(PlateIndex.self, from: Data(json.utf8))
        XCTAssertEqual(index.cycle, "2606")
        XCTAssertEqual(index.plates(for: "KSFO").count, 5)
        XCTAssertEqual(index.plates(for: "ksfo ").count, 5)
        XCTAssertTrue(index.plates(for: "KZZZ").isEmpty)

        let ils = try XCTUnwrap(index.plates(for: "KSFO").first { $0.name.contains("28L") })
        XCTAssertEqual(ils.code, "IAP")
        XCTAssertEqual(ils.pdfName, "00375IL28L.PDF")
        XCTAssertEqual(ils.category, "Approaches")
    }

    func testGroupingFollowsPilotOrder() throws {
        let index = try JSONDecoder().decode(PlateIndex.self, from: Data(json.utf8))
        let groups = index.groupedPlates(for: "KSFO")
        XCTAssertEqual(
            groups.map(\.category),
            ["Airport Diagram", "Approaches", "Departures", "Minimums"]
        )
        XCTAssertEqual(groups[1].plates.count, 2)
    }

    func testCategoryMapping() {
        XCTAssertEqual(ApproachPlate(name: "x", code: "STR", pdfName: "x.pdf").category, "Arrivals")
        XCTAssertEqual(ApproachPlate(name: "x", code: "HOT", pdfName: "x.pdf").category, "Hot Spots")
        XCTAssertEqual(ApproachPlate(name: "x", code: "ZZZ", pdfName: "x.pdf").category, "Other")
    }

    func testCurrencyDecodedWhenDatesPresent() throws {
        let withDates = """
        {"cycle":"2606","effective":"2026-06-11","expires":"2026-07-09","airports":{
          "KSFO":[{"n":"AIRPORT DIAGRAM","c":"APD","p":"00375AD.PDF"}]
        }}
        """
        let index = try JSONDecoder().decode(PlateIndex.self, from: Data(withDates.utf8))
        let currency = try XCTUnwrap(index.currency)
        XCTAssertEqual(currency.cycleLabel, "2606")
        XCTAssertEqual(currency.effectiveDate, AiracCalendar.makeUTC(year: 2026, month: 6, day: 11))
        XCTAssertEqual(currency.expirationDate, AiracCalendar.makeUTC(year: 2026, month: 7, day: 9))
    }

    func testCurrencyNilWhenDatesAbsent() throws {
        let index = try JSONDecoder().decode(PlateIndex.self, from: Data(json.utf8))
        XCTAssertNil(index.currency)
    }
}
