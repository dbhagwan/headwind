import Foundation

/// In-memory airport directory with search and proximity queries.
public struct AirportDatabase: Sendable {
    public let airports: [Airport]
    private let byIdent: [String: Airport]

    public init(airports: [Airport]) {
        self.airports = airports
        var index: [String: Airport] = [:]
        for airport in airports {
            index[airport.icao.uppercased()] = airport
            if let iata = airport.iata {
                index[iata.uppercased()] = airport
            }
        }
        self.byIdent = index
    }

    /// Exact lookup by ICAO or IATA identifier (case-insensitive).
    public func airport(ident: String) -> Airport? {
        byIdent[ident.trimmingCharacters(in: .whitespaces).uppercased()]
    }

    /// Ranked substring search across ident, name, and city.
    public func search(_ query: String) -> [Airport] {
        let q = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !q.isEmpty else { return airports }

        func rank(_ airport: Airport) -> Int? {
            if airport.icao.uppercased() == q || airport.iata?.uppercased() == q { return 0 }
            if airport.icao.uppercased().hasPrefix(q) || (airport.iata?.uppercased().hasPrefix(q) ?? false) { return 1 }
            if airport.name.uppercased().contains(q) { return 2 }
            if airport.city.uppercased().contains(q) { return 3 }
            return nil
        }

        return airports
            .compactMap { airport in rank(airport).map { (airport, $0) } }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.icao < rhs.0.icao
            }
            .map(\.0)
    }

    /// Closest airports to a coordinate, nearest first.
    public func nearest(to coordinate: Coordinate, limit: Int = 10) -> [Airport] {
        airports
            .map { ($0, NavMath.distanceNM(from: coordinate, to: $0.coordinate)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}
