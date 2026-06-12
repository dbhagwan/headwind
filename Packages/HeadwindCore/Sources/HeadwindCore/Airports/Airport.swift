import Foundation

public enum AirportKind: String, Codable, Sendable, CaseIterable {
    case large, medium, small, seaplane

    /// Display ordering / search priority: bigger fields first.
    public var priority: Int {
        switch self {
        case .large: 0
        case .medium: 1
        case .small: 2
        case .seaplane: 3
        }
    }
}

public struct Runway: Hashable, Codable, Sendable, Identifiable {
    public var id: String { ident }
    /// e.g. "10L/28R"
    public let ident: String
    public let lengthFt: Int
    public let widthFt: Int?
    public let surface: String
    /// Per-end identifiers and true headings (from FAA data), when known.
    public let leIdent: String?
    public let leHeadingDegT: Double?
    public let heIdent: String?
    public let heHeadingDegT: Double?

    public init(
        ident: String,
        lengthFt: Int,
        widthFt: Int? = nil,
        surface: String,
        leIdent: String? = nil,
        leHeadingDegT: Double? = nil,
        heIdent: String? = nil,
        heHeadingDegT: Double? = nil
    ) {
        self.ident = ident
        self.lengthFt = lengthFt
        self.widthFt = widthFt
        self.surface = surface
        self.leIdent = leIdent
        self.leHeadingDegT = leHeadingDegT
        self.heIdent = heIdent
        self.heHeadingDegT = heHeadingDegT
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
    public var id: String { ident }
    /// ICAO code where one exists (KSFO), otherwise the FAA local code (06C).
    public let ident: String
    public let iata: String?
    public let name: String
    public let city: String
    public let state: String
    public let coordinate: Coordinate
    public let elevationFt: Int
    public let kind: AirportKind
    public let runways: [Runway]
    public let frequencies: [Frequency]

    public init(
        ident: String,
        iata: String? = nil,
        name: String,
        city: String,
        state: String,
        coordinate: Coordinate,
        elevationFt: Int,
        kind: AirportKind = .small,
        runways: [Runway] = [],
        frequencies: [Frequency] = []
    ) {
        self.ident = ident
        self.iata = iata
        self.name = name
        self.city = city
        self.state = state
        self.coordinate = coordinate
        self.elevationFt = elevationFt
        self.kind = kind
        self.runways = runways
        self.frequencies = frequencies
    }

    public var longestRunwayFt: Int? { runways.map(\.lengthFt).max() }
}
