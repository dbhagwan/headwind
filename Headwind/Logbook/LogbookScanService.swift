import Foundation
import Observation
import Vision
import UIKit
import HeadwindCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One scanned entry awaiting pilot review before import. Identity is
/// stable so the review list can edit in place.
struct ScannedLogEntry: Identifiable {
    let id = UUID()
    var include = true
    var date: Date
    var aircraftType: String
    var tailNumber: String
    var fromIdent: String
    var toIdent: String
    var totalHours: Double
    var landings: Int
    var remarks: String
    var sourceText: String

    init(row: ParsedLogRow) {
        date = row.date ?? .now
        aircraftType = row.aircraftType ?? ""
        tailNumber = row.tailNumber ?? ""
        fromIdent = row.fromIdent ?? ""
        toIdent = row.toIdent ?? ""
        totalHours = row.totalHours ?? 0
        landings = row.landings ?? 0
        remarks = row.remarks ?? ""
        sourceText = row.sourceText
    }

    func toLogEntry() -> LogEntry {
        LogEntry(
            date: date,
            aircraftType: aircraftType,
            tailNumber: tailNumber,
            fromIdent: fromIdent,
            toIdent: toIdent,
            totalHours: totalHours,
            picHours: totalHours,
            dayLandings: landings,
            remarks: remarks.isEmpty ? "Imported from scanned logbook page." : remarks + " (scanned)"
        )
    }
}

/// OCRs scanned logbook pages and structures the text into entries.
///
/// Text recognition is Vision, on-device. Structuring prefers the
/// on-device Apple Intelligence model (better at messy handwriting and
/// nonstandard column orders); the deterministic HeadwindCore parser is
/// both the fallback and the safety net when generation fails. Nothing
/// leaves the device.
@MainActor
@Observable
final class LogbookScanService {
    enum Phase: Equatable {
        case idle
        case recognizing(page: Int, of: Int)
        case structuring
        case done
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Settable: the review screen edits entries in place before import.
    var entries: [ScannedLogEntry] = []

    var engineDescription: String {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            return "Parsed on-device with Apple Intelligence"
        }
        #endif
        return "Parsed on-device"
    }

    func reset() {
        phase = .idle
        entries = []
    }

    /// Seeds the review UI without a camera — capture automation only.
    func seedDemoEntries() {
        let sample = """
        3/14/24 C172 N737HW KPAO KHAF 1.2 2 Coastal tour, pattern work
        3/21/24 C172 N737HW KPAO KPAO 0.9 3 three landings full stop
        4/02/24 SR22 N45AB KSQL KMRY 1.8 1 lunch run
        4/11/24 PA-28-181 N8231C KMRY KSQL 1.7 1 night return
        """
        entries = LogbookRowParser.parse(sample).map(ScannedLogEntry.init)
        phase = .done
    }

    func process(images: [UIImage]) async {
        entries = []
        var pageTexts: [String] = []

        for (index, image) in images.enumerated() {
            phase = .recognizing(page: index + 1, of: images.count)
            do {
                pageTexts.append(try await Self.recognizeRows(in: image))
            } catch {
                phase = .failed("Couldn't read page \(index + 1): \(error.localizedDescription)")
                return
            }
        }

        phase = .structuring
        let text = pageTexts.joined(separator: "\n")
        let heuristic = LogbookRowParser.parse(text).map(ScannedLogEntry.init)

        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            if let refined = try? await Self.structureWithModel(text), !refined.isEmpty {
                entries = refined
                phase = .done
                return
            }
        }
        #endif

        entries = heuristic
        phase = heuristic.isEmpty
            ? .failed("No logbook rows recognized. Try a flatter, brighter photo of the page.")
            : .done
    }

    // MARK: OCR

    /// Recognizes text and reassembles physical table rows: observations
    /// are bucketed by vertical center so one logbook line becomes one
    /// text line regardless of column detection order.
    nonisolated private static func recognizeRows(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false  // idents/tails aren't words

        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let observations = request.results ?? []

        struct Fragment { let midY: CGFloat; let minX: CGFloat; let text: String }
        let fragments = observations.compactMap { obs -> Fragment? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let box = obs.boundingBox
            return Fragment(midY: box.midY, minX: box.minX, text: candidate.string)
        }

        // Bucket into rows: fragments whose vertical centers are within
        // half a typical line height belong to the same physical row.
        let sorted = fragments.sorted { $0.midY > $1.midY }  // Vision Y is bottom-up
        var rows: [[Fragment]] = []
        for fragment in sorted {
            if var current = rows.last, let anchor = current.first,
               abs(anchor.midY - fragment.midY) < 0.012 {
                current.append(fragment)
                rows[rows.count - 1] = current
            } else {
                rows.append([fragment])
            }
        }
        return rows
            .map { $0.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }

    // MARK: Apple Intelligence structuring

    #if canImport(FoundationModels)
    @Generable
    struct ModelPage {
        @Guide(description: "Every flight row found on the page, in order")
        var rows: [ModelRow]
    }

    @Generable
    struct ModelRow {
        @Guide(description: "Flight date as yyyy-MM-dd")
        var date: String
        @Guide(description: "Aircraft make/model, e.g. C172, PA-28-181; empty if absent")
        var aircraftType: String
        @Guide(description: "Registration/tail number, e.g. N737HW; empty if absent")
        var tailNumber: String
        @Guide(description: "Departure airport identifier; empty if absent")
        var fromIdent: String
        @Guide(description: "Arrival airport identifier; empty if absent")
        var toIdent: String
        @Guide(description: "Total flight time in decimal hours")
        var totalHours: Double
        @Guide(description: "Number of landings, 0 if not shown")
        var landings: Int
        @Guide(description: "Remarks text; empty if absent")
        var remarks: String
    }

    nonisolated private static func structureWithModel(_ text: String) async throws -> [ScannedLogEntry] {
        let session = LanguageModelSession(instructions: """
        You extract pilot logbook entries from OCR text of a paper \
        logbook page. Each input line is one physical row. Use only \
        values present in the text — never invent data. Dates become \
        yyyy-MM-dd (two-digit years are 20xx). Decimal numbers under 24 \
        are flight hours; the largest on a row is the total. Skip \
        header, footer, and column-total rows.
        """)
        let response = try await session.respond(to: text, generating: ModelPage.self)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        return response.content.rows.compactMap { row in
            guard let date = formatter.date(from: row.date) else { return nil }
            guard row.totalHours >= 0, row.totalHours < 24 else { return nil }
            var parsed = ParsedLogRow(sourceText: "")
            parsed.date = date
            parsed.aircraftType = row.aircraftType.isEmpty ? nil : row.aircraftType
            parsed.tailNumber = row.tailNumber.isEmpty ? nil : row.tailNumber
            parsed.fromIdent = row.fromIdent.isEmpty ? nil : row.fromIdent
            parsed.toIdent = row.toIdent.isEmpty ? nil : row.toIdent
            parsed.totalHours = row.totalHours
            parsed.landings = row.landings
            parsed.remarks = row.remarks.isEmpty ? nil : row.remarks
            return ScannedLogEntry(row: parsed)
        }
    }
    #endif
}
