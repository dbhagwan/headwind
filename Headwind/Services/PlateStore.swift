import Foundation
import Observation
import HeadwindCore

/// Loads the d-TPP plate index and keeps it current. The app ships a bundled
/// index, but cycles expire every 28 days — so when the bundle is stale the
/// store self-heals by fetching the latest index the data-refresh workflow
/// keeps committed on `main`, with no app update required.
@MainActor
@Observable
final class PlateStore {
    private(set) var index = PlateIndex(cycle: "", airports: [:])
    private(set) var isLoading = true
    private(set) var isCheckingForUpdate = false
    private(set) var updateMessage: String?
    private var loadTask: Task<Void, Never>?

    /// Where the data-refresh workflow publishes the current index.
    private static let remoteIndexURL = URL(string:
        "https://raw.githubusercontent.com/dbhagwan/headwind/main/Headwind/Resources/us-plates.json"
    )!

    private nonisolated static var cachedIndexURL: URL {
        DurableStorage.directory("Plates").appendingPathComponent("us-plates-latest.json")
    }

    private nonisolated static let indexSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    var cycle: String { index.cycle }
    var currency: DataCurrency? { index.currency }

    /// Currency status as of now; nil for bundles without dates.
    func currencyStatus(asOf now: Date = .now) -> DataCurrency.Status? {
        currency?.status(asOf: now)
    }

    /// True when the active index is past its expiration date.
    func isExpired(asOf now: Date = .now) -> Bool {
        if let status = currencyStatus(asOf: now), case .expired = status { return true }
        return false
    }

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
            let decoder = JSONDecoder()
            let bundled = Self.decodeBundled(decoder)
            // Prefer a previously-downloaded index if it's a newer cycle.
            if let data = try? Data(contentsOf: Self.cachedIndexURL),
               let cached = try? decoder.decode(PlateIndex.self, from: data),
               Self.isNewer(cached, than: bundled) {
                return cached
            }
            return bundled
        }.value
        index = loaded
        isLoading = false

        // If what we loaded is stale, quietly try to refresh in the background.
        if isExpired() {
            await refreshFromRemote()
        }
    }

    /// Fetches the latest published index and adopts it when it's newer.
    @discardableResult
    func refreshFromRemote() async -> Bool {
        guard !isCheckingForUpdate else { return false }
        isCheckingForUpdate = true
        defer { isCheckingForUpdate = false }

        do {
            // Decode the 1.3 MB index off the main actor to avoid a UI hitch.
            let fetched = try await Task.detached(priority: .userInitiated) { () -> (PlateIndex, Data) in
                let (data, response) = try await Self.indexSession.data(from: Self.remoteIndexURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return (try JSONDecoder().decode(PlateIndex.self, from: data), data)
            }.value

            guard Self.isNewer(fetched.0, than: index) else {
                updateMessage = "Procedures are up to date (cycle \(index.cycle))."
                return false
            }
            try? fetched.1.write(to: Self.cachedIndexURL, options: .atomic)
            index = fetched.0
            updateMessage = "Updated to cycle \(fetched.0.cycle)."
            return true
        } catch is CancellationError {
            return false
        } catch {
            updateMessage = "Update check failed: \(error.localizedDescription)"
            return false
        }
    }

    private nonisolated static func decodeBundled(_ decoder: JSONDecoder) -> PlateIndex {
        guard let url = Bundle.main.url(forResource: "us-plates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let index = try? decoder.decode(PlateIndex.self, from: data) else {
            assertionFailure("Bundled us-plates.json missing or malformed")
            return PlateIndex(cycle: "", airports: [:])
        }
        return index
    }

    /// Newer = later effective date. A dated index always beats an undated
    /// one (a stale date-less cache must never shadow a dated bundle); only
    /// when neither carries dates do we fall back to cycle inequality.
    private nonisolated static func isNewer(_ candidate: PlateIndex, than current: PlateIndex) -> Bool {
        switch (candidate.effectiveDate, current.effectiveDate) {
        case let (c?, cur?): return c > cur
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return !candidate.cycle.isEmpty && candidate.cycle != current.cycle
        }
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

    // Durable storage: a plate a pilot downloaded must survive iOS cache
    // purges (it may be needed in the air with no signal).
    private let baseDir = DurableStorage.directory("Plates")

    func pdf(cycle: String, pdfName: String) async throws -> Data {
        let file = baseDir
            .appendingPathComponent(cycle, isDirectory: true)
            .appendingPathComponent(pdfName.lowercased())
        if let data = try? Data(contentsOf: file), data.starts(with: Array("%PDF".utf8)) {
            return data
        }

        let url = URL(string: "https://aeronav.faa.gov/d-tpp/\(cycle)/\(pdfName.lowercased())")!
        let (data, response) = try await session.data(from: url)
        // Validate it's actually a PDF — an HTML error page must never be
        // cached as a plate.
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              data.starts(with: Array("%PDF".utf8)) else {
            throw URLError(.resourceUnavailable)
        }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
        return data
    }

    func isCached(cycle: String, pdfName: String) -> Bool {
        let file = baseDir
            .appendingPathComponent(cycle, isDirectory: true)
            .appendingPathComponent(pdfName.lowercased())
        return FileManager.default.fileExists(atPath: file.path)
    }
}
