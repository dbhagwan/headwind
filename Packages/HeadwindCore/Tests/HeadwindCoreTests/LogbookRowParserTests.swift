import XCTest
@testable import HeadwindCore

final class LogbookRowParserTests: XCTestCase {
    private func utcDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testParsesTypicalUSLogbookRow() {
        let rows = LogbookRowParser.parse("3/14/24 C172 N737HW KPAO KHAF 1.2 0.0 2 pattern work")
        XCTAssertEqual(rows.count, 1)
        let row = rows[0]
        XCTAssertEqual(row.date, utcDate(2024, 3, 14))
        XCTAssertEqual(row.aircraftType, "C172")
        XCTAssertEqual(row.tailNumber, "N737HW")
        XCTAssertEqual(row.fromIdent, "KPAO")
        XCTAssertEqual(row.toIdent, "KHAF")
        XCTAssertEqual(row.totalHours, 1.2)
        XCTAssertEqual(row.landings, 2)
        XCTAssertEqual(row.remarks, "pattern work")
    }

    func testMultipleRowsAndDateFormats() {
        let text = """
        2024-03-14 SR22 N45AB KSQL KMRY 1.8 1
        03-15-2024 PA-28-181 N8231C KMRY KSQL 1.7 0.3 1 night return
        """
        let rows = LogbookRowParser.parse(text)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].date, utcDate(2024, 3, 14))
        XCTAssertEqual(rows[0].aircraftType, "SR22")
        XCTAssertEqual(rows[1].date, utcDate(2024, 3, 15))
        XCTAssertEqual(rows[1].aircraftType, "PA-28-181")
        XCTAssertEqual(rows[1].tailNumber, "N8231C")
        // Largest decimal wins as total.
        XCTAssertEqual(rows[1].totalHours, 1.7)
    }

    func testDatelessLineFoldsIntoPreviousRemarks() {
        let text = """
        3/14/24 C172 N737HW KPAO KPAO 0.9 3
        three landings to a full stop
        """
        let rows = LogbookRowParser.parse(text)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].remarks, "three landings to a full stop")
    }

    func testLeadingDatelessLineIsDropped() {
        XCTAssertTrue(LogbookRowParser.parse("DATE AIRCRAFT FROM TO TOTAL").isEmpty)
    }

    func testConservativeOnAmbiguousTokens() {
        // "solo" must not become an ident; 25 (> 20) must not be landings.
        let rows = LogbookRowParser.parse("6/1/23 C152 N123 KRHV KRHV 1.1 25 solo")
        XCTAssertEqual(rows[0].tailNumber, "N123")
        XCTAssertEqual(rows[0].fromIdent, "KRHV")
        XCTAssertNil(rows[0].landings)
        XCTAssertEqual(rows[0].remarks, "25 solo")
    }

    func testTokenShapes() {
        XCTAssertTrue(LogbookRowParser.isTailNumber("N737HW"))
        XCTAssertTrue(LogbookRowParser.isTailNumber("N1"))
        XCTAssertFalse(LogbookRowParser.isTailNumber("KPAO"))
        XCTAssertTrue(LogbookRowParser.isAircraftType("C172"))
        XCTAssertTrue(LogbookRowParser.isAircraftType("PA-28-181"))
        XCTAssertTrue(LogbookRowParser.isAircraftType("DA40"))
        XCTAssertFalse(LogbookRowParser.isAircraftType("N737HW"))
        XCTAssertTrue(LogbookRowParser.isAirportIdent("KPAO"))
        XCTAssertTrue(LogbookRowParser.isAirportIdent("3O1"))
        XCTAssertTrue(LogbookRowParser.isAirportIdent("SFO"))
        XCTAssertFalse(LogbookRowParser.isAirportIdent("solo"))
        XCTAssertFalse(LogbookRowParser.isAirportIdent("to"))
    }

    func testHoursOver24Rejected() {
        // An OCR artifact like "31.0" (page number + decimal) must not
        // become 31 logged hours.
        let rows = LogbookRowParser.parse("3/14/24 C172 N737HW KPAO KHAF 31.0 1.2")
        XCTAssertEqual(rows[0].totalHours, 1.2)
    }
}
