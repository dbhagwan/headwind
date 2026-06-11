import Foundation

public struct Runway: Hashable, Codable, Sendable, Identifiable {
    public var id: String { ident }
    /// e.g. "10L/28R"
    public let ident: String
    public let lengthFt: Int
    public let widthFt: Int?
    public let surface: String

    public init(ident: String, lengthFt: Int, widthFt: Int? = nil, surface: String) {
        self.ident = ident
        self.lengthFt = lengthFt
        self.widthFt = widthFt
        self.surface = surface
    }
}

public struct Frequency: Hashable, Codable, Sendable, Identifiable {
    public var id: String { "\(name)-\(mhz)" }
    /// e.g. "Tower", "Ground", "ATIS", "CTAF"
    public let name: String
    public let mhz: Double

    public init(name: String, mhz: Double) {
        self.name = name
        self.mhz = mhz
    }
}

public struct Airport: Hashable, Codable, Sendable, Identifiable {
    public var id: String { icao }
    public let icao: String
    public let iata: String?
    public let name: String
    public let city: String
    public let state: String
    public let coordinate: Coordinate
    public let elevationFt: Int
    public let runways: [Runway]
    public let frequencies: [Frequency]

    public init(
        icao: String,
        iata: String? = nil,
        name: String,
        city: String,
        state: String,
        coordinate: Coordinate,
        elevationFt: Int,
        runways: [Runway] = [],
        frequencies: [Frequency] = []
    ) {
        self.icao = icao
        self.iata = iata
        self.name = name
        self.city = city
        self.state = state
        self.coordinate = coordinate
        self.elevationFt = elevationFt
        self.runways = runways
        self.frequencies = frequencies
    }

    public var longestRunwayFt: Int? { runways.map(\.lengthFt).max() }
}
