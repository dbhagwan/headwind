import SwiftUI
import SwiftData

@main
struct HeadwindApp: App {
    @State private var airports = AirportStore()
    @State private var weather = WeatherService()
    @State private var plan = PlanStore()
    @State private var location = LocationService()
    @State private var briefing = BriefingService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(airports)
                .environment(weather)
                .environment(plan)
                .environment(location)
                .environment(briefing)
        }
        .modelContainer(for: LogEntry.self)
    }
}
