import XCTest
@testable import HeadwindCore

final class AirportDatabaseTests: XCTestCase {
    private let db = AirportDatabase(airports: [
        Airport(icao: "KSFO", iata: "SFO", name: "San Francisco International", city: "San Francisco", state: "CA",
                coordinate: Coordinate(latitude: 37.6188, longitude: -122.3750), elevationFt: 13),
        Airport(icao: "KPAO", name: "Palo Alto", city: "Palo Alto", state: "CA",
                coordinate: Coordinate(latitude: 37.4611, longitude: -122.1150), elevationFt: 4),
        Airport(icao: "KJFK", iata: "JFK", name: "John F Kennedy International", city: "New York", state: "NY",
                coordinate: Coordinate(latitude: 40.6413, longitude: -73.7781), elevationFt: 13),
    ])

    func testExactLookupByICAOAndIATA() {
        XCTAssertEqual(db.airport(ident: "KSFO")?.icao, "KSFO")
        XCTAssertEqual(db.airport(ident: "sfo")?.icao, "KSFO")
        XCTAssertEqual(db.airport(ident: " jfk ")?.icao, "KJFK")
        XCTAssertNil(db.airport(ident: "KZZZ"))
    }

    func testSearchRanksExactIdentFirst()  {
        let results = db.search("SFO")
        XCTAssertEqual(results.first?.icao, "KSFO")
    }

    func testSearchMatchesNameAndCity() {
        XCTAssertEqual(db.search("kennedy").first?.icao, "KJFK")
        XCTAssertEqual(db.search("palo alto").first?.icao, "KPAO")
    }

    func testNearestOrdersByDistance() {
        let nearPaloAlto = Coordinate(latitude: 37.45, longitude: -122.1)
        let results = db.nearest(to: nearPaloAlto, limit: 2)
        XCTAssertEqual(results.map(\.icao), ["KPAO", "KSFO"])
    }
}
