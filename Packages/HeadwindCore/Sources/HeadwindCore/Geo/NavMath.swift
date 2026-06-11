import Foundation

/// Great-circle navigation math on a spherical earth model.
public enum NavMath {
    /// Mean earth radius in nautical miles.
    public static let earthRadiusNM = 3440.065

    /// Great-circle distance between two coordinates, in nautical miles (haversine).
    public static func distanceNM(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = radians(a.latitude)
        let lat2 = radians(b.latitude)
        let dLat = radians(b.latitude - a.latitude)
        let dLon = radians(b.longitude - a.longitude)

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))
        return earthRadiusNM * c
    }

    /// Initial true course from `a` to `b`, in degrees `[0, 360)`.
    public static func initialBearingDeg(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = radians(a.latitude)
        let lat2 = radians(b.latitude)
        let dLon = radians(b.longitude - a.longitude)

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalizeDeg(degrees(atan2(y, x)))
    }

    /// The point reached by traveling `distanceNM` from `origin` along the
    /// great circle with the given initial true bearing.
    public static func destination(from origin: Coordinate, bearingDeg: Double, distanceNM: Double) -> Coordinate {
        let delta = distanceNM / earthRadiusNM
        let theta = radians(bearingDeg)
        let lat1 = radians(origin.latitude)
        let lon1 = radians(origin.longitude)

        let lat2 = asin(sin(lat1) * cos(delta) + cos(lat1) * sin(delta) * cos(theta))
        let lon2 = lon1 + atan2(
            sin(theta) * sin(delta) * cos(lat1),
            cos(delta) - sin(lat1) * sin(lat2)
        )
        return Coordinate(
            latitude: degrees(lat2),
            longitude: normalizeLonDeg(degrees(lon2))
        )
    }

    /// Midpoint of the great circle between two coordinates.
    public static func midpoint(_ a: Coordinate, _ b: Coordinate) -> Coordinate {
        let lat1 = radians(a.latitude)
        let lat2 = radians(b.latitude)
        let lon1 = radians(a.longitude)
        let dLon = radians(b.longitude - a.longitude)

        let bx = cos(lat2) * cos(dLon)
        let by = cos(lat2) * sin(dLon)
        let lat = atan2(
            sin(lat1) + sin(lat2),
            sqrt((cos(lat1) + bx) * (cos(lat1) + bx) + by * by)
        )
        let lon = lon1 + atan2(by, cos(lat1) + bx)
        return Coordinate(latitude: degrees(lat), longitude: normalizeLonDeg(degrees(lon)))
    }

    /// Normalizes any angle to `[0, 360)` degrees.
    public static func normalizeDeg(_ deg: Double) -> Double {
        let r = deg.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Normalizes a longitude to `[-180, 180)` degrees.
    public static func normalizeLonDeg(_ deg: Double) -> Double {
        var lon = deg.truncatingRemainder(dividingBy: 360)
        if lon >= 180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        return lon
    }

    static func radians(_ deg: Double) -> Double { deg * .pi / 180 }
    static func degrees(_ rad: Double) -> Double { rad * 180 / .pi }
}
