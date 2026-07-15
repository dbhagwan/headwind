import AppIntents
import Foundation
import SwiftData

/// Time windows a pilot naturally asks about.
enum LogPeriod: String, AppEnum {
    case allTime, thisYear, thisMonth, last30Days, last90Days

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Period")
    static let caseDisplayRepresentations: [LogPeriod: DisplayRepresentation] = [
        .allTime: "All Time",
        .thisYear: "This Year",
        .thisMonth: "This Month",
        .last30Days: "Last 30 Days",
        .last90Days: "Last 90 Days",
    ]

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .allTime: return nil
        case .thisYear: return calendar.date(from: calendar.dateComponents([.year], from: .now))
        case .thisMonth: return calendar.date(from: calendar.dateComponents([.year, .month], from: .now))
        case .last30Days: return calendar.date(byAdding: .day, value: -30, to: .now)
        case .last90Days: return calendar.date(byAdding: .day, value: -90, to: .now)
        }
    }
}

/// "How many hours have I flown this year?" — totals over a period,
/// optionally filtered by aircraft type or tail number.
struct LogbookSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Flight Time Totals"
    static let description = IntentDescription(
        "Totals hours, flights, and landings from your logbook.",
        categoryName: "Logbook"
    )

    @Parameter(title: "Period", default: .allTime)
    var period: LogPeriod

    @Parameter(title: "Aircraft", description: "Type or tail number, e.g. C172 or N737HW")
    var aircraft: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Total my flight time \(\.$period)") {
            \.$aircraft
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        var entries = try AppModelContainer.shared.mainContext
            .fetch(FetchDescriptor<LogEntry>())
        if let start = period.startDate {
            entries = entries.filter { $0.date >= start }
        }
        if let aircraft, !aircraft.isEmpty {
            let needle = aircraft.uppercased()
            entries = entries.filter {
                $0.aircraftType.uppercased().contains(needle)
                    || $0.tailNumber.uppercased().contains(needle)
            }
        }

        let hours = entries.reduce(0) { $0 + $1.totalHours }
        let night = entries.reduce(0) { $0 + $1.nightHours }
        let landings = entries.reduce(0) { $0 + $1.dayLandings + $1.nightLandings }

        let periodPhrase = LogPeriod.caseDisplayRepresentations[period]
            .map { String(localized: $0.title) }?.lowercased() ?? ""
        let aircraftPhrase = aircraft.map { " in \($0)" } ?? ""
        var dialog = "You've logged \(hours.formatted(.number.precision(.fractionLength(1)))) hours across \(entries.count) flights\(aircraftPhrase) \(periodPhrase), with \(landings) landings."
        if night > 0 {
            dialog += " \(night.formatted(.number.precision(.fractionLength(1)))) of those hours were at night."
        }
        return .result(value: hours, dialog: IntentDialog(stringLiteral: dialog))
    }
}

/// "Find my flights to Half Moon Bay" — searches the logbook by airport,
/// aircraft, or period; returns entities Siri can present or chain into
/// follow-up actions.
struct FindFlightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Flights"
    static let description = IntentDescription(
        "Searches your logbook for matching flights.",
        categoryName: "Logbook"
    )

    @Parameter(title: "Airport", description: "Identifier like KHAF, matched against origin and destination")
    var airport: String?

    @Parameter(title: "Aircraft", description: "Type or tail number")
    var aircraft: String?

    @Parameter(title: "Period", default: .allTime)
    var period: LogPeriod

    static var parameterSummary: some ParameterSummary {
        Summary("Find flights \(\.$period)") {
            \.$airport
            \.$aircraft
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[LogEntryEntity]> {
        var entries = try AppModelContainer.shared.mainContext
            .fetch(FetchDescriptor<LogEntry>(sortBy: [.init(\.date, order: .reverse)]))
        if let start = period.startDate {
            entries = entries.filter { $0.date >= start }
        }
        if let airport, !airport.isEmpty {
            let needle = airport.uppercased()
            entries = entries.filter {
                $0.fromIdent.uppercased().contains(needle)
                    || $0.toIdent.uppercased().contains(needle)
            }
        }
        if let aircraft, !aircraft.isEmpty {
            let needle = aircraft.uppercased()
            entries = entries.filter {
                $0.aircraftType.uppercased().contains(needle)
                    || $0.tailNumber.uppercased().contains(needle)
            }
        }

        let results = entries.prefix(25).map(LogEntryEntity.init)
        let dialog: IntentDialog = results.isEmpty
            ? "No matching flights in your logbook."
            : IntentDialog(stringLiteral: "Found \(entries.count) matching flight\(entries.count == 1 ? "" : "s").")
        return .result(value: Array(results), dialog: dialog)
    }
}

/// "Show my logbook" — opens the app on the Logbook tab.
struct OpenLogbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Logbook"
    static let description = IntentDescription("Opens Headwind to the logbook.", categoryName: "Logbook")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppTabRouter.requested = .logbook
        return .result()
    }
}

/// Cold-launch-safe tab routing for intents: the intent may run before
/// ContentView exists, so the request is stored and consumed on appear.
@MainActor
enum AppTabRouter {
    static var requested: AppTab? {
        didSet {
            if requested != nil {
                NotificationCenter.default.post(name: .headwindTabRequested, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let headwindTabRequested = Notification.Name("headwind.tabRequested")
}

/// Natural phrases Siri recognizes without any user setup.
struct HeadwindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogbookSummaryIntent(),
            phrases: [
                "How many hours have I flown in \(.applicationName)",
                "What's my flight time in \(.applicationName)",
                "Total my logbook in \(.applicationName)",
            ],
            shortTitle: "Flight Time Totals",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: FindFlightsIntent(),
            phrases: [
                "Find my flights in \(.applicationName)",
                "Search my logbook in \(.applicationName)",
            ],
            shortTitle: "Find Flights",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OpenLogbookIntent(),
            phrases: [
                "Show my logbook in \(.applicationName)",
                "Open my logbook in \(.applicationName)",
            ],
            shortTitle: "Open Logbook",
            systemImageName: "book.closed"
        )
    }
}
