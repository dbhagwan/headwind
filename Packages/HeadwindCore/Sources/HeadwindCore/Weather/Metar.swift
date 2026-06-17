import Foundation

public struct CloudLayer: Hashable, Sendable, Codable {
    /// FEW, SCT, BKN, OVC, OVX, VV, CLR, SKC, CAVOK
    public let cover: String
    /// Base in feet AGL; nil for clear skies or vertical visibility unknown.
    public let baseFt: Int?

    public init(cover: String, baseFt: Int?) {
        self.cover = cover
        self.baseFt = baseFt
    }

    enum CodingKeys: String, CodingKey {
        case cover
        case baseFt = "base"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cover = (try? c.decode(String.self, forKey: .cover)) ?? "CLR"
        baseFt = try? c.decodeIfPresent(Int.self, forKey: .baseFt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cover, forKey: .cover)
        try c.encodeIfPresent(baseFt, forKey: .baseFt)
    }
}

/// A decoded METAR observation.
///
/// The decoder is tolerant of the aviationweather.gov JSON API's mixed types
/// (e.g. `wdir` may be an integer or `"VRB"`, `visib` may be `10` or `"10+"`).
public struct Metar: Hashable, Sendable, Codable, Identifiable {
    public var id: String { "\(stationID)-\(observationTime?.timeIntervalSince1970 ?? 0)" }

    public let stationID: String
    public let observationTime: Date?
    public let temperatureC: Double?
    public let dewpointC: Double?
    /// Direction the wind is blowing from, degrees true. `nil` when calm or variable.
    public let windDirectionDeg: Int?
    public let windVariable: Bool
    public let windSpeedKts: Int?
    public let windGustKts: Int?
    public let visibilitySM: Double?
    /// Altimeter setting in hectopascals as reported by the API.
    public let altimeterHpa: Double?
    public let clouds: [CloudLayer]
    public let rawText: String?
    public let stationName: String?
    public let latitude: Double?
    public let longitude: Double?

    /// Lowest broken/overcast/obscured layer, feet AGL.
    public var ceilingFt: Int? {
        clouds
            .filter { ["BKN", "OVC", "OVX", "VV"].contains($0.cover.uppercased()) }
            .compactMap(\.baseFt)
            .min()
    }

    public var flightCategory: FlightCategory {
        .compute(visibilitySM: visibilitySM, ceilingFt: ceilingFt)
    }

    public var altimeterInHg: Double? {
        altimeterHpa.map { $0 * 0.029529983071445 }
    }

    public init(
        stationID: String,
        observationTime: Date? = nil,
        temperatureC: Double? = nil,
        dewpointC: Double? = nil,
        windDirectionDeg: Int? = nil,
        windVariable: Bool = false,
        windSpeedKts: Int? = nil,
        windGustKts: Int? = nil,
        visibilitySM: Double? = nil,
        altimeterHpa: Double? = nil,
        clouds: [CloudLayer] = [],
        rawText: String? = nil,
        stationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.stationID = stationID
        self.observationTime = observationTime
        self.temperatureC = temperatureC
        self.dewpointC = dewpointC
        self.windDirectionDeg = windDirectionDeg
        self.windVariable = windVariable
        self.windSpeedKts = windSpeedKts
        self.windGustKts = windGustKts
        self.visibilitySM = visibilitySM
        self.altimeterHpa = altimeterHpa
        self.clouds = clouds
        self.rawText = rawText
        self.stationName = stationName
        self.latitude = latitude
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case stationID = "icaoId"
        case observationTime = "obsTime"
        case temperatureC = "temp"
        case dewpointC = "dewp"
        case windDirection = "wdir"
        case windSpeedKts = "wspd"
        case windGustKts = "wgst"
        case visibility = "visib"
        case altimeterHpa = "altim"
        case clouds
        case rawText = "rawOb"
        case stationName = "name"
        case latitude = "lat"
        case longitude = "lon"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stationID = try c.decode(String.self, forKey: .stationID)

        if let epoch = try? c.decode(Double.self, forKey: .observationTime) {
            observationTime = Date(timeIntervalSince1970: epoch)
        } else {
            observationTime = nil
        }

        temperatureC = Self.flexibleDouble(c, .temperatureC)
        dewpointC = Self.flexibleDouble(c, .dewpointC)

        if let dir = try? c.decode(Int.self, forKey: .windDirection) {
            windDirectionDeg = dir
            windVariable = false
        } else if let s = try? c.decode(String.self, forKey: .windDirection) {
            windDirectionDeg = Int(s)
            windVariable = s.uppercased() == "VRB"
        } else {
            windDirectionDeg = nil
            windVariable = false
        }

        windSpeedKts = try? c.decodeIfPresent(Int.self, forKey: .windSpeedKts)
        windGustKts = try? c.decodeIfPresent(Int.self, forKey: .windGustKts)
        visibilitySM = Self.flexibleDouble(c, .visibility)
        altimeterHpa = Self.flexibleDouble(c, .altimeterHpa)
        clouds = (try? c.decodeIfPresent([CloudLayer].self, forKey: .clouds)) ?? []
        rawText = try? c.decodeIfPresent(String.self, forKey: .rawText)
        stationName = try? c.decodeIfPresent(String.self, forKey: .stationName)
        latitude = Self.flexibleDouble(c, .latitude)
        longitude = Self.flexibleDouble(c, .longitude)
    }

    /// Decodes a value that may arrive as a number or a string like "10+" or "0.5".
    private static func flexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let d = try? container.decode(Double.self, forKey: key) { return d }
        if let s = try? container.decode(String.self, forKey: key) {
            return Double(s.replacingOccurrences(of: "+", with: ""))
        }
        return nil
    }

    /// Encodes in the same shape the API uses, so a persisted cache round-trips
    /// cleanly back through `init(from:)`.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stationID, forKey: .stationID)
        try c.encodeIfPresent(observationTime?.timeIntervalSince1970, forKey: .observationTime)
        try c.encodeIfPresent(temperatureC, forKey: .temperatureC)
        try c.encodeIfPresent(dewpointC, forKey: .dewpointC)
        if windVariable {
            try c.encode("VRB", forKey: .windDirection)
        } else if let windDirectionDeg {
            try c.encode(windDirectionDeg, forKey: .windDirection)
        }
        try c.encodeIfPresent(windSpeedKts, forKey: .windSpeedKts)
        try c.encodeIfPresent(windGustKts, forKey: .windGustKts)
        try c.encodeIfPresent(visibilitySM, forKey: .visibility)
        try c.encodeIfPresent(altimeterHpa, forKey: .altimeterHpa)
        try c.encode(clouds, forKey: .clouds)
        try c.encodeIfPresent(rawText, forKey: .rawText)
        try c.encodeIfPresent(stationName, forKey: .stationName)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
    }

    // MARK: Freshness

    /// Age of the observation; nil when the report has no timestamp.
    public func age(asOf now: Date = .now) -> TimeInterval? {
        observationTime.map { now.timeIntervalSince($0) }
    }

    /// True when the observation is older than `maxAge` (default 75 min — by
    /// which point a newer hourly METAR should exist).
    public func isStale(asOf now: Date = .now, maxAge: TimeInterval = 75 * 60) -> Bool {
        guard let age = age(asOf: now) else { return false }
        return age > maxAge
    }
}
