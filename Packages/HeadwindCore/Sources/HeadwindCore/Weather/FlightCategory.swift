import Foundation

/// FAA flight category derived from ceiling and visibility.
public enum FlightCategory: String, CaseIterable, Sendable {
    case vfr = "VFR"
    case mvfr = "MVFR"
    case ifr = "IFR"
    case lifr = "LIFR"

    /// Computes the category from visibility (statute miles) and ceiling (feet AGL).
    /// Missing values are treated as unlimited.
    public static func compute(visibilitySM: Double?, ceilingFt: Int?) -> FlightCategory {
        let vis = visibilitySM ?? .greatestFiniteMagnitude
        let ceiling = ceilingFt.map(Double.init) ?? .greatestFiniteMagnitude

        if ceiling < 500 || vis < 1 { return .lifr }
        if ceiling < 1000 || vis < 3 { return .ifr }
        if ceiling <= 3000 || vis <= 5 { return .mvfr }
        return .vfr
    }
}
