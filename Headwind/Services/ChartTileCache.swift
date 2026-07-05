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
/// powers offline area downloads.
///
/// Tiles live in durable Application Support storage (Caches gets purged),
/// partitioned by the 28-day cycle so a new chart edition is fetched fresh
/// rather than served stale forever; superseded cycles are pruned.
actor ChartTileCache {
    static let shared = ChartTileCache()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    private let rootDir = DurableStorage.directory("ChartTiles")
    private var prunedThisSession = false

    private var baseDir: URL {
        let cycle = AiracCalendar.cycleLabel(for: .now)
        let dir = rootDir.appendingPathComponent(cycle, isDirectory: true)
        if !prunedThisSession {
            prunedThisSession = true
            pruneCycles(keeping: cycle)
        }
        return dir
    }

    private func pruneCycles(keeping current: String) {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: rootDir, includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.lastPathComponent != current {
            try? FileManager.default.removeItem(at: url)
        }
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

    struct PrefetchResult: Sendable {
        var fetched = 0
        /// Tiles that failed — usually 404s outside the FAA chart's coverage
        /// footprint (normal at chart edges), or transient errors.
        var skipped = 0
    }

    /// Downloads every missing tile covering `bounds` across `zooms`.
    /// Individual tile failures are skipped, never fatal: FAA services
    /// return 404 for tiles outside a chart's coverage, and one bad tile
    /// must not abort a 4,000-tile download. Only cancellation stops it.
    func prefetch(
        layer: ChartLayer,
        bounds: GeoBounds,
        zooms: ClosedRange<Int>,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> PrefetchResult {
        let all = zooms.flatMap { TileMath.tiles(covering: bounds, zoom: $0) }
        let missing = all.filter { !FileManager.default.fileExists(atPath: fileURL(layer: layer, tile: $0).path) }
        var result = PrefetchResult()
        guard !missing.isEmpty else {
            progress(all.count, all.count)
            return result
        }

        var done = all.count - missing.count
        // Modest batches keep us polite to the FAA service and cancellable.
        for batch in stride(from: 0, to: missing.count, by: 6).map({ Array(missing[$0..<min($0 + 6, missing.count)]) }) {
            try Task.checkCancellation()
            let outcomes = await withTaskGroup(of: Bool.self) { group in
                for tile in batch {
                    group.addTask {
                        if Task.isCancelled { return false }
                        return (try? await self.tile(layer: layer, tile)) != nil
                    }
                }
                var oks: [Bool] = []
                for await ok in group { oks.append(ok) }
                return oks
            }
            try Task.checkCancellation()
            result.fetched += outcomes.filter { $0 }.count
            result.skipped += outcomes.filter { !$0 }.count
            done += batch.count
            progress(done, all.count)
        }
        return result
    }

    func cacheSizeBytes() -> Int64 {
        guard let files = FileManager.default.enumerator(
            at: rootDir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    func clear() {
        try? FileManager.default.removeItem(at: rootDir)
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
