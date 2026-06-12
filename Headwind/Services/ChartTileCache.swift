import Foundation
import HeadwindCore

/// The FAA-hosted chart raster layers (public ArcGIS tile services, no key).
enum ChartLayer: String, CaseIterable, Identifiable {
    case none
    case sectional
    case terminal
    case ifrLow
    case ifrHigh

    var id: String { rawValue }

    var serviceName: String? {
        switch self {
        case .none: nil
        case .sectional: "VFR_Sectional"
        case .terminal: "VFR_Terminal"
        case .ifrLow: "IFR_AreaLow"
        case .ifrHigh: "IFR_High"
        }
    }

    var title: String {
        switch self {
        case .none: "No Chart"
        case .sectional: "VFR Sectional"
        case .terminal: "VFR Terminal"
        case .ifrLow: "IFR Low"
        case .ifrHigh: "IFR High"
        }
    }
}

/// Disk-backed tile store for FAA chart layers: serves the moving map and
/// powers offline area downloads. Tiles live in Caches/ChartTiles/<layer>/.
actor ChartTileCache {
    static let shared = ChartTileCache()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    private var baseDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChartTiles", isDirectory: true)
    }

    /// Returns tile data, serving from disk when available.
    func tile(layer: ChartLayer, _ tile: TileID) async throws -> Data {
        let file = fileURL(layer: layer, tile: tile)
        if let data = try? Data(contentsOf: file), !data.isEmpty {
            return data
        }
        let data = try await fetch(layer: layer, tile: tile)
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: file)
        return data
    }

    /// Downloads every missing tile covering `bounds` across `zooms`.
    /// - Returns: number of tiles fetched (cached tiles are skipped).
    func prefetch(
        layer: ChartLayer,
        bounds: GeoBounds,
        zooms: ClosedRange<Int>,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> Int {
        let all = zooms.flatMap { TileMath.tiles(covering: bounds, zoom: $0) }
        let missing = all.filter { !FileManager.default.fileExists(atPath: fileURL(layer: layer, tile: $0).path) }
        guard !missing.isEmpty else {
            progress(all.count, all.count)
            return 0
        }

        var done = all.count - missing.count
        var fetched = 0
        // Modest batches keep us polite to the FAA service and cancellable.
        for batch in stride(from: 0, to: missing.count, by: 6).map({ Array(missing[$0..<min($0 + 6, missing.count)]) }) {
            try Task.checkCancellation()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for tile in batch {
                    group.addTask { _ = try await self.tile(layer: layer, tile) }
                }
                try await group.waitForAll()
            }
            done += batch.count
            fetched += batch.count
            progress(done, all.count)
        }
        return fetched
    }

    func cacheSizeBytes() -> Int64 {
        guard let files = FileManager.default.enumerator(
            at: baseDir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    func clear() {
        try? FileManager.default.removeItem(at: baseDir)
    }

    private func fileURL(layer: ChartLayer, tile: TileID) -> URL {
        baseDir
            .appendingPathComponent(layer.rawValue, isDirectory: true)
            .appendingPathComponent("\(tile.z)", isDirectory: true)
            .appendingPathComponent("\(tile.x)_\(tile.y).png")
    }

    private func fetch(layer: ChartLayer, tile: TileID) async throws -> Data {
        guard let service = layer.serviceName else { throw URLError(.badURL) }
        let url = URL(string:
            "https://tiles.arcgis.com/tiles/ssFJjBXIUyZDrSYZ/arcgis/rest/services/\(service)/MapServer/tile/\(tile.z)/\(tile.y)/\(tile.x)"
        )!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw URLError(.resourceUnavailable)
        }
        return data
    }
}
