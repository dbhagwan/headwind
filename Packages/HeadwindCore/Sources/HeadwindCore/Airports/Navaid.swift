import Foundation

/// A radio navigation aid (VOR, VORTAC, NDB, …) usable as a route waypoint.
public struct Navaid: Hashable, Codable, Sendable, Identifiable {
    public var id: String { "\(ident)-\(type)" }
    public let ident: String
    public let name: String
    /// VOR, VOR-DME, VORTAC, NDB, NDB-DME, DME, TACAN
    public let type: String
    public let coordinate: Coordinate
    public let frequencyKhz: Int?

    public init(ident: String, name: String, type: String, coordinate: Coordinate, frequencyKhz: Int? = nil) {
        self.ident = ident
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.frequencyKhz = frequencyKhz
    }

    /// "115.8" for VHF aids, "362" for NDBs.
    public var frequencyText: String? {
        guard let khz = frequencyKhz else { return nil }
        if khz >= 108_000 {
            return String(format: "%.1f", Double(khz) / 1000)
        }
        return String(khz)
    }
}
