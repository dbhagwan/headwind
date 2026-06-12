import Foundation

/// Forecast wind/temperature at one altitude from an FB winds-aloft product.
public struct WindAloft: Hashable, Sendable {
    public let altitudeFt: Int
    /// nil with nil speed = light and variable ("9900").
    public let directionDeg: Int?
    public let speedKts: Int?
    public let temperatureC: Int?

    public init(altitudeFt: Int, directionDeg: Int?, speedKts: Int?, temperatureC: Int?) {
        self.altitudeFt = altitudeFt
        self.directionDeg = directionDeg
        self.speedKts = speedKts
        self.temperatureC = temperatureC
    }

    public var isLightAndVariable: Bool { directionDeg == nil && speedKts == nil }
}

public struct WindsAloftStation: Hashable, Sendable, Identifiable {
    public var id: String { station }
    public let station: String
    public let winds: [WindAloft]

    public init(station: String, winds: [WindAloft]) {
        self.station = station
        self.winds = winds
    }
}

/// Parses the NWS FB (winds and temperatures aloft) text product, e.g.:
///
/// ```
/// FT  3000    6000    9000   12000   18000   24000  30000  34000  39000
/// SFO 2920 2925+10 3030+05 3035+01 3040-13 305525 306541 307450 308157
/// ```
///
/// Decoding rules: `9900` = light and variable; directions 51–86 mean
/// direction−50 with speed+100; temperatures above 24,000 ft are implicitly
/// negative. Cells may be blank when the level is below station elevation,
/// so tokens are matched to altitude columns by position.
public enum WindsAloftParser {
    public static func parse(_ text: String) -> [WindsAloftStation] {
        let lines = text.components(separatedBy: .newlines)
        guard let headerLine = lines.first(where: { $0.hasPrefix("FT") }) else { return [] }

        let altitudeColumns: [(altitude: Int, range: Range<Int>)] = tokens(in: headerLine)
            .compactMap { token in
                guard token.text != "FT", let alt = Int(token.text) else { return nil }
                return (alt, token.range)
            }
        guard !altitudeColumns.isEmpty else { return [] }

        var stations: [WindsAloftStation] = []
        var pastHeader = false

        for line in lines {
            if line.hasPrefix("FT") {
                pastHeader = true
                continue
            }
            guard pastHeader else { continue }

            let lineTokens = tokens(in: line)
            guard let first = lineTokens.first,
                  first.text.count >= 2, first.text.count <= 4,
                  first.text.allSatisfy({ $0.isLetter }) else { continue }

            var winds: [WindAloft] = []
            for token in lineTokens.dropFirst() {
                guard let column = bestColumn(for: token.range, in: altitudeColumns),
                      let wind = decodeCell(token.text, altitudeFt: column) else { continue }
                winds.append(wind)
            }
            if !winds.isEmpty {
                stations.append(WindsAloftStation(station: first.text, winds: winds))
            }
        }
        return stations
    }

    /// Decodes one FB cell like "2925+10", "305525", or "9900".
    static func decodeCell(_ cell: String, altitudeFt: Int) -> WindAloft? {
        var body = cell
        var temperature: Int?

        if let signIndex = body.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) {
            let tempPart = String(body[signIndex...])
            temperature = Int(tempPart)
            body = String(body[..<signIndex])
        } else if body.count == 6, altitudeFt >= 24000 {
            // Above 24,000 ft temps are appended without a sign and negative.
            temperature = Int(body.suffix(2)).map { -$0 }
            body = String(body.prefix(4))
        }

        guard body.count == 4,
              let dirRaw = Int(body.prefix(2)),
              let speedRaw = Int(body.suffix(2)) else { return nil }

        if dirRaw == 99 && speedRaw == 0 {
            return WindAloft(altitudeFt: altitudeFt, directionDeg: nil, speedKts: nil, temperatureC: temperature)
        }

        var direction = dirRaw
        var speed = speedRaw
        if direction > 36 && direction <= 86 {
            direction -= 50
            speed += 100
        }
        guard direction >= 1 && direction <= 36 else { return nil }

        return WindAloft(
            altitudeFt: altitudeFt,
            directionDeg: direction * 10 % 360 == 0 ? 360 : direction * 10,
            speedKts: speed,
            temperatureC: temperature
        )
    }

    private struct Token { let text: String; let range: Range<Int> }

    private static func tokens(in line: String) -> [Token] {
        var result: [Token] = []
        var current = ""
        var start = 0
        for (i, ch) in line.enumerated() {
            if ch == " " || ch == "\t" {
                if !current.isEmpty {
                    result.append(Token(text: current, range: start..<i))
                    current = ""
                }
            } else {
                if current.isEmpty { start = i }
                current.append(ch)
            }
        }
        if !current.isEmpty {
            result.append(Token(text: current, range: start..<line.count))
        }
        return result
    }

    /// Matches a data token to the altitude column with the closest end
    /// position (FB products right-align cells under their headers).
    private static func bestColumn(for range: Range<Int>, in columns: [(altitude: Int, range: Range<Int>)]) -> Int? {
        columns.min { lhs, rhs in
            abs(lhs.range.upperBound - range.upperBound) < abs(rhs.range.upperBound - range.upperBound)
        }?.altitude
    }
}
