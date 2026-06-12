import Foundation

/// Wind components for one runway end.
public struct RunwayEndWind: Hashable, Sendable, Identifiable {
    public var id: String { endIdent }
    public let endIdent: String
    public let headingDegT: Double
    /// Positive = headwind, negative = tailwind.
    public let headwindKts: Double
    /// Positive = wind from the right, negative = from the left.
    public let crosswindKts: Double

    public init(endIdent: String, headingDegT: Double, headwindKts: Double, crosswindKts: Double) {
        self.endIdent = endIdent
        self.headingDegT = headingDegT
        self.headwindKts = headwindKts
        self.crosswindKts = crosswindKts
    }
}

/// Ranks runway ends for the current wind. Requires per-end true headings
/// (present in the FAA-sourced runway data) and a wind given in degrees true,
/// as reported in METARs.
public enum RunwayWindCalculator {
    /// All runway ends with computed components, best option first
    /// (most headwind; crosswind magnitude breaks ties).
    public static func evaluate(
        runways: [Runway],
        windFromDegT: Double,
        windSpeedKts: Double
    ) -> [RunwayEndWind] {
        var ends: [RunwayEndWind] = []

        for runway in runways {
            if let ident = runway.leIdent, let heading = runway.leHeadingDegT {
                ends.append(end(ident: ident, headingDegT: heading, windFromDegT: windFromDegT, windSpeedKts: windSpeedKts))
            }
            if let ident = runway.heIdent, let heading = runway.heHeadingDegT {
                ends.append(end(ident: ident, headingDegT: heading, windFromDegT: windFromDegT, windSpeedKts: windSpeedKts))
            }
        }

        return ends.sorted {
            if $0.headwindKts != $1.headwindKts { return $0.headwindKts > $1.headwindKts }
            return abs($0.crosswindKts) < abs($1.crosswindKts)
        }
    }

    private static func end(
        ident: String,
        headingDegT: Double,
        windFromDegT: Double,
        windSpeedKts: Double
    ) -> RunwayEndWind {
        RunwayEndWind(
            endIdent: ident,
            headingDegT: headingDegT,
            headwindKts: WindTriangle.headwindComponent(
                courseDeg: headingDegT, windFromDeg: windFromDegT, windSpeedKts: windSpeedKts
            ),
            crosswindKts: WindTriangle.crosswindComponent(
                courseDeg: headingDegT, windFromDeg: windFromDegT, windSpeedKts: windSpeedKts
            )
        )
    }
}
