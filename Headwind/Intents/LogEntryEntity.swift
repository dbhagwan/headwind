import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

/// A logbook flight as Siri, Spotlight, and Shortcuts see it.
///
/// Entities land in the Spotlight semantic index (IndexedEntity), which
/// is what Siri reads to answer personal-context questions — on iOS 27,
/// Siri AI queries this index conversationally ("how much night time do
/// I have in the Skyhawk?"). Everything here compiles against the iOS 26
/// SDK; Siri AI consumes it without app changes.
struct LogEntryEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Logbook Flight",
        numericFormat: "\(placeholder: .int) logbook flights"
    )
    static let defaultQuery = LogEntryQuery()

    var id: UUID

    @Property(title: "Date")
    var date: Date

    @Property(title: "Aircraft Type")
    var aircraftType: String

    @Property(title: "Tail Number")
    var tailNumber: String

    @Property(title: "From")
    var fromIdent: String

    @Property(title: "To")
    var toIdent: String

    @Property(title: "Total Hours")
    var totalHours: Double

    @Property(title: "Night Hours")
    var nightHours: Double

    @Property(title: "Landings")
    var landings: Int

    @Property(title: "Remarks")
    var remarks: String

    init(_ entry: LogEntry) {
        id = entry.uid
        date = entry.date
        aircraftType = entry.aircraftType
        tailNumber = entry.tailNumber
        fromIdent = entry.fromIdent
        toIdent = entry.toIdent
        totalHours = entry.totalHours
        nightHours = entry.nightHours
        landings = entry.dayLandings + entry.nightLandings
        remarks = entry.remarks
    }

    var displayRepresentation: DisplayRepresentation {
        let route = fromIdent.isEmpty
            ? aircraftType
            : "\(fromIdent) → \(toIdent.isEmpty ? fromIdent : toIdent)"
        return DisplayRepresentation(
            title: "\(route)",
            subtitle: "\(date.formatted(date: .abbreviated, time: .omitted)) · \(aircraftType) \(tailNumber) · \(totalHours.formatted(.number.precision(.fractionLength(1)))) h"
        )
    }

    /// Richer text for the semantic index so conversational queries
    /// ("flights to Monterey", "that night flight in the Archer") match.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = "Flight \(fromIdent) to \(toIdent)"
        attributes.contentDescription = """
        Logbook flight on \(date.formatted(date: .long, time: .omitted)) \
        in \(aircraftType) \(tailNumber), \(fromIdent) to \(toIdent), \
        \(totalHours.formatted(.number.precision(.fractionLength(1)))) hours, \
        \(landings) landings.\(nightHours > 0 ? " Night flight." : "") \(remarks)
        """
        attributes.contentCreationDate = date
        return attributes
    }
}

/// Resolves entity identifiers back to logbook rows and suggests recent
/// flights when Siri/Shortcuts offer a picker.
struct LogEntryQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [LogEntryEntity] {
        let context = AppModelContainer.shared.mainContext
        let wanted = Set(identifiers)
        let descriptor = FetchDescriptor<LogEntry>(sortBy: [.init(\.date, order: .reverse)])
        return try context.fetch(descriptor)
            .filter { wanted.contains($0.uid) }
            .map(LogEntryEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [LogEntryEntity] {
        var descriptor = FetchDescriptor<LogEntry>(sortBy: [.init(\.date, order: .reverse)])
        descriptor.fetchLimit = 5
        return try AppModelContainer.shared.mainContext.fetch(descriptor).map(LogEntryEntity.init)
    }
}

/// Keeps the semantic index in step with the logbook. Full reindex is
/// cheap at personal-logbook scale (hundreds to low thousands of rows)
/// and self-heals any missed increment.
enum LogbookIndexer {
    @MainActor
    static func reindexAll() async {
        guard !DemoData.isEnabled else { return }
        do {
            let entries = try AppModelContainer.shared.mainContext
                .fetch(FetchDescriptor<LogEntry>())
            try await CSSearchableIndex.default().indexAppEntities(entries.map(LogEntryEntity.init))
        } catch {
            // Indexing is best-effort; Siri falls back to the query intents.
        }
    }

    @MainActor
    static func remove(_ entry: LogEntry) async {
        try? await CSSearchableIndex.default()
            .deleteAppEntities(identifiedBy: [entry.uid], ofType: LogEntryEntity.self)
    }
}
