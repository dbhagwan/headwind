import Foundation

/// One tile address in the web-mercator "slippy map" scheme used by the
/// FAA chart tile services.
public struct TileID: Hashable, Sendable {
    public let z: Int
    public let x: Int
    public let y: Int

    public init(z: Int, x: Int, y: Int) {
        self.z = z
        self.x = x
        self.y = y
    }
}

/// Web-mercator tile arithmetic for chart caching and offline downloads.
public enum TileMath {
    /// The tile containing a coordinate at a zoom level.
    public static func tile(for coordinate: Coordinate, zoom: Int) -> TileID {
        let n = Double(1 << zoom)
        let clampedLat = min(max(coordinate.latitude, -85.05112878), 85.05112878)
        let latRad = clampedLat * .pi / 180

        var x = Int(((coordinate.longitude + 180) / 360) * n)
        var y = Int((1 - log(tan(latRad) + 1 / cos(latRad)) / .pi) / 2 * n)
        x = min(max(x, 0), Int(n) - 1)
        y = min(max(y, 0), Int(n) - 1)
        return TileID(z: zoom, x: x, y: y)
    }

    /// All tiles covering a bounding box at one zoom level. Handles
    /// antimeridian wrap (minLon > maxLon) by walking x modulo 2^z.
    public static func tiles(covering bounds: GeoBounds, zoom: Int) -> [TileID] {
        let n = 1 << zoom
        let topLeft = tile(for: Coordinate(latitude: bounds.maxLat, longitude: bounds.minLon), zoom: zoom)
        let bottomRight = tile(for: Coordinate(latitude: bounds.minLat, longitude: bounds.maxLon), zoom: zoom)
        guard topLeft.y <= bottomRight.y else { return [] }

        let xSpan = bottomRight.x >= topLeft.x
            ? bottomRight.x - topLeft.x + 1
            : n - topLeft.x + bottomRight.x + 1

        var result: [TileID] = []
        for step in 0..<xSpan {
            let x = (topLeft.x + step) % n
            for y in topLeft.y...bottomRight.y {
                result.append(TileID(z: zoom, x: x, y: y))
            }
        }
        return result
    }

    /// Total tile count covering a bounding box across a zoom range —
    /// used to size offline downloads before starting them.
    public static func tileCount(covering bounds: GeoBounds, zooms: ClosedRange<Int>) -> Int {
        zooms.reduce(0) { count, z in
            let n = 1 << z
            let tl = tile(for: Coordinate(latitude: bounds.maxLat, longitude: bounds.minLon), zoom: z)
            let br = tile(for: Coordinate(latitude: bounds.minLat, longitude: bounds.maxLon), zoom: z)
            guard tl.y <= br.y else { return count }
            let xSpan = br.x >= tl.x ? br.x - tl.x + 1 : n - tl.x + br.x + 1
            return count + xSpan * (br.y - tl.y + 1)
        }
    }
}
