import Foundation
import Observation
import HeadwindCore

/// Streams Class B/C/D airspace geometry from the FAA AIS feature service
/// for the clean "aeronautical" map mode.
///
/// Coverage is fetched in 2°×2° cells as the camera moves, deduplicated by
/// stable volume IDs, and kept for the session.
@MainActor
@Observable
final class AirspaceService {
    private(set) var volumesByID: [String: AirspaceVolume] = [:]
    private(set) var lastError: String?

    private var fetchedCells: Set<String> = []
    private var inFlightCells: Set<String> = []

    var all: [AirspaceVolume] { Array(volumesByID.values) }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    /// Ensures airspace geometry is loaded for every grid cell the given
    /// bounds touch. Skipped when zoomed out so far the rings would be noise.
    func ensureCoverage(of bounds: GeoBounds) async {
        let span = max(bounds.maxLat - bounds.minLat, bounds.maxLon - bounds.minLon)
        guard span < 8 else { return }

        for cell in cells(covering: bounds) {
            guard !fetchedCells.contains(cell.key), !inFlightCells.contains(cell.key) else { continue }
            inFlightCells.insert(cell.key)
            defer { inFlightCells.remove(cell.key) }

            do {
                let volumes = try await Self.fetch(cell: cell.bounds)
                for volume in volumes {
                    volumesByID[volume.id] = volume
                }
                fetchedCells.insert(cell.key)
                lastError = nil
            } catch {
                // Leave the cell unmarked; it retries on the next pan.
                lastError = "Couldn't load airspace: \(error.localizedDescription)"
            }
        }
    }

    private struct Cell {
        let key: String
        let bounds: GeoBounds
    }

    private func cells(covering bounds: GeoBounds) -> [Cell] {
        let step = 2.0
        let minLat = (bounds.minLat / step).rounded(.down) * step
        let maxLat = (bounds.maxLat / step).rounded(.down) * step
        let minLon = (bounds.minLon / step).rounded(.down) * step
        let maxLon = (bounds.maxLon / step).rounded(.down) * step

        var result: [Cell] = []
        var lat = minLat
        while lat <= maxLat {
            var lon = minLon
            while lon <= maxLon {
                result.append(Cell(
                    key: "\(Int(lat))_\(Int(lon))",
                    bounds: GeoBounds(minLat: lat, maxLat: lat + step, minLon: lon, maxLon: lon + step)
                ))
                lon += step
            }
            lat += step
        }
        return result
    }

    private nonisolated static func fetch(cell: GeoBounds) async throws -> [AirspaceVolume] {
        var components = URLComponents(
            string: "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/arcgis/rest/services/Airspace/FeatureServer/0/query"
        )!
        components.queryItems = [
            URLQueryItem(name: "where", value: "CLASS_CODE IN ('B','C','D')"),
            URLQueryItem(name: "geometry", value: "\(cell.minLon),\(cell.minLat),\(cell.maxLon),\(cell.maxLat)"),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "IDENT_TXT,NAME_TXT,CLASS_CODE,DISTVERTLOWER_VAL,DISTVERTUPPER_VAL"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "f", value: "geojson"),
        ]
        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return AirspaceGeoJSON.volumes(from: data)
    }
}
