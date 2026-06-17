import Foundation

/// One terminal procedure chart from the FAA d-TPP (approach plate,
/// SID/STAR, airport diagram, minimums…).
public struct ApproachPlate: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(code)-\(pdfName)-\(name)" }
    /// e.g. "ILS OR LOC RWY 28L"
    public let name: String
    /// d-TPP chart code: IAP, DP, STR, APD, MIN, HOT, LAH, ODP…
    public let code: String
    /// PDF file name within the cycle, e.g. "00375IL28L.PDF"
    public let pdfName: String

    enum CodingKeys: String, CodingKey {
        case name = "n"
        case code = "c"
        case pdfName = "p"
    }

    public init(name: String, code: String, pdfName: String) {
        self.name = name
        self.code = code
        self.pdfName = pdfName
    }

    /// Pilot-friendly grouping for list sections, in display order.
    public var category: String {
        switch code {
        case "IAP": "Approaches"
        case "DP", "ODP": "Departures"
        case "STR": "Arrivals"
        case "APD": "Airport Diagram"
        case "MIN": "Minimums"
        case "HOT": "Hot Spots"
        case "LAH": "Land and Hold Short"
        default: "Other"
        }
    }

    public static let categoryOrder = [
        "Airport Diagram", "Approaches", "Departures", "Arrivals",
        "Minimums", "Hot Spots", "Land and Hold Short", "Other",
    ]
}

/// The bundled d-TPP index: cycle identifier plus plates per airport.
public struct PlateIndex: Codable, Sendable {
    public let cycle: String
    /// Validity window of this index; nil for older bundles without dates.
    public let effectiveDate: Date?
    public let expirationDate: Date?
    public let airports: [String: [ApproachPlate]]

    public init(
        cycle: String,
        effectiveDate: Date? = nil,
        expirationDate: Date? = nil,
        airports: [String: [ApproachPlate]]
    ) {
        self.cycle = cycle
        self.effectiveDate = effectiveDate
        self.expirationDate = expirationDate
        self.airports = airports
    }

    enum CodingKeys: String, CodingKey {
        case cycle
        case effectiveDate = "effective"
        case expirationDate = "expires"
        case airports
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cycle = try c.decode(String.self, forKey: .cycle)
        airports = try c.decode([String: [ApproachPlate]].self, forKey: .airports)
        effectiveDate = (try? c.decodeIfPresent(String.self, forKey: .effectiveDate))
            .flatMap { $0.flatMap(Self.dateFormatter.date(from:)) }
        expirationDate = (try? c.decodeIfPresent(String.self, forKey: .expirationDate))
            .flatMap { $0.flatMap(Self.dateFormatter.date(from:)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cycle, forKey: .cycle)
        try c.encode(airports, forKey: .airports)
        try c.encodeIfPresent(effectiveDate.map(Self.dateFormatter.string(from:)), forKey: .effectiveDate)
        try c.encodeIfPresent(expirationDate.map(Self.dateFormatter.string(from:)), forKey: .expirationDate)
    }

    /// Validity window for this index, when dates are present.
    public var currency: DataCurrency? {
        guard let effectiveDate, let expirationDate, !cycle.isEmpty else { return nil }
        return DataCurrency(
            cycleLabel: cycle,
            effectiveDate: effectiveDate,
            expirationDate: expirationDate
        )
    }

    public func plates(for ident: String) -> [ApproachPlate] {
        airports[ident.trimmingCharacters(in: .whitespaces).uppercased()] ?? []
    }

    /// Plates grouped into display sections, ordered for pilots.
    public func groupedPlates(for ident: String) -> [(category: String, plates: [ApproachPlate])] {
        let groups = Dictionary(grouping: plates(for: ident), by: \.category)
        return ApproachPlate.categoryOrder.compactMap { category in
            groups[category].map { (category, $0) }
        }
    }
}
