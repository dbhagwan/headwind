import Foundation

/// A platform-agnostic geographic coordinate (degrees).
///
/// HeadwindCore avoids CoreLocation so the domain layer can be built and
/// tested on any platform. The app layer bridges this to
/// `CLLocationCoordinate2D` where needed.
public struct Coordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
