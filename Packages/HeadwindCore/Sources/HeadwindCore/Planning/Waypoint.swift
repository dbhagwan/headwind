import Foundation

/// A point in a route. Usually backed by an airport, but supports arbitrary
/// lat/lon fixes.
public struct Waypoint: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    /// Short identifier, e.g. "KSFO" or a named fix.
    public let ident: String
    public let name: String
    public let coordinate: Coordinate

    public init(id: UUID = UUID(), ident: String, name: String, coordinate: Coordinate) {
        self.id = id
        self.ident = ident
        self.name = name
        self.coordinate = coordinate
    }

    public init(airport: Airport) {
        self.init(ident: airport.icao, name: airport.name, coordinate: airport.coordinate)
    }
}
