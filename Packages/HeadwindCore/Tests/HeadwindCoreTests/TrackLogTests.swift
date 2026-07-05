import XCTest
@testable import HeadwindCore

final class TrackLogTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a track from (secondsFromStart, speedKts) pairs on a straight
    /// eastbound line along the equator, one point per entry.
    private func track(_ profile: [(Double, Double)]) -> TrackLog {
        TrackLog(points: profile.enumerated().map { index, entry in
            TrackPoint(
                timestamp: t0.addingTimeInterval(entry.0),
                coordinate: Coordinate(latitude: 0, longitude: Double(index) * 0.01),
                altitudeFt: 1000,
                groundSpeedKts: entry.1
            )
        })
    }

    func testStatsOnStraightTrack() {
        // 11 points, 0.01° apart on the equator = 0.6 NM each, 6 NM total.
        let log = track((0...10).map { (Double($0) * 60, 100.0) })
        XCTAssertEqual(log.distanceNM, 6.0, accuracy: 0.01)
        XCTAssertEqual(log.durationHours, 600.0 / 3600.0, accuracy: 1e-9)
        XCTAssertEqual(log.maxGroundSpeedKts, 100)
        XCTAssertEqual(log.maxAltitudeFt, 1000)
    }

    func testSimplifiedKeepsEndpointsAndCapsCount() {
        let log = track((0..<2000).map { (Double($0), 100.0) })
        let thin = log.simplified(maxPoints: 100)
        XCTAssertEqual(thin.count, 100)
        XCTAssertEqual(thin.first, log.points.first?.coordinate)
        XCTAssertEqual(thin.last, log.points.last?.coordinate)
        // Short tracks pass through untouched.
        XCTAssertEqual(track([(0, 50), (60, 50)]).simplified(maxPoints: 100).count, 2)
    }

    func testCodableRoundTrip() throws {
        let log = track([(0, 10), (60, 80), (120, 100)])
        let decoded = try JSONDecoder().decode(TrackLog.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(decoded, log)
    }

    // MARK: Flight detection

    func testDetectsSingleFlightIgnoringTaxi() {
        // Taxi at 10 kt, accelerate, cruise at 100, decelerate, taxi back.
        var profile: [(Double, Double)] = []
        profile += (0..<5).map { (Double($0) * 10, 10.0) }          // taxi 0-40s
        profile += (5..<10).map { (Double($0) * 10, 100.0) }        // roll+climb 50-90s
        profile += (10..<60).map { (Double($0) * 10, 110.0) }       // cruise
        profile += (60..<66).map { (Double($0) * 10, 15.0) }        // rollout 600-650s
        let flights = FlightDetector.flights(in: track(profile))

        XCTAssertEqual(flights.count, 1)
        let flight = flights[0]
        XCTAssertEqual(flight.takeoffTime, t0.addingTimeInterval(50))
        XCTAssertEqual(flight.landingTime, t0.addingTimeInterval(600))
        XCTAssertEqual(flight.airborneHours, 550.0 / 3600.0, accuracy: 1e-9)
    }

    func testBriefGustDoesNotTriggerTakeoff() {
        // One 5-second blip above threshold while taxiing must not count
        // (sustain window is 10 s).
        var profile: [(Double, Double)] = (0..<10).map { (Double($0) * 5, 12.0) }
        profile[4] = (20, 45.0)  // single fast sample
        XCTAssertTrue(FlightDetector.flights(in: track(profile)).isEmpty)
    }

    func testTouchAndGoesCountAsSeparateFlights() {
        var profile: [(Double, Double)] = []
        profile += (0..<20).map { (Double($0) * 10, 100.0) }         // flight 1
        profile += (20..<24).map { (Double($0) * 10, 20.0) }         // down 200-230s
        profile += (24..<44).map { (Double($0) * 10, 100.0) }        // flight 2
        profile += (44..<48).map { (Double($0) * 10, 15.0) }         // down
        let flights = FlightDetector.flights(in: track(profile))
        XCTAssertEqual(flights.count, 2)
    }

    func testRecordingStoppedInFlightClosesAtTrackEnd() {
        let profile = (0..<20).map { (Double($0) * 10, 100.0) }
        let log = track(profile)
        let flights = FlightDetector.flights(in: log)
        XCTAssertEqual(flights.count, 1)
        XCTAssertEqual(flights[0].landingTime, log.endTime)
    }

    func testAirborneHoursSumsFlights() {
        var profile: [(Double, Double)] = []
        profile += (0..<20).map { (Double($0) * 10, 100.0) }
        profile += (20..<24).map { (Double($0) * 10, 20.0) }
        profile += (24..<44).map { (Double($0) * 10, 100.0) }
        profile += (44..<48).map { (Double($0) * 10, 15.0) }
        let hours = FlightDetector.airborneHours(in: track(profile))
        XCTAssertGreaterThan(hours, 0)
        XCTAssertEqual(
            hours,
            FlightDetector.flights(in: track(profile)).reduce(0) { $0 + $1.airborneHours },
            accuracy: 1e-12
        )
    }
}
