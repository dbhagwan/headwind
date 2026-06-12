import SwiftUI
import MapKit
import HeadwindCore

/// The moving map: ownship position, airports filtered by zoom level,
/// the active route, and a Liquid Glass instrument strip.
struct MapScreen: View {
    @Environment(AirportStore.self) private var airports
    @Environment(LocationService.self) private var location
    @Environment(PlanStore.self) private var plan
    @Environment(WeatherService.self) private var weather

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var visibleAirports: [Airport] = []
    @State private var showsImagery = false
    @State private var selectedAirport: Airport?

    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(visibleAirports) { airport in
                Annotation(airport.ident, coordinate: airport.coordinate.cl) {
                    AirportMarker(
                        airport: airport,
                        category: weather.metar(for: airport.ident)?.flightCategory
                    )
                    .onTapGesture { selectedAirport = airport }
                }
                .annotationTitles(.automatic)
            }

            if plan.waypoints.count >= 2 {
                MapPolyline(coordinates: plan.waypoints.map(\.coordinate.cl))
                    .stroke(
                        .purple.opacity(0.85),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .mapStyle(showsImagery ? .hybrid(elevation: .realistic) : .standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            updateVisibleAirports()
        }
        .overlay(alignment: .bottomTrailing) {
            mapActions
                .padding(.trailing, 12)
                .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top) {
            InstrumentStrip()
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .sheet(item: $selectedAirport) { airport in
            NavigationStack {
                AirportDetailScreen(airport: airport)
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            location.start()
            await airports.load()
            updateVisibleAirports()
        }
        .onChange(of: airports.isLoading) {
            updateVisibleAirports()
        }
    }

    /// Filters the 16k-airport directory to what the camera can usefully
    /// show: majors when zoomed out, every GA field once zoomed in.
    private func updateVisibleAirports() {
        guard !airports.database.isEmpty, let region = visibleRegion else { return }

        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        let kinds: Set<AirportKind>
        if span > 6 {
            kinds = [.large]
        } else if span > 2 {
            kinds = [.large, .medium]
        } else {
            kinds = Set(AirportKind.allCases)
        }

        let bounds = GeoBounds(
            minLat: region.center.latitude - region.span.latitudeDelta / 2,
            maxLat: region.center.latitude + region.span.latitudeDelta / 2,
            minLon: region.center.longitude - region.span.longitudeDelta / 2,
            maxLon: region.center.longitude + region.span.longitudeDelta / 2
        )
        visibleAirports = airports.database.airports(within: bounds, kinds: kinds, limit: 120)

        let towerFields = visibleAirports
            .filter { $0.kind == .large || $0.kind == .medium }
            .map(\.ident)
        Task {
            await weather.ensureMetars(for: towerFields)
        }
    }

    private var mapActions: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                Button {
                    showsImagery.toggle()
                } label: {
                    Image(systemName: showsImagery ? "globe.americas.fill" : "globe.americas")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)

                if plan.waypoints.count >= 2 {
                    Button {
                        position = .region(routeRegion(for: plan.waypoints))
                    } label: {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                }
            }
        }
    }

    private func routeRegion(for waypoints: [Waypoint]) -> MKCoordinateRegion {
        let lats = waypoints.map(\.coordinate.latitude)
        let lons = waypoints.map(\.coordinate.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion(.world)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.5),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.5)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// Airport dot tinted by current flight category (gray when unknown),
/// sized by airport class.
private struct AirportMarker: View {
    let airport: Airport
    let category: FlightCategory?

    private var size: CGFloat {
        switch airport.kind {
        case .large: 24
        case .medium: 20
        case .small, .seaplane: 15
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill((category?.color ?? .gray).gradient)
            Image(systemName: airport.kind == .seaplane ? "sailboat.fill" : "airplane")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(airport.kind == .seaplane ? 0 : -45))
        }
        .frame(width: size, height: size)
        .shadow(radius: 2)
    }
}

/// Glass strip with live ground speed, track, and altitude.
private struct InstrumentStrip: View {
    @Environment(LocationService.self) private var location

    var body: some View {
        HStack(spacing: 20) {
            InstrumentReadout(
                label: "GS",
                value: location.groundSpeedKts.map { String(Int($0.rounded())) } ?? "––",
                unit: "KT"
            )
            InstrumentReadout(
                label: "TRK",
                value: location.trackDeg.map { String(format: "%03d", Int($0.rounded())) } ?? "–––",
                unit: "°"
            )
            InstrumentReadout(
                label: "ALT",
                value: location.altitudeFt.map { String(Int($0.rounded())) } ?? "––––",
                unit: "FT"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}
