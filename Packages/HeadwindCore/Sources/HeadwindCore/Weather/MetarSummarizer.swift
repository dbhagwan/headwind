import Foundation

/// Deterministic plain-English rendering of a METAR.
///
/// Used as the always-available fallback when Apple Intelligence is not
/// available on device, and as grounding context for the AI briefing.
public enum MetarSummarizer {
    public static func plainEnglish(for metar: Metar) -> String {
        var parts: [String] = []

        let station = metar.stationName ?? metar.stationID
        parts.append("Conditions at \(station) are \(metar.flightCategory.rawValue).")

        if let speed = metar.windSpeedKts {
            if speed == 0 {
                parts.append("Winds are calm.")
            } else if metar.windVariable {
                parts.append("Wind is variable at \(speed) knots.")
            } else if let dir = metar.windDirectionDeg {
                var wind = "Wind from \(dir)° at \(speed) knots"
                if let gust = metar.windGustKts {
                    wind += ", gusting \(gust)"
                }
                parts.append(wind + ".")
            }
        }

        if let vis = metar.visibilitySM {
            let value = vis == vis.rounded() ? String(Int(vis)) : String(format: "%.1f", vis)
            parts.append("Visibility \(value) statute miles.")
        }

        if let ceiling = metar.ceilingFt {
            parts.append("Ceiling \(ceiling) feet.")
        } else if metar.clouds.isEmpty || metar.clouds.allSatisfy({ ["CLR", "SKC", "CAVOK"].contains($0.cover.uppercased()) }) {
            parts.append("Sky clear.")
        } else if let lowest = metar.clouds.compactMap(\.baseFt).min() {
            parts.append("Scattered to few clouds, lowest at \(lowest) feet.")
        }

        if let temp = metar.temperatureC {
            var line = "Temperature \(Int(temp.rounded()))°C"
            if let dew = metar.dewpointC {
                line += ", dewpoint \(Int(dew.rounded()))°C"
            }
            parts.append(line + ".")
        }

        if let altim = metar.altimeterInHg {
            parts.append(String(format: "Altimeter %.2f inHg.", altim))
        }

        return parts.joined(separator: " ")
    }
}
