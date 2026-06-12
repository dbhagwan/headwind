import XCTest
@testable import HeadwindCore

final class AirportDatabaseTests: XCTestCase {
    private let db = AirportDatabase(
        airports: [
            Airport(ident: "KSFO", iata: "SFO", name: "San Francisco International", city: "San Francisco", state: "CA",
                    coordinate: Coordinate(latitude: 37.6188, longitude: -122.3750), elevationFt: 13, kind: .large),
            Airport(ident: "KPAO", name: "Palo Alto", city: "Palo Alto", state: "CA",
                    coordinate: Coordinate(latitude: 37.4611, longitude: -122.1150), elevationFt: 4, kind: .small),
            Airport(ident: "KJFK", iata: "JFK", name: "John F Kennedy International", city: "New York", state: "NY",
                    coordinate: Coordinate(latitude: 40.6413, longitude: -73.7781), elevationFt: 13, kind: .large),
            Airport(ident: "KSAN", iata: "SAN", name: "San Diego International", city: "San Diego", state: "CA",
                    coordinate: Coordinate(latitude: 32.7336, longitude: -117.1897), elevationFt: 17, kind: .large),
        ],
        navaids: [
            Navaid(ident: "SFO", name: "San Francisco", type: "VOR-DME",
                   coordinate: Coordinate(latitude: 37.6195, longitude: -122.3740), frequencyKhz: 115_800),
            Navaid(ident: "OSI", name: "Woodside", type: "VORTAC",
                   coordinate: Coordinate(latitude: 37.3925, longitude: -122.2810), frequencyKhz: 113_900),
        ]
    )

    func testExactLookupByIdentAndIATA() {
        XCTAssertEqual(db.airport(ident: "KSFO")?.ident, "KSFO")
        XCTAssertEqual(db.airport(ident: "sfo")?.ident, "KSFO")
        XCTAssertEqual(db.airport(ident: " jfk ")?.ident, "KJFK")
        XCTAssertNil(db.airport(ident: "KZZZ"))
    }

    func testWaypointResolutionPrefersAirportThenNavaid() throws {
        XCTAssertEqual(db.waypoint(ident: "KSFO")?.ident, "KSFO")
        // Bare "SFO" resolves to the VOR, not KSFO's IATA code.
        let vor = try XCTUnwrap(db.waypoint(ident: "SFO"))
        XCTAssertEqual(vor.name, "San Francisco VOR-DME")
        XCTAssertEqual(db.waypoint(ident: "OSI")?.name, "Woodside VORTAC")
        // IATA still resolves when there's no navaid with that ident.
        XCTAssertEqual(db.waypoint(ident: "JFK")?.ident, "KJFK")
        XCTAssertNil(db.waypoint(ident: "XXXX"))
    }

    func testNavaidLookupAndFrequencyText() {
        XCTAssertEqual(db.navaid(ident: "osi")?.name, "Woodside")
        XCTAssertEqual(db.navaid(ident: "OSI")?.frequencyText, "113.9")
        XCTAssertEqual(Navaid(ident: "SF", name: "x", type: "NDB",
                              coordinate: Coordinate(latitude: 0, longitude: 0),
                              frequencyKhz: 362).frequencyText, "362")
    }

    func testSearchRanksExactIdentFirstThenKind() {
        XCTAssertEqual(db.search("SFO").first?.ident, "KSFO")
        // "san" matches several cities/names; large airports rank by ident.
        let san = db.search("san")
        XCTAssertEqual(san.first?.ident, "KSAN")
        XCTAssertTrue(db.search("").isEmpty)
    }

    func testSearchMatchesNameAndCity() {
        XCTAssertEqual(db.search("kennedy").first?.ident, "KJFK")
        XCTAssertEqual(db.search("palo alto").first?.ident, "KPAO")
    }

    func testNearestOrdersByDistance() {
        let nearPaloAlto = Coordinate(latitude: 37.45, longitude: -122.1)
        let results = db.nearest(to: nearPaloAlto, limit: 2)
        XCTAssertEqual(results.map(\.ident), ["KPAO", "KSFO"])
    }

    func testBoundsQueryFiltersKindAndRegion() {
        let bayArea = GeoBounds(minLat: 37.0, maxLat: 38.0, minLon: -123.0, maxLon: -121.5)
        XCTAssertEqual(db.airports(within: bayArea, kinds: [.large]).map(\.ident), ["KSFO"])
        XCTAssertEqual(
            Set(db.airports(within: bayArea, kinds: [.large, .small]).map(\.ident)),
            ["KSFO", "KPAO"]
        )
    }

    func testBoundsAntimeridianWrap() {
        let aleutians = GeoBounds(minLat: 50, maxLat: 55, minLon: 170, maxLon: -160)
        XCTAssertTrue(aleutians.contains(Coordinate(latitude: 52.8, longitude: 173.2)))
        XCTAssertTrue(aleutians.contains(Coordinate(latitude: 52.0, longitude: -176.0)))
        XCTAssertFalse(aleutians.contains(Coordinate(latitude: 52.0, longitude: -150.0)))
    }
}
