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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(airports)
                .environment(weather)
                .environment(plan)
                .environment(location)
                .environment(briefing)
                .environment(tfrs)
                .environment(airspace)
                .environment(plates)
        }
        .modelContainer(for: LogEntry.self)
    }
}
