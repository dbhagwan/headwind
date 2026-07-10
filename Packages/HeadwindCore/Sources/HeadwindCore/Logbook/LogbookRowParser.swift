import Foundation

/// A logbook row recovered from a scanned page — every field optional
/// because paper and OCR are both messy. The importer treats these as
/// suggestions for the pilot to review, never as truth.
public struct ParsedLogRow: Equatable, Sendable {
    public var date: Date?
    public var aircraftType: String?
    public var tailNumber: String?
    public var fromIdent: String?
    public var toIdent: String?
    public var totalHours: Double?
    public var landings: Int?
    public var remarks: String?
    /// The OCR line this row came from, for the review UI.
    public var sourceText: String

    public init(
        date: Date? = nil, aircraftType: String? = nil, tailNumber: String? = nil,
        fromIdent: String? = nil, toIdent: String? = nil, totalHours: Double? = nil,
        landings: Int? = nil, remarks: String? = nil, sourceText: String = ""
    ) {
        self.date = date
        self.aircraftType = aircraftType
        self.tailNumber = tailNumber
        self.fromIdent = fromIdent
        self.toIdent = toIdent
        self.totalHours = totalHours
        self.landings = landings
        self.remarks = remarks
        self.sourceText = sourceText
    }
}

/// Heuristic parser for OCR'd paper-logbook rows.
///
/// Standard US logbook columns read left-to-right: date, aircraft
/// make/model, ident (tail number), route from/to, then time columns.
/// The parser keys each entry on a leading date and classifies the rest
/// of the tokens by shape. It is deliberately conservative: a token that
/// doesn't confidently match a field lands in remarks instead.
///
/// This is both the no-Apple-Intelligence fallback and the seed the
/// on-device model refines, so it must never hallucinate structure.
public enum LogbookRowParser {
    /// Parses OCR text (one physical row per line) into log rows.
    /// Lines without a recognizable date are treated as remark
    /// continuations of the previous row.
    public static func parse(_ text: String, calendar: Calendar = .init(identifier: .gregorian)) -> [ParsedLogRow] {
        var rows: [ParsedLogRow] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            guard let (date, rest) = leadingDate(in: line, calendar: calendar) else {
                // Continuation: fold into the previous row's remarks.
                if var last = rows.popLast() {
                    last.remarks = [last.remarks, line].compactMap { $0 }.joined(separator: " ")
                    rows.append(last)
                }
                continue
            }

            var row = ParsedLogRow(date: date, sourceText: line)
            var remainder: [String] = []

            for token in rest.split(separator: " ").map(String.init) {
                let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",;"))
                if row.tailNumber == nil, isTailNumber(cleaned) {
                    row.tailNumber = cleaned.uppercased()
                } else if row.aircraftType == nil, isAircraftType(cleaned) {
                    row.aircraftType = cleaned.uppercased()
                } else if isAirportIdent(cleaned) {
                    if row.fromIdent == nil {
                        row.fromIdent = cleaned.uppercased()
                    } else if row.toIdent == nil {
                        row.toIdent = cleaned.uppercased()
                    } else {
                        remainder.append(cleaned)
                    }
                } else if let hours = Double(cleaned), cleaned.contains("."), hours < 24 {
                    // Time columns: the pilot logs several (total, PIC,
                    // night...). Paper order varies; the LARGEST decimal
                    // on the row is the total, the rest go to review.
                    row.totalHours = max(row.totalHours ?? 0, hours)
                } else if row.landings == nil, let n = Int(cleaned), (0...20).contains(n) {
                    row.landings = n
                } else {
                    remainder.append(token)
                }
            }

            if !remainder.isEmpty {
                row.remarks = remainder.joined(separator: " ")
            }
            rows.append(row)
        }
        return rows
    }

    // MARK: Token shapes

    /// Matches m/d/yy, m-d-yyyy, yyyy-mm-dd at the start of a line.
    /// Returns the parsed date and the rest of the line.
    static func leadingDate(in line: String, calendar: Calendar) -> (Date, String)? {
        let patterns: [(regex: String, order: [Int])] = [
            (#"^(\d{4})-(\d{1,2})-(\d{1,2})\b"#, [0, 1, 2]),          // y m d
            (#"^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b"#, [2, 0, 1]), // m d y
        ]
        for (pattern, order) in patterns {
            guard let match = line.range(of: pattern, options: .regularExpression) else { continue }
            let numbers = line[match]
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            guard numbers.count == 3 else { continue }
            var year = numbers[order[0]]
            let month = numbers[order[1]]
            let day = numbers[order[2]]
            if year < 100 { year += 2000 }
            guard (1...12).contains(month), (1...31).contains(day), (1950...2100).contains(year) else { continue }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.timeZone = TimeZone(identifier: "UTC")
            var utc = calendar
            utc.timeZone = TimeZone(identifier: "UTC")!
            guard let date = utc.date(from: components) else { continue }
            let rest = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (date, rest)
        }
        return nil
    }

    /// US registration: N followed by 1-5 digits, optionally 1-2 letters.
    static func isTailNumber(_ token: String) -> Bool {
        token.uppercased().range(
            of: #"^N\d{1,5}[A-Z]{0,2}$"#, options: .regularExpression
        ) != nil
    }

    /// Aircraft model shapes: C172, C-172, PA28, PA-28-181, SR22, BE36, DA40.
    static func isAircraftType(_ token: String) -> Bool {
        let t = token.uppercased()
        guard !isTailNumber(t) else { return false }
        return t.range(of: #"^[A-Z]{1,2}-?\d{2,3}[A-Z]?(-\d{2,3})?$"#, options: .regularExpression) != nil
    }

    /// Airport idents: KSFO, SFO, 3O1, KPAO. Requires at least one digit
    /// or a K/C/P prefix + 3 letters to avoid eating ordinary words.
    static func isAirportIdent(_ token: String) -> Bool {
        let t = token.uppercased()
        guard t.count >= 3, t.count <= 4,
              t.range(of: #"^[A-Z0-9]+$"#, options: .regularExpression) != nil,
              !isTailNumber(t), !isAircraftType(t) else { return false }
        if t.count == 4, t.first == "K" { return true }
        if t.contains(where: \.isNumber) { return true }
        // Bare 3-letter idents (SFO) are indistinguishable from words;
        // accept only fully-uppercase all-letter triples.
        return t.count == 3 && token == t
    }
}
