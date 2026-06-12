import SwiftUI
import MapKit
import HeadwindCore

/// The moving map: FAA chart layers, TFRs, ownship, route, and airports,
/// with the Liquid Glass instrument strip and controls layered above.
struct MapScreen: View {
    @Environment(AirportStore.self) private var airports
    @Environment(LocationService.self) private var location
    @Environment(PlanStore.self) private var plan
    @Environment(WeatherService.self) private var weather
    @Environment(TFRService.self) private var tfrService

    @AppStorage("map.chartLayer") private var chartLayerRaw = ChartLayer.none.rawValue
    @AppStorage("map.showsTFRs") private var showsTFRs = true

    @State private var showsImagery = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var visibleAirports: [Airport] = []
    @State private var selectedAirport: Airport?
    @State private var cameraCommand: MapCameraCommand?
    @State private var showsOfflineSheet = false

    private var chartLayer: ChartLayer {
        ChartLayer(rawValue: chartLayerRaw) ?? .none
    }

    var body: some View {
        FlightMapView(
            airports: visibleAirports,
            categories: weather.metars.mapValues(\.flightCategory),
            route: plan.waypoints.map(\.coordinate),
            chartLayer: chartLayer,
            showsImagery: showsImagery,
            tfrs: tfrService.tfrs,
            showsTFRs: showsTFRs,
            cameraCommand: cameraCommand,
            onRegionChange: { region in
                visibleRegion = region
                updateVisibleAirports()
            },
            onSelectAirport: { selectedAirport = $0 }
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            InstrumentStrip()
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .overlay(alignment: .bottomTrailing) {
            mapActions
                .padding(.trailing, 12)
                .padding(.bottom, 24)
        }
        .sheet(item: $selectedAirport) { airport in
            NavigationStack {
                AirportDetailScreen(airport: airport)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsOfflineSheet) {
            OfflineChartsSheet(layer: chartLayer, region: visibleRegion)
        }
        .task {
            location.start()
            await airports.load()
            updateVisibleAirports()
            await tfrService.refresh()
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
                Menu {
                    Picker("Chart", selection: $chartLayerRaw) {
                        ForEach(ChartLayer.allCases) { layer in
                            Text(layer.title).tag(layer.rawValue)
                        }
                    }
                    Toggle("Show TFRs", isOn: $showsTFRs)
                    Toggle("Satellite", isOn: $showsImagery)
                    if chartLayer != .none {
                        Button {
                            showsOfflineSheet = true
                        } label: {
                            Label("Offline Charts…", systemImage: "arrow.down.circle")
                        }
                    }
                } label: {
                    Image(systemName: chartLayer == .none ? "square.3.layers.3d" : "square.3.layers.3d.top.filled")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)

                Button {
                    cameraCommand = .followUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)

                if plan.waypoints.count >= 2 {
                    Button {
                        cameraCommand = .fitRoute(plan.waypoints.map(\.coordinate))
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
