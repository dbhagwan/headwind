import MapKit
import UIKit

/// Live NEXRAD reflectivity, rendered the modern way.
///
/// Raw IEM n0q tiles are color-mapped ~1 km radar cells — block-stretched
/// squares at street zoom, plus sub-20 dBZ blue noise that carpets the
/// map on drizzly days. Instead of drawing those pixels, this overlay:
///
///  1. sources tiles at z9, where one radar cell ≈ 3 tile pixels (deeper
///     zooms are just IEM upsampling the same cells),
///  2. decodes each pixel's palette color back to a scalar intensity,
///  3. gaussian-smooths and bicubic-upscales that *field* (interpolating
///     physics, not colors — this is what makes contours organic),
///  4. re-colors through a continuous modern gradient with a baked
///     alpha ramp, discarding sub-threshold noise.
///
/// A 3×3 source-tile mosaic supplies real neighbor data so smoothing is
/// seamless across tile boundaries (URLCache dedupes the shared fetches).
/// The look was prototyped and tuned against live storm data before this
/// port; keep the Python reference in the PR history in sync if tuning.
final class RadarTileOverlay: MKTileOverlay {
    /// One radar cell ≈ 3 px here; beyond this IEM upsamples.
    private static let sourceMaxZ = 9
    private static let tilePx = 256
    private static let mosaicPx = 768

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
        Task.detached(priority: .utility) {
            do {
                let data = try await self.renderTile(at: path)
                result(data, nil)
            } catch {
                result(nil, error)
            }
        }
    }

    private func renderTile(at path: MKTileOverlayPath) async throws -> Data? {
        let srcZ = min(path.z, Self.sourceMaxZ)
        let shift = path.z - srcZ
        let srcX = path.x >> shift
        let srcY = path.y >> shift

        // 3×3 source mosaic centered on the tile's parent.
        var images = [UIImage?](repeating: nil, count: 9)
        try await withThrowingTaskGroup(of: (Int, UIImage?).self) { group in
            for dy in -1...1 {
                for dx in -1...1 {
                    let index = (dy + 1) * 3 + (dx + 1)
                    let url = self.url(forTilePath: MKTileOverlayPath(
                        x: srcX + dx, y: srcY + dy, z: srcZ,
                        contentScaleFactor: path.contentScaleFactor))
                    group.addTask {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return (index, UIImage(data: data))
                    }
                }
            }
            for try await (index, image) in group {
                images[index] = image
            }
        }

        var field = Self.decodeMosaic(images)
        Self.blur(&field, sigma: shift > 0 ? 1.6 : 0.8)
        return Self.renderRegion(field: field, path: path, shift: shift)
    }

    // MARK: Palette decode

    /// Maps an n0q palette color to monotonic intensity 0…1. Sub-20 dBZ
    /// blues score below the display threshold: they inform smoothing at
    /// echo edges but never render. Derived from live-tile calibration.
    private static func intensity(r: Int, g: Int, b: Int) -> Float {
        if b > g && g > r && r < 150 { return 0.08 }                     // blue noise
        if g >= r && g >= b {                                            // greens 20–35 dBZ
            if b > 30 { return 0.15 + 0.20 * Float(min(max(214 - b, 0), 190)) / 190 }
            return 0.35 + 0.15 * Float(min(max(214 - g, 0), 100)) / 100
        }
        if r > 200 && g > 130 { return 0.50 + 0.20 * Float(min(max(255 - g, 0), 125)) / 125 } // yellow→orange
        if r > 150 && g <= 130 && b < 120 { return 0.70 + 0.15 * Float(min(max(130 - g, 0), 130)) / 130 } // red
        if r > 140 && b > 140 && g < 120 { return 0.85 + 0.15 * Float(min(b, 255)) / 255 }    // magenta
        return 0.18
    }

    private static func decodeMosaic(_ images: [UIImage?]) -> [Float] {
        var field = [Float](repeating: 0, count: mosaicPx * mosaicPx)
        let size = tilePx
        guard let ctx = CGContext(
            data: nil, width: mosaicPx, height: mosaicPx,
            bitsPerComponent: 8, bytesPerRow: mosaicPx * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return field }
        for (index, image) in images.enumerated() {
            guard let cg = image?.cgImage else { continue }
            let col = index % 3, row = index / 3
            // CG y-axis is bottom-up; mosaic row 0 is the top strip.
            ctx.draw(cg, in: CGRect(x: col * size, y: (2 - row) * size, width: size, height: size))
        }
        guard let buf = ctx.data else { return field }
        let px = buf.bindMemory(to: UInt8.self, capacity: mosaicPx * mosaicPx * 4)
        for j in 0..<mosaicPx {
            for i in 0..<mosaicPx {
                let o = (j * mosaicPx + i) * 4
                if px[o + 3] > 0 {
                    field[j * mosaicPx + i] = intensity(r: Int(px[o]), g: Int(px[o + 1]), b: Int(px[o + 2]))
                }
            }
        }
        return field
    }

    // MARK: Field smoothing

    private static func blur(_ field: inout [Float], sigma: Float) {
        let radius = Int(3 * sigma)
        guard radius > 0 else { return }
        var kernel = [Float](repeating: 0, count: 2 * radius + 1)
        var sum: Float = 0
        for i in -radius...radius {
            let v = expf(-Float(i * i) / (2 * sigma * sigma))
            kernel[i + radius] = v
            sum += v
        }
        for i in kernel.indices { kernel[i] /= sum }

        let n = mosaicPx
        var pass = [Float](repeating: 0, count: n * n)
        for j in 0..<n {                       // horizontal
            for i in 0..<n {
                var acc: Float = 0
                for k in -radius...radius {
                    let x = min(max(i + k, 0), n - 1)
                    acc += field[j * n + x] * kernel[k + radius]
                }
                pass[j * n + i] = acc
            }
        }
        for j in 0..<n {                       // vertical
            for i in 0..<n {
                var acc: Float = 0
                for k in -radius...radius {
                    let y = min(max(j + k, 0), n - 1)
                    acc += pass[y * n + i] * kernel[k + radius]
                }
                field[j * n + i] = acc
            }
        }
    }

    // MARK: Render

    /// Continuous gradient LUT: intensity byte → premultiplied RGBA.
    /// Soft mint → green → amber → orange → red → magenta, alpha ramp
    /// 0.45…0.85, transparent below the noise threshold.
    private static let lut: [(UInt8, UInt8, UInt8, UInt8)] = {
        let stops: [(Float, (Float, Float, Float))] = [
            (0.15, (64, 190, 140)), (0.35, (70, 210, 90)), (0.50, (240, 205, 90)),
            (0.65, (245, 150, 70)), (0.80, (235, 80, 70)), (1.00, (205, 70, 200)),
        ]
        return (0..<256).map { v in
            let t = Float(v) / 255
            guard t >= 0.15 else { return (0, 0, 0, 0) }
            let tc = min(t, 1)
            var color: (Float, Float, Float) = stops.last!.1
            for ((t0, c0), (t1, c1)) in zip(stops, stops.dropFirst()) where tc >= t0 && tc <= t1 {
                let f = (tc - t0) / (t1 - t0)
                color = (c0.0 + (c1.0 - c0.0) * f, c0.1 + (c1.1 - c0.1) * f, c0.2 + (c1.2 - c0.2) * f)
            }
            let alpha = 0.45 + 0.40 * (tc - 0.15) / 0.85
            return (UInt8(color.0 * alpha), UInt8(color.1 * alpha), UInt8(color.2 * alpha),
                    UInt8(alpha * 255))
        }
    }()

    private static func renderRegion(field: [Float], path: MKTileOverlayPath, shift: Int) -> Data? {
        let size = tilePx
        // Grayscale image of the field, upscaled smoothly by CG, then
        // colored through the LUT.
        var gray = [UInt8](repeating: 0, count: mosaicPx * mosaicPx)
        for i in 0..<field.count {
            gray[i] = UInt8(min(max(field[i], 0), 1) * 255)
        }
        let grayData = Data(gray)
        guard let provider = CGDataProvider(data: grayData as CFData),
              let grayImage = CGImage(
                width: mosaicPx, height: mosaicPx, bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: mosaicPx, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }

        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        ) else { return nil }

        // This tile covers a (256 >> shift)-px window of the center
        // mosaic tile; scale the whole mosaic so that window fills the
        // context (same flip convention as decodeMosaic).
        let f = CGFloat(1 << shift)
        let window = CGFloat(size) / f
        let subX = CGFloat(path.x & ((1 << shift) - 1))
        let subY = CGFloat(path.y & ((1 << shift) - 1))
        let originX = CGFloat(size) + subX * window
        let originYTop = CGFloat(size) + subY * window
        ctx.interpolationQuality = .high
        ctx.draw(grayImage, in: CGRect(
            x: -originX * f,
            y: -(CGFloat(mosaicPx) - originYTop - window) * f,
            width: CGFloat(mosaicPx) * f,
            height: CGFloat(mosaicPx) * f
        ))
        guard let grayOut = ctx.data else { return nil }
        let g = grayOut.bindMemory(to: UInt8.self, capacity: size * size)

        var rgba = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let c = lut[Int(g[i])]
            rgba[i * 4] = c.0; rgba[i * 4 + 1] = c.1; rgba[i * 4 + 2] = c.2; rgba[i * 4 + 3] = c.3
        }
        let rgbaData = Data(rgba)
        guard let rgbaProvider = CGDataProvider(data: rgbaData as CFData),
              let out = CGImage(
                width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: rgbaProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: out).pngData()
    }
}
