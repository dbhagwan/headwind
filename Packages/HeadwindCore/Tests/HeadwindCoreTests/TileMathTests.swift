import XCTest
@testable import HeadwindCore

final class TileMathTests: XCTestCase {
    func testKnownTiles() {
        // Ground truth computed independently from the slippy-map formulas;
        // the SF tile was verified against a live FAA VFR_Sectional fetch.
        XCTAssertEqual(
            TileMath.tile(for: Coordinate(latitude: 41.85, longitude: -87.65), zoom: 17),
            TileID(z: 17, x: 33623, y: 48729)
        )
        XCTAssertEqual(
            TileMath.tile(for: Coordinate(latitude: 37.6188, longitude: -122.375), zoom: 10),
            TileID(z: 10, x: 163, y: 396)
        )
        XCTAssertEqual(
            TileMath.tile(for: Coordinate(latitude: -33.8688, longitude: 151.2093), zoom: 12),
            TileID(z: 12, x: 3768, y: 2457)
        )
    }

    func testZoomZeroIsSingleTile() {
        XCTAssertEqual(
            TileMath.tile(for: Coordinate(latitude: 37, longitude: -122), zoom: 0),
            TileID(z: 0, x: 0, y: 0)
        )
    }

    func testPolarLatitudeIsClamped() {
        let north = TileMath.tile(for: Coordinate(latitude: 89.9, longitude: 0), zoom: 5)
        XCTAssertEqual(north.y, 0)
        let south = TileMath.tile(for: Coordinate(latitude: -89.9, longitude: 0), zoom: 5)
        XCTAssertEqual(south.y, 31)
    }

    func testTilesCoveringRegion() {
        // Bay Area box at z10: spans a few tiles in each axis.
        let bounds = GeoBounds(minLat: 37.0, maxLat: 38.0, minLon: -123.0, maxLon: -121.5)
        let tiles = TileMath.tiles(covering: bounds, zoom: 10)
        XCTAssertFalse(tiles.isEmpty)
        // Every tile must contain itself in the cover, including corners.
        let corner = TileMath.tile(for: Coordinate(latitude: 37.0, longitude: -123.0), zoom: 10)
        XCTAssertTrue(tiles.contains(corner))
        // Count must match the rect dimensions exactly.
        let tl = TileMath.tile(for: Coordinate(latitude: 38.0, longitude: -123.0), zoom: 10)
        let br = TileMath.tile(for: Coordinate(latitude: 37.0, longitude: -121.5), zoom: 10)
        XCTAssertEqual(tiles.count, (br.x - tl.x + 1) * (br.y - tl.y + 1))
    }

    func testTileCountAcrossZoomsMatchesEnumeration() {
        let bounds = GeoBounds(minLat: 37.0, maxLat: 38.0, minLon: -123.0, maxLon: -121.5)
        let counted = TileMath.tileCount(covering: bounds, zooms: 8...11)
        let enumerated = (8...11).reduce(0) { $0 + TileMath.tiles(covering: bounds, zoom: $1).count }
        XCTAssertEqual(counted, enumerated)
        XCTAssertGreaterThan(counted, 0)
    }
}
