import CoreLocation
import Observation

/// Streams device location for the moving map and instrument strip.
@MainActor
@Observable
final class LocationService {
    private let manager = CLLocationManager()
    private var updatesTask: Task<Void, Never>?

    private(set) var lastLocation: CLLocation?

    var coordinate: CLLocationCoordinate2D? { lastLocation?.coordinate }

    /// Ground speed in knots; nil when the fix has no valid speed.
    var groundSpeedKts: Double? {
        guard let speed = lastLocation?.speed, speed >= 0 else { return nil }
        return speed * 1.943844
    }

    /// Track over the ground in degrees true; nil when not moving.
    var trackDeg: Double? {
        guard let course = lastLocation?.course, course >= 0 else { return nil }
        return course
    }

    /// GPS altitude in feet MSL.
    var altitudeFt: Double? {
        lastLocation.map { $0.altitude * 3.28084 }
    }

    func start() {
        guard updatesTask == nil else { return }
        manager.requestWhenInUseAuthorization()
        updatesTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let self else { return }
                    if let location = update.location {
                        self.lastLocation = location
                    }
                }
            } catch {
                // Location updates ended (denied or unavailable); the map
                // falls back to the default region.
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }
}
