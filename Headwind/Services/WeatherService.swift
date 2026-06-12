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

    private var fetchedAt: [String: Date] = [:]
    private var inFlight: Set<String> = []

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

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
            let (data, _) = try await session.data(from: components.url!)
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
            let (data, _) = try await session.data(from: components.url!)
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                tafs[id] = text
            }
        } catch {
            // TAF is supplementary; keep any previous value silently.
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
        let (data, _) = try await session.data(from: components.url!)
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return WindsAloftParser.parse(text)
    }
}
