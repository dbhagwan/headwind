import Foundation

/// An FB winds-aloft station with a resolved position.
public struct StationWinds: Hashable, Sendable {
    public let station: String
    public let coordinate: Coordinate
    public let winds: [WindAloft]

    public init(station: String, coordinate: Coordinate, winds: [WindAloft]) {
        self.station = station
        self.coordinate = coordinate
        self.winds = winds
    }
}

/// Interpolates the FB winds-aloft grid to an arbitrary point and altitude.
///
/// Method: at each station, linearly interpolate the wind **vector** (u/v
/// components) between the FB levels bracketing the requested altitude
/// (clamping outside the station's range); then blend the nearest stations
/// by inverse-distance weighting. Vector-space interpolation avoids the
/// 359°→001° averaging trap. "Light and variable" reports contribute a calm
/// (zero) vector.
public enum WindsAloftInterpolator {
    public struct Wind: Hashable, Sendable {
        /// Direction the wind blows from, degrees true, (0, 360].
        public let directionFromDeg: Double
        public let speedKts: Double
    }

    public static func wind(
        at point: Coordinate,
        altitudeFt: Int,
        stations: [StationWinds],
        maxStations: Int = 3,
        maxDistanceNM: Double = 600
    ) -> Wind? {
        let candidates = stations
            .compactMap { station -> (u: Double, v: Double, distanceNM: Double)? in
                guard let (u, v) = vector(at: altitudeFt, in: station.winds) else { return nil }
                let d = NavMath.distanceNM(from: point, to: station.coordinate)
                guard d <= maxDistanceNM else { return nil }
                return (u, v, d)
            }
            .sorted { $0.distanceNM < $1.distanceNM }
            .prefix(maxStations)

        guard !candidates.isEmpty else { return nil }

        var uSum = 0.0, vSum = 0.0, wSum = 0.0
        for c in candidates {
            let w = 1.0 / max(c.distanceNM, 1.0)
            uSum += c.u * w
            vSum += c.v * w
            wSum += w
        }
        let u = uSum / wSum
        let v = vSum / wSum

        let speed = (u * u + v * v).squareRoot()
        guard speed > 0.01 else {
            return Wind(directionFromDeg: 360, speedKts: 0)
        }
        var dir = atan2(-u, -v) * 180 / .pi
        dir = NavMath.normalizeDeg(dir)
        if dir == 0 { dir = 360 }
        return Wind(directionFromDeg: dir, speedKts: speed)
    }

    /// Wind vector (u = eastward, v = northward, kts) at one station,
    /// linearly interpolated in altitude. Returns nil when the station has
    /// no usable levels.
    static func vector(at altitudeFt: Int, in winds: [WindAloft]) -> (u: Double, v: Double)? {
        let usable = winds
            .compactMap { wind -> (alt: Int, u: Double, v: Double)? in
                if wind.isLightAndVariable {
                    return (wind.altitudeFt, 0, 0)
                }
                guard let dir = wind.directionDeg, let speed = wind.speedKts else { return nil }
                let theta = Double(dir) * .pi / 180
                return (wind.altitudeFt, -Double(speed) * sin(theta), -Double(speed) * cos(theta))
            }
            .sorted { $0.alt < $1.alt }

        guard let first = usable.first, let last = usable.last else { return nil }
        if altitudeFt <= first.alt { return (first.u, first.v) }
        if altitudeFt >= last.alt { return (last.u, last.v) }

        for (below, above) in zip(usable, usable.dropFirst()) where altitudeFt <= above.alt {
            let span = Double(above.alt - below.alt)
            let t = span > 0 ? Double(altitudeFt - below.alt) / span : 0
            return (below.u + t * (above.u - below.u), below.v + t * (above.v - below.v))
        }
        return (last.u, last.v)
    }
}
