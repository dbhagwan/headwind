import Foundation
import Observation
import HeadwindCore

/// Fetches active Temporary Flight Restrictions from tfr.faa.gov:
/// the list API for metadata, then each NOTAM's detail XML for geometry.
@MainActor
@Observable
final class TFRService {
    private(set) var tfrs: [TFR] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?

    /// Geometry rarely changes for a given NOTAM; cache it across refreshes.
    private var geometryCache: [String: [[Coordinate]]] = [:]

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let listURL = URL(string: "https://tfr.faa.gov/tfrapi/exportTfrList")!
            let (data, _) = try await Self.session.data(from: listURL)
            let items = try JSONDecoder().decode([TFRListItem].self, from: data)

            let known = geometryCache
            var resolved: [TFR] = []
            var newGeometry: [String: [[Coordinate]]] = [:]

            // Resolve geometry in small batches; failures drop that TFR only.
            for batch in stride(from: 0, to: items.count, by: 6)
                .map({ Array(items[$0..<min($0 + 6, items.count)]) }) {
                await withTaskGroup(of: (String, [[Coordinate]])?.self) { group in
                    for item in batch {
                        if let cached = known[item.notamID] {
                            resolved.append(TFR(item: item, polygons: cached))
                            continue
                        }
                        group.addTask {
                            await Self.fetchGeometry(for: item)
                        }
                    }
                    for await result in group {
                        guard let (id, polygons) = result, !polygons.isEmpty,
                              let item = batch.first(where: { $0.notamID == id }) else { continue }
                        newGeometry[id] = polygons
                        resolved.append(TFR(item: item, polygons: polygons))
                    }
                }
            }

            geometryCache.merge(newGeometry) { _, new in new }
            tfrs = resolved.sorted { $0.id > $1.id }
            lastUpdated = .now
            lastError = nil
        } catch {
            lastError = "Couldn't load TFRs: \(error.localizedDescription)"
        }
    }

    private nonisolated static func fetchGeometry(for item: TFRListItem) async -> (String, [[Coordinate]])? {
        let url = URL(string: "https://tfr.faa.gov/download/detail_\(item.detailIdent).xml")!
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (item.notamID, TFRShapeParser.polygons(from: data))
    }
}
