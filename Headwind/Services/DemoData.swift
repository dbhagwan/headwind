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

    static func seedIfNeeded(plan: PlanStore, airports: AirportStore, context: ModelContext) {
        guard isEnabled else { return }

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
