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

    private let container: ModelContainer
    private let cloudSyncActive: Bool

    init() {
        (container, cloudSyncActive) = Self.makeContainer()
    }

    /// CloudKit-backed store when possible, local store otherwise.
    ///
    /// The fallback matters in three real situations: demo/capture runs
    /// (deterministic data, no account), unsigned CI builds (no iCloud
    /// entitlement — CloudKit container creation throws), and devices
    /// signed out of iCloud. The app must behave identically in all of
    /// them, just without sync.
    private static func makeContainer() -> (ModelContainer, Bool) {
        let schema = Schema([LogEntry.self, UserAircraft.self])

        if !DemoData.isEnabled {
            let cloud = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.headwind.app")
            )
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                return (container, true)
            }
        }

        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return (try ModelContainer(for: schema, configurations: local), false)
        } catch {
            fatalError("Cannot create model container: \(error)")
        }
    }

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
                .environment(\.cloudSyncActive, cloudSyncActive)
        }
        .modelContainer(container)
    }
}

extension EnvironmentValues {
    /// True when the store is CloudKit-backed and syncing via the
    /// user's Apple ID.
    @Entry var cloudSyncActive: Bool = false
}
