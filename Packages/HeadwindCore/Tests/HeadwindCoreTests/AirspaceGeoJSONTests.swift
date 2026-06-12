import XCTest
@testable import HeadwindCore

final class AirspaceGeoJSONTests: XCTestCase {
    private let fixture = """
    {"type":"FeatureCollection","features":[
      {"type":"Feature",
       "properties":{"IDENT_TXT":"KSFO","NAME_TXT":"SAN FRANCISCO CLASS B","CLASS_CODE":"B",
                     "DISTVERTLOWER_VAL":1500,"DISTVERTUPPER_VAL":10000},
       "geometry":{"type":"Polygon","coordinates":[
         [[-122.5,37.5],[-122.5,37.8],[-122.2,37.8],[-122.2,37.5],[-122.5,37.5]]]}},
      {"type":"Feature",
       "properties":{"IDENT_TXT":"KSJC","NAME_TXT":"SAN JOSE CLASS C","CLASS_CODE":"C",
                     "DISTVERTLOWER_VAL":0,"DISTVERTUPPER_VAL":4000},
       "geometry":{"type":"MultiPolygon","coordinates":[
         [[[-121.95,37.3],[-121.95,37.45],[-121.85,37.45],[-121.95,37.3]]],
         [[[-122.0,37.2],[-122.0,37.25],[-121.95,37.25],[-122.0,37.2]]]]}},
      {"type":"Feature",
       "properties":{"NAME_TXT":"SOMETHING CLASS E","CLASS_CODE":"E"},
       "geometry":{"type":"Polygon","coordinates":[[[-120,37],[-120,38],[-119,38],[-120,37]]]}},
      {"type":"Feature",
       "properties":{"NAME_TXT":"DEGENERATE","CLASS_CODE":"D"},
       "geometry":{"type":"Polygon","coordinates":[[[-120,37],[-120,38]]]}}
    ]}
    """

    func testDecodesClassBPolygon() throws {
        let volumes = AirspaceGeoJSON.volumes(from: Data(fixture.utf8))
        let classB = try XCTUnwrap(volumes.first { $0.airspaceClass == .b })

        XCTAssertEqual(classB.ident, "KSFO")
        XCTAssertEqual(classB.name, "SAN FRANCISCO CLASS B")
        XCTAssertEqual(classB.lowerFt, 1500)
        XCTAssertEqual(classB.upperFt, 10000)
        XCTAssertEqual(classB.polygons.count, 1)
        XCTAssertEqual(classB.polygons[0].count, 5)
        XCTAssertEqual(classB.polygons[0][0].latitude, 37.5, accuracy: 1e-9)
        XCTAssertEqual(classB.polygons[0][0].longitude, -122.5, accuracy: 1e-9)
    }

    func testDecodesMultiPolygonAsMultipleRings() throws {
        let volumes = AirspaceGeoJSON.volumes(from: Data(fixture.utf8))
        let classC = try XCTUnwrap(volumes.first { $0.airspaceClass == .c })
        XCTAssertEqual(classC.polygons.count, 2)
    }

    func testUnknownClassAndDegenerateRingsSkipped() {
        let volumes = AirspaceGeoJSON.volumes(from: Data(fixture.utf8))
        XCTAssertEqual(volumes.count, 2)
        XCTAssertFalse(volumes.contains { $0.name.contains("CLASS E") })
        XCTAssertFalse(volumes.contains { $0.name == "DEGENERATE" })
    }

    func testStableIDsAcrossReparses() throws {
        let first = AirspaceGeoJSON.volumes(from: Data(fixture.utf8))
        let second = AirspaceGeoJSON.volumes(from: Data(fixture.utf8))
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(Set(first.map(\.id)).count, first.count)
    }

    func testGarbageReturnsEmpty() {
        XCTAssertTrue(AirspaceGeoJSON.volumes(from: Data("not json".utf8)).isEmpty)
        XCTAssertTrue(AirspaceGeoJSON.volumes(from: Data("{}".utf8)).isEmpty)
    }
}
