import Foundation
import CoreLocation
import Observation
import HeadwindCore

/// Records GPS breadcrumb tracks and stores them durably as JSON, one file
/// per track. Runs its own location stream while recording so the map's
/// LocationService lifecycle can't clip a log.
@MainActor
@Observable
final class TrackRecorder {
    private(set) var isRecording = false
    private(set) var activeTrack = TrackLog()
    private(set) var savedTracks: [TrackLog] = []

    private var streamTask: Task<Void, Never>?
    private let manager = CLLocationManager()
    private let directory = DurableStorage.directory("Tracks")

    init() {
        loadSavedTracks()
    }

    // MARK: Recording

    func start() {
        guard !isRecording else { return }
        manager.requestWhenInUseAuthorization()
        activeTrack = TrackLog(name: Self.defaultName(for: .now))
        isRecording = true

        streamTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let self, self.isRecording else { return }
                    guard let location = update.location else { continue }
                    self.append(location)
                }
            } catch {
                // Stream ended (permission revoked etc.); keep what we have.
            }
        }
    }

    /// Stops recording and persists the track if it has any substance.
    /// - Returns: the finished track, or nil if it was too short to keep.
    @discardableResult
    func stop() -> TrackLog? {
        guard isRecording else { return nil }
        isRecording = false
        streamTask?.cancel()
        streamTask = nil

        guard activeTrack.points.count >= 2 else { return nil }
        let finished = activeTrack
        save(finished)
        return finished
    }

    private func append(_ location: CLLocation) {
        let point = TrackPoint(
            timestamp: location.timestamp,
            coordinate: Coordinate(location.coordinate),
            altitudeFt: location.altitude * 3.28084,
            groundSpeedKts: max(0, location.speed) * 1.943844
        )
        // Thin at the source: keep a point when 3 s have passed or we moved
        // meaningfully; a 2-hour flight stays around a few thousand points.
        if let last = activeTrack.points.last {
            let dt = point.timestamp.timeIntervalSince(last.timestamp)
            let moved = NavMath.distanceNM(from: last.coordinate, to: point.coordinate)
            guard dt >= 3 || moved > 0.02 else { return }
        }
        activeTrack.points.append(point)
    }

    // MARK: Store

    func loadSavedTracks() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        savedTracks = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(TrackLog.self, from: data)
            }
            .sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
    }

    func save(_ track: TrackLog) {
        if let data = try? JSONEncoder().encode(track) {
            try? data.write(to: fileURL(for: track), options: .atomic)
        }
        loadSavedTracks()
    }

    func delete(_ track: TrackLog) {
        try? FileManager.default.removeItem(at: fileURL(for: track))
        loadSavedTracks()
    }

    private func fileURL(for track: TrackLog) -> URL {
        directory.appendingPathComponent("\(track.id.uuidString).json")
    }

    private static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Flight \(formatter.string(from: date))"
    }
}
