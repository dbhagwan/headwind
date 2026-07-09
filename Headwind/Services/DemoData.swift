import Foundation
import SwiftData
import HeadwindCore

/// Seeds representative content when launched with `-demoData`
/// (used by CI screenshot automation and for demos — never in normal use).
@MainActor
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    /// A believable Bay Tour breadcrumb: taxi at KPAO, a 24-minute loop out
    /// over the bay at 2,400 ft, and a landing back home — so the Track Logs
    /// screens have real-looking content in demos and captures.
    static func sampleTrack() -> TrackLog {
        let start = Date.now.addingTimeInterval(-3600)
        let kpao = Coordinate(latitude: 37.4611, longitude: -122.1150)
        var points: [TrackPoint] = []

        // Taxi (3 min at 8 kt).
        for i in 0..<9 {
            points.append(TrackPoint(
                timestamp: start.addingTimeInterval(Double(i) * 20),
                coordinate: kpao,
                altitudeFt: 10,
                groundSpeedKts: 8
            ))
        }
        // Airborne loop: 72 samples over 24 min, an ellipse over the bay.
        for i in 0..<72 {
            let t = Double(i) / 71.0
            let angle = t * 2 * Double.pi
            let coordinate = Coordinate(
                latitude: kpao.latitude + 0.09 * sin(angle),
                longitude: kpao.longitude - 0.12 * (1 - cos(angle)) / 2
            )
            let altitude = 2400.0 * min(1, min(t / 0.12, (1 - t) / 0.12)) + 10
            points.append(TrackPoint(
                timestamp: start.addingTimeInterval(180 + t * 1440),
                coordinate: coordinate,
                altitudeFt: altitude,
                groundSpeedKts: 105
            ))
        }
        // Rollout and taxi in (90 s).
        for i in 0..<5 {
            points.append(TrackPoint(
                timestamp: start.addingTimeInterval(1640 + Double(i) * 20),
                coordinate: kpao,
                altitudeFt: 10,
                groundSpeedKts: 12
            ))
        }
        return TrackLog(name: "Bay Tour (sample)", points: points)
    }

    /// `-screenshotAirport KSFO` → "KSFO"; used by capture automation to
    /// open an airport detail page directly.
    static var screenshotAirportIdent: String? {
        argumentValue(of: "-screenshotAirport")
    }

    /// `-screenshotMapSheet KSFO` → opens that airport's sheet over the
    /// map. Combine with `-screenshotMapSheetLarge` to expand it fully —
    /// the pair exists to verify the glass background at both detents.
    static var screenshotMapSheetIdent: String? {
        argumentValue(of: "-screenshotMapSheet")
    }

    static var screenshotMapSheetIsLarge: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMapSheetLarge")
    }

    /// `-screenshotMapSheetFraction 0.9` → expand the sheet to that
    /// fractional detent. Used to find the tallest detent that still
    /// keeps the system Liquid Glass (iOS fades sheets to opaque as
    /// they approach full height).
    static var screenshotMapSheetFraction: Double? {
        argumentValue(of: "-screenshotMapSheetFraction").flatMap(Double.init)
    }

    /// `-screenshotMapSheetGlassBG` → experiment: replace the system
    /// sheet background with an explicit glassEffect at the large detent.
    static var screenshotMapSheetGlassBG: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMapSheetGlassBG")
    }

    private static func argumentValue(of flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func seedIfNeeded(
        plan: PlanStore,
        airports: AirportStore,
        tracks: TrackRecorder,
        context: ModelContext
    ) {
        guard isEnabled else { return }

        if tracks.savedTracks.isEmpty {
            tracks.save(sampleTrack())
        }

        // Screenshots showcase the clean aeronautical mode (vector airspace
        // on the muted base map); sectionals stay one tap away in the menu.
        UserDefaults.standard.set(ChartLayer.none.rawValue, forKey: "map.chartLayer")
        UserDefaults.standard.set(true, forKey: "map.showsAirspace")

        if plan.waypoints.isEmpty {
            plan.setRoute("KPAO KSFO KOAK KSJC", database: airports.database)
            plan.performance = CruisePerformance(
                trueAirspeedKts: 110,
                fuelBurnGPH: 8.5,
                windFromDeg: 290,
                windSpeedKts: 12
            )
        }

        let existing = (try? context.fetchCount(FetchDescriptor<LogEntry>())) ?? 0
        guard existing == 0 else { return }

        let day: TimeInterval = 86_400
        context.insert(LogEntry(
            date: Date.now.addingTimeInterval(-3 * day),
            aircraftType: "C172S", tailNumber: "N737HW",
            fromIdent: "KPAO", toIdent: "KHAF",
            totalHours: 1.4, picHours: 1.4,
            dayLandings: 3,
            remarks: "Coastal tour, light chop over the ridge."
        ))
        context.insert(LogEntry(
            date: Date.now.addingTimeInterval(-10 * day),
            aircraftType: "C172S", tailNumber: "N737HW",
            fromIdent: "KPAO", toIdent: "KSAC",
            totalHours: 2.1, picHours: 2.1, nightHours: 0.6,
            dayLandings: 1, nightLandings: 1,
            remarks: "Night currency. Smooth air, great visibility."
        ))
        context.insert(LogEntry(
            date: Date.now.addingTimeInterval(-21 * day),
            aircraftType: "C182T", tailNumber: "N271GB",
            fromIdent: "KSQL", toIdent: "KMRY",
            totalHours: 1.8, picHours: 1.8, instrumentHours: 0.9,
            dayLandings: 2,
            remarks: "IFR practice, two approaches at MRY."
        ))
    }
}
