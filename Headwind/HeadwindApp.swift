import SwiftUI
import SwiftData

@main
struct HeadwindApp: App {
    @State private var airports = AirportStore()
    @State private var weather = WeatherService()
    @State private var plan = PlanStore()
    @State private var location = LocationService()
    @State private var briefing = BriefingService()
    @State private var tfrs = TFRService()
    @State private var airspace = AirspaceService()
    @State private var plates = PlateStore()
    @State private var tracks = TrackRecorder()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(airports)
                .environment(weather)
                .environment(plan)
                .environment(location)
                .environment(briefing)
                .environment(tfrs)
                .environment(airspace)
                .environment(plates)
                .environment(tracks)
                .environment(\.cloudSyncActive, AppModelContainer.cloudSyncActive)
        }
        .modelContainer(AppModelContainer.shared)
    }
}

extension EnvironmentValues {
    /// True when the store is CloudKit-backed and syncing via the
    /// user's Apple ID.
    @Entry var cloudSyncActive: Bool = false
}
