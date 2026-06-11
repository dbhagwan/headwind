import Foundation

/// Solution of the classic wind triangle for a desired course.
public struct WindSolution: Hashable, Sendable {
    /// True heading to fly, degrees `[0, 360)`.
    public let trueHeadingDeg: Double
    /// Resulting ground speed in knots.
    public let groundSpeedKts: Double
    /// Wind correction angle in degrees. Positive means correcting right
    /// (wind from the right of course).
    public let windCorrectionAngleDeg: Double

    public init(trueHeadingDeg: Double, groundSpeedKts: Double, windCorrectionAngleDeg: Double) {
        self.trueHeadingDeg = trueHeadingDeg
        self.groundSpeedKts = groundSpeedKts
        self.windCorrectionAngleDeg = windCorrectionAngleDeg
    }
}

public enum WindTriangle {
    /// Solves heading and ground speed for a desired true course.
    ///
    /// - Parameters:
    ///   - trueCourseDeg: desired course over the ground, degrees true.
    ///   - trueAirspeedKts: true airspeed in knots (must be > 0).
    ///   - windFromDeg: direction the wind is blowing *from*, degrees true.
    ///   - windSpeedKts: wind speed in knots.
    /// - Returns: `nil` when the wind is too strong for the airspeed to hold
    ///   the requested course.
    public static func solve(
        trueCourseDeg: Double,
        trueAirspeedKts: Double,
        windFromDeg: Double,
        windSpeedKts: Double
    ) -> WindSolution? {
        guard trueAirspeedKts > 0 else { return nil }

        // Wind angle relative to course; positive sine = wind from the right.
        let windAngle = NavMath.radians(windFromDeg - trueCourseDeg)
        let crosswind = windSpeedKts * sin(windAngle)
        let headwind = windSpeedKts * cos(windAngle)

        let sinWCA = crosswind / trueAirspeedKts
        guard abs(sinWCA) <= 1 else { return nil }

        let wca = asin(sinWCA)
        let groundSpeed = trueAirspeedKts * cos(wca) - headwind
        guard groundSpeed > 0 else { return nil }

        let heading = NavMath.normalizeDeg(trueCourseDeg + NavMath.degrees(wca))
        return WindSolution(
            trueHeadingDeg: heading,
            groundSpeedKts: groundSpeed,
            windCorrectionAngleDeg: NavMath.degrees(wca)
        )
    }

    /// Headwind (positive) / tailwind (negative) component for a runway or course.
    public static func headwindComponent(courseDeg: Double, windFromDeg: Double, windSpeedKts: Double) -> Double {
        windSpeedKts * cos(NavMath.radians(windFromDeg - courseDeg))
    }

    /// Crosswind component; positive means wind from the right of course.
    public static func crosswindComponent(courseDeg: Double, windFromDeg: Double, windSpeedKts: Double) -> Double {
        windSpeedKts * sin(NavMath.radians(windFromDeg - courseDeg))
    }
}
