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
            for metar in decoded {
                metars[metar.stationID.uppercased()] = metar
            }
            lastUpdated = .now
            lastError = nil
        } catch {
            lastError = "Couldn't load weather: \(error.localizedDescription)"
        }
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
}
