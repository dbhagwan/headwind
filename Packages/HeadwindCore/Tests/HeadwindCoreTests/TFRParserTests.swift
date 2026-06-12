import XCTest
@testable import HeadwindCore

final class TFRParserTests: XCTestCase {
    private let fixture = """
    <XNOTAM-Update version="0.1">
      <Group><Add><Not>
        <dateEffective>2026-06-12T03:18:00</dateEffective>
        <TfrNot>
          <TFRAreaGroup>
            <abdMergedArea>
              <Avx><geoLat>39.10N</geoLat><geoLong>106.50W</geoLong></Avx>
              <Avx><geoLat>39.20N</geoLat><geoLong>106.50W</geoLong></Avx>
              <Avx><geoLat>39.20N</geoLat><geoLong>106.40W</geoLong></Avx>
              <Avx><geoLat>39.10N</geoLat><geoLong>106.40W</geoLong></Avx>
            </abdMergedArea>
          </TFRAreaGroup>
          <TFRAreaGroup>
            <abdMergedArea>
              <Avx><geoLat>40.00N</geoLat><geoLong>105.00W</geoLong></Avx>
              <Avx><geoLat>40.10N</geoLat><geoLong>105.00W</geoLong></Avx>
              <Avx><geoLat>40.05N</geoLat><geoLong>104.90W</geoLong></Avx>
            </abdMergedArea>
          </TFRAreaGroup>
        </TfrNot>
      </Not></Add></Group>
    </XNOTAM-Update>
    """

    func testParsesMultipleAreaGroups() throws {
        let polygons = TFRShapeParser.polygons(from: Data(fixture.utf8))
        XCTAssertEqual(polygons.count, 2)
        XCTAssertEqual(polygons[0].count, 4)
        XCTAssertEqual(polygons[1].count, 3)

        let first = try XCTUnwrap(polygons.first?.first)
        XCTAssertEqual(first.latitude, 39.10, accuracy: 1e-9)
        XCTAssertEqual(first.longitude, -106.50, accuracy: 1e-9)
    }

    func testHemisphereParsing() {
        XCTAssertEqual(TFRShapeParser.parseDegrees("39.392N", positive: "N", negative: "S"), 39.392)
        XCTAssertEqual(TFRShapeParser.parseDegrees("12.5S", positive: "N", negative: "S"), -12.5)
        XCTAssertEqual(TFRShapeParser.parseDegrees("106.686W", positive: "E", negative: "W"), -106.686)
        XCTAssertEqual(TFRShapeParser.parseDegrees("151.2E", positive: "E", negative: "W"), 151.2)
        XCTAssertNil(TFRShapeParser.parseDegrees("garbage", positive: "N", negative: "S"))
        XCTAssertNil(TFRShapeParser.parseDegrees("", positive: "N", negative: "S"))
    }

    func testDegenerateRingsAreDropped() {
        let xml = """
        <XNOTAM-Update><TfrNot><TFRAreaGroup><abdMergedArea>
          <Avx><geoLat>39.10N</geoLat><geoLong>106.50W</geoLong></Avx>
          <Avx><geoLat>39.20N</geoLat><geoLong>106.50W</geoLong></Avx>
        </abdMergedArea></TFRAreaGroup></TfrNot></XNOTAM-Update>
        """
        XCTAssertTrue(TFRShapeParser.polygons(from: Data(xml.utf8)).isEmpty)
    }

    func testListItemDecoding() throws {
        let json = """
        [{"notam_id":"6/7811","type":"HAZARDS","facility":"ZDV","state":"CO",
          "description":"29NM SE GLENWOOD SPRINGS, CO","creation_date":"06/12/2026"}]
        """
        let items = try JSONDecoder().decode([TFRListItem].self, from: Data(json.utf8))
        XCTAssertEqual(items.first?.notamID, "6/7811")
        XCTAssertEqual(items.first?.detailIdent, "6_7811")
        XCTAssertEqual(items.first?.type, "HAZARDS")
    }
}
