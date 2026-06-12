import SwiftUI
import MapKit
import HeadwindCore

/// One-shot camera instruction delivered through SwiftUI state.
struct MapCameraCommand: Equatable {
    enum Action: Equatable {
        case followUser
        case fitRoute([Coordinate])
    }
    let id: UUID
    let action: Action

    static func followUser() -> Self { .init(id: UUID(), action: .followUser) }
    static func fitRoute(_ coords: [Coordinate]) -> Self { .init(id: UUID(), action: .fitRoute(coords)) }
}

/// MKMapView wrapper: FAA chart tile overlays, TFR polygons, route line,
/// and zoom-filtered airport annotations. SwiftUI's `Map` can't host
/// `MKTileOverlay`, and charts are the heart of an EFB — so the moving map
/// lives on MapKit's UIKit surface with the Liquid Glass UI layered above.
struct FlightMapView: UIViewRepresentable {
    var airports: [Airport]
    var categories: [String: FlightCategory]
    var route: [Coordinate]
    var chartLayer: ChartLayer
    var showsImagery: Bool
    var tfrs: [TFR]
    var showsTFRs: Bool
    var cameraCommand: MapCameraCommand?
    var onRegionChange: (MKCoordinateRegion) -> Void
    var onSelectAirport: (Airport) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.setUserTrackingMode(.follow, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.syncMapType(map)
        c.syncChartLayer(map)
        c.syncRoute(map)
        c.syncTFRs(map)
        c.syncAirports(map)
        c.runCameraCommand(map)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FlightMapView

        private var tileOverlay: CachingTileOverlay?
        private var routeLine: MKPolyline?
        private var routeCoords: [Coordinate] = []
        private var tfrOverlayIDs: Set<String> = []
        private var tfrOverlays: [MKPolygon] = []
        private var annotations: [String: AirportAnnotation] = [:]
        private var lastCommandID: UUID?

        init(parent: FlightMapView) {
            self.parent = parent
        }

        // MARK: Sync

        func syncMapType(_ map: MKMapView) {
            let wanted: MKMapType = parent.showsImagery ? .hybrid : .standard
            if map.mapType != wanted { map.mapType = wanted }
        }

        func syncChartLayer(_ map: MKMapView) {
            guard tileOverlay?.layer != parent.chartLayer else { return }
            if let old = tileOverlay {
                map.removeOverlay(old)
                tileOverlay = nil
            }
            if parent.chartLayer != .none {
                let overlay = CachingTileOverlay(layer: parent.chartLayer)
                map.addOverlay(overlay, level: .aboveLabels)
                tileOverlay = overlay
            }
        }

        func syncRoute(_ map: MKMapView) {
            guard routeCoords != parent.route else { return }
            routeCoords = parent.route
            if let old = routeLine {
                map.removeOverlay(old)
                routeLine = nil
            }
            if routeCoords.count >= 2 {
                let coords = routeCoords.map(\.cl)
                let line = MKPolyline(coordinates: coords, count: coords.count)
                map.addOverlay(line, level: .aboveLabels)
                routeLine = line
            }
        }

        func syncTFRs(_ map: MKMapView) {
            let wanted = parent.showsTFRs ? parent.tfrs : []
            let wantedIDs = Set(wanted.map(\.id))
            guard wantedIDs != tfrOverlayIDs else { return }

            map.removeOverlays(tfrOverlays)
            tfrOverlays = wanted.flatMap { tfr in
                tfr.polygons.map { ring -> MKPolygon in
                    let coords = ring.map(\.cl)
                    return MKPolygon(coordinates: coords, count: coords.count)
                }
            }
            map.addOverlays(tfrOverlays, level: .aboveLabels)
            tfrOverlayIDs = wantedIDs
        }

        func syncAirports(_ map: MKMapView) {
            let wanted = Dictionary(uniqueKeysWithValues: parent.airports.map { ($0.ident, $0) })

            for (ident, annotation) in annotations where wanted[ident] == nil {
                map.removeAnnotation(annotation)
                annotations[ident] = nil
            }

            for (ident, airport) in wanted {
                let category = parent.categories[ident]
                if let existing = annotations[ident] {
                    if existing.category != category {
                        existing.category = category
                        if let view = map.view(for: existing) {
                            view.image = MarkerImages.image(kind: airport.kind, category: category)
                        }
                    }
                } else {
                    let annotation = AirportAnnotation(airport: airport, category: category)
                    annotations[ident] = annotation
                    map.addAnnotation(annotation)
                }
            }
        }

        func runCameraCommand(_ map: MKMapView) {
            guard let command = parent.cameraCommand, command.id != lastCommandID else { return }
            lastCommandID = command.id

            switch command.action {
            case .followUser:
                map.setUserTrackingMode(.follow, animated: true)
            case .fitRoute(let coords) where coords.count >= 2:
                let lats = coords.map(\.latitude)
                let lons = coords.map(\.longitude)
                let center = CLLocationCoordinate2D(
                    latitude: (lats.min()! + lats.max()!) / 2,
                    longitude: (lons.min()! + lons.max()!) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.5),
                    longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.5)
                )
                map.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
            default:
                break
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            switch overlay {
            case let tiles as MKTileOverlay:
                let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
                renderer.alpha = 0.92
                return renderer
            case let line as MKPolyline:
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor.systemPurple.withAlphaComponent(0.85)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            case let polygon as MKPolygon:
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.18)
                renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.8)
                renderer.lineWidth = 2
                return renderer
            default:
                return MKOverlayRenderer(overlay: overlay)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let airport = annotation as? AirportAnnotation else { return nil }
            let id = "airport"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.image = MarkerImages.image(kind: airport.airport.kind, category: airport.category)
            view.canShowCallout = false
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? AirportAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            parent.onSelectAirport(annotation.airport)
        }
    }
}

/// MKTileOverlay that serves FAA chart tiles through the disk cache,
/// so anything browsed (or prefetched) keeps working offline.
final class CachingTileOverlay: MKTileOverlay {
    let layer: ChartLayer

    init(layer: ChartLayer) {
        self.layer = layer
        super.init(urlTemplate: nil)
        minimumZ = 4
        maximumZ = 12
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tile = TileID(z: path.z, x: path.x, y: path.y)
        let layer = self.layer
        Task {
            do {
                result(try await ChartTileCache.shared.tile(layer: layer, tile), nil)
            } catch {
                result(nil, error)
            }
        }
    }
}

final class AirportAnnotation: NSObject, MKAnnotation {
    let airport: Airport
    var category: FlightCategory?

    var coordinate: CLLocationCoordinate2D { airport.coordinate.cl }
    var title: String? { airport.ident }

    init(airport: Airport, category: FlightCategory?) {
        self.airport = airport
        self.category = category
    }
}

/// Pre-rendered airport dot images, cached per (kind, flight category).
enum MarkerImages {
    private static var cache: [String: UIImage] = [:]

    static func image(kind: AirportKind, category: FlightCategory?) -> UIImage {
        let key = "\(kind.rawValue)-\(category?.rawValue ?? "none")"
        if let cached = cache[key] { return cached }

        let size: CGFloat = switch kind {
        case .large: 26
        case .medium: 21
        case .small, .seaplane: 15
        }
        let color: UIColor = switch category {
        case .vfr: .systemGreen
        case .mvfr: .systemBlue
        case .ifr: .systemRed
        case .lifr: .systemPurple
        case nil: .systemGray
        }

        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            color.setFill()
            ctx.cgContext.fillEllipse(in: rect)
            UIColor.white.withAlphaComponent(0.9).setStroke()
            ctx.cgContext.setLineWidth(1.5)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.75, dy: 0.75))

            let symbolName = kind == .seaplane ? "sailboat.fill" : "airplane"
            if let symbol = UIImage(systemName: symbolName)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let glyphSize = size * 0.55
                let cg = ctx.cgContext
                cg.saveGState()
                cg.translateBy(x: size / 2, y: size / 2)
                if kind != .seaplane {
                    cg.rotate(by: -.pi / 4)
                }
                symbol.draw(in: CGRect(
                    x: -glyphSize / 2, y: -glyphSize / 2,
                    width: glyphSize, height: glyphSize
                ))
                cg.restoreGState()
            }
        }
        cache[key] = image
        return image
    }
}
