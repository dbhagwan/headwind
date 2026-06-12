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
    public let airports: [String: [ApproachPlate]]

    public init(cycle: String, airports: [String: [ApproachPlate]]) {
        self.cycle = cycle
        self.airports = airports
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
