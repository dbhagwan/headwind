import Foundation

/// A latitude/longitude bounding box. Handles antimeridian wrap
/// (minLon > maxLon) for Alaska's far Aleutians.
public struct GeoBounds: Sendable {
    public let minLat: Double
    public let maxLat: Double
    public let minLon: Double
    public let maxLon: Double

    public init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }

    public func contains(_ c: Coordinate) -> Bool {
        guard c.latitude >= minLat, c.latitude <= maxLat else { return false }
        if minLon <= maxLon {
            return c.longitude >= minLon && c.longitude <= maxLon
        }
        return c.longitude >= minLon || c.longitude <= maxLon
    }
}

/// In-memory aviation directory: airports plus navaids, with search,
/// proximity, and route-waypoint resolution.
public struct AirportDatabase: Sendable {
    public let airports: [Airport]
    public let navaids: [Navaid]

    private let airportsByIdent: [String: Int]
    private let navaidsByIdent: [String: Int]

    private struct SearchKey: Sendable {
        let ident: String
        let iata: String?
        let name: String
        let city: String
        let priority: Int
    }
    private let searchKeys: [SearchKey]

    public init(airports: [Airport], navaids: [Navaid] = []) {
        self.airports = airports
        self.navaids = navaids

        var airportIndex: [String: Int] = [:]
        airportIndex.reserveCapacity(airports.count * 2)
        for (i, airport) in airports.enumerated() {
            airportIndex[airport.ident.uppercased()] = i
        }
        // IATA codes resolve only where they don't shadow a real identifier.
        for (i, airport) in airports.enumerated() {
            if let iata = airport.iata?.uppercased(), airportIndex[iata] == nil {
                airportIndex[iata] = i
            }
        }
        self.airportsByIdent = airportIndex

        var navaidIndex: [String: Int] = [:]
        for (i, navaid) in navaids.enumerated() where navaidIndex[navaid.ident.uppercased()] == nil {
            navaidIndex[navaid.ident.uppercased()] = i
        }
        self.navaidsByIdent = navaidIndex

        self.searchKeys = airports.map { airport in
            SearchKey(
                ident: airport.ident.uppercased(),
                iata: airport.iata?.uppercased(),
                name: airport.name.uppercased(),
                city: airport.city.uppercased(),
                priority: airport.kind.priority
            )
        }
    }

    public var isEmpty: Bool { airports.isEmpty }

    /// Exact lookup by ICAO/local identifier or IATA code (case-insensitive).
    public func airport(ident: String) -> Airport? {
        airportsByIdent[normalize(ident)].map { airports[$0] }
    }

    public func navaid(ident: String) -> Navaid? {
        navaidsByIdent[normalize(ident)].map { navaids[$0] }
    }

    /// Resolves a route token: airport identifier first, then navaid,
    /// then airport IATA — matching how pilots write routes (bare
    /// 3-letter tokens like "OSI" usually mean the VOR).
    public func waypoint(ident: String) -> Waypoint? {
        let key = normalize(ident)
        if let i = airportsByIdent[key], airports[i].ident.uppercased() == key {
            return Waypoint(airport: airports[i])
        }
        if let i = navaidsByIdent[key] {
            return Waypoint(navaid: navaids[i])
        }
        if let i = airportsByIdent[key] {
            return Waypoint(airport: airports[i])
        }
        return nil
    }

    /// Ranked substring search across ident, name, and city.
    public func search(_ query: String, limit: Int = 50) -> [Airport] {
        let q = normalize(query)
        guard !q.isEmpty else { return [] }

        var matches: [(rank: Int, priority: Int, index: Int)] = []
        for (i, key) in searchKeys.enumerated() {
            let rank: Int
            if key.ident == q || key.iata == q {
                rank = 0
            } else if key.ident.hasPrefix(q) || (key.iata?.hasPrefix(q) ?? false) {
                rank = 1
            } else if key.name.contains(q) {
                rank = 2
            } else if !key.city.isEmpty && key.city.contains(q) {
                rank = 3
            } else {
                continue
            }
            matches.append((rank, key.priority, i))
        }

        return matches
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                if $0.priority != $1.priority { return $0.priority < $1.priority }
                return airports[$0.index].ident < airports[$1.index].ident
            }
            .prefix(limit)
            .map { airports[$0.index] }
    }

    /// Closest airports to a coordinate, nearest first.
    public func nearest(to coordinate: Coordinate, limit: Int = 10, kinds: Set<AirportKind>? = nil) -> [Airport] {
        airports
            .lazy
            .filter { kinds == nil || kinds!.contains($0.kind) }
            .map { ($0, NavMath.distanceNM(from: coordinate, to: $0.coordinate)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Airports inside a bounding box, filtered by kind and capped by
    /// distance to the box center — used by the moving map.
    public func airports(within bounds: GeoBounds, kinds: Set<AirportKind>, limit: Int = 120) -> [Airport] {
        let center = Coordinate(
            latitude: (bounds.minLat + bounds.maxLat) / 2,
            longitude: (bounds.minLon + bounds.maxLon) / 2
        )
        let hits = airports.filter { kinds.contains($0.kind) && bounds.contains($0.coordinate) }
        guard hits.count > limit else { return hits }
        return hits
            .map { ($0, NavMath.distanceNM(from: center, to: $0.coordinate)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).uppercased()
    }
}
