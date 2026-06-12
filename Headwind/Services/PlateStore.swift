import Foundation
import Observation
import HeadwindCore

/// Loads the bundled d-TPP plate index and caches downloaded plate PDFs
/// on disk for offline use.
@MainActor
@Observable
final class PlateStore {
    private(set) var index = PlateIndex(cycle: "", airports: [:])
    private(set) var isLoading = true
    private var loadTask: Task<Void, Never>?

    var cycle: String { index.cycle }

    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
    }

    private func performLoad() async {
        let loaded = await Task.detached(priority: .userInitiated) { () -> PlateIndex in
            guard let url = Bundle.main.url(forResource: "us-plates", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let index = try? JSONDecoder().decode(PlateIndex.self, from: data) else {
                assertionFailure("Bundled us-plates.json missing or malformed")
                return PlateIndex(cycle: "", airports: [:])
            }
            return index
        }.value
        index = loaded
        isLoading = false
    }
}

/// Disk-backed store for plate PDFs, keyed by cycle so stale plates
/// never survive a cycle change.
actor PlateCache {
    static let shared = PlateCache()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    private var baseDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plates", isDirectory: true)
    }

    func pdf(cycle: String, pdfName: String) async throws -> Data {
        let file = baseDir
            .appendingPathComponent(cycle, isDirectory: true)
            .appendingPathComponent(pdfName.lowercased())
        if let data = try? Data(contentsOf: file), !data.isEmpty {
            return data
        }

        let url = URL(string: "https://aeronav.faa.gov/d-tpp/\(cycle)/\(pdfName.lowercased())")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw URLError(.resourceUnavailable)
        }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: file)
        return data
    }

    func isCached(cycle: String, pdfName: String) -> Bool {
        let file = baseDir
            .appendingPathComponent(cycle, isDirectory: true)
            .appendingPathComponent(pdfName.lowercased())
        return FileManager.default.fileExists(atPath: file.path)
    }
}
