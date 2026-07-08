import Foundation

/// One GPS fix in a recorded track.
public struct TrackPoint: Codable, Hashable, Sendable {
    public let timestamp: Date
    public let coordinate: Coordinate
    public let altitudeFt: Double
    public let groundSpeedKts: Double

    public init(timestamp: Date, coordinate: Coordinate, altitudeFt: Double, groundSpeedKts: Double) {
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.altitudeFt = altitudeFt
        self.groundSpeedKts = groundSpeedKts
    }
}

/// A recorded flight track with derived statistics.
public struct TrackLog: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var points: [TrackPoint]

    public init(id: UUID = UUID(), name: String = "", points: [TrackPoint] = []) {
        self.id = id
        self.name = name
        self.points = points
    }

    public var startTime: Date? { points.first?.timestamp }
    public var endTime: Date? { points.last?.timestamp }

    public var durationHours: Double {
        guard let start = startTime, let end = endTime else { return 0 }
        return end.timeIntervalSince(start) / 3600
    }

    /// Ground distance flown, summed great-circle over the breadcrumb.
    public var distanceNM: Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + NavMath.distanceNM(from: pair.0.coordinate, to: pair.1.coordinate)
        }
    }

    public var maxAltitudeFt: Double { points.map(\.altitudeFt).max() ?? 0 }
    public var maxGroundSpeedKts: Double { points.map(\.groundSpeedKts).max() ?? 0 }

    /// GPX 1.1 document for sharing with other tools (ForeFlight, CloudAhoy,
    /// Google Earth all import GPX).
    public func gpx() -> String {
        let formatter = ISO8601DateFormatter()
        let trackpoints = points.map { point in
            """
                  <trkpt lat="\(point.coordinate.latitude)" lon="\(point.coordinate.longitude)">
                    <ele>\(String(format: "%.1f", point.altitudeFt * 0.3048))</ele>
                    <time>\(formatter.string(from: point.timestamp))</time>
                  </trkpt>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Headwind" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(name.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;"))</name>
            <trkseg>
        \(trackpoints)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    /// Route coordinates thinned for map display (keeps endpoints).
    public func simplified(maxPoints: Int = 500) -> [Coordinate] {
        guard maxPoints >= 2 else {
            // A cap below 2 can't represent a path; return the endpoints.
            return [points.first?.coordinate, points.last?.coordinate].compactMap { $0 }
        }
        guard points.count > maxPoints else {
            return points.map(\.coordinate)
        }
        let stride = Double(points.count - 1) / Double(maxPoints - 1)
        var coords = (0..<maxPoints).map { points[min(Int(Double($0) * stride), points.count - 1)].coordinate }
        // FP truncation can land the final sample one short of the true end
        // (e.g. 98.9999… → 98); the endpoint contract is explicit.
        coords[coords.count - 1] = points[points.count - 1].coordinate
        return coords
    }
}

/// Detects flight segments in a track using ground speed with hysteresis:
/// airborne when sustained above `takeoffKts`, landed when sustained below
/// `landingKts` — so taxiing and a bounced landing don't double-count.
public enum FlightDetector {
    public struct Flight: Hashable, Sendable {
        public let takeoffTime: Date
        public let landingTime: Date
        public var airborneHours: Double {
            landingTime.timeIntervalSince(takeoffTime) / 3600
        }
    }

    public static func flights(
        in track: TrackLog,
        takeoffKts: Double = 40,
        landingKts: Double = 30,
        sustainSeconds: TimeInterval = 10
    ) -> [Flight] {
        var flights: [Flight] = []
        var airborne = false
        var candidateSince: Date?
        var takeoffAt: Date?

        for point in track.points {
            if !airborne {
                if point.groundSpeedKts >= takeoffKts {
                    if let since = candidateSince {
                        if point.timestamp.timeIntervalSince(since) >= sustainSeconds {
                            airborne = true
                            takeoffAt = since
                            candidateSince = nil
                        }
                    } else {
                        candidateSince = point.timestamp
                    }
                } else {
                    candidateSince = nil
                }
            } else {
                if point.groundSpeedKts <= landingKts {
                    if let since = candidateSince {
                        if point.timestamp.timeIntervalSince(since) >= sustainSeconds {
                            airborne = false
                            if let takeoff = takeoffAt {
                                flights.append(Flight(takeoffTime: takeoff, landingTime: since))
                            }
                            takeoffAt = nil
                            candidateSince = nil
                        }
                    } else {
                        candidateSince = point.timestamp
                    }
                } else {
                    candidateSince = nil
                }
            }
        }

        // Track ended while airborne (recording stopped in flight).
        if airborne, let takeoff = takeoffAt, let last = track.endTime {
            flights.append(Flight(takeoffTime: takeoff, landingTime: last))
        }
        return flights
    }

    /// Total airborne time across all detected flights, in hours.
    public static func airborneHours(in track: TrackLog) -> Double {
        flights(in: track).reduce(0) { $0 + $1.airborneHours }
    }
}
