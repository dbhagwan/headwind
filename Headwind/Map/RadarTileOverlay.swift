import MapKit
import UIKit

/// Live NEXRAD composite reflectivity tiles from the Iowa Environmental
/// Mesonet's public cache of NWS radar (no key required). Radar refreshes
/// roughly every 5 minutes; the URL carries a 5-minute time bucket so
/// MapKit's tile cache rolls over as new sweeps arrive.
///
/// Tiles are post-processed on device before display:
/// - Sub-20 dBZ returns (clear-air and drizzle noise, the n0q palette's
///   blue bins) are stripped — they otherwise carpet the whole map on a
///   light-rain day and bury the chart.
/// - Past the source's native zoom (12), tiles are synthesized by
///   smoothly upscaling the parent tile's quadrant instead of letting
///   MapKit block-stretch them into giant pixels.
final class RadarTileOverlay: MKTileOverlay {
    /// IEM serves n0q up to z12; beyond that we synthesize.
    private static let nativeMaxZ = 12
    private static let tilePx = 256

    init() {
        super.init(urlTemplate: nil)
        minimumZ = 3
        maximumZ = 19
        canReplaceMapContent = false
        tileSize = CGSize(width: Self.tilePx, height: Self.tilePx)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let bucket = Int(Date.now.timeIntervalSince1970 / 300)
        return URL(string:
            "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/\(path.z)/\(path.x)/\(path.y).png?ts=\(bucket)"
        )!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let dz = max(0, path.z - Self.nativeMaxZ)
        var source = path
        if dz > 0 {
            source = MKTileOverlayPath(
                x: path.x >> dz, y: path.y >> dz, z: path.z - dz,
                contentScaleFactor: path.contentScaleFactor
            )
        }
        URLSession.shared.dataTask(with: url(forTilePath: source)) { data, _, error in
            guard let data else {
                result(nil, error)
                return
            }
            result(Self.process(data, forQuadrantOf: path, dz: dz) ?? data, nil)
        }.resume()
    }

    /// Crops/upscales the source tile to the requested overzoom quadrant
    /// (bilinear, not blocky) and strips low-reflectivity noise.
    ///
    /// Noise classifier, validated against live IEM tiles: the sub-20 dBZ
    /// palette runs dark blue → cyan, always with b > g > r and a low red
    /// channel. Real precipitation is green-dominant (20–35 dBZ), then
    /// yellow/orange/red, then magenta (65+), where red is high or green
    /// is not between the other two — none match the test.
    private static func process(_ data: Data, forQuadrantOf path: MKTileOverlayPath, dz: Int) -> Data? {
        guard let source = UIImage(data: data)?.cgImage else { return nil }
        let size = tilePx
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the source scaled 2^dz, offset so the requested quadrant
        // fills the context. Tile y counts from the top; CG's y-axis
        // points up, hence the (scale-1-subY) flip. Validated against
        // real z10 tiles synthesized from their z8 parents.
        let scale = CGFloat(1 << dz)
        let subX = CGFloat(path.x & ((1 << dz) - 1))
        let subY = CGFloat(path.y & ((1 << dz) - 1))
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(
            x: -subX * CGFloat(size),
            y: -(scale - 1 - subY) * CGFloat(size),
            width: CGFloat(size) * scale,
            height: CGFloat(size) * scale
        ))

        guard let buffer = ctx.data else { return nil }
        let px = buffer.bindMemory(to: UInt8.self, capacity: size * size * 4)
        for i in stride(from: 0, to: size * size * 4, by: 4) {
            let r = px[i], g = px[i + 1], b = px[i + 2], a = px[i + 3]
            if a > 0, b > g, g > r, r < 150 {
                px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0
            }
        }

        guard let output = ctx.makeImage() else { return nil }
        return UIImage(cgImage: output).pngData()
    }
}
