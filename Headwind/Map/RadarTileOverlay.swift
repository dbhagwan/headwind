import MapKit

/// Live NEXRAD composite reflectivity tiles from the Iowa Environmental
/// Mesonet's public cache of NWS radar (no key required). Radar refreshes
/// roughly every 5 minutes; the URL carries a 5-minute time bucket so
/// MapKit's tile cache rolls over as new sweeps arrive.
final class RadarTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: nil)
        minimumZ = 3
        maximumZ = 12
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let bucket = Int(Date.now.timeIntervalSince1970 / 300)
        return URL(string:
            "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/\(path.z)/\(path.x)/\(path.y).png?ts=\(bucket)"
        )!
    }
}
