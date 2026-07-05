import Foundation
import Observation
import HeadwindCore

/// Client for the free aviationweather.gov data API (no key required).
@MainActor
@Observable
final class WeatherService {
    private(set) var metars: [String: Metar] = [:]
    private(set) var tafs: [String: String] = [:]
    private(set) var isRefreshing = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?
    /// True when the last refresh failed but cached observations are showing.
    private(set) var isOffline = false

    private var fetchedAt: [String: Date] = [:]
    private var inFlight: Set<String> = []
    private var didHydrate = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private struct CachedWeather: Codable {
        var updated: Date
        var metars: [String: Metar]
        var tafs: [String: String]
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("weather-cache.json")
    }

    /// Restores the last saved observations so the app opens with weather even
    /// before (or without) a network refresh. Safe to call repeatedly.
    func loadCache() {
        guard !didHydrate else { return }
        didHydrate = true
        guard metars.isEmpty,
              let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(CachedWeather.self, from: data) else { return }
        metars = cached.metars
        tafs = cached.tafs
        lastUpdated = cached.updated
    }

    private func persist() {
        let snapshot = CachedWeather(updated: lastUpdated ?? .now, metars: metars, tafs: tafs)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: cacheURL)
        }
    }

    func metar(for ident: String) -> Metar? {
        metars[ident.trimmingCharacters(in: .whitespaces).uppercased()]
    }

    func taf(for ident: String) -> String? {
        tafs[ident.trimmingCharacters(in: .whitespaces).uppercased()]
    }

    /// Fetches current METARs for the given station identifiers.
    func refreshMetars(for idents: [String]) async {
        let ids = idents
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else { return }

        var components = URLComponents(string: "https://aviationweather.gov/api/data/metar")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "format", value: "json"),
        ]

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let (data, response) = try await session.data(from: components.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                // Server-side trouble isn't "offline" — keep data, note error.
                lastError = "Weather service unavailable — showing last data."
                return
            }
            let decoded = try JSONDecoder().decode([Metar].self, from: data)
            let now = Date.now
            for metar in decoded {
                metars[metar.stationID.uppercased()] = metar
            }
            // Mark every requested ident as fetched — stations with no METAR
            // (most small fields) shouldn't be re-requested on every map pan.
            for id in ids {
                fetchedAt[id] = now
            }
            lastUpdated = now
            lastError = nil
            isOffline = false
            persist()
        } catch is CancellationError {
            // A dismissed screen cancelling its fetch is not a failure.
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Same: SwiftUI task cancellation surfaces as URLError.cancelled.
        } catch let urlError as URLError {
            lastError = "Couldn't load weather: \(urlError.localizedDescription)"
            // Only true connectivity loss counts as offline.
            let offlineCodes: Set<URLError.Code> = [
                .notConnectedToInternet, .networkConnectionLost, .timedOut,
                .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
            ]
            isOffline = !metars.isEmpty && offlineCodes.contains(urlError.code)
        } catch {
            lastError = "Couldn't load weather: \(error.localizedDescription)"
        }
    }

    /// Fetches METARs only for stations not already fetched recently.
    /// Used by the moving map as the camera pans across the country.
    func ensureMetars(for idents: [String], maxAge: TimeInterval = 600, cap: Int = 50) async {
        let now = Date.now
        let needed = idents
            .map { $0.uppercased() }
            .filter { id in
                guard !inFlight.contains(id) else { return false }
                guard let fetched = fetchedAt[id] else { return true }
                return now.timeIntervalSince(fetched) > maxAge
            }
            .prefix(cap)
        guard !needed.isEmpty else { return }

        inFlight.formUnion(needed)
        defer { inFlight.subtract(needed) }
        await refreshMetars(for: Array(needed))
    }

    /// Fetches the raw TAF text for one station.
    func refreshTAF(for ident: String) async {
        let id = ident.trimmingCharacters(in: .whitespaces).uppercased()
        guard !id.isEmpty else { return }

        var components = URLComponents(string: "https://aviationweather.gov/api/data/taf")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: id),
            URLQueryItem(name: "format", value: "raw"),
        ]

        do {
            let (data, response) = try await session.data(from: components.url!)
            // Only accept a real 200 with plausible TAF text — an HTML error
            // page must never be stored (it would persist into the cache).
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let text = String(data: data, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  !text.hasPrefix("<") else { return }
            tafs[id] = text
        } catch {
            // TAF is supplementary; keep any previous value silently.
        }
    }

    /// Currently active SIGMETs/AIRMETs (refreshed on demand).
    private(set) var airSigmets: [AirSigmet] = []
    private var airSigmetsFetchedAt: Date?

    /// Refreshes hazard areas at most every 5 minutes.
    func refreshAirSigmets() async {
        if let fetched = airSigmetsFetchedAt, Date.now.timeIntervalSince(fetched) < 300 {
            return
        }
        var components = URLComponents(string: "https://aviationweather.gov/api/data/airsigmet")!
        components.queryItems = [URLQueryItem(name: "format", value: "json")]
        do {
            let (data, _) = try await session.data(from: components.url!)
            let decoded = try JSONDecoder().decode([AirSigmet].self, from: data)
            airSigmets = decoded.filter { !$0.polygon.isEmpty && $0.isActive(asOf: .now) }
            airSigmetsFetchedAt = .now
        } catch {
            // Hazards are supplementary; keep any previous set silently.
        }
    }

    /// Recent pilot reports near the map view (refreshed on demand).
    private(set) var pireps: [Pirep] = []
    private var pirepsFetchedAt: Date?
    private var pirepsCenter: Coordinate?

    /// Refreshes PIREPs for a bounding box, at most every 5 minutes unless
    /// the view has moved substantially.
    func refreshPireps(within bounds: GeoBounds) async {
        let center = Coordinate(
            latitude: (bounds.minLat + bounds.maxLat) / 2,
            longitude: (bounds.minLon + bounds.maxLon) / 2
        )
        if let fetched = pirepsFetchedAt, let previous = pirepsCenter,
           Date.now.timeIntervalSince(fetched) < 300,
           NavMath.distanceNM(from: previous, to: center) < 60 {
            return
        }

        var components = URLComponents(string: "https://aviationweather.gov/api/data/pirep")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(
                name: "bbox",
                value: String(format: "%.2f,%.2f,%.2f,%.2f", bounds.minLat, bounds.minLon, bounds.maxLat, bounds.maxLon)
            ),
        ]
        do {
            let (data, response) = try await session.data(from: components.url!)
            pirepsFetchedAt = .now
            pirepsCenter = center
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 204 or empty 200 body = genuinely no reports in the box.
            if status == 204 || (status == 200 && data.isEmpty) {
                pireps = []
                return
            }
            // A transient 5xx/429 must not erase valid pins — keep the old set.
            guard status == 200 else { return }
            // Decode per-item so one malformed report can't sink the batch.
            let raw = (try? JSONSerialization.jsonObject(with: data)) as? [Any] ?? []
            let decoder = JSONDecoder()
            pireps = raw.compactMap { item in
                guard let itemData = try? JSONSerialization.data(withJSONObject: item) else { return nil }
                return try? decoder.decode(Pirep.self, from: itemData)
            }
        } catch {
            // PIREPs are supplementary; keep any previous set silently.
        }
    }

    /// Fetches and parses an FB winds-aloft product for a forecast region.
    func windsAloft(region: String, forecastHours: String) async throws -> [WindsAloftStation] {
        var components = URLComponents(string: "https://aviationweather.gov/api/data/windtemp")!
        components.queryItems = [
            URLQueryItem(name: "region", value: region),
            URLQueryItem(name: "level", value: "low"),
            URLQueryItem(name: "fcst", value: forecastHours),
        ]
        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return WindsAloftParser.parse(text)
    }
}
