import Foundation

/// A SIGMET or AIRMET hazard area from the aviationweather.gov
/// `airsigmet` endpoint.
///
/// The decoder is tolerant of that API's quirks: coordinates arrive as
/// strings, valid times as epoch-second strings, and altitude fields may be
/// missing.
public struct AirSigmet: Hashable, Sendable, Decodable, Identifiable {
    public var id: String { "\(type)-\(seriesID ?? "")-\(hazard ?? "")-\(validFrom?.timeIntervalSince1970 ?? 0)" }

    /// "SIGMET", "AIRMET", or "OUTLOOK".
    public let type: String
    /// TURB, ICE, IFR, MTN OBSCN, CONVECTIVE, ...
    public let hazard: String?
    public let severity: String?
    public let seriesID: String?
    public let validFrom: Date?
    public let validTo: Date?
    public let altitudeLowFt: Int?
    public let altitudeHiFt: Int?
    public let rawText: String?
    public let polygon: [Coordinate]

    public init(
        type: String,
        hazard: String? = nil,
        severity: String? = nil,
        seriesID: String? = nil,
        validFrom: Date? = nil,
        validTo: Date? = nil,
        altitudeLowFt: Int? = nil,
        altitudeHiFt: Int? = nil,
        rawText: String? = nil,
        polygon: [Coordinate] = []
    ) {
        self.type = type
        self.hazard = hazard
        self.severity = severity
        self.seriesID = seriesID
        self.validFrom = validFrom
        self.validTo = validTo
        self.altitudeLowFt = altitudeLowFt
        self.altitudeHiFt = altitudeHiFt
        self.rawText = rawText
        self.polygon = polygon
    }

    public func isActive(asOf now: Date) -> Bool {
        if let validFrom, now < validFrom { return false }
        if let validTo, now > validTo { return false }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case type = "airSigmetType"
        case hazard
        case severity
        case seriesID = "seriesId"
        case validFrom = "validTimeFrom"
        case validTo = "validTimeTo"
        case altitudeLow = "altitudeLow1"
        case altitudeHi = "altitudeHi1"
        case altitudeHi2 = "altitudeHi2"
        case rawText = "rawAirSigmet"
        case coords
    }

    private struct RawPoint: Decodable {
        let lat: FlexibleNumber?
        let lon: FlexibleNumber?
    }

    /// Number that may arrive as a JSON number or a numeric string.
    struct FlexibleNumber: Decodable {
        let value: Double
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode(Double.self) {
                value = d
            } else if let s = try? c.decode(String.self), let d = Double(s) {
                value = d
            } else {
                throw DecodingError.dataCorruptedError(
                    in: c, debugDescription: "Expected number or numeric string"
                )
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? "SIGMET"
        hazard = try? c.decodeIfPresent(String.self, forKey: .hazard)
        severity = Self.flexibleString(c, .severity)
        seriesID = Self.flexibleString(c, .seriesID)
        validFrom = Self.epoch(c, .validFrom)
        validTo = Self.epoch(c, .validTo)
        altitudeLowFt = Self.flexibleInt(c, .altitudeLow)
        altitudeHiFt = Self.flexibleInt(c, .altitudeHi) ?? Self.flexibleInt(c, .altitudeHi2)
        rawText = try? c.decodeIfPresent(String.self, forKey: .rawText)

        let raw = (try? c.decodeIfPresent([RawPoint].self, forKey: .coords)) ?? []
        polygon = raw.compactMap { point in
            guard let lat = point.lat?.value, let lon = point.lon?.value else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        }
    }

    private static func epoch(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Date? {
        if let n = try? c.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: n)
        }
        if let s = try? c.decode(String.self, forKey: key), let n = Double(s) {
            return Date(timeIntervalSince1970: n)
        }
        return nil
    }

    private static func flexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let n = try? c.decode(Int.self, forKey: key) { return n }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return Int(d) }
        return nil
    }

    private static func flexibleString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let n = try? c.decode(Double.self, forKey: key) {
            return n == n.rounded() ? String(Int(n)) : String(n)
        }
        return nil
    }
}
