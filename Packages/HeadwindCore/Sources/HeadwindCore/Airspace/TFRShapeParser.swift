import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Extracts polygon rings from a tfr.faa.gov XNOTAM detail XML document.
///
/// Geometry lives in `<abdMergedArea>` blocks (one per area group), each a
/// list of `<Avx>` vertices with `<geoLat>39.39N</geoLat>` /
/// `<geoLong>106.68W</geoLong>` hemisphere-suffixed values. Circles are
/// pre-discretized into the merged area by the FAA, so vertices are all we
/// need.
public final class TFRShapeParser: NSObject, XMLParserDelegate {
    public static func polygons(from data: Data) -> [[Coordinate]] {
        let parser = TFRShapeParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()

        if !parser.mergedPolygons.isEmpty {
            return parser.mergedPolygons.filter { $0.count >= 3 }
        }
        // Fallback for documents without a merged area: treat all vertices
        // encountered as a single ring.
        return parser.allVertices.count >= 3 ? [parser.allVertices] : []
    }

    private var mergedPolygons: [[Coordinate]] = []
    private var currentPolygon: [Coordinate]?
    private var allVertices: [Coordinate] = []

    private var inAvx = false
    private var currentElement = ""
    private var latText = ""
    private var lonText = ""

    public func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName: String?, attributes: [String: String]
    ) {
        currentElement = elementName
        switch elementName {
        case "abdMergedArea":
            currentPolygon = []
        case "Avx":
            inAvx = true
            latText = ""
            lonText = ""
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inAvx else { return }
        if currentElement == "geoLat" { latText += string }
        if currentElement == "geoLong" { lonText += string }
    }

    public func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName: String?
    ) {
        switch elementName {
        case "Avx":
            inAvx = false
            if let lat = Self.parseDegrees(latText, positive: "N", negative: "S"),
               let lon = Self.parseDegrees(lonText, positive: "E", negative: "W") {
                let vertex = Coordinate(latitude: lat, longitude: lon)
                allVertices.append(vertex)
                currentPolygon?.append(vertex)
            }
        case "abdMergedArea":
            if let polygon = currentPolygon, polygon.count >= 3 {
                mergedPolygons.append(polygon)
            }
            currentPolygon = nil
        case "geoLat", "geoLong":
            currentElement = "Avx"
        default:
            break
        }
    }

    /// "39.39251459N" → 39.39…, "106.686W" → -106.686.
    static func parseDegrees(_ raw: String, positive: Character, negative: Character) -> Double? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let last = text.last else { return nil }

        var sign = 1.0
        var numeric = text
        if last == negative {
            sign = -1
            numeric = String(text.dropLast())
        } else if last == positive {
            numeric = String(text.dropLast())
        }
        return Double(numeric).map { $0 * sign }
    }
}
