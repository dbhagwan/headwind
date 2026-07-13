import Foundation
import SwiftData

/// A pilot logbook entry, persisted with SwiftData and mirrored to the
/// user's private iCloud database when available. CloudKit requires
/// inline defaults on every stored property.
@Model
final class LogEntry {
    var date: Date = Date.now
    var aircraftType: String = ""
    var tailNumber: String = ""
    var fromIdent: String = ""
    var toIdent: String = ""
    var totalHours: Double = 0
    var picHours: Double = 0
    var nightHours: Double = 0
    var instrumentHours: Double = 0
    var dayLandings: Int = 0
    var nightLandings: Int = 0
    var remarks: String = ""

    init(
        date: Date = .now,
        aircraftType: String = "",
        tailNumber: String = "",
        fromIdent: String = "",
        toIdent: String = "",
        totalHours: Double = 0,
        picHours: Double = 0,
        nightHours: Double = 0,
        instrumentHours: Double = 0,
        dayLandings: Int = 0,
        nightLandings: Int = 0,
        remarks: String = ""
    ) {
        self.date = date
        self.aircraftType = aircraftType
        self.tailNumber = tailNumber
        self.fromIdent = fromIdent
        self.toIdent = toIdent
        self.totalHours = totalHours
        self.picHours = picHours
        self.nightHours = nightHours
        self.instrumentHours = instrumentHours
        self.dayLandings = dayLandings
        self.nightLandings = nightLandings
        self.remarks = remarks
    }
}
