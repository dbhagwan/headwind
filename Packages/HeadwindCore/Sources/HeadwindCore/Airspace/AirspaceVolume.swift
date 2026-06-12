import Foundation

public enum AirspaceClass: String, Sendable, CaseIterable, Hashable {
    case b = "B"
    case c = "C"
    case d = "D"
}

/// One controlled-airspace volume (a Class B shelf, a Class C ring, a
/// Class D cylinder) with vertical limits and polygon geometry.
public struct AirspaceVolume: Hashable, Sendable, Identifiable {
    public let id: String
    public let airspaceClass: AirspaceClass
    public let ident: String?
    public let name: String
    public let lowerFt: Int?
    public let upperFt: Int?
    public let polygons: [[Coordinate]]

    public init(
        id: String,
        airspaceClass: AirspaceClass,
        ident: String?,
        name: String,
        lowerFt: Int?,
        upperFt: Int?,
        polygons: [[Coordinate]]
    ) {
        self.id = id
        self.airspaceClass = airspaceClass
        self.ident = ident
        self.name = name
        self.lowerFt = lowerFt
        self.upperFt = upperFt
        self.polygons = polygons
    }
}

/// Decodes the FAA AIS Airspace feature service's GeoJSON responses.
///
/// Uses JSONSerialization rather than Codable because GeoJSON coordinate
/// arrays have geometry-dependent nesting depth.
public enum AirspaceGeoJSON {
    public static func volumes(from data: Data) -> [AirspaceVolume] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else { return [] }

        var result: [AirspaceVolume] = []
        for feature in features {
            guard let props = feature["properties"] as? [String: Any],
                  let classText = props["CLASS_CODE"] as? String,
                  let airspaceClass = AirspaceClass(rawValue: classText.uppercased()),
                  let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }

            let polygons: [[Coordinate]]
            switch type {
            case "Polygon":
                polygons = ((geometry["coordinates"] as? [Any]) ?? []).compactMap(ring)
            case "MultiPolygon":
                polygons = ((geometry["coordinates"] as? [Any]) ?? [])
                    .compactMap { $0 as? [Any] }
                    .flatMap { $0.compactMap(ring) }
            default:
                continue
            }
            guard !polygons.isEmpty else { continue }

            let name = (props["NAME_TXT"] as? String) ?? "Airspace"
            let ident = props["IDENT_TXT"] as? String
            let lower = (props["DISTVERTLOWER_VAL"] as? NSNumber)?.intValue
            let upper = (props["DISTVERTUPPER_VAL"] as? NSNumber)?.intValue

            // Stable content-derived id so re-fetches of overlapping regions
            // dedupe cleanly.
            let anchor = polygons[0][0]
            let id = "\(airspaceClass.rawValue)-\(ident ?? name)-\(lower ?? -1)-\(upper ?? -1)-" +
                String(format: "%.4f_%.4f", anchor.latitude, anchor.longitude)

            result.append(AirspaceVolume(
                id: id,
                airspaceClass: airspaceClass,
                ident: ident,
                name: name,
                lowerFt: lower,
                upperFt: upper,
                polygons: polygons
            ))
        }
        return result
    }

    private static func ring(_ any: Any) -> [Coordinate]? {
        guard let points = any as? [[Any]] else { return nil }
        let coords: [Coordinate] = points.compactMap { point in
            guard point.count >= 2,
                  let lon = (point[0] as? NSNumber)?.doubleValue,
                  let lat = (point[1] as? NSNumber)?.doubleValue else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        }
        return coords.count >= 3 ? coords : nil
    }
}
