import Foundation

/// One entry from the tfr.faa.gov list API.
public struct TFRListItem: Decodable, Hashable, Sendable, Identifiable {
    public var id: String { notamID }
    public let notamID: String
    /// e.g. "SECURITY", "HAZARDS", "VIP", "SPACE OPERATIONS"
    public let type: String?
    public let facility: String?
    public let state: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case notamID = "notam_id"
        case type, facility, state, description
    }

    public init(notamID: String, type: String? = nil, facility: String? = nil,
                state: String? = nil, description: String? = nil) {
        self.notamID = notamID
        self.type = type
        self.facility = facility
        self.state = state
        self.description = description
    }

    /// "6/7811" → "6_7811", as used by the detail XML URL.
    public var detailIdent: String {
        notamID.replacingOccurrences(of: "/", with: "_")
    }
}

/// A TFR with resolved geometry, ready to draw.
public struct TFR: Hashable, Sendable, Identifiable {
    public var id: String { item.notamID }
    public let item: TFRListItem
    /// One or more polygon rings (lat/lon vertices).
    public let polygons: [[Coordinate]]

    public init(item: TFRListItem, polygons: [[Coordinate]]) {
        self.item = item
        self.polygons = polygons
    }
}
