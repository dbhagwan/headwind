import Foundation
import SwiftData

/// A pilot logbook entry, persisted with SwiftData.
@Model
final class LogEntry {
    var date: Date
    var aircraftType: String
    var tailNumber: String
    var fromIdent: String
    var toIdent: String
    var totalHours: Double
    var picHours: Double
    var nightHours: Double
    var instrumentHours: Double
    var dayLandings: Int
    var nightLandings: Int
    var remarks: String

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
