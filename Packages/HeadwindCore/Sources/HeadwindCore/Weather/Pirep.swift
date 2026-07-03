import Foundation

/// A pilot report from the aviationweather.gov `pirep` endpoint.
///
/// Field quirks: numbers arrive as strings, flight level is hundreds of feet
/// ("370" → 37,000 ft), and turbulence/icing intensities are free-ish text
/// like "LGT", "MOD", "MOD-SEV", "SEV".
public struct Pirep: Hashable, Sendable, Decodable, Identifiable {
    public var id: String {
        "\(reportType ?? "P")-\(aircraft ?? "")-\(observationTime?.timeIntervalSince1970 ?? 0)-\(coordinate.latitude)-\(coordinate.longitude)"
    }

    /// "PIREP", "AIREP", or "Urgent PIREP" style markers.
    public let reportType: String?
    public let aircraft: String?
    public let coordinate: Coordinate
    public let observationTime: Date?
    /// Feet MSL, parsed from the FL-style hundreds field when numeric.
    public let altitudeFt: Int?
    public let turbulence: String?
    public let icing: String?
    public let weather: String?
    public let temperatureC: Int?
    public let rawText: String?

    public init(
        reportType: String? = nil,
        aircraft: String? = nil,
        coordinate: Coordinate,
        observationTime: Date? = nil,
        altitudeFt: Int? = nil,
        turbulence: String? = nil,
        icing: String? = nil,
        weather: String? = nil,
        temperatureC: Int? = nil,
        rawText: String? = nil
    ) {
        self.reportType = reportType
        self.aircraft = aircraft
        self.coordinate = coordinate
        self.observationTime = observationTime
        self.altitudeFt = altitudeFt
        self.turbulence = turbulence
        self.icing = icing
        self.weather = weather
        self.temperatureC = temperatureC
        self.rawText = rawText
    }

    public enum Severity: Int, Comparable, Sendable {
        case routine = 0
        case moderate = 1
        case severe = 2

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Worst condition reported, for pin coloring/sorting. Urgent reports
    /// and SEV/EXTRM intensities rank severe; MOD ranks moderate.
    public var severity: Severity {
        if reportType?.uppercased().contains("URGENT") == true { return .severe }
        let combined = "\(turbulence ?? "") \(icing ?? "")".uppercased()
        if combined.contains("SEV") || combined.contains("EXTRM") { return .severe }
        if combined.contains("MOD") { return .moderate }
        return .routine
    }

    public var hasTurbulence: Bool { !(turbulence ?? "").isEmpty }
    public var hasIcing: Bool { !(icing ?? "").isEmpty }

    enum CodingKeys: String, CodingKey {
        case reportType = "pirepType"
        case aircraft = "acType"
        case lat, lon
        case observationTime = "obsTime"
        case flightLevel = "fltLvl"
        case turbulence = "tbInt1"
        case icing = "icgInt1"
        case weather = "wxString"
        case temperature = "temp"
        case rawText = "rawOb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        guard let lat = Self.number(c, .lat), let lon = Self.number(c, .lon) else {
            throw DecodingError.dataCorruptedError(
                forKey: .lat, in: c, debugDescription: "PIREP without coordinates"
            )
        }
        coordinate = Coordinate(latitude: lat, longitude: lon)

        reportType = Self.text(c, .reportType)
        aircraft = Self.text(c, .aircraft)
        observationTime = Self.number(c, .observationTime).map { Date(timeIntervalSince1970: $0) }
        altitudeFt = Self.number(c, .flightLevel).map { Int($0) * 100 }
        turbulence = Self.text(c, .turbulence)
        icing = Self.text(c, .icing)
        weather = Self.text(c, .weather)
        temperatureC = Self.number(c, .temperature).map { Int($0) }
        rawText = Self.text(c, .rawText)
    }

    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }

    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard let s = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
